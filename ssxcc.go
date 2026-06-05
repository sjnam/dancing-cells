// ssxcc — an XCC (exact cover with colors) solver using sparse-set
// "dancing cells" data structures instead of dancing links.
//
// This is a Go port of Donald E. Knuth's CWEB program SSXCC
// (https://www-cs-faculty.stanford.edu/~knuth/programs/ssxcc.w).
// It accepts the same DLX input format and reproduces the same
// statistics (solutions, mems, updates, nodes, bytes), so results can
// be compared directly against the original.
//
// "One mem essentially means a memory access to a 64-bit word." The
// inline mems++ / mems += n bookkeeping mirrors Knuth's o/oo/ooo
// annotations so the reported mem counts match the C program.
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
)

// ---------------------------------------------------------------------------
// Tunable capacities (matching the @d constants of the original program).
// ---------------------------------------------------------------------------

const (
	maxLevel = 5000     // at most this many options in a solution
	maxCols  = 100000   // at most this many items
	maxNodes = 10000000 // at most this many nonzero matrix elements / sentinel
	saveSize = 10000000 // at most this many entries on savestack

	primExtra   = 4 // extra set entries for each primary item
	secondExtra = 4 // and this many for each secondary item
	maxExtra    = 4 // maximum of primExtra and secondExtra
)

// vbose codes.
const (
	showBasics   = 1
	showChoices  = 2
	showDetails  = 4
	showProfile  = 128
	showFullStat = 256
	showTots     = 512
	showWarnings = 1024
	showMaxDeg   = 2048
)

// A node of the matrix. itm and clr stay constant after initialization;
// loc changes as options dance in and out of item sets. spr is a spare
// field that the original keeps only for 16-byte alignment / debugging.
type node struct {
	itm, loc, clr, spr int32
}

// twoints is one savestack entry: an item and its size.
type twoints struct {
	l, r int32
}

// ---------------------------------------------------------------------------
// Global state.
// ---------------------------------------------------------------------------

var (
	// command-line controlled options
	randomSeed     int
	randomizing    bool
	vbose          = showBasics + showWarnings
	spacing        int
	showChoicesMax = 1000000
	showChoicesGap = 1000000
	showLevelsMax  = 1000000
	maxcount       = uint64(0xffffffffffffffff)
	timeout        = uint64(0x1fffffffffffffff)
	delta          = uint64(10000000000)
	thresh         = uint64(10000000000)
	shapeFile      *os.File
	shapeName      string

	// statistics
	maxl       int
	maxsaveptr int
	count      uint64
	options    uint64
	imems      uint64
	mems       uint64
	tmems      uint64
	cmems      uint64
	updates    uint64
	bytes      uint64
	nodes      uint64
	maxdeg     int

	// core data structures
	nd        []node
	lastNode  int
	item      []int32
	second    = maxCols
	lastItm   int
	set       []int32
	itemlen   int
	setlen    int
	active    int
	oactive   int
	baditem   int
	osecond   int
	force     []int32
	forced    int

	// search state
	level     int
	choice    []int32
	saved     []int32
	savestack []twoints
	saveptr   int
	profile   []uint64

	out *bufio.Writer // buffered stdout for solutions
)

// ---------------------------------------------------------------------------
// Sparse-set field accessors. For item x (an index into set):
//   set[x-1] = size,  set[x-2] = pos,  set[x-3] = rname,  set[x-4] = lname.
// ---------------------------------------------------------------------------

func size(x int) int  { return int(set[x-1]) }
func pos(x int) int   { return int(set[x-2]) }
func rname(x int) int { return int(set[x-3]) }
func lname(x int) int { return int(set[x-4]) }

func setSize(x, v int)  { set[x-1] = int32(v) }
func setPos(x, v int)   { set[x-2] = int32(v) }
func setRname(x, v int) { set[x-3] = int32(v) }
func setLname(x, v int) { set[x-4] = int32(v) }

// isspace matches C's isspace for the bytes we care about.
func isspace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
}

// packLR encodes up to 8 name bytes into two little-endian 32-bit ints,
// exactly as the C union stringbuf{str[8]; lr{l,r}} does on a little-endian
// machine.
func packLR(b *[8]byte) (int, int) {
	l := int(b[0]) | int(b[1])<<8 | int(b[2])<<16 | int(b[3])<<24
	r := int(b[4]) | int(b[5])<<8 | int(b[6])<<16 | int(b[7])<<24
	return l, r
}

func decodeName(l, r int) string {
	b := []byte{
		byte(l), byte(l >> 8), byte(l >> 16), byte(l >> 24),
		byte(r), byte(r >> 8), byte(r >> 16), byte(r >> 24),
	}
	n := 0
	for n < 8 && b[n] != 0 {
		n++
	}
	return string(b[:n])
}

// ---------------------------------------------------------------------------
// Printing helpers.
// ---------------------------------------------------------------------------

func printItemName(k int, w io.Writer) {
	fmt.Fprintf(w, " %s", decodeName(lname(k), rname(k)))
}

func printOption(p int, w io.Writer) {
	x := int(nd[p].itm)
	if p >= lastNode || x <= 0 {
		fmt.Fprintf(os.Stderr, "Illegal option %d!\n", p)
		return
	}
	q := p
	for {
		printItemName(x, w)
		if nd[q].clr != 0 {
			fmt.Fprintf(w, ":%c", rune(nd[q].clr))
		}
		q++
		x = int(nd[q].itm)
		if x < 0 {
			q += x
			x = int(nd[q].itm)
		}
		if q == p {
			break
		}
	}
	k := int(nd[q].loc)
	fmt.Fprintf(w, " (%d of %d)\n", k-x+1, size(x))
}

func prow(p int) { printOption(p, os.Stderr) }

func printState() {
	fmt.Fprintf(os.Stderr, "Current state (level %d):\n", level)
	for l := 0; l < level; l++ {
		printOption(int(choice[l]), os.Stderr)
		if l >= showLevelsMax {
			fmt.Fprintf(os.Stderr, " ...\n")
			break
		}
	}
	fmt.Fprintf(os.Stderr, " %d solutions, %d mems, and max level %d so far.\n",
		count, mems, maxl)
}

func printProgress() {
	fmt.Fprintf(os.Stderr, " after %d mems: %d sols,", mems, count)
	f, fd := 0.0, 1.0
	ds := false
	for l := 0; l < level; l++ {
		c := int(nd[choice[l]].itm)
		d := size(c)
		k := int(nd[choice[l]].loc) - c + 1
		fd *= float64(d)
		f += float64(k-1) / fd
		if l < showLevelsMax {
			fmt.Fprintf(os.Stderr, " %c%c", digit(k), digit(d))
		} else if !ds {
			ds = true
			fmt.Fprint(os.Stderr, "...")
		}
	}
	fmt.Fprintf(os.Stderr, " %.5f\n", f+0.5/fd)
}

func digit(k int) byte {
	switch {
	case k < 10:
		return byte('0' + k)
	case k < 36:
		return byte('a' + k - 10)
	case k < 62:
		return byte('A' + k - 36)
	default:
		return '*'
	}
}

func printProfile() {
	fmt.Fprintf(os.Stderr, "Profile:\n")
	for l := 0; l <= maxl; l++ {
		fmt.Fprintf(os.Stderr, "%3d: %d\n", l, profile[l])
	}
}

// sanity checks redundant invariants of the data structure (debug only).
func sanity() {
	for k := 0; k < itemlen; k++ {
		x := int(item[k])
		if pos(x) != k {
			fmt.Fprintf(os.Stderr, "Bad pos field of item")
			printItemName(x, os.Stderr)
			fmt.Fprintf(os.Stderr, " (%d,%d)!\n", k, x)
		}
	}
	qq := 0
	for i := 0; i < lastNode; i++ {
		l, r := int(nd[i].itm), int(nd[i].loc)
		if l <= 0 {
			if int(nd[i+r+1].itm) != -r {
				fmt.Fprintf(os.Stderr, "Bad spacer in nodes %d, %d!\n", i, i+r+1)
			}
			qq = 0
		} else {
			if l > r {
				fmt.Fprintf(os.Stderr, "itm>loc in node %d!\n", i)
			} else {
				if int(set[r]) != i {
					fmt.Fprintf(os.Stderr, "Bad loc field for option %d of item", r-l+1)
					printItemName(l, os.Stderr)
					fmt.Fprintf(os.Stderr, " in node %d!\n", i)
				}
				if pos(l) < active {
					q := -1
					if r < l+size(l) {
						q = 1
					}
					if q*qq < 0 {
						fmt.Fprintf(os.Stderr, "Flipped status at option %d of item", r-l+1)
						printItemName(l, os.Stderr)
						fmt.Fprintf(os.Stderr, " in node %d!\n", i)
					}
					qq = q
				}
			}
		}
	}
}

const sanityChecking = false

// ---------------------------------------------------------------------------
// Input.
// ---------------------------------------------------------------------------

var reader *bufio.Reader

// nextLine reads one input line. The returned buffer always ends with a
// newline followed by NUL padding, so that C-style buf[p+j] probing stays
// in bounds and stops at the terminating NUL. slen mirrors strlen(buf).
func nextLine() (buf []byte, slen int, ok bool) {
	s, err := reader.ReadString('\n')
	if len(s) == 0 && err != nil {
		return nil, 0, false
	}
	if len(s) == 0 || s[len(s)-1] != '\n' {
		s += "\n"
	}
	slen = len(s)
	buf = make([]byte, slen+12) // content + '\n', then NUL padding
	copy(buf, s)
	return buf, slen, true
}

func panicf(p int, buf []byte, msg string) {
	// Print up to 99 chars of the offending line, like the C panic macro.
	line := buf
	if i := indexByte(line, 0); i >= 0 {
		line = line[:i]
	}
	if len(line) > 99 {
		line = line[:99]
	}
	fmt.Fprintf(os.Stderr, "%s!\n%d: %s\n", msg, p, string(line))
	os.Exit(-666)
}

func indexByte(b []byte, c byte) int {
	for i := range b {
		if b[i] == c {
			return i
		}
	}
	return -1
}

func inputItemNames() {
	var buf []byte
	var slen, p int
	lastItm = 0
	for {
		var ok bool
		buf, slen, ok = nextLine()
		if !ok {
			break
		}
		mems++
		p = slen - 1
		if buf[p] != '\n' {
			panicf(p, buf, "Input line way too long")
		}
		for p = 0; ; p++ {
			mems++
			if !isspace(buf[p]) {
				break
			}
		}
		if buf[p] == '|' || buf[p] == 0 {
			continue // comment or blank line
		}
		lastItm = 1
		break
	}
	if lastItm == 0 {
		panicf(p, buf, "No items")
	}
	for {
		mems++
		if buf[p] == 0 {
			break
		}
		var nb [8]byte
		mems++ // clear namebuf
		j := 0
		for ; j < 8; j++ {
			mems++
			if isspace(buf[p+j]) {
				break
			}
			if buf[p+j] == ':' || buf[p+j] == '|' {
				panicf(p, buf, "Illegal character in item name")
			}
			mems++
			nb[j] = buf[p+j]
		}
		if j == 8 && !isspace(buf[p+j]) {
			panicf(p, buf, "Item name too long")
		}
		l, r := packLR(&nb)
		mems += 2
		setLname(lastItm<<2, l)
		setRname(lastItm<<2, r)
		// check for duplicate item name
		var k int
		for k = lastItm - 1; k != 0; k-- {
			mems++
			if lname(k<<2) != l {
				continue
			}
			if rname(k<<2) == r {
				break
			}
		}
		if k != 0 {
			panicf(p, buf, "Duplicate item name")
		}
		lastItm++
		if lastItm > maxCols {
			panicf(p, buf, "Too many items")
		}
		for p += j + 1; ; p++ {
			mems++
			if !isspace(buf[p]) {
				break
			}
		}
		if buf[p] == '|' {
			if second != maxCols {
				panicf(p, buf, "Item name line contains | twice")
			}
			second = lastItm
			for p++; ; p++ {
				mems++
				if !isspace(buf[p]) {
					break
				}
			}
		}
	}
}

func inputOptions() {
	for {
		buf, slen, ok := nextLine()
		if !ok {
			break
		}
		mems++
		p := slen - 1
		if buf[p] != '\n' {
			panicf(p, buf, "Option line too long")
		}
		for p = 0; ; p++ {
			mems++
			if !isspace(buf[p]) {
				break
			}
		}
		if buf[p] == '|' || buf[p] == 0 {
			continue
		}
		i := lastNode // the spacer at the left of this option
		pp := 0
		for buf[p] != 0 {
			var nb [8]byte
			mems++ // clear namebuf
			j := 0
			for ; j < 8; j++ {
				mems++
				if isspace(buf[p+j]) || buf[p+j] == ':' {
					break
				}
				mems++
				nb[j] = buf[p+j]
			}
			if j == 0 {
				panicf(p, buf, "Empty item name")
			}
			if j == 8 && !isspace(buf[p+j]) && buf[p+j] != ':' {
				panicf(p, buf, "Item name too long")
			}
			l, r := packLR(&nb)
			// Create a node for the item named in buf[p].
			var k int
			for k = (lastItm - 1) << 2; k != 0; k -= 4 {
				mems++
				if lname(k) != l {
					continue
				}
				if rname(k) == r {
					break
				}
			}
			if k == 0 {
				panicf(p, buf, "Unknown item name")
			}
			mems++
			if pos(k) > i {
				panicf(p, buf, "Duplicate item name in this option")
			}
			lastNode++
			if lastNode == maxNodes {
				panicf(p, buf, "Too many nodes")
			}
			mems++
			t := size(k) // how many previous options used this item
			mems++
			nd[lastNode].itm = int32(k >> 2)
			nd[lastNode].loc = int32(t)
			if (k >> 2) < second {
				pp = 1
			}
			mems++
			setSize(k, t+1)
			setPos(k, lastNode)
			// color
			if buf[p+j] != ':' {
				mems++
				nd[lastNode].clr = 0
			} else if k >= second {
				mems++
				sp1 := isspace(buf[p+j+1])
				if sp1 {
					panicf(p, buf, "Color must be a single character")
				}
				mems++
				if !isspace(buf[p+j+2]) {
					panicf(p, buf, "Color must be a single character")
				}
				mems++
				nd[lastNode].clr = int32(buf[p+j+1])
				p += 2
			} else {
				panicf(p, buf, "Primary item must be uncolored")
			}
			for p += j + 1; ; p++ {
				mems++
				if !isspace(buf[p]) {
					break
				}
			}
		}
		if pp == 0 {
			if vbose&showWarnings != 0 {
				fmt.Fprintf(os.Stderr, "Option ignored (no primary items): %s",
					trimToNul(buf))
			}
			for lastNode > i {
				// Remove lastNode from its item list.
				mems++
				k := int(nd[lastNode].itm) << 2
				mems += 2
				setSize(k, size(k)-1)
				setPos(k, i-1)
				lastNode--
			}
		} else {
			mems++
			nd[i].loc = int32(lastNode - i) // complete the previous spacer
			lastNode++                      // create the next spacer
			if lastNode == maxNodes {
				panicf(p, buf, "Too many nodes")
			}
			options++
			mems++
			nd[lastNode].itm = int32(i + 1 - lastNode)
			nd[lastNode].spr = int32(options) // option number, debugging only
		}
	}
	// Initialize item.
	active, itemlen = lastItm-1, lastItm-1
	k, j := 0, primExtra
	for ; k < itemlen; k++ {
		mems += 2
		item[k] = int32(j)
		if k+2 < second {
			j += primExtra + size((k+1)<<2)
		} else {
			j += secondExtra + size((k+1)<<2)
		}
	}
	setlen = j - 4 // a decent upper bound
	if second == maxCols {
		osecond, second = active, j
	} else {
		osecond = second - 1
	}
	// Expand set: move names and sizes to their final positions.
	for ; k != 0; k-- {
		mems++
		j = int(item[k-1])
		if k == second {
			second = j // second is now an index into set
		}
		mems += 2
		setSize(j, size(k<<2))
		if size(j) == 0 && k <= osecond {
			baditem = k
		}
		mems++
		setPos(j, k-1)
		mems += 2
		setRname(j, rname(k<<2))
		setLname(j, lname(k<<2))
	}
	// Adjust nd.
	for k = 1; k < lastNode; k++ {
		mems++
		if nd[k].itm < 0 {
			continue // skip a spacer
		}
		mems++
		j = int(item[int(nd[k].itm)-1])
		ii := j + int(nd[k].loc)
		mems++
		nd[k].itm = int32(j)
		nd[k].loc = int32(ii)
		mems++
		set[ii] = int32(k)
	}
}

func trimToNul(b []byte) string {
	if i := indexByte(b, 0); i >= 0 {
		return string(b[:i])
	}
	return string(b)
}

// ---------------------------------------------------------------------------
// The dancing.
// ---------------------------------------------------------------------------

// hide removes all incompatible options remaining in the set of item c.
// If check is true, it returns false when its actions would make some
// primary item uncoverable (and primary items left with a single option
// are pushed onto the force stack). When color != 0, item c is secondary
// and options whose color matches are retained.
func hide(c, color, check int) bool {
	mems++
	for rr, s := c, c+size(c); rr < s; rr++ {
		mems++
		tt := int(set[rr])
		match := false
		if color != 0 {
			mems++
			match = int(nd[tt].clr) == color
		}
		if color == 0 || !match {
			// Remove option tt from the other sets it's in.
			for nn := tt + 1; nn != tt; {
				mems++
				uu, vv := int(nd[nn].itm), int(nd[nn].loc)
				if uu < 0 {
					nn += uu
					continue
				}
				mems++
				if pos(uu) < oactive {
					mems++
					ss := size(uu) - 1
					if ss <= 1 && check != 0 && uu < second && pos(uu) < active {
						if ss == 0 {
							if vbose&showChoices != 0 && level < showChoicesMax {
								fmt.Fprintf(os.Stderr, " can't cover")
								printItemName(uu, os.Stderr)
								fmt.Fprintf(os.Stderr, "\n")
							}
							return false
						}
						mems++
						force[forced] = int32(uu)
						forced++
					}
					mems++
					nnp := int(set[uu+ss])
					mems++
					setSize(uu, ss)
					mems += 2
					set[uu+ss] = int32(nn)
					set[vv] = int32(nnp)
					mems += 2
					nd[nn].loc = int32(uu + ss)
					nd[nnp].loc = int32(vv)
					updates++
				}
				nn++
			}
		}
	}
	return true
}

func solve() {
	var (
		c, cc, k, p, pp, q, s, t int
		curChoice, curNode       int
		bestItm                  int
	)
	level = 0
forward:
	nodes++
	if vbose&showProfile != 0 {
		profile[level]++
	}
	if sanityChecking {
		sanity()
	}
	// Maybe do a forced move.
	for forced != 0 {
		mems++
		forced--
		bestItm = int(force[forced])
		mems++
		if pos(bestItm) < active {
			goto doForced
		}
	}
	// Do special things if enough mems have accumulated.
	if delta != 0 && mems >= thresh {
		thresh += delta
		if vbose&showFullStat != 0 {
			printState()
		} else {
			printProgress()
		}
	}
	if mems >= timeout {
		fmt.Fprintf(os.Stderr, "TIMEOUT!\n")
		goto done
	}
	// Set bestItm to the best item for branching.
	{
		t, tmems = maxNodes, mems
		if vbose&showDetails != 0 && level < showChoicesMax && level >= maxl-showChoicesGap {
			fmt.Fprintf(os.Stderr, "Level %d:", level)
		}
		for k = 0; k < active; k++ {
			mems++
			if int(item[k]) >= second {
				continue
			}
			mems++
			s = size(int(item[k]))
			if vbose&showDetails != 0 && level < showChoicesMax && level >= maxl-showChoicesGap {
				printItemName(int(item[k]), os.Stderr)
				fmt.Fprintf(os.Stderr, "(%d)", s)
			}
			if s <= 1 {
				if s == 0 {
					fmt.Fprintf(os.Stderr, "I'm confused.\n") // hide missed this
				} else {
					mems++
					force[forced] = item[k]
					forced++
				}
			} else if s <= t {
				if s < t {
					bestItm, t = int(item[k]), s
				} else if int(item[k]) < bestItm {
					bestItm = int(item[k]) // suggested by P. Weigel
				}
			}
		}
		if vbose&showDetails != 0 && level < showChoicesMax && level >= maxl-showChoicesGap {
			if forced != 0 {
				fmt.Fprintf(os.Stderr, " found %d forced\n", forced)
			} else if t == maxNodes {
				fmt.Fprintf(os.Stderr, " solution\n")
			} else {
				fmt.Fprintf(os.Stderr, " branching on")
				printItemName(bestItm, os.Stderr)
				fmt.Fprintf(os.Stderr, "(%d)\n", t)
			}
		}
		if t > maxdeg && t < maxNodes && forced == 0 {
			maxdeg = t
		}
		if shapeFile != nil {
			if t == maxNodes {
				fmt.Fprintf(shapeFile, "sol\n")
			} else {
				fmt.Fprintf(shapeFile, "%d", t)
				printItemName(bestItm, shapeFile)
				fmt.Fprintf(shapeFile, "\n")
			}
			shapeFile.Sync()
		}
		cmems += mems - tmems
	}
	if forced != 0 {
		mems++
		forced--
		bestItm = int(force[forced])
		goto doForced
	}
	if t == maxNodes {
		// Visit a solution and goto backup.
		count++
		if spacing != 0 && count%uint64(spacing) == 0 {
			fmt.Fprintf(out, "%d:\n", count)
			for k = 0; k < level; k++ {
				printOption(int(choice[k]), out)
			}
			out.Flush()
		}
		if count >= maxcount {
			goto done
		}
		goto backup
	}
	// Swap bestItm out of the active list.
	p = active - 1
	active = p
	mems++
	pp = pos(bestItm)
	mems++
	cc = int(item[p])
	mems += 2
	item[p] = int32(bestItm)
	item[pp] = int32(cc)
	mems += 2
	setPos(cc, pp)
	setPos(bestItm, p)
	updates++

	oactive = active
	hide(bestItm, 0, 0) // hide its options
	curChoice = bestItm
	// Save the currently active sizes.
	if saveptr+active > maxsaveptr {
		if saveptr+active >= saveSize {
			fmt.Fprintf(os.Stderr, "Stack overflow (savesize=%d)!\n", saveSize)
			os.Exit(-5)
		}
		maxsaveptr = saveptr + active
	}
	for p = 0; p < active; p++ {
		mems += 3
		savestack[saveptr+p].l = item[p]
		savestack[saveptr+p].r = int32(size(int(item[p])))
	}
	saveptr += active
	mems++
	saved[level+1] = int32(saveptr)

advance:
	mems += 2
	curNode = int(set[curChoice])
	choice[level] = int32(curNode)
	if vbose&showChoices != 0 && level < showChoicesMax {
		fmt.Fprintf(os.Stderr, "L%d:", level)
		printOption(curNode, os.Stderr)
	}
	// Swap out all other items of curNode.
	p = active
	oactive = active
	for q = curNode + 1; q != curNode; {
		mems++
		c = int(nd[q].itm)
		if c < 0 {
			q += c
		} else {
			mems++
			pp = pos(c)
			if pp < p {
				p--
				mems++
				cc = int(item[p])
				mems += 2
				item[p] = int32(c)
				item[pp] = int32(cc)
				mems += 2
				setPos(cc, pp)
				setPos(c, p)
				updates++
			}
			q++
		}
	}
	active = p
	// Hide the other options of those items, or goto abort.
	for q = curNode + 1; q != curNode; {
		mems++
		cc = int(nd[q].itm)
		if cc < 0 {
			q += cc
		} else {
			if cc < second {
				if !hide(cc, 0, 1) {
					forced = 0
					goto abort
				}
			} else { // do nothing if cc already purified
				mems++
				pp = pos(cc)
				if pp < oactive {
					mems++
					if !hide(cc, int(nd[q].clr), 1) {
						forced = 0
						goto abort
					}
				}
			}
			q++
		}
	}
	level++
	if level > maxl {
		if level >= maxLevel {
			fmt.Fprintf(os.Stderr, "Too many levels!\n")
			os.Exit(-4)
		}
		maxl = level
	}
	goto forward

backup:
	if level == 0 {
		goto done
	}
	level--
	mems += 2
	curNode = int(choice[level])
	bestItm = int(nd[curNode].itm)
	curChoice = int(nd[curNode].loc)
abort:
	mems++
	if curChoice+1 >= bestItm+size(bestItm) {
		goto backup
	}
	// Restore the currently active sizes.
	mems++
	saveptr = int(saved[level+1])
	mems++
	active = saveptr - int(saved[level])
	for p = -active; p < 0; p++ {
		mems += 2
		setSize(int(savestack[saveptr+p].l), int(savestack[saveptr+p].r))
	}
	curChoice++
	goto advance

doForced:
	if vbose&showChoices != 0 && level < showChoicesMax {
		fmt.Fprintf(os.Stderr, "(forcing)\n")
	}
	// Swap bestItm out of the active list.
	p = active - 1
	active = p
	mems++
	pp = pos(bestItm)
	mems++
	cc = int(item[p])
	mems += 2
	item[p] = int32(bestItm)
	item[pp] = int32(cc)
	mems += 2
	setPos(cc, pp)
	setPos(bestItm, p)
	updates++

	oactive = active
	hide(bestItm, 0, 0)
	curChoice = bestItm
	mems++
	saved[level+1] = int32(saveptr) // nothing placed on savestack
	goto advance

done:
}

// ---------------------------------------------------------------------------
// Command line and main.
// ---------------------------------------------------------------------------

func processCommandLine() {
	args := os.Args
	k := 0
	for j := len(args) - 1; j >= 1; j-- {
		a := args[j]
		if len(a) == 0 {
			k = 1
			continue
		}
		rest := a[1:]
		switch a[0] {
		case 'v':
			k |= scanInt(rest, &vbose)
		case 'm':
			k |= scanInt(rest, &spacing)
		case 's':
			k |= scanInt(rest, &randomSeed)
			randomizing = true
		case 'd':
			k |= scanUint(rest, &delta)
			thresh = delta
		case 'c':
			k |= scanInt(rest, &showChoicesMax)
		case 'C':
			k |= scanInt(rest, &showLevelsMax)
		case 'l':
			k |= scanInt(rest, &showChoicesGap)
		case 't':
			k |= scanUint(rest, &maxcount)
		case 'T':
			k |= scanUint(rest, &timeout)
		case 'S':
			shapeName = rest
			f, err := os.Create(shapeName)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Sorry, I can't open file `%s' for writing!\n", shapeName)
			} else {
				shapeFile = f
			}
		default:
			k = 1
		}
	}
	if k != 0 {
		fmt.Fprintf(os.Stderr, "Usage: %s [v<n>] [m<n>] [s<n>] [d<n>]"+
			" [c<n>] [C<n>] [l<n>] [t<n>] [T<n>] [S<bar>] < foo.dlx\n", args[0])
		os.Exit(-1)
	}
	if randomizing {
		gbInitRand(int64(randomSeed))
	}
}

func scanInt(s string, dst *int) int {
	v, err := strconv.Atoi(s)
	if err != nil {
		return 1
	}
	*dst = v
	return 0
}

func scanUint(s string, dst *uint64) int {
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return 1
	}
	*dst = uint64(v)
	return 0
}

func main() {
	nd = make([]node, maxNodes)
	item = make([]int32, maxCols)
	set = make([]int32, maxNodes+maxExtra*maxCols)
	force = make([]int32, maxCols)
	choice = make([]int32, maxLevel)
	saved = make([]int32, maxLevel+1)
	savestack = make([]twoints, saveSize)
	profile = make([]uint64, maxLevel)

	reader = bufio.NewReader(os.Stdin)
	out = bufio.NewWriter(os.Stdout)
	defer out.Flush()

	processCommandLine()
	inputItemNames()
	inputOptions()

	if vbose&showBasics != 0 {
		fmt.Fprintf(os.Stderr,
			"(%d options, %d+%d items, %d entries successfully read)\n",
			options, osecond, itemlen-osecond, lastNode)
	}
	if vbose&showTots != 0 {
		fmt.Fprintf(os.Stderr, "Item totals:")
		for k := 0; k < itemlen; k++ {
			if k == second {
				fmt.Fprintf(os.Stderr, " |")
			}
			fmt.Fprintf(os.Stderr, " %d", size(int(item[k])))
		}
		fmt.Fprintf(os.Stderr, "\n")
	}

	imems, mems = mems, 0
	if baditem != 0 {
		if vbose&showChoices != 0 {
			fmt.Fprintf(os.Stderr, "Item")
			printItemName(int(item[baditem-1]), os.Stderr)
			fmt.Fprintf(os.Stderr, " has no options!\n")
		}
	} else {
		if randomizing {
			for k := active; k > 1; {
				mems += 4
				j := int(gbUnifRand(int64(k)))
				k--
				mems += 4
				t := int(item[j])
				item[j] = item[k]
				item[k] = int32(t)
				mems += 2
				setPos(t, k)
				setPos(int(item[j]), j)
			}
		}
		solve()
	}

	if vbose&showProfile != 0 {
		printProfile()
	}
	if vbose&showMaxDeg != 0 {
		fmt.Fprintf(os.Stderr, "The maximum branching degree was %d.\n", maxdeg)
	}
	if vbose&showBasics != 0 {
		ss := "s"
		if count == 1 {
			ss = ""
		}
		fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d+%d mems,",
			count, ss, imems, mems)
		bytes = uint64((itemlen+setlen)*4 + lastNode*16 + 2*maxl*4 + maxsaveptr*8)
		fmt.Fprintf(os.Stderr, " %d updates, %d bytes, %d nodes,",
			updates, bytes, nodes)
		ccost := uint64(0)
		if mems != 0 {
			ccost = (200*cmems + mems) / (2 * mems)
		}
		fmt.Fprintf(os.Stderr, " ccost %d%%.\n", ccost)
	}
	if sanityChecking {
		fmt.Fprintf(os.Stderr, "sanity_checking was on!\n")
	}
	if shapeFile != nil {
		shapeFile.Close()
	}
}
