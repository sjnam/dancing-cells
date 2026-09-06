\datethis
\def\title{Windmill Dominoes}

@* Introduction.
Exercise 7.2.2.1--305 glues a small tilted domino over an ordinary one and gets
ten two-layer pieces, the {\it windmill dominoes}. Its five parts ask for the
arrangement whose upper layer looks like a windmill, for packings of the ten
pieces into a $4\times5$ and a $2\times10$ box, and for the two ways of making
the {\it upper\/} layer fill a rectangle instead. Exercise 306 then asks for the
arrangements in which the twenty large squares and the twenty small ones each
form a snake-in-the-box cycle, in the sense of exercise 172(b).

This program checks every count both answers print. The two exercises share a
piece set and a coordinate system, so they share a program.

Answer 305 supplies the coordinates: the large square in row $i$ and column $j$
is the pair $(2i+1)(2j+1)$, and the small tilted square straddling two adjacent
large squares is the midpoint between them. So a point with two odd coordinates
is a large square, a point with exactly one is a small one, and a point with
none is a corner of the large grid. Large squares have area~4, small ones
area~2.

@c
package main

import (
	"flag"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	cells "github.com/sjnam/dancing-cells"
)

@<Declarations@>
@<Functions@>

func main() {
	@<Read the command line@>
	@<Do what the mode asks@>
}

@ The parts of exercise 305 are named as the exercise names them. |shapes|
lists the distinct shapes the large squares make, which is how the picture in
the answer to part~(d) gets identified; |snake| is the whole of exercise 306.
@<Read the command line@>=
mode := flag.String("mode", "pieces",
	"pieces, a, b, c, d, e8, e9, shapes, or snake")
verbose := flag.Bool("v", false, "list the options of each piece")
flag.Parse()

@ @<Do what the mode asks@>=
switch *mode {
case "pieces":
	@<Check the piece set@>
case "shapes":
	@<List the shapes the large squares make@>
case "snake":
	@<Do exercise 306@>
default:
	report(*mode, *verbose)
}

@* The windmill dominoes.
A point is a pair of integers; the parity of the pair says what kind of square
sits there.

@<Declarations@>=
type pt struct{ a, b int }

@ @<Functions@>=
func large(p pt) bool { return p.a%2 != 0 && p.b%2 != 0 }

@ @<Functions@>=
func small(p pt) bool { return (p.a+p.b)%2 != 0 }

@ A piece is two large squares that share an edge and two small ones that share
an edge. The exercise's picture shows that the small domino has to cover part
of the large one, so at least one of its squares lies over a square of the
large domino; the other may hang off.

@<Declarations@>=
type piece struct {
	big   [2]pt
	small [2]pt
}

@ A quarter turn about the origin keeps both kinds of square where they belong,
because it preserves the parities.

@<Functions@>=
func rot(p pt) pt { return pt{-p.b, p.a} }

@ @<Functions@>=
func (q piece) turn() piece {
	var r piece
	for i := 0; i < 2; i++ {
		r.big[i] = rot(q.big[i])
		r.small[i] = rot(q.small[i])
	}
	return r.tidy()
}

@ Sliding a piece by an even amount is the only translation that respects the
parities. |tidy| slides it until it sits at the origin and puts each pair in
order, so that two placements of the same piece look the same.

@<Functions@>=
func (q piece) tidy() piece {
	q = q.sorted()
	minA, minB := 1<<30, 1<<30
	for _, p := range q.cells() {
		if p.a < minA {
			minA = p.a
		}
		if p.b < minB {
			minB = p.b
		}
	}
	da, db := minA-minA&1, minB-minB&1
	for i := 0; i < 2; i++ {
		q.big[i] = pt{q.big[i].a - da, q.big[i].b - db}
		q.small[i] = pt{q.small[i].a - da, q.small[i].b - db}
	}
	return q
}

@ @<Functions@>=
func (q piece) sorted() piece {
	if ahead(q.big[1], q.big[0]) {
		q.big[0], q.big[1] = q.big[1], q.big[0]
	}
	if ahead(q.small[1], q.small[0]) {
		q.small[0], q.small[1] = q.small[1], q.small[0]
	}
	return q
}

@ @<Functions@>=
func ahead(u, v pt) bool { return u.a < v.a || (u.a == v.a && u.b < v.b) }

@ @<Functions@>=
func (q piece) cells() []pt {
	return []pt{q.big[0], q.big[1], q.small[0], q.small[1]}
}

@ Two pieces are the same when a turn and a slide carry one to the other; the
exercise counts them that way, and reflections are {\it not\/} allowed, since a
piece and its mirror image are different windmill dominoes. The canonical form
is the least of the four turns.

@<Functions@>=
func (q piece) key() string {
	c := q.cells()
	sort.Slice(c, func(i, j int) bool { return ahead(c[i], c[j]) })
	s := ""
	for _, p := range c {
		s += fmt.Sprintf("(%d,%d)", p.a, p.b)
	}
	return s
}

@ @<Functions@>=
func (q piece) canon() string {
	best, r := "", q.tidy()
	for i := 0; i < 4; i++ {
		if k := r.key(); best == "" || k < best {
			best = k
		}
		r = r.turn()
	}
	return best
}

@ Building the set: take each of the two large dominoes, collect the small
squares that touch either of its squares, pair each with a diagonal neighbour,
and reduce. Exactly ten survive.

@<Functions@>=
func pieces() []piece {
	seen := map[string]piece{}
	for _, big := range [][2]pt{{{1, 1}, {1, 3}}, {{1, 1}, {3, 1}}} {
		@<Glue every small domino onto this large one@>
	}
	var keys []string
	for k := range seen {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var out []piece
	for _, k := range keys {
		out = append(out, seen[k])
	}
	return out
}

@ @<Glue every small domino onto this large one@>=
touching := map[pt]bool{}
for _, g := range big {
	for _, d := range []pt{{-1, 0}, {1, 0}, {0, -1}, {0, 1}} {
		touching[pt{g.a + d.a, g.b + d.b}] = true
	}
}
for p := range touching {
	for _, d := range smallSteps {
		q := pt{p.a + d.a, p.b + d.b}
		if !small(q) {
			continue
		}
		pc := piece{big, [2]pt{p, q}}
		seen[pc.canon()] = pc.tidy()
	}
}

@ Two small squares share an edge when they step diagonally by one; two large
squares share an edge when they step by two. These two step sets come up
everywhere, and exercise 306 needs them by name.

@<Declarations@>=
var smallSteps = []pt{{-1, -1}, {-1, 1}, {1, -1}, {1, 1}}

@ @<Declarations@>=
var bigSteps = []pt{{-2, 0}, {2, 0}, {0, -2}, {0, 2}}

@ Answer 305 lists the four placements of ``the leftmost piece'': $\{13,15,12,
23\}$, $\{33,53,23,32\}$, $\{33,31,34,23\}$ and $\{31,11,41,32\}$. They should
be the four turns of a single one of the ten.

@<Check the piece set@>=
ps := pieces()
fmt.Printf("windmill dominoes: %d\n", len(ps))
for i, q := range ps {
	fmt.Printf("  %d: large %v %v, small %v %v\n", i,
		q.big[0], q.big[1], q.small[0], q.small[1])
}
@<Compare with the placements answer 305 prints@>

@ @<Compare with the placements answer 305 prints@>=
printed := [][4]pt{
	{{1, 3}, {1, 5}, {1, 2}, {2, 3}},
	{{3, 3}, {5, 3}, {2, 3}, {3, 2}},
	{{3, 3}, {3, 1}, {3, 4}, {2, 3}},
	{{3, 1}, {1, 1}, {4, 1}, {3, 2}},
}
keys := map[string]bool{}
for _, pl := range printed {
	keys[piece{[2]pt{pl[0], pl[1]}, [2]pt{pl[2], pl[3]}}.canon()] = true
}
known := map[string]bool{}
for _, q := range ps {
	known[q.canon()] = true
}
fmt.Printf("the four placements answer 305 prints are one piece: %v\n",
	len(keys) == 1)
for k := range keys {
	fmt.Printf("and it is one of the ten: %v\n", known[k])
}

@* Boxes and layers.
A box of $m$ rows and $n$ columns holds large squares at the odd-odd points
strictly inside $2m$ by $2n$. The small squares of a piece may or may not have
to stay inside, and which of the two layers has to be filled exactly changes
from part to part; that is the whole of the difference between (a)--(c) and
(d)--(e).

@<Declarations@>=
type box struct{ m, n int }

@ @<Functions@>=
func (x box) insideLarge(p pt) bool {
	return large(p) && 0 < p.a && p.a < 2*x.m && 0 < p.b && p.b < 2*x.n
}

@ Item names have to survive the parser, and a coordinate can go negative, so
everything is shifted by eight before it is written down.

@<Functions@>=
func sq(p pt) string { return fmt.Sprintf("s%d.%d", p.a+8, p.b+8) }

@ @<Functions@>=
func unsq(s string) pt {
	i := strings.IndexByte(s, '.')
	a, _ := strconv.Atoi(s[1:i])
	b, _ := strconv.Atoi(s[i+1:])
	return pt{a - 8, b - 8}
}

@ A problem is a box together with a demand on the upper layer. When |pairs| is
set, a piece may only be placed so that its small domino is one of the listed
pairs; that is how part~(a) asks for a windmill. When |smallPrim| is set, those
small squares are primary and have to be filled exactly, which is what
parts~(d) and~(e) want. When neither is set the small squares merely have to
keep out of each other's way inside the box.

@<Declarations@>=
type prob struct {
	x          box
	smallPrim  map[pt]bool
	pairs      map[[2]pt]bool
	piecesPrim bool
	largePrim  bool
}

@ @<Functions@>=
func pairKey(u, v pt) [2]pt {
	if ahead(v, u) {
		u, v = v, u
	}
	return [2]pt{u, v}
}

@ @<Functions@>=
func (w prob) options(q piece) []piece {
	var out []piece
	seen := map[piece]bool{}
	r := q.tidy()
	for turn := 0; turn < 4; turn++ {
		for da := -4 * w.x.m; da <= 4*w.x.m; da += 2 {
			for db := -4 * w.x.n; db <= 4*w.x.n; db += 2 {
				@<Slide the piece there and keep it if it fits@>
			}
		}
		r = r.turn()
	}
	return out
}

@ @<Slide the piece there and keep it if it fits@>=
var s piece
for i := 0; i < 2; i++ {
	s.big[i] = pt{r.big[i].a + da, r.big[i].b + db}
	s.small[i] = pt{r.small[i].a + da, r.small[i].b + db}
}
if !w.x.insideLarge(s.big[0]) || !w.x.insideLarge(s.big[1]) {
	continue
}
@<Ask whether the upper layer allows this placement@>
if s = s.sorted(); !seen[s] {
	seen[s] = true
	out = append(out, s)
}

@ @<Ask whether the upper layer allows this placement@>=
switch {
case w.pairs != nil:
	if !w.pairs[pairKey(s.small[0], s.small[1])] {
		continue
	}
case w.smallPrim != nil:
	if !w.smallPrim[s.small[0]] || !w.smallPrim[s.small[1]] {
		continue
	}
default:
	if outside(s.small[0], w.x) || outside(s.small[1], w.x) {
		continue
	}
}

@ @<Functions@>=
func outside(p pt, x box) bool {
	return p.a <= 0 || p.a >= 2*x.m || p.b <= 0 || p.b >= 2*x.n
}

@* The exact cover problem.
Each piece is an item, primary when it must be used and secondary when it need
not be; each square of a layer that has to be filled exactly is a primary item;
each square that merely has to stay unshared is a secondary item.

@<Functions@>=
func (w prob) build() (string, [][]piece) {
	ps := pieces()
	all := make([][]piece, len(ps))
	var prim, sec []string
	for i := range ps {
		all[i] = w.options(ps[i])
		@<Declare the item for piece i@>
	}
	@<Declare the items for the squares@>
	var b strings.Builder
	b.WriteString(strings.Join(prim, " "))
	if len(sec) > 0 {
		b.WriteString(" | " + strings.Join(sec, " "))
	}
	b.WriteByte('\n')
	@<Write one option per placement@>
	return b.String(), all
}

@ @<Declare the item for piece i@>=
if w.piecesPrim {
	prim = append(prim, fmt.Sprintf("P%d", i))
} else {
	sec = append(sec, fmt.Sprintf("P%d", i))
}

@ A small square that is neither wanted nor forbidden gets no item at all: when
|smallPrim| is set, the placements were already restricted to it.

@<Declare the items for the squares@>=
for a := 1; a < 2*w.x.m; a++ {
	for b := 1; b < 2*w.x.n; b++ {
		p := pt{a, b}
		switch {
		case large(p):
			if w.largePrim {
				prim = append(prim, sq(p))
			} else {
				sec = append(sec, sq(p))
			}
		case small(p):
			if w.smallPrim[p] {
				prim = append(prim, sq(p))
			} else if w.smallPrim == nil {
				sec = append(sec, sq(p))
			}
		}
	}
}

@ @<Write one option per placement@>=
for i := range ps {
	for _, s := range all[i] {
		fmt.Fprintf(&b, "P%d %s %s %s %s\n", i,
			sq(s.big[0]), sq(s.big[1]), sq(s.small[0]), sq(s.small[1]))
	}
}

@ A solution arrives as a list of options, each a list of item names; turning it
back into placements is a matter of parities.

@<Functions@>=
func parse(opt []cells.Option) []piece {
	var out []piece
	for _, o := range opt {
		var q piece
		nb, ns := 0, 0
		for _, t := range o[1:] {
			if p := unsq(t); large(p) {
				q.big[nb] = p
				nb++
			} else {
				q.small[ns] = p
				ns++
			}
		}
		out = append(out, q.sorted())
	}
	return out
}

@ @<Functions@>=
func bigs(sol []piece) []pt {
	var out []pt
	for _, q := range sol {
		out = append(out, q.big[0], q.big[1])
	}
	return out
}

@ @<Functions@>=
func smalls(sol []piece) []pt {
	var out []pt
	for _, q := range sol {
		out = append(out, q.small[0], q.small[1])
	}
	return out
}

@* Symmetries of a box.
Two arrangements in the same box are the same puzzle when one of the box's own
symmetries carries the other to it: four of them for an oblong, eight for a
square. Which of them actually apply depends on the problem---the windmill of
part~(a) is chiral, so its reflections drop out---so a symmetry counts only when
it carries every legal placement to a legal one.

@<Declarations@>=
type xform struct {
	name string
	f    func(pt) pt
}

@ @<Functions@>=
func (x box) group() []xform {
	m, n := 2*x.m, 2*x.n
	g := []xform{
		{"id", func(p pt) pt { return p }},
		{"flip rows", func(p pt) pt { return pt{m - p.a, p.b} }},
		{"flip cols", func(p pt) pt { return pt{p.a, n - p.b} }},
		{"turn 180", func(p pt) pt { return pt{m - p.a, n - p.b} }},
	}
	if x.m == x.n {
		g = append(g,
			xform{"transpose", func(p pt) pt { return pt{p.b, p.a} }},
			xform{"turn 90", func(p pt) pt { return pt{p.b, m - p.a} }},
			xform{"turn 270", func(p pt) pt { return pt{n - p.b, p.a} }},
			xform{"anti-transpose", func(p pt) pt { return pt{n - p.b, m - p.a} }})
	}
	return g
}

@ @<Functions@>=
func (t xform) on(q piece) piece {
	var r piece
	for i := 0; i < 2; i++ {
		r.big[i] = t.f(q.big[i])
		r.small[i] = t.f(q.small[i])
	}
	return r.sorted()
}

@ Because a placement determines its piece, a symmetry that carries every legal
placement to a legal one automatically permutes the ten pieces, and so carries
solutions to solutions.

@<Functions@>=
func (w prob) symmetries(all [][]piece) []xform {
	legal := map[piece]bool{}
	for _, l := range all {
		for _, q := range l {
			legal[q] = true
		}
	}
	var out []xform
	for _, t := range w.x.group() {
		ok := true
		for q := range legal {
			if !legal[t.on(q)] {
				ok = false
				break
			}
		}
		if ok {
			out = append(out, t)
		}
	}
	return out
}

@ @<Functions@>=
func skey(sol []piece) string {
	c := append([]piece(nil), sol...)
	sort.Slice(c, func(i, j int) bool {
		if c[i].big[0] != c[j].big[0] {
			return ahead(c[i].big[0], c[j].big[0])
		}
		return ahead(c[i].small[0], c[j].small[0])
	})
	var b strings.Builder
	for _, q := range c {
		fmt.Fprintf(&b, "%v%v%v%v;", q.big[0], q.big[1], q.small[0], q.small[1])
	}
	return b.String()
}

@ A class of arrangements is an orbit of the group. Counting classes by
dividing the number of arrangements by the group order is wrong whenever some
arrangement is symmetric, so each one contributes the order of its own
stabilizer instead: a class whose stabilizer has order $f$ holds $|G|/f$
arrangements, so it earns $f$ towards a total that is divided by $|G|$ at the
end. Answer 305 splits its counts exactly this way, writing $501484=2\cdot4+
4\cdot125369$.

@<Declarations@>=
type tally struct{ sols, weight int }

@ @<Functions@>=
func (t *tally) add(fix int) { t.sols++; t.weight += fix }

@ @<Functions@>=
func (t tally) classes(g int) int { return t.weight / g }

@* The shape of a layer.
Answer 305 speaks of arrangements ``whose small squares do at least form a
symmetric shape''. A shape is symmetric when a reflection or turn about its own
centre carries it to itself; where it happens to sit is beside the point. Only
a shape as wide as it is tall can survive a quarter turn or a diagonal
reflection, so those are asked about only then.

@<Declarations@>=
var shapeMaps = []struct {
	name string
	f    func(pt, int, int) pt
	sq   bool
}{
	{"mirror across a row", func(p pt, ha, hb int) pt { return pt{ha - p.a, p.b} }, false},
	{"mirror across a column", func(p pt, ha, hb int) pt { return pt{p.a, hb - p.b} }, false},
	{"turn 180", func(p pt, ha, hb int) pt { return pt{ha - p.a, hb - p.b} }, false},
	{"mirror across a diagonal", func(p pt, ha, hb int) pt { return pt{p.b, p.a} }, true},
	{"mirror across the other diagonal", func(p pt, ha, hb int) pt { return pt{hb - p.b, ha - p.a} }, true},
	{"turn 90", func(p pt, ha, hb int) pt { return pt{p.b, ha - p.a} }, true},
	{"turn 270", func(p pt, ha, hb int) pt { return pt{hb - p.b, p.a} }, true},
}

@ @<Functions@>=
func shapeKind(ps []pt) string {
	set := map[pt]bool{}
	for _, p := range ps {
		set[p] = true
	}
	loA, hiA, loB, hiB := span(ps)
	ha, hb := loA+hiA, loB+hiB
	var got []string
	for _, t := range shapeMaps {
		@<Try this map on the shape@>
	}
	return strings.Join(got, ", ")
}

@ @<Try this map on the shape@>=
if t.sq && hiA-loA != hiB-loB {
	continue
}
ok := true
for p := range set {
	if !set[t.f(p, ha, hb)] {
		ok = false
		break
	}
}
if ok {
	got = append(got, t.name)
}

@ @<Functions@>=
func span(ps []pt) (loA, hiA, loB, hiB int) {
	loA, hiA, loB, hiB = 1<<30, -(1 << 30), 1<<30, -(1 << 30)
	for _, p := range ps {
		if p.a < loA {
			loA = p.a
		}
		if p.a > hiA {
			hiA = p.a
		}
		if p.b < loB {
			loB = p.b
		}
		if p.b > hiB {
			hiB = p.b
		}
	}
	return
}

@ There is a narrower question one can ask instead: is the shape symmetric
about the horizontal or the vertical axis {\it of the box\/}? That is what one
sees when the output is drawn inside a fixed frame, and it turns out to be what
answer 305 counts in part~(a).

@<Functions@>=
func (w prob) frameSym(ps []pt) bool {
	set := map[pt]bool{}
	for _, p := range ps {
		set[p] = true
	}
	for _, t := range w.x.group()[1:3] {
		ok := true
		for p := range set {
			if !set[t.f(p)] {
				ok = false
				break
			}
		}
		if ok {
			return true
		}
	}
	return false
}

@ @<Functions@>=
func spans(ps []pt, m, n int) bool {
	loA, hiA, loB, hiB := span(ps)
	return (hiA-loA)/2+1 <= m && (hiB-loB)/2+1 <= n
}

@ @<Functions@>=
func grid(x box, sol []piece) string {
	on := map[pt]bool{}
	for _, p := range bigs(sol) {
		on[p] = true
	}
	s := ""
	for a := 1; a < 2*x.m; a += 2 {
		s += "      "
		for b := 1; b < 2*x.n; b += 2 {
			if on[pt{a, b}] {
				s += "#"
			} else {
				s += "."
			}
		}
		s += "\n"
	}
	return s
}

@* The five parts of exercise 305.
Part~(a) uses a $5\times5$ box and asks that the small squares of every option
be one of $\{34,45\}$, $\{47,56\}$, $\{76,65\}$ or $\{63,54\}$ --- the four
blades of a windmill turning about the middle of the box. Only four pieces are
used, so the piece items are secondary; the eight small squares are the primary
ones, and the large squares merely have to avoid each other.

Parts~(b) and~(c) fill a box with all ten pieces: large squares primary, small
squares secondary and confined to the box.

Parts~(d) and~(e) turn that upside down. The upper layer has to fill a tilted
rectangle exactly, so those twenty small squares are primary; the large squares
only have to keep out of each other's way, inside a box big enough to hold them.

@<Functions@>=
func rect(c pt, i, j int) map[pt]bool {
	out := map[pt]bool{}
	for u := 0; u <= i; u++ {
		for v := 0; v <= j; v++ {
			out[pt{c.a + u + v, c.b - u + v}] = true
		}
	}
	return out
}

@ @<Functions@>=
func part(which string) prob {
	switch which {
	case "a":
		@<Set up the windmill of part (a)@>
	case "b":
		return prob{x: box{4, 5}, piecesPrim: true, largePrim: true}
	case "c":
		return prob{x: box{2, 10}, piecesPrim: true, largePrim: true}
	case "d":
		return prob{x: box{7, 7}, smallPrim: rect(pt{4, 7}, 3, 4), piecesPrim: true}
	case "e8":
		return prob{x: box{8, 8}, smallPrim: rect(pt{3, 4}, 1, 9), piecesPrim: true}
	case "e9":
		return prob{x: box{9, 9}, smallPrim: rect(pt{4, 5}, 1, 9), piecesPrim: true}
	}
	panic("no such part")
}

@ @<Set up the windmill of part (a)@>=
w := prob{x: box{5, 5}, smallPrim: map[pt]bool{}, pairs: map[[2]pt]bool{}}
for _, q := range [][2]pt{
	{{3, 4}, {4, 5}}, {{4, 7}, {5, 6}}, {{7, 6}, {6, 5}}, {{6, 3}, {5, 4}},
} {
	w.pairs[pairKey(q[0], q[1])] = true
	w.smallPrim[q[0]] = true
	w.smallPrim[q[1]] = true
}
return w

@ @<Functions@>=
func report(which string, verbose bool) {
	w := part(which)
	in, all := w.build()
	@<Say how big the problem is@>
	sym := w.symmetries(all)
	g := len(sym)
	@<Count the solutions and sort them by symmetry@>
	@<Say what the counts came to@>
}

@ @<Say how big the problem is@>=
nopt := 0
for i, l := range all {
	nopt += len(l)
	if verbose {
		fmt.Printf("  piece %d: %d options\n", i, len(l))
	}
}
sym0 := w.symmetries(all)
var names []string
for _, t := range sym0 {
	names = append(names, t.name)
}
fmt.Printf("part (%s): %dx%d box, %d options, symmetries %v\n",
	which, w.x.m, w.x.n, nopt, names)

@ @<Count the solutions and sort them by symmetry@>=
t0 := time.Now()
xc := cells.NewXCC()
total := 0
stab := map[int]int{}
var bigSym, bigMirror, smallSym, smallAsym, bigFrame, fitting tally
shapes := map[string]int{}
for s := range xc.Dance(strings.NewReader(in)).Solutions {
	sol := parse(s)
	total++
	@<Work out the stabilizer of this arrangement@>
	@<Tally what its two layers look like@>
}
el := time.Since(t0).Round(time.Millisecond)

@ @<Work out the stabilizer of this arrangement@>=
k := skey(sol)
fix := 0
for _, t := range sym {
	var moved []piece
	for _, q := range sol {
		moved = append(moved, t.on(q))
	}
	if skey(moved) == k {
		fix++
	}
}
stab[fix]++

@ @<Tally what its two layers look like@>=
if bk := shapeKind(bigs(sol)); bk != "" {
	bigSym.add(fix)
	shapes[bk]++
	if strings.Contains(bk, "mirror") {
		bigMirror.add(fix)
	}
}
if w.frameSym(bigs(sol)) {
	bigFrame.add(fix)
}
if shapeKind(smalls(sol)) != "" {
	smallSym.add(fix)
	if fix == 1 {
		smallAsym.add(fix)
	}
}
if spans(bigs(sol), 5, 5) {
	fitting.add(fix)
}

@ @<Say what the counts came to@>=
fmt.Printf("  %d solutions, %d nodes, %s\n", total, xc.Nodes(), el)
for f := 1; f <= g; f++ {
	if stab[f] > 0 {
		fmt.Printf("  stabilizer of order %d: %d arrangements = %d classes of %d\n",
			f, stab[f], stab[f]*f/g, g/f)
	}
}
fmt.Printf("  large squares form a symmetric shape: %d arrangements, %d classes"+
	" (%d with a mirror, %d about an axis of the box)\n",
	bigSym.sols, bigSym.classes(g), bigMirror.classes(g), bigFrame.classes(g))
fmt.Printf("  small squares form a symmetric shape: %d arrangements, %d classes"+
	" (%d of them asymmetric)\n",
	smallSym.sols, smallSym.classes(g), smallAsym.classes(g))
if which == "d" {
	fmt.Printf("  large squares fit a 5x5 box: %d arrangements, %d classes\n",
		fitting.sols, fitting.classes(g))
}
for k, v := range shapes {
	fmt.Printf("     large shape fixed by {%s}: %d arrangements\n", k, v)
}

@ Answer 305 says that $2\cdot3$ of the arrangements of part~(d) ``have large
squares that form the symmetric shape shown''. To find which shape that is, one
has to count the arrangements per shape, and the picture in the book has to be
read.

@<List the shapes the large squares make@>=
w := part("d")
in, _ := w.build()
xc := cells.NewXCC()
count := map[string]int{}
kind := map[string]string{}
for s := range xc.Dance(strings.NewReader(in)).Solutions {
	sol := parse(s)
	g := trim(grid(w.x, sol))
	count[g]++
	kind[g] = shapeKind(bigs(sol))
}
@<Print the shapes that are symmetric@>

@ @<Print the shapes that are symmetric@>=
var keys []string
for k := range count {
	if kind[k] != "" {
		keys = append(keys, k)
	}
}
sort.Strings(keys)
fmt.Printf("%d distinct shapes in all, %d of them symmetric\n",
	len(count), len(keys))
for _, k := range keys {
	fmt.Printf("  %d arrangements [%s]:\n%s", count[k], kind[k], k)
}

@ @<Functions@>=
func trim(g string) string {
	lines := strings.Split(strings.TrimRight(g, "\n"), "\n")
	for len(lines) > 0 && strings.Trim(lines[0], " .") == "" {
		lines = lines[1:]
	}
	for len(lines) > 0 && strings.Trim(lines[len(lines)-1], " .") == "" {
		lines = lines[:len(lines)-1]
	}
	return strings.Join(lines, "\n") + "\n"
}

@* Two snakes at once.
Exercise 306 asks in how many ways the ten windmill dominoes can be arranged so
that the twenty large squares define a snake-in-the-box cycle and so do the
twenty small ones. A snake-in-the-box cycle, by exercise 172(b), is a set of
vertices whose induced subgraph is a single cycle: every chosen vertex has
exactly two chosen neighbours, and the whole is connected.

Answer 306 writes this as one big problem for Algorithm~M, with an item that
decides each square, an item that gives it two neighbours, and items of
multiplicity $[0\,.\,.\,3]$ to forbid a bare 4-cycle; it warns that nonsharp
branching is needed. I could not get that to finish, so this program takes the
structure apart instead.

The key is that an induced cycle has no chords. So two large squares that share
an edge and both lie on the cycle are neighbours {\it along\/} the cycle, and
the ten large dominoes are therefore a perfect matching of a 20-cycle---of
which there are exactly two. The same argument applies to the upper layer. That
turns the problem into: choose the cycle, choose one of its two matchings, and
hang a small domino on each large one.

@ Choosing the cycle is itself an exact cover problem, and a small one. Each
cell of the box is either empty or has exactly two chosen neighbours; an item
of multiplicity $[20\,.\,.\,20]$ counts the chosen ones; and the four cells
around a lattice point carry an item of multiplicity $[0\,.\,.\,3]$, which is
answer 306's own device for forbidding a 4-cycle. Connectivity an exact cover
cannot say, so it is checked afterwards.

@<Functions@>=
func cycleModel(x box, want int) string {
	var prim, sec []string
	var b strings.Builder
	@<Name the items of the cycle problem@>
	b.WriteString(strings.Join(prim, " ") + " | " + strings.Join(sec, " ") + "\n")
	for a := 1; a < 2*x.m; a += 2 {
		for c := 1; c < 2*x.n; c += 2 {
			@<Write the options for cell (a,c)@>
		}
	}
	return b.String()
}

@ @<Name the items of the cycle problem@>=
for a := 1; a < 2*x.m; a += 2 {
	for c := 1; c < 2*x.n; c += 2 {
		prim = append(prim, "c"+sq(pt{a, c}))
		sec = append(sec, "v"+sq(pt{a, c}))
	}
}
for a := 2; a < 2*x.m-1; a += 2 {
	for c := 2; c < 2*x.n-1; c += 2 {
		prim = append(prim, "0:3|B"+sq(pt{a, c}))
	}
}
prim = append(prim, fmt.Sprintf("%d|N", want))

@ @<Write the options for cell (a,c)@>=
p := pt{a, c}
fmt.Fprintf(&b, "c%s v%s:0\n", sq(p), sq(p))
var nb []pt
for _, d := range bigSteps {
	if q := (pt{p.a + d.a, p.b + d.b}); x.insideLarge(q) {
		nb = append(nb, q)
	}
}
var caps string
for _, d := range []pt{{-1, -1}, {-1, 1}, {1, -1}, {1, 1}} {
	q := pt{p.a + d.a, p.b + d.b}
	if 1 < q.a && q.a < 2*x.m-1 && 1 < q.b && q.b < 2*x.n-1 {
		caps += " B" + sq(q)
	}
}
@<Write one option per choice of two neighbours@>

@ @<Write one option per choice of two neighbours@>=
for i := 0; i < len(nb); i++ {
	for j := i + 1; j < len(nb); j++ {
		fmt.Fprintf(&b, "c%s v%s:1 N", sq(p), sq(p))
		for k, q := range nb {
			col := "0"
			if k == i || k == j {
				col = "1"
			}
			fmt.Fprintf(&b, " v%s:%s", sq(q), col)
		}
		b.WriteString(caps + "\n")
	}
}

@ @<Functions@>=
func snakeCycles(x box, want int) [][]pt {
	mc := cells.NewMCC()
	var out [][]pt
	for s := range mc.Dance(strings.NewReader(cycleModel(x, want))).Solutions {
		var on []pt
		for _, o := range s {
			for _, t := range o {
				if strings.HasPrefix(t, "v") && strings.HasSuffix(t, ":1") {
					on = append(on, unsq(t[1:len(t)-2]))
				}
			}
		}
		@<Keep this one if it is a single cycle filling the box@>
	}
	return out
}

@ The cells come back once per option that mentions them, so they need weeding;
and the bounding box has to be the whole box, or the same shape would be found
again in a larger one.

@<Keep this one if it is a single cycle filling the box@>=
on = unique(on)
if len(on) != want || !oneComponent(on, bigSteps) {
	continue
}
loA, hiA, loB, hiB := span(on)
if loA != 1 || hiA != 2*x.m-1 || loB != 1 || hiB != 2*x.n-1 {
	continue
}
out = append(out, on)

@ @<Functions@>=
func unique(ps []pt) []pt {
	seen := map[pt]bool{}
	var out []pt
	for _, p := range ps {
		if !seen[p] {
			seen[p] = true
			out = append(out, p)
		}
	}
	sort.Slice(out, func(i, j int) bool { return ahead(out[i], out[j]) })
	return out
}

@ @<Functions@>=
func oneComponent(ps []pt, steps []pt) bool {
	set := map[pt]bool{}
	for _, p := range ps {
		set[p] = true
	}
	seen := map[pt]bool{ps[0]: true}
	queue := []pt{ps[0]}
	for len(queue) > 0 {
		p := queue[0]
		queue = queue[1:]
		for _, d := range steps {
			if q := (pt{p.a + d.a, p.b + d.b}); set[q] && !seen[q] {
				seen[q] = true
				queue = append(queue, q)
			}
		}
	}
	return len(seen) == len(set)
}

@* Perfect matchings.
Walking round a cycle is easy when every vertex has exactly two neighbours in
it: step to whichever neighbour has not been visited.

@<Functions@>=
func ringOf(ps []pt, steps []pt) []pt {
	set := map[pt]bool{}
	for _, p := range ps {
		set[p] = true
	}
	out, seen := []pt{ps[0]}, map[pt]bool{ps[0]: true}
	for len(out) < len(ps) {
		cur, moved := out[len(out)-1], false
		for _, d := range steps {
			if q := (pt{cur.a + d.a, cur.b + d.b}); set[q] && !seen[q] {
				seen[q] = true
				out = append(out, q)
				moved = true
				break
			}
		}
		if !moved {
			return out
		}
	}
	return out
}

@ A cycle of even length has two perfect matchings: take every other edge,
starting at one end of an edge or at the other.

@<Functions@>=
func matchings(ps []pt) [][][2]pt {
	ring := ringOf(ps, bigSteps)
	var out [][][2]pt
	for off := 0; off < 2; off++ {
		var m [][2]pt
		for k := off; k < off+len(ring); k += 2 {
			u, v := ring[k%len(ring)], ring[(k+1)%len(ring)]
			if ahead(v, u) {
				u, v = v, u
			}
			m = append(m, [2]pt{u, v})
		}
		out = append(out, m)
	}
	return out
}

@ An attachment says which of the ten pieces a large domino becomes when a
small domino is glued to it, and where that small domino lies relative to the
domino's first square. The step from the first large square to the second is
the only thing that tells the two orientations apart, so the attachments are
indexed by it: twenty for each.

@<Declarations@>=
type attach struct {
	piece int
	small [2]pt
}

@ @<Functions@>=
func glue() map[pt][]attach {
	out := map[pt][]attach{}
	for i, q := range pieces() {
		r := q.tidy()
		for turn := 0; turn < 4; turn++ {
			s := r.sorted()
			d := pt{s.big[1].a - s.big[0].a, s.big[1].b - s.big[0].b}
			out[d] = append(out[d], attach{i, [2]pt{
				{s.small[0].a - s.big[0].a, s.small[0].b - s.big[0].b},
				{s.small[1].a - s.big[0].a, s.small[1].b - s.big[0].b},
			}})
			r = r.turn()
		}
	}
	return out
}

@* Walking the dominoes.
With the lower layer settled, what is left is to give each large domino a small
one: ten choices out of twenty apiece, with the ten pieces all different and
the upper layer growing into a cycle. Two prunings make this quick. A small
square may never have three neighbours. And a square that no later domino can
reach will never gain another neighbour, so it must have two already; a cycle
that closes before all twenty squares are down can never take in the rest.

@<Declarations@>=
type walk struct {
	dom   [][2]pt
	gl    map[pt][]attach
	reach []map[pt]bool
	used  [10]bool
	deg   map[pt]int
	edges int
	small []pt
	sol   []piece
	found [][]piece
	loose bool
}

@ @<Declarations@>=
type edge struct{ u, v pt }

@ @<Functions@>=
func (w *walk) run(k int) {
	if k == len(w.dom) {
		@<Keep the arrangement if the upper layer will do@>
		return
	}
	d := w.dom[k]
	step := pt{d[1].a - d[0].a, d[1].b - d[0].b}
	for _, at := range w.gl[step] {
		@<Try this attachment on domino k@>
	}
}

@ @<Keep the arrangement if the upper layer will do@>=
for _, p := range w.small {
	if w.deg[p] != 2 {
		return
	}
}
if w.loose || oneComponent(w.small, smallSteps) {
	w.found = append(w.found, append([]piece(nil), w.sol...))
}

@ @<Try this attachment on domino k@>=
if w.used[at.piece] {
	continue
}
s0 := pt{d[0].a + at.small[0].a, d[0].b + at.small[0].b}
s1 := pt{d[0].a + at.small[1].a, d[0].b + at.small[1].b}
if _, on := w.deg[s0]; on {
	continue
}
if _, on := w.deg[s1]; on {
	continue
}
added, ok := w.place(s0, s1)
if ok && w.promising(k+1) {
	w.used[at.piece] = true
	w.sol = append(w.sol, piece{big: d, small: [2]pt{s0, s1}})
	w.run(k + 1)
	w.sol = w.sol[:len(w.sol)-1]
	w.used[at.piece] = false
}
w.unplace(s0, s1, added)

@ The two small squares of a piece are diagonal neighbours, so the piece brings
an edge of the upper layer's cycle with it. That edge has to be counted once,
not twice---a mistake that makes every branch die at once, since both squares
would reach degree two the moment they are put down.

@<Functions@>=
func (w *walk) place(s0, s1 pt) ([]edge, bool) {
	w.deg[s0], w.deg[s1] = 0, 0
	w.small = append(w.small, s0, s1)
	var added []edge
	for _, s := range []pt{s0, s1} {
		for _, t := range smallSteps {
			n := pt{s.a + t.a, s.b + t.b}
			if _, on := w.deg[n]; !on || (s == s1 && n == s0) {
				continue
			}
			added = append(added, edge{s, n})
		}
	}
	@<Add the edges and see whether anything is crowded@>
}

@ @<Add the edges and see whether anything is crowded@>=
ok := true
for _, e := range added {
	w.deg[e.u]++
	w.deg[e.v]++
	w.edges++
	if w.deg[e.u] > 2 || w.deg[e.v] > 2 {
		ok = false
	}
}
return added, ok

@ @<Functions@>=
func (w *walk) unplace(s0, s1 pt, added []edge) {
	for _, e := range added {
		w.deg[e.u]--
		w.deg[e.v]--
		w.edges--
	}
	delete(w.deg, s0)
	delete(w.deg, s1)
	w.small = w.small[:len(w.small)-2]
}

@ @<Functions@>=
func (w *walk) promising(next int) bool {
	if w.edges >= len(w.small) && len(w.small) < 2*len(w.dom) {
		return false
	}
	left := w.reach[next]
	for _, s := range w.small {
		if w.deg[s] == 2 {
			continue
		}
		@<Give up unless a later domino can still reach a neighbour of s@>
	}
	return true
}

@ It is the {\it neighbouring\/} squares that must still be free, not the
square itself: the square is already down, so of course no later domino can put
anything there.

@<Give up unless a later domino can still reach a neighbour of s@>=
room := false
for _, t := range smallSteps {
	n := pt{s.a + t.a, s.b + t.b}
	if _, on := w.deg[n]; on || !left[n] {
		continue
	}
	room = true
	break
}
if !room {
	return false
}

@ @<Functions@>=
func solveCycle(cs []pt, gl map[pt][]attach, loose bool) [][]piece {
	var out [][]piece
	for _, m := range matchings(cs) {
		@<Work out what the dominoes from k onwards can still touch@>
		w := &walk{dom: m, gl: gl, reach: reach, deg: map[pt]int{}, loose: loose}
		w.run(0)
		out = append(out, w.found...)
	}
	return out
}

@ @<Work out what the dominoes from k onwards can still touch@>=
reach := make([]map[pt]bool, len(m)+1)
reach[len(m)] = map[pt]bool{}
for k := len(m) - 1; k >= 0; k-- {
	r := map[pt]bool{}
	for p := range reach[k+1] {
		r[p] = true
	}
	step := pt{m[k][1].a - m[k][0].a, m[k][1].b - m[k][0].b}
	for _, at := range gl[step] {
		for _, s := range at.small {
			r[pt{m[k][0].a + s.a, m[k][0].b + s.b}] = true
		}
	}
	reach[k] = r
}

@* What answer 306 counts.
Every snake-in-the-box cycle of twenty large squares fits in a box of size
$3\times9$, $4\times8$, $5\times7$ or $6\times6$, and answer 306 reports
$(0,0,4\cdot9,8\cdot8)$ solutions in those four cases. Those are what Algorithm~M
finds, and Algorithm~M is not told about connectivity: six of the eight
$6\times6$ classes are spurious, their small squares making an 8-cycle and a
12-cycle rather than one cycle of twenty. So the counts have to be taken two
ways---as answer 306's model would take them, and with connectivity insisted
on.

Answer 306's model forbids two things this program's search does not. Its
multiplicity items rule out a 4-cycle. And its items exist only for
$0<x<2n$, $0<y<2m$, so the upper layer may not stick out of the box. Both have
to be imposed to reproduce its numbers.

@<Do exercise 306@>=
gl := glue()
genuine := 0
for _, x := range []box{{3, 9}, {4, 8}, {5, 7}, {6, 6}} {
	t0 := time.Now()
	cs := snakeCycles(x, 20)
	@<Pave every cycle and sort the arrangements out@>
	genuine += classesOf(tight, x.group())
	@<Report this box size@>
}
fmt.Printf("essentially different solutions altogether: %d\n", genuine)

@ @<Pave every cycle and sort the arrangements out@>=
var loose, tight, asKnuth [][]piece
for _, c := range cs {
	for _, sol := range solveCycle(c, gl, true) {
		loose = append(loose, sol)
		if oneComponent(smalls(sol), smallSteps) {
			tight = append(tight, sol)
		}
		if !hasFourCycle(sol) && !sticksOut(sol, x) {
			asKnuth = append(asKnuth, sol)
		}
	}
}

@ @<Functions@>=
func hasFourCycle(sol []piece) bool {
	for _, n := range cycleSizes(smalls(sol), smallSteps) {
		if n == 4 {
			return true
		}
	}
	return false
}

@ @<Functions@>=
func sticksOut(sol []piece, x box) bool {
	for _, p := range smalls(sol) {
		if outside(p, x) {
			return true
		}
	}
	return false
}

@ @<Functions@>=
func cycleSizes(ps []pt, steps []pt) []int {
	set := map[pt]bool{}
	for _, p := range ps {
		set[p] = true
	}
	seen := map[pt]bool{}
	var out []int
	for _, p := range ps {
		if seen[p] {
			continue
		}
		@<Measure the component containing p@>
	}
	sort.Ints(out)
	return out
}

@ @<Measure the component containing p@>=
n, queue := 0, []pt{p}
seen[p] = true
for len(queue) > 0 {
	q := queue[0]
	queue = queue[1:]
	n++
	for _, t := range steps {
		if r := (pt{q.a + t.a, q.b + t.b}); set[r] && !seen[r] {
			seen[r] = true
			queue = append(queue, r)
		}
	}
}
out = append(out, n)

@ @<Functions@>=
func classesOf(sols [][]piece, g []xform) int {
	seen := map[string]bool{}
	n := 0
	for _, s := range sols {
		if seen[skey(s)] {
			continue
		}
		n++
		for _, t := range g {
			var m []piece
			for _, q := range s {
				m = append(m, t.on(q))
			}
			seen[skey(m)] = true
		}
	}
	return n
}

@ Answer 306 also remarks in passing that two of the large squares may touch at
a corner, and that five of the eleven solutions do not have this ``defect''.
Every induced cycle turns corners, and at every turn two of its cells touch
diagonally; what is meant must be a corner contact between cells that are
{\it not\/} two steps apart round the cycle, where the ring doubles back and
pinches itself.

@<Functions@>=
func pinches(sol []piece) bool {
	ring := ringOf(bigs(sol), bigSteps)
	pos := map[pt]int{}
	for i, p := range ring {
		pos[p] = i
	}
	for i, p := range ring {
		@<Look for a corner contact from far round the ring@>
	}
	return false
}

@ @<Look for a corner contact from far round the ring@>=
for _, d := range []pt{{2, 2}, {2, -2}} {
	j, on := pos[pt{p.a + d.a, p.b + d.b}]
	if !on {
		continue
	}
	gap := i - j
	if gap < 0 {
		gap = -gap
	}
	if gap > len(ring)-gap {
		gap = len(ring) - gap
	}
	if gap > 2 {
		return true
	}
}

@ @<Report this box size@>=
g := x.group()
fmt.Printf("%dx%d: %d snake-in-the-box 20-cycles fill the box\n", x.m, x.n, len(cs))
fmt.Printf("   as answer 306 counts them (no 4-cycle, upper layer inside):"+
	" %d arrangements, %d classes\n", len(asKnuth), classesOf(asKnuth, g))
@<Say which of those are spurious@>
fmt.Printf("   one cycle in both layers: %d arrangements, %d classes (%s)\n",
	len(tight), classesOf(tight, g), time.Since(t0).Round(time.Millisecond))
@<Say how many of the genuine ones pinch@>

@ @<Say which of those are spurious@>=
bad := map[string][][]piece{}
for _, sol := range asKnuth {
	if oneComponent(smalls(sol), smallSteps) {
		continue
	}
	k := fmt.Sprint(cycleSizes(smalls(sol), smallSteps))
	bad[k] = append(bad[k], sol)
}
for k, l := range bad {
	fmt.Printf("      of which %d arrangements, %d classes are spurious:"+
		" the upper layer is %s\n", len(l), classesOf(l, g), k)
}

@ @<Say how many of the genuine ones pinch@>=
var yes, no [][]piece
for _, sol := range tight {
	if pinches(sol) {
		yes = append(yes, sol)
	} else {
		no = append(no, sol)
	}
}
if len(tight) > 0 {
	fmt.Printf("      %d classes pinch, %d do not\n",
		classesOf(yes, g), classesOf(no, g))
}

@* Index.
