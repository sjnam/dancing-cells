package dcells

import (
	"context"
	"time"
)

// MCC solves exact cover with item multiplicities and colors, using sparse-set
// "dancing cells" and binary branching. It is the library form of the SSMCC
// engine and complements the XCC-only Solver (NewDancer); use it when items may
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
