\def\title{Dancing Cells}

@s Context int
@s Duration int
@s Ticker int
@s Reader int
@s Builder int
@s Time int
@s any int

@** Introduction.
Every so often a problem that looks like a puzzle turns out to be the same
problem wearing a different hat. Packing the squares $1{\times}1$, $2{\times}2$,
\dots, $n{\times}n$ into a tray---the {\it partridge puzzle\/}; pencilling
digits into a Sudoku grid; strewing pentominoes across a chessboard; timetabling
exams so that no student sits two at once---each of these is, underneath, a
single austere question. It is the {\it exact cover\/} problem: given a universe
of {\it items\/} and a collection of {\it options}, each option being a subset of
the items, can we select options so that every item is covered exactly once?

Donald Knuth taught a generation to answer that question with {\it Algorithm~X},
backtracking made vivid by the {\it dancing links\/} data structure. There, the
sparse matrix of options and items is threaded by doubly linked lists, so that
covering an item unstitches it from every list at once, and uncovering it---on
the way back up the search tree---stitches it right back, the links dancing out
and in as the search advances and retreats. It is one of the prettiest ideas in
all of combinatorial computing.

And then, as the idea neared its thirtieth birthday, Knuth wrote it out again
{\it the other way}. In his programs {\tt SSXCC} and {\tt SSMCC} he threw out the
links and kept the dance, storing each item's surviving options in a {\it sparse
set\/}---the little two-array structure that Preston Briggs and Linda Torczon
had distilled in 1993 from a throwaway exercise of Aho, Hopcroft, and Ullman. He
wrote it, he tells us, ``as if I live on a planet where the sparse-set ideas are
well known, but doubly linked links are almost unheard-of.'' This program is a Go
citizen of that planet: a port of {\tt SSXCC} and {\tt SSMCC}, dancing cells in
place of dancing links.

@ We keep two engines under one roof, because ``exactly once'' has two natural
loosenings and each earns its own machine.

The first, |XCC|, is exact cover {\it with colors}. Items come in two flavors:
{\it primary\/} items, which must be covered exactly once, and {\it secondary\/}
items, which may be covered any number of times {\it provided all the options
that touch one agree on its color}. Colors let options negotiate---``I will use
this square only if you paint it blue''---and turn out to express a startling
range of constraints. |XCC| branches the way Algorithm~X does: it picks the item
with the fewest surviving options and tries them all, a {\it $d$-way\/} fan-out.

The second, |MCC|, is exact cover {\it with multiplicities}. Here a primary item
may ask to be covered not once but between $u$ and $v$ times. This small change
alters the arithmetic of the search enough that a {\it binary\/} branch ---
include this one option, or banish it---serves better than a $d$-way one, so
|MCC| is a separate engine rather than a coat of paint on the first.

@ One Go-flavored liberty runs through both. Knuth's solvers print each solution
to the standard error stream and press on; ours hand each solution back through a
channel. A caller constructs a solver with |dcells.NewXCC()| or
|dcells.NewMCC()|, calls |Dance(reader)| on the input, and ranges over
|res.Solutions|; each value that arrives is a |[]Option|, and each |Option| is a
|[]string| of item names---a colored secondary item appearing as |name:color|.
The search runs in its own goroutine and blocks on every send, so ranging over
the solutions paces it, and a consumer who stops listening stops the search.
This API deliberately mirrors the |dlx| library
(\.{github.com/sjnam/dlx}), our dancing-links sibling, so programs migrate
between the two without noticing; item names and colors may be arbitrary,
possibly multibyte, strings in both. The input, likewise, we do not touch: it is
exactly the {\tt DLX} text format of Knuth's earlier solvers, so any file that
fed {\tt DLX2} or {\tt DLX3} feeds us unchanged.

The whole library, then, is four movements: a small shared vocabulary of types,
the two engines, and the parser that feeds them. Here is its skeleton; the rest
of this document fills in each named part, in order.
@c
// Package dcells solves exact cover (XCC, MCC) with dancing cells.
package dcells

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
)

@<Shared declarations@>@;
@<The XCC engine@>@;
@<The MCC engine@>@;
@<The DLX parser@>@;

@** Data structures.
Sparse-set data structures were introduced by Preston Briggs and Linda Torczon
[{\sl ACM Letters on Programming Languages and Systems\/ \bf2} (1993), 59--69],
who realized that an exercise in Aho, Hopcroft, and Ullman's classic text was
much more than a slick trick to avoid initializing an array. The idea is
astonishingly simple. To represent a subset $S$ of a universe
$U=\{x_0,\ldots,x_{n-1}\}$, keep two arrays $p$ and $q$ that are inverse
permutations of each other, and a count $s$. The members of $S$ are exactly
$x_{p_0},\ldots,x_{p_{s-1}}$. Then $x_k\in S$ iff $q_k<s$; to delete a member,
decrease $s$ and swap it to position~$s$; to insert, swap it to position~$s$ and
increase~$s$. No list, no links---just two permutations learning to dance.

Our sets never start empty and grow; they start {\it full\/} (every option is a
candidate) and shrink as the search commits to choices, so we keep genuine
inverse permutations rather than the half-defined arrays of the original
application.

@ The whole matrix lives in three flat arrays. An array |item| holds, for each
still-active item, an index |x| into a much larger array |set|. Beginning at
|set[x]| and running for |size(x)| entries are the options that currently
contain that item; so |item| plays the role of the permutation~$p$, and a
companion field |pos(x)| plays~$q$, recording that this item sits at
|item[pos(x)]|. Covering an item is then nothing but shrinking a count and
swapping two array slots---the sparse-set delete, done over and over. The
slots just below each item's base in |set| hold its bookkeeping (its size, its
position, its item number, and for MCC its multiplicity bounds); named accessor
methods, defined with each engine, read and write them.

The small vocabulary that both engines share is collected here:
@<Shared declarations@>=
@<Bookkeeping constants@>@;
@<The node type@>@;
@<Solutions and heartbeats@>@;
@<Undo records@>@;
@<The slice grower@>@;

@ @<Bookkeeping constants@>=
const (
	primExtra   = 4       // set entries reserved below each item's base
	infSize     = 1 << 30 // "no item to branch on" => a solution
	secondUnset = 1 << 30 // sentinel for "no primary/secondary boundary yet"
)

@ The options themselves are stored as runs of {\it nodes\/} in the third flat
array, |nd|, one node per item of the option, with ``spacer'' nodes marking the
seams between consecutive options. A node's |itm| field names its item and its
|loc| field records where, within that item's active run, this node presently
sits; |clr| is an interned color (0 meaning none). The |itm| and |clr| fields
are frozen once input is read, but |loc| moves as options dance in and out.
@<The node type@>=
type node struct {
	itm, loc, clr int32 // itm and clr are fixed after input; loc dances
}

@ A solution is reported as the list of its options, and each option as the
list of its item names---a colored secondary item appearing as \.{name:color}.
This is deliberately the same shape that the |dlx| library produces, so that
programs can migrate between the two without noticing. |Result| carries the two
channels a caller consumes: every exact cover arrives on |Solutions|, and ---
when the solver's pulse is switched on---occasional progress strings arrive
on |Heartbeat|. Both channels close when the search finishes or its context is
cancelled.
@<Solutions and heartbeats@>=
type Option []string

type Result struct {
	Solutions <-chan []Option
	Heartbeat <-chan string
}

@ Two tiny record types ride the {\it save stacks}, which are how the searches
remember enough to undo a branch. The $d$-way engine restores an item and a
size; the multiplicity engine restores an item, a size, and a bound. They are
introduced here and earn their keep much later, in the undo machinery of each
engine.
@<Undo records@>=
type twoints struct {
	l, r int32
}

type threeints struct{ l, s, b int32 }

@ One generic helper appears on nearly every page: |ensure| returns a slice at
least |n| long, preserving contents and growing the backing array geometrically
when it must. The dancing arrays grow only during input and while a save stack
deepens, so amortized doubling keeps the whole run allocation-light.
@<The slice grower@>=
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

@ The two solver structs, when we meet them, will share several blocks of state
verbatim; we define those blocks once and let the tangler copy them into both.
First, the public knobs. |Debug| turns on the same terse input-summary and
final-tally lines that the |dlx| library prints to |stderr|; |PulseInterval|,
if positive, asks for the heartbeats mentioned above.
@<Solver knobs@>=
Debug         bool          // print input summary and final stats to stderr
PulseInterval time.Duration // if > 0, offer periodic Heartbeat strings

@ Names and colors are arbitrary strings, so both engines intern them: each
distinct name becomes a small integer (1-based, since index~0 is a
placeholder), and each color likewise. The maps double as duplicate detectors.
@<Naming tables@>=
names      []string // interned item names, by item number (1-based)
nameIndex  map[string]int
colorNames []string // interned colors, by id (1-based; 0 means "no color")
colorIndex map[string]int

@ Both searches keep a {\it force stack\/} of items whose next move is no
longer a choice---forced moves will be a recurring character in this story
--- and the same counters of search effort. An ``update'' is one sparse-set
swap; a ``node'' is one visit to the recursive search.
@<The force stack@>=
force  []int32
forced int

@ @<Search statistics@>=
updates uint64
nodes   uint64
options uint64
count   uint64

@ @<Output channels@>=
solStream chan []Option
heartbeat chan string
pulse     *time.Ticker

@** The XCC engine.
Now the first solver, from the top. The algorithm is Algorithm~X in sparse-set
clothing, and one paragraph suffices to state it. {\it Choose\/} the active
primary item with the fewest remaining options---if none remains, the partial
solution is a solution. {\it Cover\/} that item: remove it from the active list
and hide every option that can no longer be used. Then {\it try\/} each of its
options in turn: commit the option (which covers all its other items too),
recurse, and undo. The rest is bookkeeping---but bookkeeping chosen so that
every one of those verbs is a handful of array swaps.

The engine unfolds in four movements, and the groups that follow trace them:
state and construction; the dance---the public launcher, the recursive
search, and the chooser; the covering machinery---committing, hiding, and
the undo apparatus that makes trying reversible; and the small reporting
offices that hand solutions back to the caller.
@<The XCC engine@>=
@<XCC state@>@;
@<Creating an XCC solver@>@;
@<XCC set accessors@>@;
@<XCC interning@>@;
@<Launching the XCC dance@>@;
@<The XCC search@>@;
@<Choosing the XCC item@>@;
@<Committing an XCC option@>@;
@<Hiding conflicting options@>@;
@<Covering an XCC item@>@;
@<XCC undo machinery@>@;
@<Visiting an XCC solution@>@;
@<The XCC heartbeat@>@;
@<Reporting an XCC option@>@;

@* XCC state and construction.
An |XCC| value carries the entire state of one computation. Besides the
shared blocks we prepared earlier, it owns the matrix arrays---|nd|, |item|,
|set|, with |second| marking the boundary between primary and secondary items
--- and the arrays that record the search path: |choice| holds the option
chosen at each level, and |saved|/|savestack| snapshot sizes for backtracking.
@<XCC state@>=
type XCC struct {
	@<Solver knobs@>@;
	ctx context.Context

	@<XCC matrix arrays@>@;
	@<Naming tables@>@;
	@<The force stack@>@;
	@<XCC backtrack arrays@>@;
	@<Search statistics@>@;
	@<Output channels@>@;
}

@ @<XCC matrix arrays@>=
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

@ @<XCC backtrack arrays@>=
choice    []int32
saved     []int32
savestack []twoints
saveptr   int

@ A fresh solver needs its sentinels and its (empty but non-nil) tables; by
default heartbeats are off and the context is the background context, never
cancelled. To make a search cancellable, hand it a context before starting:
|WithContext| returns a shallow copy, so the original stays reusable, and it
refuses a nil context outright---that would otherwise surface as a mysterious
panic deep in the dance. |Updates| and |Nodes| report the search statistics
once the |Solutions| channel has been drained.
@<Creating an XCC solver@>=
func NewXCC() *XCC {
	return &XCC{
		second:     secondUnset,
		names:      []string{""}, // item numbers are 1-based
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // color 0 means "no color"
		colorIndex: make(map[string]int),
		ctx:        context.Background(),
	}
}

func (s *XCC) WithContext(ctx context.Context) *XCC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *s
	c.ctx = ctx
	return &c
}

func (s *XCC) Updates() uint64 { return s.updates }
func (s *XCC) Nodes() uint64   { return s.nodes }

@ Here are the sparse-set accessors in the flesh. For an item whose base is
|x|, the reserved slots just below |x| hold its size, its position in |item|,
and its item number; the fourth reserved slot is spare. Reading and writing
them by name keeps the arithmetic of ``two below the base'' from leaking into
the algorithms.
@<XCC set accessors@>=
func (s *XCC) size(x int) int   { return int(s.set[x-1]) }
func (s *XCC) pos(x int) int    { return int(s.set[x-2]) }
func (s *XCC) itemNo(x int) int { return int(s.set[x-3]) }

func (s *XCC) setSize(x, v int)   { s.set[x-1] = int32(v) }
func (s *XCC) setPos(x, v int)    { s.set[x-2] = int32(v) }
func (s *XCC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

@ Interning a name registers it the first time and rejects a duplicate;
interning a color happily returns the existing id on later sightings, because
many options may share a color.
@<XCC interning@>=
func (s *XCC) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

func (s *XCC) internColor(name string) int {
	if id, ok := s.colorIndex[name]; ok {
		return id
	}
	id := len(s.colorNames)
	s.colorNames = append(s.colorNames, name)
	s.colorIndex[name] = id
	return id
}

@* The XCC dance.
|Dance| reads the matrix (panicking on malformed input), opens the channels,
and launches the search in a goroutine; it returns at once, and the goroutine
closes both channels when it is done, so a |range| over the solutions
terminates naturally. A |baditem|---a primary item that ended the input with
no options at all---makes the whole problem trivially unsolvable, so the
search is skipped and the channels simply close.
@<Launching the XCC dance@>=
func (s *XCC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)

	s.solStream = make(chan []Option)
	s.heartbeat = make(chan string)

	go func() {
		defer close(s.solStream)
		defer close(s.heartbeat)

		@<Report the XCC input summary@>@;
		if s.PulseInterval > 0 {
			s.pulse = time.NewTicker(s.PulseInterval)
			defer s.pulse.Stop()
		}

		if s.baditem == 0 {
			s.search(0)
		}

		@<Report the XCC totals@>@;
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}
}

@ Under |Debug| we bracket the search with the same summary lines the |dlx|
library prints, down to the fussy singular/plural of ``solutions.''
@<Report the XCC input summary@>=
if s.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
}

@ @<Report the XCC totals@>=
if s.Debug {
	plural := "s"
	if s.count == 1 {
		plural = ""
	}
	fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
		s.count, plural, s.updates, s.nodes)
}

@ The search is one recursive function. At each node it counts a step, gives
the context a chance to abort, and offers a heartbeat; then it asks
|chooseItem| where to branch. A |false| return, here and below, means ``unwind
the entire search''---the caller has walked away or cancelled---and it
propagates up through every level.
@<The XCC search@>=
func (s *XCC) search(level int) bool {
	s.nodes++
	select {
	case <-s.ctx.Done():
		return false
	default:
	}
	s.tick()

	best, solution := s.chooseItem()
	if solution {
		return s.visit(level)
	}
	@<Cover |best| and try each of its options in turn@>@;
	return true
}

@ Covering |best| starts with the item itself: |swapOut| retires it from the
active list, and |hide|---in its unchecked form, since we are committing to
cover |best| no matter what---removes each of its options from the sets of
the {\it other\/} items they touch. What remains in |best|'s own set is
untouched: those are exactly the candidates to try. We snapshot all the active
sizes once, then loop: pick a candidate, commit it, recurse, restore the
sizes, and go around again. Note that |restoreSizes| runs whether or not the
commit succeeded---a failed |commitOption| leaves partial damage that must be
undone just the same.
@<Cover |best| and try each of its options in turn@>=
s.swapOut(best)
s.oactive = s.active
s.hide(best, 0, 0)
s.saveSizes(level)
s.choice = ensure(s.choice, level+1)
for c := best; c < best+s.size(best); c++ {
	opt := int(s.set[c])
	s.choice[level] = int32(opt)
	if s.commitOption(opt) {
		if !s.search(level + 1) {
			return false
		}
	}
	s.restoreSizes(level)
}

@ Which item shall we branch on? Christine Solnon and Knuth added a wrinkle to
the classic ``minimum remaining values'' rule that repays its keep: an item
already down to a {\it single\/} option is a forced move, best taken at once
and---crucially---taken without the expense of saving anybody's sizes. Such
items wait on the force stack. So we first drain the stack (skipping items
that were covered while they waited), and only then scan for the emptiest
primary item. If the scan pushed new singletons, one of them wins instead. A
|score| that never improved from |infSize| means no primary item is active at
all: a solution.
@<Choosing the XCC item@>=
func (s *XCC) chooseItem() (best int, solution bool) {
	for s.forced != 0 {
		s.forced--
		if f := int(s.force[s.forced]); s.pos(f) < s.active {
			return f, false
		}
	}
	@<Scan the active primaries for the emptiest@>@;
	if s.forced != 0 {
		s.forced--
		return int(s.force[s.forced]), false
	}
	return best, score == infSize
}

@ Ties go to the leftmost item, matching Knuth's solvers. Size zero cannot
occur here---|hide| refuses to let an active primary item starve---so the
empty case documents itself and moves on.
@<Scan the active primaries for the emptiest@>=
score := infSize
for k := 0; k < s.active; k++ {
	x := int(s.item[k])
	if x >= s.second {
		continue // secondary items are not branched on
	}
	switch sz := s.size(x); {
	case sz == 0:
		// unreachable: hide never starves an active primary item
	case sz == 1:
		s.force = ensure(s.force, s.forced+1)
		s.force[s.forced] = int32(x)
		s.forced++
	case sz < score || (sz == score && x < best):
		best, score = x, sz
	}
}

@* XCC covering and undoing.
Committing to option |opt| is where the real covering happens, in two passes
over the option's nodes. (An option's nodes are contiguous, bracketed by
spacers whose |itm| is non-positive; starting just past |opt| and following
the spacer offsets walks the whole option round-robin.) The first pass swaps
every other item of the option out of the active list, so no future choice
can land on them. The second pass hides the options that now conflict. If any
primary item would be left uncoverable, we abandon the commit---clearing the
force stack, whose pending entries died with the branch.
@<Committing an XCC option@>=
func (s *XCC) commitOption(opt int) bool {
	@<Swap the items of |opt| out of the active list@>@;
	@<Hide or purify each item of |opt|@>@;
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
		s.updates++
	}
	q++
}
s.active = p

@ The second pass distinguishes the two item flavors. A primary item is being
covered outright, so every other option that uses it must go. A secondary item
is being {\it purified\/}: options that agree with the committed color survive,
the rest go---and Solnon's observation, which this code inherits, is that
purification and covering are the same sweep seen from two angles, so one
|hide| serves both. A secondary item already purified earlier (its |pos| is
beyond |oactive|) is skipped entirely.
@<Hide or purify each item of |opt|@>=
for q := opt + 1; q != opt; {
	c := int(s.nd[q].itm)
	if c < 0 {
		q += c
		continue
	}
	switch {
	case c < s.second:
		if !s.hide(c, 0, 1) {
			s.forced = 0
			return false
		}
	case s.pos(c) < s.oactive:
		if !s.hide(c, int(s.nd[q].clr), 1) {
			s.forced = 0
			return false
		}
	}
	q++
}

@ |hide| walks the options remaining in item |c|'s set and deletes each from
the sets of {\it its\/} other items. When a |color| is given (|c| is secondary),
options sharing that color are kept---that is the purification. The |check|
flag tells |hide| whether anyone is still allowed to veto: when we hide the
branching item itself the answer is no, but during a commit a primary item
that drops to zero options kills the branch, and one that drops to a single
option becomes a forced move.
@<Hiding conflicting options@>=
func (s *XCC) hide(c, color, check int) bool {
	for rr, end := c, c+s.size(c); rr < end; rr++ {
		tt := int(s.set[rr])
		if color != 0 && int(s.nd[tt].clr) == color {
			continue
		}
		@<Delete option |tt| from the sets of its other items@>@;
	}
	return true
}

@ Here at last is the sparse-set delete in its natural habitat: shrink the
size, swap the departing node into the vacated last slot, and repair both
|loc| fields. Items whose |pos| is at or beyond |oactive| were swapped out by
the current commit and their sets must stay intact for the eventual restore,
so they are left alone.
@<Delete option |tt| from the sets of its other items@>=
for nn := tt + 1; nn != tt; {
	u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
	if u < 0 {
		nn += u
		continue
	}
	if s.pos(u) < s.oactive {
		ss := s.size(u) - 1
		@<Veto or force item |u| if it is running out@>@;
		nnp := int(s.set[u+ss])
		s.setSize(u, ss)
		s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
		s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
		s.updates++
	}
	nn++
}

@ @<Veto or force item |u| if it is running out@>=
if ss <= 1 && check != 0 && u < s.second && s.pos(u) < s.active {
	if ss == 0 {
		return false
	}
	s.force = ensure(s.force, s.forced+1)
	s.force[s.forced] = int32(u)
	s.forced++
}

@ Covering the chosen item itself is one bare sparse-set delete on the |item|
array.
@<Covering an XCC item@>=
func (s *XCC) swapOut(x int) {
	p := s.active - 1
	s.active = p
	pp := s.pos(x)
	cc := int(s.item[p])
	s.item[p], s.item[pp] = int32(x), int32(cc)
	s.setPos(cc, pp)
	s.setPos(x, p)
	s.updates++
}

@ Finally, backtracking. Knuth's first sparse-set attempt undid each deletion
in reverse, mirror-image code that had to be maintained in step with the
forward pass. Solnon's suggestion, adopted here, is happily cruder: before a
branch, save the {\it sizes\/} of all active items in one sweep; afterward,
slam them back. Positions and set contents need no repair---the swaps left
every set a permutation of itself, and a restored size re-admits exactly the
right entries. The |saved| array remembers how deep the save stack was at each
level, which also tells |restoreSizes| how many items were active then.
@<XCC undo machinery@>=
func (s *XCC) saveSizes(level int) {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		s.savestack[s.saveptr+p] = twoints{s.item[p], int32(s.size(int(s.item[p])))}
	}
	s.saveptr += s.active
	s.saved = ensure(s.saved, level+2)
	s.saved[level+1] = int32(s.saveptr)
}

func (s *XCC) restoreSizes(level int) {
	s.saveptr = int(s.saved[level+1])
	s.active = s.saveptr - int(s.saved[level])
	for p := -s.active; p < 0; p++ {
		e := s.savestack[s.saveptr+p]
		s.setSize(int(e.l), int(e.r))
	}
}

@* XCC reporting.
Reaching a solution, we materialize it from the |choice| stack---one option
per level---and send it down the channel. The send is the pacing point: if
the consumer has abandoned the range, or the context is cancelled, the other
arm of the select fires and the whole search unwinds.
@<Visiting an XCC solution@>=
func (s *XCC) visit(level int) bool {
	s.count++
	sol := make([]Option, level)
	for k := 0; k < level; k++ {
		sol[k] = s.option(int(s.choice[k]))
	}
	select {
	case <-s.ctx.Done():
		return false
	case s.solStream <- sol:
		return true
	}
}

@ A heartbeat is strictly best-effort: when the pulse has fired we offer a
progress line, but if nobody is waiting to receive it we drop it and dance on.
No part of the search ever blocks on a heartbeat.
@<The XCC heartbeat@>=
func (s *XCC) tick() {
	if s.pulse == nil {
		return
	}
	select {
	case <-s.pulse.C:
		select {
		case s.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", s.nodes, s.count):
		default:
		}
	default:
	}
}

@ The search knows each chosen option only by a node inside it. To report the
option we walk back to its first node (spacers have non-positive |itm|) and
then forward, naming each item and appending its color where there is one. The
result is in the input order of the items, independent of which node we
started from, so callers can index |opt[0]|, |opt[1]|,~\dots\ positionally.
@<Reporting an XCC option@>=
func (s *XCC) option(p int) Option {
	for s.nd[p-1].itm > 0 {
		p-- // move to the option's first node
	}
	var opt Option
	for q := p; s.nd[q].itm > 0; q++ {
		name := s.names[s.itemNo(int(s.nd[q].itm))]
		if c := s.nd[q].clr; c != 0 {
			name += ":" + s.colorNames[c]
		}
		opt = append(opt, name)
	}
	return opt
}

@** The MCC engine.
The second solver answers a richer question. In |MCC| a primary item carries a
{\it multiplicity\/} $[u..v]$: it must be covered at least $u$ and at most $v$
times, plain exact cover being the case $[1..1]$. Two numbers travel with each
such item. Its {\it bound\/} is its residual capacity---how many more times
it still wants covering, counting down as options are chosen. Its {\it slack\/}
is $v-u$, the give in the constraint, and it never changes. Filip Stappers
added these extensions to Knuth's line of solvers in 2023.

Multiplicities change the shape of the branch. An item that may be covered
several times is not disposed of by one $d$-way fan-out over its options, so
|MCC| branches {\it in binary}: each search node names one item and one of its
options and asks two questions---{\it include\/} the option, or {\it
remove\/} it and choose again. The item to branch on is the one of least {\it
branching degree\/} $\ell+s-b+1$, where $\ell$ is its number of surviving
options, $b$ its bound, and $s=\min({\rm slack},b)$; degree~1 means the move
is forced. Two search coordinates must not be confused: the {\it stage\/}
counts options included so far (left branches only), while right branches
re-enter the same stage with one option fewer.

The engine unfolds like its sibling, in the same four movements: state and
construction; the binary dance with its chooser; the branch actions ---
including and excluding an option, with their shared sparse-set surgery and
the undo machinery; and the closing reporting offices.
@<The MCC engine@>=
@<MCC constants@>@;
@<MCC state@>@;
@<Creating an MCC solver@>@;
@<MCC set accessors@>@;
@<MCC interning@>@;
@<Launching the MCC dance@>@;
@<The MCC search@>@;
@<Forced MCC moves@>@;
@<Choosing the MCC item@>@;
@<Including an MCC option@>@;
@<Excluding an MCC option@>@;
@<Deactivating an MCC item@>@;
@<MCC undo machinery@>@;
@<Visiting an MCC solution@>@;
@<The MCC heartbeat@>@;
@<Reporting an MCC option@>@;

@* MCC state and construction.
Each MCC item needs two reserved slots more than an XCC item, for its slack
and bound.
@<MCC constants@>=
const (
	mccExtra = 5 // set entries below each item base: size, pos, itemNo, slack, bound
	mccIprop = 5 // input-phase slot spacing
)

@ The |MCC| state mirrors |XCC| almost field for field---the shared blocks
are literally the same sections---but there is no |oactive|, no |choice|,
and no |saved|: binary branching records its path in |included| (one option
per stage, ready for output) and rewinds through a save stack of
size-and-bound triples.
@<MCC state@>=
type MCC struct {
	@<Solver knobs@>@;
	ctx context.Context

	@<MCC matrix arrays@>@;
	@<Naming tables@>@;
	@<The force stack@>@;
	@<MCC backtrack arrays@>@;
	@<Search statistics@>@;
	@<Output channels@>@;
}

@ @<MCC matrix arrays@>=
nd       []node
lastNode int
item     []int32
second   int
lastItm  int
set      []int32
itemlen  int
setlen   int
active   int
baditem  int
osecond  int

@ @<MCC backtrack arrays@>=
included  []int32 // option included at each stage, for solution output
savestack []threeints
saveptr   int

@ Construction and cancellation retell the |XCC| story.
@<Creating an MCC solver@>=
func NewMCC() *MCC {
	return &MCC{
		second:     secondUnset,
		names:      []string{""},
		nameIndex:  make(map[string]int),
		colorNames: []string{""},
		colorIndex: make(map[string]int),
		ctx:        context.Background(),
	}
}

func (m *MCC) WithContext(ctx context.Context) *MCC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *m
	c.ctx = ctx
	return &c
}

func (m *MCC) Updates() uint64 { return m.updates }
func (m *MCC) Nodes() uint64   { return m.nodes }

@ The accessor family grows by two, for the |slack| and |bound| slots.
@<MCC set accessors@>=
func (m *MCC) size(x int) int   { return int(m.set[x-1]) }
func (m *MCC) pos(x int) int    { return int(m.set[x-2]) }
func (m *MCC) itemNo(x int) int { return int(m.set[x-3]) }
func (m *MCC) slack(x int) int  { return int(m.set[x-4]) }
func (m *MCC) bound(x int) int  { return int(m.set[x-5]) }

func (m *MCC) setSize(x, v int)   { m.set[x-1] = int32(v) }
func (m *MCC) setPos(x, v int)    { m.set[x-2] = int32(v) }
func (m *MCC) setItemNo(x, v int) { m.set[x-3] = int32(v) }
func (m *MCC) setSlack(x, v int)  { m.set[x-4] = int32(v) }
func (m *MCC) setBound(x, v int)  { m.set[x-5] = int32(v) }

@ Interning is verbatim the |XCC| code with the other receiver; Go gives us no
graceful way to share a method body between two types, and six small lines are
cheaper than an abstraction.
@<MCC interning@>=
func (m *MCC) internName(name string) (num int, ok bool) {
	if _, dup := m.nameIndex[name]; dup {
		return 0, false
	}
	num = len(m.names)
	m.names = append(m.names, name)
	m.nameIndex[name] = num
	return num, true
}

func (m *MCC) internColor(name string) int {
	if id, ok := m.colorIndex[name]; ok {
		return id
	}
	id := len(m.colorNames)
	m.colorNames = append(m.colorNames, name)
	m.colorIndex[name] = id
	return id
}

@* The MCC binary dance.
Launching, too, is the twin of |XCC|'s |Dance|.
@<Launching the MCC dance@>=
func (m *MCC) Dance(rd io.Reader) *Result {
	m.inputMatrix(rd)

	m.solStream = make(chan []Option)
	m.heartbeat = make(chan string)

	go func() {
		defer close(m.solStream)
		defer close(m.heartbeat)

		@<Report the MCC input summary@>@;
		if m.PulseInterval > 0 {
			m.pulse = time.NewTicker(m.PulseInterval)
			defer m.pulse.Stop()
		}

		if m.baditem == 0 {
			m.search(0)
		}

		@<Report the MCC totals@>@;
	}()

	return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}
}

@ @<Report the MCC input summary@>=
if m.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
}

@ @<Report the MCC totals@>=
if m.Debug {
	plural := "s"
	if m.count == 1 {
		plural = ""
	}
	fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
		m.count, plural, m.updates, m.nodes)
}

@ Now the binary dance. After the usual node count, abort check, and pulse, a
forced item left over from a covering at some shallower node takes absolute
priority; then the chooser speaks, possibly discovering new forced items of
its own; and a degree of |infSize| means no primary item remains---a
solution. Only then do we truly branch.
@<The MCC search@>=
func (m *MCC) search(stage int) bool {
	m.nodes++
	select {
	case <-m.ctx.Done():
		return false
	default:
	}
	m.tick()

	@<Dispatch a leftover forced item@>@;

	best, score := m.chooseBest()
	if m.forced != 0 {
		m.forced--
		return m.forcedMove(stage, int(m.force[m.forced]))
	}
	if score == infSize {
		return m.visit(stage)
	}
	@<Branch left and right on |best|@>@;
	return true
}

@ Items on the force stack may have been deactivated since they were pushed;
those are silently discarded.
@<Dispatch a leftover forced item@>=
for m.forced != 0 {
	m.forced--
	if bi := int(m.force[m.forced]); m.pos(bi) < m.active {
		return m.forcedMove(stage, bi)
	}
}

@ The branch proper. We save the state once and probe |best|'s first surviving
option, |opt|. The {\it left\/} child includes it and moves to |stage+1|; the
{\it right\/} child restores the state, removes the option, and re-enters the
{\it same\/} stage to choose afresh. When the degree is~1 there is no right
child---excluding the option would starve the item---so half the work
vanishes. Either way we leave with the save stack exactly as we found it.
@<Branch left and right on |best|@>=
mark := m.saveState()
opt := int(m.set[best])
m.included = ensure(m.included, stage+1)
m.included[stage] = int32(opt)

if m.includeOption(opt) {
	if !m.search(stage + 1) {
		m.saveptr = mark
		return false
	}
}
if score != 1 {
	m.restoreState(mark)
	if m.removeOption(opt) {
		if !m.search(stage) {
			m.saveptr = mark
			return false
		}
	}
}
m.saveptr = mark

@ A forced item has exactly one admissible move and no alternative, so we
commit it and step forward {\it without saving anything\/}---that is the
whole point of recognizing forced moves, per Solnon's 2023 improvement. Some
ancestor's |restoreState| will undo its effects when the time comes. Note the
quiet |true| when the inclusion fails: the branch is dead, but the search as a
whole goes on.
@<Forced MCC moves@>=
func (m *MCC) forcedMove(stage, bi int) bool {
	opt := int(m.set[bi])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)
	if m.includeOption(opt) {
		return m.search(stage + 1)
	}
	return true
}

@ The chooser weighs every active primary item by the branching degree
$\ell+s-b+1$ and keeps the smallest, breaking ties by smaller slack, then
larger size, then leftmost position---a cascade tuned by Knuth's
experiments. An item whose degree falls to~1 is forced, and, because it may
still need covering more than once, it is pushed |bound-slack| times so that
each required covering gets its turn.
@<Choosing the MCC item@>=
func (m *MCC) chooseBest() (best, score int) {
	score = infSize
	bestS, bestL := 0, 0
	for k := 0; k < m.active; k++ {
		x := int(m.item[k])
		if x >= m.second {
			continue
		}
		s := m.slack(x)
		if b := m.bound(x); s > b {
			s = b
		}
		t := m.size(x) + s - m.bound(x) + 1
		switch {
		case t == 1:
			for i := m.bound(x) - m.slack(x); i > 0; i-- {
				m.force = ensure(m.force, m.forced+1)
				m.force[m.forced] = int32(x)
				m.forced++
			}
		case t <= score && (t < score || (s <= bestS && (s < bestS ||
			(m.size(x) >= bestL && (m.size(x) > bestL || x < best))))):
			score, best, bestS, bestL = t, x, s, m.size(x)
		}
	}
	return best, score
}

@* The MCC branch actions.
Including an option walks its nodes---first rewinding to the option's
start---and settles accounts with each item in turn via |coverOrCommit|. An
item found already inactive is fine if secondary (it was purified earlier)
and impossible if primary. A |false| from anywhere means some item became
uncoverable and the caller's branch is dead.
@<Including an MCC option@>=
func (m *MCC) includeOption(opt int) bool {
	for m.nd[opt-1].itm > 0 {
		opt--
	}
	for ; ; opt++ {
		ii := int(m.nd[opt].itm)
		if ii <= 0 {
			break
		}
		pp := int(m.nd[opt].loc)
		if m.pos(ii) >= m.active {
			if ii >= m.second {
				continue // secondary item already purified
			}
			return false // cannot happen for a well-formed active option
		}
		if !m.coverOrCommit(ii, opt, pp) {
			return false
		}
	}
	return true
}

@ For one item |ii| of the included option (whose node is |cur|, sitting at
slot |p| of |ii|'s set) there are two futures. A primary item first pays one
unit of bound; if that exhausts it---or if |ii| is secondary---the item is
finished and leaves the field. Otherwise |ii| still wants more coverings and
merely drops this option from its set.
@<Including an MCC option@>=
func (m *MCC) coverOrCommit(ii, cur, p int) bool {
	if ii < m.second {
		m.setBound(ii, m.bound(ii)-1)
	}
	if ii >= m.second || m.bound(ii) == 0 {
		@<Cover or purify item |ii| outright@>@;
	} else {
		@<Drop option |cur| from item |ii|, which wants more@>@;
	}
	return true
}

@ Finishing an item means removing every {\it competing\/} option from the
rest of the matrix---except, when |ii| is secondary and the committed node
carries a color, the options that agree with that color: they are purified,
not removed. The item itself is then deactivated. (The loop runs downward
because |removeFromOtherSets| reshuffles the set as it works.)
@<Cover or purify item |ii| outright@>=
ss := m.size(ii)
c := 0
if ii >= m.second {
	c = int(m.nd[cur].clr)
}
for s := ii + ss - 1; s >= ii; s-- {
	if s == p {
		continue
	}
	optp := int(m.set[s])
	if c == 0 || int(m.nd[optp].clr) != c {
		if !m.removeFromOtherSets(optp) {
			return false
		}
	}
}
m.deactivate(ii)

@ An item that still wants coverings loses just this one option---unless
that would push its set below |bound-slack|, the minimum it can still hope to
collect, in which case the branch dies. Dropping the last option of an item
whose remaining demand is zero simply retires it.
@<Drop option |cur| from item |ii|, which wants more@>=
ss := m.size(ii) - 1
if ss < m.bound(ii)-m.slack(ii) {
	m.forced = 0
	return false // ii would be wiped out
}
if ss == 0 {
	m.deactivate(ii)
} else {
	@<Swap option |cur| out of slot |p| of item |ii|'s set@>@;
}

@ Three different passages need the same five lines of sparse-set surgery, so
we name them once: the departing option trades places with the last live entry
of |ii|'s set, and both |loc| fields are repaired.
@<Swap option |cur| out of slot |p| of item |ii|'s set@>=
nnp := int(m.set[ii+ss])
m.setSize(ii, ss)
m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
m.updates++

@ Removing a competing option deletes it from every active set it belongs to,
skipping purified secondary items, and watching---as always---for a
primary item pushed below its coverable minimum.
@<Excluding an MCC option@>=
func (m *MCC) removeFromOtherSets(optp int) bool {
	cur := optp
	for m.nd[cur-1].itm > 0 {
		cur--
	}
	for ; ; cur++ {
		ii := int(m.nd[cur].itm)
		if ii <= 0 {
			break
		}
		p := int(m.nd[cur].loc)
		if p >= m.second && m.pos(ii) >= m.active {
			continue
		}
		ss := m.size(ii) - 1
		if p < m.second {
			if ss < m.bound(ii)-m.slack(ii) {
				m.forced = 0
				return false
			}
			if ss == 0 {
				m.deactivate(ii)
			}
		}
		if ss > 0 {
			@<Swap option |cur| out of slot |p| of item |ii|'s set@>@;
		}
	}
	return true
}

@ The right branch of the search needs the same deletion---remove option
|cur| without committing it---and differs from |removeFromOtherSets| in one
detail only: a |false| here is an ordinary ``can't cover,'' reported to a
caller who is about to backtrack anyway, so the force stack is left in peace.
@<Excluding an MCC option@>=
func (m *MCC) removeOption(cur int) bool {
	for m.nd[cur-1].itm > 0 {
		cur--
	}
	for ; ; cur++ {
		ii := int(m.nd[cur].itm)
		if ii <= 0 {
			break
		}
		p := int(m.nd[cur].loc)
		if p >= m.second && m.pos(ii) >= m.active {
			continue
		}
		ss := m.size(ii) - 1
		if p < m.second {
			if ss < m.bound(ii)-m.slack(ii) {
				return false
			}
			if ss == 0 {
				m.deactivate(ii)
			}
		}
		if ss > 0 {
			@<Swap option |cur| out of slot |p| of item |ii|'s set@>@;
		}
	}
	return true
}

@ Deactivating an item is the sparse-set delete on the |item| array once more.
@<Deactivating an MCC item@>=
func (m *MCC) deactivate(ii int) {
	m.active--
	p := m.pos(ii)
	iii := int(m.item[m.active])
	m.item[m.active], m.item[p] = int32(ii), int32(iii)
	m.setPos(ii, m.active)
	m.setPos(iii, p)
}

@ Binary branching cannot get away with saving only sizes: bounds change too.
So |saveState| snapshots each active item's size and (for primary items) its
bound, returning a mark for |restoreState| to rewind to---the multiplicity
analogue of the |XCC| undo machinery.
@<MCC undo machinery@>=
func (m *MCC) saveState() int {
	mark := m.saveptr
	m.savestack = ensure(m.savestack, m.saveptr+m.active)
	for p := 0; p < m.active; p++ {
		x := int(m.item[p])
		e := threeints{l: int32(x), s: int32(m.size(x))}
		if x < m.second {
			e.b = int32(m.bound(x))
		}
		m.savestack[m.saveptr] = e
		m.saveptr++
	}
	return mark
}

func (m *MCC) restoreState(mark int) {
	m.active = m.saveptr - mark
	for p := 0; p < m.active; p++ {
		e := m.savestack[mark+p]
		m.setSize(int(e.l), int(e.s))
		if int(e.l) < m.second {
			m.setBound(int(e.l), int(e.b))
		}
	}
	m.saveptr = mark
}

@* MCC reporting.
Emitting a solution reads the |included| stack; the pacing select is the
same as |XCC|'s.
@<Visiting an MCC solution@>=
func (m *MCC) visit(stage int) bool {
	m.count++
	sol := make([]Option, stage)
	for k := 0; k < stage; k++ {
		sol[k] = m.option(int(m.included[k]))
	}
	select {
	case <-m.ctx.Done():
		return false
	case m.solStream <- sol:
		return true
	}
}

@ @<The MCC heartbeat@>=
func (m *MCC) tick() {
	if m.pulse == nil {
		return
	}
	select {
	case <-m.pulse.C:
		select {
		case m.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", m.nodes, m.count):
		default:
		}
	default:
	}
}

@ @<Reporting an MCC option@>=
func (m *MCC) option(p int) Option {
	for m.nd[p-1].itm > 0 {
		p--
	}
	var opt Option
	for q := p; m.nd[q].itm > 0; q++ {
		name := m.names[m.itemNo(int(m.nd[q].itm))]
		if c := m.nd[q].clr; c != 0 {
			name += ":" + m.colorNames[c]
		}
		opt = append(opt, name)
	}
	return opt
}

@** Reading the DLX input.
Both engines eat the same format, the {\tt DLX} text that Knuth's solvers have
used for years. A problem is a stream of lines. The {\it first\/} non-blank,
non-comment line names the items: the primary items, then a lone \.{\|}, then
the secondary items. Every line after that is one option, naming the items it
contains; a secondary item in an option may carry a color as \.{name:color}.
Item names and colors are whitespace-free strings, and a line beginning with
\.{\|} is a comment. The multiplicity engine reads one thing more: a primary
item may be written \.{high\|name} or \.{low:high\|name} to declare that it
wants covering between |low| and |high| times, the bare name meaning $[1..1]$.

Parsing happens in two phases per engine---the item line, then the options
--- followed by a {\it finalization\/} that lays out the sparse sets the
dance expects. The two engines' phases differ only where multiplicities
intrude, but Go's type system makes sharing the code more trouble than it is
worth, so each engine gets its own copy and the MCC prose dwells only on the
differences.
@<The DLX parser@>=
@<Parse failures@>@;
@<Reading one line@>@;
@<Scanning tokens@>@;
@<The XCC input phase@>@;
@<The MCC input phase@>@;

@* Scanning the input.
A malformed input is a programming error, not a runtime condition to be
nursed along, so the parser announces trouble by panicking with a
|parseError|.
@<Parse failures@>=
type parseError struct{ msg string }

func (e *parseError) Error() string { return e.msg }

func failf(format string, a ...any) {
	panic(&parseError{fmt.Sprintf(format, a...)})
}

@ |nextLine| reads one line into a NUL-terminated, NUL-padded buffer, so that
scanning one byte past the content stays in bounds and stops at the
terminating NUL---a small trick borrowed from the C originals that spares
every scanner below an end-of-buffer test.
@<Reading one line@>=
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

@ |token| lifts the next word, stopping at whitespace, the NUL, or---when
|stopColon| is set---a colon, which is how an option's \.{name:color} is
split.
@<Scanning tokens@>=
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

@* Parsing an XCC problem.
Here is the XCC input phase, in the order the dance driver invokes it.
@<The XCC input phase@>=
func (s *XCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

@<XCC item-name input@>@;
@<XCC option input@>@;
@<XCC input finalization@>@;

@ The item line is the first line that is neither blank nor a comment. Walking
it token by token, a lone \.{\|} switches us from primary to secondary items
(and may appear only once); anything else is a name, checked for the forbidden
characters \.{:} and \.{\|} and for duplication before it is interned. At the
end, |lastItm| is the item count plus one, since |names[0]| is unused.
@<XCC item-name input@>=
func (s *XCC) readItemNames(br *bufio.Reader) {
	@<Find the XCC item line@>@;
	for buf[p] != 0 {
		name, next := token(buf, p, false)
		if name == "|" {
			if s.second != secondUnset {
				failf("item name line contains | twice")
			}
			s.second = len(s.names) // the next item's number
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
	s.lastItm = len(s.names) // items + 1 (names[0] is unused)
}

@ @<Find the XCC item line@>=
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

@ Each remaining line is one option; blanks and comments are skipped, and the
end of the stream triggers finalization.
@<XCC option input@>=
func (s *XCC) readOptions(br *bufio.Reader) {
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

@ Reading one option is a loop of name-and-maybe-color scans. An option that
mentions no primary item can never be chosen---committing it would cover
nothing---so it is quietly unwound, node by node; Knuth's solvers print a
warning here, and we simply drop it. A real option is sealed with a spacer
node so the runs stay separable.
@<XCC option input@>=
func (s *XCC) readOption(buf []byte) {
	spacer := s.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {
		@<Scan one XCC item name and its color@>@;
	}

	if !hasPrimary {
		@<Unwind the XCC option@>@;
		return
	}
	s.nd[spacer].loc = int32(s.lastNode - spacer)
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	s.options++
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
}

@ A color may follow a name after a colon---but only on a secondary item.
@<Scan one XCC item name and its color@>=
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

@ Unwinding pops each half-built node and takes back its tally from the
input-phase slot.
@<Unwind the XCC option@>=
for s.lastNode > spacer {
	slot := int(s.nd[s.lastNode].itm) << 2
	s.setSize(slot, s.size(slot)-1)
	s.setPos(slot, spacer-1)
	s.lastNode--
}

@ During input the |set| array is used at a coarse |m<<2| spacing---room
enough for each item's reserved slots---and |createNode| tallies one more
node for item |m| there, catching a repeated item within a single option by
noticing that the item's last-seen position is already inside this option.
@<XCC option input@>=
func (s *XCC) createNode(m, spacer int, hasPrimary *bool) {
	slot := m << 2
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

@ Finalization converts the coarse input tallies into the dance's real
layout, in three sweeps over the data.
@<XCC input finalization@>=
func (s *XCC) finalize() {
	@<Lay out the XCC set array@>@;
	@<Fill in the XCC item headers@>@;
	@<Repoint the XCC nodes@>@;
}

@ The first sweep assigns each item a compact base in |set|---leaving
|primExtra| reserved slots below it---and converts the primary/secondary
boundary into those coordinates. A problem with no \.{\|} in its item line has
no secondary items, and |second| lands just past the used part of |set|.
@<Lay out the XCC set array@>=
s.active, s.itemlen = s.lastItm-1, s.lastItm-1
s.item = ensure(s.item, s.itemlen)
s.set = ensure(s.set, (s.itemlen<<2)+1) // all input slots readable

j := primExtra
k := 0
for ; k < s.itemlen; k++ {
	s.item[k] = int32(j)
	j += primExtra + s.size((k+1)<<2)
}
s.setlen = j - primExtra
s.set = ensure(s.set, j+1)
if s.second == secondUnset {
	s.osecond, s.second = s.active, j
} else {
	s.osecond = s.second - 1
}

@ The second sweep, running backward so the input tallies are read before
their slots are overwritten, fills in each item's size, position, and number
--- and flags as |baditem| any primary item that ended up with no options.
@<Fill in the XCC item headers@>=
for ; k != 0; k-- {
	base := int(s.item[k-1])
	if k == s.second {
		s.second = base
	}
	s.setSize(base, s.size(k<<2))
	if s.size(base) == 0 && k <= s.osecond {
		s.baditem = k
	}
	s.setPos(base, k-1)
	s.setItemNo(base, k)
}

@ The third sweep rewrites every node's |itm| and |loc| from item numbers and
per-item counts into real |set| indices, and drops each node into its slot.
After this, the sparse sets are ready to dance.
@<Repoint the XCC nodes@>=
for k = 1; k < s.lastNode; k++ {
	if s.nd[k].itm < 0 {
		continue
	}
	base := int(s.item[int(s.nd[k].itm)-1])
	loc := base + int(s.nd[k].loc)
	s.nd[k].itm = int32(base)
	s.nd[k].loc = int32(loc)
	s.set[loc] = int32(k)
}

@* Parsing an MCC problem.
The MCC input phase parallels the XCC one; multiplicity bounds are the news.
@<The MCC input phase@>=
func (m *MCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	m.readItemNames(br)
	m.readOptions(br)
}

@<Multiplicity bounds parsing@>@;
@<MCC item-name input@>@;
@<MCC option input@>@;
@<MCC input finalization@>@;

@ An item token may be \.{name} (defaulting to $[1..1]$), \.{high\|name}, or
\.{low:high\|name}; the lone \.{\|} separator between primary and secondary
items is handled by the caller, not here. Secondary items may not carry a
multiplicity, an upper bound of zero is nonsense, and a lower bound may not
exceed the upper.
@<Multiplicity bounds parsing@>=
func mustAtoi(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		failf("illegal number in bound spec: %q", s)
	}
	return n
}

func parseItemSpec(tok string, inSecondary bool) (name string, lower, upper int) {
	if i := strings.IndexByte(tok, '|'); i >= 0 {
		@<Split the bound prefix from the name@>@;
	} else {
		name, lower, upper = tok, 1, 1
	}
	if name == "" {
		failf("item name empty: %q", tok)
	}
	if strings.ContainsAny(name, ":|") {
		failf("illegal character in item name: %q", name)
	}
	return
}

@ @<Split the bound prefix from the name@>=
if inSecondary {
	failf("secondary item cannot have a multiplicity: %q", tok)
}
spec, nm := tok[:i], tok[i+1:]
if j := strings.IndexByte(spec, ':'); j >= 0 {
	lower, upper = mustAtoi(spec[:j]), mustAtoi(spec[j+1:])
} else {
	upper = mustAtoi(spec)
	lower = upper
}
if upper == 0 {
	failf("upper bound is zero: %q", tok)
}
if lower > upper {
	failf("lower bound exceeds upper bound: %q", tok)
}
name = nm

@ Reading the MCC item line differs from the XCC version in one clause: each
name arrives through |parseItemSpec|, and its slack ($upper-lower$) and bound
($upper$) are stashed at the item's coarse input slot for finalization to
pick up.
@<MCC item-name input@>=
func (m *MCC) readItemNames(br *bufio.Reader) {
	@<Find the MCC item line@>@;
	for buf[p] != 0 {
		tok, next := token(buf, p, false)
		if tok == "|" {
			if m.second != secondUnset {
				failf("item name line contains | twice")
			}
			m.second = len(m.names) // the next item's number
		} else {
			name, lower, upper := parseItemSpec(tok, m.second != secondUnset)
			num, ok := m.internName(name)
			if !ok {
				failf("duplicate item name: %s", name)
			}
			slot := num * mccIprop
			m.set = ensure(m.set, slot)
			m.setSlack(slot, upper-lower)
			m.setBound(slot, upper)
		}
		p = skipSpace(buf, next)
	}
	m.lastItm = len(m.names)
}

@ @<Find the MCC item line@>=
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

@ Options are read exactly as in the XCC parser, at |mccIprop| spacing.
@<MCC option input@>=
func (m *MCC) readOptions(br *bufio.Reader) {
	for {
		buf, ok := nextLine(br)
		if !ok {
			break
		}
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
			continue
		}
		m.readOption(buf)
	}
	m.finalize()
}

@ @<MCC option input@>=
func (m *MCC) readOption(buf []byte) {
	spacer := m.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {
		@<Scan one MCC item name and its color@>@;
	}

	if !hasPrimary {
		@<Unwind the MCC option@>@;
		return
	}
	m.nd[spacer].loc = int32(m.lastNode - spacer)
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	m.options++
	m.nd[m.lastNode].itm = int32(spacer + 1 - m.lastNode)
}

@ @<Scan one MCC item name and its color@>=
name, next := token(buf, p, true)
if name == "" {
	failf("empty item name")
}
num, known := m.nameIndex[name]
if !known {
	failf("unknown item name: %s", name)
}
m.createNode(num, spacer, &hasPrimary)
if buf[next] == ':' {
	if num < m.second {
		failf("primary item must be uncolored: %s", name)
	}
	color, ce := token(buf, next+1, false)
	if color == "" {
		failf("missing color after %s:", name)
	}
	m.nd[m.lastNode].clr = int32(m.internColor(color))
	next = ce
} else {
	m.nd[m.lastNode].clr = 0
}
p = skipSpace(buf, next)

@ @<Unwind the MCC option@>=
for m.lastNode > spacer {
	slot := int(m.nd[m.lastNode].itm) * mccIprop
	m.setSize(slot, m.size(slot)-1)
	m.setPos(slot, spacer-1)
	m.lastNode--
}

@ @<MCC option input@>=
func (m *MCC) createNode(num, spacer int, hasPrimary *bool) {
	slot := num * mccIprop
	m.set = ensure(m.set, slot)
	if m.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", m.names[num])
	}
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	t := m.size(slot)
	m.nd[m.lastNode].itm = int32(num)
	m.nd[m.lastNode].loc = int32(t)
	if num < m.second {
		*hasPrimary = true
	}
	m.setSize(slot, t+1)
	m.setPos(slot, m.lastNode)
}

@ MCC finalization runs the same three sweeps and then retires the items that
can be seen, already, to play no part.
@<MCC input finalization@>=
func (m *MCC) finalize() {
	@<Lay out the MCC set array@>@;
	@<Fill in the MCC item headers@>@;
	@<Repoint the MCC nodes@>@;
	m.deactivateOptionless()
}

@ @<Lay out the MCC set array@>=
m.active, m.itemlen = m.lastItm-1, m.lastItm-1
m.item = ensure(m.item, m.itemlen)
m.set = ensure(m.set, m.itemlen*mccIprop+1) // all input slots readable

j := mccExtra
k := 0
for ; k < m.itemlen; k++ {
	m.item[k] = int32(j)
	j += mccExtra + m.size((k+1)*mccIprop)
}
m.setlen = j - mccExtra
m.set = ensure(m.set, j+1)
if m.second == secondUnset {
	m.osecond, m.second = m.active, j
} else {
	m.osecond = m.second - 1
}

@ Alongside size, position, and number, this sweep copies in each primary
item's slack and bound, and the notion of |baditem| sharpens: fatal trouble is
a primary item that cannot even reach its {\it lower\/} bound. A primary item
with lower bound~0 and no options is not trouble at all---it simply never
appears---so it is stacked for the closing sweep, as is any optionless
secondary item.
@<Fill in the MCC item headers@>=
for ; k != 0; k-- {
	base := int(m.item[k-1])
	if k == m.second {
		m.second = base
	}
	m.setSize(base, m.size(k*mccIprop))
	m.setItemNo(base, k)
	m.setSlack(base, m.slack(k*mccIprop))
	m.setBound(base, m.bound(k*mccIprop))
	m.setPos(base, k-1)
	switch {
	case k <= m.osecond && m.size(base) < m.bound(base)-m.slack(base):
		m.baditem = k
	case m.size(base) == 0:
		m.force = ensure(m.force, m.forced+1)
		m.force[m.forced] = int32(base)
		m.forced++
	}
}

@ @<Repoint the MCC nodes@>=
for k = 1; k < m.lastNode; k++ {
	if m.nd[k].itm < 0 {
		continue
	}
	base := int(m.item[int(m.nd[k].itm)-1])
	loc := base + int(m.nd[k].loc)
	m.nd[k].itm = int32(base)
	m.nd[k].loc = int32(loc)
	m.set[loc] = int32(k)
}

@ The closing sweep drains the stack of optionless items, deactivating each so
the search never has to consider them.
@<MCC input finalization@>=
func (m *MCC) deactivateOptionless() {
	for m.forced != 0 {
		m.forced--
		j := int(m.force[m.forced])
		m.active--
		i := int(m.item[m.active])
		pp := m.pos(j)
		m.item[m.active], m.item[pp] = int32(j), int32(i)
		m.setPos(j, m.active)
		m.setPos(i, pp)
	}
}

@** Tests.
A literate program ought to carry its own proof of life. This last part is
woven from the same source, yet it tangles to a {\it separate\/} file,
\.{dcells\_test.go}, by way of GWEB's file-output control code---the one that
names an auxiliary output rather than the main one. Running |go test| then
exercises both engines against small problems whose answers we already know.

The shared helper |collect| runs the XCC solver and renders each solution as
one canonical string---the item names within an option sorted, the options
within a solution sorted, and finally the solutions themselves sorted---so a
test can compare against an expected value without caring in what order they
were found.
@(dcells_test.go@>=
package dcells

import (
	"sort"
	"strings"
	"testing"
)

func collect(t *testing.T, input string) []string {
	t.Helper()
	res := NewXCC().Dance(strings.NewReader(input))
	var sols []string
	for sol := range res.Solutions {
		opts := make([]string, len(sol))
		for i, opt := range sol {
			opts[i] = strings.Join(opt, " ")
		}
		sort.Strings(opts)
		sols = append(sols, strings.Join(opts, " | "))
	}
	sort.Strings(sols)
	return sols
}

@ The plainest test is the textbook one: Knuth's six-option example from {\sl
TAOCP\/} 7.2.2.1, whose only exact cover is $\{a\,d\,f\}$, $\{b\,g\}$,
$\{c\,e\}$. Two more check the color machinery and confirm that an uncoverable
item yields no solution at all.
@(dcells_test.go@>=
func TestExactCover(t *testing.T) {
	// The classic TAOCP 7.2.2.1 example: unique cover {a d f},{b g},{c e}.
	input := "a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n"
	sols := collect(t, input)
	if len(sols) != 1 {
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
	}
	want := "a d f | b g | c e"
	if sols[0] != want {
		t.Errorf("got %q, want %q", sols[0], want)
	}
}

func TestColors(t *testing.T) {
	// Secondary items x,y with colors; two exact covers.
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
	sols := collect(t, input)
	if len(sols) != 2 {
		t.Fatalf("want 2 solutions, got %d: %v", len(sols), sols)
	}
}

func TestNoSolution(t *testing.T) {
	// Item c can never be covered.
	input := "a b c\na b\n"
	res := NewXCC().Dance(strings.NewReader(input))
	n := 0
	for range res.Solutions {
		n++
	}
	if n != 0 {
		t.Errorf("want 0 solutions, got %d", n)
	}
}

@ Item names and colors are arbitrary strings, so the next test uses a
multi-character color (\.{England}) and checks that the name survives into the
output---exactly what the zebra and word-search examples rely on.
@(dcells_test.go@>=
func TestMultiCharColorAndLongNames(t *testing.T) {
	input := "house1 house2 | nationality\n" +
		"house1 nationality:England\nhouse2 nationality:England\n"
	sols := collect(t, input)
	if len(sols) != 1 {
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
	}
	// Each option keeps its color name in the output.
	if !strings.Contains(sols[0], "nationality:England") {
		t.Errorf("color name lost: %q", sols[0])
	}
}

@ A sterner exercise encodes the $n$-queens problem as exact cover---rows
and columns as primary items, the two diagonal families as secondary---and
checks the solution counts against their known values (4, 40, and 92 for
$n=6,7,8$). The two-digit |itoa| keeps the generated item names short and
aligned.
@(dcells_test.go@>=
func nQueensCount(t *testing.T, n int) int {
	t.Helper()
	var b strings.Builder
	for i := 0; i < n; i++ {
		b.WriteString(itoa("r", i))
	}
	for j := 0; j < n; j++ {
		b.WriteString(itoa("c", j))
	}
	b.WriteString("|")
	for k := 0; k < 2*n-1; k++ {
		b.WriteString(itoa(" a", k))
	}
	for k := 0; k < 2*n-1; k++ {
		b.WriteString(itoa(" b", k))
	}
	b.WriteString("\n")
	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			b.WriteString(itoa("r", i))
			b.WriteString(itoa("c", j))
			b.WriteString(itoa("a", i+j))
			b.WriteString(itoa("b", i-j+n-1))
			b.WriteString("\n")
		}
	}
	res := NewXCC().Dance(strings.NewReader(b.String()))
	n2 := 0
	for range res.Solutions {
		n2++
	}
	return n2
}

func itoa(prefix string, x int) string {
	return prefix + string(rune('0'+x/10)) + string(rune('0'+x%10)) + " "
}

func TestQueens(t *testing.T) {
	// Known n-queens solution counts.
	for n, want := range map[int]int{6: 4, 7: 40, 8: 92} {
		if got := nQueensCount(t, n); got != want {
			t.Errorf("%d-queens: got %d, want %d", n, got, want)
		}
	}
}

@ The multiplicity engine gets its own battery. |countMCC| just counts what
the MCC solver finds, and the cases below probe an exact count (\.{2\|a}), a
slack range (\.{1:2\|a}), and a richer mix cross-checked against
\.{cmd/ssmcc}.
@(dcells_test.go@>=
func countMCC(t *testing.T, input string) int {
	t.Helper()
	res := NewMCC().Dance(strings.NewReader(input))
	n := 0
	for range res.Solutions {
		n++
	}
	return n
}

func TestMCCMultiplicity(t *testing.T) {
	// "a" must be covered exactly twice (2|a); the only cover is {ab, ac}.
	input := "2|a b c\na b\na c\nb c\n"
	if n := countMCC(t, input); n != 1 {
		t.Errorf("exact-twice: got %d solutions, want 1", n)
	}
}

func TestMCCSlack(t *testing.T) {
	// "a" covered 1..2 times; b, c exactly once. One cover: {ab, ac}.
	input := "1:2|a b c\na b\na c\nb c\n"
	if n := countMCC(t, input); n != 1 {
		t.Errorf("slack: got %d solutions, want 1", n)
	}
}

func TestMCCRicher(t *testing.T) {
	// Cross-checked against cmd/ssmcc: 4 solutions.
	input := "1:3|a 2|b c d\na b\na c\na d\nb c\nb d\nc d\na b c\n"
	if n := countMCC(t, input); n != 4 {
		t.Errorf("richer: got %d solutions, want 4", n)
	}
}

@ Finally, two sanity checks that the MCC engine subsumes the plain one: with
default multiplicities it must reproduce ordinary XCC---the same 92
solutions to 8-queens---and the color machinery must work there too.
@(dcells_test.go@>=
func TestMCCPlainXCC(t *testing.T) {
	n := 8
	var b strings.Builder
	for i := 0; i < n; i++ {
		b.WriteString(itoa("r", i))
	}
	for j := 0; j < n; j++ {
		b.WriteString(itoa("c", j))
	}
	b.WriteString("|")
	for k := 0; k < 2*n-1; k++ {
		b.WriteString(itoa(" a", k))
	}
	for k := 0; k < 2*n-1; k++ {
		b.WriteString(itoa(" b", k))
	}
	b.WriteString("\n")
	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			b.WriteString(itoa("r", i))
			b.WriteString(itoa("c", j))
			b.WriteString(itoa("a", i+j))
			b.WriteString(itoa("b", i-j+n-1))
			b.WriteString("\n")
		}
	}
	if got := countMCC(t, b.String()); got != 92 {
		t.Errorf("8-queens via MCC: got %d, want 92", got)
	}
}

func TestMCCColors(t *testing.T) {
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
	if n := countMCC(t, input); n != 2 {
		t.Errorf("colors: got %d solutions, want 2", n)
	}
}

@** Index.
