\input amssym
\input luamplib.sty

\datethis
\def\title{Bounded permutation problems}

@s big.Int int

@* Introduction.
Exercise 7.2.2.1--196 is an exercise in analysis rather than in search. It takes
the smallest interesting family of exact cover problems---the {\it bounded
permutation problem}, which asks for all permutations $p_1\ldots p_n$ of
$\{1,\ldots,n\}$ with $p_j\le a_j$---and asks exactly how much work
Algorithm~X does on it, counted in {\it updates}.

\smallskip
{\narrower\noindent
{\bf 196.} [{\it M29\/}]\enspace Given a bounded permutation problem defined by
$a_1\ldots a_n$, consider the ``dual'' problem defined by $b_1\ldots b_n$, where
$b_k$ is the number of $j$ such that $1\le j\le n$ and $a_j\ge n+1-k$.
[Equivalently, $b_n\ldots b_1$ is the conjugate of the integer partition
$a_n\ldots a_1$, in the sense of Section 7.2.1.4.]
\smallskip
\item{a)} What is the dual problem when $n=9$ and $a_1\ldots a_9=246677889$?
\item{b)} Prove that the solutions to the dual problem are essentially the
inverses of the permutations that solve the original problem.
\item{c)} If Algorithm~X begins with an $a_1$-way branch on item $X_1$, how many
updates does it perform while preparing for the subproblems at depth~1 of its
search tree?
\item{d)} How many solutions does a bounded permutation problem have, given
$a_1\ldots a_n$?
\item{e)} Give a formula for the total number of updates, assuming that the
algorithm always branches on $X_j$ at depth $j-1$ of the search tree.
\item{f)} Evaluate the formula of (e) when $a_j=n$ for $1\le j\le n$ (that is,
all permutations).
\item{g)} Evaluate the formula of (e) when $a_j=\min(j+1,n)$ for $1\le j\le n$.
\item{h)} Evaluate the formula of (e) when $a_j=\min(2j,n)$ for $1\le j\le n$.
\item{i)} Show, however, that the assumption in (e) is not always correct. How
can the total updates be calculated correctly in general?
\par}
\smallskip

@ Nine claims, every one of them a number or a formula, and every one of them
checkable. That is what this program does: it builds each problem, runs
Algorithm~X on it with the updates counted the way Knuth's own \.{DLX} programs
count them, and compares.
@^Knuth, Donald Ervin@>

I wrote it in September 2026 while reading the exercise and its answer
carefully, and it turned up three things worth reporting, all of them in the
answer rather than in the exercise. Answer~(h) states $\Pi_n$ without its two
factorial signs, though the same quantity appears with them on page~103.
Answer~(h) also opens its series with~6 where the term is~2. And the branching
sequence quoted at the end of answer~(i) is not the one Algorithm~X follows.

These notes, with the numbers this program produced, are the companion
document \.{README.md} in the directory above.

@ Here is the picture the exercise draws in the reader's head. On the left, the
$9\times9$ grid of options for $a_1\ldots a_9=246677889$: a cell in row $j$ and
column $k$ means that the option `$X_j\,Y_k$' exists, so the filled cells form
the Young diagram of the partition. Count the cells in each column and read the
counts from the right: they are $b_1\ldots b_9=135778899$, the dual problem.
That is the same fact as answer~(a)'s advice to draw the bipartite graph and
rotate it by $180^\circ$, which exchanges the $X$'s with the $Y$'s and reverses
each row. The middle panel shows which item Algorithm~X actually branches on at
each depth, and the right panel shows the updates per solution settling down to
$4e-1$ for two of the three families of parts~(f)--(h).

$$\mplibcode input staircase; \endmplibcode$$

@ The skeleton is a command line and a choice of what to check.
@c
package main

import (
	"flag"
	"fmt"
	"log"
	"math"
	"math/big"
	"sort"
	"strings"

	cells "github.com/sjnam/dancing-cells"
)

@<Declarations@>

@<Functions@>

func main() {
	@<Read the command line@>
	for _, m := range modes {
		switch m {
		case "dual":
			@<Take the dual, part (a)@>
		case "inverse":
			@<Match the solutions with their inverses, part (b)@>
		case "root":
			@<Count the updates at the root, part (c)@>
		case "count":
			@<Count the solutions, part (d)@>
		case "total":
			@<Count all of the updates, part (e)@>
		case "families":
			@<Evaluate the three families, parts (f), (g), (h)@>
		case "mrv":
			@<Watch the heuristic choose, part (i)@>
		case "sweep":
			@<Sweep every small problem@>
		default:
			log.Fatalf("unknown mode %q", m)
		}
	}
}

@ Mode \.{all} runs the eight checks in the order of the exercise.
@<Read the command line@>=
mode := flag.String("mode", "all",
	"dual, inverse, root, count, total, families, mrv, sweep, or all")
digits := flag.String("a", "246677889", "the sequence a_1...a_n, one digit each")
upto := flag.Int("upto", 9, "how far the exhaustive sweeps go")
top := flag.Int("top", 16, "largest n for the three families")
flag.Parse()
modes := []string{*mode}
if *mode == "all" {
	modes = []string{"dual", "inverse", "root", "count", "total",
		"families", "mrv", "sweep"}
}
a := digitSeq(*digits)

@* Algorithm X, with its updates counted.
An {\it update}, in the vocabulary of Section 7.2.2.1, is the removal of an
option from an item's list. Knuth's programs count one for every node that
|hide| unlinks and one more for every item that |cover| removes from the list
of items still to be covered; \.{DLX2} and its descendants report the total
alongside the number of solutions. So the quantity this exercise analyzes is a
property of the doubly linked lists themselves.

That rules out the engines in this repository. They descend from Knuth's
sparse-set programs, where an item is not covered by unlinking nodes but by
shortening a set, and where \.{ssxcc} forces items of size one before it
branches at all. Their update counts are their own. To read an exercise about
Algorithm~X I need Algorithm~X, links and all.

@ So here it is: a horizontal doubly linked list of the items still to be
covered, and a vertical doubly linked list for each item, threaded through a
node array with a spacer between consecutive options. The four operations that
work on it are |cover|, |hide|, |uncover| and |unhide|, exactly as in
(12)--(15) of the text.
@<Declarations@>=
type dlx struct {
	items                   int      // how many items there are
	name                    []string // item names, indexed from~1
	llink, rlink            []int    // the active items, in a ring
	top, ulink, dlink, size []int    // the node array
	opts                    [][]int  // the options, as lists of item numbers
	optOf                   []int    // which option each node belongs to
	path                    []int    // the options chosen on the way down
	updates                 uint64   // what the exercise is about
	nodes                   uint64   // the size of the search tree
	count                   uint64   // solutions found
	prep                    uint64   // updates spent preparing depth~1
	leftmost                bool     // branch leftmost, not on the fewest
	chose                   []map[string]bool
	sols                    [][]int // the solutions, if |keep|
	keep                    bool
}

@ Item $i$ occupies |name[i]| and node~$i$, for $1\le i\le|items|$; node~0 heads
the ring of active items and never moves.
@<Functions@>=
func newDLX(names []string, opts [][]int) *dlx {
	n := len(names)
	d := &dlx{items: n, name: append([]string{""}, names...), opts: opts}
	d.llink = make([]int, n+1)
	d.rlink = make([]int, n+1)
	for i := 0; i <= n; i++ {
		d.llink[i], d.rlink[i] = (i+n)%(n+1), (i+1)%(n+1)
	}
	@<Lay out the node array@>
	return d
}

@ Each option contributes one node per item, appended to the bottom of that
item's list, and then a spacer. A spacer has a nonpositive |top|; its |ulink|
points at the first node of the option above it and its |dlink| at the last node
of the option below, which is what lets |hide| walk an option in a circle.
@<Lay out the node array@>=
d.top = make([]int, n+2)
d.ulink = make([]int, n+2)
d.dlink = make([]int, n+2)
d.size = make([]int, n+2)
d.optOf = make([]int, n+2)
for i := 0; i <= n; i++ {
	d.ulink[i], d.dlink[i] = i, i
}
d.optOf[n+1] = -1
for k, o := range opts {
	first := len(d.top)
	for _, i := range o {
		u := d.ulink[i]
		d.top = append(d.top, i)
		d.ulink = append(d.ulink, u)
		d.dlink = append(d.dlink, i)
		d.size = append(d.size, 0)
		d.optOf = append(d.optOf, k)
		x := len(d.top) - 1
		d.dlink[u], d.ulink[i] = x, x
		d.size[i]++
	}
	d.dlink[first-1] = len(d.top) - 1
	d.top = append(d.top, -(k + 1))
	d.ulink = append(d.ulink, first)
	d.dlink = append(d.dlink, 0)
	d.size = append(d.size, 0)
	d.optOf = append(d.optOf, -1)
}

@ Covering item $i$ hides every option that uses it and then unlinks $i$ itself.
The last line is the update that answer~(c) counts as its leading~1.
@<Functions@>=
func (d *dlx) cover(i int) {
	for p := d.dlink[i]; p != i; p = d.dlink[p] {
		@<Hide the other items of the option through |p|@>
	}
	l, r := d.llink[i], d.rlink[i]
	d.rlink[l], d.llink[r] = r, l
	d.updates++
}

@ Hiding walks the option rightward from |p|, wrapping at the spacer, and takes
each node out of its item's list. One update apiece.
@<Hide the other items of the option through |p|@>=
for q := p + 1; q != p; {
	x := d.top[q]
	if x <= 0 {
		q = d.ulink[q]
		continue
	}
	u, w := d.ulink[q], d.dlink[q]
	d.dlink[u], d.ulink[w] = w, u
	d.size[x]--
	d.updates++
	q++
}

@ Uncovering runs the film backwards and costs nothing, which is why the
exercise can speak of the updates of a whole search as a single number.
@<Functions@>=
func (d *dlx) uncover(i int) {
	l, r := d.llink[i], d.rlink[i]
	d.rlink[l], d.llink[r] = i, i
	for p := d.ulink[i]; p != i; p = d.ulink[p] {
		@<Unhide the other items of the option through |p|@>
	}
}

@ @<Unhide the other items of the option through |p|@>=
for q := p - 1; q != p; {
	x := d.top[q]
	if x <= 0 {
		q = d.dlink[q]
		continue
	}
	u, w := d.ulink[q], d.dlink[q]
	d.dlink[u], d.ulink[w] = q, q
	d.size[x]++
	q--
}

@ Steps X2--X8. An empty item list is a solution; otherwise we choose an item,
cover it, and try each of its options in turn.
@<Functions@>=
func (d *dlx) search(depth int) {
	d.nodes++
	if d.rlink[0] == 0 {
		@<Record a solution@>
		return
	}
	i := d.branchItem(depth)
	mark := d.updates
	d.cover(i)
	if depth == 0 {
		d.prep += d.updates - mark
	}
	for x := d.dlink[i]; x != i; x = d.dlink[x] {
		@<Cover the other items of option |x|@>
		d.path[depth] = d.optOf[x]
		d.search(depth + 1)
		@<Uncover the other items of option |x|@>
	}
	d.uncover(i)
}

@ Part (c) asks for exactly the updates counted here plus the |cover(i)| above:
what it costs to have the depth-1 subproblems standing and ready, and nothing
of what happens inside them.
@<Cover the other items of option |x|@>=
mark = d.updates
for p := x + 1; p != x; {
	j := d.top[p]
	if j <= 0 {
		p = d.ulink[p]
		continue
	}
	d.cover(j)
	p++
}
if depth == 0 {
	d.prep += d.updates - mark
}

@ @<Uncover the other items of option |x|@>=
for p := x - 1; p != x; {
	j := d.top[p]
	if j <= 0 {
		p = d.dlink[p]
		continue
	}
	d.uncover(j)
	p--
}

@ Step X3, the MRV heuristic: the item with the fewest remaining options wins,
and among equals the one that comes first in the item list. That is the rule in
Knuth's programs, where the scan keeps a candidate only when it is strictly
smaller. Setting |leftmost| replaces the contest by the assumption of part~(e),
which for our item order means branching on $X_j$ at depth $j-1$.
@<Functions@>=
func (d *dlx) branchItem(depth int) int {
	best := d.rlink[0]
	if !d.leftmost {
		least := 1 << 30
		for i := d.rlink[0]; i != 0; i = d.rlink[i] {
			if d.size[i] < least {
				best, least = i, d.size[i]
			}
		}
	}
	if d.chose != nil && depth < len(d.chose) {
		d.chose[depth][d.name[best]] = true
	}
	return best
}

@ A solution is a set of options, one per item of the left half; read off the
right half and it is a permutation.
@<Record a solution@>=
d.count++
if d.keep {
	n := d.items / 2
	p := make([]int, n)
	for k := 0; k < n; k++ {
		o := d.opts[d.path[k]]
		p[o[0]-1] = o[1] - n
	}
	d.sols = append(d.sols, p)
}

@* Bounded permutation problems.
The problem for $a_1\ldots a_n$ has $2n$ items $X_1,\ldots,X_n$,
$Y_1,\ldots,Y_n$ and the $a_1+\cdots+a_n$ options `$X_j\,Y_k$' for
$1\le k\le a_j$. The order of the items is the order in which they are declared,
and it decides the ties in step X3; I put the $X$'s first, as the exercise does.
@<Functions@>=
func problem(a []int) *dlx {
	n := len(a)
	names := make([]string, 0, 2*n)
	for j := 1; j <= n; j++ {
		names = append(names, fmt.Sprintf("X%d", j))
	}
	for k := 1; k <= n; k++ {
		names = append(names, fmt.Sprintf("Y%d", k))
	}
	var opts [][]int
	for j := 1; j <= n; j++ {
		for k := 1; k <= a[j-1]; k++ {
			opts = append(opts, []int{j, n + k})
		}
	}
	d := newDLX(names, opts)
	d.path = make([]int, n+1)
	return d
}

@ Three assumptions come free with the problem, as page 103 explains: $a$ is
nondecreasing, $a_j\ge j$, and $a_n\le n$. A sequence that breaks the middle one
has no solutions at all, so the sweeps stay inside the canonical form.
@<Functions@>=
func canonical(a []int) bool {
	n := len(a)
	for j := 1; j <= n; j++ {
		if a[j-1] < j || a[j-1] > n {
			return false
		}
		if j > 1 && a[j-2] > a[j-1] {
			return false
		}
	}
	return true
}

@ @<Functions@>=
func digitSeq(s string) []int {
	a := make([]int, len(s))
	for i, c := range s {
		if c < '1' || c > '9' {
			log.Fatalf("bad sequence %q", s)
		}
		a[i] = int(c - '0')
	}
	if !canonical(a) {
		log.Fatalf("%q is not a canonical bounded permutation problem", s)
	}
	return a
}

@ The dual counts, for each $k$, how many of the $a_j$ reach as high as
$n+1-k$. Rotating the Young diagram of $a$ by $180^\circ$ turns rows into
columns and back to rows, which is why $b_n\ldots b_1$ is the conjugate
partition of $a_n\ldots a_1$ and why dualizing twice gives $a$ again.
@<Functions@>=
func dual(a []int) []int {
	n := len(a)
	b := make([]int, n)
	for k := 1; k <= n; k++ {
		for _, aj := range a {
			if aj >= n+1-k {
				b[k-1]++
			}
		}
	}
	return b
}

@ @<Functions@>=
func show(a []int) string {
	var b strings.Builder
	for _, x := range a {
		fmt.Fprintf(&b, "%d", x)
	}
	return b.String()
}

@ Part (a) wants one dual, and gets three checks: the printed answer, the
involution, and the canonical form.
@<Take the dual, part (a)@>=
b := dual(a)
fmt.Printf("(a) a = %s, dual b = %s (answer: 135778899, agrees: %v)\n",
	show(a), show(b), show(b) == "135778899")
fmt.Printf("    b is canonical: %v; dual of the dual is a: %v\n",
	canonical(b), show(dual(b)) == show(a))

@* Inverses.
Part (b) says two things. The options correspond: with $\bar k=n+1-k$,
`$X_j\,Y_k$' is a dual option if and only if `$Y_{\bar\jmath}\,X_{\bar k}$' is
an original one. And so do the solutions: $q_1\ldots q_n$ is the inverse of an
original solution if and only if $\bar q_n\ldots\bar q_1$ is a dual solution.

The first half is a statement about the sequences alone, and it comes out of the
definition. Since $a$ is nondecreasing, $b_j$ counts a final segment of the
$a$'s: $b_j=n-t+1$ where $t$ is least with $a_t\ge n+1-j$. Then $k\le b_j$ says
$n+1-k\ge t$, which says $a_{n+1-k}\ge n+1-j$. That is the claim.
@<Functions@>=
func optionsMatch(a []int) bool {
	n := len(a)
	b := dual(a)
	for j := 1; j <= n; j++ {
		for k := 1; k <= n; k++ {
			if (k <= b[j-1]) != (n+1-j <= a[n-k]) {
				return false
			}
		}
	}
	return true
}

@ The second half I check by enumeration, which is why this sweep stops sooner
than the others. Take every solution of the original
problem, invert the permutation, reverse it and complement each entry; the
result should be exactly the set of solutions of the dual, with nothing left
over on either side.
@<Functions@>=
func inversesMatch(a []int) bool {
	n := len(a)
	@<Collect the solutions of |a| and of its dual@>
	for _, p := range orig {
		inv := make([]int, n)
		for j := 1; j <= n; j++ {
			inv[p[j-1]-1] = j
		}
		r := make([]int, n)
		for j := 1; j <= n; j++ {
			r[j-1] = n + 1 - inv[n-j]
		}
		if !want[show(r)] {
			return false
		}
		delete(want, show(r))
	}
	return len(want) == 0
}

@ @<Collect the solutions of |a| and of its dual@>=
d := problem(a)
d.keep = true
d.search(0)
orig := d.sols
e := problem(dual(a))
e.keep = true
e.search(0)
want := map[string]bool{}
for _, q := range e.sols {
	want[show(q)] = true
}

@ @<Match the solutions with their inverses, part (b)@>=
fmt.Printf("(b) a = %s: options correspond: %v; solutions invert: %v\n",
	show(a), optionsMatch(a), inversesMatch(a))
bad, seqs, far := 0, 0, min(*upto, 7)
for n := 1; n <= far; n++ {
	for _, c := range allSeqs(n) {
		seqs++
		if !optionsMatch(c) || !inversesMatch(c) {
			bad++
			fmt.Println("    FAILS:", show(c))
		}
	}
}
fmt.Printf("    every problem with n <= %d: %d sequences, %d failures\n",
	far, seqs, bad)

@* Preparing the subproblems.
Answer (c) says the root costs $1+a_1(n+1)$ updates, ``because each $Y_k$ for
$1\le k\le a_1$ appears in $n$ options.'' Follow the algorithm: covering $X_1$
unlinks $X_1$ itself, one update, and hides the single $Y$ node of each of its
$a_1$ options, $a_1$ more. Then each of the $a_1$ branches covers its $Y_k$,
which now has $n-1$ options left, for $1+(n-1)=n$ updates apiece. Altogether
$1+a_1+a_1n$.

The program measures it instead of arguing: |prep| accumulates exactly the
updates made at depth~0, and nothing from inside the subtrees.
@<Count the updates at the root, part (c)@>=
fmt.Println("(c) updates spent preparing the depth-1 subproblems")
for _, c := range []([]int){a, digitSeq("123456789"), digitSeq("999999999"),
	digitSeq("234456789"), digitSeq("22")} {
	d := problem(c)
	d.leftmost = true // the branch on $X_1$ that part (c) assumes
	d.search(0)
	n := len(c)
	fmt.Printf("    a = %-9s measured %5d   1+a_1(n+1) = %5d   %v\n",
		show(c), d.prep, 1+c[0]*(n+1), d.prep == uint64(1+c[0]*(n+1)))
}

@* How many solutions.
Answer (d) is $a_1(a_2-1)(a_3-2)\ldots(a_n-n+1)$: having chosen $p_1,\ldots,
p_{j-1}$, all of them at most $a_{j-1}\le a_j$, the values still open to $p_j$
number $a_j-j+1$ whatever the earlier choices were. The same count applied to
the dual must give the same answer, which the exercise calls not an obvious
fact, and which part~(b) explains.

The partial products are the ones that count the search tree, so they get a
name of their own.
@<Functions@>=
func bigPi(a []int, j int) *big.Int {
	p := big.NewInt(1)
	for i := 1; i <= j; i++ {
		p.Mul(p, big.NewInt(int64(a[i-1]-i+1)))
	}
	return p
}

@ For a second opinion on the number of solutions I hand the same problem to
\.{ssxcc}, the engine of this repository, in the \.{DLX} text format. How many
solutions a problem has does not depend on the algorithm that finds them.
@<Functions@>=
func dlxText(a []int) string {
	n := len(a)
	var b strings.Builder
	for j := 1; j <= n; j++ {
		fmt.Fprintf(&b, "X%d ", j)
	}
	for k := 1; k <= n; k++ {
		fmt.Fprintf(&b, "Y%d ", k)
	}
	b.WriteByte('\n')
	for j := 1; j <= n; j++ {
		for k := 1; k <= a[j-1]; k++ {
			fmt.Fprintf(&b, "X%d Y%d\n", j, k)
		}
	}
	return b.String()
}

@ @<Functions@>=
func ssxccCount(a []int) uint64 {
	x := cells.NewXCC()
	res := x.Dance(strings.NewReader(dlxText(a)))
	var n uint64
	for range res.Solutions {
		n++
	}
	return n
}

@ @<Count the solutions, part (d)@>=
fmt.Println("(d) solutions, by the formula and by three searches")
for _, c := range []([]int){a, digitSeq("123456789"), digitSeq("999999999"),
	digitSeq("246688999")} {
	n := len(c)
	d := problem(c)
	d.search(0)
	pa, pb := bigPi(c, n), bigPi(dual(c), n)
	fmt.Printf("    a = %-9s formula %-7s dual %-7s Algorithm X %-7d"+
		" ssxcc %-7d  %v\n", show(c), pa, pb, d.count, ssxccCount(c),
		pa.Cmp(pb) == 0 && pa.String() == fmt.Sprint(d.count) &&
			d.count == ssxccCount(c))
}

@* The total.
Answer (e) reads $1+\bigl(\sum_{j=1}^n(n+3-j)\Pi_j\bigr)-\Pi_n$, where
$\Pi_j=\prod_{i=1}^j(a_i-i+1)$. It follows from (c). Each of the $\Pi_{j-1}$
nodes at depth $j-1$ faces a bounded permutation problem on $n-j+1$ items whose
first bound is $a_j-j+1$, so by~(c) it spends $1+(a_j-j+1)(n-j+2)$ updates
getting its children ready. Summing,
$$\sum_{j=1}^n\Pi_{j-1}+\sum_{j=1}^n(n-j+2)\Pi_j
 =1+\sum_{j=1}^n\Pi_j-\Pi_n+\sum_{j=1}^n(n-j+2)\Pi_j,$$
which is the printed formula.
@<Functions@>=
func total(a []int) *big.Int {
	n := len(a)
	t := big.NewInt(1)
	for j := 1; j <= n; j++ {
		t.Add(t, new(big.Int).Mul(big.NewInt(int64(n+3-j)), bigPi(a, j)))
	}
	return t.Sub(t, bigPi(a, n))
}

@ @<Count all of the updates, part (e)@>=
fmt.Println("(e) all the updates, under the assumption of (e)")
for _, c := range []([]int){a, digitSeq("123456789"), digitSeq("999999999"),
	digitSeq("246688999"), digitSeq("234567899")} {
	d := problem(c)
	d.leftmost = true
	d.search(0)
	t := total(c)
	fmt.Printf("    a = %-9s measured %-10d formula %-10s %v\n",
		show(c), d.updates, t, t.String() == fmt.Sprint(d.updates))
}

@* Three families.
Parts (f), (g) and (h) evaluate the formula on three sequences that grow with
$n$: every permutation, $a_j=\min(j+1,n)$, and $a_j=\min(2j,n)$. All three
satisfy the assumption of part~(e)---the sweep in the last section shows that
the heuristic really does branch on $X_j$ throughout---so the formula and the
search must agree, and the interest is in what the closed forms say.
@<Functions@>=
func family(kind byte, n int) []int {
	a := make([]int, n)
	for j := 1; j <= n; j++ {
		switch kind {
		case 'f':
			a[j-1] = n
		case 'g':
			a[j-1] = min(j+1, n)
		case 'h':
			a[j-1] = min(2*j, n)
		}
	}
	return a
}

@ Answer (f) is $1+\bigl(\sum_{j=1}^n(n+3-j)n^{\underline j}\bigr)-n!$, which is
about $(4e-1)n!$; here $\Pi_j$ is the falling factorial power. Answer~(g) is
$6\cdot2^n-2n-7$, since $\Pi_j=2^j$ for $j<n$ and $\Pi_n=2^{n-1}$. Answer~(h)
gives $\Pi_n$ and says the updates per solution again approach $4e-1$.
@<Functions@>=
func closedForm(kind byte, n int) *big.Int {
	switch kind {
	case 'g': // $6\cdot2^n-2n-7$
		t := new(big.Int).Lsh(big.NewInt(6), uint(n))
		return t.Sub(t, big.NewInt(int64(2*n+7)))
	case 'h': // the $\Pi_n$ of answer (h), with its factorials
		p := new(big.Int).MulRange(1, int64((n+1)/2))
		return p.Mul(p, new(big.Int).MulRange(1, int64((n+2)/2)))
	}
	return new(big.Int).MulRange(1, int64(n)) // $n!$, the solutions in (f)
}

@ @<Functions@>=
func ratio(x, y *big.Int) float64 {
	f, _ := new(big.Rat).SetFrac(x, y).Float64()
	return f
}

@ Each family gets a table: the updates, the solutions, their quotient, and
wherever the search is still small enough to run, the count Algorithm~X
actually makes.
@<Evaluate the three families, parts (f), (g), (h)@>=
for _, kind := range []byte{'f', 'g', 'h'} {
	@<Announce the family@>
	for n := 1; n <= *top; n++ {
		c := family(kind, n)
		t, sols := total(c), bigPi(c, n)
		line := fmt.Sprintf("    n = %2d  updates %-14s solutions %-11s"+
			" per solution %9.6f", n, t, sols, ratio(t, sols))
		@<Compare with the closed form and with a real search@>
		fmt.Println(line)
	}
}
@<Look at the series of answer (h)@>

@ @<Announce the family@>=
switch kind {
case 'f':
	fmt.Println("(f) a_j = n, all permutations")
case 'g':
	fmt.Println("(g) a_j = min(j+1,n)")
case 'h':
	fmt.Println("(h) a_j = min(2j,n)")
}

@ In family (g) the closed form is the update total; in (f) and (h) it is the
number of solutions. Running the search itself costs $\Pi_n$ time, so I stop
when that gets silly.
@<Compare with the closed form and with a real search@>=
cf := closedForm(kind, n)
if kind == 'g' {
	line += fmt.Sprintf("  6*2^n-2n-7 %v", cf.Cmp(t) == 0)
} else {
	line += fmt.Sprintf("  closed form %v", cf.Cmp(sols) == 0)
}
if sols.IsInt64() && sols.Int64() < 100000 {
	d := problem(c)
	d.search(0)
	line += fmt.Sprintf("  search %v",
		t.String() == fmt.Sprint(d.updates) && d.count == uint64(sols.Int64()))
}

@ The one place where the printed answer and the arithmetic part company is the
series in~(h). Divide the total by $\Pi_n$ and let $i=n-j$: the terms with
$j>n/2$ contribute $\sum_i(i+3)/i!$, the terms with $j\le n/2$ are the
$O(n^2/(n/2)!)$ remainder, and the $-\Pi_n$ contributes $-1$. So the series is
$$(3-1)+4/1!+5/2!+\cdots\;=\;4e-1,$$
with 2 in front, not 6. The printed 6 would make the sum $4e+3$, which is not
what the same line says it converges to.
@<Look at the series of answer (h)@>=
sum, fact := 0.0, 1.0
for i := 1; i <= 20; i++ {
	fact *= float64(i)
	sum += float64(i+3) / fact
}
fmt.Printf("(h) 4e-1 = %.9f;  2+4/1!+5/2!+... = %.9f;  6+4/1!+5/2!+... = %.9f\n",
	4*math.E-1, 2+sum, 6+sum)
c := family('h', 200)
fmt.Printf("    the ratio at n = 200 is %.9f\n", ratio(total(c), bigPi(c, 200)))

@* What the heuristic really does.
Part (i) grants that the assumption of (e) can fail, and says why: if $b_1<a_1$
then $Y_n$ has fewer options than $X_1$, so the first branch is on $Y_n$, not
$X_1$, and the root costs $1+b_1(n+1)$ updates. It closes with an example:
``The example problem in~(a) branches on $Y_9$, then $X_2$, then $Y_8$, etc.''

Two of those three claims survive the reading. The count $1+b_1(n+1)$ is right
every time. The branching sequence is not.
@<Watch the heuristic choose, part (i)@>=
@<Show the items the heuristic picks@>
@<Check the root cost when the dual wins@>
@<Check the general recursion@>

@ Watching is a matter of recording, at each depth, the names of the items that
step X3 chose there---a set, because different branches may reach different
subproblems.
@<Show the items the heuristic picks@>=
n := len(a)
d := problem(a)
d.chose = make([]map[string]bool, n)
for i := range d.chose {
	d.chose[i] = map[string]bool{}
}
d.search(0)
fmt.Printf("(i) a = %s: the items step X3 branches on\n", show(a))
for i, s := range d.chose {
	var names []string
	for k := range s {
		names = append(names, k)
	}
	sort.Strings(names)
	fmt.Printf("    depth %d: %s\n", i, strings.Join(names, " "))
}
fmt.Printf("    Algorithm X makes %d updates and %d nodes here;"+
	" the formula of (e) says %s\n", d.updates, d.nodes, total(a))

@ The rule behind the sequence is easy to state. Because $a$ is nondecreasing,
the shortest $X$ item is $X_1$ with $a_1$ options; because $b$ is nondecreasing,
the shortest $Y$ item has $b_1$ options. Ties go to the $X$, which is declared
first. So the branch is on an $X$ exactly when $a_1\le b_1$.

For $246677889$ that gives $Y_9$, then $X_1$, then $Y_8$, then $X_2$: the two
sides alternate while the bounds stay tight. Answer~(i) omits the $X_1$ and puts
$X_2$ where $Y_8$ belongs.

@ There is a second, smaller slip in the same sentence. The shortest $Y$ item is
$Y_n$ only if no other $Y$ ties with it, and ties do happen: if the $a_j$ skip a
value, several $Y$'s have the same length and step X3 takes the leftmost. The
sweep below counts how often. The update total is unaffected, because the tied
items are the ones whose options all lead to $X$'s of full length $n$.
@<Check the root cost when the dual wins@>=
tried, notLast, wrong := 0, 0, 0
first := ""
for n := 1; n <= *upto+1; n++ {
	for _, c := range allSeqs(n) {
		b1 := dual(c)[0]
		if b1 >= c[0] {
			continue
		}
		tried++
		@<Run the root and check what it chose@>
	}
}
fmt.Printf("    problems with b_1 < a_1 (n <= %d): %d of them, %d cost"+
	" something other than 1+b_1(n+1)\n", *upto+1, tried, wrong)
fmt.Printf("    %d branch on a Y other than Y_n; the first is a = %s\n",
	notLast, first)

@ @<Run the root and check what it chose@>=
d := problem(c)
d.chose = []map[string]bool{{}}
d.search(0)
if d.prep != uint64(1+b1*(n+1)) {
	wrong++
}
if !d.chose[0][fmt.Sprintf("Y%d", n)] {
	notLast++
	if first == "" {
		first = show(c)
	}
}

@ ``How can the total updates be calculated correctly in general?'' By the same
recursion, with the choice put in. Let $b_1$ be the number of $a_i$ equal to
$n$. If $a_1\le b_1$ the algorithm branches on $X_1$, spends $1+a_1(n+1)$
updates, and hands each of $a_1$ children the problem $(a_2-1)\ldots(a_n-1)$.
Otherwise it branches on the shortest $Y$, spends $1+b_1(n+1)$, and hands each
of $b_1$ children the problem $\min(a_1,n-1)\ldots\min(a_{n-1},n-1)$. Both
children are the same for every branch, which is what makes a recursion on the
sequence alone possible; and both are canonical.
@<Functions@>=
func mrvTotal(a []int) *big.Int {
	n := len(a)
	if n == 0 {
		return big.NewInt(0)
	}
	b1, sub := 0, make([]int, n-1)
	for _, x := range a {
		if x == n {
			b1++
		}
	}
	branches := a[0]
	if a[0] <= b1 {
		for i := 1; i < n; i++ {
			sub[i-1] = a[i] - 1
		}
	} else {
		branches = b1
		for i := 0; i < n-1; i++ {
			sub[i] = min(a[i], n-1)
		}
	}
	t := big.NewInt(int64(1 + branches*(n+1)))
	return t.Add(t, new(big.Int).Mul(big.NewInt(int64(branches)), mrvTotal(sub)))
}

@ @<Check the general recursion@>=
fmt.Printf("    the recursion gives %s for a = %s\n", mrvTotal(a), show(a))
seqs, bad := 0, 0
for n := 1; n <= *upto; n++ {
	for _, c := range allSeqs(n) {
		d := problem(c)
		d.search(0)
		seqs++
		if mrvTotal(c).String() != fmt.Sprint(d.updates) {
			bad++
			fmt.Println("      FAILS:", show(c))
		}
	}
}
fmt.Printf("    every problem with n <= %d: %d sequences, %d failures\n",
	*upto, seqs, bad)

@* Sweeps.
Every canonical sequence up to a given length, in lexicographic order.
@<Functions@>=
func allSeqs(n int) [][]int {
	var out [][]int
	cur := make([]int, n)
	var rec func(j, prev int)
	rec = func(j, prev int) {
		if j > n {
			out = append(out, append([]int(nil), cur...))
			return
		}
		for v := max(j, prev); v <= n; v++ {
			cur[j-1] = v
			rec(j+1, v)
		}
	}
	rec(1, 1)
	return out
}

@ How many such sequences are there? A nondecreasing $a_1\ldots a_n$ with
$j\le a_j\le n$ is a ballot sequence read sideways, so there are $C_n$ of them,
the Catalan number; the sweep confirms $1,2,5,14,42,132,429$ as it goes.
@<Functions@>=
func catalan(n int) *big.Int {
	c := new(big.Int).Binomial(int64(2*n), int64(n))
	return c.Div(c, big.NewInt(int64(n+1)))
}

@ The last mode puts the four formulas side by side on every small problem at
once: the solution count of (d), the update total of (e) under its assumption,
the recursion of (i) against the real search, and the question of how often the
assumption of (e) holds at all.
@<Sweep every small problem@>=
fmt.Printf("sweep: every canonical a_1...a_n with n <= %d\n", *upto)
for n := 1; n <= *upto; n++ {
	seqs, badD, badE, badI, differ := 0, 0, 0, 0, 0
	for _, c := range allSeqs(n) {
		seqs++
		@<Compare the formulas on |c|@>
	}
	fmt.Printf("    n = %d: %5d sequences (Catalan: %v), %d/%d/%d failures"+
		" in (d)/(e)/(i), %d where the heuristic leaves the assumption"+
		" of (e)\n", n, seqs, catalan(n).String() == fmt.Sprint(seqs),
		badD, badE, badI, differ)
}

@ Running the same problem twice, once with the heuristic and once with the
leftmost rule, is what separates the assumption of part~(e) from what
Algorithm~X does. The two agree on the number of solutions, never on more.
@<Compare the formulas on |c|@>=
x := problem(c)
x.leftmost = true
x.search(0)
m := problem(c)
m.search(0)
if bigPi(c, n).String() != fmt.Sprint(m.count) {
	badD++
}
if total(c).String() != fmt.Sprint(x.updates) {
	badE++
}
if mrvTotal(c).String() != fmt.Sprint(m.updates) {
	badI++
}
if x.updates != m.updates {
	differ++
}

@* Index.
