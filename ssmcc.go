//line ssmcc.w:27
package dcells

import (
	"bufio"
	"cmp"
	"context"
	"fmt"
	"io"
	"os"
	"slices"
	"strconv"
	"strings"
	"time"
)

//line ssmcc.w:151
const (
	mccExtra = 5 // 아이템 밑자리 아래의 set 칸: size, pos, itemNo, slack, bound
	mccIprop = 5 // 입력 단계의 자리 간격
)

type threeints struct{ l, s, b int32 }

//line ssmcc.w:163
type MCC struct {

//line ssmcc.w:75
	Debug         bool          // 입력 요약과 마무리 통계를 stderr에 찍는다
	PulseInterval time.Duration // 양수이면 이따금 Heartbeat 문자열을 내준다

//line ssmcc.w:749
	Bound func(Frame) int // 앞으로 치를 값의 하한, nil이어도 된다

//line ssmcc.w:754
	Best int // Minimize에서 가장 싼 덮개를 몇 개나 찾을 것인가

//line ssmcc.w:165
	ctx context.Context

//line ssmcc.w:167

//line ssmcc.w:177
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

//line ssmcc.w:168

//line ssmcc.w:82
	names      []string // 아이템 번호(1부터)로 찾는, 가둬 둔 아이템 이름
	nameIndex  map[string]int
	colorNames []string // 색 번호(1부터, 0은 "색 없음")로 찾는, 가둬 둔 색 이름
	colorIndex map[string]int

//line ssmcc.w:169

//line ssmcc.w:92
	force  []int32
	forced int

//line ssmcc.w:170

//line ssmcc.w:190
	included  []int32 // 단계마다 들인 옵션, 해를 내놓을 때 쓴다
	savestack []threeints
	saveptr   int

//line ssmcc.w:171

//line ssmcc.w:763
	minimizing bool
	optNo      []int32     // 노드 -> 그 노드가 속한 옵션
	optCost    []int32     // 옵션 번호 -> 부르는 쪽이 매긴 값
	optTax     []int64     // 옵션 번호 -> 그 값에 든 세금
	itemBase   []int32     // 아이템 번호 -> set 안의 밑자리
	cost       int64       // 이제껏 들인 옵션들의 값
	taxDue     int64       // 앞으로 올 덮기가 아직 물어야 할 세금
	podium     []int64     // 이제껏 가장 싼 덮개 Best개의 값, 최대 힙
	byNet      []pricedOpt // 모든 옵션, 순값이 비싼 것부터
	swept      int         // 지금 마디가 byNet의 어디까지 쓸었는가

//line ssmcc.w:172

//line ssmcc.w:96
	updates uint64
	nodes   uint64
	options uint64
	count   uint64

//line ssmcc.w:173

//line ssmcc.w:102
	solStream chan []Option
	heartbeat chan string
	pulse     *time.Ticker

//line ssmcc.w:174
}

//line ssmcc.w:196
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

func (m *MCC) WithContext(ctx context.Context) *MCC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *m
	c.ctx = ctx
	return &c
}

func (m *MCC) Updates() uint64 { return m.updates }

//line ssmcc.w:217
func (m *MCC) Nodes() uint64 { return m.nodes }

//line ssmcc.w:221
func (m *MCC) size(x int) int { return int(m.set[x-1]) }

//line ssmcc.w:222
func (m *MCC) pos(x int) int { return int(m.set[x-2]) }

//line ssmcc.w:223
func (m *MCC) itemNo(x int) int { return int(m.set[x-3]) }

//line ssmcc.w:224
func (m *MCC) slack(x int) int { return int(m.set[x-4]) }

//line ssmcc.w:225
func (m *MCC) bound(x int) int { return int(m.set[x-5]) }

func (m *MCC) setSize(x, v int) { m.set[x-1] = int32(v) }

//line ssmcc.w:228
func (m *MCC) setPos(x, v int) { m.set[x-2] = int32(v) }

//line ssmcc.w:229
func (m *MCC) setItemNo(x, v int) { m.set[x-3] = int32(v) }

//line ssmcc.w:230
func (m *MCC) setSlack(x, v int) { m.set[x-4] = int32(v) }

//line ssmcc.w:231
func (m *MCC) setBound(x, v int) { m.set[x-5] = int32(v) }

//line ssmcc.w:236
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

//line ssmcc.w:259
func (m *MCC) Dance(rd io.Reader) *Result {
	m.inputMatrix(rd)

//line ssmcc.w:267
	m.solStream = make(chan []Option)
	m.heartbeat = make(chan string)

	go func() {
		defer close(m.solStream)
		defer close(m.heartbeat)

//line ssmcc.w:274

//line ssmcc.w:290
		if m.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
		}

//line ssmcc.w:275
		if m.PulseInterval > 0 {
			m.pulse = time.NewTicker(m.PulseInterval)
			defer m.pulse.Stop()
		}

		if m.baditem == 0 {
			m.search(0)
		}

//line ssmcc.w:284

//line ssmcc.w:297
		if m.Debug {
			plural := "s"
			if m.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				m.count, plural, m.updates, m.nodes)
		}

//line ssmcc.w:285
	}()

	return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}

//line ssmcc.w:262
}

//line ssmcc.w:322
func (m *MCC) search(stage int) bool {
	m.nodes++
	select {
	case <-m.ctx.Done():
		return false
	default:
	}
	m.tick()

//line ssmcc.w:331

//line ssmcc.w:349
	for m.forced != 0 {
		m.forced--
		if bi := int(m.force[m.forced]); m.pos(bi) < m.active {
			return m.forcedMove(stage, bi)
		}
	}

//line ssmcc.w:332

//line ssmcc.w:951
	if m.minimizing {
		rest := m.taxDue
		if m.Bound != nil {
			rest = max(rest, int64(m.Bound(Frame{m})))
		}
		if m.cost+rest >= m.podium[0] {
			return true
		}
	}

//line ssmcc.w:333

//line ssmcc.w:920
	if m.minimizing {
		budget := m.podium[0] - m.cost - m.taxDue
		for ; m.swept < len(m.byNet) && m.byNet[m.swept].net >= budget; m.swept++ {

//line ssmcc.w:928
			for cur := int(m.byNet[m.swept].node); m.nd[cur].itm > 0; cur++ {
				ii, p := int(m.nd[cur].itm), int(m.nd[cur].loc)
				if m.pos(ii) >= m.active || p >= ii+m.size(ii) {
					continue // 살아 있지 않은 아이템이거나, 이 옵션이 이미 떠난 집합이다
				}
				ss := m.size(ii) - 1
				if ii < m.second && ss < m.bound(ii)-m.slack(ii) {
					return true // 이 아이템은 더는 넉넉히 덮일 수 없다
				}

//line ssmcc.w:541
				nnp := int(m.set[ii+ss])
				m.setSize(ii, ss)
				m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
				m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
				m.updates++

//line ssmcc.w:938
				if ss == 0 {
					m.deactivate(ii) // 집합에 남은 것이 없다
				}
			}

//line ssmcc.w:924
		}
	}

//line ssmcc.w:335
	best, score := m.chooseBest()
	if m.forced != 0 {
		m.forced--
		return m.forcedMove(stage, int(m.force[m.forced]))
	}
	if score == infSize {
		return m.visit(stage)
	}

//line ssmcc.w:363
	mark, swept := m.saveState(), m.swept
	opt := int(m.set[best])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)

//line ssmcc.w:964
	price, tax := int64(0), int64(0)
	if m.minimizing {
		o := m.optNo[opt]
		price, tax = int64(m.optCost[o]), m.optTax[o]
	}

//line ssmcc.w:369
	m.cost += price
	m.taxDue -= tax
	if m.includeOption(opt) {
		if !m.search(stage + 1) {
			m.saveptr = mark
			return false
		}
	}
	m.cost -= price
	m.taxDue += tax
	m.swept = swept
	if score != 1 {
		m.restoreState(mark)
		if m.removeOption(opt) {
			if !m.search(stage) {
				m.saveptr = mark
				return false
			}
		}
	}
	m.saveptr = mark

//line ssmcc.w:344
	return true
}

//line ssmcc.w:398
func (m *MCC) forcedMove(stage, bi int) bool {
	opt := int(m.set[bi])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)

//line ssmcc.w:964
	price, tax := int64(0), int64(0)
	if m.minimizing {
		o := m.optNo[opt]
		price, tax = int64(m.optCost[o]), m.optTax[o]
	}

//line ssmcc.w:403
	m.cost += price
	m.taxDue -= tax
	ok := true
	if m.includeOption(opt) {
		ok = m.search(stage + 1)
	}
	m.cost -= price
	m.taxDue += tax
	return ok
}

//line ssmcc.w:421
func (m *MCC) chooseBest() (best, score int) {
	score = infSize
	bestS, bestL := 0, 0
	for k := 0; k < m.active; k++ {
		x := int(m.item[k])
		if x >= m.second {
			continue
		}
		s := m.slack(x)
		if b := m.bound(x); s > b {
			s = b
		}
		t := m.size(x) + s - m.bound(x) + 1
		switch {
		case t == 1:
			for i := m.bound(x) - m.slack(x); i > 0; i-- {
				m.force = ensure(m.force, m.forced+1)
				m.force[m.forced] = int32(x)
				m.forced++
			}
		case t <= score && (t < score || (s <= bestS && (s < bestS ||
			(m.size(x) >= bestL && (m.size(x) > bestL || x < best))))):
			score, best, bestS, bestL = t, x, s, m.size(x)
		}
	}
	return best, score
}

//line ssmcc.w:456
func (m *MCC) includeOption(opt int) bool {
	for m.nd[opt-1].itm > 0 {
		opt--
	}
	for ; ; opt++ {
		ii := int(m.nd[opt].itm)
		if ii <= 0 {
			break
		}
		pp := int(m.nd[opt].loc)
		if m.pos(ii) >= m.active {
			if ii >= m.second {
				continue // 이미 씻긴 부 아이템
			}
			return false // 성한 살아 있는 옵션이라면 일어날 수 없다
		}
		if !m.coverOrCommit(ii, opt, pp) {
			return false
		}
	}
	return true
}

//line ssmcc.w:485
func (m *MCC) coverOrCommit(ii, cur, p int) bool {
	if ii < m.second {
		m.setBound(ii, m.bound(ii)-1)
	}
	if ii >= m.second || m.bound(ii) == 0 {

//line ssmcc.w:503
		ss := m.size(ii)
		c := 0
		if ii >= m.second {
			c = int(m.nd[cur].clr)
		}
		for s := ii + ss - 1; s >= ii; s-- {
			if s == p {
				continue
			}
			optp := int(m.set[s])
			if c == 0 || int(m.nd[optp].clr) != c {
				if !m.removeFromOtherSets(optp) {
					return false
				}
			}
		}
		m.deactivate(ii)

//line ssmcc.w:491
	} else {

//line ssmcc.w:526
		ss := m.size(ii) - 1
		if ss < m.bound(ii)-m.slack(ii) {
			m.forced = 0
			return false // 아이템 ii가 지워질 참이다
		}
		if ss == 0 {
			m.deactivate(ii)
		} else {

//line ssmcc.w:541
			nnp := int(m.set[ii+ss])
			m.setSize(ii, ss)
			m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
			m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
			m.updates++

//line ssmcc.w:535
		}

//line ssmcc.w:493
	}
	return true
}

//line ssmcc.w:551
func (m *MCC) removeFromOtherSets(optp int) bool {
	cur := optp
	for m.nd[cur-1].itm > 0 {
		cur--
	}
	for ; ; cur++ {
		ii := int(m.nd[cur].itm)
		if ii <= 0 {
			break
		}
		p := int(m.nd[cur].loc)
		if p >= m.second && m.pos(ii) >= m.active {
			continue
		}
		ss := m.size(ii) - 1
		if p < m.second {
			if ss < m.bound(ii)-m.slack(ii) {
				m.forced = 0
				return false
			}
			if ss == 0 {
				m.deactivate(ii)
			}
		}
		if ss > 0 {

//line ssmcc.w:541
			nnp := int(m.set[ii+ss])
			m.setSize(ii, ss)
			m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
			m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
			m.updates++

//line ssmcc.w:577
		}
	}
	return true
}

//line ssmcc.w:587
func (m *MCC) removeOption(cur int) bool {
	for m.nd[cur-1].itm > 0 {
		cur--
	}
	for ; ; cur++ {
		ii := int(m.nd[cur].itm)
		if ii <= 0 {
			break
		}
		p := int(m.nd[cur].loc)
		if p >= m.second && m.pos(ii) >= m.active {
			continue
		}
		ss := m.size(ii) - 1
		if p < m.second {
			if ss < m.bound(ii)-m.slack(ii) {
				return false
			}
			if ss == 0 {
				m.deactivate(ii)
			}
		}
		if ss > 0 {

//line ssmcc.w:541
			nnp := int(m.set[ii+ss])
			m.setSize(ii, ss)
			m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
			m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
			m.updates++

//line ssmcc.w:611
		}
	}
	return true
}

//line ssmcc.w:619
func (m *MCC) deactivate(ii int) {
	m.active--
	p := m.pos(ii)
	iii := int(m.item[m.active])
	m.item[m.active], m.item[p] = int32(ii), int32(iii)
	m.setPos(ii, m.active)
	m.setPos(iii, p)
}

//line ssmcc.w:633
func (m *MCC) saveState() int {
	mark := m.saveptr
	m.savestack = ensure(m.savestack, m.saveptr+m.active)
	for p := 0; p < m.active; p++ {
		x := int(m.item[p])
		e := threeints{l: int32(x), s: int32(m.size(x))}
		if x < m.second {
			e.b = int32(m.bound(x))
		}
		m.savestack[m.saveptr] = e
		m.saveptr++
	}
	return mark
}

func (m *MCC) restoreState(mark int) {
	m.active = m.saveptr - mark
	for p := 0; p < m.active; p++ {
		e := m.savestack[mark+p]
		m.setSize(int(e.l), int(e.s))
		if int(e.l) < m.second {
			m.setBound(int(e.l), int(e.b))
		}
	}
	m.saveptr = mark
}

//line ssmcc.w:664
func (m *MCC) visit(stage int) bool {
	m.count++
	if m.minimizing {

//line ssmcc.w:973
		h, i := m.podium, 0
		for j := 1; j < len(h); j = 2*i + 1 {
			if j+1 < len(h) && h[j+1] > h[j] {
				j++ // 더 비싼 자식
			}
			if h[j] <= m.cost {
				break
			}
			h[i] = h[j]
			i = j
		}
		h[i] = m.cost

//line ssmcc.w:668
	}
	sol := make([]Option, stage)
	for k := 0; k < stage; k++ {
		sol[k] = m.option(int(m.included[k]))
	}
	select {
	case <-m.ctx.Done():
		return false
	case m.solStream <- sol:
		return true
	}
}

//line ssmcc.w:682
func (m *MCC) tick() {
	if m.pulse == nil {
		return
	}
	select {
	case <-m.pulse.C:
		select {
		case m.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", m.nodes, m.count):
		default:
		}
	default:
	}
}

//line ssmcc.w:697
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

//line ssmcc.w:784
func (m *MCC) Minimize(rd io.Reader, cost func(o int, opt Option) int) *Result {
	m.inputMatrix(rd)

//line ssmcc.w:800
	m.optNo = make([]int32, m.lastNode+1)
	m.optCost = make([]int32, int(m.options)+1)
	o := int32(0)
	for k := 1; k < m.lastNode; k++ {
		if m.nd[k].itm <= 0 {
			continue // 옵션과 옵션 사이의 사이막
		}
		if m.nd[k-1].itm <= 0 {
			o++
			m.optCost[o] = int32(cost(int(o), m.option(k)))
		}
		m.optNo[k] = o
	}

//line ssmcc.w:820
	m.itemBase = make([]int32, m.itemlen+1)
	for k := 0; k < m.itemlen; k++ {
		base := int(m.item[k])
		m.itemBase[m.itemNo(base)] = int32(base)
	}

//line ssmcc.w:787

//line ssmcc.w:841
	m.optTax = make([]int64, len(m.optCost))
	m.taxDue = 0
	for k := 0; k < m.active; k++ {
		x := int(m.item[k])
		if x >= m.second || m.slack(x) != 0 || m.size(x) == 0 {
			continue
		}

//line ssmcc.w:856
		t := infCost
		for c := x; c < x+m.size(x); c++ {
			o := m.optNo[int(m.set[c])]
			t = min(t, int64(m.optCost[o])-m.optTax[o])
		}

//line ssmcc.w:849
		for c := x; c < x+m.size(x); c++ {
			m.optTax[m.optNo[int(m.set[c])]] += t
		}
		m.taxDue += t * int64(m.bound(x))
	}

//line ssmcc.w:788

//line ssmcc.w:868
	for o := 1; o < len(m.optCost); o++ {
		if net := int64(m.optCost[o]) - m.optTax[o]; net < 0 {
			panic(fmt.Sprintf("dcells: option %d has negative net cost %d; "+
				"no item of fixed multiplicity absorbs it", o, net))
		}
	}

//line ssmcc.w:789

//line ssmcc.w:884
	m.byNet = m.byNet[:0]
	for k := 1; k < m.lastNode; k++ {
		if m.nd[k].itm > 0 && m.nd[k-1].itm <= 0 {
			o := m.optNo[k]
			m.byNet = append(m.byNet,
				pricedOpt{int32(k), int64(m.optCost[o]) - m.optTax[o]})
		}
	}
	slices.SortStableFunc(m.byNet, func(a, b pricedOpt) int {
		return cmp.Compare(b.net, a.net)
	})

//line ssmcc.w:790

//line ssmcc.w:876
	m.podium = make([]int64, max(m.Best, 1))
	for i := range m.podium {
		m.podium[i] = infCost
	}
	m.swept = 0

//line ssmcc.w:791
	m.minimizing = true

//line ssmcc.w:267
	m.solStream = make(chan []Option)
	m.heartbeat = make(chan string)

	go func() {
		defer close(m.solStream)
		defer close(m.heartbeat)

//line ssmcc.w:274

//line ssmcc.w:290
		if m.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
		}

//line ssmcc.w:275
		if m.PulseInterval > 0 {
			m.pulse = time.NewTicker(m.PulseInterval)
			defer m.pulse.Stop()
		}

		if m.baditem == 0 {
			m.search(0)
		}

//line ssmcc.w:284

//line ssmcc.w:297
		if m.Debug {
			plural := "s"
			if m.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				m.count, plural, m.updates, m.nodes)
		}

//line ssmcc.w:285
	}()

	return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}

//line ssmcc.w:793
}

//line ssmcc.w:990
func (m *MCC) eachLive(yield func(item, opt int) bool) {
	for k := 0; k < m.active; k++ {
		x := int(m.item[k])
		if x >= m.second {
			continue
		}
		i := m.itemNo(x)
		for c := x; c < x+m.size(x); c++ {
			if !yield(i, int(m.optNo[int(m.set[c])])) {
				return
			}
		}
	}
}

//line ssmcc.w:1011
func (m *MCC) optionCost(opt int) int { return int(m.optCost[opt]) }

//line ssmcc.w:1012
func (m *MCC) itemName(item int) string { return m.names[item] }

func (m *MCC) itemNeed(item int) int {
	x := int(m.itemBase[item])
	if x >= m.second {
		return 0
	}
	return max(m.bound(x)-m.slack(x), 0)
}

//line ssmcc.w:1029
func (m *MCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	m.readItemNames(br)
	m.readOptions(br)
}

//line ssmcc.w:1045
func mustAtoi(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		failf("illegal number in bound spec: %q", s)
	}
	return n
}

func parseItemSpec(tok string, inSecondary bool) (name string, lower, upper int) {
	if i := strings.IndexByte(tok, '|'); i >= 0 {

//line ssmcc.w:1069
		if inSecondary {
			failf("secondary item cannot have a multiplicity: %q", tok)
		}
		spec, nm := tok[:i], tok[i+1:]
		if j := strings.IndexByte(spec, ':'); j >= 0 {
			lower, upper = mustAtoi(spec[:j]), mustAtoi(spec[j+1:])
		} else {
			upper = mustAtoi(spec)
			lower = upper
		}
		if upper == 0 {
			failf("upper bound is zero: %q", tok)
		}
		if lower > upper {
			failf("lower bound exceeds upper bound: %q", tok)
		}
		name = nm

//line ssmcc.w:1056
	} else {
		name, lower, upper = tok, 1, 1
	}
	if name == "" {
		failf("item name empty: %q", tok)
	}
	if strings.ContainsAny(name, ":|") {
		failf("illegal character in item name: %q", name)
	}
	return
}

//line ssmcc.w:1091
func (m *MCC) readItemNames(br *bufio.Reader) {

//line ssmcc.w:1117
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

//line ssmcc.w:1093
	for buf[p] != 0 {
		tok, next := token(buf, p, false)
		if tok == "|" {
			if m.second != secondUnset {
				failf("item name line contains | twice")
			}
			m.second = len(m.names) // 다음 아이템의 번호
		} else {
			name, lower, upper := parseItemSpec(tok, m.second != secondUnset)
			num, ok := m.internName(name)
			if !ok {
				failf("duplicate item name: %s", name)
			}
			slot := num * mccIprop
			m.set = ensure(m.set, slot)
			m.setSlack(slot, upper-lower)
			m.setBound(slot, upper)
		}
		p = skipSpace(buf, next)
	}
	m.lastItm = len(m.names)
}

//line ssmcc.w:1136
func (m *MCC) readOptions(br *bufio.Reader) {
	for {
		buf, ok := nextLine(br)
		if !ok {
			break
		}
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
			continue
		}
		m.readOption(buf)
	}
	m.finalize()
}

//line ssmcc.w:1151
func (m *MCC) readOption(buf []byte) {
	spacer := m.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {

//line ssmcc.w:1170
		name, next := token(buf, p, true)
		if name == "" {
			failf("empty item name")
		}
		num, known := m.nameIndex[name]
		if !known {
			failf("unknown item name: %s", name)
		}
		m.createNode(num, spacer, &hasPrimary)
		if buf[next] == ':' {
			if num < m.second {
				failf("primary item must be uncolored: %s", name)
			}
			color, ce := token(buf, next+1, false)
			if color == "" {
				failf("missing color after %s:", name)
			}
			m.nd[m.lastNode].clr = int32(m.internColor(color))
			next = ce
		} else {
			m.nd[m.lastNode].clr = 0
		}
		p = skipSpace(buf, next)

//line ssmcc.w:1156
	}

	if !hasPrimary {

//line ssmcc.w:1195
		for m.lastNode > spacer {
			slot := int(m.nd[m.lastNode].itm) * mccIprop
			m.setSize(slot, m.size(slot)-1)
			m.setPos(slot, spacer-1)
			m.lastNode--
		}

//line ssmcc.w:1160
		return
	}
	m.nd[spacer].loc = int32(m.lastNode - spacer)
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	m.options++
	m.nd[m.lastNode].itm = int32(spacer + 1 - m.lastNode)
}

//line ssmcc.w:1203
func (m *MCC) createNode(num, spacer int, hasPrimary *bool) {
	slot := num * mccIprop
	m.set = ensure(m.set, slot)
	if m.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", m.names[num])
	}
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	t := m.size(slot)
	m.nd[m.lastNode].itm = int32(num)
	m.nd[m.lastNode].loc = int32(t)
	if num < m.second {
		*hasPrimary = true
	}
	m.setSize(slot, t+1)
	m.setPos(slot, m.lastNode)
}

//line ssmcc.w:1224
func (m *MCC) finalize() {

//line ssmcc.w:1232
	m.active, m.itemlen = m.lastItm-1, m.lastItm-1
	m.item = ensure(m.item, m.itemlen)
	m.set = ensure(m.set, m.itemlen*mccIprop+1) // 입력 자리를 모두 읽을 수 있게

	j := mccExtra
	k := 0
	for ; k < m.itemlen; k++ {
		m.item[k] = int32(j)
		j += mccExtra + m.size((k+1)*mccIprop)
	}
	m.setlen = j - mccExtra
	m.set = ensure(m.set, j+1)
	if m.second == secondUnset {
		m.osecond, m.second = m.active, j
	} else {
		m.osecond = m.second - 1
	}

//line ssmcc.w:1226

//line ssmcc.w:1256
	for ; k != 0; k-- {
		base := int(m.item[k-1])
		if k == m.second {
			m.second = base
		}
		m.setSize(base, m.size(k*mccIprop))
		m.setItemNo(base, k)
		m.setSlack(base, m.slack(k*mccIprop))
		m.setBound(base, m.bound(k*mccIprop))
		m.setPos(base, k-1)
		switch {
		case k <= m.osecond && m.size(base) < m.bound(base)-m.slack(base):
			m.baditem = k
		case m.size(base) == 0:
			m.force = ensure(m.force, m.forced+1)
			m.force[m.forced] = int32(base)
			m.forced++
		}
	}

//line ssmcc.w:1227

//line ssmcc.w:1277
	for k = 1; k < m.lastNode; k++ {
		if m.nd[k].itm < 0 {
			continue
		}
		base := int(m.item[int(m.nd[k].itm)-1])
		loc := base + int(m.nd[k].loc)
		m.nd[k].itm = int32(base)
		m.nd[k].loc = int32(loc)
		m.set[loc] = int32(k)
	}

//line ssmcc.w:1228
	m.deactivateOptionless()
}

//line ssmcc.w:1291
func (m *MCC) deactivateOptionless() {
	for m.forced != 0 {
		m.forced--
		j := int(m.force[m.forced])
		m.active--
		i := int(m.item[m.active])
		pp := m.pos(j)
		m.item[m.active], m.item[pp] = int32(j), int32(i)
		m.setPos(j, m.active)
		m.setPos(i, pp)
	}
}
