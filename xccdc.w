\def\title{XCCDC}

@s Context int
@s Duration int
@s Ticker int
@s Reader int
@s Builder int
@s Time int
@s any int

@** Introduction.
This is {\tt XCCDC}: exact cover with colors again, danced on sparse sets
again, but this time the solver looks much further ahead. It is the third
engine of the |dcells| package, and like the other two it reads on its own;
the |Option| and |Result| types, |ensure|, and the {\tt DLX} scanner belong to
the companion document \.{dcells.w}, and the sparse sets all three dance on
are recalled below in brief and told at more leisure there.

Its ancestor is {\tt SSXCC} (\.{ssxcc.w}), from which Knuth derived the
original of this program by adding data structures and algorithms rather than
by changing any. The problem is the same problem---primary items to be covered
exactly once, secondary items to be covered any number of times provided the
options that touch one agree on its color---and the answers are the same
answers. What differs is how much work each node of the search tree is willing
to do before it commits to anything.

{\tt SSXCC} looks one step ahead: it notices an item that has run out of
options, and it notices an item down to a single option. {\tt XCCDC} maintains
{\it domain consistency}, which is the whole of that idea and more. An option
is thrown out as soon as {\it using it\/} would leave some primary item
elsewhere with nothing to be covered by. In effect the preprocessor
{\tt DLX-PRE} is run again and again, at every node, all the way down. Nodes
become expensive; there are far fewer of them. Whether that trade pays depends
entirely on the problem, which is exactly why it is worth having both engines
in the same package.

Two problems from this repository's own \.{examples} directory show both sides
of the bargain. On the $15\times15$ filomino puzzle, {\tt SSXCC} visits
133{,}639 nodes and takes eleven seconds; {\tt XCCDC} visits 82 and takes
fifty milliseconds. On the pentomino packing of an $8\times8$ board with a
$2\times2$ hole, {\tt XCCDC} again wants far fewer nodes---12{,}295 against
93{,}833---and takes six times as long to get them, having purged more than a
million options on the way. Nothing about a problem announces in advance which
of the two it is going to be.
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

@<The consistency machinery@>
@<The engine@>
@<The input phase@>

@ Sparse sets are the ground everything stands on, so here they are in a
paragraph. To represent a subset $S$ of a universe $U=\{x_0,\ldots,x_{n-1}\}$,
keep two arrays $p$ and $q$ that are inverse permutations of each other,
together with a count~$s$; the members of $S$ are exactly
$x_{p_0},\ldots,x_{p_{s-1}}$. Then $x_k\in S$ iff $q_k<s$; to delete a member,
swap it to position $s-1$ and decrease~$s$; to insert, swap it to position~$s$
and increase~$s$. No list, no links---just two permutations learning to dance.
Preston Briggs and Linda Torczon distilled the idea in 1993 [{\sl ACM Letters
on Programming Languages and Systems\/ \bf2}, 59--69] from an exercise of Aho,
Hopcroft, and Ullman.

@ The matrix lives in three flat arrays. |nd| holds the options as runs of
{\it nodes}, one node per item of an option, with spacer nodes marking the
seams. |item| lists the still-active items, playing the role of the
permutation~$p$ above. And |set| holds, for each item, the options that
currently contain it: an item is named by its base index~|x| into |set|, its
surviving options are |set[x]| and the |size(x)-1| entries after it, and
|pos(x)| plays~$q$, recording that this item sits at |item[pos(x)]|. Covering
an item is then nothing but shrinking a count and swapping two array
slots---the sparse-set delete, done over and over. The slots just below each
base hold that bookkeeping, which here includes two fields used for testing
whether two options can coexist; named accessors below read and write them.

@ The solver struct is assembled from several blocks of state, given names
here so that the struct itself reads as a list of its concerns. First, the
public knobs. |Debug| turns on the same terse input-summary and final-tally
lines that the |dlx| library prints to |stderr|, plus one line of its own
about the initial pruning; |PulseInterval|, if positive, asks for periodic
heartbeats.
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

@ An ``update'' is one sparse-set swap; a ``node'' is one visit to the search;
a ``purge'' is one option thrown out for want of support, which is the very
thing this engine exists to do.
@<Search statistics@>=
updates uint64
nodes   uint64
purges  uint64
options uint64
count   uint64

@ @<Output channels@>=
solStream chan []Option
heartbeat chan string
pulse     *time.Ticker

@** Domain consistency.
Read the given {\tt XCC} problem as a binary constraint-satisfaction problem.
The variables are the primary items. The domain of primary item~$p$ is the set
of options that contain~$p$---exactly the sparse set the dance already keeps
for~$p$. And between each pair of primary items $p\ne p'$ there is a
constraint: option $o$ for~$p$ may stand together with option $o'$ for~$p'$
if and only if $o$ and~$o'$ are {\it compatible}, meaning that they are equal,
or else they have no item in common except secondary items on whose nonzero
colors they agree.

Domain consistency is then the property: for every $p\ne p'$ and every $o$ in
the domain of~$p$, some compatible $o'$ lies in the domain of~$p'$. Said the
other way round, and this is the way to remember it: choosing~$o$ must not
wipe out the domain of any primary item that $o$ does not contain. An option
that fails this test can never appear in any solution, so we remove it---and
removing it may make its neighbors fail in turn. Either some domain empties,
and the current subproblem has no solution at all, or the cascade settles and
every domain is nonempty and consistent. Only then do we branch.

@ Maintaining that property, rather than recomputing it, is the whole art. The
scheme here combines Christian Bessi\`ere's algorithm AC-6 [{\sl Artificial
Intelligence\/ \bf65} (1994), 179--190] with Christophe Lecoutre and Fred
Hemery's AC3rm [{\sl IJCAI Proceedings\/ \bf20} (2007), 125--130], by keeping
{\it witnesses}. Conceptually there is an array $S[o,p]$, defined for every
option~$o$ and primary item~$p$: if $p\in o$ it is the marker~$\#$, and
otherwise it is some option $o'\ni p$ compatible with~$o$. Every entry of~$S$
is a witness that one particular corner of the consistency condition holds,
and as long as the witness stands there is nothing to check.

@ The array is never stored. What is stored is its inverse. For each
option~$o'$ we keep the {\it trigger list\/} of~$o'$: all pairs $(o,p)$ with
$S[o,p]=o'$. When $o'$ goes away, those are precisely the witnesses it takes
with it, so its trigger list fires and each of the holes must be filled again
by a search for a fresh witness. Each option~$o$ also has a {\it fixit list\/}
of the pairs $(o',p)$ triggered against it whose holes are not yet refilled,
and a queue~$Q$ holds every option with at least one outstanding hole.
Triggers and fixits are stacks; the queue is first-in-first-out; all three
live in one array |pool| of cells with an |info| and a |link| field, in the
familiar way.

@ Here is that machinery, in the order in which the dance leans on it.
@<The consistency machinery@>=
@<Option accessors@>
@<The pool of links@>
@<Testing compatibility@>
@<Deactivating an option@>
@<Reverting a fixit list@>
@<Emptying the queue@>
@<Establishing consistency@>

@ Two words of vocabulary before the code. An option is named internally by
the index of the spacer node just preceding it, and an item---primary or
secondary---by its base in |set|. So ``option |opt|'' below always means a
spacer index, and the search hands options around as node indices only until
they can be normalized by |optionOf|.

@ Knuth found room for an option's three dynamic fields inside nodes that were
otherwise going to waste, and this port keeps his kludge, because it is a good
one: the top of |opt|'s trigger stack lives in |nd[opt].clr|, the top of its
fixit stack in |nd[opt].xtra|, and its |age|---which the next chapter
explains---in |nd[opt+1].xtra|. A spacer has no color and no location of its
own, and the first node of an option is the one node in it whose |xtra| nobody
else wants. We have |fixit(opt)| nonzero exactly when $o$ is in the queue.
@<Option accessors@>=
func (s *XCCDC) trigger(opt int) int { return int(s.nd[opt].clr) }
func (s *XCCDC) fixit(opt int) int   { return int(s.nd[opt].xtra) }
func (s *XCCDC) age(opt int) int     { return int(s.nd[opt+1].xtra) }

func (s *XCCDC) setTrigger(opt, v int) { s.nd[opt].clr = int32(v) }
func (s *XCCDC) setFixit(opt, v int)   { s.nd[opt].xtra = int32(v) }
func (s *XCCDC) setAge(opt, v int)     { s.nd[opt+1].xtra = int32(v) }

@ The pool cells are pairs of integers, and the |twoints| type that
\.{ssxcc.w} declares for its save stack serves perfectly well; |l| is the
|info| field and |r| the |link|. Cell~0 is not a cell but the head of the free
list, so a link of~0 means the end of a list, as it should. Freed cells are
recycled by hand, since a search may allocate and release millions of them.
@<The pool of links@>=
func (s *XCCDC) getavail() int {
	if p := int(s.pool[0].r); p != 0 {
		s.pool[0].r = s.pool[p].r
		return p // whatever info(p) held is the caller's business
	}
	s.poolptr++
	s.pool = ensure(s.pool, s.poolptr)
	return s.poolptr - 1
}

func (s *XCCDC) putavail(p int) {
	s.pool[p].r = s.pool[0].r
	s.pool[0].r = int32(p)
}

@ Entries of a trigger list and of a fixit list are pairs of cells: the first
mentions an option, the second a primary item. So the pair $(o,p)$ occupies
cells $c$ and~$c'$ with $\\{link}(c)=c'$, $\\{info}(c)=o$, and
$\\{info}(c')=p$; and $\\{link}(c')$ runs on to the next entry. Turning a
trigger into a fixit therefore costs two stores and no allocation, which is
the point of the arrangement.

@ One of our main activities is finding options compatible with a given
option~$O$. We do it by stamping every item of~$O$ with the current value of
|compatStamp| and, for a secondary item, recording the color~$O$ gives it; a
candidate is then rejected the moment it meets a stamped item it disagrees
with. Item $I$ belongs to~$O$ exactly when |mark(I)| equals the stamp, which
is why the stamp must be fresh each time. Should it ever run out of room we
zero every mark and start over---a precaution that costs two billion
compatibility tests to trigger, and nothing at all before then.
@<Testing compatibility@>=
func (s *XCCDC) markItems(opt int) {
	@<Bump the compatibility stamp@>
	for nn := opt + 1; s.nd[nn].itm > 0; nn++ {
		ii := int(s.nd[nn].itm)
		s.setMark(ii, s.compatStamp)
		if ii >= s.second {
			if c := int(s.nd[nn].clr); c != 0 {
				s.setMatch(ii, c)
			} else {
				s.setMatch(ii, -1) // an uncolored item matches no color
			}
		}
	}
}

@ @<Bump the compatibility stamp@>=
if s.compatStamp == maxStamp {
	for k := 0; k < s.itemlen; k++ {
		s.setMark(int(s.item[k]), 0)
	}
	s.compatStamp = 0
}
s.compatStamp++

@ Now the test itself. We are handed a node |p| somewhere in the middle of
some option~$O'$, because that is how options present themselves in an item's
set, and we must answer two questions at once: is $O'$ compatible with the
marked option, and where does $O'$ begin? Both fall out of one round-robin
walk. Spacers have nonpositive |itm|, and a spacer's |itm| is the negated
length of the option before it, so meeting one tells us where the option's own
spacer lies and lets the walk wrap around to the start. We are done when the
walk returns to the node we came in on. The returned spacer is meaningful only
when the answer is yes.
@<Testing compatibility@>=
func (s *XCCDC) compatible(p int) (opt int, ok bool) {
	opt = p
	for nn := p + 1; nn != p; nn++ {
		jj := int(s.nd[nn].itm)
		switch {
		case jj <= 0:
			opt = nn + jj - 1 // a spacer; jump back to the option's own
			nn = opt
		case s.mark(jj) == s.compatStamp:
			if jj < s.second || s.nd[nn].clr == 0 ||
				int(s.nd[nn].clr) != s.match(jj) {
				return opt, false
			}
		}
	}
	return opt, true
}

@ Here is what happens when an option goes away, whatever the reason. First it
leaves the sets of its items---and if that would empty some primary item's
domain we abandon the whole operation, because the current subproblem is
hopeless. Otherwise the option's trigger list fires: every witness it was
providing must be replaced, so those entries move to the fixit lists of the
options that were relying on them, and those options join the queue.

The rest of |optOut| is housekeeping that pays for itself many times over.
Trigger lists are long, and most of what is in them concerns options that are
already inactive and will stay that way for a while. Rather than walk past
them again and again, we bucket them by |age|---the subject of the next
chapter---and rebuild the list youngest-last, with markers saying ``everything
below here is too young to matter.'' The buckets are |trigHead| and
|trigTail|, which every call finds empty and leaves empty.
@<Deactivating an option@>=
func (s *XCCDC) optOut(opt, act int) bool {
	@<Delete |opt| from the sets of its unpurified items, or fail@>
	s.setAge(opt, s.curAge)
	s.purges++
	tmin, cutoff := infiniteAge, -1
	hintP, hintQ, pp := 0, 0, 0
	for p := s.trigger(opt); p != 0; p = pp {
		q := int(s.pool[p].r)
		optp, ii := int(s.pool[p].l), int(s.pool[q].l)
		pp = int(s.pool[q].r)
		if optp < 0 {
			@<Believe or discard a trigger hint@>
		}
		@<Decide whether this entry is dead, and if so set |t|@>
		if !dead {
			@<Turn the trigger into a fixit for |optp|@>
			continue
		}
		if t < 0 {
			s.putavail(p) // an option this young will never be back
			s.putavail(q)
			continue
		}
		@<File the entry in the bucket for age |t|@>
	}
	@<Rebuild |opt|'s trigger list from the buckets@>
	return true
}

@ A secondary item that was purified at some earlier stage has a frozen set,
which we must not disturb; items lying between |active| and the caller's |act|
are the ones being purified right now, and those we do maintain. The deletion
itself is the sparse-set delete of \.{ssxcc.w}, seen here from the option's
side rather than the item's.
@<Delete |opt| from the sets of its unpurified items, or fail@>=
for nn := opt + 1; ; nn++ {
	ii := int(s.nd[nn].itm)
	if ii <= 0 {
		break
	}
	p := int(s.nd[nn].loc)
	if p >= s.second && s.pos(ii) >= act {
		continue // ii was purified before this branch began
	}
	sz := s.size(ii) - 1
	if sz == 0 && p < s.second {
		@<Give up: |opt| was this item's last option@>
	}
	nnp := int(s.set[ii+sz])
	s.setSize(ii, sz)
	s.set[ii+sz], s.set[p] = int32(nn), int32(nnp)
	s.nd[nn].loc, s.nd[nnp].loc = int32(ii+sz), int32(p)
	s.updates++
}

@ We cannot complete the current choices to anything domain consistent, so
every fixit list still waiting in the queue must go back where it came from.
Undoing them is not optional bookkeeping: those cells hold the only record of
which witnesses were removed, and a later branch will need them.
@<Give up: |opt| was this item's last option@>=
for s.qfront != s.qrear {
	p := s.qfront
	s.qfront = int(s.pool[p].r)
	waiting := int(s.pool[p].l)
	s.putavail(p)
	s.revertFixits(waiting)
}
return false

@ Turning fixits back into triggers is exactly the reverse of the move that
made them, cell for cell.
@<Reverting a fixit list@>=
func (s *XCCDC) revertFixits(opt int) {
	var pp int
	for p := s.fixit(opt); p != 0; p = pp {
		q := int(s.pool[p].r)
		optp := int(s.pool[p].l)
		pp = int(s.pool[q].r)
		s.pool[p].l = int32(opt)
		s.pool[q].r = int32(s.trigger(optp))
		s.setTrigger(optp, p)
	}
	s.setFixit(opt, 0)
}

@ An entry $(o,p)$ of |opt|'s trigger list is {\it dead\/} if the option~$o$
that relied on the witness is itself inactive, or if the item~$p$ it was
waiting to cover has been covered. The age test settles the first question
cheaply whenever it can: an inactive option's age is at most |curAge|, so an
option whose age is greater is certainly active. When it cannot, we look:
an option is active if and only if it still appears in the set of its first
item, and this is where the input phase's insistence that every option begin
with a {\it primary\/} item earns its keep, for a purified secondary item
would tell us nothing.
@<Decide whether this entry is dead, and if so set |t|@>=
t, dead := -1, false
if a := s.age(optp); a <= s.curAge {
	jj := int(s.nd[optp+1].itm) // optp's first item, always primary
	if int(s.nd[optp+1].loc) >= jj+s.size(jj) {
		t, dead = a, true
	}
}
if !dead && s.pos(ii) >= s.active {
	t, dead = s.curAge, true
}

@ A live entry becomes a hole to be filled. Its two cells move from |opt|'s
trigger list to |optp|'s fixit list without being copied, and an option that
had no holes before now goes on the queue---with an infinite age, so that
|emptyQueue| can tell later whether it was purged while it waited.
@<Turn the trigger into a fixit for |optp|@>=
s.pool[p].l = int32(opt)
s.pool[q].r = int32(s.fixit(optp))
if s.fixit(optp) == 0 {
	r := s.getavail()
	s.pool[s.qrear].r = int32(r)
	s.pool[s.qrear].l = int32(optp)
	s.qrear = r
	s.setAge(optp, infiniteAge)
}
s.setFixit(optp, p)

@ @<File the entry in the bucket for age |t|@>=
if s.trigHead[t] == 0 {
	s.trigTail[t] = int32(q)
}
s.pool[q].r = s.trigHead[t]
s.trigHead[t] = int32(p)
if t < tmin {
	tmin = t
}

@ The queue is where the cascade lives. Each option on it has holes; for every
hole we scan the domain of the item in question for a compatible option, and
either we find a new witness---the common case, and a cheap one, since the
scan usually stops at once---or the option has lost its last support and must
be purged, which puts more options on the queue. When the queue finally
empties, the surviving options are domain consistent.
@<Emptying the queue@>=
func (s *XCCDC) emptyQueue() bool {
	for s.qfront != s.qrear {
		p := s.qfront
		opt := int(s.pool[p].l)
		s.qfront = int(s.pool[p].r)
		s.putavail(p)
		if s.age(opt) != infiniteAge {
			s.revertFixits(opt) // opt itself was purged in the meantime
			continue
		}
		s.markItems(opt)
		@<Look for a new witness for each hole in |opt|@>
	}
	return true
}

@ @<Look for a new witness for each hole in |opt|@>=
var pp int
for p := s.fixit(opt); p != 0; p = pp {
	q := int(s.pool[p].r)
	ii := int(s.pool[q].l) // a primary item not in opt
	pp = int(s.pool[q].r)
	found := false
	for c, end := ii, ii+s.size(ii); c < end; c++ {
		if optp, ok := s.compatible(int(s.set[c])); ok {
			@<Record |optp| as the witness for |opt| and |ii|@>
			found = true
			break
		}
	}
	if !found {
		@<Purge |opt| for want of support, or fail@>
		break
	}
}
s.setFixit(opt, 0)

@ The two cells that recorded the hole become the head of |optp|'s trigger
list, so the new witness carries the obligation the old one dropped.
@<Record |optp| as the witness for |opt| and |ii|@>=
s.pool[p].l = int32(opt)
s.pool[q].r = int32(s.trigger(optp))
s.setTrigger(optp, p)

@ The holes not yet examined go back to the lists they were taken from before
|opt| is purged, because |optOut| is about to walk |opt|'s own trigger list
and expects the world to be in one piece.
@<Purge |opt| for want of support, or fail@>=
s.setFixit(opt, p)
s.revertFixits(opt)
if !s.optOut(opt, s.active) {
	return false
}

@ Getting the ball rolling is the same idea applied to every option at once,
before the search begins. All |mark| fields are zero at this point, and no
item is inactive, so the code below is the queue's inner loop with the
allocation of fresh cells added: each option looks for a witness against every
primary item it does not contain, and options that cannot find one are purged
on the spot. Whatever that leaves is the largest domain-consistent subset of
the given options, and it is the problem the dance actually solves.
@<Establishing consistency@>=
func (s *XCCDC) establishDC() bool {
	s.curAge = -1
	s.qfront = s.getavail()
	s.qrear = s.qfront
	for opt := 0; opt < s.lastNode; opt += int(s.nd[opt].loc) + 1 {
		s.markItems(opt)
		@<Find a witness for |opt| against every primary item it lacks@>
	}
	return s.emptyQueue()
}

@ Note that the options purged here are purged with |curAge| equal to $-1$,
which is younger than any age the search will ever use. That is how the
trigger lists come to hold entries that can be thrown away rather than filed,
and it is why nothing is filed at all during this pass.
@<Find a witness for |opt| against every primary item it lacks@>=
for k := 0; k < s.osecond; k++ {
	ii := int(s.item[k])
	if s.mark(ii) == s.compatStamp {
		continue // ii is in opt, so no witness is called for
	}
	found := false
	for c, end := ii, ii+s.size(ii); c < end; c++ {
		if optp, ok := s.compatible(int(s.set[c])); ok {
			p := s.getavail()
			q := s.getavail()
			s.pool[p].r = int32(q)
			s.pool[q].l = int32(ii)
			@<Record |optp| as the witness for |opt| and |ii|@>
			found = true
			break
		}
	}
	if !found {
		if !s.optOut(opt, s.active) {
			return false
		}
		break // opt is gone; on to the next one
	}
}

@ Options purged during that first pass are useless baggage in the trigger
lists of the options that survived, and they will never come back, so we sweep
them out once instead of stepping over them forever.
@<Tidy up the initial trigger lists@>=
for opt := 0; opt < s.lastNode; opt += int(s.nd[opt].loc) + 1 {
	if s.age(opt) < 0 {
		continue
	}
	qq, pp := -1, 0
	for p := s.trigger(opt); p != 0; p = pp {
		q := int(s.pool[p].r)
		optp := int(s.pool[p].l)
		pp = int(s.pool[q].r)
		if s.age(optp) < 0 {
			s.putavail(p)
			s.putavail(q)
			if qq < 0 {
				s.setTrigger(opt, pp)
			} else {
				s.pool[qq].r = int32(pp)
			}
		} else {
			qq = q
		}
	}
}

@** The engine.
Now the solver itself. Its outer shape is the one all three engines share ---
read the matrix, launch a goroutine, hand solutions back on a channel---and
its inner shape is where it parts company with {\tt SSXCC}.

The strategy is still to branch on the item that looks hardest to cover, the
one whose set is currently smallest. But {\tt SSXCC} would then try that
item's options one after another, a $d$-way fan-out, and here we cannot: after
trying an option we must {\it remove\/} it and restore domain consistency, and
that changes the whole subproblem, so the item that looked hardest a moment
ago may not be the right one to ask about now. The branching is therefore
binary. We choose a best item $p_1$, try its first option; on the way back we
remove that option, make the domains consistent again, choose a fresh best
item~$p_2$, try {\it its\/} first option; and so on until no consistent
nonempty set of domains is left.

@ Those $k$ tries all belong to the same {\it stage}: they are all attempts to
extend the same partial solution of $s$ chosen options to one of $s+1$
options. The binary search tree records each of them on its own {\it level},
so a stage is a run of levels and the two must never be confused. In this
port a stage is one call of |search| and the levels within it are the
iterations of its loop, which is why |search| has a loop inside a recursion
where its siblings have plain recursion. Backtracking comes in the same two
flavors it does in Knuth's original: {\it in\/} the stage, when a choice fails
and there is another to make, which is the next turn of the loop; and {\it
to\/} the previous stage, when nothing consistent remains, which is a return.

@ Let $I_s$ be the items still active once $c_1,\ldots,c_s$ have been chosen,
and $P_s$ its primary ones. Write $O_{-1}$ for the options as given,
$O_s\hbox{$^{\rm init}$}$ for the largest domain-consistent set compatible
with $c_1,\ldots,c_s$, and $O_s$ for what is left of it after this stage has
already examined and discarded some choices. Then the search descends through
$$O_{-1}\supseteq O_0^{\rm init}\supseteq O_0\supset O_1^{\rm init}\supseteq
O_1\supset\cdots\supset O_s^{\rm init}\supseteq O_s,$$ every set after the
first being domain consistent. The nesting is the reason the witness array
needs no undoing when we backtrack: a witness is a witness, and a support
that was valid for a larger set of options is still valid for a smaller one.
So nothing here is ever restored except the sizes of the sparse sets.

@ Two small declarations open the code. Each item reserves five slots just
below its base in |set|---its size, its position, its item number, its
compatibility mark, and the color it must match while it is being purified.
And the node carries a fourth field beyond the three that \.{dcells.w}
defines, the |xtra| that holds an option's fixit list and its age, so this
engine declares a node type of its own rather than borrowing that one.
@<Constants@>=
const (
	dcExtra     = 5       // set entries reserved below each item's base
	dcIprop     = 5       // input-phase slot spacing
	infiniteAge = 1 << 29 // an age no purged option can have
	maxStamp    = 1<<31 - 1
)

type dcnode struct {
	itm, loc, clr, xtra int32 // itm and clr are fixed after input; loc dances
}

@ Here is the engine, in the order in which it is told.
@<The engine@>=
@<Constants@>
@<The solver state@>
@<Creating a solver@>
@<Set accessors@>
@<Interning@>
@<Launching the dance@>
@<The search@>
@<Choosing the item@>
@<Including an option@>
@<Purging an option@>
@<The undo machinery@>
@<Visiting a solution@>
@<The heartbeat@>
@<Reporting an option@>

@* State and construction.
An |XCCDC| value carries the entire state of one computation: the matrix
arrays, the naming tables, the support structure of the previous chapter, and
the arrays that record the search path.
@<The solver state@>=
type XCCDC struct {
	@<Solver knobs@>
	ctx context.Context

	@<The matrix arrays@>
	@<Naming tables@>
	@<The support structure@>
	@<The backtrack arrays@>
	@<Search statistics@>
	@<Output channels@>
}

@ @<The matrix arrays@>=
nd       []dcnode
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

@ The pool holds every trigger list, every fixit list, and the queue; the two
bucket arrays are scratch space for |optOut|, empty except while it runs. Of
the three stamps, |compatStamp| distinguishes one compatibility test from the
next, while |curStamp| and |biggestStamp| date the stages, so that a trigger
hint can be recognized as stale.
@<The support structure@>=
pool         []twoints // info in .l, link in .r; cell 0 heads the free list
poolptr      int
qfront       int
qrear        int
trigHead     []int32 // buckets, indexed by age, used while rebuilding a list
trigTail     []int32
compatStamp  int
curStamp     int32
biggestStamp int32

@ Backtracking needs less here than in either sibling, because only sizes are
ever undone. |chosen| holds the option picked at each stage, ready for output;
|stageStamp| dates the stages for the benefit of trigger hints; and |curAge|
is the field through which the search tells |optOut| how firmly the option it
is removing has been ruled out.
@<The backtrack arrays@>=
chosen     []int32
stageStamp []int32
savestack  []twoints
saveptr    int
curAge     int

@ A fresh solver needs its sentinels and its (empty but non-nil) tables. The
pool starts with its single reserved cell and its first usable one; by default
heartbeats are off and the context is the background context, never cancelled.
|WithContext| returns a shallow copy, so the original stays reusable, and it
refuses a nil context outright. |Updates|, |Nodes|, and |Purges| report the
search statistics once the |Solutions| channel has been drained.
@<Creating a solver@>=
func NewXCCDC() *XCCDC {
	return &XCCDC{
		second:     secondUnset,
		names:      []string{""}, // item numbers are 1-based
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // color 0 means "no color"
		colorIndex: make(map[string]int),
		pool:       make([]twoints, 2),
		poolptr:    1,
		ctx:        context.Background(),
	}
}

func (s *XCCDC) WithContext(ctx context.Context) *XCCDC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *s
	c.ctx = ctx
	return &c
}

func (s *XCCDC) Updates() uint64 { return s.updates }
func (s *XCCDC) Nodes() uint64   { return s.nodes }
func (s *XCCDC) Purges() uint64  { return s.purges }

@ The sparse-set accessors, in the flesh. Reading and writing the reserved
slots by name keeps the arithmetic of ``four below the base'' out of the
algorithms. |mark| and |match| are the two that {\tt SSXCC} has no use for.
@<Set accessors@>=
func (s *XCCDC) size(x int) int   { return int(s.set[x-1]) }
func (s *XCCDC) pos(x int) int    { return int(s.set[x-2]) }
func (s *XCCDC) itemNo(x int) int { return int(s.set[x-3]) }
func (s *XCCDC) mark(x int) int   { return int(s.set[x-4]) }
func (s *XCCDC) match(x int) int  { return int(s.set[x-5]) }

func (s *XCCDC) setSize(x, v int)   { s.set[x-1] = int32(v) }
func (s *XCCDC) setPos(x, v int)    { s.set[x-2] = int32(v) }
func (s *XCCDC) setItemNo(x, v int) { s.set[x-3] = int32(v) }
func (s *XCCDC) setMark(x, v int)   { s.set[x-4] = int32(v) }
func (s *XCCDC) setMatch(x, v int)  { s.set[x-5] = int32(v) }

@ Interning a name registers it the first time and rejects a duplicate;
interning a color happily returns the existing id on later sightings, because
many options may share a color. This is verbatim the code of the other two
engines with a third receiver; Go gives us no graceful way to share a method
body between three types.
@<Interning@>=
func (s *XCCDC) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

func (s *XCCDC) internColor(name string) int {
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
terminates naturally. There is no |Minimize| here: branch and bound belongs to
the other two engines, and Knuth's original has no notion of cost.
@<Launching the dance@>=
func (s *XCCDC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)
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
		@<Make the domains consistent, then dance@>
		@<Report the totals@>
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}
}

@ A |baditem|---a primary item that ended the input with no options at all ---
makes the problem trivially unsolvable, and so does an initial pass that
empties somebody's domain. In either case no search happens and the channels
simply close.
@<Make the domains consistent, then dance@>=
if s.baditem == 0 && s.establishDC() {
	@<Tidy up the initial trigger lists@>
	@<Report the initial pruning@>
	s.search(0)
}

@ Under |Debug| we bracket the search with the same summary lines the |dlx|
library prints, down to the fussy singular/plural of ``solutions,'' and add
one line of our own: how many options the initial consistency pass threw away
before the first branch was ever taken. On a well-constrained problem that
number is often most of them.
@<Report the input summary@>=
if s.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
}

@ @<Report the initial pruning@>=
if s.Debug {
	fmt.Fprintf(os.Stderr, "Domain consistency purged %d of %d options.\n",
		s.purges, s.options)
}

@ @<Report the totals@>=
if s.Debug {
	plural := "s"
	if s.count == 1 {
		plural = ""
	}
	fmt.Fprintf(os.Stderr,
		"Altogether %d solution%s, %d updates, %d nodes, %d purges.\n",
		s.count, plural, s.updates, s.nodes, s.purges)
}

@ And here is the search: one call per stage, one turn of its loop per level.
At each level it counts a node, gives the context a chance to abort, offers a
heartbeat, and asks the chooser where to branch; a degree of |infSize| means
no primary item is left active, which is to say that the partial solution is a
solution. Otherwise it takes the item's first surviving option and tries it.

A |false| return means ``unwind the entire search''---the caller has walked
away or cancelled---and it propagates up through every stage. A |true| return
means only ``back up to the previous stage.''
@<The search@>=
func (s *XCCDC) search(stage int) bool {
	@<Enter the stage@>
	mark := s.saveptr
	for {
		s.nodes++
		select {
		case <-s.ctx.Done():
			return false
		default:
		}
		s.tick()

		best, t := s.chooseItem()
		if t == infSize {
			return s.visit(stage)
		}
		opt := int(s.set[best])
		s.chosen = ensure(s.chosen, stage+1)
		s.chosen[stage] = int32(opt)
		if t != 1 {
			s.saveSizes()
		}
		@<Try |opt|, and go on to the next stage if it survives@>
		if t == 1 {
			return true // the choice was forced; there is no alternative
		}
		@<Remove |opt| and stay in this stage, or back up@>
	}
}

@ Sizes are saved once per level, and only when the choice is a real
choice: an item with a single option leaves nothing to come back to, so a
forced move is taken without saving anything at all, and the level that
follows it can never be revisited. That is why the ``degree one'' tests appear
twice below---once to skip the save, once to skip the retry.
@<Enter the stage@>=
s.stageStamp = ensure(s.stageStamp, stage+1)
s.trigHead = ensure(s.trigHead, 2*stage+2)
s.trigTail = ensure(s.trigTail, 2*stage+2)
@<Bump the current stamp@>
s.stageStamp[stage] = s.curStamp

@ Including the option covers its items and purges everything incompatible
with it; emptying the queue then restores domain consistency, which may purge
a great deal more. Should either fail, this branch is dead, but the stage may
still have others.
@<Try |opt|, and go on to the next stage if it survives@>=
s.curAge = stage + stage + 1
if s.includeOption(opt) && s.emptyQueue() {
	if !s.search(stage + 1) {
		return false
	}
}

@ Coming back---whether from a completed subtree or from a choice that never
got off the ground---we restore the sizes and rule the option out. If the
domains cannot be made consistent without it, this stage is finished and we
back up; otherwise the loop turns and the chooser speaks again, in a
subproblem strictly smaller than the one it saw last time.
@<Remove |opt| and stay in this stage, or back up@>=
s.restoreSizes(mark)
s.curAge = stage + stage
if !s.purgeOption(opt, s.active) || !s.emptyQueue() {
	return true
}

@ Which item shall we branch on? The one with fewest options, ties going to
the leftmost, exactly as in {\tt SSXCC}---but without that engine's force
stack, since domain consistency has already dealt with the forced moves in its
own way. Size zero cannot occur: an item whose domain empties takes the whole
branch down with it long before the chooser is asked. The scan stops early at
size~1, because nothing can beat it.
@<Choosing the item@>=
func (s *XCCDC) chooseItem() (best, score int) {
	score = infSize
	for k := 0; score > 1 && k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // secondary items are not branched on
		}
		switch sz := s.size(x); {
		case sz < score:
			best, score = x, sz
		case sz == score && x < best:
			best = x
		}
	}
	return best, score
}

@* Ages and hints.
Suppose a problem has 1000 options and 100 items. Then the witness array has
100{,}000 entries, nearly all of them real supports, and every real support is
an entry in some trigger list. The lists are enormous. Yet after a few choices
there may be only 100 options and 30 uncovered items left, so at most 3000 of
those entries can possibly matter. Maintaining consistency would be hopeless
if we had to walk past the other 97{,}000 every time; the saving grace is that
we may reorder a trigger list whenever we look at it, and we look at it only
when its option has just gone inactive.

@ So every deactivated option is stamped with an {\it age}, and the ages say
how firmly it is out. When an option leaves $O_s^{\rm init}$ without reaching
$O_s$---that is, when this stage tries it and moves on---its age is $2s$; when
it leaves $O_s$ without reaching $O_{s+1}^{\rm init}$---when the choice we
just made is incompatible with it---its age is $2s+1$. Turn that around and
it reads as a test: an inactive option belongs to $O_s^{\rm init}$ if and only
if its age is at least~$2s$, and to $O_s$ if and only if its age is at least
$2s+1$. Young options are the ones purged early, on the strength of few
assumptions; they are the ones that will stay out longest, and they are
exactly what we want at the bottom of the list. Hence the bucket sort in
|optOut|, which puts the youngest last.

@ Sorting alone would still leave us walking the whole list. So |optOut| also
inserts {\it hints}: an entry whose option field is the negative number
$-c-1$ says ``every entry below this one has age less than~$c$,'' which is to
say that none of them can be active yet. A later reader that believes the hint
can stop there.

Believing it requires care, because the search tree has moved on since the
hint was written. Suppose $o$ has age~$2s$: then $o$ is in $O_s^{\rm init}$
but not in~$O_s$, and as long as we neither backtrack to stage $s-1$ nor
return to stage~$s$ afresh, $O_s$ can only shrink, so $o$ stays out and the
hint stays true. Suppose instead $o$ has age $2s+1$: then $o$ is in $O_s$ but
not in $O_{s+1}^{\rm init}$, and the hint holds until stage $s+1$ is entered
anew. Both cases are covered by dating the hint with the stamp of stage
$\lfloor(c+1)/2\rfloor$, and every stage takes a fresh stamp on the way in.
That is the whole of the mechanism, and it is why the second cell of a hint
holds a stamp where an ordinary entry holds an item.
@<Believe or discard a trigger hint@>=
c := -optp - 1
if c < s.curAge && ii == int(s.stageStamp[(c+1)>>1]) {
	hintP, hintQ, cutoff = p, q, c
	break // everything below is known to be inactive
}
s.putavail(p) // the hint has gone stale
s.putavail(q)
continue

@ Rebuilding the list is now a matter of stacking the buckets in front of
whatever the walk did not reach. Each nonempty bucket gets a fresh hint of its
own, except the bucket of the current age---an option purged at this very
moment is no evidence about anything, so it earns no hint. If the surviving
hint says less than the buckets already do, we drop it rather than keep two
hints in a row.
@<Rebuild |opt|'s trigger list from the buckets@>=
pp = 0
if hintP != 0 {
	pp = hintP
	if tmin <= cutoff {
		pp = int(s.pool[hintQ].r) // the buckets subsume this hint
		s.putavail(hintP)
		s.putavail(hintQ)
	}
}
for t := tmin; t < s.curAge; t++ {
	if s.trigHead[t] == 0 {
		continue
	}
	s.pool[int(s.trigTail[t])].r = int32(pp)
	@<Head the bucket with a fresh hint@>
	s.trigHead[t] = 0
}
if s.curAge >= 0 && s.trigHead[s.curAge] != 0 {
	s.pool[int(s.trigTail[s.curAge])].r = int32(pp)
	pp = int(s.trigHead[s.curAge])
	s.trigHead[s.curAge] = 0
}
s.setTrigger(opt, pp)

@ The guard on |curAge| in the last paragraph is for the initial pass, which
runs at age $-1$ and files nothing in any bucket.
@<Head the bucket with a fresh hint@>=
p := s.getavail()
q := s.getavail()
s.pool[p].l = int32(-t - 1)
s.pool[p].r = int32(q)
s.pool[q].l = s.stageStamp[(t+1)>>1]
s.pool[q].r = s.trigHead[t]
pp = p

@ Each stage takes a stamp larger than any a hint can be carrying, and the
stamps of the stages below it must stay distinct, since they may be quoted in
hints yet to be written. A counter that only ever increases satisfies both
conditions, and would satisfy them forever if integers were unbounded. They
are not, so once in a very long while---after two billion stages have been
entered---we must renumber. At that point every hint in the program becomes
unverifiable, so we throw them all away and start counting from the number of
stages currently open.
@<Bump the current stamp@>=
s.biggestStamp++
if s.biggestStamp == maxStamp {
	@<Remove every hint from every trigger list@>
	for k := 0; k < stage; k++ {
		s.stageStamp[k] = int32(k)
	}
	s.biggestStamp = int32(stage)
}
s.curStamp = s.biggestStamp

@ A hint is two cells, and it is never the last entry in its list---the
rebuilding code above always follows one with the bucket that provoked it ---
so removing it means copying the entry below it into its place.
@<Remove every hint from every trigger list@>=
for k := 0; k < s.lastNode; k += int(s.nd[k].loc) + 1 {
	for p := s.trigger(k); p != 0; p = int(s.pool[p].r) {
		if s.pool[p].l < 0 {
			q := int(s.pool[p].r)
			r := int(s.pool[q].r)
			s.pool[p].l, s.pool[p].r = s.pool[r].l, s.pool[r].r
			s.putavail(q)
			s.putavail(r)
		}
	}
}

@* The branch actions.
Including an option is where the covering happens. First every item of the
option leaves the active list, each secondary one remembering the color the
option gives it. Then, for each of those items in turn, the options that can
no longer be used are purged: for a primary item that means every other option
containing it, and for a secondary item with a color it means every option
that disagrees---purification and covering being the same sweep seen from two
angles. A secondary item the option leaves uncolored is covered outright, like
a primary one.
@<Including an option@>=
func (s *XCCDC) includeOption(node int) bool {
	opt := s.optionOf(node)
	@<Inactivate every item of |opt|, recording its color@>
	for k := s.active; k < s.oactive; k++ {
		x := int(s.item[k])
		end := x + s.size(x) - 1
		if x >= s.second && s.match(x) != 0 {
			@<Purify item |x|, purging the options that disagree@>
		} else {
			@<Cover item |x|, purging every option but |opt|@>
		}
	}
	@<Make |opt| itself inactive@>
	return true
}

@ At this point an item of |opt| is inactive if and only if it is a secondary
item that was purified at some earlier stage; everything else moves out now.
The items that move form the block |item[active..oactive)|, and the loops
below walk exactly that block.
@<Inactivate every item of |opt|, recording its color@>=
p := s.active
s.oactive = s.active
for q := opt + 1; s.nd[q].itm > 0; q++ {
	c := int(s.nd[q].itm)
	pp := s.pos(c)
	if pp < p {
		p--
		cc := int(s.item[p])
		s.item[p], s.item[pp] = int32(c), int32(cc)
		if c >= s.second {
			s.setMatch(c, int(s.nd[q].clr))
		}
		s.setPos(cc, pp)
		s.setPos(c, p)
		s.updates++
	}
}
s.active = p

@ Both loops run from right to left, because a purged option is swapped
toward the right end of the set as it leaves, into the space the shrinking
size has just vacated. Walking the other way would step on the survivors.
@<Purify item |x|, purging the options that disagree@>=
c := s.match(x)
for ; end >= x; end-- {
	optp := int(s.set[end])
	if int(s.nd[optp].clr) != c && !s.purgeOption(optp, s.oactive) {
		return false
	}
}

@ @<Cover item |x|, purging every option but |opt|@>=
for ; end >= x; end-- {
	optp := s.optionOf(int(s.set[end]))
	if optp != opt && !s.optOut(optp, s.oactive) {
		return false
	}
}

@ One thing here has no counterpart in {\tt SSXCC}: the chosen option is made
inactive too, and the primary items it covers are left with {\it empty\/}
domains rather than domains of size one. It would be quite wrong to reach this
by calling |optOut|, which exists to refuse exactly that; a primary item
running out of options is a catastrophe there and a celebration here. So we
say it directly. Nothing needs to happen to |opt|'s trigger list, because no
active option involves an inactive primary item.
@<Make |opt| itself inactive@>=
for k := s.active; k < s.oactive; k++ {
	x := int(s.item[k])
	if x < s.second {
		s.setSize(x, 0)
	}
}
s.setAge(opt, s.curAge)

@ The search and the purification loop above both name an option by a node
inside it, so both go through |purgeOption|; spacers have nonpositive |itm|,
which is what |optionOf| walks back to.
@<Purging an option@>=
func (s *XCCDC) purgeOption(node, act int) bool {
	return s.optOut(s.optionOf(node), act)
}

func (s *XCCDC) optionOf(node int) int {
	for node--; s.nd[node].itm > 0; node-- {
	}
	return node
}

@ Finally, backtracking, which is Solnon's trick and nothing more: before a
branch, save the {\it sizes\/} of all active items in one sweep; afterward,
slam them back. Positions and set contents need no repair---the swaps left
every set a permutation of itself, and a restored size re-admits exactly the
right entries---and the witness array needs none either, as the nesting
argument at the head of this chapter showed. The stack pointer at the moment a
stage begins is all a stage needs to remember, so |restoreSizes| can recover
the number of active items from the distance back to it.
@<The undo machinery@>=
func (s *XCCDC) saveSizes() {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		x := int(s.item[p])
		s.savestack[s.saveptr+p] = twoints{int32(x), int32(s.size(x))}
	}
	s.saveptr += s.active
}

func (s *XCCDC) restoreSizes(mark int) {
	s.active = s.saveptr - mark
	s.saveptr = mark
	for p := 0; p < s.active; p++ {
		e := s.savestack[mark+p]
		s.setSize(int(e.l), int(e.r))
	}
}

@* Reporting.
Reaching a solution, we materialize it from the |chosen| stack---one option
per stage---and send it down the channel. The send is the pacing point: if the
consumer has abandoned the range, or the context is cancelled, the other arm
of the select fires and the whole search unwinds.
@<Visiting a solution@>=
func (s *XCCDC) visit(stage int) bool {
	s.count++
	sol := make([]Option, stage)
	for k := 0; k < stage; k++ {
		sol[k] = s.option(int(s.chosen[k]))
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
func (s *XCCDC) tick() {
	if s.pulse == nil {
		return
	}
	select {
	case <-s.pulse.C:
		select {
		case s.heartbeat <- fmt.Sprintf("%d nodes, %d solutions, %d purges so far",
			s.nodes, s.count, s.purges):
		default:
		}
	default:
	}
}

@ The search knows each chosen option only by a node inside it. To report the
option we walk back to its first node and then forward, naming each item and
appending its color where there is one. One difference from the other two
engines deserves a note: this one insists that every option begin with a
primary item, and shifts the option's nodes at input time if it does not, so
an option whose text began with secondary items is reported with its first
primary item in front of them. The items after that first one keep the order
they were written in.
@<Reporting an option@>=
func (s *XCCDC) option(p int) Option {
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

@** Reading the DLX input.
The {\tt DLX} text format---an item line, then one line per option---is
described in \.{dcells.w}, together with the small scanner this phase leans
on: |nextLine|, |token|, |skipSpace|, and |failf| for the malformed input that
a caller should never have written. What remains is the part that knows about
{\it this\/} engine's arrays. Parsing happens in two phases---the item line,
then the options---followed by a {\it finalization\/} that lays out the sparse
sets the dance expects.
@<The input phase@>=
func (s *XCCDC) inputMatrix(rd io.Reader) {
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
func (s *XCCDC) readItemNames(br *bufio.Reader) {
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
func (s *XCCDC) readOptions(br *bufio.Reader) {
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
func (s *XCCDC) readOption(buf []byte) {
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
Because |createNode| may put the node somewhere other than at the end, it
returns the slot it used, and the color goes there.
@<Scan one item name and its color@>=
name, next := token(buf, p, true)
if name == "" {
	failf("empty item name")
}
m, known := s.nameIndex[name]
if !known {
	failf("unknown item name: %s", name)
}
at := s.createNode(m, spacer, &hasPrimary)
if buf[next] == ':' {
	if m < s.second {
		failf("primary item must be uncolored: %s", name)
	}
	color, ce := token(buf, next+1, false)
	if color == "" {
		failf("missing color after %s:", name)
	}
	s.nd[at].clr = int32(s.internColor(color))
	next = ce
}
p = skipSpace(buf, next)

@ Unwinding pops each half-built node and takes back its tally from the
input-phase slot. The nodes of an option with no primary item all sit one
slot beyond |lastNode|, which is where the shift below left them.
@<Unwind the option@>=
for s.lastNode > spacer {
	slot := int(s.nd[s.lastNode+1].itm) * dcIprop
	s.setSize(slot, s.size(slot)-1)
	s.setPos(slot, spacer-1)
	s.lastNode--
}

@ During input the |set| array is used at a coarse |dcIprop| spacing---room
enough for each item's reserved slots---and |createNode| tallies one more node
for item |m| there, catching a repeated item within a single option by
noticing that the item's last-seen position is already inside this option.

Here too is the shift that guarantees every option a primary item in front.
While no primary item has been seen the nodes are written one slot ahead,
leaving the first slot empty; the first primary item to arrive claims that
slot, and everything after it is written normally. The maneuver costs one
comparison per item and buys the cheap ``is this option still active?'' test
that the trigger lists depend on.
@<Option input@>=
func (s *XCCDC) createNode(m, spacer int, hasPrimary *bool) int {
	slot := m * dcIprop
	s.set = ensure(s.set, slot)
	if s.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", s.names[m])
	}
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+2)
	at := s.lastNode
	if !*hasPrimary {
		if m < s.second {
			at, *hasPrimary = spacer+1, true
		} else {
			at = s.lastNode + 1
		}
	}
	t := s.size(slot)
	s.nd[at].itm = int32(m)
	s.nd[at].loc = int32(t)
	s.nd[at].clr = 0
	s.setSize(slot, t+1)
	s.setPos(slot, s.lastNode)
	return at
}

@ Finalization converts the coarse input tallies into the dance's real layout,
in three sweeps over the data.
@<Input finalization@>=
func (s *XCCDC) finalize() {
	@<Lay out the set array@>
	@<Fill in the item headers@>
	@<Repoint the nodes@>
}

@ The first sweep assigns each item a compact base in |set|---leaving
|dcExtra| reserved slots below it---and converts the primary/secondary
boundary into those coordinates. A problem with no \.{\|} in its item line has
no secondary items, and |second| lands just past the used part of |set|.
@<Lay out the set array@>=
s.active, s.itemlen = s.lastItm-1, s.lastItm-1
s.item = ensure(s.item, s.itemlen)
s.set = ensure(s.set, s.itemlen*dcIprop+1) // all input slots readable

j := dcExtra
k := 0
for ; k < s.itemlen; k++ {
	s.item[k] = int32(j)
	j += dcExtra + s.size((k+1)*dcIprop)
}
s.setlen = j - dcExtra
s.set = ensure(s.set, j+1)
if s.second == secondUnset {
	s.osecond, s.second = s.active, j
} else {
	s.osecond = s.second - 1
}

@ The second sweep, running backward so the input tallies are read before
their slots are overwritten, fills in each item's size, position, and number,
clears its compatibility mark, and flags as |baditem| any primary item that
ended up with no options.
@<Fill in the item headers@>=
for ; k != 0; k-- {
	base := int(s.item[k-1])
	if k == s.second {
		s.second = base
	}
	s.setSize(base, s.size(k*dcIprop))
	if s.size(base) == 0 && k <= s.osecond {
		s.baditem = k
	}
	s.setPos(base, k-1)
	s.setItemNo(base, k)
	s.setMark(base, 0)
}

@ The third sweep rewrites every node's |itm| and |loc| from item numbers and
per-item counts into real |set| indices, and drops each node into its slot.
After this, the sparse sets are ready to dance.
@<Repoint the nodes@>=
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

@** Tests.
A literate program ought to carry its own proof of life. This last part is
woven from the same source, yet it tangles to a {\it separate\/} file,
\.{xccdc\_test.go}, by way of GWEB's file-output control code---the one that
names an auxiliary output rather than the main one.

The helper renders a solution set canonically: the item names within an option
sorted, the options within a solution sorted, and finally the solutions
themselves sorted. Sorting the names inside an option matters more here than
it did for the other two engines, since this one may report an option's first
primary item out of turn; sorting makes the comparisons below indifferent to
that.
@(xccdc_test.go@>=
package dcells

import (
	"fmt"
	"slices"
	"sort"
	"strings"
	"testing"
)

func canonDC(res *Result) []string {
	var sols []string
	for sol := range res.Solutions {
		opts := make([]string, len(sol))
		for i, opt := range sol {
			names := append([]string(nil), opt...)
			sort.Strings(names)
			opts[i] = strings.Join(names, " ")
		}
		sort.Strings(opts)
		sols = append(sols, strings.Join(opts, " | "))
	}
	sort.Strings(sols)
	return sols
}

func danceDC(input string) []string {
	return canonDC(NewXCCDC().Dance(strings.NewReader(input)))
}

@ The plainest test is the textbook one: Knuth's six-option example from {\sl
TAOCP\/} 7.2.2.1, whose only exact cover is $\{a\,d\,f\}$, $\{b\,g\}$,
$\{c\,e\}$. Two more check the color machinery and confirm that an uncoverable
item yields no solution at all---the last of these never even reaches the
search, since the initial consistency pass empties a domain.
@(xccdc_test.go@>=
func TestDCExactCover(t *testing.T) {
	input := "a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n"
	sols := danceDC(input)
	if len(sols) != 1 {
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
	}
	if want := "a d f | b g | c e"; sols[0] != want {
		t.Errorf("got %q, want %q", sols[0], want)
	}
}

func TestDCColors(t *testing.T) {
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
	if sols := danceDC(input); len(sols) != 2 {
		t.Fatalf("want 2 solutions, got %d: %v", len(sols), sols)
	}
}

func TestDCNoSolution(t *testing.T) {
	if sols := danceDC("a b c\na b\n"); len(sols) != 0 {
		t.Errorf("want 0 solutions, got %d", len(sols))
	}
}

@ Options that lead with secondary items exercise the shift that puts a
primary item first. Both covers must still be found, and every option must be
reported with an uncolored primary item at its head---which is the invariant
the trigger lists rely on, checked here where it is visible.
@(xccdc_test.go@>=
func TestDCSecondaryFirst(t *testing.T) {
	input := "a b | x y\nx:A y:B a\ny:B b\nx:A b\n"
	n := 0
	for sol := range NewXCCDC().Dance(strings.NewReader(input)).Solutions {
		n++
		for _, opt := range sol {
			if strings.ContainsRune(opt[0], ':') {
				t.Errorf("option %v does not lead with a primary item", opt)
			}
		}
	}
	if n != 2 {
		t.Errorf("want 2 solutions, got %d", n)
	}
}

@ The real test of an exact-cover solver is that it agrees with another one.
Each problem below goes through both engines, and the canonical solution sets
must match exactly---not merely in number. The last two have secondary items
with colors, which is where the compatibility test earns its keep.
@(xccdc_test.go@>=
func TestDCAgreesWithXCC(t *testing.T) {
	inputs := []string{
		"a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n",
		"a b c\na b c\na b\nc\na\nb c\n",
		"p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n",
		"a b | x y\nx:A y:B a\ny:B b\nx:A b\n",
		queensDC(6),
		queensDC(7),
		langfordDC(4),
		langfordDC(5),
	}
	for i, in := range inputs {
		want := canonDC(NewXCC().Dance(strings.NewReader(in)))
		got := canonDC(NewXCCDC().Dance(strings.NewReader(in)))
		if !slices.Equal(want, got) {
			t.Errorf("problem %d: XCC found %d covers, XCCDC found %d",
				i, len(want), len(got))
		}
	}
}

@ Two problem generators, kept here so that this document's tests stand on
their own. The $n$-queens board has rows and columns as primary items and the
two diagonal families as secondary ones; Langford pairs place the numbers
$1,\ldots,n$ twice each so that the two copies of~$k$ are $k+1$ apart, and
have solutions when $n\bmod4$ is 0 or~3.
@(xccdc_test.go@>=
func queensDC(n int) string {
	var b strings.Builder
	for i := 0; i < n; i++ {
		fmt.Fprintf(&b, "r%02d ", i)
	}
	for j := 0; j < n; j++ {
		fmt.Fprintf(&b, "c%02d ", j)
	}
	b.WriteString("|")
	for k := 0; k < 2*n-1; k++ {
		fmt.Fprintf(&b, " a%02d b%02d", k, k)
	}
	b.WriteString("\n")
	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			fmt.Fprintf(&b, "r%02d c%02d a%02d b%02d\n", i, j, i+j, i-j+n-1)
		}
	}
	return b.String()
}

func langfordDC(n int) string {
	var b strings.Builder
	for k := 1; k <= n; k++ {
		fmt.Fprintf(&b, "d%d ", k)
	}
	for i := 0; i < 2*n; i++ {
		fmt.Fprintf(&b, "s%02d ", i)
	}
	b.WriteString("\n")
	for k := 1; k <= n; k++ {
		for i := 0; i+k+1 < 2*n; i++ {
			fmt.Fprintf(&b, "d%d s%02d s%02d\n", k, i, i+k+1)
		}
	}
	return b.String()
}

@ Finally the counts everyone knows: 4, 40, and 92 solutions to the
$n$-queens problem for $n=6$, 7, and~8. The test also logs what the two
engines paid for them, which is the whole reason this program exists---the
node counts are the interesting column, and the purge count says how much
looking ahead it took to get them.
@(xccdc_test.go@>=
func TestDCQueens(t *testing.T) {
	for n, want := range map[int]int{6: 4, 7: 40, 8: 92} {
		in := queensDC(n)
		dc := NewXCCDC()
		got := 0
		for range dc.Dance(strings.NewReader(in)).Solutions {
			got++
		}
		if got != want {
			t.Errorf("%d-queens: got %d solutions, want %d", n, got, want)
		}
		x := NewXCC()
		for range x.Dance(strings.NewReader(in)).Solutions {
		}
		t.Logf("%d-queens: XCCDC %d nodes, %d updates, %d purges;"+
			" XCC %d nodes, %d updates",
			n, dc.Nodes(), dc.Updates(), dc.Purges(), x.Nodes(), x.Updates())
	}
}

@** Index.
