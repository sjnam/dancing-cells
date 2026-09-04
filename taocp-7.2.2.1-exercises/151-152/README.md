# TAOCP 7.2.2.1, Exercises 151 and 152: A Careful Reading

Written 3–4 September 2026, against Volume 4B, Addison-Wesley, first printing,
2022, and the errata file as of that date.

This is one reader's response to the request on Knuth's [news
page](https://www-cs-faculty.stanford.edu/~knuth/news.html): read an exercise
and its answer very carefully, then report back.

## What I found

| Item | Finding |
| --- | --- |
| Exercise 151 (statement) | One loose term: "Hamiltonian cycle". |
| Answer 151 | Correct throughout. |
| Exercise 152 (statement) | No error. |
| Answer 152 | Correct throughout. |

Every quantitative claim in both exercises was recomputed and every one holds,
including the headline count of 6420 in answer 151(b) — which came out exactly
right twice, by two different routes — and the impossibility result at the end
of 152, which an exhaustive search confirms. Both parts of exercise 151 were
solved outright and independently verified.

The one defect is a word. Exercise 151 calls the path in its figure a
"Hamiltonian cycle"; it is a single closed loop, as the same sentence goes on
to say, but it is not Hamiltonian on any natural reading.

Three things here go past the book. The 8×12 array of exercise 152, for which
the answer prints no arrangement, was found and is drawn in the companion
program. No 64-cell rectangle admits the 32 non-crossing pieces, not just the
chessboard. And the chessboard mission misses by exactly one piece, which
turns the failed puzzle into a sharp one.

---

## 1. What the exercises ask

A path domino is a 1×2 tile with a curve drawn on it. The curve enters and
leaves through the midpoints of the six unit edges on the tile's boundary, so a
tile is decided by a matching of those six points — no point used twice, and
any number of them left alone. Two tiles are the same if one is the other
turned through 180°, which on a cyclic numbering of the points is the shift by
three.

Exercise 151 uses the tiles that switch on two or four of the six points, and
asks for all of them in an 8×9 array whose curves join into a single closed
loop. Exercise 152 completes the set with the blank tile and the eleven that
use all six points, and asks for all forty-eight in an 8×12 array.

## 2. The pieces

Counted from the definition rather than from the book, by enumerating matchings
modulo the half-turn:

| Subpaths | Points used | Configurations | Distinct pieces | Non-crossing |
| --- | --- | --- | --- | --- |
| none | 0 of 6 | 1 | 1 | 1 |
| one | 2 of 6 | 15 | 9 | 9 |
| two | 4 of 6 | 45 | 27 | 18 |
| three | all 6 | 15 | 11 | 4 |
| **total** | | 76 | **48** | **32** |

The 15 → 9 drop is six swapped pairs plus three centrally symmetric chords;
45 → 27 and 15 → 11 follow the same way. Exercise 151 uses the middle two rows,
9 + 27 = 36 pieces covering 72 cells; exercise 152 adds the other twelve, and
48 pieces cover 96 cells.

The 27 → 18 drop under "no crossings" is worth a sentence, because it is the
same fact that makes the factored method necessary. Of the three ways to pair
four points on a circle, exactly one crosses. So every four-on pattern stands
for exactly three pieces, of which one crosses — which is both the multiplicity
3 that answer 151 assigns and the reason 27 becomes 18. The 11 → 4 drop is the
five non-crossing perfect matchings of a hexagon, the Catalan number C₃,
falling into four classes under the half-turn.

## 3. Exercise 151

### 3.1 The printed figure, measured

The statement makes a claim about its own illustration — "only two of the
dominoes in the arrangement above are in horizontal position" — so the
illustration was measured rather than trusted. Page 143 was rendered at
1200 dpi, the grid rules located, and every interior edge tested for a drawn
line and every edge midpoint for a path crossing.

| Measurement | Found | Consistent with |
| --- | --- | --- |
| horizontal dominoes | 2 | the claim, exactly — rows 4–5, columns 1–2 |
| vertical dominoes | 34 | 36 pieces covering 72 cells |
| crossings on domino boundaries | 63 | (9×2 + 27×4) ÷ 2 |
| crossings on the outer border | 0 | the loop stays on the board |
| two-on pattern classes present | 9 × 1 | multiplicity 1 for patterns 1–9 |
| four-on pattern classes present | 9 × 3 | multiplicity 3 for patterns a–i |

Those last two rows are the strongest single piece of evidence in these notes.
The multiplicities the answer prescribes were not taken on faith and fed to a
solver; they were read back out of Knuth's own printed arrangement.

### 3.2 The model

Rebuilding answer 151's formulation literally — primary items 1–9 and a–i for
the on/off pattern classes, one primary item per cell, the two special items
H and V, and secondary items at the interior attachment points — reproduces its
stated dimensions on the nose: **63 h items and 64 v items, 127 in all**, over
72 cells and 18 pattern items, giving **2698 options**.

The two sample options check out too, and they explain a piece of notation the
text leaves silent. Read in the cyclic order, both have points 2, 3, 4 and 5
switched on and points 0 and 1 off — the same class, correctly labelled `a` in
both. The comma is not a typo: it separates the three attachment points on one
half of the domino from the three on the other, the two halves the half-turn
exchanges. In the first option the point that would be numbered 0 lies on the
outer border and is simply omitted, which is why that option lists five colours
and the second lists six.

### 3.3 The numbers

| Run | Solutions | Nodes | Time | Status |
| --- | --- | --- | --- | --- |
| 151(b), odd heights dropped | **6420** | 213,691,862 | 8m 19s | exhausted |
| 151(b), all placements | **6420** | 420,727,076 | 26m 15s | exhausted |
| 151(a), H=18 V=18 | 1,348,830 | 2,594,988,942 | 1h 30m | running |

Both 151(b) runs have H = 32 and V = 4.

"The algorithm finds 6420 solutions." It does — the same 6420 by both routes,
which also settles the parenthetical about omitting odd-height placements: the
shortcut is sound as well as faster, 69% less time here. And the aside for part
(a), "there are millions of solutions", is borne out: over 1.34 million had
been found after ninety minutes with the tree nowhere near exhausted.

### 3.4 Why 32 is the maximum

The answer asserts H = 32 and V = 4 without argument. One is easy to supply.
Each row holds 9 cells, an odd number, and horizontal dominoes cover an even
number of cells in any row; so every row contains an odd — hence at least one —
vertically covered cell. Eight rows need at least 8 such cells, each vertical
domino supplies 2, so V ≥ 4 and H ≤ 32. Both parts were then solved outright,
so the bound is attained.

### 3.5 Both parts solved

```text
151(a) · 18 horizontal, 18 vertical · 0.1 s
<>^^^<><>        151(b) · 32 horizontal, 4 vertical · 7.3 s
<>vvv^<>^        <><><>^<>
^<><>v<>v        <><><>v<>
v<><><><>        <>^<><><>
^^<>^^<>^        <>v<><><>
vv<>vv<>v        <>^<><><>
<>^^^^^^^        <>v<><><>
<>vvvvvvv        <><>^<><>
                 <><>v<><>
```

Solving takes the second stage the answer describes — "a (nontrivial) program,
whose structure has a lot in common with Algorithm X" — which must choose, for
each four-on domino, one of the three pairings, so that all 36 pieces are used
once and the arcs close into a single loop. Implemented as a backtracking
search with union-find (an arc that closes a cycle is rejected unless it is the
last one), it found a loop on the very first factored solution offered, in both
cases. An independent pass then re-derived each loop from scratch: 63 arcs,
36 distinct pieces, every endpoint of degree 2, one cycle. That matches the
answer's claim that such assignments are found "in a flash".

## 4. The one loose term

> An 8 × 9 arrangement, which nicely illustrates all 36 of the possibilities,
> is shown; notice that its path is a Hamiltonian cycle, consisting of a single
> loop.
>
> — statement of exercise 151, p. 143

A single loop it certainly is. Hamiltonian it is not, on any natural reading.
Measuring which cells the path enters shows that three of the 72 cells —
(2,0), (6,7) and (7,0) — are never entered at all; and if the dominoes rather
than the cells are taken as the vertices, 27 of the 36 are entered twice, since
they carry two subpaths apiece. The only reading under which the phrase is true
is the vacuous one, where the vertices are the 63 arc endpoints and any single
cycle is trivially Hamiltonian on its own vertex set.

This is a slip of vocabulary rather than a mathematical error: the clause
immediately following, "consisting of a single loop", states the property that
actually matters and that the figure has. It is the only defect these notes
turned up in either exercise.

## 5. Exercise 152

### 5.1 The model

"This (factored) problem is like the previous one, but with an additional
pattern j of multiplicity 11, and a blank pattern of multiplicity 1, but
without H or V." Rebuilt, that is 20 on/off pattern classes whose
multiplicities sum to 48 — one blank, nine at 1, nine at 3, and the
all-six-on pattern at 11 — over 96 cells with 84 + 88 = **172 secondary
items** and **3925 options**. Everything the sentence describes is there.

### 5.2 The chessboard

> Notice that exactly 32 of the 48 path dominoes have no crossings. Thus it is
> irresistible to try to place them on a chessboard, so as to form a single
> noncrossing loop. Unfortunately, Algorithm M tells us that such a mission is
> impossible …
>
> — answer 152, pp. 459–460

Exactly 32, by enumeration, as the table in §2 shows. And it is impossible: the
model — 64 cells, 20 pattern classes, 56 + 56 = 112 secondary items — was built
and searched to exhaustion, **no solution in 459,686,670 nodes, 17m 48s**.

Searching it directly was too slow to finish (an hour and 1,586,612,830 nodes
with no end in sight), so the search was cut down by symmetry. The blank piece
is unique, so every solution places exactly one; the board and the piece set
are both invariant under the dihedral group of order 8; so any solution can be
turned until its blank lies in a fundamental domain. Pinning the blank to one
representative of each of the 16 orbits of a domino placement on an 8×8 board —
Burnside gives (112 + 8 + 8) ÷ 8 = 16 — makes the proof three times cheaper
without losing a solution.

### 5.3 The 8×12 array

This is the one the answer leaves without a picture:

> One needs to be lucky to find a solution; the author struck it rich with
> Algorithm M after 35.1 Tμ.
>
> — answer 152, p. 459

One was found here too:

![The 8 by 12 array: all forty-eight path dominoes, their arcs forming one
closed loop](loop8x12.png)

The search was split the same way as the chessboard proof. The blank piece is
unique, and the 172 placements of a domino on an 8×12 board fall into 48 orbits
under the four symmetries of a rectangle; pinning the blank to one orbit gives
an independent chunk, and the union of the 48 chunks is the whole problem. Six
chunks ran in parallel.

| | |
| --- | --- |
| chunk that succeeded | 4 (the fifth) |
| nodes | 3,682,952,464 |
| time | 3h 25m |
| factored solutions examined | 1 |
| verification | one closed loop, 96 arcs, 48 distinct pieces |

The arcs closed into a single loop on the very first factored solution the
chunk offered. Node counts are not mems, so none of this is a comparison with
the author's 35.1 Tμ — only a record of what it cost here.

This is one solution, not the solution. Its tiling is carried to itself by
none of the three non-trivial symmetries of the rectangle, so its images under
them are three further solutions and there are at least four in all. How many
there are altogether was not determined: the search stopped at the first hit,
and the other 47 chunks were never run to exhaustion.

The run is deterministic, so it can be repeated:

```sh
verify -set 48 -rows 8 -cols 12 -blankat 4 -loop
```

---

## 6. Past the last bracket

Knuth's closing line — "Something interesting, however, can surely be done with
those 32" — is an invitation with no answer attached. Two questions follow from
it, and both are cheap to settle.

### 6.1 No 64-cell rectangle works either

Thirty-two dominoes cover 64 cells, and the chessboard is only one of the four
rectangles that hold them. None of the others works.

| Board | Outcome | Nodes | Time |
| --- | --- | --- | --- |
| 1 × 64 | impossible | 0 | instant |
| 2 × 32 | impossible | 0 | instant |
| 4 × 16 | impossible | 64,111,262 | 2m 39s |
| 8 × 8 | impossible | 459,686,670 | 17m 48s |

The two thin boards fall without a single search node, for a reason that reads
in one line: a three-subpath piece uses all six of its attachment points, so
none of them may lie on the border — the piece has to sit strictly inside the
board. On a board one or two cells tall no domino has all six edges interior,
and four such pieces have to go somewhere.

The 4×16 run was done twice, with and without the symmetry reduction:
21,300,024 nodes against 64,111,262, the factor of three the four-group
predicts, and the same outcome — a useful check on the reduction that carries
the 8×8 proof.

### 6.2 The mission misses by exactly one piece

Put all 48 pieces on the table but allow at most k of the self-crossing ones.
At k = 0 the non-crossing capacities add up to 32, exactly how many dominoes
the board holds, so that is the original question — and it has no solution. At
k = 1 the board tiles in 0.62 seconds, 237,760 nodes.

The deficiency is one piece, and it is not a particular piece. Ten of the
twenty pattern classes own a crossing piece; confining the single crossing to
each of those ten in turn, every one of them works.

| Class | Nodes | Time |
| --- | --- | --- |
| p12 | 182 | 2 ms |
| p11 | 198 | 2 ms |
| p7 | 34,722 | 82 ms |
| p18 | 85,589 | 158 ms |
| p16 | 197,456 | 478 ms |
| p17 | 198,783 | 379 ms |
| p13 | 219,676 | 392 ms |
| p10 | 822,963 | 1.5 s |
| p15 | 2,124,024 | 4.5 s |
| p19 | 7,818,354 | 18.8 s |

There is no culprit to point at.

Swapping a non-crossing piece for the crossing piece of the same class leaves
the on/off pattern untouched: the same six points are switched on, only the
joining inside changes. Since the factored problem sees nothing but the pattern
census, that swap does exactly one thing — it raises one class's budget from 2
to 3 and lowers another's from 2 to 1. So the obstruction is not geometric and
not local. It is the census itself, and it is one unit away from being
realizable, in any direction.

### 6.3 A puzzle to put in its place

That gives the failed mission a repair, sharp at both ends:

> A single closed path can be drawn on the chessboard with 32 distinct path
> dominoes so that it crosses itself exactly once — and one that never crosses
> itself does not exist.

The upper half comes out on the very first factored solution offered, in 0.63
seconds and 237,760 nodes, and an independent pass then checks it: 57 arcs
closing into one cycle, 32 distinct pieces, every endpoint of degree 2. The
arc count is fixed in advance by the census — 9 pieces of one subpath, 18 of
two and 4 of three give 9 + 36 + 12 = 57 — so it is not a number the search
was free to choose. The lower half is the exhaustive result of §5.2. One is
therefore not merely attainable but minimal.

```sh
./verify -set 48 -rows 8 -cols 8 -cross 1 -loop
```

---

## 7. Method

Three independent lines of attack were used, and they agree wherever they
overlap.

1. **Enumeration.** The piece counts were derived twice, once in Python and
   once inside the Go model builder, from the definition of a matching modulo
   the half-turn — never copied from the book.
2. **Image measurement.** The 8×9 figure was recovered from the PDF by locating
   grid rules and testing every interior edge for a drawn line and every edge
   midpoint for a path crossing. The recovered tiling covers exactly 72 cells
   and its pattern census matches the model's multiplicities, which is a strong
   check on both.
3. **Search.** The factored models were solved with the MCC engine, and the
   loop assignment with a purpose-built backtracker. Two separately written
   model generators produced identical option counts (2698) for the 8×9
   problem, and the second reproduced 151's solved arrangement independently.

The program is kept in [`verify/`](verify/). It is a GWEB literate program —
[`verify.w`](verify/verify.w) is the source, and `gtangle` produces the Go from
it. The typeset document, [`verify.pdf`](verify/verify.pdf), is committed
beside the source, so it can be read without installing GWEB; the 8×12 loop is
drawn there in MetaPost.

To reproduce:

```sh
make tangle                     # gtangle verify.w -> verify.go
cd taocp-7.2.2.1-exercises/151-152/verify && go build -o verify .
./verify -mode census -set 48                       # 1, 9, 27, 11
./verify -mode census -set nc32                     # 1, 9, 18, 4
./verify -set 36 -rows 8 -cols 9 -h 32 -v 4 -loop   # exercise 151(b)
./verify -set nc32 -rows 8 -cols 8 -symblank -count # the impossibility
./verify -set 48 -rows 8 -cols 8 -cross 0 -symblank -count  # again, other model
./verify -set 48 -rows 8 -cols 8 -cross 1 -loop     # crossing exactly once
./verify -set 48 -rows 8 -cols 8 -cross 1 -xclass 19  # one nominated class
./verify -set 48 -rows 8 -cols 12 -blankat 4 -loop  # the 8x12 array
```

Node counts are those of the MCC engine and are not comparable to Knuth's mem
counts. Timings come from a single desktop machine and are indicative only.
Coordinates are given as (row, column) with the origin at the top left,
matching the answer's own convention.

## 8. References

- D. E. Knuth, *The Art of Computer Programming*, Volume 4B (Addison-Wesley,
  2022), §7.2.2.1, exercises 151–152 (pp. 143–144), answers (pp. 459–460).
- D. E. Knuth, *Changes to Volume 4B*,
  <https://cs.stanford.edu/~knuth/err4b.textxt> — no entry touches either
  exercise.
- The 36 path dominoes were first studied by Ed Pegg Jr. in 1999, and first
  placed into a single-loop 8 × 9 array by Roger Phillips later that year.
