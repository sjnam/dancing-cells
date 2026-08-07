\input amssym

\def\title{Hungarian Dance No.\thinspace5}

@s Option int
@s Frame int
@s Builder int
@s Duration int
@s Rand int
@s Time int

@* Hungarian Dance No.\thinspace5.
This program began with Brahms. Somewhere in the headlong $\rm F\sharp$ minor
of the fifth Hungarian Dance a thought arrived: what would happen if {\it
dancing cells\/} and the {\it Hungarian algorithm\/} were put on the same
floor? Both carry a dance and a country in their names, and so far as I can
tell they have never met.

Brahms never claimed to have composed the twenty-one dances. The title page of
the first edition says {\it gesetzt\/}---set, arranged---and not {\it
komponiert}. He was putting tunes he had picked up from Hungarian players into
a frame of his own. No.\thinspace5 goes one better: the melody Brahms took for
an anonymous folk song was in fact the cs\'ard\'as ``B\'artfai eml\'ek'' by a
named Hungarian composer, K\'eler B\'ela. A borrowed tune in a borrowed frame,
with the debt written into the title.

The Hungarian algorithm has precisely the same provenance. When Harold Kuhn
called his 1955 method for the assignment problem ``Hungarian,'' it was to
write into the title the debt he owed K\H{o}nig and Egerv\'ary. What Brahms did,
Kuhn did again.
@^Egerv\'ary, Eugen (= Jen\H{o})@>
@:Konig}{K\H{o}nig, D\'enes@>

And a cs\'ard\'as is built of two strains. A slow {\it lass\'u\/} and a
headlong {\it friss\/} alternate, and No.\thinspace5 keeps holding back and
then tearing away. Which is exactly the shape of the search we are about to
build.

The Hungarian algorithm is the slow strain. It is deliberate, spending
$O(m^3)$ at every node to measure {\it exactly\/} what the rest of the problem
is worth. Dancing cells is the fast one. Covering an item is a handful of array
swaps, and backing out again is a matter of restoring sizes. Every node
alternates the two: measure slowly, descend quickly, measure slowly again.

If the thing wants a name, let it be the {\it Hungarian Dance technique}. Not
an algorithm: no new procedure is invented here. It is a name for where two
existing algorithms are made to mesh---the branching danced by cells, the
bounding set by Hungary.

So what shall we solve? A {\it Latin square\/} of order~$n$ fills an
$n\times n$ grid with $n$ symbols so that no symbol repeats within any row or
any column---the grid Sudoku is played on. A {\it transversal\/} of that square
is a choice of $n$ cells, one from each row and one from each column, whose
symbols are all different as well. Rows, columns, and symbols: $n$ of each, and
every one of them used exactly once.

Transversals are an old question. Euler's thirty-six officers really asked
whether two Latin squares interlock, and a square that splits cleanly into
transversals is the same thing as a square that has a mate. Even orders with no
transversal at all have been known for a long time (the addition table of
$\Bbb Z_n$ is one); Ryser conjectured that a square of odd order must have one,
and Brualdi and Stein conjectured that every square has a partial transversal
of $n-1$ cells. Both are still open.

Our question lays one more layer on top. Suppose every cell carries a price.
Then we may ask:
$$\hbox{\it Which transversal costs the least?}$$
``Is there a transversal?'' is exact cover. There are $3n$ items---$n$ rows,
$n$ columns, $n$ symbols---and $n^2$ options, one per cell; the option for cell
$(i,j)$ covers row~$i$, column~$j$, and the symbol written there. Transversals
of the square and exact covers of that problem correspond one to one. |cells.Dance|
answers this much.

``Which costs the least?'' is answered by |cells.Minimize|. Price the options and the
engine searches by branch and bound, sending out each transversal that is
cheaper than everything before it; the last one to arrive is the cheapest.
That much is easy too---all it takes is a price list. The meat is what comes
next, the {\it bound}.

@ Why is this the right floor on which to make the two algorithms meet?
Finding a transversal is {\it 3-dimensional matching}: rows, columns, and
symbols interlocked all at once, and one of Karp's twenty-one NP-complete
problems. But erase {\it any one\/} of the three axes and what remains is
2-dimensional matching, which is to say the assignment problem. Forget that the
symbols must differ and only ``one per row, one per column'' is left---and that
falls in polynomial time. The Hungarian algorithm solves it {\it exactly\/} in
$O(n^3)$.

The drop between those two sentences is the whole point. What we relax to is
not an estimate but {\it a subproblem's exact optimum}, so the bound is strong.
And the relaxation has the same shape as the original, so the live (item,
option) pairs that |cells.Frame| hands out can be poured straight into a matrix.
There is no second data structure to build.

In short: {\it NP-hard, but polynomial one dimension down}. No better floor for
dancing cells and a Hungarian dance together.

So far as I could find, nobody has put the two together in quite this way.
Using the Hungarian method for a branch-and-bound lower bound is an old trick,
but what I turned up is mostly about the quadratic assignment problem; and
where the {\tt DLX} line has been given costs and bounds, the bound was not
Hungarian. I did not search hard enough to say it has never been done---only
that I did not find it.

For the square we take the addition table of $\Bbb Z_n$, that is
$L_{ij}=(i+j)\bmod n$, because it divides so amusingly by parity. As Hall and
Paige showed in 1955, $\Bbb Z_n$ has transversals only when $n$ is odd, and
their counts are \pdfURL{OEIS \.{A006717}}{https://oeis.org/A006717}: 15,
133, 2025, 37851 for $n=5,7,9,11$. This
program counts exactly those. The skeleton follows the story just told.
@c
package main

import (
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"time"

	cells "github.com/sjnam/dancing-cells"
)

@<Data structures@>

@<Functions@>

func main() {
	@<Read the command line@>
	@<Build the square and price it@>
	@<Make the cover problem and solve it@>
	@<Show the answer and the effort@>
}

@ The command line takes one thing, the order of the square. Prices come from
a random generator, so a different seed makes a different problem, and
`\.{-plain}' solves it a second time with the bound taken off, for the sake of
comparing node counts. That is: what happens if you dance the fast strain
without the slow one. Dropping the slow strain does not turn the search back
into |cells.Dance|, though. All that stops is the measuring of what is left to
pay; a branch whose price has already overtaken the incumbent is folded just
the same. The fast strain, danced with the bound set to zero.
@<Read the command line@>=
seed := flag.Int64("seed", 1, "random seed for the cell prices")
plain := flag.Bool("plain", false, "also solve without the bound, to compare")
flag.Parse()
if flag.NArg() != 1 {
	log.Fatalf("usage: %s [-seed n] [-plain] order\n", os.Args[0])
}
n, err := strconv.Atoi(flag.Arg(0))
if err != nil || n < 1 {
	log.Fatalf("the order must be a positive integer\n")
}

@* The square and its prices.
One |board| carries everything this computation needs. The first half is the
problem itself; the second half is the household the bound keeps and rummages
through at every node. It is allocated up front for one reason: |cells.Bound| is
called once per search node, and nothing there may go asking for memory.
@<Data structures@>=
type board struct {
	n    int
	sym  [][]int // the square: |sym[i][j]| is the symbol in that cell
	cost [][]int // the price of every cell

	optCol  []int  // option number $\to$ the column of its cell
	optCost []int  // option number $\to$ the price of its cell
	kind    []int8 // item number $\to$ 0 unknown, 1 row, 2 column, 3 symbol
	itemCol []int  // number of a column item $\to$ which column it is

	rowAt   []int   // number of a row item $\to$ its slot in the matrix
	colSlot []int   // column number $\to$ its slot in the matrix, or $-1$
	rows    []int   // the row items still alive
	ncols   int     // how many columns are still alive
	a       [][]int // the cost matrix handed to the Hungarian algorithm
	hu      hwork   // the scratch arrays the Hungarian algorithm uses
}

@ Two constants. |noCell| means ``there is no such cell,'' so it is larger than
any real price, and |big| plays infinity inside the Hungarian algorithm, so it
is larger still.
@<Data structures@>=
const (
	noCell = 1 << 20 // in the cost matrix: this row and column are not joined
	big    = 1 << 30 // infinity, inside the Hungarian algorithm
)

@ The addition table of $\Bbb Z_n$ is built in one line. Prices are drawn
uniformly from 0 up to 1000. That they are not negative is a requirement of the
bound as much as a convenience---with negative prices in the mix, ``choosing
more cells might make it cheaper,'' and the assignment relaxation stops being a
lower bound at all.
@<Build the square and price it@>=
b := &board{n: n}
rng := rand.New(rand.NewSource(*seed))
b.sym = make([][]int, n)
b.cost = make([][]int, n)
for i := 0; i < n; i++ {
	b.sym[i] = make([]int, n)
	b.cost[i] = make([]int, n)
	for j := 0; j < n; j++ {
		b.sym[i][j] = (i + j) % n
		b.cost[i][j] = rng.Intn(1000)
	}
}
@<Allocate what the bound will need@>

@ There are $3n$ items and $n^2$ options, and both are numbered from~1, so the
arrays are one longer than you would think.
@<Allocate what the bound will need@>=
b.optCol = make([]int, n*n+1)
b.optCost = make([]int, n*n+1)
b.kind = make([]int8, 3*n+1)
b.itemCol = make([]int, 3*n+1)
b.rowAt = make([]int, 3*n+1)
b.colSlot = make([]int, n)
b.a = make([][]int, n)
for i := range b.a {
	b.a[i] = make([]int, n)
}
b.hu.u = make([]int, n+1)
b.hu.v = make([]int, n+1)
b.hu.p = make([]int, n+1)
b.hu.way = make([]int, n+1)
b.hu.minv = make([]int, n+1)
b.hu.used = make([]bool, n+1)

@* Casting it as an exact cover.
The input is {\tt DLX} text, verbatim. The first line lists the $3n$ item
names, all of them primary, so no `\.{\|}' appears. Below it comes one line per
cell, naming the row, the column, and the symbol that cell covers. Names are
built as `\.{r3}, \.{c5}, \.{s2}' so that later on the name alone will say
whether an item is a row, a column, or a symbol.
@<Make the cover problem and solve it@>=
var sb strings.Builder
for i := 0; i < n; i++ {
	fmt.Fprintf(&sb, "r%d ", i)
}
for j := 0; j < n; j++ {
	fmt.Fprintf(&sb, "c%d ", j)
}
for k := 0; k < n; k++ {
	fmt.Fprintf(&sb, "s%d ", k)
}
sb.WriteString("\n")
for i := 0; i < n; i++ {
	for j := 0; j < n; j++ {
		fmt.Fprintf(&sb, "r%d c%d s%d\n", i, j, b.sym[i][j])
	}
}
input := sb.String()

@ Now solve. |cells.Minimize| takes the price function, and |cells.Bound| is simply dropped
into a field---two lines in all. The covers that arrive keep getting cheaper,
so keeping only the last one leaves us holding the answer.
@<Make the cover problem and solve it@>=
xc := cells.NewXCC()
xc.Bound = b.bound
start := time.Now()
res := xc.Minimize(strings.NewReader(input), b.price)

var best []cells.Option
for sol := range res.Solutions {
	best = sol
}
took := time.Since(start)

@ The price function is called once per option, as soon as the input has been
read. While it is answering, it also fills in the table that turns an option
number back into a cell. The bound will consult that table at every node, so
this is a good moment to build it. The option number is the very handle
|cells.Bound| will see later.
@<Functions@>=
func (b *board) price(o int, opt cells.Option) int {
	i, j := cellOf(opt)
	b.optCol[o], b.optCost[o] = j, b.cost[i][j]
	return b.cost[i][j]
}

@ An option comes back as `\.{r3\ c5\ s2},' in the order it was written, so reading
the first two names tells us which cell it is.
@<Functions@>=
func cellOf(opt cells.Option) (i, j int) {
	fmt.Sscanf(opt[0], "r%d", &i)
	fmt.Sscanf(opt[1], "c%d", &j)
	return i, j
}

@* The slow strain: the Hungarian algorithm.
The assignment problem---put $n$ workers on $n$ jobs, one each, so that the
total wage is least---is a classic of combinatorial optimization. It is the
problem Kuhn's 1955 method solves, and, as related above, the name it goes by
is a receipt for the debt owed to K\H onig and Egerv\'ary.

What follows is the {\it potentials\/} formulation. Give every row a $u_i$ and
every column a $v_j$, keep $u_i+v_j\le a_{ij}$ at all times, and
$\sum u_i+\sum v_j$ stays below the cost of any assignment whatever. If the
cells where equality holds admit a perfect matching, that matching is optimal.
So the algorithm brings the rows in one at a time along shortest augmenting
paths, shifting the potentials as it goes to make equality hold in one more
place. That is $O(n^2)$ per row and $O(n^3)$ in all.

@ This algorithm is called from exactly one place, yet it stays a function. It
wants explaining in its own right, and the loops that walk an augmenting path
back are wound tightly enough that unrolling them into the caller would make
the whole thing harder to read, not easier. Its scratch arrays were allocated
by |board| up front.
@<Data structures@>=
type hwork struct {
	u, v, p, way, minv []int
	used               []bool
}

@ Here |a| is an $n\times n$ cost matrix and the value returned is the least
total of a perfect assignment. Inside, counting from~1 is more convenient, so
|p| and |u| and |v| are each one slot longer. |p[j]| is the row matched to
column~$j$, and 0 means the column is still empty.
@<Functions@>=
func (h *hwork) solve(a [][]int, n int) int {
	for j := 0; j <= n; j++ {
		h.u[j], h.v[j], h.p[j], h.way[j] = 0, 0, 0, 0
	}
	for i := 1; i <= n; i++ {
		@<Bring row |i| in along an augmenting path@>
	}
	@<Add up the matched entries@>
}

@ Row~$i$ arrives. |minv[j]| is the cost of the cheapest path yet found to the
untouched column~$j$, and |way[j]| records which column that path came through.
Reaching an empty column completes the augmenting path.
@<Bring row |i| in along an augmenting path@>=
h.p[0] = i
j0 := 0
for j := 0; j <= n; j++ {
	h.minv[j], h.used[j] = big, false
}
for {
	h.used[j0] = true
	@<Find the cheapest column |j1| and its slack |delta|@>
	@<Shift the potentials by |delta|@>
	j0 = j1
	if h.p[j0] == 0 {
		break
	}
}
@<Walk the path back and reassign@>

@ From row |i0|, the one matched to the column we just touched, look over every
column not yet touched, revising |minv| and picking the cheapest of them.
@<Find the cheapest column |j1| and its slack |delta|@>=
i0, delta, j1 := h.p[j0], big, 0
for j := 1; j <= n; j++ {
	if h.used[j] {
		continue
	}
	if cur := a[i0-1][j-1] - h.u[i0] - h.v[j]; cur < h.minv[j] {
		h.minv[j], h.way[j] = cur, j0
	}
	if h.minv[j] < delta {
		delta, j1 = h.minv[j], j
	}
}

@ Shifting the potentials by |delta| makes equality hold at the column just
chosen, while every equality already established is preserved. The untouched
columns see their |minv| fall by the same amount.
@<Shift the potentials by |delta|@>=
for j := 0; j <= n; j++ {
	if h.used[j] {
		h.u[h.p[j]] += delta
		h.v[j] -= delta
	} else {
		h.minv[j] -= delta
	}
}

@ Walking the augmenting path backwards along |way|, push each match over by
one. Column 0 is both the starting point and the marker, so arriving there
means we are done.
@<Walk the path back and reassign@>=
for {
	j1 := h.way[j0]
	h.p[j0] = h.p[j1]
	j0 = j1
	if j0 == 0 {
		break
	}
}

@ @<Add up the matched entries@>=
total := 0
for j := 1; j <= n; j++ {
	total += a[h.p[j]-1][j-1]
}
return total

@* Where the two strains meet.
Now to tie all of it into the shape |cells.Bound| wants. This is the spot where the
two algorithms take each other's hands. A |cells.Frame| is a peephole into one search
node, and |f.Live| runs over every surviving (primary item, option) pair. It
hands out one item's options together, which suits anybody thinking in rows.

The number of surviving rows and the number of surviving columns are always
equal, since choosing one option covers one row and one column together. If
that number is zero we have already arrived, and nothing more remains to be
paid.
@<Functions@>=
func (b *board) bound(f cells.Frame) int {
	@<Collect the surviving rows and columns@>
	m := len(b.rows)
	if m == 0 || b.ncols != m {
		return 0
	}
	@<Fill the cost matrix from the surviving cells@>
	if v := b.hu.solve(b.a, m); v < noCell {
		return v
	}
	return noCell // this branch cannot be finished at all
}

@ The first sweep assigns slots. A surviving row gets a row slot in the matrix,
a surviving column a column slot. |Live| hands out one item's pairs
consecutively, so it is enough to skip whatever equals the item just seen.
@<Collect the surviving rows and columns@>=
b.rows, b.ncols = b.rows[:0], 0
for c := range b.colSlot {
	b.colSlot[c] = -1
}
last := -1
for item := range f.Live {
	if item == last {
		continue
	}
	last = item
	@<Learn what this item is, once and for all@>
	switch b.kind[item] {
	case 1:
		b.rowAt[item] = len(b.rows)
		b.rows = append(b.rows, item)
	case 2:
		b.colSlot[b.itemCol[item]] = b.ncols
		b.ncols++
	}
}

@ Item numbers never change during the search, so a name need be taken apart
only once. Symbol items are marked 3 and never looked at again. Relaxing is
precisely the act of forgetting the symbols, and the absence of that |case| is
the point of this whole program.
@<Learn what this item is, once and for all@>=
if b.kind[item] == 0 {
	name := f.Name(item)
	var k int
	switch name[0] {
	case 'r':
		b.kind[item] = 1
	case 'c':
		fmt.Sscanf(name, "c%d", &k)
		b.kind[item], b.itemCol[item] = 2, k
	default:
		b.kind[item] = 3
	}
}

@ The second sweep fills the matrix. Every option still left to a row item is a
surviving cell, so its price goes into the corresponding slot. A row and a
column meet in exactly one cell, so nothing is ever overwritten. What is left
holds |noCell|, which makes the answer exceed |noCell| if such a pairing has to
be chosen.
@<Fill the cost matrix from the surviving cells@>=
for i := 0; i < m; i++ {
	for j := 0; j < m; j++ {
		b.a[i][j] = noCell
	}
}
for item, opt := range f.Live {
	if b.kind[item] != 1 {
		continue
	}
	if j := b.colSlot[b.optCol[opt]]; j >= 0 {
		b.a[b.rowAt[item]][j] = b.optCost[opt]
	}
}

@* Showing the answer.
$\Bbb Z_n$ has no transversal whatever when $n$ is even, so coming away
empty-handed is not at all unusual.
@<Show the answer and the effort@>=
if best == nil {
	fmt.Printf("a square of order %d has no transversal (%d nodes, %v)\n",
		n, xc.Nodes(), took.Round(time.Millisecond))
	return
}
pick := make([]int, n) // the column chosen in each row
for _, opt := range best {
	i, j := cellOf(opt)
	pick[i] = j
}
@<Print the square with the chosen cells marked@>
@<Print the total and the effort@>
@<Solve once more without the bound, for comparison@>

@ Every cell is written as \.{symbol:price}, and the chosen ones are bracketed.
A large square runs off the screen, so we draw it only up to order twelve.
@<Print the square with the chosen cells marked@>=
if n <= 12 {
	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			cell := fmt.Sprintf("%d:%d", b.sym[i][j], b.cost[i][j])
			if pick[i] == j {
				fmt.Printf(" [%5s]", cell)
			} else {
				fmt.Printf("  %5s ", cell)
			}
		}
		fmt.Println()
	}
	fmt.Println()
}

@ @<Print the total and the effort@>=
sum := 0
for i := 0; i < n; i++ {
	sum += b.cost[i][pick[i]]
}
fmt.Printf("cheapest transversal costs %d, %d nodes, %v\n",
	sum, xc.Nodes(), took.Round(time.Millisecond))

@ To compare, solve once more with the bound removed. The answer is of course
the same and only the node count differs. |price| gets called again and refills
the tables, but with the same values, so no harm is done.
@<Solve once more without the bound, for comparison@>=
if *plain {
	bare := cells.NewXCC()
	t0 := time.Now()
	r2 := bare.Minimize(strings.NewReader(input), b.price)
	for range r2.Solutions {}
	fmt.Printf("without a bound: %d nodes, %v\n",
		bare.Nodes(), time.Since(t0).Round(time.Millisecond))
}

@* Did it get faster?
Odd orders, measured with seed~1. On the left is |cells.Minimize| with the bound
taken off, on the right the Hungarian Dance technique; nodes are search nodes.
$$\vbox{\halign{\hfil$#$\quad&\hfil#\quad&\hfil#\quad&\hfil#\quad&\hfil#\quad
&\hfil#\cr
\noalign{\hrule\smallskip}
n&\hbox{no bound}&&\hbox{with a bound}&&\hbox{ratio}\cr
\noalign{\smallskip\hrule\smallskip}
13&155{,}095&41{\rm ms}&979&4{\rm ms}&158\cr
15&1{,}681{,}693&257{\rm ms}&6{,}881&27{\rm ms}&244\cr
17&8{,}571{,}751&1.35{\rm s}&16{,}842&75{\rm ms}&509\cr
19&117{,}455{,}633&19.5{\rm s}&82{,}212&496{\rm ms}&1429\cr
21&\hbox{---}&\hbox{$>$1 min}&268{,}418&1.97{\rm s}&\hbox{---}\cr
\noalign{\smallskip\hrule}
}}$$
That the ratio grows with the order is the point. Computing the bound is not
cheap---about 6 microseconds a node, thirty-six times the 0.17 microseconds of
an unbounded one---but with fourteen hundred times fewer nodes it still comes out
some forty times faster at $n=19$. The wall moves from around nineteen to
around twenty-seven: with the bound, $n=27$ finishes in two minutes, and
$n=29$ does not finish in four.

@ So, put honestly: on small boards it is {\it slower}. Below about eleven the
search is over in a blink without any bound at all, and laying $O(m^3)$ on
every node is a loss.
The slow strain earns its keep only when the piece runs long. This program
leaves the bound on always because that is what the essay is about, not because
it is always right; in earnest, one would switch it off on small boards.

@ At even orders the bound does {\it nothing at all}. The node counts agree to
the last digit. Knowing why, one sees it had to be so. $\Bbb Z_n$ has no
transversal when $n$ is even, so no solution ever turns up, so the incumbent
stays at infinity forever. Nothing exceeds infinity, and the pruning test
|cost+rest >= incumbent| is therefore never once true. Branch and {\it bound\/}
does its work only after it has something to beat.

The one thing a bound could still do here is report that the relaxation itself
has no solution---which is why the |noCell| path exists---but the assignment
relaxation is so loose that at even orders of $\Bbb Z_n$ it almost always does
have one. A worthless problem gets a worthless bound.

@* Where else to dance it.
The floors this works on can be described in a single sentence.
$$\vbox{\hsize=0.86\hsize\noindent\it Split the primary items into two groups.
If every option covers exactly one item from each group, then the assignment
problem between those two groups is a relaxation.}$$
Every other item may be forgotten. The more you forget the weaker the bound
gets, but it stays a {\it valid\/} bound, and the Hungarian algorithm solves
that relaxation exactly. A surprising number of problems have this shape.

@ Before listing them, though, it is better to know this toy's ceiling. The
minimum-cost transversal is far too easy to write as an integer program. Give
every cell a 0--1 variable and say ``sums to one'' for every row, every column
and every symbol, and that is the whole model---and written that way, its LP
relaxation is nearly tight. For fun I fed the same square and the same prices
to a general integer programming solver: it finished $n=27$ in a second or so,
and hardly branched at all. That is exactly where this program spends two
minutes.

The reason is the quality of the relaxation, and that is the thing worth
carrying away. We throw an entire axis {\it away}. Measured with the symbols
forgotten, the value sits some forty percent below the optimum. The LP
relaxation keeps all three groups and drops only integrality, so it falls short
by less than ten. That the Hungarian algorithm solves our relaxation {\it
exactly\/} and that our relaxation is {\it good\/} turn out to be two different
statements. Earlier I called the bound strong; I was measuring it against a
version of itself whose bound was zero.

@ So the question of where to use this is better asked the other way round:
{\it where does the LP go slack once the problem is written as an integer
program?} Problems where colors or multiplicities make writing that program a
nuisance in the first place; problems that want every solution enumerated
rather than the cheapest one; and problems where the answer is held not by a
relaxation but by the geometry. The last of those is what
\.{examples/hollow} does. The bound there is no exact relaxation at all---it
merely notices what the shape of the board has already settled---and it turns a
computation that would not finish into two seconds.

@ A handful of problems with this shape, all the same. Ask the question above
of any of them first.
\smallskip
{\parindent=2em
\item{1.} {\it Minimum-cost $n$-queens.} A queen uses one row and one column;
forget the diagonals. The test in \.{ssxcc.w} already has this shape, and
swapping its homely bound for a Hungarian one would sharpen it at once.
\item{2.} {\it Minimum-cost 3-dimensional matching.} What this program solves
is the special case; keep any two axes of the general one and the assignment
problem is there. One may even take all three choices of two, and use the
largest of the three bounds. This is also where the ceiling above bites
hardest: all three together are still worth less than the one LP relaxation.
\item{3.} {\it Timetabling.} An option uses one teacher and one period; forget
the rooms and the classes. School timetables and exam invigilation have the
same shape.
\item{4.} {\it Crew scheduling as set partitioning.} This is the framework the
airlines actually use, and bounding it by an assignment relaxation is a stock
move in that trade. Here an option takes several items at once, so choosing the
two groups well takes some judgment. Worth noting too that the trade is bound
tightly to column generation and the LP: there is something to learn there, but
nothing to win.
\item{5.} {\it Latin square completion.} Filling in a partly completed board as
cheaply as possible. The item structure is the same as the transversal
problem's.\par}

@ Since this was written, the same bound hook has been fitted to the MCC
engine too. Binary branching made the place to hang it delicate. Giving up on
a branch has to happen where the force stack is empty; otherwise the next node
finds the leftover entries and adopts them as its own forced moves---and under
binary branching a forced move is not a branch at all, but the inclusion of
one option with the alternatives never tried. The answers still look
plausible; they merely stop being the cheapest. It took a few thousand random
problems checked against full enumeration to catch it.

|cells.Frame| became common property in the bargain, and |f.Need(item)| now says how
many more times an item must at least be covered---always~1 under XCC, but
possibly several under MCC. That is what opens the way to pricing a problem
naturally written with multiplicities, the partridge puzzle for one. That road
was actually taken in \.{examples/hollow}, where in place of an exact relaxation
like the Hungarian one the bound merely notices what the geometry has already
decided.

@ And this, that choosing the bound is where the skill lies. How you split the
two groups decides how strong the bound is; one may measure several splittings
and take the best, or take the largest of several bounds at once. Choosing a
relaxation is, in the end, not so different from choosing a tune.

What this essay leaves behind, then, is not a fast program but an arrangement.
As Brahms set someone else's tunes in a frame of his own, so here two
algorithms that already existed are set in one frame; how well the frame sings
depends on the tune laid over it. Over Latin squares it did not sing
especially well. The floor where it earns its keep is somewhere else.

\vfill
\centerline{\it I am listening to Brahms's Hungarian Dance No.\thinspace5 as I write this.}

@* Index.
