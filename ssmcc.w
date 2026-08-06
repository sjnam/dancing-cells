\def\title{SSMCC}

@s Context int
@s Duration int
@s Ticker int
@s Reader int
@s Builder int
@s Time int
@s any int

@** Introduction.
This is {\tt SSMCC}: exact cover with {\it multiplicities\/}, danced on sparse
sets. It is the second engine of the |dcells| package, and like its sibling it
reads on its own; the |Option| and |Result| types, the |node| array, |ensure|,
and the {\tt DLX} scanner belong to the companion document \.{dcells.w}. The
sparse sets both engines dance on are recalled below in brief, and told at
more leisure there.

A primary item here carries a range $[u..v]$: it must be covered at least $u$
and at most $v$ times, plain exact cover being the case $[1..1]$. That small
change alters the arithmetic of the search enough that a {\it binary\/}
branch---include this one option, or banish it---serves better than the
$d$-way fan-out of {\tt SSXCC} (\.{ssxcc.w}), which is why the two engines are
separate programs. Filip Stappers added these extensions to Knuth's line of
solvers in 2023.
@c
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
|pos(x)| plays~$q$, recording that this item sits at |item[pos(x)]|. Deleting
an option from an item is then nothing but shrinking a count and swapping two
array slots---the sparse-set delete, done over and over. The slots just below
each base hold that bookkeeping, which here includes the item's slack and
bound; named accessors below read and write them.

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
This solver answers a richer question than plain exact cover does. In |MCC| a
primary item carries a
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
@<The engine@>=
@<Constants@>
@<The solver state@>
@<Creating a solver@>
@<Set accessors@>
@<Interning@>
@<Launching the dance@>
@<The search@>
@<Forced moves@>
@<Choosing the item@>
@<Including an option@>
@<Excluding an option@>
@<Deactivating an item@>
@<The undo machinery@>
@<Visiting a solution@>
@<The heartbeat@>
@<Reporting an option@>

@* State and construction.
Each MCC item needs two reserved slots more than an XCC item, for its slack
and bound.
@<Constants@>=
const (
	mccExtra = 5 // set entries below each item base: size, pos, itemNo, slack, bound
	mccIprop = 5 // input-phase slot spacing
)

type threeints struct{ l, s, b int32 }

@ The |MCC| state mirrors |XCC| almost field for field---the shared blocks
are literally the same sections---but there is no |oactive|, no |choice|,
and no |saved|: binary branching records its path in |included| (one option
per stage, ready for output) and rewinds through a save stack of
size-and-bound triples.
@<The solver state@>=
type MCC struct {
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
baditem  int
osecond  int

@ @<The backtrack arrays@>=
included  []int32 // option included at each stage, for solution output
savestack []threeints
saveptr   int

@ Construction and cancellation retell the |XCC| story.
@<Creating a solver@>=
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
@<Set accessors@>=
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
@<Interning@>=
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

@* The binary dance.
Launching, too, is the twin of |XCC|'s |Dance|.
@<Launching the dance@>=
func (m *MCC) Dance(rd io.Reader) *Result {
	m.inputMatrix(rd)
	@<Launch the search goroutine@>
}

@ The launch is set down as a section rather than a function, because
|Minimize| in a later chapter wants exactly these lines after it has done its
own preparation.
@<Launch the search goroutine@>=
m.solStream = make(chan []Option)
m.heartbeat = make(chan string)

go func() {
	defer close(m.solStream)
	defer close(m.heartbeat)

	@<Report the input summary@>
	if m.PulseInterval > 0 {
		m.pulse = time.NewTicker(m.PulseInterval)
		defer m.pulse.Stop()
	}

	if m.baditem == 0 {
		m.search(0)
	}

	@<Report the totals@>
}()

return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}

@ @<Report the input summary@>=
if m.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
}

@ @<Report the totals@>=
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
priority; then---if we are out for the cheapest cover---we ask whether this
branch could beat the best one yet; then the chooser speaks, possibly
discovering new forced items of its own; and a degree of |infSize| means no
primary item remains---a solution. Only then do we truly branch.

The order of those first two is not a matter of taste. Giving up on a branch
means returning from the middle of |search|, and that is only safe where the
force stack is empty---which is exactly where the dispatch loop above leaves
it. Abandon a branch with entries still on the stack and the {\it next\/}
node will find them there and take them for its own, and under binary
branching a forced move is not a branch at all: it includes one option and
never looks at the alternatives. The search would quietly lose solutions. (Its
sibling is spared this, because a stale forced item there merely picks the
item to fan out on, and fanning out on any active primary item is always
sound.)
@<The search@>=
func (m *MCC) search(stage int) bool {
	m.nodes++
	select {
	case <-m.ctx.Done():
		return false
	default:
	}
	m.tick()

	@<Dispatch a leftover forced item@>
	@<Give up on this branch if it cannot beat the incumbent@>

	best, score := m.chooseBest()
	if m.forced != 0 {
		m.forced--
		return m.forcedMove(stage, int(m.force[m.forced]))
	}
	if score == infSize {
		return m.visit(stage)
	}
	@<Branch left and right on |best|@>
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

@<Price this option@>
m.cost += price
if m.includeOption(opt) {
	if !m.search(stage + 1) {
		m.saveptr = mark
		return false
	}
}
m.cost -= price
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
@<Forced moves@>=
func (m *MCC) forcedMove(stage, bi int) bool {
	opt := int(m.set[bi])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)
	@<Price this option@>
	m.cost += price
	ok := true
	if m.includeOption(opt) {
		ok = m.search(stage + 1)
	}
	m.cost -= price
	return ok
}

@ The chooser weighs every active primary item by the branching degree
$\ell+s-b+1$ and keeps the smallest, breaking ties by smaller slack, then
larger size, then leftmost position---a cascade tuned by Knuth's
experiments. An item whose degree falls to~1 is forced, and, because it may
still need covering more than once, it is pushed |bound-slack| times so that
each required covering gets its turn.
@<Choosing the item@>=
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

@* The branch actions.
Including an option walks its nodes---first rewinding to the option's
start---and settles accounts with each item in turn via |coverOrCommit|. An
item found already inactive is fine if secondary (it was purified earlier)
and impossible if primary. A |false| from anywhere means some item became
uncoverable and the caller's branch is dead.
@<Including an option@>=
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
@<Including an option@>=
func (m *MCC) coverOrCommit(ii, cur, p int) bool {
	if ii < m.second {
		m.setBound(ii, m.bound(ii)-1)
	}
	if ii >= m.second || m.bound(ii) == 0 {
		@<Cover or purify item |ii| outright@>
	} else {
		@<Drop option |cur| from item |ii|, which wants more@>
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
	@<Swap option |cur| out of slot |p| of item |ii|'s set@>
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
@<Excluding an option@>=
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
			@<Swap option |cur| out of slot |p| of item |ii|'s set@>
		}
	}
	return true
}

@ The right branch of the search needs the same deletion---remove option
|cur| without committing it---and differs from |removeFromOtherSets| in one
detail only: a |false| here is an ordinary ``can't cover,'' reported to a
caller who is about to backtrack anyway, so the force stack is left in peace.
@<Excluding an option@>=
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
			@<Swap option |cur| out of slot |p| of item |ii|'s set@>
		}
	}
	return true
}

@ Deactivating an item is the sparse-set delete on the |item| array once more.
@<Deactivating an item@>=
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
@<The undo machinery@>=
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

@* Reporting.
Emitting a solution reads the |included| stack; the pacing select is the
same as |XCC|'s.
@<Visiting a solution@>=
func (m *MCC) visit(stage int) bool {
	m.count++
	m.incumbent = m.cost
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

@ @<The heartbeat@>=
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

@ @<Reporting an option@>=
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

@** Least-cost covers.
Multiplicities let a problem say how {\it many}; prices let it say how {\it
dear}. Put a price on every option and the question stops being ``is there a
cover?'' and becomes ``what is the cheapest one?''---and the same search
answers it by branch and bound, exactly as its sibling does. Keep an {\it
incumbent}, the price of the best cover so far, infinite until the first one
turns up; at every node ask whether this branch could possibly beat it, and if
not, turn back. \.{ssxcc.w} tells that story at more length; here we need only
say where the binary dance differs.

It differs in one pleasant way. The running cost rises only on a {\it left\/}
branch, where an option is included, and a forced move---which is an inclusion
with the choosing left out---pays the same way. A {\it right\/} branch merely
banishes an option and re-enters the same stage, buying nothing and owing
nothing. So there is exactly one place where the price of an option is added
and taken back, plus its twin in the forced move.

@ Nothing here disturbs |Dance|. The optimizing entry point is a second one,
|Minimize|, and when it is not in use the search runs the code it ran before,
one boolean test the poorer. The |Frame| that a bound function looks through
belongs to \.{dcells.w}, since both engines offer the same one; what is left
here is the four answers this engine gives it.
@<The optimizer@>=
@<The minimizing entry point@>
@<Answering the frame@>

@ The bound oracle is a knob like the others, and like the others it may be
left alone. |Bound| is called at every node of a minimizing search and must
return a lower bound on the price of {\it completing\/} the partial cover
before it---never an overestimate, or the search will prune away the answer.
Returning~0 is always safe and always useless.
@<Solver knobs@>=
Bound func(Frame) int // lower bound on the cost still to come; may be nil

@ The private half of the bookkeeping, field for field the same as |XCC|'s.
Options are numbered $1,2,\ldots$ in the order they were read, |optNo| maps
each node to the number of the option it belongs to, |optCost| holds the price
the caller put on each, and |itemBase| bridges the numbers the frame speaks in
to the bases the dance uses. All three stay nil until |Minimize| builds them,
which is what |minimizing| really means.
@<Cost bookkeeping@>=
minimizing bool
optNo      []int32 // node -> the option that node belongs to
optCost    []int32 // option number -> the price the caller put on it
itemBase   []int32 // item number -> its base in |set|
cost       int64   // price of the options included so far
incumbent  int64   // price of the cheapest cover so far

@ |Minimize| reads the same input |Dance| does, prices it, and starts the same
search. What arrives on |Solutions| is a chain of covers each strictly cheaper
than the last, so a caller who keeps only the newest ends up holding an
optimal one. The price list is a function rather than a slice because an
option's number is an awkward thing for a caller to keep count of: blank
lines, comments, and options that mention no primary item all pass by without
consuming a number. So we hand the caller both the number and the option
itself, in the very shape solutions arrive in, and let it answer.
@<The minimizing entry point@>=
func (m *MCC) Minimize(rd io.Reader, cost func(o int, opt Option) int) *Result {
	m.inputMatrix(rd)
	@<Price the options@>
	m.minimizing, m.incumbent = true, infCost
	@<Launch the search goroutine@>
}

@ Pricing is one sweep over the nodes. Real nodes have a positive |itm| and
spacers do not, so a node whose predecessor is a spacer begins a fresh option:
we advance the option number, ask the caller what that option is worth, and
paint the number over the run of nodes that follows.
@<Price the options@>=
m.optNo = make([]int32, m.lastNode+1)
m.optCost = make([]int32, int(m.options)+1)
o := int32(0)
for k := 1; k < m.lastNode; k++ {
	if m.nd[k].itm <= 0 {
		continue // a spacer between two options
	}
	if m.nd[k-1].itm <= 0 {
		o++
		m.optCost[o] = int32(cost(int(o), m.option(k)))
	}
	m.optNo[k] = o
}
@<Index the items by number@>

@ The frame answers questions about an item by its {\it number}, while the
dance knows items by their {\it base\/} in |set|, so one table has to bridge
the two. Finalization may have deactivated an item or two by now, which shuffles
|item|, but every base is still somewhere in it and carries its own number.
@<Index the items by number@>=
m.itemBase = make([]int32, m.itemlen+1)
for k := 0; k < m.itemlen; k++ {
	base := int(m.item[k])
	m.itemBase[m.itemNo(base)] = int32(base)
}

@ Here is the pruning test, spliced into the head of |search|. Returning
|true| abandons this branch and lets the search go on elsewhere; only
cancellation returns |false|. The comparison is |>=| rather than |>|, so a
cover merely tying the incumbent is cut off too---which is why the covers that
do arrive are strictly improving, and why |visit| may record its cover as the
new incumbent without comparing anything.
@<Give up on this branch if it cannot beat the incumbent@>=
if m.minimizing {
	rest := int64(0)
	if m.Bound != nil {
		rest = int64(m.Bound(Frame{m}))
	}
	if m.cost+rest >= m.incumbent {
		return true
	}
}

@ And here is the price of one option, from a node inside it. A plain |Dance|
never built the tables, so it pays nothing but the test.
@<Price this option@>=
price := int64(0)
if m.minimizing {
	price = int64(m.optCost[m.optNo[opt]])
}

@ Now this engine's four answers to the frame. Walking the live part of the
matrix means walking the active items, skipping the secondary ones---they
demand nothing of their own---and running along each survivor's set.
@<Answering the frame@>=
func (m *MCC) eachLive(yield func(item, opt int) bool) {
	for k := 0; k < m.active; k++ {
		x := int(m.item[k])
		if x >= m.second {
			continue
		}
		i := m.itemNo(x)
		for c := x; c < x+m.size(x); c++ {
			if !yield(i, int(m.optNo[int(m.set[c])])) {
				return
			}
		}
	}
}

@ Two of the remaining three are plain lookups. The third is the one answer
that means something different here than it does under |XCC|, and it is the
reason a bound function can be written for multiplicities at all: an item's
{\it bound\/} is how many more coverings it will still accept and its {\it
slack\/} is how many of those it could do without, so the number it truly
still demands is the difference---and never less than zero.
@<Answering the frame@>=
func (m *MCC) optionCost(opt int) int  { return int(m.optCost[opt]) }
func (m *MCC) itemName(item int) string { return m.names[item] }

func (m *MCC) itemNeed(item int) int {
	x := int(m.itemBase[item])
	if x >= m.second {
		return 0
	}
	return max(m.bound(x)-m.slack(x), 0)
}

@** Reading the DLX input.
The {\tt DLX} text format and the scanner that chews it into tokens live in
\.{dcells.w}; only the part that knows about {\it this\/} engine's arrays is
here. It parallels the XCC input phase of \.{ssxcc.w} closely enough that the
prose below dwells only on what multiplicities change---which is chiefly the
item line, where a primary item may be written \.{high\|name} or
\.{low:high\|name}, the bare name meaning $[1..1]$.
@<The input phase@>=
func (m *MCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	m.readItemNames(br)
	m.readOptions(br)
}

@<Multiplicity bounds parsing@>
@<Item-name input@>
@<Option input@>
@<Input finalization@>

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
		@<Split the bound prefix from the name@>
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

@ Reading the item line differs from the XCC version in one clause: each
name arrives through |parseItemSpec|, and its slack ($upper-lower$) and bound
($upper$) are stashed at the item's coarse input slot for finalization to
pick up.
@<Item-name input@>=
func (m *MCC) readItemNames(br *bufio.Reader) {
	@<Find the item line@>
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

@ Options are read exactly as in the XCC parser, at |mccIprop| spacing.
@<Option input@>=
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

@ @<Option input@>=
func (m *MCC) readOption(buf []byte) {
	spacer := m.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {
		@<Scan one item name and its color@>
	}

	if !hasPrimary {
		@<Unwind the option@>
		return
	}
	m.nd[spacer].loc = int32(m.lastNode - spacer)
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	m.options++
	m.nd[m.lastNode].itm = int32(spacer + 1 - m.lastNode)
}

@ @<Scan one item name and its color@>=
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

@ @<Unwind the option@>=
for m.lastNode > spacer {
	slot := int(m.nd[m.lastNode].itm) * mccIprop
	m.setSize(slot, m.size(slot)-1)
	m.setPos(slot, spacer-1)
	m.lastNode--
}

@ @<Option input@>=
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

@ Finalization runs the same three sweeps and then retires the items that
can be seen, already, to play no part.
@<Input finalization@>=
func (m *MCC) finalize() {
	@<Lay out the set array@>
	@<Fill in the item headers@>
	@<Repoint the nodes@>
	m.deactivateOptionless()
}

@ @<Lay out the set array@>=
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
@<Fill in the item headers@>=
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

@ @<Repoint the nodes@>=
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
@<Input finalization@>=
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
\.{ssmcc\_test.go}, by way of GWEB's file-output control code---the one that
names an auxiliary output rather than the main one. |countMCC| just counts what
the solver finds, and the cases below probe an exact count (\.{2\|a}), a slack
range (\.{1:2\|a}), and a richer mix cross-checked against \.{cmd/ssmcc}.
@(ssmcc_test.go@>=
package dcells

import (
	"fmt"
	"math/rand"
	"strings"
	"testing"
)

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

@ Finally, two sanity checks that this engine subsumes the plain one: with
default multiplicities it must reproduce ordinary XCC---the same 92
solutions to 8-queens---and the color machinery must work there too.
@(ssmcc_test.go@>=
func TestMCCPlainXCC(t *testing.T) {
	n := 8
	var b strings.Builder
	for i := 0; i < n; i++ {
		b.WriteString(fmt.Sprintf("r%02d ", i))
	}
	for j := 0; j < n; j++ {
		b.WriteString(fmt.Sprintf("c%02d ", j))
	}
	b.WriteString("|")
	for k := 0; k < 2*n-1; k++ {
		b.WriteString(fmt.Sprintf(" a%02d ", k))
	}
	for k := 0; k < 2*n-1; k++ {
		b.WriteString(fmt.Sprintf(" b%02d ", k))
	}
	b.WriteString("\n")
	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			b.WriteString(fmt.Sprintf("r%02d ", i))
			b.WriteString(fmt.Sprintf("c%02d ", j))
			b.WriteString(fmt.Sprintf("a%02d ", i+j))
			b.WriteString(fmt.Sprintf("b%02d ", i-j+n-1))
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

@ Minimization gets a problem small enough to check by hand. Item \.{a} wants
covering twice, \.{b} and \.{c} once each, and of the six priced options only
three combinations satisfy all that: $\{ab,ac\}$ at~9, $\{ac,a,b\}$ at~14, and
$\{ab,a,c\}$ at~15. The prices are keyed by the option's printed form so that
a returned cover can be added up the same way it was quoted.
@(ssmcc_test.go@>=
func priceOfCover(sol []Option, price map[string]int) int {
	c := 0
	for _, opt := range sol {
		c += price[strings.Join(opt, " ")]
	}
	return c
}

func TestMCCMinimize(t *testing.T) {
	input := "2|a b c\na b\na c\na\nb c\nb\nc\n"
	price := map[string]int{"a b": 5, "a c": 4, "a": 9, "b c": 2, "b": 1, "c": 1}
	res := NewMCC().Minimize(strings.NewReader(input),
		func(_ int, opt Option) int { return price[strings.Join(opt, " ")] })
	got := -1
	for sol := range res.Solutions {
		got = priceOfCover(sol, price)
	}
	if got != 9 {
		t.Errorf("cheapest cover costs %d, want 9", got)
	}
}

@ |Need| is what a bound function has here that it does not have under |XCC|,
so it gets a test of its own: at the root, before anything has been covered,
each item must still be wanting exactly its lower multiplicity.
@(ssmcc_test.go@>=
func TestMCCNeed(t *testing.T) {
	input := "2|a 1:3|b c\na b\na c\nb\na\nb c\n"
	seen := map[string]int{}
	s := NewMCC()
	s.Bound = func(f Frame) int {
		if len(seen) == 0 {
			for i := range f.Live {
				seen[f.Name(i)] = f.Need(i)
			}
		}
		return 0
	}
	r := s.Minimize(strings.NewReader(input), func(_ int, _ Option) int { return 1 })
	for range r.Solutions {
	}
	for name, want := range map[string]int{"a": 2, "b": 1, "c": 1} {
		if seen[name] != want {
			t.Errorf("Need(%s) = %d at the root, want %d", name, seen[name], want)
		}
	}
}

@ Here is a bound that is sound whenever no price is negative. An item still
wanting $k$ more coverings must take $k$ distinct options out of what survives
in its set, and each of those costs at least the cheapest one there; so
$k$ times that cheapest is a floor under the item's remaining share, and the
dearest such floor is a floor under the lot. |Live| hands us one item's
options at a time, which is exactly the shape this scan wants.
@(ssmcc_test.go@>=
func cheapestTimesNeed(f Frame) int {
	bound, item, low, need := 0, -1, 0, 0
	flush := func() {
		if item >= 0 && low*need > bound {
			bound = low * need
		}
	}
	for i, opt := range f.Live {
		if i != item {
			flush()
			item, low, need = i, f.Cost(opt), f.Need(i)
		} else if c := f.Cost(opt); c < low {
			low = c
		}
	}
	flush()
	return bound
}

@ And here is the test that earns its keep. Small multiplicity problems are
generated at random---every non-empty subset of the items is an option unless
the dice say to leave it out---and the cheapest cover is found twice over: by
enumerating every cover with |Dance|, and by |Minimize|, with a bound and
without one. All three must agree, four hundred times running.

This is the shape of test that caught a real bug. Pruning at the wrong point
in |search| used to leave entries on the force stack, and the next node would
adopt them as its own forced moves---which under binary branching means
committing to one option and never trying the others. Every answer stayed
plausible; they were merely, sometimes, not the cheapest.
@(ssmcc_test.go@>=
func randomMCCProblem(rng *rand.Rand) (input string, price map[string]int) {
	names := []string{"a", "b", "c", "d"}[:3+rng.Intn(2)]
	var b strings.Builder
	@<Write a random item line@>
	@<Write a random priced option for most subsets@>
	return b.String(), price
}

@ @<Write a random item line@>=
for _, name := range names {
	switch rng.Intn(3) {
	case 0:
		fmt.Fprintf(&b, "%s ", name)
	case 1:
		fmt.Fprintf(&b, "2|%s ", name)
	default:
		fmt.Fprintf(&b, "1:2|%s ", name)
	}
}
b.WriteString("\n")

@ @<Write a random priced option for most subsets@>=
price = map[string]int{}
for mask := 1; mask < 1<<len(names); mask++ {
	if rng.Intn(3) == 0 {
		continue // leave this one out
	}
	var opt []string
	for i, name := range names {
		if mask&(1<<i) != 0 {
			opt = append(opt, name)
		}
	}
	line := strings.Join(opt, " ")
	price[line] = rng.Intn(40)
	b.WriteString(line + "\n")
}

@ @(ssmcc_test.go@>=
func TestMCCMinimizeMatchesSearch(t *testing.T) {
	rng := rand.New(rand.NewSource(7))
	for trial := 0; trial < 400; trial++ {
		input, price := randomMCCProblem(rng)
		@<Enumerate every cover and keep the cheapest@>
		@<Minimize with a bound and without, and compare@>
	}
}

@ @<Enumerate every cover and keep the cheapest@>=
want := -1
res := NewMCC().Dance(strings.NewReader(input))
for sol := range res.Solutions {
	if c := priceOfCover(sol, price); want < 0 || c < want {
		want = c
	}
}

@ @<Minimize with a bound and without, and compare@>=
for _, bound := range []func(Frame) int{nil, cheapestTimesNeed} {
	s := NewMCC()
	s.Bound = bound
	r := s.Minimize(strings.NewReader(input),
		func(_ int, opt Option) int { return price[strings.Join(opt, " ")] })
	got, last := -1, -1
	for sol := range r.Solutions {
		got = priceOfCover(sol, price)
		if last >= 0 && got >= last {
			t.Fatalf("trial %d: costs not improving (%d after %d)", trial, got, last)
		}
		last = got
	}
	if got != want {
		t.Fatalf("trial %d: got %d, want %d\n%s", trial, got, want, input)
	}
}

@** Index.
