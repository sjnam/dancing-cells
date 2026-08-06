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

The library is one Go package told as three literate documents. This one holds
the common ground: the shape of the public API, the node array that both
engines dance on, and the hands that read {\tt DLX} text. The engines
themselves live next door---{\tt SSXCC} in \.{ssxcc.w} and {\tt SSMCC} in
\.{ssmcc.w}---and each of those can be read start to finish without the other,
in the manner of Knuth's {\tt DLX1}, {\tt DLX2}, {\tt DLX3}. Here is the
skeleton of the common ground.
@c
// Package dcells solves exact cover (XCC, MCC) with dancing cells.
package dcells

import (
	"bufio"
	"fmt"
)

@<Shared declarations@>
@<The input scanner@>

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
@<Bookkeeping constants@>
@<The node type@>
@<Solutions and heartbeats@>
@<The slice grower@>

@ Two sentinels are shared by both engines. |infSize| is larger than any real
option count, so a chooser that never improves on it has learned that no item
remains to branch on---which is to say, that the partial solution is a
solution. |secondUnset| marks an item line that has not yet met its
\.{\|} separator.
@<Bookkeeping constants@>=
const (
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
@<The input scanner@>=
@<Parse failures@>
@<Reading one line@>
@<Scanning tokens@>

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

@** Index.
