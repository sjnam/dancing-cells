package main

import (
	"fmt"
	"os"
)

// The dancing. Unlike the d-way branching of SSXCC, this program branches in a
// binary tree (an idea from MDANCE/DLX3 generalized to multiplicities): a node
// is labeled with an item i and an option o. The LEFT child includes o (so i is
// covered once more); the RIGHT child removes o while leaving i uncovered.
//
//   - level is the depth in the binary tree (every branch increases it).
//   - stage is the number of LEFT branches taken (= options in the partial
//     solution). Only saveState/restoreState and the solution list use stages.
//
// saveState/restoreState are pure bookkeeping over the global savestack; they
// do not influence the search path, so solutions, nodes, and updates match the
// original program exactly.

func solve() {
	if randomizing {
		randomizeItems()
	}
	search(0, 0)
}

// search explores the forward node at the given stage and level. It returns
// false to abort the whole search (the solution limit was reached or we timed
// out).
func search(stage, level int) bool {
	nodes++
	if level > 0 {
		stagelevel[level] = int32(stage)
		levelstage[stage] = int32(level)
	}
	if level > maxl {
		maxl = level
	}
	if stage > maxs {
		maxs = stage
	}
	if vbose&showProfile != 0 {
		profile[stage]++
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

	// A forced item left over from a covering at a shallower node.
	for forced != 0 {
		forced--
		if bi := int(force[forced]); pos(bi) < active {
			return forcedMove(stage, level, bi)
		}
	}

	best, score := chooseBest(stage, level)
	if forced != 0 {
		forced--
		return forcedMove(stage, level, int(force[forced]))
	}
	if score == infSize {
		return visit(stage)
	}

	// Branch on best (degree score): LEFT includes its first option, RIGHT
	// removes that option and re-chooses.
	mark := saveState()
	opt := int(set[best])
	choice[level] = int32(opt)
	deg[level] = int32(score)
	included[stage] = int32(opt)

	if includeOption(opt, stage) {
		if !search(stage+1, level+1) {
			saveptr = mark
			return false
		}
	}
	if score != 1 {
		restoreState(mark)
		if removeOption(opt) {
			if !search(stage, level+1) {
				saveptr = mark
				return false
			}
		}
	}
	saveptr = mark
	return true
}

// forcedMove commits the single option of a forced item bi (degree 1, no right
// branch). It saves nothing: an ancestor's restoreState undoes its effects.
func forcedMove(stage, level, bi int) bool {
	if vbose&showChoices != 0 && level < showChoicesMax {
		fmt.Fprintln(os.Stderr, "(forcing)")
	}
	opt := int(set[bi])
	choice[level] = int32(opt)
	deg[level] = 1
	included[stage] = int32(opt)
	if includeOption(opt, stage) {
		return search(stage+1, level+1)
	}
	return true
}

func visit(stage int) bool {
	count++
	if spacing != 0 && count%uint64(spacing) == 0 {
		fmt.Fprintf(out, "%d:\n", count)
		for k := 0; k < stage; k++ {
			printOption(int(included[k]), out, 0)
		}
		out.Flush()
	}
	return maxcount == 0 || count < maxcount
}

// chooseBest finds the active primary item of least branching degree. The
// degree of an item is l+s-b+1, where l is its size, b its residual bound, and
// s=min(slack,b). An item of degree 1 is forced: it must take every one of its
// (bound-slack) options, so it is pushed that many times onto the force stack.
// score==infSize means no primary item remains (a solution).
func chooseBest(stage, level int) (best, score int) {
	score = infSize
	bestS, bestL := 0, 0
	trace := vbose&showDetails != 0 && level < showChoicesMax && level >= maxl-showChoicesGap
	if trace {
		fmt.Fprintf(os.Stderr, "Level %d:", level)
	}
	for k := 0; k < active; k++ {
		x := int(item[k])
		if x >= second {
			continue
		}
		s := slack(x)
		if s > bound(x) {
			s = bound(x)
		}
		t := size(x) + s - bound(x) + 1
		if trace {
			printItemName(x, os.Stderr)
			if bound(x) != 1 || s != 0 {
				fmt.Fprintf(os.Stderr, "(%d:%d,%d)", bound(x)-s, bound(x), t)
			} else {
				fmt.Fprintf(os.Stderr, "(%d)", t)
			}
		}
		switch {
		case t == 1:
			for i := bound(x) - slack(x); i > 0; i-- {
				force[forced] = int32(x)
				forced++
			}
		case t <= score && (t < score || (s <= bestS && (s < bestS ||
			(size(x) >= bestL && (size(x) > bestL || x < best))))):
			score, best, bestS, bestL = t, x, s, size(x)
		}
	}
	reportChoice(trace, best, score)
	return best, score
}

func reportChoice(trace bool, best, score int) {
	if trace {
		switch {
		case score == infSize:
			fmt.Fprintln(os.Stderr, " solution")
		case forced != 0:
			fmt.Fprintf(os.Stderr, " found %d forced:", forced)
			for i := 0; i < forced; i++ {
				printItemName(int(force[i]), os.Stderr)
			}
			fmt.Fprintln(os.Stderr)
		default:
			fmt.Fprint(os.Stderr, " branching on")
			printItemName(best, os.Stderr)
			fmt.Fprintf(os.Stderr, "(%d)\n", score)
		}
	}
	if score > maxdeg && score < infSize && forced == 0 {
		maxdeg = score
	}
	if shapeOut != nil {
		if score == infSize {
			fmt.Fprintln(shapeOut, "sol")
		} else {
			fmt.Fprintf(shapeOut, "%d", score)
			printItemName(best, shapeOut)
			fmt.Fprintln(shapeOut)
		}
	}
}

// includeOption extends the partial solution by option opt. Each primary item
// of opt has its residual bound decreased; an item whose bound reaches 0 (or a
// secondary item) is covered/purified — its conflicting options are removed and
// it is deactivated. A primary item still needing coverage simply drops opt
// from its set. Returns false if some item becomes uncoverable.
func includeOption(opt, stage int) bool {
	if vbose&showChoices != 0 {
		fmt.Fprintf(os.Stderr, "S%d:", stage)
		printOption(opt, os.Stderr, 1)
	}
	for nd[opt-1].itm > 0 {
		opt-- // move to the beginning of the option
	}
	for ; ; opt++ {
		ii := int(nd[opt].itm)
		if ii <= 0 {
			break
		}
		pp := int(nd[opt].loc) // where opt appears in ii's set
		if pos(ii) >= active {
			if ii >= second {
				continue // secondary item already purified
			}
			confusion("active") // a primary item of an active option must be active
		}
		if !coverOrCommit(ii, opt, pp) {
			return false
		}
	}
	return true
}

func coverOrCommit(ii, opt, pp int) bool {
	if ii < second {
		setBound(ii, bound(ii)-1)
	}
	if ii >= second || bound(ii) == 0 {
		ss := size(ii)
		c := 0
		if ii >= second {
			c = int(nd[opt].clr)
		}
		for s := ii + ss - 1; s >= ii; s-- {
			if s == pp {
				continue
			}
			optp := int(set[s])
			if c == 0 || int(nd[optp].clr) != c {
				if !removeFromOtherSets(optp) {
					return false
				}
			}
		}
		deactivate(ii)
	} else {
		ss := size(ii) - 1
		if ss < bound(ii)-slack(ii) {
			toughItm, forced = ii, 0
			return false // ii would be wiped out
		}
		if ss == 0 {
			deactivate(ii)
		} else {
			nnp := int(set[ii+ss])
			setSize(ii, ss)
			set[ii+ss], set[pp] = int32(opt), int32(nnp)
			nd[opt].loc, nd[nnp].loc = int32(ii+ss), int32(pp)
			updates++
		}
	}
	return true
}

// removeFromOtherSets swaps option optp out of every active set it belongs to
// (skipping purified secondary items). Returns false if a primary item would be
// left uncoverable.
func removeFromOtherSets(optp int) bool {
	nn := optp
	for nd[nn-1].itm > 0 {
		nn--
	}
	for ; ; nn++ {
		ii := int(nd[nn].itm)
		if ii <= 0 {
			break
		}
		p := int(nd[nn].loc)
		if p >= second && pos(ii) >= active {
			continue // ii already purified
		}
		ss := size(ii) - 1
		if p < second {
			if ss < bound(ii)-slack(ii) {
				toughItm, forced = ii, 0
				return false
			}
			if ss == 0 {
				deactivate(ii)
			}
		}
		if ss > 0 {
			nnp := int(set[ii+ss])
			setSize(ii, ss)
			set[ii+ss], set[p] = int32(nn), int32(nnp)
			nd[nn].loc, nd[nnp].loc = int32(ii+ss), int32(p)
			updates++
		}
	}
	return true
}

// removeOption performs the right branch: it removes option cur from the
// subproblem without committing it. Returns false ("can't cover") if that
// leaves a primary item uncoverable, in which case the caller backtracks.
func removeOption(cur int) bool {
	for nd[cur-1].itm > 0 {
		cur--
	}
	for ; ; cur++ {
		ii := int(nd[cur].itm)
		if ii <= 0 {
			break
		}
		p := int(nd[cur].loc)
		if p >= second && pos(ii) >= active {
			continue // ii inactive
		}
		ss := size(ii) - 1
		if p < second {
			if ss < bound(ii)-slack(ii) {
				return false
			}
			if ss == 0 {
				deactivate(ii)
			}
		}
		if ss > 0 {
			nnp := int(set[ii+ss])
			setSize(ii, ss)
			set[ii+ss], set[p] = int32(cur), int32(nnp)
			nd[cur].loc, nd[nnp].loc = int32(ii+ss), int32(p)
			updates++
		}
	}
	return true
}

// deactivate removes item ii from the active list.
func deactivate(ii int) {
	active--
	p := pos(ii)
	iii := int(item[active])
	item[active], item[p] = int32(ii), int32(iii)
	setPos(ii, active)
	setPos(iii, p)
}

// saveState snapshots the active items' sizes and bounds; restoreState rewinds
// to a snapshot. The savestack is a bump arena indexed by the returned mark.
func saveState() int {
	mark := saveptr
	if saveptr+active >= saveSize {
		fmt.Fprintf(os.Stderr, "Stack overflow (savesize=%d)!\n", saveSize)
		os.Exit(-5)
	}
	for p := 0; p < active; p++ {
		x := int(item[p])
		e := threeints{l: int32(x), s: int32(size(x))}
		if x < second {
			e.b = int32(bound(x))
		}
		savestack[saveptr] = e
		saveptr++
	}
	return mark
}

func restoreState(mark int) {
	active = saveptr - mark
	for p := 0; p < active; p++ {
		e := savestack[mark+p]
		setSize(int(e.l), int(e.s))
		if int(e.l) < second {
			setBound(int(e.l), int(e.b))
		}
	}
	saveptr = mark
}

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
