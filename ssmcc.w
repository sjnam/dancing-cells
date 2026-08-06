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

@<The MCC engine@>
@<The MCC input phase@>

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
@<MCC constants@>
@<MCC state@>
@<Creating an MCC solver@>
@<MCC set accessors@>
@<MCC interning@>
@<Launching the MCC dance@>
@<The MCC search@>
@<Forced MCC moves@>
@<Choosing the MCC item@>
@<Including an MCC option@>
@<Excluding an MCC option@>
@<Deactivating an MCC item@>
@<MCC undo machinery@>
@<Visiting an MCC solution@>
@<The MCC heartbeat@>
@<Reporting an MCC option@>

@* MCC state and construction.
Each MCC item needs two reserved slots more than an XCC item, for its slack
and bound.
@<MCC constants@>=
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
@<MCC state@>=
type MCC struct {
	@<Solver knobs@>
	ctx context.Context

	@<MCC matrix arrays@>
	@<Naming tables@>
	@<The force stack@>
	@<MCC backtrack arrays@>
	@<Search statistics@>
	@<Output channels@>
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

		@<Report the MCC input summary@>
		if m.PulseInterval > 0 {
			m.pulse = time.NewTicker(m.PulseInterval)
			defer m.pulse.Stop()
		}

		if m.baditem == 0 {
			m.search(0)
		}

		@<Report the MCC totals@>
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

	@<Dispatch a leftover forced item@>

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
			@<Swap option |cur| out of slot |p| of item |ii|'s set@>
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
			@<Swap option |cur| out of slot |p| of item |ii|'s set@>
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
The {\tt DLX} text format and the scanner that chews it into tokens live in
\.{dcells.w}; only the part that knows about {\it this\/} engine's arrays is
here. It parallels the XCC input phase of \.{ssxcc.w} closely enough that the
prose below dwells only on what multiplicities change---which is chiefly the
item line, where a primary item may be written \.{high\|name} or
\.{low:high\|name}, the bare name meaning $[1..1]$.
@<The MCC input phase@>=
func (m *MCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	m.readItemNames(br)
	m.readOptions(br)
}

@<Multiplicity bounds parsing@>
@<MCC item-name input@>
@<MCC option input@>
@<MCC input finalization@>

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

@ Reading the MCC item line differs from the XCC version in one clause: each
name arrives through |parseItemSpec|, and its slack ($upper-lower$) and bound
($upper$) are stashed at the item's coarse input slot for finalization to
pick up.
@<MCC item-name input@>=
func (m *MCC) readItemNames(br *bufio.Reader) {
	@<Find the MCC item line@>
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
		@<Scan one MCC item name and its color@>
	}

	if !hasPrimary {
		@<Unwind the MCC option@>
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
	@<Lay out the MCC set array@>
	@<Fill in the MCC item headers@>
	@<Repoint the MCC nodes@>
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
\.{ssmcc\_test.go}, by way of GWEB's file-output control code---the one that
names an auxiliary output rather than the main one. |countMCC| just counts what
the solver finds, and the cases below probe an exact count (\.{2\|a}), a slack
range (\.{1:2\|a}), and a richer mix cross-checked against \.{cmd/ssmcc}.
@(ssmcc_test.go@>=
package dcells

import (
	"fmt"
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

@ Finally, two sanity checks that the MCC engine subsumes the plain one: with
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

@** Index.
