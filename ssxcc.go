//line ssxcc.w:31
package dcells

import (
	"bufio"
	"cmp"
	"context"
	"fmt"
	"io"
	"os"
	"slices"
	"strings"
	"time"
)

//line ssxcc.w:144
const primExtra = 4 // 아이템 밑자리 아래에 잡아 두는 set 칸의 수

type twoints struct {
	l, r int32
}

//line ssxcc.w:157
type XCC struct {

//line ssxcc.w:77
	Debug         bool          // 입력 요약과 마무리 통계를 stderr에 찍는다
	PulseInterval time.Duration // 양수이면 이따금 Heartbeat 문자열을 내준다

//line ssxcc.w:694
	Bound func(Frame) int // 앞으로 치를 값의 하한, nil이어도 된다

//line ssxcc.w:699
	Best int // Minimize에서 가장 싼 덮개를 몇 개나 찾을 것인가

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

//line ssxcc.w:84
	names      []string // 아이템 번호(1부터)로 찾는, 가둬 둔 아이템 이름
	nameIndex  map[string]int
	colorNames []string // 색 번호(1부터, 0은 "색 없음")로 찾는, 가둬 둔 색 이름
	colorIndex map[string]int

//line ssxcc.w:163

//line ssxcc.w:94
	force  []int32
	forced int

//line ssxcc.w:164

//line ssxcc.w:185
	choice    []int32
	saved     []int32
	savestack []twoints
	saveptr   int

//line ssxcc.w:165

//line ssxcc.w:706
	minimizing bool
	optNo      []int32     // 노드 -> 그 노드가 속한 옵션
	optCost    []int32     // 옵션 번호 -> 부르는 쪽이 매긴 값
	optTax     []int64     // 옵션 번호 -> 그 값에 든 세금
	itemBase   []int32     // 아이템 번호 -> set 안의 밑자리
	cost       int64       // 이제껏 맡긴 옵션들의 값
	taxDue     int64       // 아직 덮이지 않은 주 아이템들의 세금 합
	podium     []int64     // 이제껏 가장 싼 덮개 Best개의 값, 최대 힙
	byNet      []pricedOpt // 모든 옵션, 순값이 비싼 것부터
	sweptAt    []int32     // 층 -> 그 마디가 byNet의 어디까지 쓸었는가

//line ssxcc.w:166

//line ssxcc.w:98
	updates uint64
	nodes   uint64
	options uint64
	count   uint64

//line ssxcc.w:167

//line ssxcc.w:104
	solStream chan []Option
	heartbeat chan string
	pulse     *time.Ticker

//line ssxcc.w:168
}

//line ssxcc.w:198
func NewXCC() *XCC {
	return &XCC{
		second:     secondUnset,
		names:      []string{""}, // 아이템 번호는 1부터다
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // 색 0은 "색 없음"을 뜻한다
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

//line ssxcc.w:226
func (s *XCC) size(x int) int { return int(s.set[x-1]) }

//line ssxcc.w:227
func (s *XCC) pos(x int) int { return int(s.set[x-2]) }

//line ssxcc.w:228
func (s *XCC) itemNo(x int) int { return int(s.set[x-3]) }

func (s *XCC) setSize(x, v int) { s.set[x-1] = int32(v) }

//line ssxcc.w:231
func (s *XCC) setPos(x, v int) { s.set[x-2] = int32(v) }

//line ssxcc.w:232
func (s *XCC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

//line ssxcc.w:238
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

//line ssxcc.w:263
func (s *XCC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)

//line ssxcc.w:273
	s.solStream = make(chan []Option)
	s.heartbeat = make(chan string)

	go func() {
		defer close(s.solStream)
		defer close(s.heartbeat)

//line ssxcc.w:280

//line ssxcc.w:298
		if s.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
		}

//line ssxcc.w:281
		if s.PulseInterval > 0 {
			s.pulse = time.NewTicker(s.PulseInterval)
			defer s.pulse.Stop()
		}

		if s.baditem == 0 {
			s.search(0)
		}

//line ssxcc.w:290

//line ssxcc.w:305
		if s.Debug {
			plural := "s"
			if s.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				s.count, plural, s.updates, s.nodes)
		}

//line ssxcc.w:291
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}

//line ssxcc.w:266
}

//line ssxcc.w:321
func (s *XCC) search(level int) bool {
	s.nodes++
	select {
	case <-s.ctx.Done():
		return false
	default:
	}
	s.tick()

//line ssxcc.w:837
	if s.minimizing {
		rest := s.taxDue
		if s.Bound != nil {
			rest = max(rest, int64(s.Bound(Frame{s})))
		}
		if s.cost+rest >= s.podium[0] {
			return true
		}
	}

//line ssxcc.w:330

//line ssxcc.w:914
	if s.minimizing {
		budget := s.podium[0] - s.cost - s.taxDue
		p := 0
		if level > 0 {
			p = int(s.sweptAt[level-1])
		}
		for ; p < len(s.byNet) && s.byNet[p].net >= budget; p++ {

//line ssxcc.w:934
			for nn := int(s.byNet[p].node); s.nd[nn].itm > 0; nn++ {
				u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
				if s.pos(u) >= s.active || v >= u+s.size(u) {
					continue // 살아 있지 않은 아이템이거나, 이 옵션이 이미 떠난 집합이다
				}
				ss := s.size(u) - 1
				if ss == 0 && u < s.second {
					return true // 주 아이템에 감당할 수 있는 옵션이 하나도 남지 않았다
				}
				nnp := int(s.set[u+ss])
				s.setSize(u, ss)
				s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
				s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
				s.updates++
			}

//line ssxcc.w:922
		}
		s.sweptAt = ensure(s.sweptAt, level+1)
		s.sweptAt[level] = int32(p)
	}

//line ssxcc.w:332
	best, solution := s.chooseItem()
	if solution {
		return s.visit(level)
	}

//line ssxcc.w:352
	s.swapOut(best)
	s.oactive = s.active
	s.hide(best, 0, 0)
	s.saveSizes(level)
	s.choice = ensure(s.choice, level+1)
	for c := best; c < best+s.size(best); c++ {
		opt := int(s.set[c])
		s.choice[level] = int32(opt)

//line ssxcc.w:851
		price, tax := int64(0), int64(0)
		if s.minimizing {
			o := s.optNo[opt]
			price, tax = int64(s.optCost[o]), s.optTax[o]
		}

//line ssxcc.w:361

//line ssxcc.w:972
		if s.minimizing && s.cost+price+s.taxDue-tax >= s.podium[0] {
			continue
		}

//line ssxcc.w:362
		s.cost += price
		s.taxDue -= tax
		if s.commitOption(opt) {
			if !s.search(level + 1) {
				return false
			}
		}
		s.restoreSizes(level)
		s.cost -= price
		s.taxDue += tax
	}

//line ssxcc.w:337
	return true
}

//line ssxcc.w:386
func (s *XCC) chooseItem() (best int, solution bool) {
	for s.forced != 0 {
		s.forced--
		if f := int(s.force[s.forced]); s.pos(f) < s.active {
			return f, false
		}
	}

//line ssxcc.w:405
	score := infSize
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // 부 아이템에서는 분기하지 않는다
		}
		switch sz := s.size(x); {
		case sz == 0:
			// 닿지 않는다: hide는 살아 있는 주 아이템을 굶기지 않는다
		case sz == 1:
			s.force = ensure(s.force, s.forced+1)
			s.force[s.forced] = int32(x)
			s.forced++
		case sz < score || (sz == score && x < best):
			best, score = x, sz
		}
	}

//line ssxcc.w:394
	if s.forced != 0 {
		s.forced--
		return int(s.force[s.forced]), false
	}
	return best, score == infSize
}

//line ssxcc.w:432
func (s *XCC) commitOption(opt int) bool {

//line ssxcc.w:439
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

//line ssxcc.w:434

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

//line ssxcc.w:435
	return true
}

//line ssxcc.w:494
func (s *XCC) hide(c, color, check int) bool {
	for rr, end := c, c+s.size(c); rr < end; rr++ {
		tt := int(s.set[rr])
		if color != 0 && int(s.nd[tt].clr) == color {
			continue
		}

//line ssxcc.w:510
		for nn := tt + 1; nn != tt; {
			u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
			if u < 0 {
				nn += u
				continue
			}
			if s.pos(u) < s.oactive {
				ss := s.size(u) - 1

//line ssxcc.w:529
				if ss <= 1 && check != 0 && u < s.second && s.pos(u) < s.active {
					if ss == 0 {
						return false
					}
					s.force = ensure(s.force, s.forced+1)
					s.force[s.forced] = int32(u)
					s.forced++
				}

//line ssxcc.w:519
				nnp := int(s.set[u+ss])
				s.setSize(u, ss)
				s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
				s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
				s.updates++
			}
			nn++
		}

//line ssxcc.w:501
	}
	return true
}

//line ssxcc.w:541
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

//line ssxcc.w:562
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

//line ssxcc.w:590
func (s *XCC) visit(level int) bool {
	s.count++
	if s.minimizing {

//line ssxcc.w:862
		h, i := s.podium, 0
		for j := 1; j < len(h); j = 2*i + 1 {
			if j+1 < len(h) && h[j+1] > h[j] {
				j++ // 더 비싼 자식
			}
			if h[j] <= s.cost {
				break
			}
			h[i] = h[j]
			i = j
		}
		h[i] = s.cost

//line ssxcc.w:594
	}
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
		p-- // 옵션의 첫 노드로 옮긴다
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

//line ssxcc.w:736
func (s *XCC) Minimize(rd io.Reader, cost func(o int, opt Option) int) *Result {
	s.inputMatrix(rd)

//line ssxcc.w:751
	s.optNo = make([]int32, s.lastNode+1)
	s.optCost = make([]int32, int(s.options)+1)
	o := int32(0)
	for k := 1; k < s.lastNode; k++ {
		if s.nd[k].itm <= 0 {
			continue // 옵션과 옵션 사이의 사이막
		}
		if s.nd[k-1].itm <= 0 {
			o++
			s.optCost[o] = int32(cost(int(o), s.option(k)))
		}
		s.optNo[k] = o
	}

//line ssxcc.w:771
	s.itemBase = make([]int32, s.itemlen+1)
	for k := 0; k < s.itemlen; k++ {
		base := int(s.item[k])
		s.itemBase[s.itemNo(base)] = int32(base)
	}

//line ssxcc.w:739

//line ssxcc.w:800
	s.optTax = make([]int64, len(s.optCost))
	s.taxDue = 0
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second || s.size(x) == 0 {
			continue // 부 아이템은 세금을 물지 않고, 옵션이 없는 아이템도 그렇다
		}

//line ssxcc.w:816
		t := infCost
		for c := x; c < x+s.size(x); c++ {
			o := s.optNo[int(s.set[c])]
			t = min(t, int64(s.optCost[o])-s.optTax[o])
		}

//line ssxcc.w:808
		for c := x; c < x+s.size(x); c++ {
			s.optTax[s.optNo[int(s.set[c])]] += t
		}
		s.taxDue += t
	}

//line ssxcc.w:740

//line ssxcc.w:955
	s.byNet = s.byNet[:0]
	for k := 1; k < s.lastNode; k++ {
		if s.nd[k].itm > 0 && s.nd[k-1].itm <= 0 {
			o := s.optNo[k]
			s.byNet = append(s.byNet,
				pricedOpt{int32(k), int64(s.optCost[o]) - s.optTax[o]})
		}
	}
	slices.SortStableFunc(s.byNet, func(a, b pricedOpt) int {
		return cmp.Compare(b.net, a.net)
	})

//line ssxcc.w:741

//line ssxcc.w:825
	s.podium = make([]int64, max(s.Best, 1))
	for i := range s.podium {
		s.podium[i] = infCost
	}

//line ssxcc.w:742
	s.minimizing = true

//line ssxcc.w:273
	s.solStream = make(chan []Option)
	s.heartbeat = make(chan string)

	go func() {
		defer close(s.solStream)
		defer close(s.heartbeat)

//line ssxcc.w:280

//line ssxcc.w:298
		if s.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
		}

//line ssxcc.w:281
		if s.PulseInterval > 0 {
			s.pulse = time.NewTicker(s.PulseInterval)
			defer s.pulse.Stop()
		}

		if s.baditem == 0 {
			s.search(0)
		}

//line ssxcc.w:290

//line ssxcc.w:305
		if s.Debug {
			plural := "s"
			if s.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				s.count, plural, s.updates, s.nodes)
		}

//line ssxcc.w:291
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}

//line ssxcc.w:744
}

//line ssxcc.w:1000
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

//line ssxcc.w:1019
func (s *XCC) optionCost(opt int) int { return int(s.optCost[opt]) }

//line ssxcc.w:1020
func (s *XCC) itemName(item int) string { return s.names[item] }

func (s *XCC) itemNeed(item int) int {
	if int(s.itemBase[item]) < s.second {
		return 1
	}
	return 0
}

//line ssxcc.w:1037
func (s *XCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

//line ssxcc.w:1053
func (s *XCC) readItemNames(br *bufio.Reader) {

//line ssxcc.w:1076
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

//line ssxcc.w:1055
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

//line ssxcc.w:1096
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

//line ssxcc.w:1115
func (s *XCC) readOption(buf []byte) {
	spacer := s.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {

//line ssxcc.w:1135
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

//line ssxcc.w:1120
	}

	if !hasPrimary {

//line ssxcc.w:1162
		for s.lastNode > spacer {
			slot := int(s.nd[s.lastNode].itm) << 2
			s.setSize(slot, s.size(slot)-1)
			s.setPos(slot, spacer-1)
			s.lastNode--
		}

//line ssxcc.w:1124
		return
	}
	s.nd[spacer].loc = int32(s.lastNode - spacer)
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	s.options++
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
}

//line ssxcc.w:1174
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

//line ssxcc.w:1195
func (s *XCC) finalize() {

//line ssxcc.w:1206
	s.active, s.itemlen = s.lastItm-1, s.lastItm-1
	s.item = ensure(s.item, s.itemlen)
	s.set = ensure(s.set, (s.itemlen<<2)+1) // 입력 칸을 모두 읽을 수 있게

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

//line ssxcc.w:1197

//line ssxcc.w:1228
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

//line ssxcc.w:1198

//line ssxcc.w:1245
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

//line ssxcc.w:1199
}
