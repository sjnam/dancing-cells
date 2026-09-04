\datethis
\def\title{MacMahon Bricks}

@* Introduction.
Exercise 7.2.2.1--147 takes the thirty coloured cubes of exercise 146 and asks
what solids they can build. A ``brick'' of size $l\times m\times n$ is an
assembly of $l\cdot m\cdot n$ of the cubes in which touching faces agree in
colour and each of the six outer sides is a single solid colour. Part~(a) asks
for a brick of size $2\times3\times5$ that uses all thirty; part~(b) asks for a
catalogue of every brick there is.

The answer supplies that catalogue: for each shape and each pattern of face
colours it lists how many essentially different bricks have $1$, $2$, $4$ or $8$
automorphisms. Twenty-four such lines are printed. This program computes them
all, together with the smaller claims the answer makes along the way.

Everything here follows the answer's own recipe. Positions and faces are named
by the even/odd coordinates of exercise 145; the exact cover problem is the one
answer 147(b) describes; and the count is divided by 720 in the way the answer
prescribes, by leaving only a single option for the first cell.

@c
package main

import (
	"flag"
	"fmt"
	"sort"
	"strings"

	cells "github.com/sjnam/dancing-cells"
)

@<Declarations@>
@<Functions@>

func main() {
	@<Read the command line@>
	@<Do what the mode asks@>
}

@ Five modes. The census checks the piece set on its own, before anything is
built out of it. The printed mode reads back the two arrays that answer 147(a)
displays. The catalogue mode is the main event. The near mode looks at the two
shapes the answer mentions in its closing parenthesis, and the six mode counts
the bricks whose outer sides show six different colours---a statistic that turns
out to be worth having.
@<Read the command line@>=
mode := flag.String("mode", "catalog", "census, printed, catalog, near, six, or solve")
size := flag.String("b", "2x2x4", "brick size lxmxn")
nopin := flag.Bool("nopin", false, "keep all 720 options for the first cell")
dump := flag.Bool("dump", false, "list every essentially different brick")
flag.Parse()
noPin, dumpAll = *nopin, *dump
var l, m, n int
fmt.Sscanf(*size, "%dx%dx%d", &l, &m, &n)

@ @<Do what the mode asks@>=
switch *mode {
case "census":
	census()
case "printed":
	printedCheck()
case "near":
	nearMiss()
case "six":
	distinctSides(brick{l, m, n})
case "solve":
	report(brick{l, m, n})
case "catalog":
	@<Run every shape that could possibly work@>
default:
	fmt.Println("unknown mode")
}

@ A brick can hold at most thirty cubes, so $lmn\le30$; nothing else needs to be
assumed. Shapes with no solutions print one line and pass by, which is how the
absence of $3\times3\times3$---and of $2\times2\times6$ and $2\times2\times7$,
which the answer's catalogue also passes over in silence---gets checked.
@<Run every shape that could possibly work@>=
for i := 1; i <= 30; i++ {
	for j := i; j <= 30; j++ {
		for k := j; k <= 30; k++ {
			if i*j*k <= 30 {
				report(brick{i, j, k})
			}
		}
	}
}

@ @<Declarations@>=
var noPin, dumpAll bool

@* The thirty cubes.
Answer 146(b) counts the cubes by pairing up the colours: for each way of
splitting $\{a,b,c,d,e,f\}$ into three opposite pairs there are two cubes,
mirror images of each other, and $15\times2=30$. It also names them. The cube
called $uu'vv'ww'$ is the one that can be placed with $u$ on top, $u'$ on the
bottom, $v$ in front, $v'$ in the back, $w$ at the left and $w'$ at the right.

Reading the constraints the answer gives, the name is built like this: $a$ is
always on top, since it is the smallest colour; the colour opposite it may be
any of the other five; of the four that remain the smallest goes in front and
its partner in the back; and the last pair goes left and right, either way
round. That last choice is exactly the choice of mirror image, and $5\times3
\times2=30$.

I keep a cube as the colour on each of its six faces, with the faces indexed by
direction.
@<Declarations@>=
const (
	dTop = iota
	dBot
	dFront
	dBack
	dLeft
	dRight
)

var dvec = [6][3]int{{0, 0, 1}, {0, 0, -1}, {0, -1, 0}, {0, 1, 0}, {-1, 0, 0}, {1, 0, 0}}

type cube struct {
	name string
	col  [6]byte
}

@ @<Functions@>=
func cubes() []cube {
	var out []cube
	@<Take each colour in turn as the one opposite \\{a}@>
	return out
}

@ The four colours left after $a$ and its opposite are chosen have their
smallest member in front; the partner of that one may be any of the other
three; and the two that then remain go left and right in either order.
@<Take each colour in turn as the one opposite \\{a}@>=
for up := byte('b'); up <= 'f'; up++ {
	four := others('a', up, 0, 0)
	for _, vp := range four[1:] {
		last := others('a', up, four[0], vp)
		for _, flip := range []bool{false, true} {
			w, wp := last[0], last[1]
			if flip {
				w, wp = wp, w
			}
			c := cube{col: [6]byte{'a', up, four[0], vp, w, wp}}
			c.name = string(c.col[:])
			out = append(out, c)
		}
	}
}

@ @<Functions@>=
func others(p, q, r, s byte) []byte {
	var out []byte
	for c := byte('a'); c <= 'f'; c++ {
		if c != p && c != q && c != r && c != s {
			out = append(out, c)
		}
	}
	return out
}

@* Turning a cube over.
The twenty-four rotations of a cube are the signed permutations of the three
axes with determinant $+1$. I store each one as a permutation of the six
directions: entry $d$ says where the face that pointed in direction $d$ ends up.
@<Functions@>=
func rotations() [][6]int {
	var out [][6]int
	for _, p := range axisPerms {
		for s := 0; s < 8; s++ {
			@<Assemble one signed permutation and keep the proper ones@>
		}
	}
	return out
}

@ The sign of the permutation times the product of the reversals is the
determinant, and a reflection is no use here: a cube cannot be turned into its
mirror image by any motion.
@<Assemble one signed permutation and keep the proper ones@>=
det := permSign(p)
var q [6]int
for d := 0; d < 6; d++ {
	var w [3]int
	for a := 0; a < 3; a++ {
		w[a] = dvec[d][p[a]]
		if s&(1<<a) != 0 {
			w[a] = -w[a]
		}
	}
	q[d] = dirOf(w)
}
for a := 0; a < 3; a++ {
	if s&(1<<a) != 0 {
		det = -det
	}
}
if det > 0 {
	out = append(out, q)
}

@ @<Declarations@>=
var axisPerms = [][3]int{{0, 1, 2}, {0, 2, 1}, {1, 0, 2}, {1, 2, 0}, {2, 0, 1}, {2, 1, 0}}

@ @<Functions@>=
func permSign(p [3]int) int {
	s := 1
	for i := 0; i < 3; i++ {
		for j := i + 1; j < 3; j++ {
			if p[i] > p[j] {
				s = -s
			}
		}
	}
	return s
}

func dirOf(v [3]int) int {
	for i, w := range dvec {
		if w == v {
			return i
		}
	}
	panic("not an axis direction")
}

@* Every colouring is a cube.
Thirty cubes with twenty-four orientations each make 720 ways of painting six
distinct colours on six labelled faces---and there are exactly $6!=720$ such
paintings altogether. So the list below should hit every one of them once, and
checking that is a good way to be sure the naming rule was read correctly. If a
cube had been missed, or one counted twice, the collision would show up here
rather than in some later number that nobody could interpret.
@<Declarations@>=
type placement struct {
	name string
	col  [6]byte
}

@ @<Functions@>=
func placements() []placement {
	var out []placement
	for _, c := range cubes() {
		for _, r := range rotations() {
			var col [6]byte
			for d := 0; d < 6; d++ {
				col[r[d]] = c.col[d]
			}
			out = append(out, placement{c.name, col})
		}
	}
	return out
}

func byColour() map[[6]byte]string {
	out := map[[6]byte]string{}
	for _, p := range placements() {
		out[p.col] = p.name
	}
	return out
}

@ The census also looks up the ten cube names that the two answers print, six
of them in answer 146(b) for the row of cubes in $(*)$ and four more in answer
147(a).
@<Functions@>=
func census() {
	cs, pl, bc := cubes(), placements(), byColour()
	fmt.Printf("%d cubes, %d placements, %d distinct face colourings\n",
		len(cs), len(pl), len(bc))
	named := map[string]bool{}
	for _, c := range cs {
		named[c.name] = true
	}
	missing := 0
	for _, w := range printedNames {
		if !named[w] {
			fmt.Printf("  the answers name %s, which I do not have\n", w)
			missing++
		}
	}
	fmt.Printf("all %d names printed in the answers are in the set: %v\n",
		len(printedNames), missing == 0)
}

@ @<Declarations@>=
var printedNames = []string{"aebfcd", "acbfde", "acbdef", "afbdec", "abcedf",
	"aebcfd", "abcefd", "abcdfe", "abcdef", "acbefd"}

@* Coordinates for a brick.
Exercise 145 gives the convention that answer 147(a) calls ideal, and it is:
let the triple $(x,y,z)$ with $0\le x\le2l$, $0\le y\le2m$, $0\le z\le2n$ stand
for a vertex, edge, face or cell of the brick according as it has none, one,
two or three odd coordinates. So the cell $(i,j,k)$ sits at $(2i+1,2j+1,2k+1)$
and its six faces are one step away along each axis.

A brick may have cells missing, which is needed only at the very end, for the
two shapes that come close to a $3\times3\times3$; everywhere else the set of
absent cells is empty.
@<Declarations@>=
type pt [3]int

type brick struct{ l, m, n int }

var skip = map[[3]int]bool{}

@ @<Functions@>=
func (b brick) dims() [3]int { return [3]int{b.l, b.m, b.n} }

func (b brick) eachCell(f func(i, j, k int)) {
	for i := 0; i < b.l; i++ {
		for j := 0; j < b.m; j++ {
			for k := 0; k < b.n; k++ {
				if !skip[[3]int{i, j, k}] {
					f(i, j, k)
				}
			}
		}
	}
}

func (b brick) ncells() int {
	n := 0
	b.eachCell(func(i, j, k int) { n++ })
	return n
}

@ The faces of a cell, in the same order as the directions.
@<Functions@>=
func (b brick) faces(i, j, k int) [6]pt {
	return [6]pt{
		{2*i + 1, 2*j + 1, 2*k + 2},
		{2*i + 1, 2*j + 1, 2 * k},
		{2*i + 1, 2 * j, 2*k + 1},
		{2*i + 1, 2*j + 2, 2*k + 1},
		{2 * i, 2*j + 1, 2*k + 1},
		{2*i + 2, 2*j + 1, 2*k + 1},
	}
}

func fname(p pt) string { return fmt.Sprintf("F%d.%d.%d", p[0], p[1], p[2]) }

@ Listing the face triples in a fixed order gives a canonical way to write a
brick down as a string, which is what the tests for sameness will need.
@<Functions@>=
func (b brick) coords() []pt {
	d := b.dims()
	var out []pt
	for x := 0; x <= 2*d[0]; x++ {
		for y := 0; y <= 2*d[1]; y++ {
			for z := 0; z <= 2*d[2]; z++ {
				if x%2+y%2+z%2 == 2 {
					out = append(out, pt{x, y, z})
				}
			}
		}
	}
	return out
}

@ The outer sides. A face is on the outside when its cell is on the boundary
and the face points away from the brick.
@<Functions@>=
func (b brick) exterior() [6][]pt {
	var out [6][]pt
	b.eachCell(func(i, j, k int) {
		ff := b.faces(i, j, k)
		@<Collect the faces of this cell that face outwards@>
	})
	return out
}

@ @<Collect the faces of this cell that face outwards@>=
if k == b.n-1 {
	out[dTop] = append(out[dTop], ff[dTop])
}
if k == 0 {
	out[dBot] = append(out[dBot], ff[dBot])
}
if j == 0 {
	out[dFront] = append(out[dFront], ff[dFront])
}
if j == b.m-1 {
	out[dBack] = append(out[dBack], ff[dBack])
}
if i == 0 {
	out[dLeft] = append(out[dLeft], ff[dLeft])
}
if i == b.l-1 {
	out[dRight] = append(out[dRight], ff[dRight])
}

@* The exact cover problem.
Answer 147(b) lays the problem out. There is a primary item for every cell, a
secondary item for every one of the thirty cube names, and a secondary item for
every face; an option puts one cube, in one orientation, into one cell, and
colours that cell's six faces. Two cells that share a face therefore have to
agree about its colour, which is the whole point of the colour mechanism.

Six more primary items take care of the outer sides. Each has six options, one
per colour, and the option paints every face on that side the same. The answer
writes one of them out in full: {\tt top 101:c 103:c 105:c 107:c 109:c 301:c
303:c 305:c 307:c 309:c}.
@<Functions@>=
func (b brick) xcc() (string, int) {
	var prim, sec []string
	@<Name the items@>
	var sb strings.Builder
	sb.WriteString(strings.Join(prim, " ") + " | " + strings.Join(sec, " ") + "\n")
	nopt := 0
	@<Write an option for every cube in every cell@>
	@<Write the options that paint the outer sides@>
	return sb.String(), nopt
}

@ @<Name the items@>=
b.eachCell(func(i, j, k int) {
	prim = append(prim, fmt.Sprintf("P%d.%d.%d", i, j, k))
})
prim = append(prim, sideName[:]...)
for _, c := range cubes() {
	sec = append(sec, "N"+c.name)
}
seen := map[string]bool{}
var fs []string
b.eachCell(func(i, j, k int) {
	for _, f := range b.faces(i, j, k) {
		if !seen[fname(f)] {
			seen[fname(f)] = true
			fs = append(fs, fname(f))
		}
	}
})
sort.Strings(fs)
sec = append(sec, fs...)

@ @<Declarations@>=
var sideName = [6]string{"XU", "XD", "XF", "XB", "XL", "XR"}

@ Here is where the factor of 720 comes off. Every permutation of the six
colours carries a brick to a brick, and the permutation is pinned down
completely by what it does to one cube's six faces. So each orbit under those
720 permutations contains exactly one brick whose first cell holds a chosen
placement, and keeping only that option counts each orbit once. The answer says
as much; the program checks it, by solving one case both ways.
@<Write an option for every cube in every cell@>=
pl := placements()
first := true
b.eachCell(func(i, j, k int) {
	ff := b.faces(i, j, k)
	pinned := first && !noPin
	first = false
	for _, p := range pl {
		if pinned && p.col != [6]byte{'a', 'b', 'c', 'd', 'e', 'f'} {
			continue
		}
		fmt.Fprintf(&sb, "P%d.%d.%d N%s", i, j, k, p.name)
		for d := 0; d < 6; d++ {
			fmt.Fprintf(&sb, " %s:%c", fname(ff[d]), p.col[d])
		}
		sb.WriteByte('\n')
		nopt++
	}
})

@ @<Write the options that paint the outer sides@>=
ext := b.exterior()
for d := 0; d < 6; d++ {
	for c := byte('a'); c <= 'f'; c++ {
		sb.WriteString(sideName[d])
		for _, f := range ext[d] {
			fmt.Fprintf(&sb, " %s:%c", fname(f), c)
		}
		sb.WriteByte('\n')
		nopt++
	}
}

@* Reading a solution back.
A solution is easier to think about as the array of answer 147(a): a colour on
every face of the brick, interior and exterior alike. The cube in a cell is
then whatever the six faces around it say it is, so the array carries all the
information there is.
@<Declarations@>=
type tensor struct {
	b   brick
	col map[pt]byte
}

@ @<Functions@>=
func (b brick) solve() []tensor {
	in, _ := b.xcc()
	xc := cells.NewXCC()
	var out []tensor
	for sol := range xc.Dance(strings.NewReader(in)).Solutions {
		t := tensor{b, map[pt]byte{}}
		for _, o := range sol {
			@<Copy this option's face colours into the array@>
		}
		out = append(out, t)
	}
	return out
}

@ @<Copy this option's face colours into the array@>=
for _, it := range o {
	i := strings.IndexByte(it, ':')
	if i < 0 || it[0] != 'F' {
		continue
	}
	var p pt
	fmt.Sscanf(it[1:i], "%d.%d.%d", &p[0], &p[1], &p[2])
	t.col[p] = it[i+1]
}

@* Telling bricks apart.
Two bricks count as the same when one becomes the other under a rotation or
reflection of the box together with a permutation of the colours. The
geometric part is easy to list: an axis may be sent to any axis of the same
length, and any axis may be reversed.
@<Functions@>=
func (b brick) syms() []func(pt) pt {
	d := b.dims()
	var out []func(pt) pt
	for _, s := range axisPerms {
		if d[0] != d[s[0]] || d[1] != d[s[1]] || d[2] != d[s[2]] {
			continue
		}
		for f := 0; f < 8; f++ {
			@<Add the symmetry that permutes by \\{s} and reverses by \\{f}@>
		}
	}
	return out
}

@ @<Add the symmetry that permutes by \\{s} and reverses by \\{f}@>=
sg, fl := s, f
out = append(out, func(p pt) pt {
	var q pt
	for a := 0; a < 3; a++ {
		v := p[sg[a]]
		if fl&(1<<a) != 0 {
			v = 2*d[a] - v
		}
		q[a] = v
	}
	return q
})

@ The colour part is easier still. Renaming the colours in order of first
appearance produces a string that two bricks share exactly when a permutation
of colours turns one into the other; no search is needed.
@<Functions@>=
func relabel(b brick, col map[pt]byte) string {
	seen := map[byte]byte{}
	var sb strings.Builder
	for _, p := range b.coords() {
		c := col[p]
		if _, ok := seen[c]; !ok {
			seen[c] = byte('a' + len(seen))
		}
		sb.WriteByte(seen[c])
	}
	return sb.String()
}

@ So the canonical form of a brick is the least of those strings over all the
symmetries, and its automorphisms are the symmetries that leave the string
alone. For each symmetry there is at most one colour permutation that could
work---the image of a single cube decides it---so the automorphism group is a
subgroup of the geometric one, and a class of bricks accounts for exactly
$G/{\rm Aut}$ of the solutions the search finds.
@<Functions@>=
func (t tensor) canon() (string, int) {
	me := relabel(t.b, t.col)
	best, naut := "", 0
	for _, g := range t.b.syms() {
		img := map[pt]byte{}
		for p, c := range t.col {
			img[g(p)] = c
		}
		s := relabel(t.b, img)
		if best == "" || s < best {
			best = s
		}
		if s == me {
			naut++
		}
	}
	return best, naut
}

@* The face colours.
The answer sorts its catalogue by the pattern of colours on the six outer
sides, written as three pairs: {\tt aa x bb x cc} when the sides come in three
matched pairs, {\tt ab x cd x ef} when all six differ, and so on. The pairs go
in the order of the axes; when two axes have the same length they may be
swapped, so I take whichever order reads smaller once the colours are renamed.
@<Functions@>=
func (t tensor) sidePairs() [3][2]byte {
	d := t.b.dims()
	var pr [3][2]byte
	for a := 0; a < 3; a++ {
		pr[a][0] = t.faceOn(a, 0)
		pr[a][1] = t.faceOn(a, 2*d[a])
		if pr[a][0] > pr[a][1] {
			pr[a][0], pr[a][1] = pr[a][1], pr[a][0]
		}
	}
	return pr
}

func (t tensor) faceOn(a, lim int) byte {
	for _, p := range t.b.coords() {
		if p[a] == lim {
			return t.col[p]
		}
	}
	return 0
}

@ @<Functions@>=
func (t tensor) sides() string {
	d, pr := t.b.dims(), t.sidePairs()
	best := ""
	for _, s := range axisPerms {
		if d[0] != d[s[0]] || d[1] != d[s[1]] || d[2] != d[s[2]] {
			continue
		}
		@<Spell the three pairs out in the order \\{s}@>
	}
	return best
}

@ @<Spell the three pairs out in the order \\{s}@>=
seen := map[byte]byte{}
var sb strings.Builder
for a := 0; a < 3; a++ {
	if a > 0 {
		sb.WriteString(" x ")
	}
	for _, c := range pr[s[a]] {
		if _, ok := seen[c]; !ok {
			seen[c] = byte('a' + len(seen))
		}
		sb.WriteByte(seen[c])
	}
}
if best == "" || sb.String() < best {
	best = sb.String()
}

@ The answer notices something about these patterns: a colour that shows up
twice on the surface always does so on two parallel sides, never on two that
meet. That is a claim about every solution of every case, and it costs nothing
to test it while the solutions go past.
@<Functions@>=
func (t tensor) oppositeOnly() bool {
	pr := t.sidePairs()
	cnt := map[byte]int{}
	for a := 0; a < 3; a++ {
		cnt[pr[a][0]]++
		cnt[pr[a][1]]++
	}
	for c, k := range cnt {
		if k == 1 {
			continue
		}
		if k > 2 || !somePair(pr, c) {
			return false
		}
	}
	return true
}

func somePair(pr [3][2]byte, c byte) bool {
	for a := 0; a < 3; a++ {
		if pr[a][0] == c && pr[a][1] == c {
			return true
		}
	}
	return false
}

@* One line of the catalogue.
Now everything can be put together. For one shape: solve, group the solutions
into classes, and count the classes by pattern and by number of automorphisms,
which is precisely the form the answer's summary takes.
@<Functions@>=
func report(b brick) {
	_, nopt := b.xcc()
	ts := b.solve()
	fmt.Printf("%dx%dx%d: %d cells, %d options, %d solutions\n",
		b.l, b.m, b.n, b.ncells(), nopt, len(ts))
	if len(ts) == 0 {
		return
	}
	@<Check the remark about parallel sides@>
	@<Sort the solutions into classes and print the line@>
}

@ @<Check the remark about parallel sides@>=
bad := 0
for _, t := range ts {
	if !t.oppositeOnly() {
		bad++
	}
}
if bad > 0 {
	fmt.Printf("    %d solutions repeat a colour on sides that meet\n", bad)
} else {
	fmt.Printf("    every repeated side colour is on parallel sides\n")
}

@ @<Sort the solutions into classes and print the line@>=
type key struct {
	sides string
	aut   int
}
class := map[string]tensor{}
for _, t := range ts {
	c, _ := t.canon()
	class[c] = t
}
tally := map[key]int{}
accounted := 0
for _, t := range class {
	_, na := t.canon()
	tally[key{t.sides(), na}]++
	accounted += len(b.syms()) / na
}
fmt.Printf("    |G| = %d, %d essentially different, %d solutions accounted for\n",
	len(b.syms()), len(class), accounted)
@<Print one row per pattern of face colours@>

@ The answer's table has columns for $1$, $2$, $4$ and $8$ automorphisms.
Anything outside that range---and the $2\times2\times2$ case has a brick with
twenty-four---gets a note of its own.
@<Print one row per pattern of face colours@>=
var pats []string
for k := range tally {
	if !contains(pats, k.sides) {
		pats = append(pats, k.sides)
	}
}
sort.Strings(pats)
for _, s := range pats {
	fmt.Printf("    %-14s (%d, %d, %d, %d)", s,
		tally[key{s, 1}], tally[key{s, 2}], tally[key{s, 4}], tally[key{s, 8}])
	for k, v := range tally {
		if k.sides == s && k.aut != 1 && k.aut != 2 && k.aut != 4 && k.aut != 8 {
			fmt.Printf("  [and %d with %d automorphisms]", v, k.aut)
		}
	}
	fmt.Println()
}
if dumpAll {
	@<List every class with its six side colours@>
}

@ @<Functions@>=
func contains(ss []string, s string) bool {
	for _, t := range ss {
		if t == s {
			return true
		}
	}
	return false
}

@ When two counts disagree it helps to see the bricks themselves. This lists
each class with the colour on each of its six sides and how many colours that
makes---a plain fact about a brick that owes nothing to any convention for
ordering the pairs.
@<List every class with its six side colours@>=
var keys []string
for k := range class {
	keys = append(keys, k)
}
sort.Strings(keys)
for _, k := range keys {
	t := class[k]
	_, na := t.canon()
	pr := t.sidePairs()
	set := map[byte]bool{}
	for a := 0; a < 3; a++ {
		set[pr[a][0]] = true
		set[pr[a][1]] = true
	}
	fmt.Printf("      aut %2d  %-14s  %c%c %c%c %c%c  %d colours on the surface\n",
		na, t.sides(), pr[0][0], pr[0][1], pr[1][0], pr[1][1],
		pr[2][0], pr[2][1], len(set))
}

@* Six different colours.
The catalogue's disagreements, if there are any, are easier to talk about in a
form that involves no canonical ordering at all: of the solutions a shape has,
how many show six different colours on the outside? A third model settles that
independently of how the classes are sorted. Give each colour a secondary item
of its own and hang it on the options that paint a side; a secondary item can
be taken at most once, so no two sides can claim the same colour, and with six
sides and six colours they must all differ.
@<Functions@>=
func distinctSides(b brick) {
	in, _ := b.xcc()
	lines := strings.Split(strings.TrimRight(in, "\n"), "\n")
	@<Add a colour item to the header and to every side option@>
	xc := cells.NewXCC()
	n := 0
	for range xc.Dance(strings.NewReader(strings.Join(lines, "\n") + "\n")).Solutions {
		n++
	}
	fmt.Printf("%dx%dx%d: %d bricks with six different colours outside\n",
		b.l, b.m, b.n, n)
}

@ @<Add a colour item to the header and to every side option@>=
head := strings.SplitN(lines[0], " | ", 2)
var used []string
for c := byte('a'); c <= 'f'; c++ {
	used = append(used, fmt.Sprintf("U%c", c))
}
lines[0] = head[0] + " | " + strings.Join(used, " ") + " " + head[1]
for i, ln := range lines[1:] {
	for d := 0; d < 6; d++ {
		if strings.HasPrefix(ln, sideName[d]+" ") {
			lines[i+1] = ln + fmt.Sprintf(" U%c", ln[len(ln)-1])
		}
	}
}

@* The arrays the answer prints.
Answer 147(a) displays two of these arrays: the $3\times5\times5$ one for the
$1\times2\times2$ brick of the exercise, and the $5\times7\times11$ one for the
magnificent $2\times3\times5$. Both are worth reading back in, because a
transcription that survives the test below is almost certainly right: a single
wrong letter would leave some cell holding a colouring that is no cube at all.
@<Declarations@>=
var printed122 = []string{
	@<The array of the $1\times2\times2$ brick@>
}

var printed235 = []string{
	@<The array of the magnificent brick@>
}

@ @<The array of the $1\times2\times2$ brick@>=
".....\n.a.a.\n.....\n.a.a.\n.....",
".d.d.\nc.e.c\n.f.f.\nc.d.c\n.e.e.",
".....\n.b.b.\n.....\n.b.b.\n.....",

@ @<The array of the magnificent brick@>=
"...........\n.a.a.a.a.a.\n...........\n.a.a.a.a.a.\n" +
	"...........\n.a.a.a.a.a.\n...........",
".c.c.c.c.c.\nb.f.d.f.d.b\n.e.e.b.b.f.\nb.c.d.f.e.b\n" +
	".f.f.e.d.d.\nb.e.d.b.e.b\n.c.c.c.c.c.",
"...........\n.d.b.e.e.e.\n...........\n.d.b.c.c.c.\n" +
	"...........\n.d.b.f.f.f.\n...........",
".c.c.c.c.c.\nb.f.d.b.f.b\n.e.e.f.d.d.\nb.c.d.e.f.b\n" +
	".f.f.b.b.e.\nb.e.d.e.d.b\n.c.c.c.c.c.",
"...........\n.a.a.a.a.a.\n...........\n.a.a.a.a.a.\n" +
	"...........\n.a.a.a.a.a.\n...........",

@ Each block is one value of $x$, each line of a block one value of $y$, and
each character one value of $z$; a dot stands wherever the triple is not a
face. Reading it in checks the shape as it goes.
@<Functions@>=
func readPrinted(b brick, blocks []string) (tensor, error) {
	t := tensor{b, map[pt]byte{}}
	d := b.dims()
	if len(blocks) != 2*d[0]+1 {
		return t, fmt.Errorf("want %d blocks, got %d", 2*d[0]+1, len(blocks))
	}
	for x, blk := range blocks {
		@<Read one block of the array@>
	}
	return t, nil
}

@ @<Read one block of the array@>=
rows := strings.Split(blk, "\n")
if len(rows) != 2*d[1]+1 {
	return t, fmt.Errorf("block %d: want %d rows, got %d", x, 2*d[1]+1, len(rows))
}
for y, row := range rows {
	if len(row) != 2*d[2]+1 {
		return t, fmt.Errorf("block %d row %d: %d columns", x, y, len(row))
	}
	for z := 0; z < len(row); z++ {
		isFace := x%2+y%2+z%2 == 2
		if isFace == (row[z] == '.') {
			return t, fmt.Errorf("(%d,%d,%d) is %q", x, y, z, row[z])
		}
		if isFace {
			t.col[pt{x, y, z}] = row[z]
		}
	}
}

@ @<Functions@>=
func checkPrinted(b brick, blocks []string) {
	t, err := readPrinted(b, blocks)
	if err != nil {
		fmt.Printf("  malformed: %v\n", err)
		return
	}
	bc := byColour()
	used := map[string]bool{}
	ok := true
	@<Look at the cube in every cell@>
	fmt.Printf("  %dx%dx%d: %d cells, %d distinct cubes",
		b.l, b.m, b.n, b.ncells(), len(used))
	fmt.Printf(", sides %s, parallel rule %v -- %s\n",
		t.sides(), t.oppositeOnly(), verdict[ok && len(used) == b.ncells()])
}

@ @<Declarations@>=
var verdict = map[bool]string{true: "a genuine brick", false: "SOMETHING IS WRONG"}

@ @<Look at the cube in every cell@>=
b.eachCell(func(i, j, k int) {
	ff := b.faces(i, j, k)
	var col [6]byte
	for d := 0; d < 6; d++ {
		col[d] = t.col[ff[d]]
	}
	nm, isCube := bc[col]
	if !isCube {
		fmt.Printf("  cell (%d,%d,%d) holds %s, which is no cube\n", i, j, k, string(col[:]))
		ok = false
		return
	}
	if used[nm] {
		fmt.Printf("  cube %s appears twice\n", nm)
		ok = false
	}
	used[nm] = true
})

@* Handedness.
The answer names the cubes in five places: the four cells of the
$1\times2\times2$ array, and one cell of the magnificent brick, whose option it
writes out as {\tt 135 acbefd 035:a 125:b 134:d 136:f 145:e 235:c}. Those names
are chiral---a cube and its mirror image get different ones---while an array of
coordinates is just an array until somebody says how it sits in space. Nothing
in the exercise or the answer says.

So I read the five cells both ways round. One handedness gives the five names
the answer prints and the other gives their five mirror images, which settles
which reading was meant even though it was never stated. Reflecting a single
axis is enough to change hands, and since the name already ignores rotations it
does not matter which axis.
@<Functions@>=
func mirrorName(bc map[[6]byte]string, col [6]byte) string {
	col[dLeft], col[dRight] = col[dRight], col[dLeft]
	return bc[col]
}

@ @<Functions@>=
func printedCheck() {
	fmt.Println("the array of the 1x2x2 brick:")
	checkPrinted(brick{1, 2, 2}, printed122)
	fmt.Println("the magnificent 2x3x5 brick:")
	checkPrinted(brick{2, 3, 5}, printed235)
	fmt.Println("the cells the answer names, read both ways round:")
	@<Name the five cells the answer names@>
}

@ @<Declarations@>=
var namedCells = []struct {
	b    brick
	i    int
	j    int
	k    int
	want string
}{
	{brick{1, 2, 2}, 0, 0, 0, "abcedf"},
	{brick{1, 2, 2}, 0, 0, 1, "abcefd"},
	{brick{1, 2, 2}, 0, 1, 0, "abcdfe"},
	{brick{1, 2, 2}, 0, 1, 1, "abcdef"},
	{brick{2, 3, 5}, 0, 1, 2, "acbefd"},
}

@ @<Name the five cells the answer names@>=
bc := byColour()
right, left := 0, 0
for _, c := range namedCells {
	blocks := printed122
	if c.b.l == 2 {
		blocks = printed235
	}
	t, err := readPrinted(c.b, blocks)
	if err != nil {
		fmt.Println(err)
		continue
	}
	ff := c.b.faces(c.i, c.j, c.k)
	var col [6]byte
	for d := 0; d < 6; d++ {
		col[d] = t.col[ff[d]]
	}
	@<Compare the two readings with the printed name@>
}
fmt.Printf("  right-handed agrees %d times out of %d, left-handed %d\n",
	right, len(namedCells), left)

@ @<Compare the two readings with the printed name@>=
r, l := bc[col], mirrorName(bc, col)
if r == c.want {
	right++
}
if l == c.want {
	left++
}
fmt.Printf("  (%d,%d,%d) right-handed %s, left-handed %s, the answer says %s\n",
	2*c.i+1, 2*c.j+1, 2*c.k+1, r, l, c.want)

@* Two near misses.
The answer ends by pointing out that although no $3\times3\times3$ brick exists,
one can come close: the shape with a corner missing can be built from 26 of the
cubes, and the shape without the middle cube and the one above it from 25.
Leaving cells out is all this takes; the faces where a cell is missing simply
belong to nothing, and the sides that remain are still required to be solid.
@<Functions@>=
func nearMiss() {
	for _, c := range nearShapes {
		skip = map[[3]int]bool{}
		for _, g := range c.gone {
			skip[g] = true
		}
		b := brick{3, 3, 3}
		ts := b.solve()
		@<Say how the near miss came out@>
	}
	skip = map[[3]int]bool{}
}

@ @<Declarations@>=
var nearShapes = []struct {
	what string
	gone [][3]int
}{
	{"a 3x3x3 with one corner missing", [][3]int{{2, 2, 2}}},
	{"a 3x3x3 without the middle cube and the one above it",
		[][3]int{{1, 1, 1}, {1, 1, 2}}},
}

@ @<Say how the near miss came out@>=
fmt.Printf("%s: %d cells, %d solutions", c.what, b.ncells(), len(ts))
if len(ts) > 0 {
	bc := byColour()
	used := map[string]bool{}
	b.eachCell(func(i, j, k int) {
		ff := b.faces(i, j, k)
		var col [6]byte
		for d := 0; d < 6; d++ {
			col[d] = ts[0].col[ff[d]]
		}
		used[bc[col]] = true
	})
	fmt.Printf(", the first built from %d of the thirty cubes", len(used))
}
fmt.Println()

@** Index.
