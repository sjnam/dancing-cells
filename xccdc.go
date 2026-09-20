//line xccdc.w:41
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

//line xccdc.w:175
func (s *XCCDC) trigger(opt int) int { return int(s.nd[opt].clr) }

//line xccdc.w:176
func (s *XCCDC) fixit(opt int) int { return int(s.nd[opt].xtra) }

//line xccdc.w:177
func (s *XCCDC) age(opt int) int { return int(s.nd[opt+1].xtra) }

func (s *XCCDC) setTrigger(opt, v int) { s.nd[opt].clr = int32(v) }

//line xccdc.w:180
func (s *XCCDC) setFixit(opt, v int) { s.nd[opt].xtra = int32(v) }

//line xccdc.w:181
func (s *XCCDC) setAge(opt, v int) { s.nd[opt+1].xtra = int32(v) }

//line xccdc.w:189
func (s *XCCDC) getavail() int {
	if p := int(s.pool[0].r); p != 0 {
		s.pool[0].r = s.pool[p].r
		return p // info(p)에 무엇이 있었든 부르는 쪽이 알아서 한다
	}
	s.poolptr++
	s.pool = ensure(s.pool, s.poolptr)
	return s.poolptr - 1
}

func (s *XCCDC) putavail(p int) {
	s.pool[p].r = s.pool[0].r
	s.pool[0].r = int32(p)
}

//line xccdc.w:218
func (s *XCCDC) markItems(opt int) {

//line xccdc.w:234
	if s.compatStamp == maxStamp {
		for k := 0; k < s.itemlen; k++ {
			s.setMark(int(s.item[k]), 0)
		}
		s.compatStamp = 0
	}
	s.compatStamp++

//line xccdc.w:220
	for nn := opt + 1; s.nd[nn].itm > 0; nn++ {
		ii := int(s.nd[nn].itm)
		s.setMark(ii, s.compatStamp)
		if ii >= s.second {
			if c := int(s.nd[nn].clr); c != 0 {
				s.setMatch(ii, c)
			} else {
				s.setMatch(ii, -1) // 색 없는 아이템은 어느 색과도 맞지 않는다
			}
		}
	}
}

//line xccdc.w:251
func (s *XCCDC) compatible(p int) (opt int, ok bool) {
	opt = p
	for nn := p + 1; nn != p; nn++ {
		jj := int(s.nd[nn].itm)
		switch {
		case jj <= 0:
			opt = nn + jj - 1 // 사이막이다. 그 옵션 제 사이막으로 되돌아간다
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

//line xccdc.w:283
func (s *XCCDC) optOut(opt, act int) bool {

//line xccdc.w:317
	for nn := opt + 1; ; nn++ {
		ii := int(s.nd[nn].itm)
		if ii <= 0 {
			break
		}
		p := int(s.nd[nn].loc)
		if p >= s.second && s.pos(ii) >= act {
			continue // 아이템 ii는 이 가지가 열리기 전에 씻겼다
		}
		sz := s.size(ii) - 1
		if sz == 0 && p < s.second {

//line xccdc.w:342
			for s.qfront != s.qrear {
				p := s.qfront
				s.qfront = int(s.pool[p].r)
				waiting := int(s.pool[p].l)
				s.putavail(p)
				s.revertFixits(waiting)
			}
			return false

//line xccdc.w:329
		}
		nnp := int(s.set[ii+sz])
		s.setSize(ii, sz)
		s.set[ii+sz], s.set[p] = int32(nn), int32(nnp)
		s.nd[nn].loc, s.nd[nnp].loc = int32(ii+sz), int32(p)
		s.updates++
	}

//line xccdc.w:285
	s.setAge(opt, s.curAge)
	s.purges++
	tmin, cutoff := infiniteAge, -1
	hintP, hintQ, pp := 0, 0, 0
	for p := s.trigger(opt); p != 0; p = pp {
		q := int(s.pool[p].r)
		optp, ii := int(s.pool[p].l), int(s.pool[q].l)
		pp = int(s.pool[q].r)
		if optp < 0 {

//line xccdc.w:944
			c := -optp - 1
			if c < s.curAge && ii == int(s.stageStamp[(c+1)>>1]) {
				hintP, hintQ, cutoff = p, q, c
				break // 이 아래는 모두 살아 있지 않음이 알려져 있다
			}
			s.putavail(p) // 이 귀띔은 철이 지났다
			s.putavail(q)
			continue

//line xccdc.w:295
		}

//line xccdc.w:376
		t, dead := -1, false
		if a := s.age(optp); a <= s.curAge {
			jj := int(s.nd[optp+1].itm) // optp의 첫 아이템, 언제나 주 아이템이다
			if int(s.nd[optp+1].loc) >= jj+s.size(jj) {
				t, dead = a, true
			}
		}
		if !dead && s.pos(ii) >= s.active {
			t, dead = s.curAge, true
		}

//line xccdc.w:297
		if !dead {

//line xccdc.w:392
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

//line xccdc.w:299
			continue
		}
		if t < 0 {
			s.putavail(p) // 이만큼 어린 옵션은 영영 돌아오지 않는다
			s.putavail(q)
			continue
		}

//line xccdc.w:404
		if s.trigHead[t] == 0 {
			s.trigTail[t] = int32(q)
		}
		s.pool[q].r = s.trigHead[t]
		s.trigHead[t] = int32(p)
		if t < tmin {
			tmin = t
		}

//line xccdc.w:307
	}

//line xccdc.w:959
	pp = 0
	if hintP != 0 {
		pp = hintP
		if tmin <= cutoff {
			pp = int(s.pool[hintQ].r) // 바구니들이 이 귀띔을 품는다
			s.putavail(hintP)
			s.putavail(hintQ)
		}
	}
	for t := tmin; t < s.curAge; t++ {
		if s.trigHead[t] == 0 {
			continue
		}
		s.pool[int(s.trigTail[t])].r = int32(pp)

//line xccdc.w:986
		p := s.getavail()
		q := s.getavail()
		s.pool[p].l = int32(-t - 1)
		s.pool[p].r = int32(q)
		s.pool[q].l = s.stageStamp[(t+1)>>1]
		s.pool[q].r = s.trigHead[t]
		pp = p

//line xccdc.w:974
		s.trigHead[t] = 0
	}
	if s.curAge >= 0 && s.trigHead[s.curAge] != 0 {
		s.pool[int(s.trigTail[s.curAge])].r = int32(pp)
		pp = int(s.trigHead[s.curAge])
		s.trigHead[s.curAge] = 0
	}
	s.setTrigger(opt, pp)

//line xccdc.w:309
	return true
}

//line xccdc.w:354
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

//line xccdc.w:419
func (s *XCCDC) emptyQueue() bool {
	for s.qfront != s.qrear {
		p := s.qfront
		opt := int(s.pool[p].l)
		s.qfront = int(s.pool[p].r)
		s.putavail(p)
		if s.age(opt) != infiniteAge {
			s.revertFixits(opt) // 그사이에 opt 자신이 솎였다
			continue
		}
		s.markItems(opt)

//line xccdc.w:436
		var pp int
		for p := s.fixit(opt); p != 0; p = pp {
			q := int(s.pool[p].r)
			ii := int(s.pool[q].l) // opt에 없는 주 아이템
			pp = int(s.pool[q].r)
			found := false
			for c, end := ii, ii+s.size(ii); c < end; c++ {
				if optp, ok := s.compatible(int(s.set[c])); ok {

//line xccdc.w:459
					s.pool[p].l = int32(opt)
					s.pool[q].r = int32(s.trigger(optp))
					s.setTrigger(optp, p)

//line xccdc.w:445
					found = true
					break
				}
			}
			if !found {

//line xccdc.w:467
				s.setFixit(opt, p)
				s.revertFixits(opt)
				if !s.optOut(opt, s.active) {
					return false
				}

//line xccdc.w:451
				break
			}
		}
		s.setFixit(opt, 0)

//line xccdc.w:431
	}
	return true
}

//line xccdc.w:480
func (s *XCCDC) establishDC() bool {
	s.curAge = -1
	s.qfront = s.getavail()
	s.qrear = s.qfront
	for opt := 0; opt < s.lastNode; opt += int(s.nd[opt].loc) + 1 {
		s.markItems(opt)

//line xccdc.w:496
		for k := 0; k < s.osecond; k++ {
			ii := int(s.item[k])
			if s.mark(ii) == s.compatStamp {
				continue // ii는 opt 안에 있으니 증인이 필요 없다
			}
			found := false
			for c, end := ii, ii+s.size(ii); c < end; c++ {
				if optp, ok := s.compatible(int(s.set[c])); ok {
					p := s.getavail()
					q := s.getavail()
					s.pool[p].r = int32(q)
					s.pool[q].l = int32(ii)

//line xccdc.w:459
					s.pool[p].l = int32(opt)
					s.pool[q].r = int32(s.trigger(optp))
					s.setTrigger(optp, p)

//line xccdc.w:509
					found = true
					break
				}
			}
			if !found {
				if !s.optOut(opt, s.active) {
					return false
				}
				break // opt는 사라졌다. 다음 것으로 간다
			}
		}

//line xccdc.w:487
	}
	return s.emptyQueue()
}

//line xccdc.w:589
const (
	dcExtra     = 5       // 아이템 밑자리 아래에 맡아 두는 set 칸
	dcIprop     = 5       // 입력 단계의 자리 간격
	infiniteAge = 1 << 29 // 솎인 옵션이 가질 수 없는 나이
	maxStamp    = 1<<31 - 1

//line xccdc.w:594
)

type dcnode struct {
	itm, loc, clr, xtra int32 // itm과 clr은 입력 뒤 굳고, loc이 춤춘다
}

//line xccdc.w:621
type XCCDC struct {

//line xccdc.w:87
	Debug         bool          // 입력 요약과 마무리 통계를 stderr에 찍는다
	PulseInterval time.Duration // 양수이면 이따금 Heartbeat 문자열을 내준다

//line xccdc.w:623
	ctx context.Context

//line xccdc.w:625

//line xccdc.w:634
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

//line xccdc.w:626

//line xccdc.w:94
	names      []string // 아이템 번호(1부터)로 찾는, 가둬 둔 아이템 이름
	nameIndex  map[string]int
	colorNames []string // 색 번호(1부터, 0은 "색 없음")로 찾는, 가둬 둔 색 이름
	colorIndex map[string]int

//line xccdc.w:627

//line xccdc.w:652
	pool         []twoints // info는 .l, link는 .r. 0번 칸이 빈 목록의 머리다
	poolptr      int
	qfront       int
	qrear        int
	trigHead     []int32 // 나이로 찾는 바구니, 목록을 다시 지을 때 쓴다
	trigTail     []int32
	compatStamp  int
	curStamp     int32
	biggestStamp int32

//line xccdc.w:628

//line xccdc.w:668
	chosen     []int32
	stageStamp []int32
	savestack  []twoints
	saveptr    int
	curAge     int

//line xccdc.w:629

//line xccdc.w:103
	updates uint64
	nodes   uint64
	purges  uint64
	options uint64
	count   uint64

//line xccdc.w:630

//line xccdc.w:110
	solStream chan []Option
	heartbeat chan string
	pulse     *time.Ticker

//line xccdc.w:631
}

//line xccdc.w:681
func NewXCCDC() *XCCDC {
	return &XCCDC{
		second:     secondUnset,
		names:      []string{""}, // 아이템 번호는 1부터다
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // 0번 색은 "색 없음"이다
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

//line xccdc.w:704
func (s *XCCDC) Nodes() uint64 { return s.nodes }

//line xccdc.w:705
func (s *XCCDC) Purges() uint64 { return s.purges }

//line xccdc.w:711
func (s *XCCDC) size(x int) int { return int(s.set[x-1]) }

//line xccdc.w:712
func (s *XCCDC) pos(x int) int { return int(s.set[x-2]) }

//line xccdc.w:713
func (s *XCCDC) itemNo(x int) int { return int(s.set[x-3]) }

//line xccdc.w:714
func (s *XCCDC) mark(x int) int { return int(s.set[x-4]) }

//line xccdc.w:715
func (s *XCCDC) match(x int) int { return int(s.set[x-5]) }

func (s *XCCDC) setSize(x, v int) { s.set[x-1] = int32(v) }

//line xccdc.w:718
func (s *XCCDC) setPos(x, v int) { s.set[x-2] = int32(v) }

//line xccdc.w:719
func (s *XCCDC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

//line xccdc.w:720
func (s *XCCDC) setMark(x, v int) { s.set[x-4] = int32(v) }

//line xccdc.w:721
func (s *XCCDC) setMatch(x, v int) { s.set[x-5] = int32(v) }

//line xccdc.w:728
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

//line xccdc.w:754
func (s *XCCDC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)
	s.solStream = make(chan []Option)
	s.heartbeat = make(chan string)

	go func() {
		defer close(s.solStream)
		defer close(s.heartbeat)

//line xccdc.w:763

//line xccdc.w:790
		if s.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
		}

//line xccdc.w:764
		if s.PulseInterval > 0 {
			s.pulse = time.NewTicker(s.PulseInterval)
			defer s.pulse.Stop()
		}

//line xccdc.w:779
		if s.baditem == 0 && s.establishDC() {

//line xccdc.w:524
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

//line xccdc.w:781

//line xccdc.w:797
			if s.Debug {
				fmt.Fprintf(os.Stderr, "Domain consistency purged %d of %d options.\n",
					s.purges, s.options)
			}

//line xccdc.w:782
			s.search(0)
		}

//line xccdc.w:769

//line xccdc.w:803
		if s.Debug {
			plural := "s"
			if s.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr,
				"Altogether %d solution%s, %d updates, %d nodes, %d purges.\n",
				s.count, plural, s.updates, s.nodes, s.purges)
		}

//line xccdc.w:770
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}
}

//line xccdc.w:822
func (s *XCCDC) search(stage int) bool {

//line xccdc.w:858
	s.stageStamp = ensure(s.stageStamp, stage+1)
	s.trigHead = ensure(s.trigHead, 2*stage+2)
	s.trigTail = ensure(s.trigTail, 2*stage+2)

//line xccdc.w:1001
	s.biggestStamp++
	if s.biggestStamp == maxStamp {

//line xccdc.w:1015
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

//line xccdc.w:1004
		for k := 0; k < stage; k++ {
			s.stageStamp[k] = int32(k)
		}
		s.biggestStamp = int32(stage)
	}
	s.curStamp = s.biggestStamp

//line xccdc.w:862
	s.stageStamp[stage] = s.curStamp

//line xccdc.w:824
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

//line xccdc.w:869
		s.curAge = stage + stage + 1
		if s.includeOption(opt) && s.emptyQueue() {
			if !s.search(stage + 1) {
				return false
			}
		}

//line xccdc.w:845
		if t == 1 {
			return true // 고를 것이 없었으니 달리 갈 길도 없다
		}

//line xccdc.w:881
		s.restoreSizes(mark)
		s.curAge = stage + stage
		if !s.purgeOption(opt, s.active) || !s.emptyQueue() {
			return true
		}

//line xccdc.w:849
	}
}

//line xccdc.w:893
func (s *XCCDC) chooseItem() (best, score int) {
	score = infSize
	for k := 0; score > 1 && k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // 부 아이템에서는 분기하지 않는다
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

//line xccdc.w:1035
func (s *XCCDC) includeOption(node int) bool {
	opt := s.optionOf(node)

//line xccdc.w:1055
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

//line xccdc.w:1038
	for k := s.active; k < s.oactive; k++ {
		x := int(s.item[k])
		end := x + s.size(x) - 1
		if x >= s.second && s.match(x) != 0 {

//line xccdc.w:1078
			c := s.match(x)
			for ; end >= x; end-- {
				optp := int(s.set[end])
				if int(s.nd[optp].clr) != c && !s.purgeOption(optp, s.oactive) {
					return false
				}
			}

//line xccdc.w:1043
		} else {

//line xccdc.w:1087
			for ; end >= x; end-- {
				optp := s.optionOf(int(s.set[end]))
				if optp != opt && !s.optOut(optp, s.oactive) {
					return false
				}
			}

//line xccdc.w:1045
		}
	}

//line xccdc.w:1101
	for k := s.active; k < s.oactive; k++ {
		x := int(s.item[k])
		if x < s.second {
			s.setSize(x, 0)
		}
	}
	s.setAge(opt, s.curAge)

//line xccdc.w:1048
	return true
}

//line xccdc.w:1113
func (s *XCCDC) purgeOption(node, act int) bool {
	return s.optOut(s.optionOf(node), act)
}

func (s *XCCDC) optionOf(node int) int {
	for node--; s.nd[node].itm > 0; node-- {
	}
	return node
}

//line xccdc.w:1132
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

//line xccdc.w:1155
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

//line xccdc.w:1173
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

//line xccdc.w:1195
func (s *XCCDC) option(p int) Option {
	for s.nd[p-1].itm > 0 {
		p-- // 옵션의 첫 노드로 간다
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

//line xccdc.w:1218
func (s *XCCDC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

//line xccdc.w:1234
func (s *XCCDC) readItemNames(br *bufio.Reader) {

//line xccdc.w:1257
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

//line xccdc.w:1236
	for buf[p] != 0 {
		name, next := token(buf, p, false)
		if name == "|" {
			if s.second != secondUnset {
				failf("item name line contains | twice")
			}
			s.second = len(s.names) // 다음 아이템의 번호
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
	s.lastItm = len(s.names) // 아이템 수 + 1 (names[0]은 쓰지 않는다)
}

//line xccdc.w:1277
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

//line xccdc.w:1296
func (s *XCCDC) readOption(buf []byte) {
	spacer := s.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {

//line xccdc.w:1318
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

//line xccdc.w:1301
	}

	if !hasPrimary {

//line xccdc.w:1344
		for s.lastNode > spacer {
			slot := int(s.nd[s.lastNode+1].itm) * dcIprop
			s.setSize(slot, s.size(slot)-1)
			s.setPos(slot, spacer-1)
			s.lastNode--
		}

//line xccdc.w:1305
		return
	}
	s.nd[spacer].loc = int32(s.lastNode - spacer)
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	s.options++
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
}

//line xccdc.w:1362
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

//line xccdc.w:1389
func (s *XCCDC) finalize() {

//line xccdc.w:1400
	s.active, s.itemlen = s.lastItm-1, s.lastItm-1
	s.item = ensure(s.item, s.itemlen)
	s.set = ensure(s.set, s.itemlen*dcIprop+1) // 입력 자리를 모두 읽을 수 있게

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

//line xccdc.w:1391

//line xccdc.w:1422
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

//line xccdc.w:1392

//line xccdc.w:1440
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

//line xccdc.w:1393
}
