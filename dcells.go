// Package dcells solves exact-cover-with-colors (XCC) problems using sparse-set
// "dancing cells" data structures instead of dancing links.
//
// It is a library form of the SSXCC engine (a Go port of Donald E. Knuth's
// program of the same name), exposing an API that mirrors github.com/sjnam/dlx:
// feed a problem in the DLX text format through an io.Reader and range over the
// resulting solutions.
//
//	xc := dcells.NewXCC()
//	res := xc.Dance(reader)
//	for sol := range res.Solutions {
//		for _, opt := range sol {
//			fmt.Println(opt) // opt is []string of item names, e.g. [a d f]
//		}
//	}
//
// Item names and colors are arbitrary (possibly multibyte) strings, as in dlx.
package dcells

import (
	"context"
	"time"
)

const (
	primExtra   = 4       // set entries reserved below each item's base
	infSize     = 1 << 30 // "no item to branch on" => a solution
	secondUnset = 1 << 30 // sentinel for "no primary/secondary boundary yet"
)

// Option is one option of a solution, given as the list of its item names. A
// colored secondary item appears as "name:color".
type Option []string

// Result is returned by Dance. Range over Solutions to receive every exact
// cover; the channel is closed when the search finishes (or the context is
// cancelled). Heartbeat optionally carries periodic progress strings.
type Result struct {
	Solutions <-chan []Option
	Heartbeat <-chan string
}

// node is one cell of the matrix. itm and clr are fixed after input; loc moves
// as options dance in and out of an item's active set. clr is an interned color
// id (0 means none).
type node struct {
	itm, loc, clr int32
}

// twoints is one savestack entry: an item and the size to restore.
type twoints struct {
	l, r int32
}

// ===========================================================================
// XCC — exact cover with colors (d-way branching)
// ===========================================================================

// XCC holds the state of one dancing-cells computation.
type XCC struct {
	// Debug, when true, prints the input summary and final statistics to
	// stderr, like the dlx library.
	Debug bool
	// PulseInterval controls how often a Heartbeat string is offered.
	PulseInterval time.Duration

	ctx context.Context

	// matrix, items, and the sparse-set "set" array
	nd       []node
	lastNode int
	item     []int32
	second   int
	lastItm  int
	set      []int32
	itemlen  int
	setlen   int
	active   int
	oactive  int
	baditem  int
	osecond  int

	// interned item names (by item number, 1-based) and colors (by id, 1-based)
	names      []string
	nameIndex  map[string]int
	colorNames []string
	colorIndex map[string]int

	// force stack of items reduced to a single remaining option
	force  []int32
	forced int

	// depth-first search state
	choice    []int32
	saved     []int32
	savestack []twoints
	saveptr   int

	// statistics
	updates uint64
	nodes   uint64
	options uint64
	count   uint64

	// output, set up per Dance call
	solStream chan []Option
	heartbeat chan string
	pulse     *time.Ticker
}

// NewXCC returns a ready-to-use XCC. Heartbeats are off by default; set
// PulseInterval > 0 to receive them.
func NewXCC() *XCC {
	return &XCC{
		second:     secondUnset,
		names:      []string{""}, // item numbers are 1-based
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // color 0 means "no color"
		colorIndex: make(map[string]int),
		ctx:        context.Background(),
	}
}

// WithContext returns a copy of the XCC that aborts its search when ctx is
// cancelled. Call it before Dance.
func (s *XCC) WithContext(ctx context.Context) *XCC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *s
	c.ctx = ctx
	return &c
}

// Updates and Nodes report search statistics after the Solutions channel has
// been fully drained.
func (s *XCC) Updates() uint64 { return s.updates }
func (s *XCC) Nodes() uint64   { return s.nodes }

// ensure returns a slice of length >= n with s's contents preserved, growing
// the backing array (amortized) when necessary.
func ensure[T any](s []T, n int) []T {
	if n <= len(s) {
		return s
	}
	if n <= cap(s) {
		return s[:n]
	}
	t := make([]T, n, max(cap(s)*2, n, 64))
	copy(t, s)
	return t
}

// internName maps an item name to its 1-based number, registering it the first
// time. ok is false on a duplicate.
func (s *XCC) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

// internColor maps a color name to its 1-based id, registering it the first
// time.
func (s *XCC) internColor(name string) int {
	if id, ok := s.colorIndex[name]; ok {
		return id
	}
	id := len(s.colorNames)
	s.colorNames = append(s.colorNames, name)
	s.colorIndex[name] = id
	return id
}

// Sparse-set field accessors for item x (an index into set):
//
//	set[x-1]=size  set[x-2]=pos  set[x-3]=item number (for name lookup)
func (s *XCC) size(x int) int   { return int(s.set[x-1]) }
func (s *XCC) pos(x int) int    { return int(s.set[x-2]) }
func (s *XCC) itemNo(x int) int { return int(s.set[x-3]) }

func (s *XCC) setSize(x, v int)   { s.set[x-1] = int32(v) }
func (s *XCC) setPos(x, v int)    { s.set[x-2] = int32(v) }
func (s *XCC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

func isspace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
}

// option reconstructs the option containing node p as its list of item names,
// in the order the items were given (with ":color" suffixes for colored
// secondary items). The order is independent of which node p is, matching the
// dlx library, so callers can index opt[0], opt[1], ... positionally.
func (s *XCC) option(p int) Option {
	for s.nd[p-1].itm > 0 {
		p-- // move to the option's first node
	}
	var opt Option
	for q := p; s.nd[q].itm > 0; q++ {
		name := s.names[s.itemNo(int(s.nd[q].itm))]
		if c := s.nd[q].clr; c != 0 {
			name += ":" + s.colorNames[c]
		}
		opt = append(opt, name)
	}
	return opt
}

// ===========================================================================
// MCC — exact cover with multiplicities (binary branching)
// ===========================================================================

// MCC solves exact cover with item multiplicities and colors, using sparse-set
// "dancing cells" and binary branching. It is the library form of the SSMCC
// engine and complements the XCC type (NewXCC); use it when items may
// be covered a range of times.
//
//	mcc := dcells.NewMCC()
//	res := mcc.Dance(reader)
//	for sol := range res.Solutions { ... }
//
// A primary item name in the input may carry a multiplicity prefix "low:high|"
// or "high|" (default 1:1), as in Knuth's DLX3 / SSMCC. Item names and colors
// are arbitrary (possibly multibyte) strings.

const (
	mccExtra = 5 // set entries below each item base: size, pos, itemNo, slack, bound
	mccIprop = 5 // input-phase slot spacing
)

// threeints is one MCC savestack entry: an item, its size, and its bound.
type threeints struct{ l, s, b int32 }

// MCC holds the state of one multiplicity dancing-cells computation.
type MCC struct {
	Debug         bool
	PulseInterval time.Duration

	ctx context.Context

	nd       []node
	lastNode int
	item     []int32
	second   int
	lastItm  int
	set      []int32
	itemlen  int
	setlen   int
	active   int
	baditem  int
	osecond  int

	names      []string
	nameIndex  map[string]int
	colorNames []string
	colorIndex map[string]int

	force  []int32
	forced int

	included  []int32 // option included at each stage, for solution output
	savestack []threeints
	saveptr   int

	updates uint64
	nodes   uint64
	options uint64
	count   uint64

	solStream chan []Option
	heartbeat chan string
	pulse     *time.Ticker
}

// NewMCC returns a ready-to-use MCC solver. Heartbeats are off by default; set
// PulseInterval > 0 to receive them.
func NewMCC() *MCC {
	return &MCC{
		second:     secondUnset,
		names:      []string{""},
		nameIndex:  make(map[string]int),
		colorNames: []string{""},
		colorIndex: make(map[string]int),
		ctx:        context.Background(),
	}
}

// WithContext returns a copy of the MCC solver that aborts when ctx is
// cancelled. Call it before Dance.
func (m *MCC) WithContext(ctx context.Context) *MCC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *m
	c.ctx = ctx
	return &c
}

func (m *MCC) Updates() uint64 { return m.updates }
func (m *MCC) Nodes() uint64   { return m.nodes }

// Sparse-set field accessors for item x (an index into set):
//
//	set[x-1]=size  set[x-2]=pos  set[x-3]=item number
//	set[x-4]=slack  set[x-5]=bound  (slack/bound only meaningful for primary)
func (m *MCC) size(x int) int   { return int(m.set[x-1]) }
func (m *MCC) pos(x int) int    { return int(m.set[x-2]) }
func (m *MCC) itemNo(x int) int { return int(m.set[x-3]) }
func (m *MCC) slack(x int) int  { return int(m.set[x-4]) }
func (m *MCC) bound(x int) int  { return int(m.set[x-5]) }

func (m *MCC) setSize(x, v int)   { m.set[x-1] = int32(v) }
func (m *MCC) setPos(x, v int)    { m.set[x-2] = int32(v) }
func (m *MCC) setItemNo(x, v int) { m.set[x-3] = int32(v) }
func (m *MCC) setSlack(x, v int)  { m.set[x-4] = int32(v) }
func (m *MCC) setBound(x, v int)  { m.set[x-5] = int32(v) }

func (m *MCC) internName(name string) (num int, ok bool) {
	if _, dup := m.nameIndex[name]; dup {
		return 0, false
	}
	num = len(m.names)
	m.names = append(m.names, name)
	m.nameIndex[name] = num
	return num, true
}

func (m *MCC) internColor(name string) int {
	if id, ok := m.colorIndex[name]; ok {
		return id
	}
	id := len(m.colorNames)
	m.colorNames = append(m.colorNames, name)
	m.colorIndex[name] = id
	return id
}

// option reconstructs the option containing node p as its item names, in input
// order (with ":color" suffixes), so callers can index opt[0], opt[1], ... .
func (m *MCC) option(p int) Option {
	for m.nd[p-1].itm > 0 {
		p--
	}
	var opt Option
	for q := p; m.nd[q].itm > 0; q++ {
		name := m.names[m.itemNo(int(m.nd[q].itm))]
		if c := m.nd[q].clr; c != 0 {
			name += ":" + m.colorNames[c]
		}
		opt = append(opt, name)
	}
	return opt
}
