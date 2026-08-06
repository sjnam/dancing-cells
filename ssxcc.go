//line ssxcc.w:31
package dcells

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"time"
)

//line ssxcc.w:144
const primExtra = 4 // set entries reserved below each item's base

type twoints struct {
	l, r int32
}

//line ssxcc.w:157
type XCC struct {

//line ssxcc.w:74
	Debug         bool          // print input summary and final stats to stderr
	PulseInterval time.Duration // if > 0, offer periodic Heartbeat strings

//line ssxcc.w:680
	Bound func(Frame) int // lower bound on the cost still to come; may be nil

//line ssxcc.w:159
	ctx context.Context

//line ssxcc.w:161

//line ssxcc.w:171
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

//line ssxcc.w:162

//line ssxcc.w:81
	names      []string // interned item names, by item number (1-based)
	nameIndex  map[string]int
	colorNames []string // interned colors, by id (1-based; 0 means "no color")
	colorIndex map[string]int

//line ssxcc.w:163

//line ssxcc.w:91
	force  []int32
	forced int

//line ssxcc.w:164

//line ssxcc.w:185
	choice    []int32
	saved     []int32
	savestack []twoints
	saveptr   int

//line ssxcc.w:165

//line ssxcc.w:687
	minimizing bool
	optNo      []int32 // node -> the option that node belongs to
	optCost    []int32 // option number -> the price the caller put on it
	itemBase   []int32 // item number -> its base in |set|
	cost       int64   // price of the options committed so far
	incumbent  int64   // price of the cheapest cover so far

//line ssxcc.w:166

//line ssxcc.w:95
	updates uint64
	nodes   uint64
	options uint64
	count   uint64

//line ssxcc.w:167

//line ssxcc.w:101
	solStream chan []Option
	heartbeat chan string
	pulse     *time.Ticker

//line ssxcc.w:168
}

//line ssxcc.w:198
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

func (s *XCC) WithContext(ctx context.Context) *XCC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *s
	c.ctx = ctx
	return &c
}

func (s *XCC) Updates() uint64 { return s.updates }

//line ssxcc.w:219
func (s *XCC) Nodes() uint64 { return s.nodes }

//line ssxcc.w:227
func (s *XCC) size(x int) int { return int(s.set[x-1]) }

//line ssxcc.w:228
func (s *XCC) pos(x int) int { return int(s.set[x-2]) }

//line ssxcc.w:229
func (s *XCC) itemNo(x int) int { return int(s.set[x-3]) }

func (s *XCC) setSize(x, v int) { s.set[x-1] = int32(v) }

//line ssxcc.w:232
func (s *XCC) setPos(x, v int) { s.set[x-2] = int32(v) }

//line ssxcc.w:233
func (s *XCC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

//line ssxcc.w:239
func (s *XCC) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

func (s *XCC) internColor(name string) int {
	if id, ok := s.colorIndex[name]; ok {
		return id
	}
	id := len(s.colorNames)
	s.colorNames = append(s.colorNames, name)
	s.colorIndex[name] = id
	return id
}

//line ssxcc.w:265
func (s *XCC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)

//line ssxcc.w:276
	s.solStream = make(chan []Option)
	s.heartbeat = make(chan string)

	go func() {
		defer close(s.solStream)
		defer close(s.heartbeat)

//line ssxcc.w:283

//line ssxcc.w:301
		if s.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
		}

//line ssxcc.w:284
		if s.PulseInterval > 0 {
			s.pulse = time.NewTicker(s.PulseInterval)
			defer s.pulse.Stop()
		}

		if s.baditem == 0 {
			s.search(0)
		}

//line ssxcc.w:293

//line ssxcc.w:308
		if s.Debug {
			plural := "s"
			if s.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				s.count, plural, s.updates, s.nodes)
		}

//line ssxcc.w:294
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}

//line ssxcc.w:268
}

//line ssxcc.w:325
func (s *XCC) search(level int) bool {
	s.nodes++
	select {
	case <-s.ctx.Done():
		return false
	default:
	}
	s.tick()

//line ssxcc.w:751
	if s.minimizing {
		rest := int64(0)
		if s.Bound != nil {
			rest = int64(s.Bound(Frame{s}))
		}
		if s.cost+rest >= s.incumbent {
			return true
		}
	}

//line ssxcc.w:335
	best, solution := s.chooseItem()
	if solution {
		return s.visit(level)
	}

//line ssxcc.w:355
	s.swapOut(best)
	s.oactive = s.active
	s.hide(best, 0, 0)
	s.saveSizes(level)
	s.choice = ensure(s.choice, level+1)
	for c := best; c < best+s.size(best); c++ {
		opt := int(s.set[c])
		s.choice[level] = int32(opt)

//line ssxcc.w:765
		price := int64(0)
		if s.minimizing {
			price = int64(s.optCost[s.optNo[opt]])
		}

//line ssxcc.w:364
		s.cost += price
		if s.commitOption(opt) {
			if !s.search(level + 1) {
				return false
			}
		}
		s.restoreSizes(level)
		s.cost -= price
	}

//line ssxcc.w:340
	return true
}

//line ssxcc.w:384
func (s *XCC) chooseItem() (best int, solution bool) {
	for s.forced != 0 {
		s.forced--
		if f := int(s.force[s.forced]); s.pos(f) < s.active {
			return f, false
		}
	}

//line ssxcc.w:403
	score := infSize
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // secondary items are not branched on
		}
		switch sz := s.size(x); {
		case sz == 0:
			// unreachable: hide never starves an active primary item
		case sz == 1:
			s.force = ensure(s.force, s.forced+1)
			s.force[s.forced] = int32(x)
			s.forced++
		case sz < score || (sz == score && x < best):
			best, score = x, sz
		}
	}

//line ssxcc.w:392
	if s.forced != 0 {
		s.forced--
		return int(s.force[s.forced]), false
	}
	return best, score == infSize
}

//line ssxcc.w:431
func (s *XCC) commitOption(opt int) bool {

//line ssxcc.w:438
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
			s.updates++
		}
		q++
	}
	s.active = p

//line ssxcc.w:433

//line ssxcc.w:466
	for q := opt + 1; q != opt; {
		c := int(s.nd[q].itm)
		if c < 0 {
			q += c
			continue
		}
		switch {
		case c < s.second:
			if !s.hide(c, 0, 1) {
				s.forced = 0
				return false
			}
		case s.pos(c) < s.oactive:
			if !s.hide(c, int(s.nd[q].clr), 1) {
				s.forced = 0
				return false
			}
		}
		q++
	}

//line ssxcc.w:434
	return true
}

//line ssxcc.w:495
func (s *XCC) hide(c, color, check int) bool {
	for rr, end := c, c+s.size(c); rr < end; rr++ {
		tt := int(s.set[rr])
		if color != 0 && int(s.nd[tt].clr) == color {
			continue
		}

//line ssxcc.w:512
		for nn := tt + 1; nn != tt; {
			u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
			if u < 0 {
				nn += u
				continue
			}
			if s.pos(u) < s.oactive {
				ss := s.size(u) - 1

//line ssxcc.w:531
				if ss <= 1 && check != 0 && u < s.second && s.pos(u) < s.active {
					if ss == 0 {
						return false
					}
					s.force = ensure(s.force, s.forced+1)
					s.force[s.forced] = int32(u)
					s.forced++
				}

//line ssxcc.w:521
				nnp := int(s.set[u+ss])
				s.setSize(u, ss)
				s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
				s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
				s.updates++
			}
			nn++
		}

//line ssxcc.w:502
	}
	return true
}

//line ssxcc.w:543
func (s *XCC) swapOut(x int) {
	p := s.active - 1
	s.active = p
	pp := s.pos(x)
	cc := int(s.item[p])
	s.item[p], s.item[pp] = int32(x), int32(cc)
	s.setPos(cc, pp)
	s.setPos(x, p)
	s.updates++
}

//line ssxcc.w:563
func (s *XCC) saveSizes(level int) {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		s.savestack[s.saveptr+p] = twoints{s.item[p], int32(s.size(int(s.item[p])))}
	}
	s.saveptr += s.active
	s.saved = ensure(s.saved, level+2)
	s.saved[level+1] = int32(s.saveptr)
}

func (s *XCC) restoreSizes(level int) {
	s.saveptr = int(s.saved[level+1])
	s.active = s.saveptr - int(s.saved[level])
	for p := -s.active; p < 0; p++ {
		e := s.savestack[s.saveptr+p]
		s.setSize(int(e.l), int(e.r))
	}
}

//line ssxcc.w:592
func (s *XCC) visit(level int) bool {
	s.count++
	s.incumbent = s.cost
	sol := make([]Option, level)
	for k := 0; k < level; k++ {
		sol[k] = s.option(int(s.choice[k]))
	}
	select {
	case <-s.ctx.Done():
		return false
	case s.solStream <- sol:
		return true
	}
}

//line ssxcc.w:611
func (s *XCC) tick() {
	if s.pulse == nil {
		return
	}
	select {
	case <-s.pulse.C:
		select {
		case s.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", s.nodes, s.count):
		default:
		}
	default:
	}
}

//line ssxcc.w:631
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

//line ssxcc.w:707
func (s *XCC) Minimize(rd io.Reader, cost func(o int, opt Option) int) *Result {
	s.inputMatrix(rd)

//line ssxcc.w:719
	s.optNo = make([]int32, s.lastNode+1)
	s.optCost = make([]int32, int(s.options)+1)
	o := int32(0)
	for k := 1; k < s.lastNode; k++ {
		if s.nd[k].itm <= 0 {
			continue // a spacer between two options
		}
		if s.nd[k-1].itm <= 0 {
			o++
			s.optCost[o] = int32(cost(int(o), s.option(k)))
		}
		s.optNo[k] = o
	}

//line ssxcc.w:739
	s.itemBase = make([]int32, s.itemlen+1)
	for k := 0; k < s.itemlen; k++ {
		base := int(s.item[k])
		s.itemBase[s.itemNo(base)] = int32(base)
	}

//line ssxcc.w:710
	s.minimizing, s.incumbent = true, infCost

//line ssxcc.w:276
	s.solStream = make(chan []Option)
	s.heartbeat = make(chan string)

	go func() {
		defer close(s.solStream)
		defer close(s.heartbeat)

//line ssxcc.w:283

//line ssxcc.w:301
		if s.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
		}

//line ssxcc.w:284
		if s.PulseInterval > 0 {
			s.pulse = time.NewTicker(s.PulseInterval)
			defer s.pulse.Stop()
		}

		if s.baditem == 0 {
			s.search(0)
		}

//line ssxcc.w:293

//line ssxcc.w:308
		if s.Debug {
			plural := "s"
			if s.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				s.count, plural, s.updates, s.nodes)
		}

//line ssxcc.w:294
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}

//line ssxcc.w:712
}

//line ssxcc.w:774
func (s *XCC) eachLive(yield func(item, opt int) bool) {
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue
		}
		i := s.itemNo(x)
		for c := x; c < x+s.size(x); c++ {
			if !yield(i, int(s.optNo[int(s.set[c])])) {
				return
			}
		}
	}
}

//line ssxcc.w:793
func (s *XCC) optionCost(opt int) int { return int(s.optCost[opt]) }

//line ssxcc.w:794
func (s *XCC) itemName(item int) string { return s.names[item] }

func (s *XCC) itemNeed(item int) int {
	if int(s.itemBase[item]) < s.second {
		return 1
	}
	return 0
}

//line ssxcc.w:813
func (s *XCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

//line ssxcc.w:829
func (s *XCC) readItemNames(br *bufio.Reader) {

//line ssxcc.w:852
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

//line ssxcc.w:831
	for buf[p] != 0 {
		name, next := token(buf, p, false)
		if name == "|" {
			if s.second != secondUnset {
				failf("item name line contains | twice")
			}
			s.second = len(s.names) // the next item's number
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
	s.lastItm = len(s.names) // items + 1 (names[0] is unused)
}

//line ssxcc.w:872
func (s *XCC) readOptions(br *bufio.Reader) {
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

//line ssxcc.w:892
func (s *XCC) readOption(buf []byte) {
	spacer := s.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {

//line ssxcc.w:912
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

//line ssxcc.w:897
	}

	if !hasPrimary {

//line ssxcc.w:939
		for s.lastNode > spacer {
			slot := int(s.nd[s.lastNode].itm) << 2
			s.setSize(slot, s.size(slot)-1)
			s.setPos(slot, spacer-1)
			s.lastNode--
		}

//line ssxcc.w:901
		return
	}
	s.nd[spacer].loc = int32(s.lastNode - spacer)
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	s.options++
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
}

//line ssxcc.w:951
func (s *XCC) createNode(m, spacer int, hasPrimary *bool) {
	slot := m << 2
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

//line ssxcc.w:972
func (s *XCC) finalize() {

//line ssxcc.w:983
	s.active, s.itemlen = s.lastItm-1, s.lastItm-1
	s.item = ensure(s.item, s.itemlen)
	s.set = ensure(s.set, (s.itemlen<<2)+1) // all input slots readable

	j := primExtra
	k := 0
	for ; k < s.itemlen; k++ {
		s.item[k] = int32(j)
		j += primExtra + s.size((k+1)<<2)
	}
	s.setlen = j - primExtra
	s.set = ensure(s.set, j+1)
	if s.second == secondUnset {
		s.osecond, s.second = s.active, j
	} else {
		s.osecond = s.second - 1
	}

//line ssxcc.w:974

//line ssxcc.w:1005
	for ; k != 0; k-- {
		base := int(s.item[k-1])
		if k == s.second {
			s.second = base
		}
		s.setSize(base, s.size(k<<2))
		if s.size(base) == 0 && k <= s.osecond {
			s.baditem = k
		}
		s.setPos(base, k-1)
		s.setItemNo(base, k)
	}

//line ssxcc.w:975

//line ssxcc.w:1022
	for k = 1; k < s.lastNode; k++ {
		if s.nd[k].itm < 0 {
			continue
		}
		base := int(s.item[int(s.nd[k].itm)-1])
		loc := base + int(s.nd[k].loc)
		s.nd[k].itm = int32(base)
		s.nd[k].loc = int32(loc)
		s.set[loc] = int32(k)
	}

//line ssxcc.w:976
}
