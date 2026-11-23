\input amssym
\input luamplib.sty

\def\title{Every rth Element}

@s Builder int
@s Reader int

@* Introduction.
A {\it twelve-tone row\/} is a permutation of the twelve pitch classes, and
Schoenberg's students built whole compositions out of one. Exercise 103 of
\S7.2.2.1 asks for the rows whose eleven adjacent intervals
$(x_k-x_{k-1})\bmod n$ are all different---the {\it all-interval\/} rows---and
exercise 104 goes after a rarer breed still.
@^Schoenberg, Arnold@>
@^Knuth, Donald Ervin@>

\smallskip
{\narrower\noindent
{\bf 104.} [{\it M28\/}]\enspace Assume that $n+1=p$ is prime. Given an $n$-tone
row $x=x_0x_1\ldots x_{n-1}$, define $y_k=x_{(k-1)\bmod p}$, and let
$x^{(r)}=y_ry_{2r}\ldots y_{nr}$ be the $n$-tone row consisting of ``every $r$th
element of $x$'' (where $x_n$ is considered to be blank). For example, when
$n=12$, every 5th element of $x$ is the sequence
$x^{(5)}=x_4x_9x_1x_6x_{11}x_3x_8x_0x_5x_{10}x_2x_7$.
\smallskip\noindent
An $n$-tone row is called {\it perfect\/} if it is equivalent to $x^{(r)}$ for
$1\le r\le n$. For example, the amazing 12-tone row $0\,1\,4\,2\,9\,5\,11\,3\,8\,
10\,7\,6$ is perfect.
\smallskip
{\parindent=20pt
\item{a)} Prove that a perfect $n$-tone row has the all-interval property.
\item{b)} Prove that a perfect $n$-tone row also satisfies $x\equiv x^R$.
\par}
\par}
\smallskip

Two rows are {\it equivalent\/} when they differ by a transposition, that is,
when $x'_k=(x_k+d)\bmod n$ for some fixed $d$; and $x^R$ is the reversal
$x_{n-1}\ldots x_1x_0$. I have quoted the statement as amended on 15~September
2025; the first printing said ``whenever $k$ is not a multiple of~$p$'' in place
of the parenthesis about $x_n$.

@ Here is the amazing row itself, read as a path on the twelve pitch classes.
It starts at $0$ and finishes at $6$, which answer 103(a) says every
all-interval row must do; the eleven steps between are eleven different
intervals, which is what part~(a) of this exercise asks one to prove.

$$\mplibcode input allinterval; \endmplibcode$$

@ I wrote this program in September 2026 to check the exercise and its answer.
Everything in both turned out to be right, so what follows is corroboration
rather than correction: the printed sequence $x^{(5)}$ is right index for index,
the amazing row really is perfect, and both parts of the answer hold for every
row that a machine can reach.

The answer to part~(a) does more than it advertises. Its argument shows that a
perfect row {\it is\/} a table of discrete logarithms---that $x_{k-1}$ is the
index of $k$ with respect to some primitive root $R$ modulo $p$---and the
converse is easy, so the perfect rows are exactly those tables. There are
$\varphi(n)$ of them for each $n$, one per primitive root, and the amazing row
of the exercise is the one belonging to the smallest primitive root of~13.

These notes are the companion document \.{README.md} in the directory above.

@ The program has four things to say, and a flag chooses which.
@c
package main

import (
	"flag"
	"fmt"
	"log"
	"strings"

	cells "github.com/sjnam/dancing-cells"
)

@<Functions@>

func main() {
	@<Read the command line@>
	switch *mode {
	case "example":
		@<Check what the exercise prints@>
	case "perfect":
		@<Exhibit the perfect rows@>
	case "all":
		@<Search every row exhaustively@>
	case "xcc":
		@<Count all-interval rows with dancing cells@>
	default:
		log.Fatalf("unknown mode %q", *mode)
	}
}

@ Twelve is the interesting size and the only one the exercise names, but
nothing here is special to it, so the sizes to try are a flag too.
@<Read the command line@>=
mode := flag.String("mode", "example", "example, perfect, all, or xcc")
upto := flag.Int("upto", 12, "largest n to try")
flag.Parse()

@* Rows and their transformations.
A row is a slice of the integers $0$ through $n-1$, in some order. Everything
the exercise defines is a few lines apiece, but they are used from several
places, so they are functions.

The first is the subject of the exercise. Every index arrives as $jr$ for some
$1\le j\le n$, and $y_k$ is $x_{(k-1)\bmod p}$, so the $j$th element of
$x^{(r)}$ is $x_{(jr-1)\bmod p}$. Since $p$ is prime and neither $j$ nor $r$ is
a multiple of it, $jr$ never is either---which is exactly why the exercise
assumes $p$ prime, and why $x_n$ is never wanted.
@<Functions@>=
func sub(x []int, r int) []int {
	n := len(x)
	p := n + 1
	out := make([]int, n)
	for j := 1; j <= n; j++ {
		out[j-1] = x[(j*r-1)%p]
	}
	return out
}

@ Equivalence is transposition, so two rows are equivalent when the difference
of their first elements already accounts for all the rest.
@<Functions@>=
func equiv(a, b []int) bool {
	n := len(a)
	d := ((b[0] - a[0]) % n + n) % n
	for i := range a {
		if (a[i]+d)%n != b[i] {
			return false
		}
	}
	return true
}

func reversed(x []int) []int {
	n := len(x)
	out := make([]int, n)
	for i := range x {
		out[i] = x[n-1-i]
	}
	return out
}

@ A row is perfect when every $x^{(r)}$ is equivalent to it, and it has the
all-interval property when its $n-1$ adjacent differences are all different.
Since a row is a permutation no difference can be zero, so being different is
the whole of it.
@<Functions@>=
func perfect(x []int) bool {
	for r := 1; r <= len(x); r++ {
		if !equiv(x, sub(x, r)) {
			return false
		}
	}
	return true
}

func allInterval(x []int) bool {
	n := len(x)
	seen := make([]bool, n)
	for k := 1; k < n; k++ {
		d := ((x[k]-x[k-1])%n + n) % n
		if d == 0 || seen[d] {
			return false
		}
		seen[d] = true
	}
	return true
}

@ Three scraps of number theory. The multiplicative order of $r$ modulo $p$ is
what tells a primitive root from an impostor, and Euler's $\varphi$ is the count
that the perfect rows will turn out to match.
@<Functions@>=
func isPrime(m int) bool {
	if m < 2 {
		return false
	}
	for d := 2; d*d <= m; d++ {
		if m%d == 0 {
			return false
		}
	}
	return true
}

func gcd(a, b int) int {
	for b != 0 {
		a, b = b, a%b
	}
	return a
}

func totient(n int) int {
	c := 0
	for k := 1; k <= n; k++ {
		if gcd(k, n) == 1 {
			c++
		}
	}
	return c
}

func order(r, p int) int {
	e, w := 1, r%p
	for w != 1 {
		w, e = w*r%p, e+1
	}
	return e
}

@ Here is the row that the answer to part~(a) secretly describes. Walking the
powers of $R$ and recording where each residue turns up gives the table of
indices $x_{k-1}=\mathop{\rm ind}\nolimits_R k$; if $R$ is not a primitive root
the walk closes early and there is no row to report.
@<Functions@>=
func dlogRow(R, p int) []int {
	n := p - 1
	if order(R, p) != n {
		return nil
	}
	x := make([]int, n)
	v := 1
	for e := 0; e < n; e++ {
		x[v-1] = e
		v = v * R % p
	}
	return x
}

@ Finally, a way to walk every row with $x_0=0$---one representative of each
equivalence class, since a transposition is settled by its first element. There
are $(n-1)!$ of them, which is 39,916,800 when $n=12$: large, but not too large
to visit one at a time.
@<Functions@>=
func rows(n int, visit func([]int)) {
	x := make([]int, n)
	used := make([]bool, n)
	used[0] = true
	var rec func(int)
	rec = func(i int) {
		if i == n {
			visit(x)
			return
		}
		for v := 1; v < n; v++ {
			if !used[v] {
				used[v], x[i] = true, v
				rec(i + 1)
				used[v] = false
			}
		}
	}
	rec(1)
}

@* What the exercise prints.
The statement makes two concrete claims, and both can be checked on sight. The
first is the sequence of indices for $n=12$ and $r=5$.
@<Check what the exercise prints@>=
fmt.Println("the exercise says that every 5th element of a 12-tone row is")
fmt.Println("   x4 x9 x1 x6 x11 x3 x8 x0 x5 x10 x2 x7")
want := []int{4, 9, 1, 6, 11, 3, 8, 0, 5, 10, 2, 7}
got := make([]int, 12)
for j := 1; j <= 12; j++ {
	got[j-1] = (j*5 - 1) % 13
}
fmt.Printf("the definition gives %v\n", got)
fmt.Printf("agrees: %v\n\n", equiv2(want, got))

@ The second claim is that one particular row is perfect. It is, and it is more
than that: it is the table of indices for $R=2$, the smallest primitive root
of~13.
@<Check what the exercise prints@>=
amazing := []int{0, 1, 4, 2, 9, 5, 11, 3, 8, 10, 7, 6}
fmt.Printf("the amazing row %v\n", amazing)
fmt.Printf("   is perfect:            %v\n", perfect(amazing))
fmt.Printf("   has all intervals:     %v\n", allInterval(amazing))
fmt.Printf("   is equivalent to x^R:  %v\n", equiv(amazing, reversed(amazing)))
fmt.Printf("   is the index table of R=2: %v\n",
	equiv2(amazing, dlogRow(2, 13)))

@ Comparing two slices for plain equality, rather than for equivalence, is
wanted twice above and once again later, so it is a function of its own.
@<Functions@>=
func equiv2(a, b []int) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

@ Part~(b) of the answer is a single equation, $x^{(n)}=x^R$, and it deserves a
word because it is stronger than the exercise needs. Since $n\equiv-1$ modulo
$p$ we have $(jn-1)\bmod p=n-j$, so the $j$th element of $x^{(n)}$ is $x_{n-j}$:
the reversal exactly, not merely something equivalent to it. It holds for
{\it every\/} row, perfect or not, and a perfect row is equivalent to $x^{(n)}$
by definition, which finishes part~(b).
@<Check what the exercise prints@>=
fmt.Println()
bad := 0
for n := 2; n <= 12; n++ {
	if !isPrime(n + 1) {
		continue
	}
	rows(n, func(x []int) {
		if !equiv2(sub(x, n), reversed(x)) {
			bad++
		}
	})
	fmt.Printf("n=%2d: x^(n) = x^R for every row, exceptions so far: %d\n", n, bad)
}

@* Perfect rows are tables of logarithms.
The answer to part~(a) assumes $x$ perfect, picks a primitive root $r$, and
finds a constant $c_r$ with $y_{kr}\equiv x_{k-1}+c_r$. Iterating gives
$x_{(r^k-1)\bmod p}\equiv kc_r$, and then it sets $R=r^d$ where $c_rd\bmod n=1$
to conclude that $R^{x_{k-1}}\equiv k$.

That last move needs $d$ to exist, which needs $c_r$ to be invertible modulo
$n$---and the answer does not stop to say so. It is true, and the reason is the
sentence just before it: because $r$ is primitive, $(r^k-1)\bmod p$ runs through
all of $0,\ldots,n-1$ as $k$ runs through $1,\ldots,n$, so the values $kc_r$
must run through all of $\Bbb Z_n$, which forces $\gcd(c_r,n)=1$. The
restriction to primitive $r$ is doing real work here, and this mode shows it: for
every other $r$ the greatest common divisor exceeds~1 and no $d$ exists.
@<Exhibit the perfect rows@>=
for n := 1; n <= *upto; n++ {
	p := n + 1
	if !isPrime(p) {
		continue
	}
	fmt.Printf("n=%2d  p=%2d  phi(n)=%d\n", n, p, totient(n))
	@<Print the index table of each primitive root@>
}
@<Show that a nonprimitive r leaves no room for d@>

@ @<Print the index table of each primitive root@>=
for R := 1; R < p; R++ {
	x := dlogRow(R, p)
	if x == nil {
		continue
	}
	fmt.Printf("   R=%2d  x = %v  perfect=%v all-interval=%v x~xR=%v\n",
		R, x, perfect(x), allInterval(x), equiv(x, reversed(x)))
}

@ The table below is for the amazing row, but any perfect row tells the same
story: the constant $c_r$ is the index of $r$, so it is invertible modulo $n$
exactly when $r$ is itself a primitive root.
@<Show that a nonprimitive r leaves no room for d@>=
x := dlogRow(2, 13)
fmt.Printf("\nfor the row %v (n=12, p=13):\n", x)
fmt.Printf("%4s %6s %6s %6s %s\n", "r", "ord(r)", "c_r", "gcd", "")
for r := 1; r <= 12; r++ {
	c := (sub(x, r)[0] - x[0] + 12) % 12
	note := ""
	if gcd(c, 12) == 1 {
		note = "d exists"
	}
	fmt.Printf("%4d %6d %6d %6d %s\n", r, order(r, 13), c, gcd(c, 12), note)
}

@* Exhaustive verification.
Nothing above proves anything; it only checks the cases the exercise names. This
mode does the real work, visiting every row with $x_0=0$ and asking four
questions of each: is it perfect, and if so does it have the all-interval
property that part~(a) promises, is it equivalent to its reversal as part~(b)
promises, and is it one of the $\varphi(n)$ tables of logarithms.
@<Search every row exhaustively@>=
fmt.Printf("%3s %3s %12s %8s %8s %6s %7s %6s\n",
	"n", "p", "rows", "perfect", "all-int", "x~xR", "phi(n)", "=dlog")
for n := 1; n <= *upto; n++ {
	p := n + 1
	if !isPrime(p) {
		continue
	}
	@<Count the perfect rows among all $(n-1)!$ of them@>
	@<Report what the perfect rows satisfy@>
}

@ @<Count the perfect rows among all $(n-1)!$ of them@>=
var perf [][]int
total := 0
rows(n, func(x []int) {
	total++
	if perfect(x) {
		perf = append(perf, append([]int(nil), x...))
	}
})

@ The tables of logarithms are collected into a set, and the perfect rows are
looked up in it; the two agree when the counts match and every lookup succeeds.
@<Report what the perfect rows satisfy@>=
logs := map[string]bool{}
for R := 1; R < p; R++ {
	if x := dlogRow(R, p); x != nil {
		logs[fmt.Sprint(x)] = true
	}
}
ai, rev, same := 0, 0, len(logs) == len(perf)
for _, x := range perf {
	if allInterval(x) {
		ai++
	}
	if equiv(x, reversed(x)) {
		rev++
	}
	if !logs[fmt.Sprint(x)] {
		same = false
	}
}
fmt.Printf("%3d %3d %12d %8d %8d %6d %7d %6v\n",
	n, p, total, len(perf), ai, rev, totient(n), same)

@* All-interval rows, by dancing cells.
Exercise 103 asks for the all-interval rows themselves, and its answer gives an
{\tt XCC} formulation to hand to Algorithm~C. It is worth building here for two
reasons: it puts a published count next to a run of our own solver, and every
perfect row must appear among the solutions if part~(a) is right.

The items are a position $j$ and a pitch $p_t$ for $0\le j,t<n$, an interval
value $d_k$ and an interval slot $q_t$ for $1\le k,t<n$, all primary; and a
secondary item $x_j$ per position, whose color is the pitch that lands there.
@<Count all-interval rows with dancing cells@>=
fmt.Printf("%3s %8s %9s %11s %10s   %s\n",
	"n", "items", "options", "solutions", "nodes", "answer 103(b)")
knuth := map[int]int{2: 1, 4: 2, 6: 4, 8: 24, 10: 288, 12: 3856}
for n := 2; n <= *upto; n += 2 {
	@<Write the {\tt XCC} problem for all-interval rows@>
	@<Solve it and compare with the published count@>
}

@ One option per position and pitch says ``pitch $t$ goes in position $j$''.
Answer 103(a) shows that an all-interval row must have $x_{n-1}=(x_0+n/2)\bmod
n$, so with $x_0$ pinned to zero the last pitch is forced; both facts are
imposed by leaving options out.
@<Write the {\tt XCC} problem for all-interval rows@>=
var b strings.Builder
for j := 0; j < n; j++ {
	fmt.Fprintf(&b, "j%d ", j)
}
for t := 0; t < n; t++ {
	fmt.Fprintf(&b, "p%d ", t)
}
for k := 1; k < n; k++ {
	fmt.Fprintf(&b, "d%d ", k)
}
for t := 1; t < n; t++ {
	fmt.Fprintf(&b, "q%d ", t)
}
b.WriteString("|")
for j := 0; j < n; j++ {
	fmt.Fprintf(&b, " x%d", j)
}
b.WriteString("\n")

@ @<Write the {\tt XCC} problem for all-interval rows@>=
for j := 0; j < n; j++ {
	for t := 0; t < n; t++ {
		if (j == 0 && t != 0) || (j == n-1 && t != n/2) {
			continue
		}
		fmt.Fprintf(&b, "j%d p%d x%d:%d\n", j, t, j, t)
	}
}

@ The other options say ``interval $k$ sits in slot $t$'', and they carry the
arithmetic in their colors: the pitch at position $t-1$ is $i$ and the pitch at
position $t$ is $i+k$. Two options that disagree about a position cannot both be
chosen, because a secondary item admits only one color, and that single
mechanism is what makes the row and its intervals permutations at the same time.
@<Write the {\tt XCC} problem for all-interval rows@>=
for k := 1; k < n; k++ {
	for t := 1; t < n; t++ {
		for i := 0; i < n; i++ {
			fmt.Fprintf(&b, "d%d q%d x%d:%d x%d:%d\n",
				k, t, t-1, i, t, (i+k)%n)
		}
	}
}

@ @<Solve it and compare with the published count@>=
in := b.String()
xc := cells.NewXCC()
res := xc.Dance(strings.NewReader(in))
count := 0
for range res.Solutions {
	count++
}
fmt.Printf("%3d %8d %9d %11d %10d   %d %s\n",
	n, 5*n-2, strings.Count(in, "\n")-1, count, xc.Nodes(),
	knuth[n], map[bool]string{true: "agrees", false: "DISAGREES"}[count == knuth[n]])

@* Index.
