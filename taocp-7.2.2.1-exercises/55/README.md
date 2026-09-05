# TAOCP 7.2.2.1, Exercise 55: A Careful Reading

Written 5 September 2026, against Volume 4B, Addison-Wesley, first printing,
2022, and the errata file as of that date.

This is one reader's response to the request on Knuth's [news
page](https://www-cs-faculty.stanford.edu/~knuth/news.html): read an exercise
and its answer very carefully, then report back.

## What I found

| Item | Finding |
| --- | --- |
| Exercise 55 (statement) | No error. |
| Answer 55, the lower bound | Correct, and its argument checks out cell by cell. |
| Answer 55, the 18-clue puzzle for (28a) | Genuine. One of exactly 189. |
| Answer 55, "18 clues impossible" for (28b) | Confirmed. |
| Answer 55, "19 clues impossible" for (28b) | Confirmed. |
| Answer 55, the 20-clue puzzle for (28b) | Genuine. One of exactly 648. |
| Answer 55, the transfer to (28c) | Confirmed, and answer 43's formula holds as printed. |
| Answer 55, "the 2043 subsets" | Confirmed: the minimal unavoidable sets of at most 18 cells number exactly 2043. |

Everything in the answer is right. What this reading adds is a different route
to the negative half — the part where the answer says only that a SAT instance
came back unsatisfiable, at a cost of 177 megamems for the 19-clue case.

The same observation that gives the lower bound also cuts the search down to
almost nothing. Ruling out 18 clues for (28b) takes 0.13 seconds here, and
ruling out 19 takes 8.8 seconds. The saving is not cleverness about search; it
is that the answer's own argument, pushed one step further, says exactly where
the clues have to go.

## 1. What the exercise asks

Display (28) shows three highly symmetrical sudoku squares. Exercise 55 asks
for the smallest number of clues that can force (28a) as the unique answer —
proving 18 necessary and exhibiting 18 that suffice — and then for the same
question about (28b).

The hint gives the key: *at least two of the nine appearances of {1, 4, 7} in
the top three rows must be among the clues.*

## 2. The three squares

They were transcribed from the printed page, and then checked against the
closed forms in answer 43, which are a completely separate description of the
same objects:

| | Valid sudoku | Matches answer 43's formula |
| --- | --- | --- |
| (28a) | yes | yes |
| (28b) | yes | yes |
| (28c) | yes | yes |

A transcription slip would show up as a disagreement, so this settles the
reading of the page.

## 3. Unavoidable sets: the whole exercise in one idea

Call a set of cells **unavoidable** if the digits in it can be rearranged to
give another solution. Every clue set must meet every unavoidable set — miss
one, and both rearrangements stay open, so the puzzle has two answers.

So the minimum number of clues is exactly the size of the smallest hitting set
of the unavoidable sets. Nothing else enters into it.

Only minimal unavoidable sets matter. For these two squares the small ones are
very uniform:

| | (28a) | (28b) |
| --- | --- | --- |
| minimal unavoidable sets of 6 cells | 81 | 162 |
| of 7, 8, 9, 10, 11 cells | 0 | 0 |
| completions when one is blanked | exactly 2, every time | exactly 2, every time |

Each was tested on its own terms, without reference to the search that found
it: blank the six cells, give all seventy-five others, and count the ways to
fill it back in. Every one gives exactly two. Hand back any single cell and the
count drops to one, so each is minimal.

## 4. The lower bound

The hint's nine cells are the ones holding 1, 4 or 7 in the top three rows.
They turn out to be the first column of each box in the top band, and the
digits in them form a 3 × 3 Latin square on {1, 4, 7}. There are twelve such
Latin squares; four of them agree with the original at any one specified cell.
Hence:

> With one of the nine given and the other eight blank, there are **4** ways to
> complete the square.

That is the hint, confirmed, with the number the hint does not state. Two clues
are therefore needed inside those nine cells.

The answer then says the whole diagram splits into nine disjoint sets of nine
with the same property. It does: one band of rows crossed with one column of
each box, nine ways.

| | (28a) | (28b) |
| --- | --- | --- |
| nine disjoint groups covering all 81 cells | yes | yes |
| each group needs two clues | yes | yes |
| so at least 18 clues | yes | yes |

## 5. The shape this forces

Here is the step that makes the rest cheap. Nine groups, two clues apiece,
eighteen clues — with nothing to spare. An 18-clue puzzle has **exactly two
clues in every group**. A 19-clue puzzle has three in exactly one group and two
in the rest, which is the remark the answer makes next; it is now simple
arithmetic rather than an observation.

Inside a group, only 9 of the 36 pairs meet every unavoidable set that lies
within the group. So the candidates for an 18-clue puzzle number

$$9^9 = 387{,}420{,}489$$

and that is *all* of them. The printed puzzles confirm the shape:

| | Clues per group | Clues that could be dropped |
| --- | --- | --- |
| the 18-clue puzzle for (28a) | 2 2 2 2 2 2 2 2 2 | 0 |
| the 20-clue puzzle for (28b) | 3 2 2 2 2 2 2 2 3 | 0 |

## 6. Why (28a) needs 18 and (28b) needs 20

The two squares are indistinguishable so far: same bound, same nine groups,
same nine usable pairs per group, same 9<sup>9</sup> candidates. The answer
says only that (28b)'s SAT instance came back unsatisfiable. The difference is
this:

| | six-cell unavoidable sets | lying inside a group | straddling two groups |
| --- | --- | --- | --- |
| (28a) | 81 | 81 | **0** |
| (28b) | 162 | 81 | **81** |

(28b) has 81 unavoidable sets that no single group can cover. Each of them can
be tested the moment the last group it touches has been settled, so they prune
the candidate tree as it is built:

| | Candidates | Surviving | Puzzles | Time |
| --- | --- | --- | --- | --- |
| (28b), 18 clues | 387,420,489 | 1,296 | **0** | 0.13 s |
| (28b), 19 clues | ~35 billion | 81,648 | **0** | 8.8 s |
| (28b), 20 clues | — | 3,190,104 | **648** | 6 min |
| (28a), 18 clues | 387,420,489 | 4,356,045 | **189** | 27 min |

The straddling sets take (28b) from 387 million candidates down to 1,296, and
none of those 1,296 turns out to have a unique solution. That is the whole
proof that 18 clues are impossible, and it runs in a tenth of a second.

## 7. The 2043 sets behind the answer's SAT instance

The answer describes the 19-clue instance as the one "which insists on having
at least one clue in each of the 2043 subsets of at most 18 cells that can be
rearranged into new solutions". The number is given and not explained, and it
is worth pinning down, because several things it might count are not 2043.

It is not the number of subsets of at most 18 cells that can be rearranged.
Every superset of an unavoidable set is unavoidable, so that number is enormous:
the unions of pairwise disjoint six-cell sets alone come to 272,079 for (28b),
and those are only the tidiest of them. What a clause set wants is the
**minimal** ones — a clause for a set that contains another is redundant.

Enumerating the minimal unavoidable sets of (28b) by size:

| Size | Minimal unavoidable sets | Cumulative time |
| --- | --- | --- |
| 4, 5 | 0 | |
| **6** | **162** | 24 ms |
| 7 – 15 | 0 | 8 min |
| **16** | **567** | 30 min |
| 17 | 0 | 1 h 31 min |
| **18** | **1,314** | 4 h 54 min |
| | **2,043** | |

So 2043 is exactly the number of minimal unavoidable sets of at most 18 cells,
and the answer's clause set is the irredundant one. Nothing needs correcting;
the number is right, and now it says what it counts.

Two things about that table are worth a second look. The gaps are wide — no
minimal set at all between 6 and 16 cells, and none at 17 — and every size that
occurs is even. Whether the evenness is forced I do not know; nothing in the
argument requires it, since a row can perfectly well be permuted by a 3-cycle.

The last row cost 4 hours 54 minutes, which is most of the running time of
everything in this reading put together. It is the one place where the
answer's SAT solver is doing something a plain search finds hard.

## 8. Two counts the answer does not give

The searches above are exhaustive, so they answer a question the answer leaves
open. The answer says that "all 18-clue characterizations must have a very
special form" and prints one it likes; it does not say how many there are.

| | Number of puzzles |
| --- | --- |
| 18-clue puzzles for (28a) | **189** |
| 20-clue puzzles for (28b) | **648** |

Both of the printed puzzles are among them — which is the real check on the two
negative results. A search that had wrongly discarded candidates would have
failed to find Knuth's own puzzles, and it finds both.

## 9. The transfer to (28c)

The answer closes with a parenthesis: the constructions for (28b) apply to
(28c) through the isotopism of answer 43. Answer 43 gives it as

$$c'_{ij} = b'_{(i\pi)(j\pi^-)}\pi, \qquad (i\_1, i\_0)\_3\pi = (i\_1, (i\_0+i\_1) \bmod 3)\_3$$

with $\pi$ on the row index, its inverse on the column index, and $\pi$ again on
the digit. Rather than trust a reading of that, the program searches for the
isotopism among the permutations a sudoku allows. It finds

* rows `[0 1 2 5 3 4 7 8 6]`, which is $\pi^{-1}$;
* columns `[0 1 2 4 5 3 8 6 7]`, which is $\pi$;
* digits `[0 1 2 4 5 3 8 6 7]`, which is $\pi$ again.

Rewritten, that is exactly the printed formula, and the program also checks the
formula in that shape directly. The constructions then carry over: the nine
groups become nine groups of (28c), still covering all 81 cells and still
needing two clues apiece, and the 20-clue puzzle becomes a 20-clue puzzle for
(28c) with a unique solution.

## 10. What I checked before reporting this

- **The unavoidable sets, independently of the search that found them.** Blank
  the set, give every other cell, count the completions; hand back one cell,
  count again. All 81 for (28a) and all 162 for (28b) are genuinely unavoidable
  and genuinely minimal.
- **The group partition, cell by cell.** For each of the nine groups and each
  of its nine cells: give that cell, blank the other eight, count. Never fewer
  than 2.
- **The search machinery, against Knuth's own answers.** The 20-clue search for
  (28b) recovers the printed puzzle; the 18-clue search for (28a) recovers the
  printed puzzle. This is what makes the two zero counts worth anything.
- **The clue distribution.** An early version of the search let the surplus
  clues fall in a single group. That is wrong — twenty clues can be three in
  each of two groups, and the answer's own puzzle is of that kind — so the
  search now tries every way of handing out the surplus. (The 18- and 19-clue
  results were unaffected, there being only one distribution in each case, but
  the 20-clue validation would have failed.)
- **The enumeration behind the 2043.** It walks the grid cell by cell with two
  prunes, and a prune that is slightly wrong loses sets in silence. So every
  set it reports is then tested the slow way, and the method itself is checked
  against a second one that shares none of its machinery: a minimal unavoidable
  set is the set of cells on which two complete squares differ, so the sets of a
  given size are the squares at that Hamming distance — an ordinary sudoku
  problem with one multiplicity item counting the changed cells. Split by how
  many cells each row changes (a row that changes at all must change at least
  twice), that route returns the same 162 at distance 6, in 45 milliseconds.
- **The transcriptions.** The three squares agree with answer 43's independent
  closed forms; the two puzzles agree with the squares they claim to determine.

## 11. Method

The program is a GWEB literate program. [`verify.w`](verify/verify.w) is the
source and `gtangle` produces the Go from it; the typeset document,
[`verify.pdf`](verify/verify.pdf), is committed beside it so it can be read
without installing GWEB.

To reproduce:

```sh
make tangle
cd taocp-7.2.2.1-exercises/55/verify && go build -o verify .
./verify -mode squares               # the three squares, against answer 43
./verify -mode puzzles               # both printed puzzles
./verify -mode groups -g b           # the nine groups and the bound
./verify -mode sets -g b -d 6        # the unavoidable sets, tested honestly
./verify -mode sets -g b -d 18       # the 2043, in about five hours
./verify -mode clues -g b -n 18      # 0 puzzles, a tenth of a second
./verify -mode clues -g b -n 19      # 0 puzzles, nine seconds
./verify -mode clues -g b -n 20 -v   # 648 puzzles
./verify -mode clues -g a -n 18 -d 15 -v   # 189 puzzles, about half an hour
./verify -mode isotopy               # the transfer to (28c)
```

## References

Donald E. Knuth, *The Art of Computer Programming*, Volume 4B (Addison-Wesley,
2022), §7.2.2.1, exercise 55 (p. 149), answer (p. 427); display (28) on p. 74
for the three squares; answer 43 for their closed forms and the isotopism;
§7.2.2.2 for the SAT solver the answer used. The problem of the minimum number
of clues is due to G. McGuire, whose name the exercise carries.
