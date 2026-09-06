//line xccdc.w:46
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

//line xccdc.w:183
func (s *XCCDC) trigger(opt int) int { return int(s.nd[opt].clr) }

//line xccdc.w:184
func (s *XCCDC) fixit(opt int) int { return int(s.nd[opt].xtra) }

//line xccdc.w:185
func (s *XCCDC) age(opt int) int { return int(s.nd[opt+1].xtra) }

func (s *XCCDC) setTrigger(opt, v int) { s.nd[opt].clr = int32(v) }

//line xccdc.w:188
func (s *XCCDC) setFixit(opt, v int) { s.nd[opt].xtra = int32(v) }

//line xccdc.w:189
func (s *XCCDC) setAge(opt, v int) { s.nd[opt+1].xtra = int32(v) }

//line xccdc.w:197
func (s *XCCDC) getavail() int {
	if p := int(s.pool[0].r); p != 0 {
		s.pool[0].r = s.pool[p].r
		return p // whatever info(p) held is the caller's business
	}
	s.poolptr++
	s.pool = ensure(s.pool, s.poolptr)
	return s.poolptr - 1
}

func (s *XCCDC) putavail(p int) {
	s.pool[p].r = s.pool[0].r
	s.pool[0].r = int32(p)
}

//line xccdc.w:228
func (s *XCCDC) markItems(opt int) {

//line xccdc.w:244
	if s.compatStamp == maxStamp {
		for k := 0; k < s.itemlen; k++ {
			s.setMark(int(s.item[k]), 0)
		}
		s.compatStamp = 0
	}
	s.compatStamp++

//line xccdc.w:230
	for nn := opt + 1; s.nd[nn].itm > 0; nn++ {
		ii := int(s.nd[nn].itm)
		s.setMark(ii, s.compatStamp)
		if ii >= s.second {
			if c := int(s.nd[nn].clr); c != 0 {
				s.setMatch(ii, c)
			} else {
				s.setMatch(ii, -1) // an uncolored item matches no color
			}
		}
	}
}

//line xccdc.w:262
func (s *XCCDC) compatible(p int) (opt int, ok bool) {
	opt = p
	for nn := p + 1; nn != p; nn++ {
		jj := int(s.nd[nn].itm)
		switch {
		case jj <= 0:
			opt = nn + jj - 1 // a spacer; jump back to the option's own
			nn = opt
		case s.mark(jj) == s.compatStamp:
			if jj < s.second || s.nd[nn].clr == 0 ||
				int(s.nd[nn].clr) != s.match(jj) {
				return opt, false
			}
		}
	}
	return opt, true
}

//line xccdc.w:295
func (s *XCCDC) optOut(opt, act int) bool {

//line xccdc.w:330
	for nn := opt + 1; ; nn++ {
		ii := int(s.nd[nn].itm)
		if ii <= 0 {
			break
		}
		p := int(s.nd[nn].loc)
		if p >= s.second && s.pos(ii) >= act {
			continue // ii was purified before this branch began
		}
		sz := s.size(ii) - 1
		if sz == 0 && p < s.second {

//line xccdc.w:355
			for s.qfront != s.qrear {
				p := s.qfront
				s.qfront = int(s.pool[p].r)
				waiting := int(s.pool[p].l)
				s.putavail(p)
				s.revertFixits(waiting)
			}
			return false

//line xccdc.w:342
		}
		nnp := int(s.set[ii+sz])
		s.setSize(ii, sz)
		s.set[ii+sz], s.set[p] = int32(nn), int32(nnp)
		s.nd[nn].loc, s.nd[nnp].loc = int32(ii+sz), int32(p)
		s.updates++
	}

//line xccdc.w:297
	s.setAge(opt, s.curAge)
	s.purges++
	tmin, cutoff := infiniteAge, -1
	hintP, hintQ, pp := 0, 0, 0
	for p := s.trigger(opt); p != 0; p = pp {
		q := int(s.pool[p].r)
		optp, ii := int(s.pool[p].l), int(s.pool[q].l)
		pp = int(s.pool[q].r)
		if optp < 0 {

//line xccdc.w:979
			c := -optp - 1
			if c < s.curAge && ii == int(s.stageStamp[(c+1)>>1]) {
				hintP, hintQ, cutoff = p, q, c
				break // everything below is known to be inactive
			}
			s.putavail(p) // the hint has gone stale
			s.putavail(q)
			continue

//line xccdc.w:307
		}

//line xccdc.w:390
		t, dead := -1, false
		if a := s.age(optp); a <= s.curAge {
			jj := int(s.nd[optp+1].itm) // optp's first item, always primary
			if int(s.nd[optp+1].loc) >= jj+s.size(jj) {
				t, dead = a, true
			}
		}
		if !dead && s.pos(ii) >= s.active {
			t, dead = s.curAge, true
		}

//line xccdc.w:309
		if !dead {

//line xccdc.w:406
			s.pool[p].l = int32(opt)
			s.pool[q].r = int32(s.fixit(optp))
			if s.fixit(optp) == 0 {
				r := s.getavail()
				s.pool[s.qrear].r = int32(r)
				s.pool[s.qrear].l = int32(optp)
				s.qrear = r
				s.setAge(optp, infiniteAge)
			}
			s.setFixit(optp, p)

//line xccdc.w:311
			continue
		}
		if t < 0 {
			s.putavail(p) // an option this young will never be back
			s.putavail(q)
			continue
		}

//line xccdc.w:418
		if s.trigHead[t] == 0 {
			s.trigTail[t] = int32(q)
		}
		s.pool[q].r = s.trigHead[t]
		s.trigHead[t] = int32(p)
		if t < tmin {
			tmin = t
		}

//line xccdc.w:319
	}

//line xccdc.w:995
	pp = 0
	if hintP != 0 {
		pp = hintP
		if tmin <= cutoff {
			pp = int(s.pool[hintQ].r) // the buckets subsume this hint
			s.putavail(hintP)
			s.putavail(hintQ)
		}
	}
	for t := tmin; t < s.curAge; t++ {
		if s.trigHead[t] == 0 {
			continue
		}
		s.pool[int(s.trigTail[t])].r = int32(pp)

//line xccdc.w:1022
		p := s.getavail()
		q := s.getavail()
		s.pool[p].l = int32(-t - 1)
		s.pool[p].r = int32(q)
		s.pool[q].l = s.stageStamp[(t+1)>>1]
		s.pool[q].r = s.trigHead[t]
		pp = p

//line xccdc.w:1010
		s.trigHead[t] = 0
	}
	if s.curAge >= 0 && s.trigHead[s.curAge] != 0 {
		s.pool[int(s.trigTail[s.curAge])].r = int32(pp)
		pp = int(s.trigHead[s.curAge])
		s.trigHead[s.curAge] = 0
	}
	s.setTrigger(opt, pp)

//line xccdc.w:321
	return true
}

//line xccdc.w:367
func (s *XCCDC) revertFixits(opt int) {
	var pp int
	for p := s.fixit(opt); p != 0; p = pp {
		q := int(s.pool[p].r)
		optp := int(s.pool[p].l)
		pp = int(s.pool[q].r)
		s.pool[p].l = int32(opt)
		s.pool[q].r = int32(s.trigger(optp))
		s.setTrigger(optp, p)
	}
	s.setFixit(opt, 0)
}

//line xccdc.w:434
func (s *XCCDC) emptyQueue() bool {
	for s.qfront != s.qrear {
		p := s.qfront
		opt := int(s.pool[p].l)
		s.qfront = int(s.pool[p].r)
		s.putavail(p)
		if s.age(opt) != infiniteAge {
			s.revertFixits(opt) // opt itself was purged in the meantime
			continue
		}
		s.markItems(opt)

//line xccdc.w:451
		var pp int
		for p := s.fixit(opt); p != 0; p = pp {
			q := int(s.pool[p].r)
			ii := int(s.pool[q].l) // a primary item not in opt
			pp = int(s.pool[q].r)
			found := false
			for c, end := ii, ii+s.size(ii); c < end; c++ {
				if optp, ok := s.compatible(int(s.set[c])); ok {

//line xccdc.w:474
					s.pool[p].l = int32(opt)
					s.pool[q].r = int32(s.trigger(optp))
					s.setTrigger(optp, p)

//line xccdc.w:460
					found = true
					break
				}
			}
			if !found {

//line xccdc.w:482
				s.setFixit(opt, p)
				s.revertFixits(opt)
				if !s.optOut(opt, s.active) {
					return false
				}

//line xccdc.w:466
				break
			}
		}
		s.setFixit(opt, 0)

//line xccdc.w:446
	}
	return true
}

//line xccdc.w:496
func (s *XCCDC) establishDC() bool {
	s.curAge = -1
	s.qfront = s.getavail()
	s.qrear = s.qfront
	for opt := 0; opt < s.lastNode; opt += int(s.nd[opt].loc) + 1 {
		s.markItems(opt)

//line xccdc.w:512
		for k := 0; k < s.osecond; k++ {
			ii := int(s.item[k])
			if s.mark(ii) == s.compatStamp {
				continue // ii is in opt, so no witness is called for
			}
			found := false
			for c, end := ii, ii+s.size(ii); c < end; c++ {
				if optp, ok := s.compatible(int(s.set[c])); ok {
					p := s.getavail()
					q := s.getavail()
					s.pool[p].r = int32(q)
					s.pool[q].l = int32(ii)

//line xccdc.w:474
					s.pool[p].l = int32(opt)
					s.pool[q].r = int32(s.trigger(optp))
					s.setTrigger(optp, p)

//line xccdc.w:525
					found = true
					break
				}
			}
			if !found {
				if !s.optOut(opt, s.active) {
					return false
				}
				break // opt is gone; on to the next one
			}
		}

//line xccdc.w:503
	}
	return s.emptyQueue()
}

//line xccdc.w:610
const (
	dcExtra     = 5       // set entries reserved below each item's base
	dcIprop     = 5       // input-phase slot spacing
	infiniteAge = 1 << 29 // an age no purged option can have
	maxStamp    = 1<<31 - 1

//line xccdc.w:615
)

type dcnode struct {
	itm, loc, clr, xtra int32 // itm and clr are fixed after input; loc dances
}

//line xccdc.w:643
type XCCDC struct {

//line xccdc.w:92
	Debug         bool          // print input summary and final stats to stderr
	PulseInterval time.Duration // if > 0, offer periodic Heartbeat strings

//line xccdc.w:645
	ctx context.Context

//line xccdc.w:647

//line xccdc.w:656
	nd       []dcnode
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

//line xccdc.w:648

//line xccdc.w:99
	names      []string // interned item names, by item number (1-based)
	nameIndex  map[string]int
	colorNames []string // interned colors, by id (1-based; 0 means "no color")
	colorIndex map[string]int

//line xccdc.w:649

//line xccdc.w:675
	pool         []twoints // info in .l, link in .r; cell 0 heads the free list
	poolptr      int
	qfront       int
	qrear        int
	trigHead     []int32 // buckets, indexed by age, used while rebuilding a list
	trigTail     []int32
	compatStamp  int
	curStamp     int32
	biggestStamp int32

//line xccdc.w:650

//line xccdc.w:691
	chosen     []int32
	stageStamp []int32
	savestack  []twoints
	saveptr    int
	curAge     int

//line xccdc.w:651

//line xccdc.w:108
	updates uint64
	nodes   uint64
	purges  uint64
	options uint64
	count   uint64

//line xccdc.w:652

//line xccdc.w:115
	solStream chan []Option
	heartbeat chan string
	pulse     *time.Ticker

//line xccdc.w:653
}

//line xccdc.w:704
func NewXCCDC() *XCCDC {
	return &XCCDC{
		second:     secondUnset,
		names:      []string{""}, // item numbers are 1-based
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // color 0 means "no color"
		colorIndex: make(map[string]int),
		pool:       make([]twoints, 2),
		poolptr:    1,
		ctx:        context.Background(),
	}
}

func (s *XCCDC) WithContext(ctx context.Context) *XCCDC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *s
	c.ctx = ctx
	return &c
}

func (s *XCCDC) Updates() uint64 { return s.updates }

//line xccdc.w:727
func (s *XCCDC) Nodes() uint64 { return s.nodes }

//line xccdc.w:728
func (s *XCCDC) Purges() uint64 { return s.purges }

//line xccdc.w:734
func (s *XCCDC) size(x int) int { return int(s.set[x-1]) }

//line xccdc.w:735
func (s *XCCDC) pos(x int) int { return int(s.set[x-2]) }

//line xccdc.w:736
func (s *XCCDC) itemNo(x int) int { return int(s.set[x-3]) }

//line xccdc.w:737
func (s *XCCDC) mark(x int) int { return int(s.set[x-4]) }

//line xccdc.w:738
func (s *XCCDC) match(x int) int { return int(s.set[x-5]) }

func (s *XCCDC) setSize(x, v int) { s.set[x-1] = int32(v) }

//line xccdc.w:741
func (s *XCCDC) setPos(x, v int) { s.set[x-2] = int32(v) }

//line xccdc.w:742
func (s *XCCDC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

//line xccdc.w:743
func (s *XCCDC) setMark(x, v int) { s.set[x-4] = int32(v) }

//line xccdc.w:744
func (s *XCCDC) setMatch(x, v int) { s.set[x-5] = int32(v) }

//line xccdc.w:752
func (s *XCCDC) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

func (s *XCCDC) internColor(name string) int {
	if id, ok := s.colorIndex[name]; ok {
		return id
	}
	id := len(s.colorNames)
	s.colorNames = append(s.colorNames, name)
	s.colorIndex[name] = id
	return id
}

//line xccdc.w:779
func (s *XCCDC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)
	s.solStream = make(chan []Option)
	s.heartbeat = make(chan string)

	go func() {
		defer close(s.solStream)
		defer close(s.heartbeat)

//line xccdc.w:788

//line xccdc.w:817
		if s.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
		}

//line xccdc.w:789
		if s.PulseInterval > 0 {
			s.pulse = time.NewTicker(s.PulseInterval)
			defer s.pulse.Stop()
		}

//line xccdc.w:805
		if s.baditem == 0 && s.establishDC() {

//line xccdc.w:541
			for opt := 0; opt < s.lastNode; opt += int(s.nd[opt].loc) + 1 {
				if s.age(opt) < 0 {
					continue
				}
				qq, pp := -1, 0
				for p := s.trigger(opt); p != 0; p = pp {
					q := int(s.pool[p].r)
					optp := int(s.pool[p].l)
					pp = int(s.pool[q].r)
					if s.age(optp) < 0 {
						s.putavail(p)
						s.putavail(q)
						if qq < 0 {
							s.setTrigger(opt, pp)
						} else {
							s.pool[qq].r = int32(pp)
						}
					} else {
						qq = q
					}
				}
			}

//line xccdc.w:807

//line xccdc.w:824
			if s.Debug {
				fmt.Fprintf(os.Stderr, "Domain consistency purged %d of %d options.\n",
					s.purges, s.options)
			}

//line xccdc.w:808
			s.search(0)
		}

//line xccdc.w:794

//line xccdc.w:830
		if s.Debug {
			plural := "s"
			if s.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr,
				"Altogether %d solution%s, %d updates, %d nodes, %d purges.\n",
				s.count, plural, s.updates, s.nodes, s.purges)
		}

//line xccdc.w:795
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}
}

//line xccdc.w:850
func (s *XCCDC) search(stage int) bool {

//line xccdc.w:886
	s.stageStamp = ensure(s.stageStamp, stage+1)
	s.trigHead = ensure(s.trigHead, 2*stage+2)
	s.trigTail = ensure(s.trigTail, 2*stage+2)

//line xccdc.w:1039
	s.biggestStamp++
	if s.biggestStamp == maxStamp {

//line xccdc.w:1053
		for k := 0; k < s.lastNode; k += int(s.nd[k].loc) + 1 {
			for p := s.trigger(k); p != 0; p = int(s.pool[p].r) {
				if s.pool[p].l < 0 {
					q := int(s.pool[p].r)
					r := int(s.pool[q].r)
					s.pool[p].l, s.pool[p].r = s.pool[r].l, s.pool[r].r
					s.putavail(q)
					s.putavail(r)
				}
			}
		}

//line xccdc.w:1042
		for k := 0; k < stage; k++ {
			s.stageStamp[k] = int32(k)
		}
		s.biggestStamp = int32(stage)
	}
	s.curStamp = s.biggestStamp

//line xccdc.w:890
	s.stageStamp[stage] = s.curStamp

//line xccdc.w:852
	mark := s.saveptr
	for {
		s.nodes++
		select {
		case <-s.ctx.Done():
			return false
		default:
		}
		s.tick()

		best, t := s.chooseItem()
		if t == infSize {
			return s.visit(stage)
		}
		opt := int(s.set[best])
		s.chosen = ensure(s.chosen, stage+1)
		s.chosen[stage] = int32(opt)
		if t != 1 {
			s.saveSizes()
		}

//line xccdc.w:897
		s.curAge = stage + stage + 1
		if s.includeOption(opt) && s.emptyQueue() {
			if !s.search(stage + 1) {
				return false
			}
		}

//line xccdc.w:873
		if t == 1 {
			return true // the choice was forced; there is no alternative
		}

//line xccdc.w:910
		s.restoreSizes(mark)
		s.curAge = stage + stage
		if !s.purgeOption(opt, s.active) || !s.emptyQueue() {
			return true
		}

//line xccdc.w:877
	}
}

//line xccdc.w:923
func (s *XCCDC) chooseItem() (best, score int) {
	score = infSize
	for k := 0; score > 1 && k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // secondary items are not branched on
		}
		switch sz := s.size(x); {
		case sz < score:
			best, score = x, sz
		case sz == score && x < best:
			best = x
		}
	}
	return best, score
}

//line xccdc.w:1075
func (s *XCCDC) includeOption(node int) bool {
	opt := s.optionOf(node)

//line xccdc.w:1096
	p := s.active
	s.oactive = s.active
	for q := opt + 1; s.nd[q].itm > 0; q++ {
		c := int(s.nd[q].itm)
		pp := s.pos(c)
		if pp < p {
			p--
			cc := int(s.item[p])
			s.item[p], s.item[pp] = int32(c), int32(cc)
			if c >= s.second {
				s.setMatch(c, int(s.nd[q].clr))
			}
			s.setPos(cc, pp)
			s.setPos(c, p)
			s.updates++
		}
	}
	s.active = p

//line xccdc.w:1078
	for k := s.active; k < s.oactive; k++ {
		x := int(s.item[k])
		end := x + s.size(x) - 1
		if x >= s.second && s.match(x) != 0 {

//line xccdc.w:1119
			c := s.match(x)
			for ; end >= x; end-- {
				optp := int(s.set[end])
				if int(s.nd[optp].clr) != c && !s.purgeOption(optp, s.oactive) {
					return false
				}
			}

//line xccdc.w:1083
		} else {

//line xccdc.w:1128
			for ; end >= x; end-- {
				optp := s.optionOf(int(s.set[end]))
				if optp != opt && !s.optOut(optp, s.oactive) {
					return false
				}
			}

//line xccdc.w:1085
		}
	}

//line xccdc.w:1143
	for k := s.active; k < s.oactive; k++ {
		x := int(s.item[k])
		if x < s.second {
			s.setSize(x, 0)
		}
	}
	s.setAge(opt, s.curAge)

//line xccdc.w:1088
	return true
}

//line xccdc.w:1155
func (s *XCCDC) purgeOption(node, act int) bool {
	return s.optOut(s.optionOf(node), act)
}

func (s *XCCDC) optionOf(node int) int {
	for node--; s.nd[node].itm > 0; node-- {
	}
	return node
}

//line xccdc.w:1174
func (s *XCCDC) saveSizes() {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		x := int(s.item[p])
		s.savestack[s.saveptr+p] = twoints{int32(x), int32(s.size(x))}
	}
	s.saveptr += s.active
}

func (s *XCCDC) restoreSizes(mark int) {
	s.active = s.saveptr - mark
	s.saveptr = mark
	for p := 0; p < s.active; p++ {
		e := s.savestack[mark+p]
		s.setSize(int(e.l), int(e.r))
	}
}

//line xccdc.w:1198
func (s *XCCDC) visit(stage int) bool {
	s.count++
	sol := make([]Option, stage)
	for k := 0; k < stage; k++ {
		sol[k] = s.option(int(s.chosen[k]))
	}
	select {
	case <-s.ctx.Done():
		return false
	case s.solStream <- sol:
		return true
	}
}

//line xccdc.w:1216
func (s *XCCDC) tick() {
	if s.pulse == nil {
		return
	}
	select {
	case <-s.pulse.C:
		select {
		case s.heartbeat <- fmt.Sprintf("%d nodes, %d solutions, %d purges so far",
			s.nodes, s.count, s.purges):
		default:
		}
	default:
	}
}

//line xccdc.w:1240
func (s *XCCDC) option(p int) Option {
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

//line xccdc.w:1264
func (s *XCCDC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

//line xccdc.w:1280
func (s *XCCDC) readItemNames(br *bufio.Reader) {

//line xccdc.w:1303
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

//line xccdc.w:1282
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

//line xccdc.w:1323
func (s *XCCDC) readOptions(br *bufio.Reader) {
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

//line xccdc.w:1343
func (s *XCCDC) readOption(buf []byte) {
	spacer := s.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {

//line xccdc.w:1365
		name, next := token(buf, p, true)
		if name == "" {
			failf("empty item name")
		}
		m, known := s.nameIndex[name]
		if !known {
			failf("unknown item name: %s", name)
		}
		at := s.createNode(m, spacer, &hasPrimary)
		if buf[next] == ':' {
			if m < s.second {
				failf("primary item must be uncolored: %s", name)
			}
			color, ce := token(buf, next+1, false)
			if color == "" {
				failf("missing color after %s:", name)
			}
			s.nd[at].clr = int32(s.internColor(color))
			next = ce
		}
		p = skipSpace(buf, next)

//line xccdc.w:1348
	}

	if !hasPrimary {

//line xccdc.w:1391
		for s.lastNode > spacer {
			slot := int(s.nd[s.lastNode+1].itm) * dcIprop
			s.setSize(slot, s.size(slot)-1)
			s.setPos(slot, spacer-1)
			s.lastNode--
		}

//line xccdc.w:1352
		return
	}
	s.nd[spacer].loc = int32(s.lastNode - spacer)
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	s.options++
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
}

//line xccdc.w:1410
func (s *XCCDC) createNode(m, spacer int, hasPrimary *bool) int {
	slot := m * dcIprop
	s.set = ensure(s.set, slot)
	if s.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", s.names[m])
	}
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+2)
	at := s.lastNode
	if !*hasPrimary {
		if m < s.second {
			at, *hasPrimary = spacer+1, true
		} else {
			at = s.lastNode + 1
		}
	}
	t := s.size(slot)
	s.nd[at].itm = int32(m)
	s.nd[at].loc = int32(t)
	s.nd[at].clr = 0
	s.setSize(slot, t+1)
	s.setPos(slot, s.lastNode)
	return at
}

//line xccdc.w:1438
func (s *XCCDC) finalize() {

//line xccdc.w:1449
	s.active, s.itemlen = s.lastItm-1, s.lastItm-1
	s.item = ensure(s.item, s.itemlen)
	s.set = ensure(s.set, s.itemlen*dcIprop+1) // all input slots readable

	j := dcExtra
	k := 0
	for ; k < s.itemlen; k++ {
		s.item[k] = int32(j)
		j += dcExtra + s.size((k+1)*dcIprop)
	}
	s.setlen = j - dcExtra
	s.set = ensure(s.set, j+1)
	if s.second == secondUnset {
		s.osecond, s.second = s.active, j
	} else {
		s.osecond = s.second - 1
	}

//line xccdc.w:1440

//line xccdc.w:1472
	for ; k != 0; k-- {
		base := int(s.item[k-1])
		if k == s.second {
			s.second = base
		}
		s.setSize(base, s.size(k*dcIprop))
		if s.size(base) == 0 && k <= s.osecond {
			s.baditem = k
		}
		s.setPos(base, k-1)
		s.setItemNo(base, k)
		s.setMark(base, 0)
	}

//line xccdc.w:1441

//line xccdc.w:1490
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

//line xccdc.w:1442
}
