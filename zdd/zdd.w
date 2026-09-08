\def\title{Dancing Cells and ZDDs}

@s Func int
@s ZDD int
@s Int int
@s Seq int
@s Rand int
@s Reader int
@s Builder int
@s Option int

@** Introduction.
The three engines of the |dcells| package hand back solutions one at a time.
That is the right shape for a puzzle with a hundred answers, and the wrong
shape for one with $10^{16}$: you cannot look at them, you cannot count them
by looking at them, and you certainly cannot pick the best one out by looking
at them. This program answers such questions without ever writing a solution
down. It reads the same {\tt DLX} input the others read, and returns a {\it
ZDD\/}---a zero-suppressed decision diagram whose paths are exactly the exact
covers.

Two ideas make it work, and they are not ours. The first is due to Masaaki
Nishino, Norihito Yasuda, Shin-ichi Minato, and Masaaki Nagata, whose
``Dancing with decision diagrams'' [{\sl AAAI\/ \bf31} (2017), 868--874]
observed that the subproblem left after some options have been chosen depends
only on {\it which items remain}, never on the order they were chosen in ---
so a search that remembers the subproblems it has solved need never solve one
twice. Knuth built that into {\tt DLX6}, extending it to colors. The second
idea is that the answer to a subproblem is not a number but a {\it family of
sets}, and families of sets are what ZDDs are for. Our ZDDs come from the
|bdd| package (\.{github.com/sjnam/bdd}), a Go rendering of Knuth's
{\tt BDD15}---so the two halves of this story, {\sl TAOCP\/} 7.2.2.1 and
7.1.4, meet in one program.

@ Whether that pays is a property of the problem, not of the engine, and it is
worth being blunt about it before anyone reaches for this program. Here is
what the memo cache saves, measured as search nodes with the cache against
search nodes without it:
$$\vbox{\halign{\hfil\tt#\quad&\hfil#\hfil\quad&\hfil#\hfil\quad&\hfil#\cr
\omit\hfil{\rm problem}\hfil&\omit{\rm solutions}\hfil&
   \omit{\rm nodes, cached}\hfil&\omit{\rm saving}\hfil\cr
\noalign{\smallskip\hrule\smallskip}
domino 8$\times$8&12{,}988{,}816&2{,}317&21{,}600$\times$\cr
domino 10$\times$10&258{,}584{,}046{,}368&13{,}562&$7.4\times10^7$\cr
domino 12$\times$12&$5.3\times10^{16}$&74{,}049&$2.8\times10^{12}$\cr
pentominoes 6$\times$10&9{,}356&2{,}243{,}002&1.6$\times$\cr
langford 11&17{,}792&162{,}544&1.4$\times$\cr
8 queens&92&1{,}122&1.1$\times$\cr}}$$
The rule behind those numbers is simple: the cache wins by exactly the factor
by which the number of solutions exceeds the number of {\it distinct
subproblems}. Tilings of a regular region decompose into small independent
pieces and have astronomically many solutions, so almost every subproblem
recurs. The twelve pentominoes are all different, so almost no subproblem
recurs, and paying for a cache of 700{,}000 signatures to save a factor of 1.6
is a bad bargain. Use the other engines for those.

@ What you get in exchange for building the diagram is the ability to ask
things afterwards. Counting is a walk over the DAG, so $5.3\times10^{16}$
tilings are counted in a fraction of a second; picking the heaviest solution
under any weights is another walk, and finds the best of $2.6\times10^{11}$
tilings in under a millisecond; a uniformly random solution is a third. None
of those is possible by enumeration. This package hands back the diagram along
with the |bdd| handle, so anything that package can do---union with another
family, restriction, reordering to shrink the diagram---is available too.
@c
// Package zdd represents all solutions of an exact cover problem as a ZDD.
package zdd

import (
	"bufio"
	"fmt"
	"io"
	"iter"
	"math/big"
	"math/rand/v2"
	"os"
	"strings"

	"github.com/sjnam/bdd"
	cells "github.com/sjnam/dancing-cells"
)

@<The solver@>
@<The diagram@>
@<The input phase@>

@** Signatures.
Everything turns on deciding when two search states are the same state. Knuth's
answer, which is also ours, is a {\it signature}: a canonical rendering of the
part of the state that the future depends on.

An option survives in the current subproblem if and only if it contains no
covered primary item and agrees with every purified secondary item on its
color. That is a statement about items alone---the chosen options do not
appear in it---so the surviving options are a function of the item state, and
the item state is all the signature needs to record. Two branches that arrive
at the same item state have the same set of surviving options, hence the same
family of solutions, and one may be answered out of the other's memo.

@ Three kinds of item go into it.

An {\it active primary\/} item is recorded by its number. An {\it active
secondary\/} item is recorded too, but only while some surviving option still
mentions it: once its set is empty it can never constrain anything again, and
recording it would split states that are really the same. The sparse sets give
that test away for free, since |size(x)| is the number of surviving options
of~|x|.

A {\it purified\/} secondary item is the subtle one. It is no longer active ---
this engine, like {\tt SSXCC}, retires an item the moment an option commits to
it---but the color it was purified to still rules out options, so it must
appear in the signature, with its color. An item covered without a color needs
no entry: nothing may use it again, which is the same as saying it is gone.

@ The rendering must be canonical, and the obvious way to write it down is not:
the sparse sets permute |item| as the search runs, so two identical states can
present their items in different orders. We therefore walk the item {\it
numbers\/} in order, from~1 to |itemlen|, and look each one up---which is what
|itemBase| is for. Each entry becomes a varint: |2i| for an item that is merely
present, and |2i+1| followed by the color for a purified one.
@<Building the signature@>=
func (s *Solver) signature() string {
	s.sig = s.sig[:0]
	for i := 1; i <= s.itemlen; i++ {
		x := int(s.itemBase[i])
		switch {
		case s.pos(x) < s.active:
			if x < s.second || s.size(x) > 0 {
				s.sig = varint(s.sig, 2*i)
			}
		case x >= s.second && s.clr[i] != 0:
			s.sig = varint(s.sig, 2*i+1)
			s.sig = varint(s.sig, int(s.clr[i]))
		}
	}
	return string(s.sig)
}

func varint(b []byte, v int) []byte {
	for v >= 0x80 {
		b = append(b, byte(v)|0x80)
		v >>= 7
	}
	return append(b, byte(v))
}

@** The engine.
The dance is {\tt SSXCC}'s, with the branching and the covering unchanged: pick
the primary item with the fewest surviving options, retire it, and try each of
its options in turn. Only the ends differ. Where {\tt SSXCC} sends a solution
down a channel, this engine returns the ZDD |Unit|---the family whose one
member is the empty set of further options---and where {\tt SSXCC} loops over
options for their side effects, this one collects what they return.

The force stack is gone. {\tt SSXCC} keeps one so that an item down to a single
option can be taken without saving anybody's sizes; here it would only muddy
the signature's story, and the memo cache subsumes most of what it was buying.
@<The solver@>=
@<Constants@>
@<The solver state@>
@<Creating a solver@>
@<Set accessors@>
@<Interning@>
@<Building the signature@>
@<Launching the dance@>
@<The search@>
@<Choosing the item@>
@<Committing an option@>
@<Hiding conflicting options@>
@<Covering an item@>
@<The undo machinery@>
@<Reporting an option@>

@ @<Constants@>=
const (
	zExtra      = 4       // set entries reserved below each item's base
	zIprop      = 4       // input-phase slot spacing
	infSize     = 1 << 30 // "no item to branch on" => a solution
	secondUnset = 1 << 30 // sentinel for "no primary/secondary boundary yet"
)

type node struct {
	itm, loc, clr int32
}

type twoints struct {
	l, r int32
}

@* State and construction.
A |Solver| carries one computation. Besides the matrix arrays it owns the
option numbering---every option gets a number, which is its element in the
ZDD---the color slots the signature reads, and the memo cache itself.
@<The solver state@>=
type Solver struct {
	Debug bool // print an input summary and final tallies to stderr
	MRV   bool // branch on the fewest-options item; |New| turns it on

	@<The matrix arrays@>
	@<Naming tables@>
	@<Option numbering@>
	@<The backtrack arrays@>
	@<The memo cache@>
}

@ @<The matrix arrays@>=
nd       []node
lastNode int
item     []int32
second   int
lastItm  int
set      []int32
itemlen  int
setlen   int
active   int
oactive  int
baditem  int
osecond  int
itemBase []int32 // item number -> its base in set

@ @<Naming tables@>=
names      []string
nameIndex  map[string]int
colorNames []string
colorIndex map[string]int

@ Options are numbered $1,2,\ldots$ in the order they were read; |optNo| takes
a node to the number of the option it belongs to, and |optFirst| takes a
number back to the option's first node, so that a solution read out of the
diagram can be turned into item names again. The ZDD's element $k$ is option
$k+1$, since |bdd| numbers elements from zero.
@<Option numbering@>=
options  int
optNo    []int32
optFirst []int32

@ @<The backtrack arrays@>=
saved     []int32
savestack []twoints
saveptr   int
clr       []int32 // item number -> the color it was purified to
sig       []byte  // scratch space for the signature

@ @<The memo cache@>=
z     *bdd.ZDD
memo  map[string]bdd.Func
nodes uint64
hits  uint64

@ @<Creating a solver@>=
func New() *Solver {
	return &Solver{
		MRV:        true,
		second:     secondUnset,
		names:      []string{""}, // item numbers are 1-based
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // color 0 means "no color"
		colorIndex: make(map[string]int),
	}
}

func (s *Solver) Nodes() uint64      { return s.nodes }
func (s *Solver) Hits() uint64       { return s.hits }
func (s *Solver) Signatures() int    { return len(s.memo) }

@ @<Set accessors@>=
func (s *Solver) size(x int) int   { return int(s.set[x-1]) }
func (s *Solver) pos(x int) int    { return int(s.set[x-2]) }
func (s *Solver) itemNo(x int) int { return int(s.set[x-3]) }

func (s *Solver) setSize(x, v int)   { s.set[x-1] = int32(v) }
func (s *Solver) setPos(x, v int)    { s.set[x-2] = int32(v) }
func (s *Solver) setItemNo(x, v int) { s.set[x-3] = int32(v) }

@ @<Interning@>=
func (s *Solver) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

func (s *Solver) internColor(name string) int {
	if id, ok := s.colorIndex[name]; ok {
		return id
	}
	id := len(s.colorNames)
	s.colorNames = append(s.colorNames, name)
	s.colorIndex[name] = id
	return id
}

@* The dance.
|Dance| reads the matrix, builds the diagram, and returns it. Unlike its
siblings it does not launch a goroutine: there is no stream to pace, and the
whole answer is ready when it returns. A problem with an uncoverable item, or
none at all, yields the empty family.
@<Launching the dance@>=
func (s *Solver) Dance(rd io.Reader) *Diagram {
	s.inputMatrix(rd)
	s.z = bdd.NewZDD(s.options)
	s.memo = make(map[string]bdd.Func)
	@<Report the input summary@>
	root := s.z.Empty()
	if s.baditem == 0 {
		root = s.search()
	}
	@<Report the totals@>
	return &Diagram{s: s, z: s.z, root: root}
}

@ @<Report the input summary@>=
if s.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
}

@ @<Report the totals@>=
if s.Debug {
	fmt.Fprintf(os.Stderr,
		"Altogether %s solutions, %d ZDD nodes,"+
			" %d search nodes, %d signatures, %d hits.\n",
		s.z.Count(root).String(), s.z.Size(root), s.nodes, len(s.memo), s.hits)
}

@ Here is the search. It answers with the family of all ways to finish the
current partial cover, and the first three lines are the whole idea of the
program: no primary item left means one way (choose nothing more); an item
with nothing to cover it means no ways; and a state we have seen before means
look it up.
@<The search@>=
func (s *Solver) search() bdd.Func {
	s.nodes++
	best, score := s.chooseItem()
	if score == infSize {
		return s.z.Unit()
	}
	if score == 0 {
		return s.z.Empty()
	}
	key := s.signature()
	if f, ok := s.memo[key]; ok {
		s.hits++
		return f
	}
	@<Try every option of |best| and take the union@>
	s.memo[key] = res
	return res
}

@ Covering |best| goes exactly as it does in {\tt SSXCC}: retire the item,
hide the options that can no longer be used, snapshot the sizes, and try each
candidate. What is new is the last line of the loop. The family of solutions
that {\it use\/} this option is the sub-family with the option added to every
member, which is the ZDD product |Join(Elt(o), sub)|; the family for the whole
node is the union of those over all candidates. Building it this way rather
than by making diagram nodes by hand costs a little time and buys a properly
ordered, reduced ZDD---which is more than Knuth's {\tt DLX6} produces, since
it warns that its output ``is not properly ordered, in general.''
@<Try every option of |best| and take the union@>=
res := s.z.Empty()
s.swapOut(best)
s.oactive = s.active
s.hide(best, 0, 0)
lo := s.saveptr
s.saveSizes()
hi := s.saveptr
for c := best; c < best+s.size(best); c++ {
	opt := int(s.set[c])
	if s.commitOption(opt) {
		sub := s.search()
		res = s.z.Union(res, s.z.Join(s.z.Elt(int(s.optNo[opt])-1), sub))
	}
	s.restoreSizes(lo, hi)
}

@ Ties go to the leftmost item, and that tie-break is not decoration here: it
is what makes the memo cache pay. The sparse sets permute |item| as the search
runs, so ``the first item of least size'' depends on how we got here, while
``the least-numbered item of least size'' depends only on the state. Branch on
the former and two paths to the same subproblem will explore it in two
different shapes, each spawning its own descendants and its own signatures. We
measured it: on the $4\times4$ domino board, dropping the tie-break doubles the
number of signatures, and by the $8\times8$ board it costs a factor of 500.
{\bf The branching rule must be a function of the signature.}

A size of zero cannot arise below the root---|hide| refuses to let an active
primary item starve---but the root of a problem read from a file can have one,
so it is reported rather than assumed away.
@<Choosing the item@>=
func (s *Solver) chooseItem() (best, score int) {
	score = infSize
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // secondary items are not branched on
		}
		sz := s.size(x)
		if sz == 0 {
			return x, 0
		}
		@<Keep |x| if it beats the incumbent@>
	}
	return best, score
}

@ Fewest options first is only the default. Knuth's exercise 7.2.2.1--264 asks
what happens when step Z3 takes the {\it least-numbered\/} active item instead,
and answers that the resulting diagram comes out ordered by option number.
Ours is ordered either way---|bdd| reduces as it builds, so the family fixes
the diagram and the branching rule cannot touch it---but the {\it search\/}
is a different shape, and on the tilings of a long thin region the sweep it
makes is far cheaper than the one \.{MRV} makes. Clearing |MRV| asks for it.
@<Keep |x| if it beats the incumbent@>=
if !s.MRV {
	if score == infSize || x < best {
		best, score = x, sz
	}
	continue
}
if sz < score || (sz == score && x < best) {
	best, score = x, sz
}

@* Covering and undoing.
The rest of the engine is {\tt SSXCC}'s, retold only where it differs. The
first pass over a committed option's nodes swaps its items out of the active
list, recording the color each secondary item is being purified to---that is
the |clr| entry the signature will read at deeper levels. The second pass
hides the options that now conflict.
@<Committing an option@>=
func (s *Solver) commitOption(opt int) bool {
	@<Swap the items of |opt| out of the active list@>
	@<Hide or purify each item of |opt|@>
	return true
}

@ @<Swap the items of |opt| out of the active list@>=
p := s.active
s.oactive = s.active
for q := opt + 1; q != opt; {
	c := int(s.nd[q].itm)
	if c < 0 {
		q += c
		continue
	}
	if pp := s.pos(c); pp < p {
		p--
		cc := int(s.item[p])
		s.item[p], s.item[pp] = int32(c), int32(cc)
		s.setPos(cc, pp)
		s.setPos(c, p)
		if c >= s.second {
			s.clr[s.itemNo(c)] = s.nd[q].clr
		}
	}
	q++
}
s.active = p

@ @<Hide or purify each item of |opt|@>=
for q := opt + 1; q != opt; {
	c := int(s.nd[q].itm)
	if c < 0 {
		q += c
		continue
	}
	switch {
	case c < s.second:
		if !s.hide(c, 0, 1) {
			return false
		}
	case s.pos(c) < s.oactive:
		if !s.hide(c, int(s.nd[q].clr), 1) {
			return false
		}
	}
	q++
}

@ @<Hiding conflicting options@>=
func (s *Solver) hide(c, color, check int) bool {
	for rr, end := c, c+s.size(c); rr < end; rr++ {
		tt := int(s.set[rr])
		if color != 0 && int(s.nd[tt].clr) == color {
			continue
		}
		@<Delete option |tt| from the sets of its other items@>
	}
	return true
}

@ @<Delete option |tt| from the sets of its other items@>=
for nn := tt + 1; nn != tt; {
	u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
	if u < 0 {
		nn += u
		continue
	}
	if s.pos(u) < s.oactive {
		ss := s.size(u) - 1
		if ss == 0 && check != 0 && u < s.second && s.pos(u) < s.active {
			return false
		}
		nnp := int(s.set[u+ss])
		s.setSize(u, ss)
		s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
		s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
	}
	nn++
}

@ @<Covering an item@>=
func (s *Solver) swapOut(x int) {
	p := s.active - 1
	s.active = p
	pp := s.pos(x)
	cc := int(s.item[p])
	s.item[p], s.item[pp] = int32(x), int32(cc)
	s.setPos(cc, pp)
	s.setPos(x, p)
}

@ Backtracking is Solnon's: save the sizes of the active items before a
branch and slam them back afterwards. A level remembers the stack pointer on
either side of its own save, |lo| and~|hi|; the distance between them is how
many items were active, and deeper levels push above |hi| and are undone by
being forgotten.
@<The undo machinery@>=
func (s *Solver) saveSizes() {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		x := int(s.item[p])
		s.savestack[s.saveptr+p] = twoints{int32(x), int32(s.size(x))}
	}
	s.saveptr += s.active
}

func (s *Solver) restoreSizes(lo, hi int) {
	s.saveptr = hi
	s.active = hi - lo
	for p := 0; p < s.active; p++ {
		e := s.savestack[lo+p]
		s.setSize(int(e.l), int(e.r))
	}
}

@ The diagram knows an option only by its number, so reporting one starts at
the first node the input phase recorded for it and runs to the spacer, naming
each item and appending its color where there is one.
@<Reporting an option@>=
func (s *Solver) option(o int) cells.Option {
	var opt cells.Option
	for q := int(s.optFirst[o]); s.nd[q].itm > 0; q++ {
		name := s.names[s.itemNo(int(s.nd[q].itm))]
		if c := s.nd[q].clr; c != 0 {
			name += ":" + s.colorNames[c]
		}
		opt = append(opt, name)
	}
	return opt
}

@** The diagram.
What |Dance| returns is a handle on the finished ZDD together with enough of
the solver to turn element numbers back into option names. The two fields
worth having in the open are the ones you need to leave this package with:
|ZDD| and |Root| give the |bdd| handle and the family, and everything that
package can do is then available---|Profile|, |Subsets|, |Quotient|, |SiftAll|
to shrink the diagram, union with a family from somewhere else.
@<The diagram@>=
type Diagram struct {
	s    *Solver
	z    *bdd.ZDD
	root bdd.Func
}

func (d *Diagram) ZDD() (*bdd.ZDD, bdd.Func) { return d.z, d.root }

@ The three questions worth wrapping are the three that need no knowledge of
|bdd| at all. |Count| is the one that motivates the whole program: it walks the
DAG, so the answer arrives in time proportional to the diagram rather than to
the number of solutions, and it arrives as a |big.Int| because the numbers we
are counting do not fit anywhere else. |Nodes| is the size of the diagram, and
|Options| the size of its universe.
@<The diagram@>=
func (d *Diagram) Count() *big.Int { return d.z.Count(d.root) }
func (d *Diagram) Nodes() int      { return d.z.Size(d.root) }
func (d *Diagram) Options() int    { return d.s.options }

@ An option is named the way the other engines name it, by its item names,
with a colored secondary item appearing as \.{name:color}. |Option| takes the
option numbers that come out of the diagram, which are 1-based; the ZDD's own
elements are one less.
@<The diagram@>=
func (d *Diagram) Option(o int) cells.Option { return d.s.option(o) }

func (d *Diagram) solution(elts []int) []cells.Option {
	sol := make([]cells.Option, len(elts))
	for i, e := range elts {
		sol[i] = d.s.option(e + 1)
	}
	return sol
}

@ Solutions can still be looked at one at a time when there are few enough to
look at. The sequence walks the diagram, so it costs nothing until it is
ranged over, and a caller who breaks out early pays only for what it saw.
@<The diagram@>=
func (d *Diagram) Solutions() iter.Seq[[]cells.Option] {
	return func(yield func([]cells.Option) bool) {
		for elts := range d.z.Subsets(d.root) {
			if !yield(d.solution(elts)) {
				return
			}
		}
	}
}

@ And two questions that enumeration cannot answer at all. |Random| draws a
solution uniformly at random---uniformly over all of them, however many there
are---and |MaxWeight| finds a solution of greatest total weight, given a weight
per option number. Both are walks over the DAG. The weight slice is indexed by
option number, so |w[1]| is the first option's weight and |w[0]| is ignored;
that keeps the numbering the same as |Option|'s.
@<The diagram@>=
func (d *Diagram) Random(r *rand.Rand) ([]cells.Option, bool) {
	elts, ok := d.z.Random(d.root, r)
	if !ok {
		return nil, false
	}
	return d.solution(elts), true
}

func (d *Diagram) MaxWeight(w []int) ([]cells.Option, int, bool) {
	ew := make([]int, d.s.options)
	for k := range ew {
		if k+1 < len(w) {
			ew[k] = w[k+1]
		}
	}
	elts, wt, ok := d.z.MaxWeight(d.root, ew)
	if !ok {
		return nil, 0, false
	}
	return d.solution(elts), wt, true
}

@** Reading the DLX input.
The {\tt DLX} text format is described in \.{dcells.w}. This package cannot
borrow that document's scanner, being a package of its own, so the few lines
it needs appear here; the rest of the phase is {\tt SSXCC}'s, with the option
numbering added.
@<The input phase@>=
func (s *Solver) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

@<The scanner@>
@<Item-name input@>
@<Option input@>
@<Input finalization@>

@ A malformed input is a programming error, not a runtime condition to be
nursed along, so the parser announces trouble by panicking. |nextLine| reads
one line into a NUL-terminated buffer, so that scanning one byte past the
content stays in bounds; |token| lifts the next word, stopping at whitespace,
the NUL, or---when |stopColon| is set---a colon.
@<The scanner@>=
type parseError struct{ msg string }

func (e *parseError) Error() string { return e.msg }

func failf(format string, a ...any) {
	panic(&parseError{fmt.Sprintf(format, a...)})
}

func isspace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
}

func nextLine(br *bufio.Reader) (buf []byte, ok bool) {
	str, err := br.ReadString('\n')
	if len(str) == 0 && err != nil {
		return nil, false
	}
	buf = make([]byte, len(str)+1)
	copy(buf, str)
	return buf, true
}

@ @<The scanner@>=
func skipSpace(buf []byte, p int) int {
	for isspace(buf[p]) {
		p++
	}
	return p
}

func token(buf []byte, p int, stopColon bool) (string, int) {
	start := p
	for buf[p] != 0 && !isspace(buf[p]) && !(stopColon && buf[p] == ':') {
		p++
	}
	return string(buf[start:p]), p
}

func ensure[T any](s []T, n int) []T {
	if n <= len(s) {
		return s
	}
	if n <= cap(s) {
		return s[:n]
	}
	t := make([]T, n, max(cap(s)*2, n, 64))
	copy(t, s)
	return t
}

@ @<Item-name input@>=
func (s *Solver) readItemNames(br *bufio.Reader) {
	@<Find the item line@>
	for buf[p] != 0 {
		name, next := token(buf, p, false)
		if name == "|" {
			if s.second != secondUnset {
				failf("item name line contains | twice")
			}
			s.second = len(s.names)
		} else {
			if strings.ContainsAny(name, ":|") {
				failf("illegal character in item name: %q", name)
			}
			if _, ok := s.internName(name); !ok {
				failf("duplicate item name: %s", name)
			}
		}
		p = skipSpace(buf, next)
	}
	s.lastItm = len(s.names)
}

@ @<Find the item line@>=
var buf []byte
var p int
found := false
for {
	var ok bool
	if buf, ok = nextLine(br); !ok {
		break
	}
	if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
		found = true
		break
	}
}
if !found {
	failf("no items")
}

@ @<Option input@>=
func (s *Solver) readOptions(br *bufio.Reader) {
	for {
		buf, ok := nextLine(br)
		if !ok {
			break
		}
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
			continue
		}
		s.readOption(buf)
	}
	s.finalize()
}

@ An option that mentions no primary item can never be chosen, so it is
quietly unwound. A real option is sealed with a spacer and takes the next
option number.
@<Option input@>=
func (s *Solver) readOption(buf []byte) {
	spacer := s.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {
		@<Scan one item name and its color@>
	}

	if !hasPrimary {
		@<Unwind the option@>
		return
	}
	s.nd[spacer].loc = int32(s.lastNode - spacer)
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	s.options++
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
}

@ @<Scan one item name and its color@>=
name, next := token(buf, p, true)
if name == "" {
	failf("empty item name")
}
m, known := s.nameIndex[name]
if !known {
	failf("unknown item name: %s", name)
}
s.createNode(m, spacer, &hasPrimary)
if buf[next] == ':' {
	if m < s.second {
		failf("primary item must be uncolored: %s", name)
	}
	color, ce := token(buf, next+1, false)
	if color == "" {
		failf("missing color after %s:", name)
	}
	s.nd[s.lastNode].clr = int32(s.internColor(color))
	next = ce
} else {
	s.nd[s.lastNode].clr = 0
}
p = skipSpace(buf, next)

@ @<Unwind the option@>=
for s.lastNode > spacer {
	slot := int(s.nd[s.lastNode].itm) * zIprop
	s.setSize(slot, s.size(slot)-1)
	s.setPos(slot, spacer-1)
	s.lastNode--
}

@ @<Option input@>=
func (s *Solver) createNode(m, spacer int, hasPrimary *bool) {
	slot := m * zIprop
	s.set = ensure(s.set, slot)
	if s.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", s.names[m])
	}
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	t := s.size(slot)
	s.nd[s.lastNode].itm = int32(m)
	s.nd[s.lastNode].loc = int32(t)
	if m < s.second {
		*hasPrimary = true
	}
	s.setSize(slot, t+1)
	s.setPos(slot, s.lastNode)
}

@ Finalization lays out the sparse sets, and adds two tables the other engines
build only on demand: |itemBase|, which the signature walks, and the option
numbering, which names the ZDD's elements.
@<Input finalization@>=
func (s *Solver) finalize() {
	@<Lay out the set array@>
	@<Fill in the item headers@>
	@<Repoint the nodes@>
	@<Number the options and index the items@>
}

@ @<Lay out the set array@>=
s.active, s.itemlen = s.lastItm-1, s.lastItm-1
s.item = ensure(s.item, s.itemlen)
s.set = ensure(s.set, s.itemlen*zIprop+1)

j := zExtra
k := 0
for ; k < s.itemlen; k++ {
	s.item[k] = int32(j)
	j += zExtra + s.size((k+1)*zIprop)
}
s.setlen = j - zExtra
s.set = ensure(s.set, j+1)
if s.second == secondUnset {
	s.osecond, s.second = s.active, j
} else {
	s.osecond = s.second - 1
}

@ @<Fill in the item headers@>=
for ; k != 0; k-- {
	base := int(s.item[k-1])
	if k == s.second {
		s.second = base
	}
	s.setSize(base, s.size(k*zIprop))
	if s.size(base) == 0 && k <= s.osecond {
		s.baditem = k
	}
	s.setPos(base, k-1)
	s.setItemNo(base, k)
}

@ @<Repoint the nodes@>=
for k = 1; k < s.lastNode; k++ {
	if s.nd[k].itm <= 0 {
		continue
	}
	base := int(s.item[int(s.nd[k].itm)-1])
	loc := base + int(s.nd[k].loc)
	s.nd[k].itm = int32(base)
	s.nd[k].loc = int32(loc)
	s.set[loc] = int32(k)
}

@ One more sweep numbers the options. A node whose predecessor is a spacer
begins a fresh one, so the numbering is the input order, and |optFirst|
remembers where each option starts so that it can be named again later.
@<Number the options and index the items@>=
s.optNo = make([]int32, s.lastNode+1)
s.optFirst = make([]int32, s.options+1)
o := int32(0)
for k = 1; k < s.lastNode; k++ {
	if s.nd[k].itm <= 0 {
		continue
	}
	if s.nd[k-1].itm <= 0 {
		o++
		s.optFirst[o] = int32(k)
	}
	s.optNo[k] = o
}
s.itemBase = make([]int32, s.itemlen+1)
for k = 0; k < s.itemlen; k++ {
	base := int(s.item[k])
	s.itemBase[s.itemNo(base)] = int32(base)
}
s.clr = make([]int32, s.itemlen+1)

@** Tests.
A literate program ought to carry its own proof of life. This part is woven
from the same source and tangles to \.{zdd\_test.go}. The first tests are the
ones every engine in this repository takes: Knuth's six-option example, the
color machinery, and a problem with no solution at all.
@(zdd_test.go@>=
package zdd

import (
	"fmt"
	"math/rand/v2"
	"sort"
	"strings"
	"testing"

	cells "github.com/sjnam/dancing-cells"
)

func count(t *testing.T, input string) string {
	t.Helper()
	return New().Dance(strings.NewReader(input)).Count().String()
}

func TestExactCover(t *testing.T) {
	input := "a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n"
	if got := count(t, input); got != "1" {
		t.Errorf("want 1 cover, got %s", got)
	}
}

func TestColors(t *testing.T) {
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
	if got := count(t, input); got != "2" {
		t.Errorf("want 2 covers, got %s", got)
	}
}

func TestNoSolution(t *testing.T) {
	if got := count(t, "a b c\na b\n"); got != "0" {
		t.Errorf("want 0 covers, got %s", got)
	}
}

@ The diagram must agree with the engine next door, solution for solution and
not merely in number. Both sides are rendered canonically---names sorted
within an option, options within a solution, solutions within the set---so
that the comparison does not depend on the order either one happens to
produce.
@(zdd_test.go@>=
func canon(sols [][]cells.Option) []string {
	out := make([]string, 0, len(sols))
	for _, sol := range sols {
		opts := make([]string, len(sol))
		for i, opt := range sol {
			names := append([]string(nil), opt...)
			sort.Strings(names)
			opts[i] = strings.Join(names, " ")
		}
		sort.Strings(opts)
		out = append(out, strings.Join(opts, " | "))
	}
	sort.Strings(out)
	return out
}

func TestAgreesWithXCC(t *testing.T) {
	for _, in := range []string{
		"a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n",
		"p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n",
		queens(6), queens(7), dominoes(4, 4), dominoes(4, 6),
	} {
		var want [][]cells.Option
		for sol := range cells.NewXCC().Dance(strings.NewReader(in)).Solutions {
			want = append(want, sol)
		}
		var got [][]cells.Option
		for sol := range New().Dance(strings.NewReader(in)).Solutions() {
			got = append(got, sol)
		}
		w, g := canon(want), canon(got)
		if len(w) != len(g) {
			t.Fatalf("XCC found %d covers, the diagram %d", len(w), len(g))
		}
		for i := range w {
			if w[i] != g[i] {
				t.Fatalf("cover %d differs:\n%s\n%s", i, w[i], g[i])
			}
		}
	}
}

@ Two generators. The $n$-queens board is the one every document here uses;
the domino board asks for the perfect matchings of a grid graph, which is the
problem this engine exists for---each cell is a primary item and each domino
placement an option covering two of them.
@(zdd_test.go@>=
func queens(n int) string {
	var b strings.Builder
	for i := range n {
		fmt.Fprintf(&b, "r%02d ", i)
	}
	for j := range n {
		fmt.Fprintf(&b, "c%02d ", j)
	}
	b.WriteString("|")
	for k := 0; k < 2*n-1; k++ {
		fmt.Fprintf(&b, " a%02d b%02d", k, k)
	}
	b.WriteString("\n")
	for i := range n {
		for j := range n {
			fmt.Fprintf(&b, "r%02d c%02d a%02d b%02d\n", i, j, i+j, i-j+n-1)
		}
	}
	return b.String()
}

func dominoes(rows, cols int) string {
	var b strings.Builder
	for r := range rows {
		for c := range cols {
			fmt.Fprintf(&b, "%x%x ", r, c)
		}
	}
	b.WriteString("\n")
	for r := range rows {
		for c := range cols {
			if c+1 < cols {
				fmt.Fprintf(&b, "%x%x %x%x\n", r, c, r, c+1)
			}
			if r+1 < rows {
				fmt.Fprintf(&b, "%x%x %x%x\n", r, c, r+1, c)
			}
		}
	}
	return b.String()
}

@ The counts everybody knows: 92, 352, and 724 queens placements, and the
number of ways to tile a $2n\times2n$ board with dominoes, which is
$\hbox{A004003}=2,\,36,\,6728,\,12{,}988{,}816,\,258{,}584{,}046{,}368$. That
last one is the point of the exercise---it is counted here in milliseconds,
while enumerating those tilings one at a time takes our other engines
50 million search nodes and eighteen seconds for the $8\times8$ case alone.
@(zdd_test.go@>=
func TestQueenCounts(t *testing.T) {
	for n, want := range map[int]string{6: "4", 7: "40", 8: "92", 9: "352", 10: "724"} {
		if got := count(t, queens(n)); got != want {
			t.Errorf("%d queens: got %s, want %s", n, got, want)
		}
	}
}

func TestDominoCounts(t *testing.T) {
	want := []string{"2", "36", "6728", "12988816", "258584046368"}
	for i, w := range want {
		n := 2 * (i + 1)
		d := New().Dance(strings.NewReader(dominoes(n, n)))
		if got := d.Count().String(); got != w {
			t.Errorf("%dx%d dominoes: got %s, want %s", n, n, got, w)
		}
		t.Logf("%2dx%-2d %18s tilings, %6d ZDD nodes, %7d search nodes",
			n, n, d.Count(), d.Nodes(), d.s.Nodes())
	}
}

@ Finally the two questions that enumeration cannot answer. Both are asked of
the $10\times10$ board, whose $2.6\times10^{11}$ tilings nobody is going to
look at. A random one and a heaviest one must both be genuine tilings---fifty
dominoes, no cell covered twice---and the heaviest must be at least as heavy
as a thousand random ones.
@(zdd_test.go@>=
func TestRandomAndMaxWeight(t *testing.T) {
	d := New().Dance(strings.NewReader(dominoes(10, 10)))
	w := make([]int, d.Options()+1)
	for k := 1; k <= d.Options(); k++ {
		w[k] = (k * 37) % 101
	}
	best, wt, ok := d.MaxWeight(w)
	if !ok {
		t.Fatal("no heaviest tiling")
	}
	@<Check that |best| is a tiling@>
	r := rand.New(rand.NewPCG(1, 2))
	for i := 0; i < 1000; i++ {
		sol, ok := d.Random(r)
		if !ok {
			t.Fatal("no random tiling")
		}
		if len(sol) != 50 {
			t.Fatalf("random tiling has %d dominoes, want 50", len(sol))
		}
		if got := weigh(d, sol, w); got > wt {
			t.Fatalf("random tiling weighs %d, heavier than the maximum %d", got, wt)
		}
	}
}

@ @<Check that |best| is a tiling@>=
if len(best) != 50 {
	t.Fatalf("heaviest tiling has %d dominoes, want 50", len(best))
}
seen := map[string]bool{}
for _, opt := range best {
	for _, cell := range opt {
		if seen[cell] {
			t.Fatalf("cell %s covered twice", cell)
		}
		seen[cell] = true
	}
}

@ Weighing a solution means finding each option's number again, which the
diagram does not hand back; the test simply matches on the printed option,
which is unique here because no two dominoes cover the same pair of cells.
@(zdd_test.go@>=
func weigh(d *Diagram, sol []cells.Option, w []int) int {
	num := map[string]int{}
	for k := 1; k <= d.Options(); k++ {
		num[strings.Join(d.Option(k), " ")] = k
	}
	total := 0
	for _, opt := range sol {
		total += w[num[strings.Join(opt, " ")]]
	}
	return total
}

@** Index.
