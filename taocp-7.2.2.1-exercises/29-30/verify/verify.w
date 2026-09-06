\input luamplib.sty

\def\title{Backtrack Trees to Order}

@s Builder int
@s Rand int
@s node int
@s matrix int
@s trace int

@* Introduction.
Algorithm~X, in \S7.2.2.1 of {\sl The Art of Computer Programming}, solves exact
cover problems by backtracking. At step X3 it looks over the items not yet
covered and picks one whose \.{LEN}---the number of options still available to
it---is least. That is the {\it MRV\/} heuristic, minimum remaining values. Each
option covering the chosen item then becomes a branch. So the shape of the
search tree is settled entirely by which item wins the \.{LEN} contest at every
step, and the cost of a run is the size of that tree.
@^Knuth, Donald Ervin@>

Exercises 29 and 30 turn the arrow around. Instead of asking what tree a problem
produces, they ask what problem produces a given tree.

\smallskip
{\narrower\noindent
{\bf 29.} [{\it 26\/}]\enspace Let $T$ be any tree. Construct the 0--1 matrix of
an unsolvable exact cover problem for which $T$ is the backtrack tree traversed
by Algorithm~X with the MRV heuristic. (A {\it unique\/} item should have the
minimum \.{LEN} value whenever step X3 is encountered.) Illustrate your
construction when $T$ is a root with two subtrees, each having three leaves.
\smallskip\noindent
{\bf 30.} [{\it 25\/}]\enspace Continuing exercise 29, let $T$ be a tree in which
certain leaves have been distinguished from the others and designated as
``solutions.'' Can all such trees arise as backtrack trees in Algorithm~X?
\par}
\smallskip

@ Here is the tree the exercise draws, with the columns that the construction
of answer 29 hands to each of its nodes: one to every leaf, three more to every
interior node. That is where the fifteen columns of the printed matrix come
from, and the shape of the tree is the shape of the search.

$$\mplibcode input backtrack; \endmplibcode$$

@ Knuth answers yes to both, by explicit construction. This program checks him.

I wrote it in September 2026 while reading the two exercises carefully, and
it turned up one thing worth reporting: answer 30, as printed in the 2022
first edition, breaks on exactly one tree---the one-node tree whose root is
marked a solution.
Knuth had already caught that. His file of changes to Volume~4B carries the
correction, dated 22 March 2023, and it does more than patch the corner: it
deletes a special rule that the corrected base case now supplies for free. Both
versions live here behind a flag, so the difference can be measured instead of
argued about.

These notes, with the numbers this program produced, are the companion
document \.{README.md} in the directory above.

@ Answer 29 builds the matrix by recursion on $T$. A leaf becomes one column with
no rows---an item that no option can cover, so the search dies there at once.
An interior node with subtrees $T_1$, \dots, $T_d$ takes the matrices already
built for its subtrees, whose columns are $C_1$, \dots, $C_d$, sets
$C=C_1\cup\cdots\cup C_d$, and appends three fresh columns named $0$, $1$, $2$
together with $d+2$ fresh rows:
$$\vbox{\halign{\hfil(#)\quad&#\hfil\cr
i&`$0\;1\;2$ and all columns of $C\setminus C_j$', for $1\le j\le d$;\cr
ii&`$j$ and all columns of $C$', for $j\in\{0,1\}$.\cr}}$$
Column~$2$ then has the strictly smallest \.{LEN}, namely~$d$, so Algorithm~X
must branch there, on the $d$ rows of type~(i), one per subtree. Choosing the
$j$th covers everything outside $C_j$ and leaves exactly the matrix of $T_j$
standing. The rows of type~(ii) are never chosen at all; they exist only to lift
columns $0$ and~$1$ one notch above column~$2$, which is what makes the minimum
unique.

@ So the program has four jobs. It builds the matrix from a tree; it runs a
faithful Algorithm~X on the result and records the tree that comes back; it
generates trees to feed the first two, either at random or exhaustively; and it
hands the matrix to our own \.{ssxcc} for a second opinion on the number of
solutions. The skeleton is a command line and a choice of what to do with it.
@c
package main

import (
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"sort"
	"strings"

	cells "github.com/sjnam/dancing-cells"
)

@<Declarations@>

@<Functions@>

func main() {
	@<Read the command line@>
	switch *mode {
	case "book":
		@<Reproduce the printed matrix@>
	case "dlx":
		@<Write the problem as \.{DLX} text@>
	case "ssxcc":
		@<Ask \.{ssxcc} for a second opinion@>
	case "all":
		@<Try every small tree@>
	case "random":
		@<Try random trees@>
	default:
		log.Fatalf("unknown mode %q", *mode)
	}
}

@ The flag that matters most is \.{-errata}. Everything else adjusts how much
work to do.
@<Read the command line@>=
mode := flag.String("mode", "book", "book, dlx, ssxcc, all, or random")
spec := flag.String("spec", "", "tree to use, e.g. ((.*.)(...))")
fix := flag.Bool("errata", false, "follow the 2023-03-22 erratum for answer 30")
upto := flag.Int("upto", 8, "mode all: try all trees up to this many nodes")
trials := flag.Int("trials", 2000, "mode random: how many trees")
budget := flag.Int("budget", 14, "mode random: largest tree to build")
sol := flag.Bool("sol", false, "mode random: designate solution leaves")
sibs := flag.Bool("sibs", true, "mode random: allow sibling solution leaves")
seed := flag.Int64("seed", 1, "mode random: seed")
flag.Parse()
errata = *fix

@* Trees.
A tree is a node with children. One bit of decoration is all exercise 30 asks
for: a leaf may be {\it designated\/} a solution, meaning that Algorithm~X should
find a solution when it arrives there instead of failing.
@<Declarations@>=
type node struct {
	kids []*node
	sol  bool // a leaf designated a ``solution'' in exercise 30
}

@ Two methods travel with it. The size of a tree is what the node count of a run
will be compared against, and the string form is how trees are written on the
command line and reported when something goes wrong: a dot is an ordinary leaf,
a star a designated one, and parentheses enclose the children of an interior
node. The tree drawn in exercise 29 is \.{((...)(...))}.
@<Functions@>=
func (t *node) size() int {
	n := 1
	for _, k := range t.kids {
		n += k.size()
	}
	return n
}

func (t *node) String() string {
	if len(t.kids) == 0 {
		if t.sol {
			return "*"
		}
		return "."
	}
	var b strings.Builder
	b.WriteByte('(')
	for _, k := range t.kids {
		b.WriteString(k.String())
	}
	b.WriteByte(')')
	return b.String()
}

@ Reading that notation back is a short recursive descent. With no argument we
hand back the tree of exercise 29, since that is the one the book draws and the
one worth looking at first---and writing the default as a spec rather than as
nodes keeps the two subtrees from quietly sharing their leaves.
@<Functions@>=
func tree(spec string) *node {
	if spec == "" {
		spec = "((...)(...))" // the tree drawn in exercise 29
	}
	pos := 0
	var parse func() *node
	parse = func() *node {
		switch c := spec[pos]; c {
		case '.', '*':
			pos++
			return &node{sol: c == '*'}
		case '(':
			pos++
			t := &node{}
			for spec[pos] != ')' {
				t.kids = append(t.kids, parse())
			}
			pos++
			return t
		default:
			log.Fatalf("bad tree spec at position %d of %q", pos, spec)
			return nil
		}
	}
	return parse()
}

@ For the random sweep I grow a tree inside a budget of nodes, spending it on a
fan-out of one to three subtrees and recursing. The shapes this makes are lumpy
and unbalanced, which is what I want---the balanced tree of exercise 29 is the
one case a bug would be least likely to survive.
@<Functions@>=
func randTree(rnd *rand.Rand, budget int) *node {
	if budget <= 1 || rnd.Intn(3) == 0 {
		return &node{}
	}
	t := &node{}
	d, rest := 1+rnd.Intn(3), budget-1
	for j := 0; j < d && rest > 0; j++ {
		t.kids = append(t.kids, randTree(rnd, 1+rnd.Intn(rest)))
		rest -= t.kids[len(t.kids)-1].size()
	}
	if len(t.kids) == 0 {
		return &node{}
	}
	return t
}

@ Designating solutions afterwards takes one pass. The |sibOK| switch is there
because of a remark at the end of answer 30---that without duplicate options no
two solution nodes can be siblings---and turning it off is how I looked for the
duplicates that remark predicts.
@<Functions@>=
func markSolutions(t *node, rnd *rand.Rand, p float64, sibOK bool) {
	used := false
	for _, k := range t.kids {
		if len(k.kids) == 0 && rnd.Float64() < p && (sibOK || !used) {
			k.sol, used = true, true
		}
		markSolutions(k, rnd, p, sibOK)
	}
}

@* The construction.
A matrix is a column count and a list of rows, each row being the sorted indices
of its ones. Columns are numbered as they are created, so a subtree's columns
come out contiguous and the printed matrix falls into the same blocks the book
shows.
@<Declarations@>=
type matrix struct {
	ncol int
	rows [][]int // each row is a sorted list of column indices
}

@ Two globals steer the recursion: the next column number to hand out, and which
version of answer 30 to follow. Both are set once per matrix and never touched
during a search, so their being globals costs nothing and saves threading them
through every call.
@<Declarations@>=
var nextCol int
var errata bool // follow the erratum rather than the printed answer 30

@ Here is the recursion itself. The base case is the one line of answer 29---one
column, no rows---except under the erratum, where a leaf marked as a solution
gets no column either. That single early return is the whole of the correction,
and \S3.4 of the notes explains why it suffices: with $C_j$ empty,
$C\setminus C_j$ is $C$, which is exactly what the printed answer asked for by
hand.
@<Functions@>=
func build(t *node) (cols []int, rows [][]int) {
	if len(t.kids) == 0 {
		if errata && t.sol {
			return nil, nil // ``let there be no rows and no columns''
		}
		nextCol++
		return []int{nextCol - 1}, nil
	}
	@<Recurse into the subtrees@>
	@<Append the rows of type (i)@>
	@<Append the rows of type (ii)@>
	cols = append(C, p0, p1, p2)
	sort.Ints(cols)
	return cols, rows
}

@ The subtrees are built first, in order, so that their rows are already in the
list before any of ours. Then come the three new columns.
@<Recurse into the subtrees@>=
var sub [][]int // the columns $C_j$ of each subtree
for _, k := range t.kids {
	cj, rj := build(k)
	sub = append(sub, cj)
	rows = append(rows, rj...)
}
var C []int
for _, cj := range sub {
	C = append(C, cj...)
}
p0, p1, p2 := nextCol, nextCol+1, nextCol+2
nextCol += 3

@ A row of type~(i) takes the three new columns and everything in $C$ that does
not belong to its own subtree. The printed answer 30 makes its one exception
right here, taking all of $C$ when the subtree is a designated solution, which
leaves nothing uncovered and so ends the search in success.
@<Append the rows of type (i)@>=
for j := range t.kids {
	r := []int{p0, p1, p2}
	for _, c := range C {
		if (!errata && t.kids[j].sol) || !contains(sub[j], c) {
			r = append(r, c)
		}
	}
	sort.Ints(r)
	rows = append(rows, r)
}

@ The two rows of type~(ii) are the ballast. Neither contains column~$2$, so
neither is ever chosen; they are in the matrix only to give columns $0$ and~$1$
a \.{LEN} of $d+1$ against column~$2$'s~$d$.
@<Append the rows of type (ii)@>=
for _, p := range []int{p0, p1} {
	r := append([]int{p}, C...)
	sort.Ints(r)
	rows = append(rows, r)
}

@ Membership in a short unsorted list is wanted in one place, but a Go |for| loop
cannot answer a question with a value, so it is a function.
@<Functions@>=
func contains(xs []int, x int) bool {
	for _, y := range xs {
		if y == x {
			return true
		}
	}
	return false
}

@ Starting the recursion means resetting the column counter. Everything above
this line is answer 29 and 30; everything below is the machinery for judging
them.
@<Functions@>=
func makeMatrix(t *node) matrix {
	nextCol = 0
	_, rows := build(t)
	return matrix{ncol: nextCol, rows: rows}
}

@* Algorithm X, taken literally.
Our own solvers are no use here. Both engines in this repository descend from
Knuth's sparse-set programs, and \.{ssxcc} in particular carries two refinements
that Algorithm~X does not have: it collects items of size one and forces them
before branching, and its |hide| refuses a branch the moment an active primary
item would be starved of options. On the matrix of exercise 29 that second
refinement finds each failure one level early, so \.{ssxcc} reports three nodes
where Algorithm~X walks nine. Neither number is wrong; they are different
algorithms. To judge an exercise about Algorithm~X I need Algorithm~X.

So this is the textbook procedure with nothing added, on dense arrays, written
for clarity rather than speed. Because it must report the shape of the search,
each call returns the node it visited, with its children attached.
@<Declarations@>=
type trace struct {
	nodes     int   // calls made, which is the size of the backtrack tree
	solutions int   // times the matrix emptied out
	ties      int   // times step X3 found no unique minimum
	dups      int   // duplicate rows in the matrix
	shape     *node // the backtrack tree that was traversed
}

@ The active columns are a bit vector and the active rows a list of indices. The
invariant is the usual one: every active row lies wholly inside the active
columns.
@<Functions@>=
func algX(m matrix) *trace {
	tr := &trace{}
	cols := make([]bool, m.ncol)
	for i := range cols {
		cols[i] = true
	}
	rows := make([]int, len(m.rows))
	for i := range rows {
		rows[i] = i
	}
	var rec func([]bool, []int) *node
	rec = func(cols []bool, rows []int) *node {
		tr.nodes++
		self := &node{}
		@<Visit a solution if nothing is left@>
		@<Choose the item of minimum \.{LEN}@>
		@<Branch on every option covering it@>
		return self
	}
	tr.shape = rec(cols, rows)
	@<Count duplicate options@>
	return tr
}

@ Step X2. An empty matrix is a solution, and the leaf we mark here is the one
that must line up with a star in the tree we were given.
@<Visit a solution if nothing is left@>=
empty := true
for _, b := range cols {
	if b {
		empty = false
		break
	}
}
if empty {
	tr.solutions++
	self.sol = true
	return self
}

@ Step X3, the heart of the matter. Exercise 29 asks that a {\it unique\/} item
attain the minimum every time we get here, so as well as finding the minimum I
count how many columns share it. Any tie is a failure of the construction, and
in all this checking there was never one.
@<Choose the item of minimum \.{LEN}@>=
best, least, ties := -1, 1<<30, 0
for c := range cols {
	if !cols[c] {
		continue
	}
	n := 0
	for _, r := range rows {
		if contains(m.rows[r], c) {
			n++
		}
	}
	switch {
	case n < least:
		best, least, ties = c, n, 1
	case n == least:
		ties++
	}
}
if ties != 1 {
	tr.ties++
}

@ Steps X4 and~X5. Covering a row deletes its columns and every row that meets
one of them; what survives is passed down. When the chosen column has no rows at
all---the leaf case of the construction---this loop simply does nothing, and the
node stands as a childless failure.
@<Branch on every option covering it@>=
for _, r := range rows {
	if !contains(m.rows[r], best) {
		continue
	}
	nc := make([]bool, len(cols))
	copy(nc, cols)
	hit := make([]bool, len(cols))
	for _, x := range m.rows[r] {
		nc[x], hit[x] = false, true
	}
	var nr []int
	for _, r2 := range rows {
		clash := false
		for _, x := range m.rows[r2] {
			if hit[x] {
				clash = true
				break
			}
		}
		if !clash {
			nr = append(nr, r2)
		}
	}
	self.kids = append(self.kids, rec(nc, nr))
}

@ Answer 30 grants itself duplicate options, and remarks that without them no two
solution nodes could be siblings. That is true of exact cover in general: if two
options each finish a solution outright, each covers every item still remaining,
and a surviving option lies wholly within the remaining items, so the two options
are the same set. Counting duplicates lets me watch the remark come true.
@<Count duplicate options@>=
seen := map[string]bool{}
for _, r := range m.rows {
	if k := fmt.Sprint(r); seen[k] {
		tr.dups++
	} else {
		seen[k] = true
	}
}

@* Judging the result.
A run passes when the tree that came back is the tree that went in---same shape,
and the same leaves marked as solutions. Ordered trees, so no canonical form is
needed; the children come back in the order their rows were laid down.
@<Functions@>=
func sameShape(a, b *node) bool {
	if len(a.kids) != len(b.kids) {
		return false
	}
	if len(a.kids) == 0 && a.sol != b.sol {
		return false
	}
	for i := range a.kids {
		if !sameShape(a.kids[i], b.kids[i]) {
			return false
		}
	}
	return true
}

@ Three more walks. The leaves of a tree are wanted both for counting the
solutions we expect and for setting the marks in the exhaustive sweep; a copy is
wanted so that one tree can be marked many ways; and the sibling test is the
other half of the duplicate-option remark.
@<Functions@>=
func leaves(t *node) []*node {
	if len(t.kids) == 0 {
		return []*node{t}
	}
	var out []*node
	for _, k := range t.kids {
		out = append(out, leaves(k)...)
	}
	return out
}

func clone(t *node) *node {
	c := &node{sol: t.sol}
	for _, k := range t.kids {
		c.kids = append(c.kids, clone(k))
	}
	return c
}

func hasSiblingSolutions(t *node) bool {
	n := 0
	for _, k := range t.kids {
		if len(k.kids) == 0 && k.sol {
			n++
		}
		if hasSiblingSolutions(k) {
			return true
		}
	}
	return n >= 2
}

@ For the exhaustive sweep I need every rooted ordered tree on $n$ nodes. A tree
is a root over a forest of $n-1$ nodes, and a forest is a first tree of some size
$k$ followed by a forest of the rest, so the two recursions call each other. The
counts are the Catalan numbers $1,1,2,5,14,42,\ldots$, which is why ten nodes is
about as far as this goes in a comfortable minute.
@<Functions@>=
func allTrees(n int) []*node {
	if n == 1 {
		return []*node{{}}
	}
	var forests func(int) [][]*node
	forests = func(rest int) [][]*node {
		if rest == 0 {
			return [][]*node{nil}
		}
		var res [][]*node
		for k := 1; k <= rest; k++ {
			for _, first := range allTrees(k) {
				for _, tail := range forests(rest - k) {
					res = append(res, append([]*node{first}, tail...))
				}
			}
		}
		return res
	}
	var out []*node
	for _, f := range forests(n - 1) {
		out = append(out, &node{kids: f})
	}
	return out
}

@* Running it.
The default mode rebuilds the figure on page 421. Answer 29 says the matrix for
the example tree has 15 columns and 14 rows, and prints it; this is where I
found that it does, to the bit.
@<Reproduce the printed matrix@>=
t := tree(*spec)
m := makeMatrix(t)
fmt.Printf("tree %s: %d nodes\n", t, t.size())
fmt.Printf("matrix: %d columns, %d rows\n", m.ncol, len(m.rows))
if m.ncol <= 40 {
	@<Print the matrix as an array of bits@>
}
tr := algX(m)
fmt.Printf("Algorithm X: %d nodes, %d solutions, %d non-unique minima\n",
	tr.nodes, tr.solutions, tr.ties)
fmt.Printf("backtrack tree = %s\n", tr.shape)
fmt.Printf("shape equals T: %v\n", sameShape(t, tr.shape))

@ @<Print the matrix as an array of bits@>=
for _, r := range m.rows {
	line := make([]byte, m.ncol)
	for i := range line {
		line[i] = '0'
	}
	for _, c := range r {
		line[c] = '1'
	}
	fmt.Printf("%s\n", line)
}

@ The same matrix in \.{DLX} text, which is what both of our engines read. Every
item is primary, so there is no vertical bar in the first line, and column $c$
is called \.{c}$c$.
@<Functions@>=
func dlxText(m matrix) string {
	var b strings.Builder
	for c := 0; c < m.ncol; c++ {
		fmt.Fprintf(&b, "c%d ", c)
	}
	b.WriteByte('\n')
	for _, r := range m.rows {
		for _, c := range r {
			fmt.Fprintf(&b, "c%d ", c)
		}
		b.WriteByte('\n')
	}
	return b.String()
}

@ @<Write the problem as \.{DLX} text@>=
os.Stdout.WriteString(dlxText(makeMatrix(tree(*spec))))

@ How many solutions a problem has does not depend on the algorithm that finds
them, so \.{ssxcc} can check that half of the work even though its search tree is
its own. In exercise 30 the answer should be the number of leaves we marked.
@<Ask \.{ssxcc} for a second opinion@>=
t := tree(*spec)
m := makeMatrix(t)
want := 0
for _, l := range leaves(t) {
	if l.sol {
		want++
	}
}
tr := algX(m)
fmt.Printf("tree %s: %d nodes, %d designated solution leaves\n",
	t, t.size(), want)
fmt.Printf("matrix: %d columns, %d rows\n", m.ncol, len(m.rows))
fmt.Printf("Algorithm X: %d nodes, %d solutions\n", tr.nodes, tr.solutions)
xc := cells.NewXCC()
xc.Debug = true
res := xc.Dance(strings.NewReader(dlxText(m)))
got := 0
for range res.Solutions {
	got++
}
fmt.Printf("ssxcc: %d solutions, %d nodes  (agrees: %v)\n",
	got, xc.Nodes(), got == want)

@ The exhaustive sweep settles it. Every ordered tree up to a given size,
every way of designating its leaves, both versions of answer 30. Ten nodes gives
258,564 pairs; the printed answer fails on one of them and the erratum on none.
@<Try every small tree@>=
total, bad := 0, 0
for n := 1; n <= *upto; n++ {
	for _, t := range allTrees(n) {
		@<Try every way of designating leaves as solutions@>
	}
}
fmt.Printf("errata=%v: %d (tree, marking) pairs, %d failures\n",
	errata, total, bad)

@ There are $2^L$ markings of a tree with $L$ leaves, and the bits of a counter
name them.
@<Try every way of designating leaves as solutions@>=
ls := leaves(t)
for mask := 0; mask < 1<<len(ls); mask++ {
	c := clone(t)
	cls := leaves(c)
	for i := range cls {
		cls[i].sol = mask&(1<<i) != 0
	}
	total++
	@<Judge this tree and marking@>
}

@ Four things must hold. The backtrack tree must have the shape we asked for; it
must have as many nodes as the tree has; step X3 must never have found a tie;
and the solutions must be exactly the leaves we starred. On top of that, the
duplicate rows in the matrix must appear precisely when two designated leaves
are siblings, which is the remark at the end of answer 30 read as a claim about
this construction.
@<Judge this tree and marking@>=
tr := algX(makeMatrix(c))
want := 0
for _, l := range leaves(c) {
	if l.sol {
		want++
	}
}
ok := sameShape(c, tr.shape) && tr.nodes == c.size() &&
	tr.ties == 0 && tr.solutions == want &&
	(tr.dups > 0) == hasSiblingSolutions(c)
if !ok {
	bad++
	if bad <= 12 {
		fmt.Printf("  FAIL %s\n", c)
	}
}

@ Before the sweep was written I ran the same judgment on random trees, which is
how the construction was first believed. It is kept because it reaches sizes the
sweep never will---a few thousand trees of twenty-odd nodes cost less than all
the trees of eleven.
@<Try random trees@>=
rnd := rand.New(rand.NewSource(*seed))
bad, most := 0, 0
for i := 0; i < *trials; i++ {
	t := randTree(rnd, *budget)
	if *sol {
		markSolutions(t, rnd, 0.4, *sibs)
	}
	@<Judge one random tree@>
}
fmt.Printf("%d trials, %d mismatches, most duplicate rows in one matrix: %d\n",
	*trials, bad, most)

@ @<Judge one random tree@>=
tr := algX(makeMatrix(t))
want := 0
for _, l := range leaves(t) {
	if l.sol {
		want++
	}
}
if tr.dups > most {
	most = tr.dups
}
if !(sameShape(t, tr.shape) && tr.nodes == t.size() &&
	tr.ties == 0 && tr.solutions == want) {
	bad++
	if bad <= 5 {
		fmt.Printf("MISMATCH tree=%s nodes=%d/%d ties=%d sols=%d/%d shape=%s\n",
			t, tr.nodes, t.size(), tr.ties, tr.solutions, want, tr.shape)
	}
}

@* Index.
