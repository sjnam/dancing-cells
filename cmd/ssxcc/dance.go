package main

import (
	"fmt"
	"os"
)

// The dancing. We repeatedly pick an active primary item that is hardest to
// cover (fewest remaining options) and branch on the ways to cover it,
// exploring depth-first. Sparse sets make undoing a branch trivial: we only
// need to restore the saved item sizes, since the swaps that hide options are
// membership-preserving permutations.

// solve runs the search from the cleaned-up initial state.
func solve() {
	if randomizing {
		randomizeItems()
	}
	search(0)
}

// search explores all completions of the current partial solution at the
// given depth. It returns false to abort the entire search (the solution
// limit was reached or we timed out).
func search(level int) bool {
	nodes++
	if level > maxl {
		maxl = level
	}
	if vbose&showProfile != 0 {
		profile[level]++
	}
	if sanityChecking {
		sanity()
	}
	if delta != 0 && nodes >= thresh {
		thresh += delta
		if vbose&showFullStat != 0 {
			printState(level)
		} else {
			printProgress(level)
		}
	}
	if nodeTimeout != 0 && nodes >= nodeTimeout {
		fmt.Fprintln(os.Stderr, "TIMEOUT!")
		return false
	}

	best, forcedChoice, solution := chooseItem(level)
	if solution {
		return visit(level)
	}
	if forcedChoice && vbose&showChoices != 0 && level < showChoicesMax {
		fmt.Fprintln(os.Stderr, "(forcing)")
	}

	// Branch on best: cover it, then try each of its options in turn,
	// restoring the saved sizes between attempts. A forced item simply has a
	// single option, so the loop runs once.
	swapOut(best)
	oactive = active
	hide(best, 0, 0)
	saveSizes(level)
	for c := best; c < best+size(best); c++ {
		opt := int(set[c])
		choice[level] = int32(opt)
		if vbose&showChoices != 0 && level < showChoicesMax {
			fmt.Fprintf(os.Stderr, "L%d:", level)
			printOption(opt, os.Stderr)
		}
		if commitOption(opt) {
			if !search(level + 1) {
				return false
			}
		}
		restoreSizes(level)
	}
	return true
}

// visit records a solution and returns false if the solution limit is hit.
func visit(level int) bool {
	count++
	if spacing != 0 && count%uint64(spacing) == 0 {
		fmt.Fprintf(out, "%d:\n", count)
		for k := range level {
			printOption(int(choice[k]), out)
		}
		out.Flush()
	}
	return maxcount == 0 || count < maxcount
}

// chooseItem selects the next item to branch on. Items already reduced to a
// single option (the force stack) take priority. Otherwise it scans the
// active primary items for the one with the fewest options, pushing any new
// singletons onto the force stack. It reports solution==true when no primary
// item remains.
func chooseItem(level int) (best int, forcedChoice, solution bool) {
	// (1) An item forced to a single option by an earlier covering.
	for forced != 0 {
		forced--
		if f := int(force[forced]); pos(f) < active {
			return f, true, false
		}
	}

	// (2) Otherwise scan for the active primary item of minimum size.
	score := maxNodes
	trace := vbose&showDetails != 0 && level < showChoicesMax && level >= maxl-showChoicesGap
	if trace {
		fmt.Fprintf(os.Stderr, "Level %d:", level)
	}
	for k := range active {
		x := int(item[k])
		if x >= second {
			continue // secondary items are not branched on
		}
		s := size(x)
		if trace {
			printItemName(x, os.Stderr)
			fmt.Fprintf(os.Stderr, "(%d)", s)
		}
		switch {
		case s == 0:
			fmt.Fprintln(os.Stderr, "I'm confused.") // hide should have caught this
		case s == 1:
			force[forced] = int32(x)
			forced++
		case s < score || (s == score && x < best): // ties: leftmost (P. Weigel)
			best, score = x, s
		}
	}
	reportChoice(trace, best, score)

	// (3) A singleton discovered during the scan, again forced.
	if forced != 0 {
		forced--
		return int(force[forced]), true, false
	}
	return best, false, score == maxNodes
}

// reportChoice emits the optional trace/shape-file annotations for the item
// just chosen, mirroring the original's bookkeeping order.
func reportChoice(trace bool, best, score int) {
	if trace {
		switch {
		case forced != 0:
			fmt.Fprintf(os.Stderr, " found %d forced\n", forced)
		case score == maxNodes:
			fmt.Fprintln(os.Stderr, " solution")
		default:
			fmt.Fprint(os.Stderr, " branching on")
			printItemName(best, os.Stderr)
			fmt.Fprintf(os.Stderr, "(%d)\n", score)
		}
	}
	if score > maxdeg && score < maxNodes && forced == 0 {
		maxdeg = score
	}
	if shapeOut != nil {
		if score == maxNodes {
			fmt.Fprintln(shapeOut, "sol")
		} else {
			fmt.Fprintf(shapeOut, "%d", score)
			printItemName(best, shapeOut)
			fmt.Fprintln(shapeOut)
		}
	}
}

// commitOption extends the partial solution by the option containing opt:
// every other item of opt is covered, and every option conflicting with opt
// is hidden. It returns false (after clearing the force stack) if this would
// leave some primary item uncoverable.
func commitOption(opt int) bool {
	// Swap every other item of opt out of the active list. A colored
	// secondary item may already have been purified (swapped out) earlier.
	p := active
	oactive = active
	for q := opt + 1; q != opt; {
		c := int(nd[q].itm)
		if c < 0 {
			q += c
			continue
		}
		if pp := pos(c); pp < p {
			p--
			cc := int(item[p])
			item[p], item[pp] = int32(c), int32(cc)
			setPos(cc, pp)
			setPos(c, p)
			updates++
		}
		q++
	}
	active = p

	// Hide the now-incompatible options of those items.
	for q := opt + 1; q != opt; {
		c := int(nd[q].itm)
		if c < 0 {
			q += c
			continue
		}
		switch {
		case c < second:
			if !hide(c, 0, 1) {
				forced = 0
				return false
			}
		case pos(c) < oactive: // skip if already purified
			if !hide(c, int(nd[q].clr), 1) {
				forced = 0
				return false
			}
		}
		q++
	}
	return true
}

// hide removes from their item sets all options remaining in item c's set
// that conflict with covering c. When color != 0, item c is secondary and
// options whose color matches are retained (purification). When check is
// true, hide returns false if it would make a primary item uncoverable and
// pushes any newly singleton primary item onto the force stack.
func hide(c, color, check int) bool {
	for rr, s := c, c+size(c); rr < s; rr++ {
		tt := int(set[rr])
		if color != 0 && int(nd[tt].clr) == color {
			continue
		}
		// Remove option tt from every other set it belongs to.
		for nn := tt + 1; nn != tt; {
			u, v := int(nd[nn].itm), int(nd[nn].loc)
			if u < 0 {
				nn += u
				continue
			}
			if pos(u) < oactive {
				ss := size(u) - 1
				if ss <= 1 && check != 0 && u < second && pos(u) < active {
					if ss == 0 {
						if vbose&showChoices != 0 {
							fmt.Fprint(os.Stderr, " can't cover")
							printItemName(u, os.Stderr)
							fmt.Fprintln(os.Stderr)
						}
						return false
					}
					force[forced] = int32(u)
					forced++
				}
				nnp := int(set[u+ss])
				setSize(u, ss)
				set[u+ss], set[v] = int32(nn), int32(nnp)
				nd[nn].loc, nd[nnp].loc = int32(u+ss), int32(v)
				updates++
			}
			nn++
		}
	}
	return true
}

// swapOut removes item x from the active list (covering it).
func swapOut(x int) {
	p := active - 1
	active = p
	pp := pos(x)
	cc := int(item[p])
	item[p], item[pp] = int32(x), int32(cc)
	setPos(cc, pp)
	setPos(x, p)
	updates++
}

// saveSizes snapshots the sizes of the currently active items so a branch can
// be undone by restoreSizes.
func saveSizes(level int) {
	if saveptr+active >= saveSize {
		fmt.Fprintf(os.Stderr, "Stack overflow (savesize=%d)!\n", saveSize)
		os.Exit(-5)
	}
	for p := range active {
		savestack[saveptr+p] = twoints{item[p], int32(size(int(item[p])))}
	}
	saveptr += active
	saved[level+1] = int32(saveptr)
}

// restoreSizes undoes the deletions made since saveSizes at this level by
// restoring the saved sizes and active count.
func restoreSizes(level int) {
	saveptr = int(saved[level+1])
	active = saveptr - int(saved[level])
	for p := -active; p < 0; p++ {
		e := savestack[saveptr+p]
		setSize(int(e.l), int(e.r))
	}
}

// randomizeItems shuffles the initial item list (Knuth's gb_unif_rand), which
// the -s option uses to vary the solution order.
func randomizeItems() {
	for k := active; k > 1; {
		j := int(gbUnifRand(int64(k)))
		k--
		t := int(item[j])
		item[j] = item[k]
		item[k] = int32(t)
		setPos(t, k)
		setPos(int(item[j]), j)
	}
}
