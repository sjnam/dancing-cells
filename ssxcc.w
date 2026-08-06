\def\title{SSXCC}

@s Context int
@s Duration int
@s Ticker int
@s Reader int
@s Builder int
@s Time int
@s any int

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
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"time"
)

@<The XCC engine@>
@<XCC optimization@>
@<The XCC input phase@>

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
@<XCC bookkeeping@>
@<XCC state@>
@<Creating an XCC solver@>
@<XCC set accessors@>
@<XCC interning@>
@<Launching the XCC dance@>
@<The XCC search@>
@<Choosing the XCC item@>
@<Committing an XCC option@>
@<Hiding conflicting options@>
@<Covering an XCC item@>
@<XCC undo machinery@>
@<Visiting an XCC solution@>
@<The XCC heartbeat@>
@<Reporting an XCC option@>

@ Two small things travel with this engine alone. Each item reserves four
slots just below its base in |set|---its size, its position, its item number,
and one spare---and each entry of the save stack remembers an item together
with the size it had before the branch, so that undoing is a matter of writing
that pair back.
@<XCC bookkeeping@>=
const primExtra = 4 // set entries reserved below each item's base

type twoints struct {
	l, r int32
}

@* XCC state and construction.
An |XCC| value carries the entire state of one computation. Besides the
shared blocks we prepared earlier, it owns the matrix arrays---|nd|, |item|,
|set|, with |second| marking the boundary between primary and secondary items
--- and the arrays that record the search path: |choice| holds the option
chosen at each level, and |saved|/|savestack| snapshot sizes for backtracking.
@<XCC state@>=
type XCC struct {
	@<Solver knobs@>
	ctx context.Context

	@<XCC matrix arrays@>
	@<Naming tables@>
	@<The force stack@>
	@<XCC backtrack arrays@>
	@<Cost bookkeeping@>
	@<Search statistics@>
	@<Output channels@>
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
terminates naturally.
@<Launching the XCC dance@>=
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

	@<Report the XCC input summary@>
	if s.PulseInterval > 0 {
		s.pulse = time.NewTicker(s.PulseInterval)
		defer s.pulse.Stop()
	}

	if s.baditem == 0 {
		s.search(0)
	}

	@<Report the XCC totals@>
}()

return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}

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
the context a chance to abort, and offers a heartbeat; then---if we are out
for the cheapest cover rather than every cover---it weighs the branch against
the best one found so far, and only then asks |chooseItem| where to branch. A
|false| return, here and below, means ``unwind the entire search''---the
caller has walked away or cancelled---and it propagates up through every
level.
@<The XCC search@>=
func (s *XCC) search(level int) bool {
	s.nodes++
	select {
	case <-s.ctx.Done():
		return false
	default:
	}
	s.tick()
	@<Give up on this branch if it cannot beat the incumbent@>

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
committed above it.
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
	s.cost += price
	if s.commitOption(opt) {
		if !s.search(level + 1) {
			return false
		}
	}
	s.restoreSizes(level)
	s.cost -= price
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
arm of the select fires and the whole search unwinds. A cover that gets this
far is also the cheapest one yet---the test at the head of |search| turned
back every branch that could not beat the incumbent---so recording it as the
new incumbent needs no comparison. (For a plain |Dance| the running cost is
always zero and the incumbent is never consulted.)
@<Visiting an XCC solution@>=
func (s *XCC) visit(level int) bool {
	s.count++
	s.incumbent = s.cost
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

@ Nothing in this chapter disturbs |Dance|. The optimizing entry point is a
second one, |Minimize|, and when it is not in use the search runs the code it
ran before, one boolean test the poorer. The chapter needs two pieces of
public vocabulary: the entry point, and the little window through which a
bound function looks at the search in progress.
@<XCC optimization@>=
@<The minimizing entry point@>
@<The search frame@>

@ An incumbent has to start out worse than any real cover. |infCost| is that
starting point---large enough that no sum of |int32| prices over the options
of one cover can reach it, small enough that adding a bound to it will not
overflow.
@<XCC bookkeeping@>=
const infCost = int64(1) << 62 // "no cover found yet"

@ The bound oracle is a knob like the others, and like the others it may be
left alone. |Bound| is called at every node of a minimizing search and must
return a lower bound on the price of {\it completing\/} the partial cover
before it---never an overestimate, or the search will prune away the answer.
Returning~0 is always safe and always useless. At a node that is about to
turn out to be a solution the frame is empty and any sensible bound is zero.
@<Solver knobs@>=
Bound func(Frame) int // lower bound on the cost still to come; may be nil

@ The private half of the bookkeeping. Options are numbered $1,2,\ldots$ in
the order they were read, |optNo| maps each node to the number of the option
it belongs to, and |optCost| holds the price the caller put on each. Both stay
nil until |Minimize| builds them, which is what |minimizing| really means.
@<Cost bookkeeping@>=
minimizing bool
optNo      []int32 // node -> the option that node belongs to
optCost    []int32 // option number -> the price the caller put on it
cost       int64   // price of the options committed so far
incumbent  int64   // price of the cheapest cover so far

@ |Minimize| reads the same input |Dance| does, prices it, and starts the same
search. What arrives on |Solutions| is a chain of covers each strictly cheaper
than the last, so a caller who keeps only the newest ends up holding an
optimal one; a caller who wants to watch the improvement come in can print
them all. If the problem has no cover at all, nothing arrives.

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
	s.minimizing, s.incumbent = true, infCost
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

@ Here is the pruning test, spliced into the head of |search|. Returning
|true| abandons this branch and lets the search go on elsewhere; only
cancellation returns |false|. The comparison is |>=| rather than |>|, so a
cover merely tying the incumbent is cut off too---which is why the covers that
do arrive are strictly improving.
@<Give up on this branch if it cannot beat the incumbent@>=
if s.minimizing {
	rest := int64(0)
	if s.Bound != nil {
		rest = int64(s.Bound(Frame{s}))
	}
	if s.cost+rest >= s.incumbent {
		return true
	}
}

@ And here is the price of one option, looked up twice per branch---once on
the way down, once on the way back---from a node inside it. A plain |Dance|
never built the tables, so it pays nothing but the test.
@<Price this option@>=
price := int64(0)
if s.minimizing {
	price = int64(s.optCost[s.optNo[opt]])
}

@ A |Frame| is a peephole into the search, valid only for the duration of the
|Bound| call that receives it. Through it a bound function can see what is
left of the problem: |Live| runs over every pair (active primary item,
surviving option of that item), which is exactly the part of the matrix still
in play, and |Cost| and |Name| translate the two numbers back into terms the
caller chose. Since |Live| yields all of one item's options before moving to
the next, a bound that thinks in rows of a matrix gets them a row at a time.
@<The search frame@>=
type Frame struct{ s *XCC }

func (f Frame) Live(yield func(item, opt int) bool) {
	s := f.s
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // secondary items demand nothing of their own
		}
		i := s.itemNo(x)
		for c := x; c < x+s.size(x); c++ {
			if !yield(i, int(s.optNo[int(s.set[c])])) {
				return
			}
		}
	}
}

func (f Frame) Cost(opt int) int     { return int(f.s.optCost[opt]) }
func (f Frame) Name(item int) string { return f.s.names[item] }

@** Reading the DLX input.
The {\tt DLX} text format---an item line, then one line per option---is
described in \.{dcells.w}, together with the small scanner that this phase
leans on: |nextLine|, |token|, |skipSpace|, and |failf| for the malformed
input that a caller should never have written. What remains is the part that
knows about {\it this\/} engine's arrays, and here it is, in the order the
dance driver invokes it. Parsing happens in two phases---the item line, then
the options---followed by a {\it finalization\/} that lays out the sparse sets
the dance expects.
@<The XCC input phase@>=
func (s *XCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

@<XCC item-name input@>
@<XCC option input@>
@<XCC input finalization@>

@ The item line is the first line that is neither blank nor a comment. Walking
it token by token, a lone \.{\|} switches us from primary to secondary items
(and may appear only once); anything else is a name, checked for the forbidden
characters \.{:} and \.{\|} and for duplication before it is interned. At the
end, |lastItm| is the item count plus one, since |names[0]| is unused.
@<XCC item-name input@>=
func (s *XCC) readItemNames(br *bufio.Reader) {
	@<Find the XCC item line@>
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
		@<Scan one XCC item name and its color@>
	}

	if !hasPrimary {
		@<Unwind the XCC option@>
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
	@<Lay out the XCC set array@>
	@<Fill in the XCC item headers@>
	@<Repoint the XCC nodes@>
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

@** Tests.
A literate program ought to carry its own proof of life. This last part is
woven from the same source, yet it tangles to a {\it separate\/} file,
\.{ssxcc\_test.go}, by way of GWEB's file-output control code---the one that
names an auxiliary output rather than the main one. Running |go test| then
exercises the engine against small problems whose answers we already know.

The shared helper |collect| runs the XCC solver and renders each solution as
one canonical string---the item names within an option sorted, the options
within a solution sorted, and finally the solutions themselves sorted---so a
test can compare against an expected value without caring in what order they
were found.
@(ssxcc_test.go@>=
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

@** Index.
