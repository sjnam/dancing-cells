package dcells

import (
	"fmt"
	"io"
	"os"
	"time"
)

// Dance parses the problem from rd (panicking on malformed input) and returns a
// Result whose Solutions channel yields every exact cover. The search runs in a
// goroutine and blocks on each send, so ranging over Solutions paces it; the
// channel closes when the search ends or the context is cancelled.
func (s *XCC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)

	s.solStream = make(chan []Option)
	s.heartbeat = make(chan string)

	go func() {
		defer close(s.solStream)
		defer close(s.heartbeat)

		if s.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
		}
		if s.PulseInterval > 0 {
			s.pulse = time.NewTicker(s.PulseInterval)
			defer s.pulse.Stop()
		}

		if s.baditem == 0 {
			s.search(0)
		}

		if s.Debug {
			plural := "s"
			if s.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				s.count, plural, s.updates, s.nodes)
		}
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}
}

// search explores all completions of the current partial solution at the given
// depth. It returns false to abort the entire search (the context was
// cancelled or the consumer stopped listening).
func (s *XCC) search(level int) bool {
	s.nodes++
	select {
	case <-s.ctx.Done():
		return false
	default:
	}
	s.tick()

	best, solution := s.chooseItem()
	if solution {
		return s.visit(level)
	}

	// Branch on best: cover it, then try each of its options in turn,
	// restoring the saved sizes between attempts.
	s.swapOut(best)
	s.oactive = s.active
	s.hide(best, 0, 0)
	s.saveSizes(level)
	s.choice = ensure(s.choice, level+1)
	for c := best; c < best+s.size(best); c++ {
		opt := int(s.set[c])
		s.choice[level] = int32(opt)
		if s.commitOption(opt) {
			if !s.search(level + 1) {
				return false
			}
		}
		s.restoreSizes(level)
	}
	return true
}

// visit emits the current solution. It returns false (stopping the search) if
// the context is cancelled while sending.
func (s *XCC) visit(level int) bool {
	s.count++
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

// tick offers a heartbeat string when the pulse fires, without blocking.
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

// chooseItem selects the next item to branch on. Items reduced to a single
// option (the force stack) take priority; otherwise the active primary item
// with the fewest options is chosen, with new singletons pushed onto the force
// stack. solution==true means no primary item remains.
func (s *XCC) chooseItem() (best int, solution bool) {
	for s.forced != 0 {
		s.forced--
		if f := int(s.force[s.forced]); s.pos(f) < s.active {
			return f, false
		}
	}

	score := infSize
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // secondary items are not branched on
		}
		switch sz := s.size(x); {
		case sz == 0:
			// Unreachable in practice: hide prevents an active primary
			// item from dropping to zero options.
		case sz == 1:
			s.force = ensure(s.force, s.forced+1)
			s.force[s.forced] = int32(x)
			s.forced++
		case sz < score || (sz == score && x < best): // ties: leftmost
			best, score = x, sz
		}
	}

	if s.forced != 0 {
		s.forced--
		return int(s.force[s.forced]), false
	}
	return best, score == infSize
}

// commitOption extends the partial solution by the option containing opt: every
// other item of opt is covered, and every conflicting option is hidden. It
// returns false (after clearing the force stack) if a primary item would be
// left uncoverable.
func (s *XCC) commitOption(opt int) bool {
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
		case s.pos(c) < s.oactive: // skip if already purified
			if !s.hide(c, int(s.nd[q].clr), 1) {
				s.forced = 0
				return false
			}
		}
		q++
	}
	return true
}

// hide removes from their item sets all options remaining in item c's set that
// conflict with covering c. When color != 0, item c is secondary and options
// whose color matches are kept (purification). When check != 0, hide returns
// false if it would make a primary item uncoverable, and pushes any newly
// singleton primary item onto the force stack.
func (s *XCC) hide(c, color, check int) bool {
	for rr, end := c, c+s.size(c); rr < end; rr++ {
		tt := int(s.set[rr])
		if color != 0 && int(s.nd[tt].clr) == color {
			continue
		}
		for nn := tt + 1; nn != tt; {
			u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
			if u < 0 {
				nn += u
				continue
			}
			if s.pos(u) < s.oactive {
				ss := s.size(u) - 1
				if ss <= 1 && check != 0 && u < s.second && s.pos(u) < s.active {
					if ss == 0 {
						return false
					}
					s.force = ensure(s.force, s.forced+1)
					s.force[s.forced] = int32(u)
					s.forced++
				}
				nnp := int(s.set[u+ss])
				s.setSize(u, ss)
				s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
				s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
				s.updates++
			}
			nn++
		}
	}
	return true
}

// swapOut removes item x from the active list (covering it).
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

// saveSizes snapshots the active items' sizes so a branch can be undone.
func (s *XCC) saveSizes(level int) {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		s.savestack[s.saveptr+p] = twoints{s.item[p], int32(s.size(int(s.item[p])))}
	}
	s.saveptr += s.active
	s.saved = ensure(s.saved, level+2)
	s.saved[level+1] = int32(s.saveptr)
}

// restoreSizes undoes the deletions since saveSizes at this level.
func (s *XCC) restoreSizes(level int) {
	s.saveptr = int(s.saved[level+1])
	s.active = s.saveptr - int(s.saved[level])
	for p := -s.active; p < 0; p++ {
		e := s.savestack[s.saveptr+p]
		s.setSize(int(e.l), int(e.r))
	}
}

// The dancing. Unlike the d-way XCC, MCC branches in a binary tree: a node
// is an item i and an option o. The LEFT child includes o (covering i once
// more); the RIGHT child removes o while leaving i uncovered. stage counts the
// LEFT branches taken (= options in the partial solution); saveState/restoreState
// bookkeep over the savestack and don't influence the search path.

// Dance parses the problem from rd (panicking on malformed input) and returns a
// Result whose Solutions channel yields every cover honoring the multiplicities.
func (m *MCC) Dance(rd io.Reader) *Result {
	m.inputMatrix(rd)

	m.solStream = make(chan []Option)
	m.heartbeat = make(chan string)

	go func() {
		defer close(m.solStream)
		defer close(m.heartbeat)

		if m.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
		}
		if m.PulseInterval > 0 {
			m.pulse = time.NewTicker(m.PulseInterval)
			defer m.pulse.Stop()
		}

		if m.baditem == 0 {
			m.search(0)
		}

		if m.Debug {
			plural := "s"
			if m.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				m.count, plural, m.updates, m.nodes)
		}
	}()

	return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}
}

// search explores the forward node at the given stage. It returns false to
// abort the whole search (context cancelled or consumer gone).
func (m *MCC) search(stage int) bool {
	m.nodes++
	select {
	case <-m.ctx.Done():
		return false
	default:
	}
	m.tick()

	// A forced item left over from a covering at a shallower node.
	for m.forced != 0 {
		m.forced--
		if bi := int(m.force[m.forced]); m.pos(bi) < m.active {
			return m.forcedMove(stage, bi)
		}
	}

	best, score := m.chooseBest()
	if m.forced != 0 {
		m.forced--
		return m.forcedMove(stage, int(m.force[m.forced]))
	}
	if score == infSize {
		return m.visit(stage)
	}

	// Branch on best (degree score): LEFT includes its first option, RIGHT
	// removes that option and re-chooses.
	mark := m.saveState()
	opt := int(m.set[best])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)

	if m.includeOption(opt) {
		if !m.search(stage + 1) {
			m.saveptr = mark
			return false
		}
	}
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
	return true
}

// forcedMove commits the single option of a forced item (degree 1, no right
// branch). It saves nothing; an ancestor's restoreState undoes its effects.
func (m *MCC) forcedMove(stage, bi int) bool {
	opt := int(m.set[bi])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)
	if m.includeOption(opt) {
		return m.search(stage + 1)
	}
	return true
}

// visit emits the current solution (the options included so far).
func (m *MCC) visit(stage int) bool {
	m.count++
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

// chooseBest finds the active primary item of least branching degree l+s-b+1,
// where l is its size, b its residual bound, and s=min(slack,b). A degree-1
// item is forced: it must take each of its bound-slack options. score==infSize
// means no primary item remains (a solution).
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

// includeOption extends the partial solution by option opt: each primary item's
// residual bound decreases; an item whose bound hits 0 (or a secondary item) is
// covered/purified, while a primary still needing coverage drops opt from its
// set. Returns false if some item becomes uncoverable.
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
			return false // should not happen for a well-formed active option
		}
		if !m.coverOrCommit(ii, opt, pp) {
			return false
		}
	}
	return true
}

func (m *MCC) coverOrCommit(ii, opt, pp int) bool {
	if ii < m.second {
		m.setBound(ii, m.bound(ii)-1)
	}
	if ii >= m.second || m.bound(ii) == 0 {
		ss := m.size(ii)
		c := 0
		if ii >= m.second {
			c = int(m.nd[opt].clr)
		}
		for s := ii + ss - 1; s >= ii; s-- {
			if s == pp {
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
	} else {
		ss := m.size(ii) - 1
		if ss < m.bound(ii)-m.slack(ii) {
			m.forced = 0
			return false // ii would be wiped out
		}
		if ss == 0 {
			m.deactivate(ii)
		} else {
			nnp := int(m.set[ii+ss])
			m.setSize(ii, ss)
			m.set[ii+ss], m.set[pp] = int32(opt), int32(nnp)
			m.nd[opt].loc, m.nd[nnp].loc = int32(ii+ss), int32(pp)
			m.updates++
		}
	}
	return true
}

// removeFromOtherSets swaps option optp out of every active set it belongs to
// (skipping purified secondary items). Returns false if a primary item would be
// left uncoverable.
func (m *MCC) removeFromOtherSets(optp int) bool {
	nn := optp
	for m.nd[nn-1].itm > 0 {
		nn--
	}
	for ; ; nn++ {
		ii := int(m.nd[nn].itm)
		if ii <= 0 {
			break
		}
		p := int(m.nd[nn].loc)
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
			nnp := int(m.set[ii+ss])
			m.setSize(ii, ss)
			m.set[ii+ss], m.set[p] = int32(nn), int32(nnp)
			m.nd[nn].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
			m.updates++
		}
	}
	return true
}

// removeOption performs the right branch: it removes option cur without
// committing it. Returns false ("can't cover") if that leaves a primary item
// uncoverable, in which case the caller backtracks.
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
			nnp := int(m.set[ii+ss])
			m.setSize(ii, ss)
			m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
			m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
			m.updates++
		}
	}
	return true
}

func (m *MCC) deactivate(ii int) {
	m.active--
	p := m.pos(ii)
	iii := int(m.item[m.active])
	m.item[m.active], m.item[p] = int32(ii), int32(iii)
	m.setPos(ii, m.active)
	m.setPos(iii, p)
}

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
