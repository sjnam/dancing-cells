\def\title{Dancing Cells}

@s node int
@s twoints int
@s threeints int
@s Option int
@s Result int
@s XCC int
@s MCC int
@s parseError int
@s Context int
@s Duration int
@s Ticker int
@s Reader int
@s Builder int
@s Time int
@s any int

@* Introduction.
Every so often a problem that looks like a puzzle turns out to be the same
problem wearing a different hat. Packing the squares $1{\times}1$, $2{\times}2$,
\dots, $n{\times}n$ into a tray --- the {\it partridge puzzle\/}; pencilling
digits into a Sudoku grid; strewing pentominoes across a chessboard; timetabling
exams so that no student sits two at once --- each of these is, underneath, a
single austere question. It is the {\it exact cover\/} problem: given a universe
of {\it items\/} and a collection of {\it options}, each option being a subset of
the items, can we select options so that every item is covered exactly once?

Donald Knuth taught a generation to answer that question with {\it Algorithm~X},
backtracking made vivid by the {\it dancing links\/} data structure. There, the
sparse matrix of options and items is threaded by doubly linked lists, so that
covering an item unstitches it from every list at once, and uncovering it --- on
the way back up the search tree --- stitches it right back, the links dancing out
and in as the search advances and retreats. It is one of the prettiest ideas in
all of combinatorial computing.

And then, as the idea neared its thirtieth birthday, Knuth wrote it out again
{\it the other way}. In his programs {\tt SSXCC} and {\tt SSMCC} he threw out the
links and kept the dance, storing each item's surviving options in a {\it sparse
set\/} --- the little two-array structure that Preston Briggs and Linda Torczon
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
that touch one agree on its color}. Colors let options negotiate --- ``I will use
this square only if you paint it blue'' --- and turn out to express a startling
range of constraints. |XCC| branches the way Algorithm~X does: it picks the item
with the fewest surviving options and tries them all, a {\it $d$-way\/} fan-out.

The second, |MCC|, is exact cover {\it with multiplicities}. Here a primary item
may ask to be covered not once but between $u$ and $v$ times. This small change
alters the arithmetic of the search enough that a {\it binary\/} branch ---
include this one option, or banish it --- serves better than a $d$-way one, so
|MCC| is a separate engine rather than a coat of paint on the first.

@ One Go-flavored liberty runs through both. Knuth's solvers print each solution
to the standard error stream and press on; ours hand each solution back through a
channel. A caller constructs a solver with |dcells.NewXCC()|, calls
|xc.Dance(reader)| on the input, and ranges over |res.Solutions|; each value that
arrives is a |[]Option|, and each |Option| is a |[]string| of item names --- a
colored secondary item appearing as |name:color|. The search runs in its own
goroutine and blocks on every send, so ranging over the solutions paces it, and a
consumer who stops listening stops the search. The input, on the other hand, we
do not touch: it is exactly the {\tt DLX} text format of Knuth's earlier solvers,
so any file that fed {\tt DLX2} or {\tt DLX3} feeds us unchanged.

Here is the whole library at a glance. A short table of contents, and then the
rest of this document fills in each part.
@c
@<Package documentation@>@;
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

@<Shared vocabulary@>@;
@<The XCC engine@>@;
@<The MCC engine@>@;
@<Reading the DLX matrix@>@;

@ One comment survives in the code: the package comment, the public tour for
anyone who meets the library through |go doc| rather than through this document.
@<Package documentation@>=
// Package dcells solves exact-cover-with-colors (XCC) and
// exact-cover-with-multiplicities (MCC) problems using sparse-set "dancing
// cells" data structures instead of dancing links.
//
// It is a library form of Donald E. Knuth's SSXCC and SSMCC programs, exposing
// an API that mirrors github.com/sjnam/dlx: construct a solver with NewXCC or
// NewMCC, call Dance with an io.Reader carrying a problem in the DLX text
// format, and range over Result.Solutions. Each solution is a slice of Option,
// and each Option lists the item names of one chosen option (a colored
// secondary item appears as "name:color").
//
// Item names and colors are arbitrary (possibly multibyte) strings, as in dlx.

@* Data structures.
Sparse-set data structures were introduced by Preston Briggs and Linda Torczon
[{\sl ACM Letters on Programming Languages and Systems\/ \bf2} (1993), 59--69],
who realized that an exercise in Aho, Hopcroft, and Ullman's classic text was
much more than a slick trick to avoid initializing an array. The idea is
astonishingly simple. To represent a subset $S$ of a universe
$U=\{x_0,\ldots,x_{n-1}\}$, keep two arrays $p$ and $q$ that are inverse
permutations of each other, and a count $s$. The members of $S$ are exactly
$x_{p_0},\ldots,x_{p_{s-1}}$. Then $x_k\in S$ iff $q_k<s$; to delete a member,
decrease $s$ and swap it to position~$s$; to insert, swap it to position~$s$ and
increase~$s$. No list, no links --- just two permutations learning to dance.

Our sets never start empty and grow; they start {\it full\/} (every option is a
candidate) and shrink as the search commits to choices, so we keep genuine
inverse permutations rather than the half-defined arrays of the original
application.

@ The whole matrix lives in three flat integer arrays and one array of nodes.
An array |item| holds, for each still-active item, an index |x| into a much
larger array |set|. Beginning at |set[x]| and running for |size(x)| entries are
the options that currently contain that item; so |item| plays the role of the
permutation~$p$, and a companion field |pos(x)| plays~$q$, recording that this
item sits at |item[pos(x)]|. Covering an item is then nothing but shrinking a
count and swapping two array slots --- the sparse-set delete, done over and over.

The bytes just below each item's base in |set| hold its bookkeeping: its size,
its position, and its item number (for name lookup). The named accessors below
read and write those reserved slots; |primExtra| counts how many there are.
@<Shared vocabulary@>=
const (
	primExtra   = 4       // set entries reserved below each item's base
	infSize     = 1 << 30 // "no item to branch on" => a solution
	secondUnset = 1 << 30 // sentinel for "no primary/secondary boundary yet"
)

@ The options themselves are stored as runs of {\it nodes\/} in the array |nd|,
one node per item of the option, with ``spacer'' nodes marking the seams between
consecutive options. A node's |itm| field names its item and its |loc| field
records where, within that item's active run, this node presently sits; |clr| is
an interned color (0 meaning none). The |itm| and |clr| fields are frozen once
input is read, but |loc| moves as options dance in and out.
@<Shared vocabulary@>=
type node struct {
	itm, loc, clr int32
}

@ A solution is reported as the list of its options, and each option as the list
of its item names --- a colored secondary item appearing as \.{name:color}. This
is deliberately the same shape that the |dlx| library produces, so that programs
can migrate between the two without noticing.
@<Shared vocabulary@>=
type Option []string

type Result struct {
	Solutions <-chan []Option
	Heartbeat <-chan string
}

@ Two tiny record types ride the {\it save stack}, which is how the search
remembers enough to undo a branch. The $d$-way engine needs to restore an item
and a size; the multiplicity engine needs an item, a size, and a bound. They are
introduced here and put to work much later, when we discuss backtracking.
@<Shared vocabulary@>=
// twoints is one savestack entry: an item and the size to restore.
type twoints struct {
	l, r int32
}

// threeints is one MCC savestack entry: an item, its size, and its bound.
type threeints struct{ l, s, b int32 }

@ One generic helper earns its keep on nearly every page: |ensure| returns a
slice at least |n| long, preserving contents and growing the backing array
geometrically when it must. The dancing arrays grow only during input and while
the save stack deepens, so amortized doubling keeps the whole run allocation-light.
@<Shared vocabulary@>=
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

@* The XCC engine.
We meet the first solver as an object. An |XCC| value carries the entire state
of one computation: the matrix, the sparse sets, the interned names and colors,
the depth-first search frontier, and the channels it will speak through. Rather
than parade all forty-odd fields at once, we group them by the job they do.
@<The XCC engine@>=
// XCC holds the state of one dancing-cells computation.
type XCC struct {
	@<XCC public knobs@>@;
	ctx context.Context

	@<XCC matrix and sparse sets@>@;
	@<XCC name and color tables@>@;
	@<XCC search state@>@;
	@<XCC statistics@>@;
	@<XCC output plumbing@>@;
}

@ Two knobs face the caller. |Debug| turns on the same terse input-summary and
final-tally lines that the |dlx| library prints to |stderr|; |PulseInterval|, if
positive, asks for an occasional heartbeat string so a long search can prove it
is still alive.
@<XCC public knobs@>=
Debug bool
// PulseInterval controls how often a Heartbeat string is offered.
PulseInterval time.Duration

@ The matrix proper. |nd| is the master node list; |item| and |set| are the
sparse-set arrays described above; |second| marks the boundary between primary
and secondary items, and the various lengths and saved copies let covering and
uncovering find their footing.
@<XCC matrix and sparse sets@>=
// matrix, items, and the sparse-set "set" array
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

@ Names and colors are arbitrary strings, so we intern them: each distinct name
becomes a small integer (1-based, since |names[0]| is a placeholder), and each
color likewise. The maps make interning a duplicate check as well.
@<XCC name and color tables@>=
// interned item names (by item number, 1-based) and colors (by id, 1-based)
names      []string
nameIndex  map[string]int
colorNames []string
colorIndex map[string]int

@ The search keeps two working stacks. The |force| stack collects items that
have been reduced to a single remaining option --- a {\it forced move}, which we
would be foolish not to make immediately. The |choice|, |saved|, and |savestack|
arrays record the current path and the sizes needed to walk back up it.
@<XCC search state@>=
// force stack of items reduced to a single remaining option
force  []int32
forced int

// depth-first search state
choice    []int32
saved     []int32
savestack []twoints
saveptr   int

@ @<XCC statistics@>=
// statistics
updates uint64
nodes   uint64
options uint64
count   uint64

@ @<XCC output plumbing@>=
// output, set up per Dance call
solStream chan []Option
heartbeat chan string
pulse     *time.Ticker

@ A fresh solver needs its sentinels and its (empty but non-nil) tables. By
default heartbeats are off and the context is the background context, never
cancelled.
@<The XCC engine@>=
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

@ To make a search cancellable, hand it a context before starting. |WithContext|
returns a shallow copy so that the original stays reusable, and refuses a nil
context outright --- a nil context is a bug that would otherwise surface as a
mysterious panic deep in the dance.
@<The XCC engine@>=
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

@ Here are the sparse-set accessors in the flesh. For an item whose base is |x|,
the four reserved slots just below |x| hold its size, its position in |item|, and
its item number; the fourth is spare. Reading and writing them by name keeps the
arithmetic of ``two below the base'' from leaking into the algorithms.
@<The XCC engine@>=
func (s *XCC) size(x int) int   { return int(s.set[x-1]) }
func (s *XCC) pos(x int) int    { return int(s.set[x-2]) }
func (s *XCC) itemNo(x int) int { return int(s.set[x-3]) }

func (s *XCC) setSize(x, v int)   { s.set[x-1] = int32(v) }
func (s *XCC) setPos(x, v int)    { s.set[x-2] = int32(v) }
func (s *XCC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

@ Interning a name registers it the first time and rejects a duplicate; interning
a color registers it the first time and happily returns the existing id on later
sightings, because many options may share a color.
@<The XCC engine@>=
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

@ When a solution is found, the search knows each chosen option only by a node
inside it. To report the option we walk back to its first node (spacers have
non-positive |itm|) and then forward, naming each item and appending its color
where there is one. The order is the input order of the items, independent of
which node we started from, so callers can index |opt[0]|, |opt[1]|,~\dots\
positionally.
@<The XCC engine@>=
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

@ Now the dance itself. |Dance| reads the matrix, opens the channels, and launches
the search in a goroutine; it returns at once, handing back the |Result| whose
|Solutions| channel will deliver every cover. The goroutine closes both channels
when it is done, so a |range| loop terminates naturally. If |Debug| is on we
bracket the search with the same summary lines the old solvers printed, and
|baditem| (an item that had no options at all) short-circuits the whole thing.
@<The XCC engine@>=
func (s *XCC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)

	s.solStream = make(chan []Option)
	s.heartbeat = make(chan string)

	go func() {
		defer close(s.solStream)
		defer close(s.heartbeat)

		if s.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
		}
		if s.PulseInterval > 0 {
			s.pulse = time.NewTicker(s.PulseInterval)
			defer s.pulse.Stop()
		}

		if s.baditem == 0 {
			s.search(0)
		}

		if s.Debug {
			plural := "s"
			if s.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				s.count, plural, s.updates, s.nodes)
		}
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}
}

@ |search| is the recursion at the heart of Algorithm~X. At each node it counts a
step, checks whether the caller has walked away or the context has been
cancelled, and offers a heartbeat. Then it asks |chooseItem| for the item to
branch on. If none remains, the partial solution {\it is\/} a solution, and we
|visit| it. Otherwise we cover the chosen item and try each of its options in
turn, restoring the saved sizes between attempts so that every branch starts from
the same clean slate.
@<The XCC engine@>=
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
	return true
}

@ Reaching a solution, we materialize it from the |choice| stack --- one option
per level --- and send it down the channel. The send is the pacing point: if the
consumer has abandoned the |range|, or the context is cancelled, the select's
other arm fires and we return |false|, unwinding the whole search.
@<The XCC engine@>=
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

@ A heartbeat is strictly best-effort: when the pulse has fired we try to offer a
progress line, but if nobody is waiting to receive it we drop it and dance on. No
part of the search ever blocks on a heartbeat.
@<The XCC engine@>=
// tick offers a heartbeat string when the pulse fires, without blocking.
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

@ The branching heuristic is the classic one --- the {\it minimum remaining
values\/} rule --- with a twist for forced moves. Any item already down to a
single option is pushed on the |force| stack and taken first, since it costs
nothing and prunes eagerly. Among the rest we pick the active primary item with
the fewest options, breaking ties toward the leftmost. When no primary item is
left, |score| never improved from |infSize|, and that is exactly the signal that
we are standing on a solution.
@<The XCC engine@>=
func (s *XCC) chooseItem() (best int, solution bool) {
	for s.forced != 0 {
		s.forced--
		if f := int(s.force[s.forced]); s.pos(f) < s.active {
			return f, false
		}
	}

	score := infSize
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // secondary items are not branched on
		}
		switch sz := s.size(x); {
		case sz == 0:
		case sz == 1:
			s.force = ensure(s.force, s.forced+1)
			s.force[s.forced] = int32(x)
			s.forced++
		case sz < score || (sz == score && x < best): // ties: leftmost
			best, score = x, sz
		}
	}

	if s.forced != 0 {
		s.forced--
		return int(s.force[s.forced]), false
	}
	return best, score == infSize
}

@ Committing to an option is where covering happens. First we swap every {\it
other\/} item of the option out of the active list, so that they can no longer be
chosen. Then we hide the options that conflict with our choice: for a primary
item, every other option that used it is now impossible; for a secondary item,
every option that would paint it a different color is impossible, but those that
agree survive --- this is {\it purification}. Christine Solnon's insight, which
this code follows, is that purification and covering are the same operation seen
from two angles, so |hide| does both. If any primary item is left with nothing to
cover it, we bail out, clearing the force stack on the way.
@<The XCC engine@>=
func (s *XCC) commitOption(opt int) bool {
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
		case s.pos(c) < s.oactive: // skip if already purified
			if !s.hide(c, int(s.nd[q].clr), 1) {
				s.forced = 0
				return false
			}
		}
		q++
	}
	return true
}

@ |hide| does the actual unstitching. For each option still present in item |c|'s
set (skipping, when a color is given, the ones that agree and are therefore
purified rather than removed), it walks that option's other nodes and deletes the
option from each of their item sets --- the sparse-set delete: shrink the size,
swap the departing node to the vacated slot, fix both |loc| fields. When |check|
is set, a primary item that drops to a single option is pushed on the force
stack, and one that drops to {\it zero\/} options makes the whole branch
hopeless, so |hide| returns |false|.
@<The XCC engine@>=
func (s *XCC) hide(c, color, check int) bool {
	for rr, end := c, c+s.size(c); rr < end; rr++ {
		tt := int(s.set[rr])
		if color != 0 && int(s.nd[tt].clr) == color {
			continue
		}
		for nn := tt + 1; nn != tt; {
			u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
			if u < 0 {
				nn += u
				continue
			}
			if s.pos(u) < s.oactive {
				ss := s.size(u) - 1
				if ss <= 1 && check != 0 && u < s.second && s.pos(u) < s.active {
					if ss == 0 {
						return false
					}
					s.force = ensure(s.force, s.forced+1)
					s.force[s.forced] = int32(u)
					s.forced++
				}
				nnp := int(s.set[u+ss])
				s.setSize(u, ss)
				s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
				s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
				s.updates++
			}
			nn++
		}
	}
	return true
}

@ Covering the chosen item itself is a bare sparse-set delete on the |item| array.
@<The XCC engine@>=
// swapOut removes item x from the active list (covering it).
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

@ Finally, backtracking. Rather than replay every deletion in reverse --- the way
Knuth's first sparse-set attempt did --- we follow Solnon and simply {\it save
the sizes\/} of all active items before a branch, then slam them back afterward.
The |saved| array remembers, per level, how far the save stack had grown, so
|restoreSizes| knows both how many items were active and what their sizes were.
It is a little profligate with memory and gloriously simple in time.
@<The XCC engine@>=
// saveSizes snapshots the active items' sizes so a branch can be undone.
func (s *XCC) saveSizes(level int) {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		s.savestack[s.saveptr+p] = twoints{s.item[p], int32(s.size(int(s.item[p])))}
	}
	s.saveptr += s.active
	s.saved = ensure(s.saved, level+2)
	s.saved[level+1] = int32(s.saveptr)
}

// restoreSizes undoes the deletions since saveSizes at this level.
func (s *XCC) restoreSizes(level int) {
	s.saveptr = int(s.saved[level+1])
	s.active = s.saveptr - int(s.saved[level])
	for p := -s.active; p < 0; p++ {
		e := s.savestack[s.saveptr+p]
		s.setSize(int(e.l), int(e.r))
	}
}

@* The MCC engine.
The second solver answers a richer question. In |MCC| a primary item carries a
{\it multiplicity\/} $[u..v]$: it must be covered at least $u$ and at most $v$
times, the plain exact-cover case being $[1..1]$. Two numbers travel with each
such item. Its {\it bound\/} is its residual capacity --- how many more times it
still wants covering, counting down as options are chosen. Its {\it slack\/} is
$v-u$, the give in the constraint, and it never changes. Filip Stappers added
these extensions to Knuth's line of solvers in 2023.

Multiplicities change the shape of the branch. With ordinary exact cover we cover
an item by trying each of its options in a single $d$-way fan-out. But an item
that may be covered several times is not so easily disposed of, so |MCC| branches
{\it in binary}: at each node it names one item and one of its options, and asks
two questions --- {\it include\/} this option, or {\it remove\/} it and choose
again. The item to branch on is the one of least {\it branching degree\/}
$\ell+s-b+1$, where $\ell$ is its number of surviving options, $b$ its bound, and
$s=\min(\hbox{slack},b)$; a degree of~1 means the move is forced.

Because so much of the machinery echoes the first engine, we lean on the reader's
memory of |XCC| and dwell only on what multiplicities add.
@<The MCC engine@>=
const (
	mccExtra = 5 // set entries below each item base: size, pos, itemNo, slack, bound
	mccIprop = 5 // input-phase slot spacing
)

@ The |MCC| state mirrors |XCC| almost field for field. It has no |oactive|,
|choice|, or |saved|: binary branching records its path in |included| (one option
per stage, ready for output) and rewinds through a |savestack| of
size-and-bound triples rather than size pairs.
@<The MCC engine@>=
// MCC holds the state of one multiplicity dancing-cells computation.
type MCC struct {
	Debug         bool
	PulseInterval time.Duration

	ctx context.Context

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

	names      []string
	nameIndex  map[string]int
	colorNames []string
	colorIndex map[string]int

	force  []int32
	forced int

	included  []int32 // option included at each stage, for solution output
	savestack []threeints
	saveptr   int

	updates uint64
	nodes   uint64
	options uint64
	count   uint64

	solStream chan []Option
	heartbeat chan string
	pulse     *time.Ticker
}

@ Construction, cancellation, and the two statistics getters are the same story
as before.
@<The MCC engine@>=
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

@ Two more reserved slots hang below each item's base --- |slack| and |bound| ---
so the accessor family grows by two. Everything else reads as before.
@<The MCC engine@>=
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

@ Interning and option reconstruction are identical in spirit to the |XCC|
versions.
@<The MCC engine@>=
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

@ |Dance| is the twin of the |XCC| version --- read, open the channels, search in
a goroutine, close on the way out --- differing only in the statistics it prints
under |Debug|.
@<The MCC engine@>=
func (m *MCC) Dance(rd io.Reader) *Result {
	m.inputMatrix(rd)

	m.solStream = make(chan []Option)
	m.heartbeat = make(chan string)

	go func() {
		defer close(m.solStream)
		defer close(m.heartbeat)

		if m.Debug {
			fmt.Fprintf(os.Stderr,
				"(%d options, %d+%d items, %d entries successfully read)\n",
				m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
		}
		if m.PulseInterval > 0 {
			m.pulse = time.NewTicker(m.PulseInterval)
			defer m.pulse.Stop()
		}

		if m.baditem == 0 {
			m.search(0)
		}

		if m.Debug {
			plural := "s"
			if m.count == 1 {
				plural = ""
			}
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
				m.count, plural, m.updates, m.nodes)
		}
	}()

	return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}
}

@ Now the binary dance. A node is an item |best| and one of its options |opt|. The
{\it left\/} child includes |opt|, covering |best| once more and stepping to
|stage+1|; the {\it right\/} child removes |opt| and stays at the same stage to
re-choose. Between the two we |restoreState| to the mark we saved, so the right
branch begins exactly where the left one did. A leftover forced item from a
shallower covering is dispatched first; a branching |score| of |infSize| means no
primary item is left and we have a solution; a |score| of~1 is a forced move with
no right branch to bother with.
@<The MCC engine@>=
func (m *MCC) search(stage int) bool {
	m.nodes++
	select {
	case <-m.ctx.Done():
		return false
	default:
	}
	m.tick()

	// A forced item left over from a covering at a shallower node.
	for m.forced != 0 {
		m.forced--
		if bi := int(m.force[m.forced]); m.pos(bi) < m.active {
			return m.forcedMove(stage, bi)
		}
	}

	best, score := m.chooseBest()
	if m.forced != 0 {
		m.forced--
		return m.forcedMove(stage, int(m.force[m.forced]))
	}
	if score == infSize {
		return m.visit(stage)
	}

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
	return true
}

@ A forced item has exactly one live option and no alternative, so we commit it
and step forward without saving anything --- some ancestor's |restoreState| will
undo its effects when the time comes.
@<The MCC engine@>=
func (m *MCC) forcedMove(stage, bi int) bool {
	opt := int(m.set[bi])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)
	if m.includeOption(opt) {
		return m.search(stage + 1)
	}
	return true
}

@ Emitting a solution and pulsing a heartbeat work exactly as in |XCC|; only the
source of the options differs --- |included| here, |choice| there.
@<The MCC engine@>=
// visit emits the current solution (the options included so far).
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

@ The heuristic weighs the branching degree $\ell+s-b+1$ and keeps the smallest,
with a careful cascade of tie-breakers. An item whose degree falls to~1 is forced,
and --- because it may need covering more than once --- it can be forced several
times over, so we push it |bound-slack| times onto the stack.
@<The MCC engine@>=
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

@ Including an option walks its nodes and, for each item, either decrements a
bound or --- when the bound reaches zero, or the item is secondary --- covers or
purifies it outright. The work is delegated to |coverOrCommit|, one item at a
time; a return of |false| means some item was left uncoverable and the caller must
back up.
@<The MCC engine@>=
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
			return false // should not happen for a well-formed active option
		}
		if !m.coverOrCommit(ii, opt, pp) {
			return false
		}
	}
	return true
}

@ For a single item |ii| of the included option there are two cases. If covering
|ii| exhausts its bound (or |ii| is secondary), the item is finished: we remove
every {\it other\/} option from its set --- keeping, for a secondary item, those
that share the chosen color --- and deactivate it. Otherwise |ii| still wants more
coverings, so we merely drop the current option from its set, unless that would
starve it below |bound-slack|, in which case the branch dies.
@<The MCC engine@>=
func (m *MCC) coverOrCommit(ii, opt, pp int) bool {
	if ii < m.second {
		m.setBound(ii, m.bound(ii)-1)
	}
	if ii >= m.second || m.bound(ii) == 0 {
		ss := m.size(ii)
		c := 0
		if ii >= m.second {
			c = int(m.nd[opt].clr)
		}
		for s := ii + ss - 1; s >= ii; s-- {
			if s == pp {
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
	} else {
		ss := m.size(ii) - 1
		if ss < m.bound(ii)-m.slack(ii) {
			m.forced = 0
			return false // ii would be wiped out
		}
		if ss == 0 {
			m.deactivate(ii)
		} else {
			nnp := int(m.set[ii+ss])
			m.setSize(ii, ss)
			m.set[ii+ss], m.set[pp] = int32(opt), int32(nnp)
			m.nd[opt].loc, m.nd[nnp].loc = int32(ii+ss), int32(pp)
			m.updates++
		}
	}
	return true
}

@ When an option is committed, every {\it competing\/} option --- one that shares
an item with it --- must leave the field. |removeFromOtherSets| does that for one
such option, deleting it from each of its items' sets and watching, as ever, for a
primary item pushed below its coverable minimum.
@<The MCC engine@>=
func (m *MCC) removeFromOtherSets(optp int) bool {
	nn := optp
	for m.nd[nn-1].itm > 0 {
		nn--
	}
	for ; ; nn++ {
		ii := int(m.nd[nn].itm)
		if ii <= 0 {
			break
		}
		p := int(m.nd[nn].loc)
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
			nnp := int(m.set[ii+ss])
			m.setSize(ii, ss)
			m.set[ii+ss], m.set[p] = int32(nn), int32(nnp)
			m.nd[nn].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
			m.updates++
		}
	}
	return true
}

@ The right branch is gentler: it removes one option without committing it,
simply deleting it from each of its items' sets. If that leaves a primary item
unable to meet its lower bound, the branch is impossible and we report it so the
caller can backtrack.
@<The MCC engine@>=
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
			nnp := int(m.set[ii+ss])
			m.setSize(ii, ss)
			m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
			m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
			m.updates++
		}
	}
	return true
}

@ Deactivating an item is the sparse-set delete on the |item| array once more.
@<The MCC engine@>=
func (m *MCC) deactivate(ii int) {
	m.active--
	p := m.pos(ii)
	iii := int(m.item[m.active])
	m.item[m.active], m.item[p] = int32(ii), int32(iii)
	m.setPos(ii, m.active)
	m.setPos(iii, p)
}

@ Binary branching cannot get away with only saving sizes: bounds change too. So
|saveState| snapshots each active item's size and (for primary items) its bound,
returning a mark; |restoreState| plays them back. This is the multiplicity
analogue of |saveSizes|/|restoreSizes|.
@<The MCC engine@>=
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

@* Reading the DLX matrix.
Both engines eat the same format, the {\tt DLX} text that Knuth's solvers have
used for years. A problem is a stream of lines. The {\it first\/} non-blank,
non-comment line names the items: the primary items, then a lone \.{\|} , then the
secondary items. Every line after that is one option, naming the items it
contains; a secondary item in an option may carry a color as \.{name:color}. Item
names and colors are whitespace-free strings, and a line beginning with \.{\|} is a
comment. The multiplicity engine reads one thing more: a primary item may be
written \.{high\|name} or \.{low:high\|name} to declare that it wants covering
between |low| and |high| times, the bare name meaning $[1..1]$.

A malformed input is a programming error, not a runtime condition to be nursed
along, so the parser announces trouble by panicking with a |parseError|.
@<Reading the DLX matrix@>=
type parseError struct{ msg string }

func (e *parseError) Error() string { return e.msg }

func failf(format string, a ...any) {
	panic(&parseError{fmt.Sprintf(format, a...)})
}

@ A handful of tiny scanners are shared by both parsers. |isspace| classifies the
whitespace bytes; |nextLine| reads one line into a NUL-terminated, NUL-padded
buffer, so that reading one byte past the content stays in bounds and stops at the
terminating NUL; |skipSpace| advances over blanks; and |token| lifts the next
word, stopping at whitespace, the NUL, or --- when asked --- a colon.
@<Reading the DLX matrix@>=
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

func skipSpace(buf []byte, p int) int {
	for isspace(buf[p]) {
		p++
	}
	return p
}

// token reads buf[p:] up to the next whitespace, NUL, or (if stopColon) ':'.
func token(buf []byte, p int, stopColon bool) (string, int) {
	start := p
	for buf[p] != 0 && !isspace(buf[p]) && !(stopColon && buf[p] == ':') {
		p++
	}
	return string(buf[start:p]), p
}

@ The |XCC| parser reads the two halves in order.
@<Reading the DLX matrix@>=
func (s *XCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

@ Reading item names: skip leading blanks and comments to reach the header line,
then take word by word. A lone \.{\|} switches us from primary to secondary items
(and may appear only once); anything else is a name, checked for the forbidden
characters \.{:} and \.{\|} and for duplication before it is interned. At the end,
|lastItm| is the item count plus one, since |names[0]| is unused.
@<Reading the DLX matrix@>=
func (s *XCC) readItemNames(br *bufio.Reader) {
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

@ Each remaining line is an option; blank and comment lines are skipped. When the
stream is exhausted we |finalize| the arrays.
@<Reading the DLX matrix@>=
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

@ Reading one option: for each name we make a node, and if a \.{:color} follows, we
attach the interned color (rejecting a color on a primary item). An option with no
primary item at all covers nothing and is quietly rolled back --- its half-built
nodes are unwound. Otherwise we cap it with a spacer node so the runs stay
separable.
@<Reading the DLX matrix@>=
func (s *XCC) readOption(buf []byte) {
	spacer := s.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {
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
	}

	if !hasPrimary {
		for s.lastNode > spacer {
			slot := int(s.nd[s.lastNode].itm) << 2
			s.setSize(slot, s.size(slot)-1)
			s.setPos(slot, spacer-1)
			s.lastNode--
		}
		return
	}
	s.nd[spacer].loc = int32(s.lastNode - spacer)
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	s.options++
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
}

@ During input we use the same |set| array, but at a coarse |m<<2| spacing that
leaves room for the four reserved slots; |finalize| will re-lay everything
compactly afterward. |createNode| tallies one more node for item |m|, catching a
repeated item within a single option, and marks |hasPrimary| when |m| is primary.
@<Reading the DLX matrix@>=
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

@ Finalizing lays out the definitive |set| array. It walks the items once to
assign each a compact base (leaving |primExtra| reserved slots below it), records
the primary/secondary boundary in the same coordinates, fills in each item's size,
position, and number, flags any primary item that ended up with no options as a
|baditem|, and finally rewrites every node's |itm| and |loc| to point at the real
bases. After this, the sparse sets are ready to dance.
@<Reading the DLX matrix@>=
func (s *XCC) finalize() {
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
}

@ The |MCC| parser differs from the |XCC| one only where multiplicities intrude:
the header may carry bound prefixes, and finalizing must seed bounds and slacks and
sweep away items that can never appear. Its skeleton is the same two-phase read.
@<Reading the DLX matrix@>=
func (m *MCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	m.readItemNames(br)
	m.readOptions(br)
}

@ A small helper reads a non-negative integer from a bound spec, and
|parseItemSpec| splits an item token into its name and its $[low..high]$ bounds.
The forms are \.{name} (defaulting to $[1..1]$), \.{high\|name}, and
\.{low:high\|name}; secondary items may not carry a multiplicity, an upper bound of
zero is nonsense, and a lower bound may not exceed the upper. The lone \.{\|}
separator is handled by the caller, not here.
@<Reading the DLX matrix@>=
func mustAtoi(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		failf("illegal number in bound spec: %q", s)
	}
	return n
}

func parseItemSpec(tok string, inSecondary bool) (name string, lower, upper int) {
	if i := strings.IndexByte(tok, '|'); i >= 0 {
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

@ Reading the |MCC| item names parallels the |XCC| version, but each primary name
arrives through |parseItemSpec| and its slack ($upper-lower$) and bound ($upper$)
are stashed at the item's coarse input slot for |finalize| to pick up.
@<Reading the DLX matrix@>=
func (m *MCC) readItemNames(br *bufio.Reader) {
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

@ @<Reading the DLX matrix@>=
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

@ Reading an option, and the node bookkeeping beneath it, are the |XCC| routines
with |mccIprop| in place of the |<<2| spacing.
@<Reading the DLX matrix@>=
func (m *MCC) readOption(buf []byte) {
	spacer := m.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {
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
	}

	if !hasPrimary {
		for m.lastNode > spacer {
			slot := int(m.nd[m.lastNode].itm) * mccIprop
			m.setSize(slot, m.size(slot)-1)
			m.setPos(slot, spacer-1)
			m.lastNode--
		}
		return
	}
	m.nd[spacer].loc = int32(m.lastNode - spacer)
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	m.options++
	m.nd[m.lastNode].itm = int32(spacer + 1 - m.lastNode)
}

@ @<Reading the DLX matrix@>=
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

@ Finalizing the |MCC| matrix does everything the |XCC| version does and then some:
alongside each item's size, position, and number it copies in the slack and bound,
flags a |baditem| that cannot even reach its lower bound, and stacks up items with
no options for the closing sweep.
@<Reading the DLX matrix@>=
func (m *MCC) finalize() {
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

	m.deactivateOptionless()
}

@ One last sweep retires the items that were stacked as optionless: a primary item
with lower bound~0 and no options simply never appears, and an optionless secondary
item is equally inert. Deactivating them now keeps the search from ever having to
consider them.
@<Reading the DLX matrix@>=
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

@* Index.
