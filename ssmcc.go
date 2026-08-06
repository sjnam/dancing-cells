//line ssmcc.w:27
package dcells

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
)

//line ssmcc.w:151
const (
	mccExtra = 5 // set entries below each item base: size, pos, itemNo, slack, bound
	mccIprop = 5 // input-phase slot spacing
)

type threeints struct{ l, s, b int32 }

//line ssmcc.w:164
type MCC struct {

//line ssmcc.w:72
	Debug         bool          // print input summary and final stats to stderr
	PulseInterval time.Duration // if > 0, offer periodic Heartbeat strings

//line ssmcc.w:741
	Bound func(Frame) int // lower bound on the cost still to come; may be nil

//line ssmcc.w:166
	ctx context.Context

//line ssmcc.w:168

//line ssmcc.w:178
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

//line ssmcc.w:169

//line ssmcc.w:79
	names      []string // interned item names, by item number (1-based)
	nameIndex  map[string]int
	colorNames []string // interned colors, by id (1-based; 0 means "no color")
	colorIndex map[string]int

//line ssmcc.w:170

//line ssmcc.w:89
	force  []int32
	forced int

//line ssmcc.w:171

//line ssmcc.w:191
	included  []int32 // option included at each stage, for solution output
	savestack []threeints
	saveptr   int

//line ssmcc.w:172

//line ssmcc.w:750
	minimizing bool
	optNo      []int32 // node -> the option that node belongs to
	optCost    []int32 // option number -> the price the caller put on it
	itemBase   []int32 // item number -> its base in |set|
	cost       int64   // price of the options included so far
	incumbent  int64   // price of the cheapest cover so far

//line ssmcc.w:173

//line ssmcc.w:93
	updates uint64
	nodes   uint64
	options uint64
	count   uint64

//line ssmcc.w:174

//line ssmcc.w:99
	solStream chan []Option
	heartbeat chan string
	pulse     *time.Ticker

//line ssmcc.w:175
}

//line ssmcc.w:197
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

//line ssmcc.w:218
func (m *MCC) Nodes() uint64 { return m.nodes }

//line ssmcc.w:222
func (m *MCC) size(x int) int { return int(m.set[x-1]) }

//line ssmcc.w:223
func (m *MCC) pos(x int) int { return int(m.set[x-2]) }

//line ssmcc.w:224
func (m *MCC) itemNo(x int) int { return int(m.set[x-3]) }

//line ssmcc.w:225
func (m *MCC) slack(x int) int { return int(m.set[x-4]) }

//line ssmcc.w:226
func (m *MCC) bound(x int) int { return int(m.set[x-5]) }

func (m *MCC) setSize(x, v int) { m.set[x-1] = int32(v) }

//line ssmcc.w:229
func (m *MCC) setPos(x, v int) { m.set[x-2] = int32(v) }

//line ssmcc.w:230
func (m *MCC) setItemNo(x, v int) { m.set[x-3] = int32(v) }

//line ssmcc.w:231
func (m *MCC) setSlack(x, v int) { m.set[x-4] = int32(v) }

//line ssmcc.w:232
func (m *MCC) setBound(x, v int) { m.set[x-5] = int32(v) }

//line ssmcc.w:238
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

//line ssmcc.w:261
func (m *MCC) Dance(rd io.Reader) *Result {
	m.inputMatrix(rd)

//line ssmcc.w:270
	m.solStream = make(chan []Option)
	m.heartbeat = make(chan string)

	go func() {
		defer close(m.solStream)
		defer close(m.heartbeat)

//line ssmcc.w:277

//line ssmcc.w:293
		if m.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
		}

//line ssmcc.w:278
		if m.PulseInterval > 0 {
			m.pulse = time.NewTicker(m.PulseInterval)
			defer m.pulse.Stop()
		}

		if m.baditem == 0 {
			m.search(0)
		}

//line ssmcc.w:287

//line ssmcc.w:300
		if m.Debug {
			plural := "s"
			if m.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				m.count, plural, m.updates, m.nodes)
		}

//line ssmcc.w:288
	}()

	return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}

//line ssmcc.w:264
}

//line ssmcc.w:327
func (m *MCC) search(stage int) bool {
	m.nodes++
	select {
	case <-m.ctx.Done():
		return false
	default:
	}
	m.tick()

//line ssmcc.w:336

//line ssmcc.w:354
	for m.forced != 0 {
		m.forced--
		if bi := int(m.force[m.forced]); m.pos(bi) < m.active {
			return m.forcedMove(stage, bi)
		}
	}

//line ssmcc.w:337

//line ssmcc.w:811
	if m.minimizing {
		rest := int64(0)
		if m.Bound != nil {
			rest = int64(m.Bound(Frame{m}))
		}
		if m.cost+rest >= m.incumbent {
			return true
		}
	}

//line ssmcc.w:339
	best, score := m.chooseBest()
	if m.forced != 0 {
		m.forced--
		return m.forcedMove(stage, int(m.force[m.forced]))
	}
	if score == infSize {
		return m.visit(stage)
	}

//line ssmcc.w:368
	mark := m.saveState()
	opt := int(m.set[best])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)

//line ssmcc.w:824
	price := int64(0)
	if m.minimizing {
		price = int64(m.optCost[m.optNo[opt]])
	}

//line ssmcc.w:374
	m.cost += price
	if m.includeOption(opt) {
		if !m.search(stage + 1) {
			m.saveptr = mark
			return false
		}
	}
	m.cost -= price
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

//line ssmcc.w:348
	return true
}

//line ssmcc.w:400
func (m *MCC) forcedMove(stage, bi int) bool {
	opt := int(m.set[bi])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)

//line ssmcc.w:824
	price := int64(0)
	if m.minimizing {
		price = int64(m.optCost[m.optNo[opt]])
	}

//line ssmcc.w:405
	m.cost += price
	ok := true
	if m.includeOption(opt) {
		ok = m.search(stage + 1)
	}
	m.cost -= price
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
				continue // secondary item already purified
			}
			return false // cannot happen for a well-formed active option
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
			return false // ii would be wiped out
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

//line ssmcc.w:618
func (m *MCC) deactivate(ii int) {
	m.active--
	p := m.pos(ii)
	iii := int(m.item[m.active])
	m.item[m.active], m.item[p] = int32(ii), int32(iii)
	m.setPos(ii, m.active)
	m.setPos(iii, p)
}

//line ssmcc.w:632
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

//line ssmcc.w:663
func (m *MCC) visit(stage int) bool {
	m.count++
	m.incumbent = m.cost
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

//line ssmcc.w:679
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

//line ssmcc.w:694
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

//line ssmcc.w:766
func (m *MCC) Minimize(rd io.Reader, cost func(o int, opt Option) int) *Result {
	m.inputMatrix(rd)

//line ssmcc.w:778
	m.optNo = make([]int32, m.lastNode+1)
	m.optCost = make([]int32, int(m.options)+1)
	o := int32(0)
	for k := 1; k < m.lastNode; k++ {
		if m.nd[k].itm <= 0 {
			continue // a spacer between two options
		}
		if m.nd[k-1].itm <= 0 {
			o++
			m.optCost[o] = int32(cost(int(o), m.option(k)))
		}
		m.optNo[k] = o
	}

//line ssmcc.w:798
	m.itemBase = make([]int32, m.itemlen+1)
	for k := 0; k < m.itemlen; k++ {
		base := int(m.item[k])
		m.itemBase[m.itemNo(base)] = int32(base)
	}

//line ssmcc.w:769
	m.minimizing, m.incumbent = true, infCost

//line ssmcc.w:270
	m.solStream = make(chan []Option)
	m.heartbeat = make(chan string)

	go func() {
		defer close(m.solStream)
		defer close(m.heartbeat)

//line ssmcc.w:277

//line ssmcc.w:293
		if m.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
		}

//line ssmcc.w:278
		if m.PulseInterval > 0 {
			m.pulse = time.NewTicker(m.PulseInterval)
			defer m.pulse.Stop()
		}

		if m.baditem == 0 {
			m.search(0)
		}

//line ssmcc.w:287

//line ssmcc.w:300
		if m.Debug {
			plural := "s"
			if m.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				m.count, plural, m.updates, m.nodes)
		}

//line ssmcc.w:288
	}()

	return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}

//line ssmcc.w:771
}

//line ssmcc.w:833
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

//line ssmcc.w:855
func (m *MCC) optionCost(opt int) int { return int(m.optCost[opt]) }

//line ssmcc.w:856
func (m *MCC) itemName(item int) string { return m.names[item] }

func (m *MCC) itemNeed(item int) int {
	x := int(m.itemBase[item])
	if x >= m.second {
		return 0
	}
	return max(m.bound(x)-m.slack(x), 0)
}

//line ssmcc.w:874
func (m *MCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	m.readItemNames(br)
	m.readOptions(br)
}

//line ssmcc.w:891
func mustAtoi(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		failf("illegal number in bound spec: %q", s)
	}
	return n
}

func parseItemSpec(tok string, inSecondary bool) (name string, lower, upper int) {
	if i := strings.IndexByte(tok, '|'); i >= 0 {

//line ssmcc.w:915
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

//line ssmcc.w:902
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

//line ssmcc.w:938
func (m *MCC) readItemNames(br *bufio.Reader) {

//line ssmcc.w:964
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

//line ssmcc.w:940
	for buf[p] != 0 {
		tok, next := token(buf, p, false)
		if tok == "|" {
			if m.second != secondUnset {
				failf("item name line contains | twice")
			}
			m.second = len(m.names) // the next item's number
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

//line ssmcc.w:983
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

//line ssmcc.w:998
func (m *MCC) readOption(buf []byte) {
	spacer := m.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {

//line ssmcc.w:1017
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

//line ssmcc.w:1003
	}

	if !hasPrimary {

//line ssmcc.w:1042
		for m.lastNode > spacer {
			slot := int(m.nd[m.lastNode].itm) * mccIprop
			m.setSize(slot, m.size(slot)-1)
			m.setPos(slot, spacer-1)
			m.lastNode--
		}

//line ssmcc.w:1007
		return
	}
	m.nd[spacer].loc = int32(m.lastNode - spacer)
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	m.options++
	m.nd[m.lastNode].itm = int32(spacer + 1 - m.lastNode)
}

//line ssmcc.w:1050
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

//line ssmcc.w:1071
func (m *MCC) finalize() {

//line ssmcc.w:1079
	m.active, m.itemlen = m.lastItm-1, m.lastItm-1
	m.item = ensure(m.item, m.itemlen)
	m.set = ensure(m.set, m.itemlen*mccIprop+1) // all input slots readable

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

//line ssmcc.w:1073

//line ssmcc.w:1104
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

//line ssmcc.w:1074

//line ssmcc.w:1125
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

//line ssmcc.w:1075
	m.deactivateOptionless()
}

//line ssmcc.w:1139
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
