\def\title{SSXCC}

@s Context int
@s Duration int
@s Ticker int
@s Reader int
@s Builder int
@s Time int

@** Introduction.
This is {\tt SSXCC}: exact cover with colors, danced on sparse sets. It is one
of the two engines of the |dcells| package, and it reads on its own. What it
borrows from its companion document \.{dcells.w}---the |Option| and |Result|
types, the |node| array, |ensure|, and the scanner that turns {\tt DLX} text
into tokens---is described there; the sparse sets it dances on are recalled
below in brief, and told at more leisure there.

{\it Primary\/} items must be covered exactly once; {\it secondary\/} items may
be covered any number of times provided every option that touches one agrees
on its color. The search branches the way Algorithm~X does: it picks the item
with the fewest surviving options and tries them all, a {\it $d$-way\/}
fan-out. Its sibling {\tt SSMCC} (\.{ssmcc.w}) relaxes ``exactly once'' to a
range and must branch differently; that is why the two are separate programs
rather than one program with a switch.

A late chapter adds a second question to the first. Once every option carries
a price, ``is there a cover?'' becomes ``what is the cheapest cover?'', and
the same search answers it by branch and bound.
@c
package dcells

import (
	"bufio"
	"cmp"
	"context"
	"fmt"
	"io"
	"os"
	"slices"
	"strings"
	"time"
)

@<The engine@>
@<The optimizer@>
@<The input phase@>

@ Sparse sets are the whole trick, so here they are in a paragraph. To
represent a subset $S$ of a universe $U=\{x_0,\ldots,x_{n-1}\}$, keep two
arrays $p$ and $q$ that are inverse permutations of each other, together with
a count~$s$; the members of $S$ are exactly $x_{p_0},\ldots,x_{p_{s-1}}$. Then
$x_k\in S$ iff $q_k<s$; to delete a member, swap it to position $s-1$ and
decrease~$s$; to insert, swap it to position~$s$ and increase~$s$. No list, no
links---just two permutations learning to dance. Preston Briggs and Linda
Torczon distilled the idea in 1993 [{\sl ACM Letters on Programming Languages
and Systems\/ \bf2}, 59--69] from an exercise of Aho, Hopcroft, and Ullman.

@ The matrix lives in three flat arrays. |nd| holds the options as runs of
{\it nodes}, one node per item of an option, with spacer nodes marking the
seams. |item| lists the still-active items, playing the role of the
permutation~$p$ above. And |set| holds, for each item, the options that
currently contain it: an item is named by its base index~|x| into |set|, its
surviving options are |set[x]| and the |size(x)-1| entries after it, and
|pos(x)| plays~$q$, recording that this item sits at |item[pos(x)]|. Covering
an item is then nothing but shrinking a count and swapping two array
slots---the sparse-set delete, done over and over. The slots just below each
base hold that bookkeeping, and named accessors below read and write them.

@ The solver struct is assembled from several blocks of state, given names
here so that the struct itself reads as a list of its concerns. First, the
public knobs. |Debug| turns on the same terse input-summary and final-tally
lines that the |dlx| library prints to |stderr|; |PulseInterval|, if positive,
asks for periodic heartbeats.
@<Solver knobs@>=
Debug         bool          // print input summary and final stats to stderr
PulseInterval time.Duration // if > 0, offer periodic Heartbeat strings

@ Names and colors are arbitrary strings, so the engine interns them: each
distinct name becomes a small integer (1-based, since index~0 is a
placeholder), and each color likewise. The maps double as duplicate detectors.
@<Naming tables@>=
names      []string // interned item names, by item number (1-based)
nameIndex  map[string]int
colorNames []string // interned colors, by id (1-based; 0 means "no color")
colorIndex map[string]int

@ The search keeps a {\it force stack\/} of items whose next move is no longer
a choice---forced moves will be a recurring character in this story---and
counters of search effort. An ``update'' is one sparse-set swap; a ``node'' is
one visit to the recursive search.
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


@** The engine.
Now the solver itself, from the top. The algorithm is Algorithm~X in sparse-set
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
@<The engine@>=
@<Bookkeeping@>
@<The solver state@>
@<Creating a solver@>
@<Set accessors@>
@<Interning@>
@<Launching the dance@>
@<The search@>
@<Choosing the item@>
@<Committing an option@>
@<Hiding conflicting options@>
@<Covering an item@>
@<The undo machinery@>
@<Visiting a solution@>
@<The heartbeat@>
@<Reporting an option@>

@ Two small declarations open it. Each item reserves four slots just below
its base in |set|---its size, its position, its item number, and one
spare---and each entry of the save stack remembers an item together
with the size it had before the branch, so that undoing is a matter of writing
that pair back.
@<Bookkeeping@>=
const primExtra = 4 // set entries reserved below each item's base

type twoints struct {
	l, r int32
}

@* State and construction.
An |XCC| value carries the entire state of one computation. Besides the
shared blocks we prepared earlier, it owns the matrix arrays---|nd|, |item|,
|set|, with |second| marking the boundary between primary and secondary items
--- and the arrays that record the search path: |choice| holds the option
chosen at each level, and |saved|/|savestack| snapshot sizes for backtracking.
@<The solver state@>=
type XCC struct {
	@<Solver knobs@>
	ctx context.Context

	@<The matrix arrays@>
	@<Naming tables@>
	@<The force stack@>
	@<The backtrack arrays@>
	@<Cost bookkeeping@>
	@<Search statistics@>
	@<Output channels@>
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

@ @<The backtrack arrays@>=
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
@<Creating a solver@>=
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
@<Set accessors@>=
func (s *XCC) size(x int) int   { return int(s.set[x-1]) }
func (s *XCC) pos(x int) int    { return int(s.set[x-2]) }
func (s *XCC) itemNo(x int) int { return int(s.set[x-3]) }

func (s *XCC) setSize(x, v int)   { s.set[x-1] = int32(v) }
func (s *XCC) setPos(x, v int)    { s.set[x-2] = int32(v) }
func (s *XCC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

@ Interning a name registers it the first time and rejects a duplicate;
interning a color happily returns the existing id on later sightings, because
many options may share a color.
@<Interning@>=
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

@* The dance.
|Dance| reads the matrix (panicking on malformed input), opens the channels,
and launches the search in a goroutine; it returns at once, and the goroutine
closes both channels when it is done, so a |range| over the solutions
terminates naturally.
@<Launching the dance@>=
func (s *XCC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)
	@<Launch the search goroutine@>
}

@ The launch itself is set down as a section rather than a function, because
|Minimize| in a later chapter wants precisely these lines after it has done
its own preparation. A |baditem|---a primary item that ended the input with no
options at all---makes the whole problem trivially unsolvable, so the search
is skipped and the channels simply close.
@<Launch the search goroutine@>=
s.solStream = make(chan []Option)
s.heartbeat = make(chan string)

go func() {
	defer close(s.solStream)
	defer close(s.heartbeat)

	@<Report the input summary@>
	if s.PulseInterval > 0 {
		s.pulse = time.NewTicker(s.PulseInterval)
		defer s.pulse.Stop()
	}

	if s.baditem == 0 {
		s.search(0)
	}

	@<Report the totals@>
}()

return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}

@ Under |Debug| we bracket the search with the same summary lines the |dlx|
library prints, down to the fussy singular/plural of ``solutions.''
@<Report the input summary@>=
if s.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
}

@ @<Report the totals@>=
if s.Debug {
	plural := "s"
	if s.count == 1 {
		plural = ""
	}
	fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
		s.count, plural, s.updates, s.nodes)
}

@ The search is one recursive function. At each node it counts a step, gives
the context a chance to abort, and offers a heartbeat; then---if we are out
for the cheapest cover rather than every cover---it weighs the branch against
the best one found so far, and only then asks |chooseItem| where to branch. A
|false| return, here and below, means ``unwind the entire search''---the
caller has walked away or cancelled---and it propagates up through every
level.
@<The search@>=
func (s *XCC) search(level int) bool {
	s.nodes++
	select {
	case <-s.ctx.Done():
		return false
	default:
	}
	s.tick()
	@<Give up on this branch if it cannot beat the cutoff@>
	@<Sweep away the options this node can no longer afford@>

	best, solution := s.chooseItem()
	if solution {
		return s.visit(level)
	}
	@<Cover |best| and try each of its options in turn@>
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
undone just the same. The running total |s.cost| rises and falls with the
choice, so that at every node it holds exactly the price of the options
committed above it; and |s.taxDue|, the tax still owed by the items not yet
covered, falls and rises with it by the tax this option pays.
@<Cover |best| and try each of its options in turn@>=
s.swapOut(best)
s.oactive = s.active
s.hide(best, 0, 0)
s.saveSizes(level)
s.choice = ensure(s.choice, level+1)
for c := best; c < best+s.size(best); c++ {
	opt := int(s.set[c])
	s.choice[level] = int32(opt)
	@<Price this option@>
	@<Skip this option if the cutoff has overtaken it@>
	s.cost += price
	s.taxDue -= tax
	if s.commitOption(opt) {
		if !s.search(level + 1) {
			return false
		}
	}
	s.restoreSizes(level)
	s.cost -= price
	s.taxDue += tax
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
@<Choosing the item@>=
func (s *XCC) chooseItem() (best int, solution bool) {
	for s.forced != 0 {
		s.forced--
		if f := int(s.force[s.forced]); s.pos(f) < s.active {
			return f, false
		}
	}
	@<Scan the active primaries for the emptiest@>
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

@* Covering and undoing.
Committing to option |opt| is where the real covering happens, in two passes
over the option's nodes. (An option's nodes are contiguous, bracketed by
spacers whose |itm| is non-positive; starting just past |opt| and following
the spacer offsets walks the whole option round-robin.) The first pass swaps
every other item of the option out of the active list, so no future choice
can land on them. The second pass hides the options that now conflict. If any
primary item would be left uncoverable, we abandon the commit---clearing the
force stack, whose pending entries died with the branch.
@<Committing an option@>=
func (s *XCC) commitOption(opt int) bool {
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
		@<Delete option |tt| from the sets of its other items@>
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
		@<Veto or force item |u| if it is running out@>
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
@<Covering an item@>=
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
@<The undo machinery@>=
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

@* Reporting.
Reaching a solution, we materialize it from the |choice| stack---one option
per level---and send it down the channel. The send is the pacing point: if
the consumer has abandoned the range, or the context is cancelled, the other
arm of the select fires and the whole search unwinds. When we are minimizing,
a cover that gets this far is also cheaper than the dearest one on the
podium---the test at the head of |search| turned back every branch that could
not beat it---so it takes that one's place without further ado. (A plain
|Dance| has no podium and never looks for one.)
@<Visiting a solution@>=
func (s *XCC) visit(level int) bool {
	s.count++
	if s.minimizing {
		@<Put the new cover on the podium@>
	}
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
@<The heartbeat@>=
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
@<Reporting an option@>=
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

@** Least-cost covers.
Many a problem has more exact covers than anyone cares to look at, and the
interesting question is not {\it which\/} but {\it how cheap}: put a price on
every option and ask for a cover of least total price. Minimum-cost
assignment, minimum-weight perfect matching, cheapest set partitioning---each
is this question wearing a hat, and each is exact cover with a price list
stapled on.

Branch and bound answers it. Keep an {\it incumbent}, the price of the best
cover so far, infinite until the first one turns up. At every node ask whether
this branch could possibly beat it; if not, turn back. Half of that sum is
known exactly---the options committed above this node have a price---and for
the other half the caller may supply a {\it lower bound\/} on what finishing
the cover must still cost. With no such oracle the incumbent alone still
prunes, since a partial cover already dearer than a finished one is hopeless,
and that much comes free.

Three refinements come from Knuth's {\tt DLX5}, the dancing-links solver in
which he first taught Algorithm~X to count money. The first is a {\it tax\/}
on every primary item, which gives the search a lower bound of its own, free
of charge, whether or not the caller supplies one; it is explained where it is
levied. The second puts the tax to work a second time, sweeping away at every
node the options that the node can no longer afford; {\tt DLX5} does that
with sorted lists, which sparse sets cannot keep, so here it takes a different
shape. The third is to hunt for the $k$
cheapest covers instead of the single cheapest one. Keep the prices of the
best $k$ covers found so far on a {\it podium\/} and let the dearest of them
be the {\it cutoff}, the price a branch has to beat to be worth exploring.
When $k=1$ the podium holds one cover and the cutoff is the incumbent. (The
cutoff rule itself is old: Garfinkel and Nemhauser used it in one of the first
programs for least-cost exact cover [{\sl Operations Research\/ \bf17}
(1969), 848--856].)

@ Nothing in this chapter disturbs |Dance|. The optimizing entry point is a
second one, |Minimize|, and when it is not in use the search runs the code it
ran before, one boolean test the poorer. Callers see three new names: the
entry point itself and two knobs, |Bound| and |Best|. The |Frame| a bound
function looks through belongs to \.{dcells.w}, since both engines offer the
same one, and what is left here is the four answers this engine gives it.
@<The optimizer@>=
@<The minimizing entry point@>
@<Answering the frame@>

@ The bound oracle is a knob like the others, and like the others it may be
left alone. |Bound| is called at every node of a minimizing search and must
return a lower bound on the price of {\it completing\/} the partial cover
before it---never an overestimate, or the search will prune away the answer.
Returning~0 is always safe and always useless. At a node that is about to
turn out to be a solution the frame is empty and any sensible bound is zero.
@<Solver knobs@>=
Bound func(Frame) int // lower bound on the cost still to come; may be nil

@ The size of the podium is a knob too. |Best| asks for the |Best| cheapest
covers, and left at zero it means one, the plain minimization.
@<Solver knobs@>=
Best int // with Minimize, how many of the cheapest covers to hunt for

@ The private half of the bookkeeping. Options are numbered $1,2,\ldots$ in
the order they were read, |optNo| maps each node to the number of the option
it belongs to, |optCost| holds the price the caller put on each, and |optTax|
holds the part of that price that is tax. All of them stay nil until
|Minimize| builds them, which is what |minimizing| really means.
@<Cost bookkeeping@>=
minimizing bool
optNo      []int32 // node -> the option that node belongs to
optCost    []int32 // option number -> the price the caller put on it
optTax     []int64 // option number -> the tax included in that price
itemBase   []int32 // item number -> its base in |set|
cost       int64   // price of the options committed so far
taxDue     int64   // total tax on the primary items not yet covered
podium     []int64 // prices of the |Best| cheapest covers so far, a max-heap
byNet      []pricedOpt // every option, dearest net cost first
sweptAt    []int32     // level -> how far along |byNet| that node has swept

@ |Minimize| reads the same input |Dance| does, prices it, and starts the same
search. With |Best| left alone, what arrives on |Solutions| is a chain of
covers each strictly cheaper than the last, so a caller who keeps only the
newest ends up holding an optimal one; a caller who wants to watch the
improvement come in can print them all. If the problem has no cover at all,
nothing arrives.

With |Best| set to some $k>1$ the chain is no longer monotone. A cover arrives
whenever it is cheaper than the $k$th cheapest one seen so far, and once the
search is over the $k$ cheapest covers that arrived are $k$ cheapest covers of
the problem---or all of its covers, if it has fewer than~$k$. The reason is
that the cutoff never rises: a cover turned away was no cheaper than the
cutoff of its day, and so no cheaper than the $k$ that are on the podium at
the end. Among covers of the same price, which ones make the podium is a
matter of luck.

The price list is a function rather than a slice because an option's number is
an awkward thing for a caller to keep count of: blank lines, comments, and
options that mention no primary item all pass by without consuming a number.
So we hand the caller both the number and the option itself, in the very shape
solutions arrive in, and let it answer. The number is worth having anyway---it
is the same handle a |Bound| function will see later.
@<The minimizing entry point@>=
func (s *XCC) Minimize(rd io.Reader, cost func(o int, opt Option) int) *Result {
	s.inputMatrix(rd)
	@<Price the options@>
	@<Levy a tax on every primary item@>
	@<Line up the options by net cost@>
	@<Set up the podium@>
	s.minimizing = true
	@<Launch the search goroutine@>
}

@ Pricing is one sweep over the nodes. Real nodes have a positive |itm| and
spacers do not, so a node whose predecessor is a spacer begins a fresh option:
we advance the option number, ask the caller what that option is worth, and
paint the number over the run of nodes that follows.
@<Price the options@>=
s.optNo = make([]int32, s.lastNode+1)
s.optCost = make([]int32, int(s.options)+1)
o := int32(0)
for k := 1; k < s.lastNode; k++ {
	if s.nd[k].itm <= 0 {
		continue // a spacer between two options
	}
	if s.nd[k-1].itm <= 0 {
		o++
		s.optCost[o] = int32(cost(int(o), s.option(k)))
	}
	s.optNo[k] = o
}
@<Index the items by number@>

@ The frame answers questions about an item by its {\it number}, while the
dance knows items by their {\it base\/} in |set|, so one table has to bridge
the two. The bases are all sitting in |item| right now, in whatever order
finalization left them, and each one carries its own number.
@<Index the items by number@>=
s.itemBase = make([]int32, s.itemlen+1)
for k := 0; k < s.itemlen; k++ {
	base := int(s.item[k])
	s.itemBase[s.itemNo(base)] = int32(base)
}

@ Now the tax. Every cover takes exactly one option from the set of each
primary item, so if we charge an item a tax~$t$ and knock $t$ off the price of
every option that contains it, each cover gets exactly $t$ cheaper; the
cheapest cover stays the cheapest. What is left of an option's price after all
its items have been taxed Knuth calls its {\it net cost}. Take for $t$ the
least net cost among the item's options at the moment it is taxed, and two
things happen together. No net cost goes negative, since an option containing
the item cost at least $t$ before. And the cheapest option in that item's set
now costs nothing net, which it goes on doing, since a later tax never exceeds
it.

Why bother, when the answer does not change? Because the running price of a
partial cover does not see this shuffling, while the covers still to come do.
The options that finish the cover must between them cover every primary item
still active, each exactly once, and each costs its tax plus a net cost that
is not negative. So the tax on the active items, |taxDue|, is a lower bound on
what is left to pay---found without looking at a single option, and kept up
to date by one subtraction per committed option. It is exactly what {\tt
DLX5} gets by comparing net costs with net costs, told in the caller's
currency.

A bonus comes with it. The argument never asks a price to be positive: a tax
may be negative, and it is net costs that must not be. So a caller may put
negative prices on options, as long as every option contains a primary
item---and in this engine every option does, since the input drops the ones
that contain none.
@<Levy a tax on every primary item@>=
s.optTax = make([]int64, len(s.optCost))
s.taxDue = 0
for k := 0; k < s.active; k++ {
	x := int(s.item[k])
	if x >= s.second || s.size(x) == 0 {
		continue // a secondary item pays no tax; nor does one without options
	}
	@<Find the least net cost |t| among the options of item |x|@>
	for c := x; c < x+s.size(x); c++ {
		s.optTax[s.optNo[int(s.set[c])]] += t
	}
	s.taxDue += t
}

@ The net cost of an option is its price minus the tax it has paid so far.
@<Find the least net cost |t| among the options of item |x|@>=
t := infCost
for c := x; c < x+s.size(x); c++ {
	o := s.optNo[int(s.set[c])]
	t = min(t, int64(s.optCost[o])-s.optTax[o])
}

@ The podium starts out as |Best| empty places, each at the price |infCost|,
so the first |Best| covers step onto it unopposed.
@<Set up the podium@>=
s.podium = make([]int64, max(s.Best, 1))
for i := range s.podium {
	s.podium[i] = infCost
}

@ Here is the pruning test, spliced into the head of |search|. Returning
|true| abandons this branch and lets the search go on elsewhere; only
cancellation returns |false|. What the rest of the cover must still cost is
at least the tax still owed, and at least whatever the caller's |Bound| says,
so it is at least the larger of the two. The cutoff is the top of the podium.
The comparison is |>=| rather than |>|, so a cover merely tying the cutoff is
cut off too---which is why, with |Best| at one, the covers that do arrive are
strictly improving.
@<Give up on this branch if it cannot beat the cutoff@>=
if s.minimizing {
	rest := s.taxDue
	if s.Bound != nil {
		rest = max(rest, int64(s.Bound(Frame{s})))
	}
	if s.cost+rest >= s.podium[0] {
		return true
	}
}

@ And here is the price of one option, and the tax included in it, looked up
twice per branch---once on the way down, once on the way back---from a node
inside it. A plain |Dance| never built the tables, so it pays nothing but the
test.
@<Price this option@>=
price, tax := int64(0), int64(0)
if s.minimizing {
	o := s.optNo[opt]
	price, tax = int64(s.optCost[o]), s.optTax[o]
}

@ A new cover goes onto the podium in place of the dearest one there, which
sits at the root of the heap. The newcomer starts at the root as well and
sinks, trading places with its dearer child, until neither child is dearer
than it is. The new root is the new cutoff.
@<Put the new cover on the podium@>=
h, i := s.podium, 0
for j := 1; j < len(h); j = 2*i + 1 {
	if j+1 < len(h) && h[j+1] > h[j] {
		j++ // the dearer child
	}
	if h[j] <= s.cost {
		break
	}
	h[i] = h[j]
	i = j
}
h[i] = s.cost

@ The tax does more than supply a bound. Suppose a node has committed options
costing |cost| and still owes |taxDue|, and let $o$ be an option with net cost
$\nu(o)$. A cover that uses $o$ below this node costs at least
$|cost|+|taxDue|+\nu(o)$: the options already committed, then $o$ itself,
which pays its own items' taxes plus $\nu(o)$, then the tax on the items it
leaves for others. If that is not below the cutoff, $o$ is useless anywhere
beneath this node. Going deeper only raises $|cost|+|taxDue|$, since each
option committed adds its net cost, which is not negative; and the cutoff only
falls. Call $|cutoff|-|cost|-|taxDue|$ the node's {\it budget}. An option whose
net cost is not under budget can be thrown away.

{\tt DLX5} does this cheaply by keeping each item's list sorted by net cost, so
that covering an item stops the moment it meets an option over budget. The
trick needs the lists to stay sorted, and dancing links keep them so:
unlinking a node leaves its neighbors in their old order. Sparse sets do not.
A deletion swaps the departing option with the last one in the set, and a
single deletion scrambles the order for good. So we sort something else,
something that never moves: the list |byNet| of all the options, dearest net
cost first. The options over a node's budget form a prefix of that list, and
because budgets only shrink on the way down, a child's prefix extends its
parent's. So each node picks up where its parent stopped, walks forward while
the net cost is not under budget, and deletes each option it passes from the
sets of the active items that still hold it. |sweptAt[level]| records where it
stopped.

Undoing costs nothing. The deletions are the same sparse-set swaps that |hide|
makes, and the sizes that |restoreSizes| writes back when the parent moves on
re-admit every option a child swept away. This is one place where dancing
cells come out ahead: {\tt DLX5} must uncover with exactly the thresholds it
covered with, because its cutoff moves in the meantime, while a restored size
does not care. Only the sets of {\it active\/} items may be touched, though.
The item an ancestor branched on is inactive, and that ancestor's loop is
walking its set at this very moment. Swapping entries there would make the
loop skip one option and try another twice.

The sweep sharpens everything after it. An item whose options are all over
budget is dead, and the branch is given up at once. The sizes that
|chooseItem| compares now count only the options this node can afford, so the
rule of minimum remaining values sees the problem as it really is. And a
caller's |Bound| sees the same smaller matrix through its |Frame|.
@<Sweep away the options this node can no longer afford@>=
if s.minimizing {
	budget := s.podium[0] - s.cost - s.taxDue
	p := 0
	if level > 0 {
		p = int(s.sweptAt[level-1])
	}
	for ; p < len(s.byNet) && s.byNet[p].net >= budget; p++ {
		@<Delete option |s.byNet[p]| from the active sets, or give up@>
	}
	s.sweptAt = ensure(s.sweptAt, level+1)
	s.sweptAt[level] = int32(p)
}

@ The deletion is the one in |hide|, with two differences. An option may
already be gone from some of its sets---hidden by a commitment higher up, or
swept away by an ancestor---and there is nothing to do there. And a primary
item left with no option at all ends the branch. Giving up in the middle of an
option leaves it deleted from some sets and not others, but that does no harm,
because the parent's |restoreSizes| is the next thing to happen. At the root
there is no parent, and giving up there means the search is over.
@<Delete option |s.byNet[p]| from the active sets, or give up@>=
for nn := int(s.byNet[p].node); s.nd[nn].itm > 0; nn++ {
	u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
	if s.pos(u) >= s.active || v >= u+s.size(u) {
		continue // an inactive item, or one this option has already left
	}
	ss := s.size(u) - 1
	if ss == 0 && u < s.second {
		return true // a primary item has nothing left that it can afford
	}
	nnp := int(s.set[u+ss])
	s.setSize(u, ss)
	s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
	s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
	s.updates++
}

@ The line is laid out once, after the tax, since the net costs are fixed from
then on. Its entries are of the type |pricedOpt| from \.{dcells.w}: an
option's first node, where the deletion above starts walking, and its net
cost. A stable sort keeps options of equal net cost in input order.
@<Line up the options by net cost@>=
s.byNet = s.byNet[:0]
for k := 1; k < s.lastNode; k++ {
	if s.nd[k].itm > 0 && s.nd[k-1].itm <= 0 {
		o := s.optNo[k]
		s.byNet = append(s.byNet,
			pricedOpt{int32(k), int64(s.optCost[o]) - s.optTax[o]})
	}
}
slices.SortStableFunc(s.byNet, func(a, b pricedOpt) int {
	return cmp.Compare(b.net, a.net)
})

@ An option can fall over budget while its elder siblings are being explored,
since every cover they find lowers the cutoff. The head of |search| would turn
it back, but only after |commitOption| had done its work. Checking first costs
one comparison.
@<Skip this option if the cutoff has overtaken it@>=
if s.minimizing && s.cost+price+s.taxDue-tax >= s.podium[0] {
	continue
}

@ Here are this engine's four answers to the frame. Walking the live part of
the matrix means walking the active items, skipping the secondary ones---they
demand nothing of their own---and running along each survivor's set.
@<Answering the frame@>=
func (s *XCC) eachLive(yield func(item, opt int) bool) {
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue
		}
		i := s.itemNo(x)
		for c := x; c < x+s.size(x); c++ {
			if !yield(i, int(s.optNo[int(s.set[c])])) {
				return
			}
		}
	}
}

@ The other three are lookups. An item still active under |XCC| wants covering
exactly once more, which is the whole of what ``exact'' means here; a
secondary item wants nothing.
@<Answering the frame@>=
func (s *XCC) optionCost(opt int) int { return int(s.optCost[opt]) }
func (s *XCC) itemName(item int) string { return s.names[item] }

func (s *XCC) itemNeed(item int) int {
	if int(s.itemBase[item]) < s.second {
		return 1
	}
	return 0
}

@** Reading the DLX input.
The {\tt DLX} text format---an item line, then one line per option---is
described in \.{dcells.w}, together with the small scanner that this phase
leans on: |nextLine|, |token|, |skipSpace|, and |failf| for the malformed
input that a caller should never have written. What remains is the part that
knows about {\it this\/} engine's arrays, and here it is, in the order the
dance driver invokes it. Parsing happens in two phases---the item line, then
the options---followed by a {\it finalization\/} that lays out the sparse sets
the dance expects.
@<The input phase@>=
func (s *XCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

@<Item-name input@>
@<Option input@>
@<Input finalization@>

@ The item line is the first line that is neither blank nor a comment. Walking
it token by token, a lone \.{\|} switches us from primary to secondary items
(and may appear only once); anything else is a name, checked for the forbidden
characters \.{:} and \.{\|} and for duplication before it is interned. At the
end, |lastItm| is the item count plus one, since |names[0]| is unused.
@<Item-name input@>=
func (s *XCC) readItemNames(br *bufio.Reader) {
	@<Find the item line@>
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

@ Each remaining line is one option; blanks and comments are skipped, and the
end of the stream triggers finalization.
@<Option input@>=
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
@<Option input@>=
func (s *XCC) readOption(buf []byte) {
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

@ A color may follow a name after a colon---but only on a secondary item.
@<Scan one item name and its color@>=
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
@<Unwind the option@>=
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
@<Option input@>=
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
@<Input finalization@>=
func (s *XCC) finalize() {
	@<Lay out the set array@>
	@<Fill in the item headers@>
	@<Repoint the nodes@>
}

@ The first sweep assigns each item a compact base in |set|---leaving
|primExtra| reserved slots below it---and converts the primary/secondary
boundary into those coordinates. A problem with no \.{\|} in its item line has
no secondary items, and |second| lands just past the used part of |set|.
@<Lay out the set array@>=
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
@<Fill in the item headers@>=
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
@<Repoint the nodes@>=
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

@** Tests.
A literate program ought to carry its own proof of life. This last part is
woven from the same source, yet it tangles to a {\it separate\/} file,
\.{ssxcc\_test.go}, by way of GWEB's file-output control code---the one that
names an auxiliary output rather than the main one. Running |go test| then
exercises the engine against small problems whose answers we already know.

The shared helper |collect| runs the solver and renders each solution as
one canonical string---the item names within an option sorted, the options
within a solution sorted, and finally the solutions themselves sorted---so a
test can compare against an expected value without caring in what order they
were found.
@(ssxcc_test.go@>=
package dcells

import (
	"fmt"
	"math/rand"
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
@(ssxcc_test.go@>=
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
@(ssxcc_test.go@>=
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
$n=6,7,8$). Generating the board is kept apart from counting its covers,
because the minimization tests below want the same board at a different price.
@(ssxcc_test.go@>=
func nQueensInput(n int) string {
	var b strings.Builder
	@<Write the $n$-queens item line@>
	@<Write the $n$-queens options@>
	return b.String()
}

@ Rows and columns are the primary items; the two diagonal families, which a
queen may leave uncovered, are secondary. The two-digit |itoa| keeps the
generated names short and aligned.
@<Write the $n$-queens item line@>=
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

@ One option per square, naming the row, the column, and the two diagonals
that meet there---in that order, which the pricing below relies on.
@<Write the $n$-queens options@>=
for i := 0; i < n; i++ {
	for j := 0; j < n; j++ {
		b.WriteString(itoa("r", i))
		b.WriteString(itoa("c", j))
		b.WriteString(itoa("a", i+j))
		b.WriteString(itoa("b", i-j+n-1))
		b.WriteString("\n")
	}
}

@ @(ssxcc_test.go@>=
func nQueensCount(t *testing.T, n int) int {
	t.Helper()
	res := NewXCC().Dance(strings.NewReader(nQueensInput(n)))
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

@ Minimization gets a problem small enough to check by hand. Over the items
|a|, |b|, |c| there are five priced options and exactly three covers:
$\{abc\}$ at~10, $\{ab\}+\{c\}$ at~3, and $\{a\}+\{bc\}$ at~7. The prices are
keyed by the option's printed form so that the test can add up a returned
cover the same way it quoted the price in the first place. Whatever order the
search stumbles on them in, what arrives must be strictly cheaper each time,
and the last must cost~3.
@(ssxcc_test.go@>=
func TestMinimize(t *testing.T) {
	input := "a b c\na b c\na b\nc\na\nb c\n"
	price := map[string]int{"a b c": 10, "a b": 1, "c": 2, "a": 4, "b c": 3}
	res := NewXCC().Minimize(strings.NewReader(input),
		func(_ int, opt Option) int { return price[strings.Join(opt, " ")] })
	var seen []int
	for sol := range res.Solutions {
		c := 0
		for _, opt := range sol {
			c += price[strings.Join(opt, " ")]
		}
		seen = append(seen, c)
	}
	@<Check that the covers improve, ending at 3@>
}

@ @<Check that the covers improve, ending at 3@>=
if len(seen) == 0 {
	t.Fatal("no cover found")
}
for i := 1; i < len(seen); i++ {
	if seen[i] >= seen[i-1] {
		t.Fatalf("costs not strictly decreasing: %v", seen)
	}
}
if got := seen[len(seen)-1]; got != 3 {
	t.Errorf("cheapest cover costs %d, want 3", got)
}

@ A sterner test prices the $n$-queens board: a queen costs the square of her
distance from the main diagonal, so the cheapest placement is the one that
hugs it. Enumerating all 92 solutions for $n=8$ and taking the least gives the
answer to beat; |Minimize| must reach the same number both with a bound
function and without one.
@(ssxcc_test.go@>=
func queenPrice(opt Option) int {
	d := digits(opt[0]) - digits(opt[1]) // the row item, then the column item
	if d < 0 {
		d = -d
	}
	return d * d
}

func digits(name string) int { return int(name[1]-'0')*10 + int(name[2]-'0') }

func coverPrice(sol []Option) int {
	c := 0
	for _, opt := range sol {
		c += queenPrice(opt)
	}
	return c
}

@ Here is a lower bound that is sound for any prices that are not negative:
every item still active must be covered by one of its surviving options, so
the cheapest of those is a floor under that item's share---and the dearest
such floor is a floor under the lot. |Live| hands us one item's options at a
time, which is exactly the shape this scan wants.
@(ssxcc_test.go@>=
func cheapestPerItem(f Frame) int {
	bound, item, low := 0, -1, 0
	for i, opt := range f.Live {
		if i != item {
			bound = max(bound, low)
			item, low = i, f.Cost(opt)
		} else if c := f.Cost(opt); c < low {
			low = c
		}
	}
	return max(bound, low)
}

func minCostQueens(n int, bound func(Frame) int) (price int, nodes uint64) {
	s := NewXCC()
	s.Bound = bound
	res := s.Minimize(strings.NewReader(nQueensInput(n)),
		func(_ int, opt Option) int { return queenPrice(opt) })
	price = -1
	for sol := range res.Solutions {
		price = coverPrice(sol)
	}
	return price, s.Nodes()
}

@ @(ssxcc_test.go@>=
func TestMinimizeQueens(t *testing.T) {
	const n = 8
	want := -1
	res := NewXCC().Dance(strings.NewReader(nQueensInput(n)))
	for sol := range res.Solutions {
		if c := coverPrice(sol); want < 0 || c < want {
			want = c
		}
	}
	plain, nodes := minCostQueens(n, nil)
	if plain != want {
		t.Errorf("Minimize found %d, want %d", plain, want)
	}
	bounded, fewer := minCostQueens(n, cheapestPerItem)
	if bounded != want {
		t.Errorf("Minimize with a bound found %d, want %d", bounded, want)
	}
	t.Logf("%d nodes without a bound, %d with one", nodes, fewer)
}

@ Asking for the $k$ cheapest covers is checked the same way, against the
whole list. The 7-queens board has forty solutions; we price them all, and
the five cheapest that |Minimize| delivers with |Best| at five must cost what
the five cheapest of the forty cost.
@(ssxcc_test.go@>=
func TestMinimizeBest(t *testing.T) {
	const n, k = 7, 5
	var all []int
	for sol := range NewXCC().Dance(strings.NewReader(nQueensInput(n))).Solutions {
		all = append(all, coverPrice(sol))
	}
	s := NewXCC()
	s.Best = k
	var got []int
	res := s.Minimize(strings.NewReader(nQueensInput(n)),
		func(_ int, opt Option) int { return queenPrice(opt) })
	for sol := range res.Solutions {
		got = append(got, coverPrice(sol))
	}
	@<Compare the |k| cheapest of |got| with the |k| cheapest of |all|@>
}

@ @<Compare the |k| cheapest of |got| with the |k| cheapest of |all|@>=
sort.Ints(all)
sort.Ints(got)
if len(got) < k {
	t.Fatalf("only %d covers arrived, want at least %d", len(got), k)
}
for i := 0; i < k; i++ {
	if got[i] != all[i] {
		t.Fatalf("the %d cheapest: got %v, want %v", k, got[:k], all[:k])
	}
}
t.Logf("%d of the %d covers arrived", len(got), len(all))

@ Negative prices are legal, thanks to the tax. Over items |a| and |b| the
options $\{ab\}$, $\{a\}$, $\{b\}$ each cost~$-1$, so $\{a\}+\{b\}$ at~$-2$
beats $\{ab\}$ at~$-1$. The search happens to find $\{ab\}$ first, and a
search that pruned on the running price alone would then turn away $\{a\}$,
already as dear as the incumbent, never learning that $\{b\}$ would make it
cheaper.
@(ssxcc_test.go@>=
func TestMinimizeNegative(t *testing.T) {
	res := NewXCC().Minimize(strings.NewReader("a b\na b\na\nb\n"),
		func(_ int, _ Option) int { return -1 })
	got := 0
	for sol := range res.Solutions {
		got = -len(sol)
	}
	if got != -2 {
		t.Errorf("cheapest cover costs %d, want -2", got)
	}
}

@ The sweep deletes options in the middle of a search that also hides and
purifies, so it gets the test that shakes out such things: small random
problems, solved both by enumerating every cover with |Dance| and by
|Minimize|, four hundred times over. Each problem has three to five primary
items and two secondary ones, options are random subsets of the primaries
with a colored secondary item or two thrown in, and prices run from $-10$
to~29, so that the tax has negative prices to absorb. |Minimize| must find the
cheapest cover, and with |Best| at three the three cheapest.
@(ssxcc_test.go@>=
func randomXCCProblem(rng *rand.Rand) (input string, price map[string]int) {
	names := []string{"a", "b", "c", "d", "e"}[:3+rng.Intn(3)]
	var b strings.Builder
	b.WriteString(strings.Join(names, " ") + " | x y\n")
	price = map[string]int{}
	for i := 0; i < 4+rng.Intn(10); i++ {
		@<Write a random option with a price@>
	}
	return b.String(), price
}

@ An option takes each primary item with probability one half---at least
one---and each secondary item with probability one third, in one of two
colors.
@<Write a random option with a price@>=
var opt []string
for _, name := range names {
	if rng.Intn(2) == 0 {
		opt = append(opt, name)
	}
}
if len(opt) == 0 {
	opt = append(opt, names[rng.Intn(len(names))])
}
for _, sec := range []string{"x", "y"} {
	if rng.Intn(3) == 0 {
		opt = append(opt, sec+":"+string(rune('A'+rng.Intn(2))))
	}
}
line := strings.Join(opt, " ")
price[line] = rng.Intn(40) - 10
b.WriteString(line + "\n")

@ @(ssxcc_test.go@>=
func TestMinimizeMatchesSearch(t *testing.T) {
	rng := rand.New(rand.NewSource(11))
	for trial := 0; trial < 400; trial++ {
		input, price := randomXCCProblem(rng)
		cost := func(sol []Option) int {
			c := 0
			for _, opt := range sol {
				c += price[strings.Join(opt, " ")]
			}
			return c
		}
		var all []int
		for sol := range NewXCC().Dance(strings.NewReader(input)).Solutions {
			all = append(all, cost(sol))
		}
		sort.Ints(all)
		@<Minimize for the one and the three cheapest, and compare@>
	}
}

@ @<Minimize for the one and the three cheapest, and compare@>=
for _, k := range []int{1, 3} {
	s := NewXCC()
	s.Best = k
	var got []int
	r := s.Minimize(strings.NewReader(input),
		func(_ int, opt Option) int { return price[strings.Join(opt, " ")] })
	for sol := range r.Solutions {
		got = append(got, cost(sol))
	}
	sort.Ints(got)
	m := min(k, len(all))
	if len(got) < m || fmt.Sprint(got[:m]) != fmt.Sprint(all[:m]) {
		t.Fatalf("trial %d, Best %d: got %v, want %v\n%s", trial, k, got, all[:m], input)
	}
}

@** Index.
