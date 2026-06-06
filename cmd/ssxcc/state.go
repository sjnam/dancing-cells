package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
)

// Tunable capacities (the @d constants of the original program).
const (
	maxLevel = 5000     // at most this many options in a solution
	maxCols  = 100000   // at most this many items
	maxNodes = 10000000 // at most this many matrix cells; also the "no item" sentinel
	saveSize = 10000000 // at most this many entries on the savestack

	primExtra   = 4 // extra set entries reserved for each primary item
	secondExtra = 4 // and for each secondary item
	maxExtra    = 4 // max(primExtra, secondExtra)
)

// vbose bit codes.
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

const sanityChecking = false // set true to verify invariants while debugging

// node is one cell of the matrix. itm and clr are fixed after input; loc
// changes as options dance in and out of an item's active set. spr only ever
// holds an option number, as a debugging aid.
type node struct {
	itm, loc, clr, spr int32
}

// twoints is one savestack entry: an item and the size to restore.
type twoints struct {
	l, r int32
}

var (
	// configuration set from the command line
	randomSeed     int
	randomizing    bool
	vbose          = showBasics + showWarnings
	spacing        int
	showChoicesMax = 1 << 30
	showChoicesGap = 1 << 30
	showLevelsMax  = 1 << 30
	maxcount       uint64 // 0 means unlimited
	nodeTimeout    uint64 // 0 means unlimited
	delta          uint64 // progress report every delta nodes; 0 disables
	thresh         uint64
	shapeName      string
	shapeFile      *os.File
	shapeOut       *bufio.Writer

	// statistics
	maxl    int
	count   uint64
	options uint64
	updates uint64
	nodes   uint64
	maxdeg  int

	// the matrix, items, and the sparse-set "set" array
	nd       []node
	lastNode int
	item     []int32
	second   = maxCols
	lastItm  int
	set      []int32
	itemlen  int
	setlen   int
	active   int
	oactive  int
	baditem  int
	osecond  int

	// the force stack of items now reducible to a single choice
	force  []int32
	forced int

	// depth-first search state
	choice    []int32
	saved     []int32
	savestack []twoints
	saveptr   int
	profile   []uint64

	in  *bufio.Reader
	out *bufio.Writer
)

// allocate reserves the working arrays once at startup.
func allocate() {
	nd = make([]node, maxNodes)
	item = make([]int32, maxCols)
	set = make([]int32, maxNodes+maxExtra*maxCols)
	force = make([]int32, maxCols)
	choice = make([]int32, maxLevel)
	saved = make([]int32, maxLevel+1)
	savestack = make([]twoints, saveSize)
	profile = make([]uint64, maxLevel)
}

// Sparse-set field accessors for an item x (an index into set):
//
//	set[x-1] = size   set[x-2] = pos   set[x-3] = rname   set[x-4] = lname
func size(x int) int  { return int(set[x-1]) }
func pos(x int) int   { return int(set[x-2]) }
func rname(x int) int { return int(set[x-3]) }
func lname(x int) int { return int(set[x-4]) }

func setSize(x, v int)  { set[x-1] = int32(v) }
func setPos(x, v int)   { set[x-2] = int32(v) }
func setRname(x, v int) { set[x-3] = int32(v) }
func setLname(x, v int) { set[x-4] = int32(v) }

func isspace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
}

// packLR encodes up to 8 name bytes into two little-endian 32-bit ints,
// matching the C union {str[8]; struct{l,r int}} on a little-endian host.
func packLR(b *[8]byte) (int, int) {
	l := int(b[0]) | int(b[1])<<8 | int(b[2])<<16 | int(b[3])<<24
	r := int(b[4]) | int(b[5])<<8 | int(b[6])<<16 | int(b[7])<<24
	return l, r
}

func decodeName(l, r int) string {
	b := [8]byte{
		byte(l), byte(l >> 8), byte(l >> 16), byte(l >> 24),
		byte(r), byte(r >> 8), byte(r >> 16), byte(r >> 24),
	}
	n := 0
	for n < 8 && b[n] != 0 {
		n++
	}
	return string(b[:n])
}

func printItemName(k int, w io.Writer) {
	fmt.Fprintf(w, " %s", decodeName(lname(k), rname(k)))
}

// printOption prints the option containing node p, identified by its item
// names, followed by the option's position within p's item list.
func printOption(p int, w io.Writer) {
	x := int(nd[p].itm)
	if p >= lastNode || x <= 0 {
		fmt.Fprintf(os.Stderr, "Illegal option %d!\n", p)
		return
	}
	for q := p; ; {
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
			k := int(nd[q].loc)
			fmt.Fprintf(w, " (%d of %d)\n", k-x+1, size(x))
			return
		}
	}
}

func printState(level int) {
	fmt.Fprintf(os.Stderr, "Current state (level %d):\n", level)
	for l := range level {
		printOption(int(choice[l]), os.Stderr)
		if l >= showLevelsMax {
			fmt.Fprintf(os.Stderr, " ...\n")
			break
		}
	}
	fmt.Fprintf(os.Stderr, " %d solutions, %d nodes, and max level %d so far.\n",
		count, nodes, maxl)
}

func printProgress(level int) {
	fmt.Fprintf(os.Stderr, " after %d nodes: %d sols,", nodes, count)
	f, fd := 0.0, 1.0
	ds := false
	for l := range level {
		c := int(nd[choice[l]].itm)
		d := size(c)
		k := int(nd[choice[l]].loc) - c + 1
		fd *= float64(d)
		f += float64(k-1) / fd
		if l < showLevelsMax {
			fmt.Fprintf(os.Stderr, " %c%c", radixDigit(k), radixDigit(d))
		} else if !ds {
			ds = true
			fmt.Fprint(os.Stderr, "...")
		}
	}
	fmt.Fprintf(os.Stderr, " %.5f\n", f+0.5/fd)
}

func radixDigit(k int) byte {
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
	fmt.Fprintln(os.Stderr, "Profile:")
	for l := 0; l <= maxl; l++ {
		fmt.Fprintf(os.Stderr, "%3d: %d\n", l, profile[l])
	}
}

// sanity verifies redundant invariants of the data structure (debug only).
func sanity() {
	for k := range itemlen {
		x := int(item[k])
		if pos(x) != k {
			fmt.Fprint(os.Stderr, "Bad pos field of item")
			printItemName(x, os.Stderr)
			fmt.Fprintf(os.Stderr, " (%d,%d)!\n", k, x)
		}
	}
	qq := 0
	for i := 0; i < lastNode; i++ {
		l, r := int(nd[i].itm), int(nd[i].loc)
		switch {
		case l <= 0:
			if int(nd[i+r+1].itm) != -r {
				fmt.Fprintf(os.Stderr, "Bad spacer in nodes %d, %d!\n", i, i+r+1)
			}
			qq = 0
		case l > r:
			fmt.Fprintf(os.Stderr, "itm>loc in node %d!\n", i)
		default:
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
