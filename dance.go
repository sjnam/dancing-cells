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
func (s *Solver) Dance(rd io.Reader) *Result {
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
func (s *Solver) search(level int) bool {
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
func (s *Solver) visit(level int) bool {
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
func (s *Solver) tick() {
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
func (s *Solver) chooseItem() (best int, solution bool) {
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
func (s *Solver) commitOption(opt int) bool {
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
func (s *Solver) hide(c, color, check int) bool {
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
func (s *Solver) swapOut(x int) {
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
func (s *Solver) saveSizes(level int) {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		s.savestack[s.saveptr+p] = twoints{s.item[p], int32(s.size(int(s.item[p])))}
	}
	s.saveptr += s.active
	s.saved = ensure(s.saved, level+2)
	s.saved[level+1] = int32(s.saveptr)
}

// restoreSizes undoes the deletions since saveSizes at this level.
func (s *Solver) restoreSizes(level int) {
	s.saveptr = int(s.saved[level+1])
	s.active = s.saveptr - int(s.saved[level])
	for p := -s.active; p < 0; p++ {
		e := s.savestack[s.saveptr+p]
		s.setSize(int(e.l), int(e.r))
	}
}
