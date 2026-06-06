package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
)

// Tunable capacities (the @d constants of the original program).
const (
	maxStage = 500      // at most this many options in a solution
	maxLevel = 32000    // at most this many levels in the (binary) search tree
	maxCols  = 100000   // at most this many items
	maxNodes = 10000000 // at most this many matrix cells
	saveSize = 10000000 // at most this many entries on the savestack

	// During input each item occupies ipropcount set entries. In the final
	// layout a primary item reserves primExtra entries below its base
	// (size, pos, rname, lname, slack, bound) and a secondary item reserves
	// secondExtra (size, pos, rname, lname). The original also kept a float
	// "weight" slot, but those weights are never read by the search, so they
	// are omitted here.
	primExtra   = 6
	secondExtra = 4
	maxExtra    = 6
	ipropcount  = 6

	infSize = 0x7fffffff // sentinel "no item to branch on" => a solution
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

const sanityChecking = false

// node is one cell of the matrix.
type node struct {
	itm, loc, clr, spr int32
}

// threeints is one savestack entry: an item, its size, and (for a primary
// item) its residual bound.
type threeints struct {
	l, s, b int32
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
	maxcount       uint64
	nodeTimeout    uint64
	delta          uint64
	thresh         uint64
	shapeName      string
	shapeFile      *os.File
	shapeOut       *bufio.Writer

	// statistics
	maxl    int
	maxs    int
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
	baditem  int
	osecond  int

	// force stack of items reducible to forced choices (each pushed u times)
	force    []int32
	forced   int
	toughItm int

	// depth-first search state
	choice     []int32 // option chosen at each level (for tracing)
	deg        []int32 // branching degree at each level (for tracing)
	included   []int32 // option included at each stage (for solution output)
	stagelevel []int32 // stage corresponding to each level (for tracing)
	levelstage []int32 // most recent level at each stage (for tracing)
	savestack  []threeints
	saveptr    int
	profile    []uint64

	in  *bufio.Reader
	out *bufio.Writer
)

func allocate() {
	nd = make([]node, maxNodes)
	item = make([]int32, maxCols)
	set = make([]int32, maxNodes+maxExtra*maxCols)
	force = make([]int32, maxCols)
	choice = make([]int32, maxLevel)
	deg = make([]int32, maxLevel)
	included = make([]int32, maxStage)
	stagelevel = make([]int32, maxLevel)
	levelstage = make([]int32, maxStage)
	savestack = make([]threeints, saveSize)
	profile = make([]uint64, maxStage)
}

// Sparse-set field accessors for an item x (an index into set):
//
//	set[x-1]=size  set[x-2]=pos  set[x-3]=rname  set[x-4]=lname
//	set[x-5]=slack  set[x-6]=bound   (slack/bound only for primary items)
func size(x int) int  { return int(set[x-1]) }
func pos(x int) int   { return int(set[x-2]) }
func rname(x int) int { return int(set[x-3]) }
func lname(x int) int { return int(set[x-4]) }
func slack(x int) int { return int(set[x-5]) }
func bound(x int) int { return int(set[x-6]) }

func setSize(x, v int)  { set[x-1] = int32(v) }
func setPos(x, v int)   { set[x-2] = int32(v) }
func setRname(x, v int) { set[x-3] = int32(v) }
func setLname(x, v int) { set[x-4] = int32(v) }
func setSlack(x, v int) { set[x-5] = int32(v) }
func setBound(x, v int) { set[x-6] = int32(v) }

func isspace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
}

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

// printOption prints the option containing node p by its item names. showpos>0
// also prints the option's position in p's item list; showpos==0 ends the line;
// showpos<0 omits the trailing newline.
func printOption(p int, w io.Writer, showpos int) {
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
	switch {
	case showpos > 0:
		fmt.Fprintf(w, " (%d of %d)\n", k-x+1, size(x))
	case showpos == 0:
		fmt.Fprintln(w)
	}
}

func confusion(msg string) {
	fmt.Fprintf(os.Stderr, "%s!\n", msg)
}

func printProfile() {
	fmt.Fprintln(os.Stderr, "Profile:")
	for s := 0; s <= maxs; s++ {
		fmt.Fprintf(os.Stderr, "%3d: %d\n", s, profile[s])
	}
}

func printState(level int) {
	fmt.Fprintf(os.Stderr, "Current state (level %d):\n", level)
	for l := 0; l < level; l++ {
		if levelstage[stagelevel[l]] != int32(l) {
			fmt.Fprint(os.Stderr, "~")
		}
		printOption(int(choice[l]), os.Stderr, -1)
		fmt.Fprintf(os.Stderr, " (of %d)\n", deg[l])
		if l >= showLevelsMax {
			fmt.Fprintln(os.Stderr, " ...")
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
	for l := 0; l < level; l++ {
		if l < showLevelsMax {
			tilde := "~"
			if levelstage[stagelevel[l]] == int32(l) {
				tilde = ""
			}
			fmt.Fprintf(os.Stderr, " %s%d", tilde, deg[l])
		}
		if levelstage[stagelevel[l]] == int32(l) {
			k, d := 1, int(deg[l])
			for ll := l - 1; ll >= 0 && stagelevel[ll] == stagelevel[l]; ll-- {
				k, d = k+1, d+1
			}
			fd *= float64(d)
			f += float64(k-1) / fd
		}
		if l >= showLevelsMax && !ds {
			ds = true
			fmt.Fprint(os.Stderr, "...")
		}
	}
	fmt.Fprintf(os.Stderr, " %.5f\n", f+0.5/fd)
}

func sanity() {
	for k := 0; k < itemlen; k++ {
		x := int(item[k])
		if pos(x) != k {
			fmt.Fprint(os.Stderr, "Bad pos field of item")
			printItemName(x, os.Stderr)
			fmt.Fprintf(os.Stderr, " (%d != %d, %d)!\n", k, pos(x), x)
		}
	}
}
