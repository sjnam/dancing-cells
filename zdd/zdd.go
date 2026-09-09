// Package zdd represents all solutions of an exact cover problem as a ZDD.
//
//line zdd/zdd.w:69
//line zdd/zdd.w:70
package zdd

import (
	"bufio"
	"fmt"
	"io"
	"iter"
	"math/big"
	"math/rand/v2"
	"os"
	"strings"

	"github.com/sjnam/bdd"
	cells "github.com/sjnam/dancing-cells"
)

//line zdd/zdd.w:178
const (
	zExtra      = 4       // set entries reserved below each item's base
	zIprop      = 4       // input-phase slot spacing
	infSize     = 1 << 30 // "no item to branch on" => a solution
	secondUnset = 1 << 30 // sentinel for "no primary/secondary boundary yet"
)

type node struct {
	itm, loc, clr int32
}

type twoints struct {
	l, r int32
}

//line zdd/zdd.w:198
type Solver struct {
	Debug bool // print an input summary and final tallies to stderr
	MRV   bool // branch on the fewest-options item; |New| turns it on

//line zdd/zdd.w:202

//line zdd/zdd.w:210
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
	itemBase []int32 // item number -> its base in set

//line zdd/zdd.w:203

//line zdd/zdd.w:225
	names      []string
	nameIndex  map[string]int
	colorNames []string
	colorIndex map[string]int

//line zdd/zdd.w:204

//line zdd/zdd.w:236
	options  int
	optNo    []int32
	optFirst []int32

//line zdd/zdd.w:205

//line zdd/zdd.w:241
	saved     []int32
	savestack []twoints
	saveptr   int
	clr       []int32 // item number -> the color it was purified to
	sig       []byte  // scratch space for the signature

//line zdd/zdd.w:206

//line zdd/zdd.w:248
	z     *bdd.ZDD
	memo  map[string]bdd.Func
	nodes uint64
	hits  uint64

//line zdd/zdd.w:207
}

//line zdd/zdd.w:254
func New() *Solver {
	return &Solver{
		MRV:        true,
		second:     secondUnset,
		names:      []string{""}, // item numbers are 1-based
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // color 0 means "no color"
		colorIndex: make(map[string]int),
	}
}

func (s *Solver) Nodes() uint64 { return s.nodes }

//line zdd/zdd.w:266
func (s *Solver) Hits() uint64 { return s.hits }

//line zdd/zdd.w:267
func (s *Solver) Signatures() int { return len(s.memo) }

//line zdd/zdd.w:270
func (s *Solver) size(x int) int { return int(s.set[x-1]) }

//line zdd/zdd.w:271
func (s *Solver) pos(x int) int { return int(s.set[x-2]) }

//line zdd/zdd.w:272
func (s *Solver) itemNo(x int) int { return int(s.set[x-3]) }

func (s *Solver) setSize(x, v int) { s.set[x-1] = int32(v) }

//line zdd/zdd.w:275
func (s *Solver) setPos(x, v int) { s.set[x-2] = int32(v) }

//line zdd/zdd.w:276
func (s *Solver) setItemNo(x, v int) { s.set[x-3] = int32(v) }

//line zdd/zdd.w:279
func (s *Solver) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

func (s *Solver) internColor(name string) int {
	if id, ok := s.colorIndex[name]; ok {
		return id
	}
	id := len(s.colorNames)
	s.colorNames = append(s.colorNames, name)
	s.colorIndex[name] = id
	return id
}

//line zdd/zdd.w:125
func (s *Solver) signature() string {
	s.sig = s.sig[:0]
	for i := 1; i <= s.itemlen; i++ {
		x := int(s.itemBase[i])
		switch {
		case s.pos(x) < s.active:
			if x < s.second || s.size(x) > 0 {
				s.sig = varint(s.sig, 2*i)
			}
		case x >= s.second && s.clr[i] != 0:
			s.sig = varint(s.sig, 2*i+1)
			s.sig = varint(s.sig, int(s.clr[i]))
		}
	}
	return string(s.sig)
}

func varint(b []byte, v int) []byte {
	for v >= 0x80 {
		b = append(b, byte(v)|0x80)
		v >>= 7
	}
	return append(b, byte(v))
}

//line zdd/zdd.w:305
func (s *Solver) Dance(rd io.Reader) *Diagram {
	s.inputMatrix(rd)
	s.z = bdd.NewZDD(s.options)
	s.memo = make(map[string]bdd.Func)

//line zdd/zdd.w:319
	if s.Debug {
		fmt.Fprintf(os.Stderr,
			"(%d options, %d+%d items, %d entries successfully read)\n",
			s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
	}

//line zdd/zdd.w:310
	root := s.z.Empty()
	if s.baditem == 0 {
		root = s.search()
	}

//line zdd/zdd.w:326
	if s.Debug {
		fmt.Fprintf(os.Stderr,
			"Altogether %s solutions, %d ZDD nodes,"+
				" %d search nodes, %d signatures, %d hits.\n",
			s.z.Count(root).String(), s.z.Size(root), s.nodes, len(s.memo), s.hits)
	}

//line zdd/zdd.w:315
	return &Diagram{s: s, z: s.z, root: root}
}

//line zdd/zdd.w:339
func (s *Solver) search() bdd.Func {
	s.nodes++
	best, score := s.chooseItem()
	if score == infSize {
		return s.z.Unit()
	}
	if score == 0 {
		return s.z.Empty()
	}
	key := s.signature()
	if f, ok := s.memo[key]; ok {
		s.hits++
		return f
	}

//line zdd/zdd.w:368
	res := s.z.Empty()
	s.swapOut(best)
	s.oactive = s.active
	s.hide(best, 0, 0)
	lo := s.saveptr
	s.saveSizes()
	hi := s.saveptr
	for c := best; c < best+s.size(best); c++ {
		opt := int(s.set[c])
		if s.commitOption(opt) {
			sub := s.search()
			res = s.z.Union(res, s.z.Join(s.z.Elt(int(s.optNo[opt])-1), sub))
		}
		s.restoreSizes(lo, hi)
	}

//line zdd/zdd.w:354
	s.memo[key] = res
	return res
}

//line zdd/zdd.w:398
func (s *Solver) chooseItem() (best, score int) {
	score = infSize
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // secondary items are not branched on
		}
		sz := s.size(x)
		if sz == 0 {
			return x, 0
		}

//line zdd/zdd.w:422
		if !s.MRV {
			if score == infSize || x < best {
				best, score = x, sz
			}
			continue
		}
		if sz < score || (sz == score && x < best) {
			best, score = x, sz
		}

//line zdd/zdd.w:410
	}
	return best, score
}

//line zdd/zdd.w:439
func (s *Solver) commitOption(opt int) bool {

//line zdd/zdd.w:446
	p := s.active
	s.oactive = s.active
	for q := opt + 1; q != opt; {
		c := int(s.nd[q].itm)
		if c < 0 {
			q += c
			continue
		}
		if pp := s.pos(c); pp < p {
			p--
			cc := int(s.item[p])
			s.item[p], s.item[pp] = int32(c), int32(cc)
			s.setPos(cc, pp)
			s.setPos(c, p)
			if c >= s.second {
				s.clr[s.itemNo(c)] = s.nd[q].clr
			}
		}
		q++
	}
	s.active = p

//line zdd/zdd.w:441

//line zdd/zdd.w:469
	for q := opt + 1; q != opt; {
		c := int(s.nd[q].itm)
		if c < 0 {
			q += c
			continue
		}
		switch {
		case c < s.second:
			if !s.hide(c, 0, 1) {
				return false
			}
		case s.pos(c) < s.oactive:
			if !s.hide(c, int(s.nd[q].clr), 1) {
				return false
			}
		}
		q++
	}

//line zdd/zdd.w:442
	return true
}

//line zdd/zdd.w:489
func (s *Solver) hide(c, color, check int) bool {
	for rr, end := c, c+s.size(c); rr < end; rr++ {
		tt := int(s.set[rr])
		if color != 0 && int(s.nd[tt].clr) == color {
			continue
		}

//line zdd/zdd.w:501
		for nn := tt + 1; nn != tt; {
			u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
			if u < 0 {
				nn += u
				continue
			}
			if s.pos(u) < s.oactive {
				ss := s.size(u) - 1
				if ss == 0 && check != 0 && u < s.second && s.pos(u) < s.active {
					return false
				}
				nnp := int(s.set[u+ss])
				s.setSize(u, ss)
				s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
				s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
			}
			nn++
		}

//line zdd/zdd.w:496
	}
	return true
}

//line zdd/zdd.w:521
func (s *Solver) swapOut(x int) {
	p := s.active - 1
	s.active = p
	pp := s.pos(x)
	cc := int(s.item[p])
	s.item[p], s.item[pp] = int32(x), int32(cc)
	s.setPos(cc, pp)
	s.setPos(x, p)
}

//line zdd/zdd.w:537
func (s *Solver) saveSizes() {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		x := int(s.item[p])
		s.savestack[s.saveptr+p] = twoints{int32(x), int32(s.size(x))}
	}
	s.saveptr += s.active
}

func (s *Solver) restoreSizes(lo, hi int) {
	s.saveptr = hi
	s.active = hi - lo
	for p := 0; p < s.active; p++ {
		e := s.savestack[lo+p]
		s.setSize(int(e.l), int(e.r))
	}
}

//line zdd/zdd.w:559
func (s *Solver) option(o int) cells.Option {
	var opt cells.Option
	for q := int(s.optFirst[o]); s.nd[q].itm > 0; q++ {
		name := s.names[s.itemNo(int(s.nd[q].itm))]
		if c := s.nd[q].clr; c != 0 {
			name += ":" + s.colorNames[c]
		}
		opt = append(opt, name)
	}
	return opt
}

//line zdd/zdd.w:579
type Diagram struct {
	s    *Solver
	z    *bdd.ZDD
	root bdd.Func
}

func (d *Diagram) ZDD() (*bdd.ZDD, bdd.Func) { return d.z, d.root }

//line zdd/zdd.w:594
func (d *Diagram) Count() *big.Int { return d.z.Count(d.root) }

//line zdd/zdd.w:595
func (d *Diagram) Nodes() int { return d.z.Size(d.root) }

//line zdd/zdd.w:596
func (d *Diagram) Options() int { return d.s.options }

//line zdd/zdd.w:603
func (d *Diagram) Option(o int) cells.Option { return d.s.option(o) }

func (d *Diagram) solution(elts []int) []cells.Option {
	sol := make([]cells.Option, len(elts))
	for i, e := range elts {
		sol[i] = d.s.option(e + 1)
	}
	return sol
}

//line zdd/zdd.w:617
func (d *Diagram) Solutions() iter.Seq[[]cells.Option] {
	return func(yield func([]cells.Option) bool) {
		for elts := range d.z.Subsets(d.root) {
			if !yield(d.solution(elts)) {
				return
			}
		}
	}
}

//line zdd/zdd.w:634
func (d *Diagram) Random(r *rand.Rand) ([]cells.Option, bool) {
	elts, ok := d.z.Random(d.root, r)
	if !ok {
		return nil, false
	}
	return d.solution(elts), true
}

func (d *Diagram) MaxWeight(w []int) ([]cells.Option, int, bool) {
	ew := make([]int, d.s.options)
	for k := range ew {
		if k+1 < len(w) {
			ew[k] = w[k+1]
		}
	}
	elts, wt, ok := d.z.MaxWeight(d.root, ew)
	if !ok {
		return nil, 0, false
	}
	return d.solution(elts), wt, true
}

//line zdd/zdd.w:662
func (s *Solver) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

//line zdd/zdd.w:679
type parseError struct{ msg string }

func (e *parseError) Error() string { return e.msg }

func failf(format string, a ...any) {
	panic(&parseError{fmt.Sprintf(format, a...)})
}

func isspace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
}

func nextLine(br *bufio.Reader) (buf []byte, ok bool) {
	str, err := br.ReadString('\n')
	if len(str) == 0 && err != nil {
		return nil, false
	}
	buf = make([]byte, len(str)+1)
	copy(buf, str)
	return buf, true
}

//line zdd/zdd.w:702
func skipSpace(buf []byte, p int) int {
	for isspace(buf[p]) {
		p++
	}
	return p
}

func token(buf []byte, p int, stopColon bool) (string, int) {
	start := p
	for buf[p] != 0 && !isspace(buf[p]) && !(stopColon && buf[p] == ':') {
		p++
	}
	return string(buf[start:p]), p
}

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

//line zdd/zdd.w:730
func (s *Solver) readItemNames(br *bufio.Reader) {

//line zdd/zdd.w:753
	var buf []byte
	var p int
	found := false
	for {
		var ok bool
		if buf, ok = nextLine(br); !ok {
			break
		}
		if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
			found = true
			break
		}
	}
	if !found {
		failf("no items")
	}

//line zdd/zdd.w:732
	for buf[p] != 0 {
		name, next := token(buf, p, false)
		if name == "|" {
			if s.second != secondUnset {
				failf("item name line contains | twice")
			}
			s.second = len(s.names)
		} else {
			if strings.ContainsAny(name, ":|") {
				failf("illegal character in item name: %q", name)
			}
			if _, ok := s.internName(name); !ok {
				failf("duplicate item name: %s", name)
			}
		}
		p = skipSpace(buf, next)
	}
	s.lastItm = len(s.names)
}

//line zdd/zdd.w:771
func (s *Solver) readOptions(br *bufio.Reader) {
	for {
		buf, ok := nextLine(br)
		if !ok {
			break
		}
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
			continue
		}
		s.readOption(buf)
	}
	s.finalize()
}

//line zdd/zdd.w:789
func (s *Solver) readOption(buf []byte) {
	spacer := s.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {

//line zdd/zdd.w:808
		name, next := token(buf, p, true)
		if name == "" {
			failf("empty item name")
		}
		m, known := s.nameIndex[name]
		if !known {
			failf("unknown item name: %s", name)
		}
		s.createNode(m, spacer, &hasPrimary)
		if buf[next] == ':' {
			if m < s.second {
				failf("primary item must be uncolored: %s", name)
			}
			color, ce := token(buf, next+1, false)
			if color == "" {
				failf("missing color after %s:", name)
			}
			s.nd[s.lastNode].clr = int32(s.internColor(color))
			next = ce
		} else {
			s.nd[s.lastNode].clr = 0
		}
		p = skipSpace(buf, next)

//line zdd/zdd.w:794
	}

	if !hasPrimary {

//line zdd/zdd.w:833
		for s.lastNode > spacer {
			slot := int(s.nd[s.lastNode].itm) * zIprop
			s.setSize(slot, s.size(slot)-1)
			s.setPos(slot, spacer-1)
			s.lastNode--
		}

//line zdd/zdd.w:798
		return
	}
	s.nd[spacer].loc = int32(s.lastNode - spacer)
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	s.options++
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
}

//line zdd/zdd.w:841
func (s *Solver) createNode(m, spacer int, hasPrimary *bool) {
	slot := m * zIprop
	s.set = ensure(s.set, slot)
	if s.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", s.names[m])
	}
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	t := s.size(slot)
	s.nd[s.lastNode].itm = int32(m)
	s.nd[s.lastNode].loc = int32(t)
	if m < s.second {
		*hasPrimary = true
	}
	s.setSize(slot, t+1)
	s.setPos(slot, s.lastNode)
}

//line zdd/zdd.w:863
func (s *Solver) finalize() {

//line zdd/zdd.w:871
	s.active, s.itemlen = s.lastItm-1, s.lastItm-1
	s.item = ensure(s.item, s.itemlen)
	s.set = ensure(s.set, s.itemlen*zIprop+1)

	j := zExtra
	k := 0
	for ; k < s.itemlen; k++ {
		s.item[k] = int32(j)
		j += zExtra + s.size((k+1)*zIprop)
	}
	s.setlen = j - zExtra
	s.set = ensure(s.set, j+1)
	if s.second == secondUnset {
		s.osecond, s.second = s.active, j
	} else {
		s.osecond = s.second - 1
	}

//line zdd/zdd.w:865

//line zdd/zdd.w:890
	for ; k != 0; k-- {
		base := int(s.item[k-1])
		if k == s.second {
			s.second = base
		}
		s.setSize(base, s.size(k*zIprop))
		if s.size(base) == 0 && k <= s.osecond {
			s.baditem = k
		}
		s.setPos(base, k-1)
		s.setItemNo(base, k)
	}

//line zdd/zdd.w:866

//line zdd/zdd.w:904
	for k = 1; k < s.lastNode; k++ {
		if s.nd[k].itm <= 0 {
			continue
		}
		base := int(s.item[int(s.nd[k].itm)-1])
		loc := base + int(s.nd[k].loc)
		s.nd[k].itm = int32(base)
		s.nd[k].loc = int32(loc)
		s.set[loc] = int32(k)
	}

//line zdd/zdd.w:867

//line zdd/zdd.w:919
	s.optNo = make([]int32, s.lastNode+1)
	s.optFirst = make([]int32, s.options+1)
	o := int32(0)
	for k = 1; k < s.lastNode; k++ {
		if s.nd[k].itm <= 0 {
			continue
		}
		if s.nd[k-1].itm <= 0 {
			o++
			s.optFirst[o] = int32(k)
		}
		s.optNo[k] = o
	}
	s.itemBase = make([]int32, s.itemlen+1)
	for k = 0; k < s.itemlen; k++ {
		base := int(s.item[k])
		s.itemBase[s.itemNo(base)] = int32(base)
	}
	s.clr = make([]int32, s.itemlen+1)

//line zdd/zdd.w:868
}
