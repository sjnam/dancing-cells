\input luamplib.sty

\datethis
\def\title{Polycube symmetry types}

@* Introduction.
Exercise 7.2.2.1--387 asks how many symmetry types a polycube can have, and for
an example of each one ``using the minimum number of cubies.'' Reflections are
not allowed---a left twist is not a right twist---so the group in play is the
24 rotations of a cube rather than all 48 of its symmetries.

Answer 387 works it out: the 24 rotations are the signed permutations of
$\{\pm1,\pm2,\pm3\}$ whose inversions and complementations together number an
even amount; that group has 30 subgroups; the subgroups fall into 11 conjugacy
classes; and those eleven classes are the symmetry types. It names them {\it
full}, {\it even}, {\it 8-fold}, {\it 6-fold}, {\it 90$^\circ$}, {\it
bidiagonal}, {\it tricentral}, {\it 120$^\circ$}, {\it diagonal}, {\it axial},
{\it none}, and draws a polycube for each.

This program checks all of that, and then works out the minimum size of each
type---which the answer states in words for only one of the eleven. Two of the
eleven pictures turn out to be bigger than they need to be, and the one below
is the clearer of the two.
$$\mplibcode input polycubes; \endmplibcode$$

@c
package main

import (
	"flag"
	"fmt"
	"sort"
	"strings"
)

@<Types@>
@<Functions@>

func main() {
	@<Read the command line@>
	@<Set up the two groups@>
	@<Do what the mode asks@>
}

@ @<Read the command line@>=
mode := flag.String("mode", "all", "group, types, grow, min, printed, or all")
top := flag.Int("top", 8, "largest polycube to grow")
lim := flag.Int("lim", 24, "largest polycube the orbit search will look for")
flag.Parse()

@ @<Do what the mode asks@>=
if *mode == "group" || *mode == "all" {
	@<Check the 24 rotations@>
}
if *mode == "types" || *mode == "all" {
	@<Count the subgroups and the symmetry types@>
	@<Check what the answer says about particular types@>
}
if *mode == "grow" || *mode == "all" {
	@<Grow every polycube and watch for new types@>
}
if *mode == "min" || *mode == "all" {
	@<Find the smallest polycube of each type@>
}
if *mode == "printed" || *mode == "all" {
	@<Weigh the pictures in answer 387@>
}

@* The rotations of a cube.
A signed permutation of the three coordinates is a matrix with one nonzero
entry in each row and column, that entry being $\pm1$; there are 48 of them,
and the 24 with determinant $+1$ are the rotations. Answer 387 describes the
same 24 differently---``the number of inversions of the permutation plus the
number of complementations is even''---so the first thing to check is that the
two descriptions pick out the same matrices.

@<Types@>=
type mat [3][3]int
type vec struct{ x, y, z int }

@ @<Functions@>=
func mul(a, b mat) mat {
	var c mat
	for i := range 3 {
		for j := range 3 {
			for k := range 3 {
				c[i][j] += a[i][k] * b[k][j]
			}
		}
	}
	return c
}

func inv(a mat) mat { // these matrices are orthogonal, so this is the transpose
	var c mat
	for i := range 3 {
		for j := range 3 {
			c[i][j] = a[j][i]
		}
	}
	return c
}

func act(a mat, v vec) vec {
	c := [3]int{v.x, v.y, v.z}
	var r [3]int
	for i := range 3 {
		r[i] = a[i][0]*c[0] + a[i][1]*c[1] + a[i][2]*c[2]
	}
	return vec{r[0], r[1], r[2]}
}

func det(a mat) int {
	return a[0][0]*(a[1][1]*a[2][2]-a[1][2]*a[2][1]) -
		a[0][1]*(a[1][0]*a[2][2]-a[1][2]*a[2][0]) +
		a[0][2]*(a[1][0]*a[2][1]-a[1][1]*a[2][0])
}

@ The 48 come out of the six permutations and the eight sign patterns. I keep
the permutation and the signs alongside each matrix, because the answer's
description is stated in terms of them.

@<Functions@>=
func signed() (ms []mat, perms [][3]int, signs [][3]int) {
	for _, p := range [][3]int{{0, 1, 2}, {0, 2, 1}, {1, 0, 2},
		{1, 2, 0}, {2, 0, 1}, {2, 1, 0}} {
		for b := range 8 {
			var m mat
			var s [3]int
			for i := range 3 {
				s[i] = 1 - 2*((b>>i)&1)
				m[i][p[i]] = s[i]
			}
			ms = append(ms, m)
			perms = append(perms, p)
			signs = append(signs, s)
		}
	}
	return
}

@ @<Set up the two groups@>=
ms, perms, signs := signed()
var rot []mat
for _, m := range ms {
	if det(m) == 1 {
		rot = append(rot, m)
	}
}

@ @<Check the 24 rotations@>=
fmt.Println("the 24 rotations")
byDet := map[mat]bool{}
for _, m := range rot {
	byDet[m] = true
}
byRule := map[mat]bool{}
for i, m := range ms {
	@<Count inversions and complementations of symmetry |i|@>
	if (invs+comps)%2 == 0 {
		byRule[m] = true
	}
}
same := len(byDet) == len(byRule)
for m := range byDet {
	if !byRule[m] {
		same = false
	}
}
fmt.Printf("  %d signed permutations, %d with determinant +1, %d with"+
	" inversions+complementations even; the two agree: %v\n",
	len(ms), len(byDet), len(byRule), same)
@<Check the rotation the answer works out@>

@ @<Count inversions and complementations of symmetry |i|@>=
p, s := perms[i], signs[i]
invs, comps := 0, 0
for a := range 3 {
	if s[a] < 0 {
		comps++
	}
	for b := a + 1; b < 3; b++ {
		if p[a] > p[b] {
			invs++
		}
	}
}

@ The answer picks one symmetry out for an example: $\bar132$ takes
$(x,y,z)\mapsto(c-x,z,y)$, a rotation of $180^\circ$ about the line $x=c/2$,
$y=z$; it is a symmetry of the bent tricube $\{000,001,010\}$ when $c=0$, and
of the L-twist $\{000,001,100,110\}$ when $c=1$. Four claims, all easy to try.

@<Check the rotation the answer works out@>=
bar132 := mat{{-1, 0, 0}, {0, 0, 1}, {0, 1, 0}}
tr := 0
for i := range 3 {
	tr += bar132[i][i]
}
var ax vec
for _, v := range []vec{{0, 1, 1}, {1, 0, 0}, {0, 1, -1}} {
	if act(bar132, v) == v {
		ax = v
	}
}
fmt.Printf("  the answer's example: determinant %d, trace %d (so a half turn),"+
	" axis (%d,%d,%d)\n", det(bar132), tr, ax.x, ax.y, ax.z)
bent := []vec{{0, 0, 0}, {0, 0, 1}, {0, 1, 0}}
twist := []vec{{0, 0, 0}, {0, 0, 1}, {1, 0, 0}, {1, 1, 0}}
fmt.Printf("  it fixes the bent tricube with c=0: %v;"+
	" the L-twist with c=1: %v\n",
	fixes(bar132, vec{0, 0, 0}, bent), fixes(bar132, vec{1, 0, 0}, twist))

@ A map $x\mapsto Mx+t$ carries a set of cubies onto itself, or it does not.

@<Functions@>=
func fixes(m mat, t vec, p []vec) bool {
	in := map[vec]bool{}
	for _, c := range p {
		in[c] = true
	}
	for _, c := range p {
		q := act(m, c)
		if !in[(vec{q.x + t.x, q.y + t.y, q.z + t.z})] {
			return false
		}
	}
	return true
}

@* Subgroups, and symmetry types.
A subgroup of a group of at most 48 elements is a set of elements closed under
the operation, so a bit vector is all the room one needs. Closing a set is a
matter of multiplying everything by everything until nothing new appears, and
the subgroups are what you reach by starting at the identity and throwing in
one element at a time until the collection stops growing.

@<Types@>=
type grp uint64

@ @<Functions@>=
func closure(el []mat, idx map[mat]int, g grp) grp {
	g |= 1 << idx[mat{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}}]
	for again := true; again; {
		again = false
		for i := range el {
			if g&(1<<i) == 0 {
				continue
			}
			for j := range el {
				if g&(1<<j) == 0 {
					continue
				}
				k := grp(1) << idx[mul(el[i], el[j])]
				if g&k == 0 {
					g |= k
					again = true
				}
			}
		}
	}
	return g
}

func subgroups(el []mat, idx map[mat]int) []grp {
	have := map[grp]bool{closure(el, idx, 0): true}
	for again := true; again; {
		again = false
		for h := range have {
			for i := range el {
				k := closure(el, idx, h|(1<<i))
				if !have[k] {
					have[k] = true
					again = true
				}
			}
		}
	}
	out := make([]grp, 0, len(have))
	for h := range have {
		out = append(out, h)
	}
	sort.Slice(out, func(a, b int) bool { return out[a] < out[b] })
	return out
}

@ Two subgroups are conjugate when one is $t^{-}Tt$ for some $t$ in the whole
group; the answer explains that conjugate subgroups amount to looking at the
object from a different direction, so the symmetry types are the conjugacy
classes.

@<Functions@>=
func conjugate(el []mat, idx map[mat]int, h grp, t mat) grp {
	var k grp
	ti := inv(t)
	for i := range el {
		if h&(1<<i) != 0 {
			k |= 1 << idx[mul(mul(ti, el[i]), t)]
		}
	}
	return k
}

func classesOf(el []mat, idx map[mat]int) (subs []grp, cls [][]grp) {
	subs = subgroups(el, idx)
	seen := map[grp]bool{}
	for _, h := range subs {
		if seen[h] {
			continue
		}
		var c []grp
		in := map[grp]bool{}
		for _, t := range el {
			k := conjugate(el, idx, h, t)
			if !in[k] {
				in[k] = true
				c = append(c, k)
			}
			seen[k] = true
		}
		cls = append(cls, c)
	}
	sort.Slice(cls, func(a, b int) bool {
		if x, y := bits(cls[a][0]), bits(cls[b][0]); x != y {
			return x > y
		}
		return len(cls[a]) < len(cls[b])
	})
	return
}

func bits(g grp) int {
	n := 0
	for ; g != 0; g &= g - 1 {
		n++
	}
	return n
}

@ Each class gets the name answer 387 gives it. Order and number of conjugates
tell the eleven apart except for the two classes of order 4 with three
conjugates each, and those two differ in whether they contain a quarter turn.

@<Functions@>=
func nameOf(el []mat, h grp, conj int) string {
	quarter := false
	for i := range el {
		if h&(1<<i) != 0 && order(el, el[i]) == 4 {
			quarter = true
		}
	}
	switch {
	case bits(h) == 24:
		return "full"
	case bits(h) == 12:
		return "even"
	case bits(h) == 8:
		return "8-fold"
	case bits(h) == 6:
		return "6-fold"
	case bits(h) == 4 && conj == 1:
		return "tricentral"
	case bits(h) == 4 && quarter:
		return "90 deg"
	case bits(h) == 4:
		return "bidiagonal"
	case bits(h) == 3:
		return "120 deg"
	case bits(h) == 2 && conj == 6:
		return "diagonal"
	case bits(h) == 2:
		return "axial"
	}
	return "none"
}

func order(el []mat, m mat) int {
	id := mat{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}}
	k, a := 1, m
	for a != id {
		a = mul(a, m)
		k++
	}
	return k
}

@ @<Set up the two groups@>=
rotIdx := map[mat]int{}
for i, m := range rot {
	rotIdx[m] = i
}
fullIdx := map[mat]int{}
for i, m := range ms {
	fullIdx[m] = i
}
rotSubs, rotCls := classesOf(rot, rotIdx)
@<Number the classes the way answer 387 does@>

@ Answer 387 numbers the eleven classes (i) to (xi) in an order of its own, so
I put them in that order too and use its numbers throughout.

@<Number the classes the way answer 387 does@>=
sort.Slice(rotCls, func(a, b int) bool {
	return answerOrder(nameOf(rot, rotCls[a][0], len(rotCls[a]))) <
		answerOrder(nameOf(rot, rotCls[b][0], len(rotCls[b])))
})

@ @<Functions@>=
func answerOrder(n string) int {
	for i, s := range []string{"full", "even", "8-fold", "6-fold", "90 deg",
		"bidiagonal", "tricentral", "120 deg", "diagonal", "axial", "none"} {
		if s == n {
			return i
		}
	}
	return 99
}

@ @<Count the subgroups and the symmetry types@>=
fmt.Println("subgroups and symmetry types")
fmt.Printf("  the 24 rotations have %d subgroups in %d conjugacy classes\n",
	len(rotSubs), len(rotCls))
fullSubs, fullCls := classesOf(ms, fullIdx)
fmt.Printf("  all 48 signed permutations have %d subgroups in %d classes\n",
	len(fullSubs), len(fullCls))
for i, c := range rotCls {
	fmt.Printf("  (%s) %-11s order %2d, %d conjugate%s\n",
		roman(i+1), nameOf(rot, c[0], len(c)), bits(c[0]), len(c),
		map[bool]string{true: "", false: "s"}[len(c) == 1])
}

@ @<Functions@>=
func roman(n int) string {
	return []string{"", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii",
		"ix", "x", "xi"}[n]
}

@* What the answer says about three of the types.
Three sentences in answer 387 say something specific enough to test. Class (ii)
``consists of the 12 symmetries whose permutations are even''; class (iv) ``has
one symmetry for each permutation of the three coordinates''; and seven of the
classes ``correspond to the eight symmetry types of a square, with reflections
implemented by turning the square over,'' the square's $180^\circ$ having
become the same thing as {\it axial}.

@<Check what the answer says about particular types@>=
fmt.Println("what the answer says about particular types")
@<Look at the class of order 12@>
@<Look at the class of order 6@>
@<Turn a square over@>

@ @<Look at the class of order 12@>=
for _, c := range rotCls {
	if bits(c[0]) != 12 {
		continue
	}
	evens, all := 0, true
	for i, m := range rot {
		e := parityOf(m) == 0
		if c[0]&(1<<i) != 0 {
			if e {
				evens++
			} else {
				all = false
			}
		} else if e {
			all = false
		}
	}
	fmt.Printf("  class (ii): %d symmetries, all with even permutations,"+
		" and no others: %v\n", evens, all)
}

@ The permutation part of a signed permutation is even or odd on its own,
whatever the signs do.

@<Functions@>=
func parityOf(m mat) int {
	var p [3]int
	for i := range 3 {
		for j := range 3 {
			if m[i][j] != 0 {
				p[i] = j
			}
		}
	}
	n := 0
	for a := range 3 {
		for b := a + 1; b < 3; b++ {
			if p[a] > p[b] {
				n++
			}
		}
	}
	return n % 2
}

@ @<Look at the class of order 6@>=
for _, c := range rotCls {
	if bits(c[0]) != 6 {
		continue
	}
	seen := map[[3]int]bool{}
	for i, m := range rot {
		if c[0]&(1<<i) != 0 {
			var p [3]int
			for a := range 3 {
				for b := range 3 {
					if m[a][b] != 0 {
						p[a] = b
					}
				}
			}
			seen[p] = true
		}
	}
	fmt.Printf("  class (iv): %d symmetries covering %d of the 6 permutations\n",
		bits(c[0]), len(seen))
}

@ A square that may be turned over has the eight symmetries of a square prism:
four rotations about the prism's axis, and four half turns about axes across
it. Its subgroups fall into eight conjugacy classes, which are the eight
symmetry types of a polyomino; each of them sits inside one of the eleven
classes of the whole rotation group, and the question is how many different
ones they land in.

@<Turn a square over@>=
var d4 []mat
for _, m := range rot {
	if act(m, vec{0, 0, 1}) == (vec{0, 0, 1}) || act(m, vec{0, 0, 1}) == (vec{0, 0, -1}) {
		d4 = append(d4, m)
	}
}
d4Idx := map[mat]int{}
for i, m := range d4 {
	d4Idx[m] = i
}
_, d4Cls := classesOf(d4, d4Idx)
@<Say where each type of square lands@>

@ @<Say where each type of square lands@>=
where := map[string][]int{}
for i, c := range d4Cls {
	var g grp
	for j := range d4 {
		if c[0]&(1<<j) != 0 {
			g |= 1 << rotIdx[d4[j]]
		}
	}
	for k, rc := range rotCls {
		for _, h := range rc {
			if h == g {
				n := nameOf(rot, h, len(rc))
				where[n] = append(where[n], i)
				_ = k
			}
		}
	}
}
var names []string
for n := range where {
	names = append(names, n)
}
sort.Strings(names)
fmt.Printf("  the square's %d types land in %d of the eleven classes: %s\n",
	len(d4Cls), len(where), strings.Join(names, ", "))
for _, n := range names {
	if len(where[n]) > 1 {
		fmt.Printf("  two of the square's types become the same class here: %s\n", n)
	}
}

@* The symmetry type of a polycube.
A rotation is a symmetry of a polycube when the rotated cubies, slid back into
place, are the cubies one started with. Those rotations form a subgroup, and
the class of that subgroup is the polycube's symmetry type.

@<Functions@>=
func shift(p []vec) []vec {
	lo := p[0]
	for _, c := range p {
		lo = vec{min(lo.x, c.x), min(lo.y, c.y), min(lo.z, c.z)}
	}
	out := make([]vec, len(p))
	for i, c := range p {
		out[i] = vec{c.x - lo.x, c.y - lo.y, c.z - lo.z}
	}
	sort.Slice(out, func(a, b int) bool {
		if out[a].x != out[b].x {
			return out[a].x < out[b].x
		}
		if out[a].y != out[b].y {
			return out[a].y < out[b].y
		}
		return out[a].z < out[b].z
	})
	return out
}

func key(p []vec) string {
	var b strings.Builder
	for _, c := range p {
		fmt.Fprintf(&b, "%d.%d.%d;", c.x, c.y, c.z)
	}
	return b.String()
}

@ @<Functions@>=
func symgroup(rot []mat, rotIdx map[mat]int, p []vec) grp {
	want := key(shift(p))
	var g grp
	for i, m := range rot {
		q := make([]vec, len(p))
		for j, c := range p {
			q[j] = act(m, c)
		}
		if key(shift(q)) == want {
			g |= 1 << i
		}
	}
	return g
}

@ Two polycubes are the same when a rotation carries one to the other, so the
smallest of the 24 turned-and-slid forms is a name they share.

@<Functions@>=
func canon(rot []mat, p []vec) string {
	best := ""
	for _, m := range rot {
		q := make([]vec, len(p))
		for j, c := range p {
			q[j] = act(m, c)
		}
		if k := key(shift(q)); best == "" || k < best {
			best = k
		}
	}
	return best
}

func unkey(s string) []vec {
	var p []vec
	for _, t := range strings.Split(strings.TrimSuffix(s, ";"), ";") {
		var c vec
		fmt.Sscanf(t, "%d.%d.%d", &c.x, &c.y, &c.z)
		p = append(p, c)
	}
	return p
}

@* Growing all the polycubes.
The plainest way to find the smallest polycube of a given type is to look at
all the small ones. Grow them a cubie at a time, keep one representative of
each rotation class, and note when a type first shows up.

@<Grow every polycube and watch for new types@>=
fmt.Printf("growing every polycube up to %d cubies\n", *top)
cur := map[string]bool{canon(rot, []vec{{0, 0, 0}}): true}
firstAt := map[string]int{}
firstIs := map[string]string{}
for n := 1; n <= *top; n++ {
	if n > 1 {
		@<Add one cubie in every way@>
	}
	@<Record any type seen for the first time@>
	fmt.Printf("  %2d cubies: %6d polycubes\n", n, len(cur))
}
@<Report the smallest polycube of each type@>

@ @<Add one cubie in every way@>=
next := map[string]bool{}
for s := range cur {
	p := unkey(s)
	in := map[vec]bool{}
	for _, c := range p {
		in[c] = true
	}
	for _, c := range p {
		for _, d := range []vec{{1, 0, 0}, {-1, 0, 0}, {0, 1, 0},
			{0, -1, 0}, {0, 0, 1}, {0, 0, -1}} {
			q := vec{c.x + d.x, c.y + d.y, c.z + d.z}
			if !in[q] {
				next[canon(rot, append(append([]vec{}, p...), q))] = true
			}
		}
	}
}
cur = next

@ @<Record any type seen for the first time@>=
for s := range cur {
	p := unkey(s)
	nm := typeName(rot, rotIdx, rotCls, p)
	if _, ok := firstAt[nm]; !ok {
		firstAt[nm], firstIs[nm] = n, s
	}
}

@ @<Functions@>=
func typeName(rot []mat, rotIdx map[mat]int, cls [][]grp, p []vec) string {
	g := symgroup(rot, rotIdx, p)
	for _, c := range cls {
		for _, h := range c {
			if h == g {
				return nameOf(rot, h, len(c))
			}
		}
	}
	return "?"
}

@ @<Report the smallest polycube of each type@>=
for i, c := range rotCls {
	nm := nameOf(rot, c[0], len(c))
	if n, ok := firstAt[nm]; ok {
		fmt.Printf("  (%-4s %-11s %2d cubies:  %s\n",
			roman(i+1)+")", nm, n, show(unkey(firstIs[nm])))
	} else {
		fmt.Printf("  (%-4s %-11s none up to %d cubies\n",
			roman(i+1)+")", nm, *top)
	}
}

@ @<Functions@>=
func show(p []vec) string {
	var b []string
	for _, c := range p {
		b = append(b, fmt.Sprintf("%d%d%d", c.x, c.y, c.z))
	}
	return strings.Join(b, " ")
}

@* The minimum for every type.
Growing polycubes runs out of room long before it reaches twenty cubies, so
the type of order 12 needs a different handle. Here is one. Every symmetry of a
polycube carries its bounding box onto the bounding box, and so fixes the
centre of that box; the centre has half-integer coordinates, which become
integers if every cubie coordinate is doubled. A polycube whose symmetries are
$G$ is therefore a union of orbits of $G$ acting about that centre---and if it
has $n$ cubies, none of them is further than $n-1$ from the centre in doubled
coordinates, because a connected polycube of $n$ cubies spans at most $n$ in
any direction.

So: try each of the eight centres modulo 2, take every orbit that fits inside
the box, and look for a set of orbits with $n$ cubies between them that is
connected and has exactly the symmetries asked for. Nothing is missed.

@<Find the smallest polycube of each type@>=
fmt.Println("the smallest polycube of each type")
for i, c := range rotCls {
	nm := nameOf(rot, c[0], len(c))
	var found []vec
	for n := 1; n <= *lim && found == nil; n++ {
		found = smallest(rot, rotIdx, rotCls, c[0], n)
		if found != nil {
			fmt.Printf("  (%-4s %-11s %2d cubies:  %s\n",
				roman(i+1)+")", nm, n, show(found))
			if nm == "even" {
				@<Look for the core of eight answer 387 describes@>
			}
		}
	}
	if found == nil {
		fmt.Printf("  (%-4s %-11s nothing up to %d cubies\n",
			roman(i+1)+")", nm, *lim)
	}
}

@ Of the class of order 12 the answer says more: ``the smallest polycube which
admits these symmetries and no more $\ldots$ contains 20 cubies, with 12
surrounding a central core of 8.'' A core of 8 can only be a $2\times2\times2$
block, so I look for one and count what is left over.

@<Look for the core of eight answer 387 describes@>=
core := 0
for _, c := range found {
	if c.x >= 1 && c.x <= 2 && c.y >= 1 && c.y <= 2 && c.z >= 1 && c.z <= 2 {
		core++
	}
}
fmt.Printf("        of those, %d form a 2x2x2 block and %d surround it\n",
	core, len(found)-core)

@ @<Functions@>=
func smallest(rot []mat, rotIdx map[mat]int, cls [][]grp, g grp, n int) []vec {
	for c := range 8 {
		q := vec{c & 1, (c >> 1) & 1, (c >> 2) & 1}
		@<Give up on this centre unless the group acts about it@>
		orbs := orbitsAbout(rot, g, q, n)
		if p := pickOrbits(rot, rotIdx, cls, g, orbs, 0, n, nil); p != nil {
			return p
		}
	}
	return nil
}

@ The rotation |m| about |q| sends a cubie at |x| to $m(x-q)+q$, which lands on
the cubie lattice for every |x| only when $(I-m)q$ is even in each coordinate.

@<Give up on this centre unless the group acts about it@>=
ok := true
for i, m := range rot {
	if g&(1<<i) == 0 {
		continue
	}
	d := act(m, q)
	if (q.x-d.x)%2 != 0 || (q.y-d.y)%2 != 0 || (q.z-d.z)%2 != 0 {
		ok = false
	}
}
if !ok {
	continue
}

@ @<Functions@>=
func orbitsAbout(rot []mat, g grp, q vec, n int) [][]vec {
	r := n - 1
	seen := map[vec]bool{}
	var out [][]vec
	for x := q.x - r; x <= q.x+r; x++ {
		for y := q.y - r; y <= q.y+r; y++ {
			for z := q.z - r; z <= q.z+r; z++ {
				p := vec{x, y, z}
				@<Collect the orbit of |p|, if it is new and it fits@>
			}
		}
	}
	sort.Slice(out, func(a, b int) bool { return len(out[a]) < len(out[b]) })
	return out
}

@ Only points of the doubled lattice are cubies, and only an orbit that lies
wholly inside the box can belong to a polycube of this size.

@<Collect the orbit of |p|, if it is new and it fits@>=
if x%2 != 0 || y%2 != 0 || z%2 != 0 || seen[p] {
	continue
}
var orb []vec
in := map[vec]bool{}
for i, m := range rot {
	if g&(1<<i) == 0 {
		continue
	}
	d := act(m, vec{p.x - q.x, p.y - q.y, p.z - q.z})
	w := vec{d.x + q.x, d.y + q.y, d.z + q.z}
	if !in[w] {
		in[w] = true
		orb = append(orb, w)
	}
}
fits := len(orb) <= n
for _, w := range orb {
	seen[w] = true
	if w.x < q.x-r || w.x > q.x+r || w.y < q.y-r || w.y > q.y+r ||
		w.z < q.z-r || w.z > q.z+r {
		fits = false
	}
}
if fits {
	out = append(out, orb)
}

@ The orbits are sorted by size, so the walk can stop as soon as the next one
is too big for what is left.

@<Functions@>=
func pickOrbits(rot []mat, rotIdx map[mat]int, cls [][]grp, g grp,
	orbs [][]vec, from, left int, chosen []vec) []vec {
	if left == 0 {
		@<Report these orbits if they make the polycube we want@>
	}
	for j := from; j < len(orbs); j++ {
		if len(orbs[j]) > left {
			break
		}
		if p := pickOrbits(rot, rotIdx, cls, g, orbs, j+1,
			left-len(orbs[j]), append(chosen, orbs[j]...)); p != nil {
			return p
		}
	}
	return nil
}

@ @<Report these orbits if they make the polycube we want@>=
p := make([]vec, len(chosen))
for i, c := range chosen {
	p[i] = vec{c.x / 2, c.y / 2, c.z / 2}
}
if !connected(p) {
	return nil
}
h := symgroup(rot, rotIdx, p)
for _, c := range cls {
	if sameClass(c, g) && sameClass(c, h) {
		return shift(p)
	}
}
return nil

@ @<Functions@>=
func sameClass(c []grp, g grp) bool {
	for _, k := range c {
		if k == g {
			return true
		}
	}
	return false
}

func connected(p []vec) bool {
	in := map[vec]bool{}
	for _, c := range p {
		in[c] = true
	}
	seen := map[vec]bool{p[0]: true}
	stack := []vec{p[0]}
	for len(stack) > 0 {
		c := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		for _, d := range []vec{{1, 0, 0}, {-1, 0, 0}, {0, 1, 0},
			{0, -1, 0}, {0, 0, 1}, {0, 0, -1}} {
			q := vec{c.x + d.x, c.y + d.y, c.z + d.z}
			if in[q] && !seen[q] {
				seen[q] = true
				stack = append(stack, q)
			}
		}
	}
	return len(seen) == len(p)
}

@* Weighing the pictures in answer 387.
The exercise asks for an example of each type ``using the minimum number of
cubies,'' so the eleven drawings ought to be as small as the numbers above.
Counting cubies in a small isometric drawing is not something to do by eye, but
one feature of such a drawing can be counted without any risk: the shaded top
faces, one for each cubie that has nothing directly above it. I read those off
the printed figure by looking for connected patches of the colour reserved for
top faces, and got

$$\vbox{\halign{\hfil#\quad&#\hfil\cr
1&full\cr 10&even\cr 2&8-fold\cr 3&6-fold\cr 8&90$^\circ$\cr 6&bidiagonal\cr
6&tricentral\cr 3&120$^\circ$\cr 3&diagonal\cr 4&axial\cr 4&none.\cr}}$$

Now, a drawing shows one top face for each column of the polycube along the
direction it is drawn as vertical. So the most top faces an $n$-cubie polycube
can ever show is the largest of its three projections, and if a drawing shows
more than that, the thing drawn is not of the minimum size.

@<Weigh the pictures in answer 387@>=
fmt.Println("weighing the pictures against the minimum")
printed := map[string]int{"full": 1, "even": 10, "8-fold": 2, "6-fold": 3,
	"90 deg": 8, "bidiagonal": 6, "tricentral": 6, "120 deg": 3,
	"diagonal": 3, "axial": 4, "none": 4}
@<Find, for each size, the most top faces a polycube of each type can show@>
@<Say which pictures are too big@>
@<Look at the type (v) picture itself@>

@ @<Find, for each size, the most top faces a polycube of each type can show@>=
mostTops := map[string]map[int]int{}
cur := map[string]bool{canon(rot, []vec{{0, 0, 0}}): true}
for n := 1; n <= 6; n++ {
	if n > 1 {
		@<Add one cubie in every way@>
	}
	for s := range cur {
		p := unkey(s)
		nm := typeName(rot, rotIdx, rotCls, p)
		t := columns(p)
		if mostTops[nm] == nil {
			mostTops[nm] = map[int]int{}
		}
		if t > mostTops[nm][n] {
			mostTops[nm][n] = t
		}
	}
}

@ @<Functions@>=
func columns(p []vec) int {
	best := 0
	for _, f := range []func(vec) [2]int{
		func(c vec) [2]int { return [2]int{c.x, c.y} },
		func(c vec) [2]int { return [2]int{c.x, c.z} },
		func(c vec) [2]int { return [2]int{c.y, c.z} }} {
		seen := map[[2]int]bool{}
		for _, c := range p {
			seen[f(c)] = true
		}
		if len(seen) > best {
			best = len(seen)
		}
	}
	return best
}

@ @<Say which pictures are too big@>=
for i, c := range rotCls {
	nm := nameOf(rot, c[0], len(c))
	least := 0
	for n := 1; n <= 6; n++ {
		if mostTops[nm] != nil && mostTops[nm][n] > 0 && least == 0 {
			least = n
		}
	}
	if least == 0 {
		fmt.Printf("  (%-4s %-11s printed drawing shows %2d top faces;"+
			" minimum size is past the reach of this check\n",
			roman(i+1)+")", nm, printed[nm])
		continue
	}
	verdict := "consistent with the minimum"
	if printed[nm] > mostTops[nm][least] {
		verdict = fmt.Sprintf("TOO BIG: %d cubies can show at most %d",
			least, mostTops[nm][least])
	}
	fmt.Printf("  (%-4s %-11s minimum %d, which can show at most %d top"+
		" faces; the drawing shows %2d -- %s\n",
		roman(i+1)+")", nm, least, mostTops[nm][least], printed[nm], verdict)
}

@ The type (v) drawing can be read exactly, because its eight top faces all sit
at one height in the drawing's projection: it is a flat pinwheel of eight
cubies. Here it is, next to a six-cubie polycube of the same type.

@<Look at the type (v) picture itself@>=
pinwheel := []vec{{0, 2, 0}, {1, 0, 0}, {1, 1, 0}, {1, 2, 0},
	{2, 1, 0}, {2, 2, 0}, {2, 3, 0}, {3, 1, 0}}
mine := []vec{{0, 1, 0}, {1, 0, 0}, {1, 1, 0}, {1, 1, 1}, {1, 2, 0}, {2, 1, 0}}
for _, p := range [][]vec{pinwheel, mine} {
	fmt.Printf("  %d cubies, connected %v, type %s:  %s\n",
		len(p), connected(p), typeName(rot, rotIdx, rotCls, p), show(shift(p)))
}

@* Index.
