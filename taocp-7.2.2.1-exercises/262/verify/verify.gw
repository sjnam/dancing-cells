\input luamplib.sty

\datethis
\def\title{Tilings, and the diagrams that hold them}

@* Introduction.
Exercise 7.2.2.1--262 asks how big a ZDD Algorithm Z builds for two families of
tilings. Part (a) takes $S_n$, a $16\times n$ rectangle with a right triangle of
side 7 cut from each corner, and asks for the number of ZDD nodes, and for the
number of domino tilings of $S_{16}$ and of $S_{32}$. Part (b) takes $T_n$, a
hexagon of sides $(8,8,n,8,8,n)$, and asks for the size of the diagram that
holds all of its diamond tilings.
$$\mplibcode input tilings; \endmplibcode$$
The answer gives two linear formulas, two long exact counts, and a page of
remarks around them: which way the cells must be numbered, whether the \.{MRV}
heuristic helps, how many diamonds of each kind a tiling has, an arctic circle,
and a picture of blue and red paths that D. Randall found hiding inside a
domino tiling. This program checks all of it.

Everything came out. The one thing that did not is in the answer's recipe for
part (b): as printed, the items it names describe a region with more upward
triangles than downward ones, and the resulting problem has no tilings at all.
One bound is missing, and \S26 says which.

@c
package main

import (
	"flag"
	"fmt"
	"math"
	"math/big"
	"math/rand/v2"
	"sort"
	"strconv"
	"strings"
	"time"

	zdd "github.com/sjnam/dancing-cells/zdd"
)

@<Types@>
@<Functions@>

func main() {
	@<Read the command line@>
	@<Do what the mode asks@>
}

@ The modes run in the order the answer reads. Most of them take a minute or
two together; \.{nodes} alone builds eighteen diagrams, the largest with more
than two million nodes.
@<Read the command line@>=
mode := flag.String("mode", "all",
	"aztec, nodes, order, mrv, hex, rows, paths, arctic, or all")
flag.Parse()
all := *mode == "all"

@ @<Do what the mode asks@>=
if *mode == "aztec" || all {
	@<Count the tilings of an Aztec diamond@>
}
if *mode == "nodes" || all {
	@<Measure the diagram of $S_n$@>
}
if *mode == "order" || all {
	@<Number the cells the other way@>
}
if *mode == "mrv" || all {
	@<Weigh the two branching rules@>
}
if *mode == "hex" || all {
	@<Measure the diagram of $T_n$@>
}
if *mode == "rows" || all {
	@<Count the diamonds of each kind@>
}
if *mode == "paths" || all {
	@<Trace Randall's paths@>
}
if *mode == "arctic" || all {
	@<Look for the arctic circle@>
}

@* The shape $S_{mn}$.
The exercise fixes the height at 16 and cuts triangles of side 7. Its answer
then loosens both at once---``the more general shapes $S_{mn}$ considered here,
where we replace 16 by $2m$ and 7 by $m-1$''---and that is the shape this
program builds, because $S_n$ is $S_{8n}$ and the Aztec diamond of order $m$ is
$S_{m(2m)}$. A cell survives when it is far enough from all four cut corners.

@<Functions@>=
func inS(r, c, m, n int) bool {
	return r+c >= m-1 && r+(n-1-c) >= m-1 &&
		(2*m-1-r)+c >= m-1 && (2*m-1-r)+(n-1-c) >= m-1
}

@ A |board| is the whole exact cover problem: the surviving cells in the order
they will be named, the dominoes in the order they will be numbered, and the
\.{DLX} text that says so. Element $k$ of the ZDD is |opts[k]|, which is how
every later section reads a tiling back.

@<Types@>=
type domino struct {
	p, q  int // item numbers, |p < q|
	horiz bool
}

type board struct {
	m, n  int
	cells [][2]int
	num   map[[2]int]int
	opts  []domino
	text  string
}

@ Answer 262 says that the order of the cells is critical: numbering them
columnwise, top to bottom and then left to right, keeps the diagram small,
while numbering them rowwise blows it up. Both are wanted, so |rowwise| picks
between them.

@<Functions@>=
func newBoard(m, n int, rowwise bool) *board {
	b := &board{m: m, n: n, num: map[[2]int]int{}}
	@<Number the cells@>
	@<Make the dominoes@>
	@<Write the \.{DLX} text@>
	return b
}

@ Counting $i$ through all $2mn$ places of the frame visits every cell of the
frame once in either numbering, so one loop serves both.

@<Number the cells@>=
for i := 0; i < 2*m*n; i++ {
	r, c := i/n, i%n
	if !rowwise {
		r, c = i%(2*m), i/(2*m)
	}
	if inS(r, c, m, n) {
		b.num[[2]int{r, c}] = len(b.cells)
		b.cells = append(b.cells, [2]int{r, c})
	}
}

@ Each cell offers the domino running right from it and the domino running
down; in either numbering the cell it is offered from is the lower-numbered of
the two, so the options come out grouped by their smallest item, which is what
makes the diagram an ordered one.

@<Make the dominoes@>=
for _, p := range b.cells {
	for k, q := range [][2]int{{p[0], p[1] + 1}, {p[0] + 1, p[1]}} {
		i, ok1 := b.num[p]
		j, ok2 := b.num[q]
		if !ok1 || !ok2 {
			continue
		}
		if i > j {
			i, j = j, i
		}
		b.opts = append(b.opts, domino{i, j, k == 0})
	}
}

@ @<Write the \.{DLX} text@>=
var sb strings.Builder
for i := range b.cells {
	if i > 0 {
		sb.WriteByte(' ')
	}
	fmt.Fprintf(&sb, "c%d", i)
}
sb.WriteByte('\n')
for _, o := range b.opts {
	fmt.Fprintf(&sb, "c%d c%d\n", o.p, o.q)
}
b.text = sb.String()

@* The hexagon $T_{lmn}$.
Part (b) works in the triangle coordinates of answer 124: a square cell
$(x,y)$, sheared and scaled, becomes an upward triangle $(x,y)$ together with
the downward triangle $(x,y)'$ immediately to its right. A diamond covers one
of each, so the options of answer 262 pair $(x,y)$ with $(x,y)'$, with
$(x,y-1)'$, or with $(x-1,y)'$---leaning one way, standing upright, leaning
the other.

The hexagon of sides $(l,m,n,l,m,n)$ is the frame $0\le x<n+m$, $0\le y<l+m$
with two opposite corners cut off. Answer 262 names the cut for the downward
triangles in full; for the upward ones it names only the lower bound, and
|printed| is here so that \S26 can show what that leaves.

@<Functions@>=
func upTri(x, y, l, m, n int, printed bool) bool {
	if !(0 <= x && x < n+m && 0 <= y && y < l+m && x+y >= m) {
		return false
	}
	return printed || x+y < n+l+m
}

func dnTri(x, y, l, m, n int) bool {
	return 0 <= x && x < n+m && 0 <= y && y < l+m &&
		m-1 <= x+y && x+y < n+l+m-1
}

@ @<Types@>=
type tri struct {
	x, y int
	down bool
}

type diamond struct {
	p, q int // item numbers, |p < q|
	x, y int // the upward triangle it covers
	kind int // 0, 1, 2 for $(x,y)'$, $(x,y-1)'$, $(x-1,y)'$
}

type hexagon struct {
	l, m, n int
	tris    []tri
	num     map[tri]int
	opts    []diamond
	text    string
}

@ The triangles are numbered by $x$ and then by $y$, the upward one first. That
is the order answer 262 lists them in, and \S30 shows what it is worth; passing
|across| numbers them by $y$ and then $x$ instead, for the comparison there.

@<Functions@>=
func newHexagon(l, m, n int, printed, across bool) *hexagon {
	h := &hexagon{l: l, m: m, n: n, num: map[tri]int{}}
	@<Number the triangles@>
	@<Make the diamonds@>
	@<Write the hexagon's \.{DLX} text@>
	return h
}

@ @<Number the triangles@>=
for i := 0; i < (n+m)*(l+m); i++ {
	x, y := i/(l+m), i%(l+m)
	if across {
		x, y = i%(n+m), i/(n+m)
	}
	for _, down := range []bool{false, true} {
		if down && !dnTri(x, y, l, m, n) {
			continue
		}
		if !down && !upTri(x, y, l, m, n, printed) {
			continue
		}
		t := tri{x, y, down}
		h.num[t] = len(h.tris)
		h.tris = append(h.tris, t)
	}
}

@ Here the lower-numbered item of a diamond is not always the upward triangle,
so the options have to be sorted into buckets by their smallest item before
they are written out.

@<Make the diamonds@>=
buckets := make([][]diamond, len(h.tris))
for _, t := range h.tris {
	if t.down {
		continue
	}
	@<Offer the three diamonds that cover $(x,y)$@>
}
for _, bucket := range buckets {
	h.opts = append(h.opts, bucket...)
}

@ @<Offer the three diamonds that cover $(x,y)$@>=
for k, d := range [][2]int{{t.x, t.y}, {t.x, t.y - 1}, {t.x - 1, t.y}} {
	if !dnTri(d[0], d[1], l, m, n) {
		continue
	}
	i, j := h.num[t], h.num[tri{d[0], d[1], true}]
	if i > j {
		i, j = j, i
	}
	buckets[i] = append(buckets[i], diamond{i, j, t.x, t.y, k})
}

@ @<Write the hexagon's \.{DLX} text@>=
var sb strings.Builder
for i := range h.tris {
	if i > 0 {
		sb.WriteByte(' ')
	}
	fmt.Fprintf(&sb, "t%d", i)
}
sb.WriteByte('\n')
for _, o := range h.opts {
	fmt.Fprintf(&sb, "t%d t%d\n", o.p, o.q)
}
h.text = sb.String()

@* Running the engine.
One call builds a diagram and reports what it cost. The engine is the |zdd|
package of this repository, which is Algorithm Z on sparse sets; |mrv| chooses
between its two branching rules, and everything else is the same.

@<Types@>=
type result struct {
	d     *zdd.Diagram
	sv    *zdd.Solver
	secs  time.Duration
}

@ @<Functions@>=
func solve(text string, mrv bool) result {
	t := time.Now()
	sv := zdd.New()
	sv.MRV = mrv
	d := sv.Dance(strings.NewReader(text))
	return result{d, sv, time.Since(t)}
}

@ Two small conveniences. |bigStr| makes a decimal string of a power of two, to
compare against a count; |formula| is the linear function the answer predicts,
with a word for whether it holds.

@<Functions@>=
func pow2(k int) *big.Int {
	return new(big.Int).Lsh(big.NewInt(1), uint(k))
}

func agrees(got, want int) string {
	if got == want {
		return "yes"
	}
	return fmt.Sprintf("no, off by %d", got-want)
}

@* Aztec diamonds.
The exercise calls $S_{16}$ ``the Aztec diamond of order 8,'' and the answer
adds that an Aztec diamond of order $m$ has exactly $2^{m(m+1)/2}$ domino
tilings. Both are easy to see here, because $S_{m(2m)}$ {\it is\/} the Aztec
diamond of order $m$: its row $r$ holds $2\min(r+1,2m-r)$ cells, so the rows
run $2,4,\ldots,2m,2m,\ldots,4,2$.

@<Count the tilings of an Aztec diamond@>=
fmt.Println("Aztec diamonds")
for m := 1; m <= 10; m++ {
	@<Check that row $r$ of $S_{m(2m)}$ has $2\min(r+1,2m-r)$ cells@>
	r := solve(newBoard(m, 2*m, false).text, false)
	fmt.Printf("  order %2d: %26s tilings, 2^%-3d %v, %8d nodes\n",
		m, r.d.Count(), m*(m+1)/2, r.d.Count().Cmp(pow2(m*(m+1)/2)) == 0,
		r.d.Nodes())
}

@ @<Check that row $r$ of $S_{m(2m)}$ has $2\min(r+1,2m-r)$ cells@>=
for row := 0; row < 2*m; row++ {
	w := 0
	for c := 0; c < 2*m; c++ {
		if inS(row, c, m, 2*m) {
			w++
		}
	}
	if w != 2*min(row+1, 2*m-row) {
		fmt.Printf("  order %d, row %d: %d cells, not a diamond!\n", m, row, w)
	}
}

@* The size of the diagram.
Now for part (a) proper. Answer 262 says that columnwise numbering ``yields
{\it linear\/} ZDD size,'' and that the number of nodes is $154440n-2655855$
for all $n\ge30$.

There is a question of what we are entitled to compare. Algorithm Z outputs a
{\it free\/} ZDD, whose shape depends on the order step Z3 branches in; but
exercise 264 shows that branching on the least-numbered item makes the output
{\it ordered}, and exercise 265 that no two of its nodes are ever equal, so in
that case the output is the reduced ordered ZDD for the option numbering---the
one canonical object, which is exactly what the |bdd| library builds. So the
counts are comparable, and \S25 shows the other side of the same coin: our
number cannot depend on the branching rule at all.

@<Measure the diagram of $S_n$@>=
fmt.Println("The diagram of S_n, cells numbered columnwise")
fmt.Println("  (the formula is claimed only for n >= 30)")
for n := 15; n <= 32; n++ {
	r := solve(newBoard(8, n, false).text, false)
	want := 154440*n - 2655855
	fmt.Printf("  n=%2d: %39s tilings, %7d nodes, 154440n-2655855: %s\n",
		n, r.d.Count(), r.d.Nodes(), agrees(r.d.Nodes(), want))
	@<Check the two counts the exercise asks for@>
}

@ ``There are $68719476736=(\sqrt2\,)^{72}$ solutions for $S_{16}$, via
exercise 7.1.4--208; for $S_{32}$ there are
$152326556015596771390830202722034115329\approx1.552^{200}$.''

@<Check the two counts the exercise asks for@>=
switch n {
case 16:
	fmt.Printf("        S_16 = 2^36 = 68719476736: %v\n",
		r.d.Count().String() == "68719476736")
case 32:
	const s32 = "152326556015596771390830202722034115329"
	f, _ := new(big.Float).SetInt(r.d.Count()).Float64()
	fmt.Printf("        S_32 = %s: %v, and it is %.4f^200\n",
		s32, r.d.Count().String() == s32, math.Pow(f, 1.0/200))
}

@* Which way to number the cells.
``Rowwise ordering (left-to-right, top-to-bottom) causes exponential growth.''
It does: the diagram grows by a factor of about 1.967 for every column added,
where columnwise numbering adds a constant 154440.

@<Number the cells the other way@>=
fmt.Println("The same problem, cells numbered rowwise")
prev := 0
for n := 16; n <= 22; n += 2 {
	r := solve(newBoard(8, n, false).text, false)
	q := solve(newBoard(8, n, true).text, false)
	growth := "  --"
	if prev > 0 {
		growth = fmt.Sprintf("%.3f",
			math.Sqrt(float64(q.d.Nodes())/float64(prev)))
	}
	prev = q.d.Nodes()
	fmt.Printf("  n=%2d: columnwise %7d nodes, rowwise %8d, per column %s\n",
		n, r.d.Nodes(), q.d.Nodes(), growth)
}

@* Fewest options, or least numbered.
``It turns out to be better {\it not\/} to use the MRV heuristic, when
$n\ge18$.'' The engine here has both rules, and the crossing is exactly where
the answer puts it: at $n=17$ fewest-options needs fewer memo entries, at
$n=18$ it needs more, and it stays behind from there on.

The diagram itself never moves. It cannot: a reduced ordered ZDD is determined
by the family and the variable order, and the branching rule is neither.

@<Weigh the two branching rules@>=
fmt.Println("Fewest options (MRV) against least numbered")
for n := 15; n <= 22; n++ {
	text := newBoard(8, n, false).text
	a, b := solve(text, true), solve(text, false)
	better := "least numbered"
	if a.sv.Signatures() < b.sv.Signatures() {
		better = "MRV"
	}
	fmt.Printf("  n=%2d: %8d memos against %8d, %-14s; same diagram: %v\n",
		n, a.sv.Signatures(), b.sv.Signatures(), better,
		a.d.Nodes() == b.d.Nodes())
}

@* The hexagon's items.
Part (b) of answer 262 sets the problem up like this:

\smallskip
\item{}``use items $(x,y)$ for $0\le x<n+8$, $0\le y<16$, $x+y\ge8$;
$(x,y)'$ for $0\le x<n+8$, $0\le y<16$, $7\le x+y<n+15$.''
\smallskip

\noindent The second clause cuts two corners off the frame; the first cuts only
one. That leaves $16(n+8)-36$ upward triangles against $16(n+8)-73$ downward
ones, and a region with unequal numbers of the two cannot be tiled by diamonds
at all. The missing bound is $x+y<n+16$: with it both counts come to
$16n+64=lm+mn+nl$ for $l=m=8$, which is what a hexagon of sides $(8,8,n,8,8,n)$
must have.

@<Measure the diagram of $T_n$@>=
fmt.Println("The items of T_n, as printed and as repaired")
for _, printed := range []bool{true, false} {
	h := newHexagon(8, 8, 6, printed, false)
	up, down := 0, 0
	for _, t := range h.tris {
		if t.down {
			down++
		} else {
			up++
		}
	}
	fmt.Printf("  n=6, %-9s %d up, %d down, %s tilings\n",
		map[bool]string{true: "printed:", false: "repaired:"}[printed],
		up, down, solve(h.text, false).d.Count())
}

@ ``Then the ZDD size (without MRV) turns out to be $257400n-1210061$, for all
$n\ge7$.'' It does, from $n=7$ on and not before; at $n=6$ the diagram has
350784 nodes where the formula asks for 334339.

The count itself is MacMahon's: a diamond tiling of the hexagon $T_{lmn}$ is a
plane partition in an $l\times m\times n$ box, and there are
$\Pi_{lmn}=\prod\prod\prod(i+j+k-1)/(i+j+k-2)$ of them.

@<Measure the diagram of $T_n$@>=
fmt.Println("The diagram of T_n")
for n := 4; n <= 10; n++ {
	h := newHexagon(8, 8, n, false, false)
	r := solve(h.text, false)
	fmt.Printf("  n=%2d: %28s tilings, MacMahon %v, %7d nodes, %s\n",
		n, r.d.Count(), r.d.Count().Cmp(macMahon(8, 8, n)) == 0,
		r.d.Nodes(), agrees(r.d.Nodes(), 257400*n-1210061))
}

@ @<Functions@>=
func macMahon(l, m, n int) *big.Int {
	num, den := big.NewInt(1), big.NewInt(1)
	for i := 1; i <= l; i++ {
		for j := 1; j <= m; j++ {
			for k := 1; k <= n; k++ {
				num.Mul(num, big.NewInt(int64(i+j+k-1)))
				den.Mul(den, big.NewInt(int64(i+j+k-2)))
			}
		}
	}
	return num.Quo(num, den)
}

@ Answer 262 names two of those products, $\Pi_{888}$ and $\Pi_{88(16)}$, and
this is the place to check them and the formula on the largest case the answer
mentions.

@<Measure the diagram of $T_n$@>=
for _, n := range []int{8, 16} {
	r := solve(newHexagon(8, 8, n, false, false).text, false)
	fmt.Printf("  Pi_88(%d) = %s: %v, %7d nodes, %s\n", n, r.d.Count(),
		r.d.Count().Cmp(macMahon(8, 8, n)) == 0, r.d.Nodes(),
		agrees(r.d.Nodes(), 257400*n-1210061))
}

@ The order of the triangles matters here as much as the order of the cells did
in part (a). Numbering by $y$ and then by $x$---across the hexagon rather than
along it---starts out smaller, but it is not linear: it roughly quadruples
where the answer's numbering adds a constant, and it has overtaken by $n=9$.

@<Measure the diagram of $T_n$@>=
fmt.Println("  and with the triangles numbered across instead of along:")
for n := 3; n <= 9; n += 2 {
	along := newHexagon(8, 8, n, false, false)
	across := newHexagon(8, 8, n, false, true)
	fmt.Printf("    n=%d: %7d nodes against %7d\n", n,
		solve(across.text, false).d.Nodes(),
		solve(along.text, false).d.Nodes())
}

@* Diamonds by kind, and by row.
The answer then reads a tiling of the hexagon as a plane partition, and says
what that forces: ``every tiling of $T_n$ has respectively
$(1,2,\ldots,8,7,\ldots,1)$ vertical diamonds in rows $(1,2,\ldots,15)$, hence
64 in all; and these occurrences are nested.''

The three kinds of diamond are the three ways to lean, and the plane-partition
picture says that a tiling of $T_{lmn}$ has $lm$, $mn$ and $nl$ of them---so
for $l=m=8$ the upright ones, kind 1, always number 64. Every one of these is a
statement about {\it all\/} tilings at once, which is where a diagram earns its
keep: |MaxWeight| finds the largest number of kind-1 diamonds any tiling has,
and the same call on negated weights finds the smallest, both in one walk over
the DAG. When the two agree the count is forced.

@<Count the diamonds of each kind@>=
fmt.Println("Diamonds by kind")
for _, s := range [][3]int{{8, 8, 2}, {3, 4, 5}, {8, 8, 8}} {
	l, m, n := s[0], s[1], s[2]
	h := newHexagon(l, m, n, false, false)
	d := solve(h.text, false).d
	fmt.Printf("  T_%d,%d,%d: kinds", l, m, n)
	for kind := 0; kind < 3; kind++ {
		lo, hi := span(d, h, func(o diamond) bool { return o.kind == kind })
		fmt.Printf(" %s", spanStr(lo, hi))
	}
	fmt.Printf("   (nl, lm, mn = %d, %d, %d)\n", n*l, l*m, m*n)
}

@ @<Functions@>=
func span(d *zdd.Diagram, h *hexagon, pick func(diamond) bool) (int, int) {
	w := make([]int, len(h.opts)+1)
	for k, o := range h.opts {
		if pick(o) {
			w[k+1] = 1
		}
	}
	_, hi, _ := d.MaxWeight(w)
	for i := range w {
		w[i] = -w[i]
	}
	_, lo, _ := d.MaxWeight(w)
	return -lo, hi
}

func spanStr(lo, hi int) string {
	if lo == hi {
		return strconv.Itoa(lo)
	}
	return fmt.Sprintf("%d..%d", lo, hi)
}

@ Row by row now. A kind-1 diamond stands on the boundary between rows $y-1$
and $y$ of the frame, so its row is $y$, and $y$ runs from 1 to $l+m-1$: for
$l=m=8$ that is the fifteen rows the answer names.

@<Count the diamonds of each kind@>=
fmt.Println("Upright diamonds row by row, T_8,8,n")
for _, n := range []int{2, 5, 8} {
	h := newHexagon(8, 8, n, false, false)
	d := solve(h.text, false).d
	fmt.Printf("  n=%d:", n)
	for y := 1; y < 16; y++ {
		lo, hi := span(d, h, func(o diamond) bool {
			return o.kind == 1 && o.y == y
		})
		fmt.Printf(" %s", spanStr(lo, hi))
	}
	fmt.Println()
}

@ ``And these occurrences are nested.'' They interlace: an upright diamond of
row $y$ sits at $2x+y$ along that row, and the positions in one row fall
strictly between the positions in the next, the longer row surrounding the
shorter. That is precisely the interlacing that turns a tiling into a plane
partition. Here it is checked on every tiling of two small hexagons, and on a
thousand random tilings of $T_{8,8,4}$---random, of course, being another thing
the diagram gives for nothing.

@<Count the diamonds of each kind@>=
fmt.Println("Interlacing")
for _, s := range [][3]int{{2, 2, 2}, {3, 3, 2}} {
	h := newHexagon(s[0], s[1], s[2], false, false)
	d := solve(h.text, false).d
	z, root := d.ZDD()
	seen, bad := 0, 0
	for elts := range z.Subsets(root) {
		seen++
		if !interlaced(h, elts) {
			bad++
		}
	}
	fmt.Printf("  T_%d,%d,%d: all %d tilings, %d not interlaced\n",
		s[0], s[1], s[2], seen, bad)
}
@<Sample $T_{8,8,4}$ at random and check the interlacing@>

@ @<Sample $T_{8,8,4}$ at random and check the interlacing@>=
h := newHexagon(8, 8, 4, false, false)
d := solve(h.text, false).d
z, root := d.ZDD()
rnd := rand.New(rand.NewPCG(20260908, 262))
bad := 0
for i := 0; i < 1000; i++ {
	elts, _ := z.Random(root, rnd)
	if !interlaced(h, elts) {
		bad++
	}
}
fmt.Printf("  T_8,8,4: 1000 random tilings, %d not interlaced\n", bad)

@ @<Functions@>=
func interlaced(h *hexagon, elts []int) bool {
	rows := make([][]int, h.l+h.m)
	for _, k := range elts {
		if o := h.opts[k]; o.kind == 1 {
			rows[o.y] = append(rows[o.y], 2*o.x+o.y)
		}
	}
	for _, v := range rows {
		sort.Ints(v)
	}
	for y := 1; y+1 < len(rows); y++ {
		if !strictlyBetween(rows[y], rows[y+1]) {
			return false
		}
	}
	return true
}

@ The shorter list must have one entry fewer than the longer, and its entries
must fall in the gaps.

@<Functions@>=
func strictlyBetween(a, b []int) bool {
	if len(a) > len(b) {
		a, b = b, a
	}
	if len(b) != len(a)+1 {
		return false
	}
	for i, v := range a {
		if !(b[i] < v && v < b[i+1]) {
			return false
		}
	}
	return true
}

@* Randall's paths.
Answer 262 ends part (a) with a picture and a caption: ``every vertical domino
has either a blue or red path; every horizontal domino has blue and red paths,
crossed.'' That is enough to draw them. Colour the cells like a chessboard and
put a node at the midpoint of every horizontal edge of the grid. Then

\smallskip
\item{$\bullet$} a vertical domino carries one straight segment, from the node
above it to the node below it, and

\item{$\bullet$} a horizontal domino carries two, each running from the top of
one of its cells to the bottom of the other---blue from the black cell down to
the white, red from the white down to the black, so that they cross.
\smallskip

\noindent Nothing else is free, and the drawing that results is the one on
page 483. What has to be checked is that the segments join up: that no node is
left with two segments coming in or two going out, that a segment never joins a
blue node to a red one, and that every path so formed runs from the top of the
region to the bottom. They do, and there are $m$ paths of each colour in an
Aztec diamond of order $m$.

@<Trace Randall's paths@>=
fmt.Println("Randall's blue and red paths")
for _, m := range []int{4, 6, 8} {
	b := newBoard(m, 2*m, false)
	d := solve(b.text, false).d
	z, root := d.ZDD()
	rnd := rand.New(rand.NewPCG(20260908, uint64(m)))
	bad, blue, red := 0, 0, 0
	for i := 0; i < 200; i++ {
		elts, _ := z.Random(root, rnd)
		@<Lay the segments of one tiling@>
		@<Follow the segments and count the paths@>
	}
	fmt.Printf("  order %2d: 200 tilings, %d faulty; %d blue and %d red"+
		" paths each time\n", m, bad, blue/200, red/200)
}

@ A node is written as the pair (row, column) of the cell below it, so the node
above cell $(r,c)$ is $(r,c)$ and the node below it is $(r+1,c)$, and the node
is blue when $r+c$ is even. Since the cells are numbered columnwise, |o.p| is
always the left or upper cell of its domino.

@<Lay the segments of one tiling@>=
next, prev := map[[2]int][2]int{}, map[[2]int]bool{}
ok := true
for _, k := range elts {
	o := b.opts[k]
	p := b.cells[o.p]
	segs := [][2][2]int{{{p[0], p[1]}, {p[0] + 2, p[1]}}}
	if o.horiz {
		@<Cross a blue segment and a red one over the domino@>
	}
	@<Add the segments, watching for a clash@>
}

@ @<Cross a blue segment and a red one over the domino@>=
black, white := p[1], p[1]+1
if (p[0]+p[1])%2 != 0 {
	black, white = white, black
}
segs = [][2][2]int{
	{{p[0], black}, {p[0] + 1, white}},
	{{p[0], white}, {p[0] + 1, black}},
}

@ @<Add the segments, watching for a clash@>=
for _, s := range segs {
	_, twice := next[s[0]]
	if twice || prev[s[1]] || (s[0][0]+s[0][1])%2 != (s[1][0]+s[1][1])%2 {
		ok = false
	}
	next[s[0]] = s[1]
	prev[s[1]] = true
}

@ A path starts at a node with nothing coming in. Following it must leave the
region at the bottom, never at the side and never at the top, and the parity of
the node it started from says which colour it is.

@<Follow the segments and count the paths@>=
for s := range next {
	if prev[s] {
		continue
	}
	if _, inside := b.num[[2]int{s[0] - 1, s[1]}]; inside {
		ok = false
	}
	e := s
	for {
		n, more := next[e]
		if !more {
			break
		}
		e = n
	}
	if _, inside := b.num[e]; inside {
		ok = false
	}
	if (s[0]+s[1])%2 == 0 {
		blue++
	} else {
		red++
	}
}
if !ok {
	bad++
}

@* The arctic circle.
``As $m\to\infty$, the dominoes at the corners are q.s. aligned, except within
an `arctic circle' of radius $m/\sqrt2$.'' Sampling would show it, but the
diagram can do better than sample: for each cell it can say {\it exactly\/} how
likely that cell is to be covered lengthwise, because the tilings that use a
given domino are the quotient of the family by that element, and counting them
is one more walk over the DAG.

Write $p$ for that chance and $|2p-1|$ for how far the cell is from undecided.
Averaged over the cells at each radius, it stays near zero out to $0.7m$ and
then climbs to one---the circle of radius $m/\sqrt2=0.7071m$ falling right in
the middle of the climb, and the climb getting steeper as $m$ grows.

@<Look for the arctic circle@>=
fmt.Println("The arctic circle: mean |2p-1| by radius, in tenths of m")
for _, m := range []int{4, 6, 8, 10} {
	b := newBoard(m, 2*m, false)
	d := solve(b.text, false).d
	@<Find the chance that each cell is covered lengthwise@>
	@<Report how far from undecided the cells are, band by band@>
}

@ @<Find the chance that each cell is covered lengthwise@>=
z, root := d.ZDD()
total := new(big.Float).SetInt(d.Count())
chance := make([]float64, len(b.cells))
for k, o := range b.opts {
	if !o.horiz {
		continue
	}
	share := new(big.Float).SetInt(z.Count(z.Quotient(root, z.Elt(k))))
	q, _ := share.Quo(share, total).Float64()
	chance[o.p] += q
	chance[o.q] += q
}

@ @<Report how far from undecided the cells are, band by band@>=
const bands = 10
var sum [bands]float64
var cnt [bands]int
for i, p := range b.cells {
	y, x := float64(p[0])+.5-float64(m), float64(p[1])+.5-float64(m)
	j := min(int(math.Hypot(x, y)/float64(m)*bands), bands-1)
	sum[j] += math.Abs(2*chance[i] - 1)
	cnt[j]++
}
fmt.Printf("  m=%2d:", m)
for j := 0; j < bands; j++ {
	if cnt[j] == 0 {
		fmt.Print("    . ")
	} else {
		fmt.Printf(" %5.2f", sum[j]/float64(cnt[j]))
	}
}
fmt.Println()

@* Index.
