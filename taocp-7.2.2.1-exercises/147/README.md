# TAOCP 7.2.2.1, Exercise 147: A Careful Reading

Written 5 September 2026, against Volume 4B, Addison-Wesley, first printing,
2022, and the errata file as of that date.

This is one reader's response to the request on Knuth's [news
page](https://www-cs-faculty.stanford.edu/~knuth/news.html): read an exercise
and its answer very carefully, then report back.

## What I found

| Item | Finding |
| --- | --- |
| Exercise 147 (statement) | No error. |
| Answer 147(a), both printed arrays | Genuine bricks. Reproduced. |
| Answer 147(b), the method | Correct, including the factor of 720. |
| Answer 147(b), the catalogue | 23 of its 24 lines reproduce exactly. |
| Answer 147(b), the 2×2×4 line | Four of its six entries disagree. |
| Answer 147(b), the closing parenthesis | Both near misses confirmed. |
| The cube names in answer 147(a) | Correct, but only under a handedness the text never states. |

Almost everything comes out. The two arrays the answer prints are genuine
bricks; the factor of 720 is exact; the remark that a repeated face colour only
ever appears on parallel sides holds in every solution of every case; and
twenty-three of the twenty-four catalogue lines reproduce to the digit.

The 2×2×4 line does not. My totals for that case agree with the answer's —
48 essentially different bricks, 244 solutions, and 17, 23 and 8 of them with
2, 4 and 8 automorphisms — but three of those 48 bricks end up with a different
pattern of face colours than the answer's numbers imply.

## 1. What the exercise asks

Exercise 146 introduces the thirty ways to paint the colours `{a,b,c,d,e,f}` on
the faces of a cube. Exercise 147 assembles them into **bricks**: an
$l \times m \times n$ cuboid of $l \cdot m \cdot n$ of the cubes, with matching
colours wherever two cubes touch and a single solid colour on each of the six
outside faces.

Part (a) asks for a brick of size 2 × 3 × 5, which uses all thirty cubes at
once. Part (b) asks for a catalogue of every brick there is.

## 2. The pieces

Answer 146(b) names a cube `uu'vv'ww'` when it can be placed with `u` on top,
`u'` on the bottom, `v` in front, `v'` in the back, `w` at the left and `w'` at
the right. Reading its constraints: `a` is always on top; any of the other five
may be opposite it; of the four that remain the smallest goes in front and its
partner in the back; and the last pair goes left and right, either way round —
which is exactly the choice between a cube and its mirror image. That gives
5 × 3 × 2 = 30.

The check that this is the right reading is a count that cannot come out by
accident:

| | Expected | Here |
| --- | --- | --- |
| cubes | 30 | 30 |
| cubes × orientations | 720 | 720 |
| distinct colourings of six labelled faces | 6! = 720 | 720 |

Every one of the 720 ways to paint six different colours on six labelled faces
is one of the thirty cubes in exactly one of its twenty-four orientations. No
cube is missed and none is counted twice. All ten cube names printed in answers
146 and 147 are in the set.

## 3. The two printed arrays

Answer 147(a) writes a brick down as a tensor, using the even/odd coordinates
of exercise 145: the triple $(x, y, z)$ names a vertex, edge, face or cell of
the brick according as it has none, one, two or three odd coordinates. Both of
the arrays the answer displays were transcribed and read back:

| | Cells | Distinct cubes | Face colours | Verdict |
| --- | --- | --- | --- | --- |
| the 1 × 2 × 2 array | 4 | 4 | ab × cc × de | a genuine brick |
| the magnificent 2 × 3 × 5 | 30 | 30 | aa × bb × cc | a genuine brick |

Both check out completely, and the 2 × 3 × 5 does use all thirty cubes. This is
a stronger test than it looks: a single mistranscribed letter would leave some
cell holding a colouring that is not a cube at all.

The six face colours the answer lists for one particular cell — `135 acbefd
035:a 125:b 134:d 136:f 145:e 235:c` — agree with my transcription character
for character, which pins the array down independently.

## 4. Handedness: a convention that is never stated

The cube names are chiral: a cube and its mirror image get different names. An
array of coordinates, on the other hand, is only an array until somebody says
how it sits in space, and nothing in the exercise or the answer says.

The answer names cubes in five places — the four cells of the 1 × 2 × 2 array,
and the cell `135` of the magnificent brick. Read one way round, all five come
out as their mirror images; read the other way, all five are exactly the names
the answer prints:

| Cell | Right-handed | Left-handed | The answer says |
| --- | --- | --- | --- |
| (1,1,1) | abcefd | **abcedf** | abcedf |
| (1,1,3) | abcedf | **abcefd** | abcefd |
| (1,3,1) | abcdef | **abcdfe** | abcdfe |
| (1,3,3) | abcdfe | **abcdef** | abcdef |
| (1,3,5) | acbedf | **acbefd** | acbefd |

So the answer is entirely self-consistent, and a reader who works through all
five examples can infer which reading was meant. But a reader who works through
only one will have no way to know, and half of them will get every name
backwards. One clause would fix it.

## 5. The exact cover problem, and the factor of 720

Answer 147(b) sets the problem up with a primary item per cell, a secondary
item per cube name, a secondary item per face, and six more primary items to
force each outside face to a solid colour. Then:

> The number of solutions is reduced by a factor of 720 if we remove all but one
> of the 720 options for position 111.

This is exact, and it is worth seeing why. The thirty cubes are closed under
permuting the six colours, so a permutation carries a brick to a brick; and a
permutation is pinned down completely by what it does to one cube's six faces.
Every orbit of 720 therefore contains exactly one brick whose first cell holds
a chosen placement. Solving 2 × 2 × 4 both ways confirms it:

| | Solutions |
| --- | --- |
| with the first cell pinned | 244 |
| with all 720 options for it | 175,680 = 244 × 720 |

## 6. The catalogue

For each shape and each pattern of face colours, the answer lists how many
essentially different bricks have 1, 2, 4 or 8 automorphisms. Two bricks are
the same when one becomes the other under a rotation or reflection of the box
together with a permutation of the colours.

**Twenty-three of the twenty-four lines reproduce exactly**: every line of
2 × 2 × 3, 2 × 2 × 5, 2 × 3 × 3, 2 × 3 × 4 and 2 × 3 × 5, together with the
smaller claims —

| Claim | Answer | Here |
| --- | --- | --- |
| 1 × 2 × 2 | 3 solutions, two bricks with 8 and 16 automorphisms | 3, same |
| 1 × 2 × 3 | unique, ab × cc × dd, 8 automorphisms | same |
| 2 × 2 × 2 | 26 = 48/24 + 48/8 + 48/4 + 48/8 | 26, same |
| 2 × 2 × 2 face colours | MacMahon ab × cd × ef, Kowalewski aa × bb × cd, Winter and the fourth aa × bc × de | same |
| no 3 × 3 × 3 brick | — | 0 solutions |
| a 3 × 3 × 3 less a corner | from 26 of the 30 | 66 solutions, all 26 cells |
| less the middle cube and the one above it | from 25 of the 30 | 80 solutions, all 25 cells |
| a repeated face colour is only ever on parallel faces | — | holds in every solution of every case |

The catalogue lists no case beyond 2 × 3 × 5. That is right: 2 × 2 × 6 and
2 × 2 × 7 both fit inside thirty cubes, and both have no solutions at all.

### The 2 × 2 × 4 line

```
                    the answer     here
aa x bb x cc      (0,  0, 1, 0)  (0,  0, 1, 0)
aa x bb x cd      (0,  0, 1, 0)  (0,  0, 1, 0)
aa x bc x dd      (0,  3, 4, 2)  (0,  3, 4, 1)
aa x bc x de      (0, 11,14, 2)  (0, 11,12, 2)
ab x cd x ee      (0,  2, 2, 3)  (0,  2, 2, 4)
ab x cd x ef      (0,  1, 1, 1)  (0,  1, 3, 1)
```

The totals are the same on both sides: 48 essentially different bricks, of
which 17 have 2 automorphisms, 23 have 4 and 8 have 8, accounting for
17 × 8 + 23 × 4 + 8 × 2 = 244 solutions. The disagreement is only about how
those 48 split by face colour, and it involves exactly three bricks: one with 8
automorphisms and two with 4. In each case the answer's pattern shows one more
repeated colour than I find.

Since the notation for face colours involves conventions — which axis is
written first, how the pairs are ordered — the cleanest way to state the
disagreement uses none of them:

> **Of the 244 bricks of size 2 × 2 × 4, how many show six different colours on
> the outside?** I get 22. The answer's line requires 14.

That count can be taken straight from a third model, which gives each colour a
secondary item so that no two sides can claim the same one. The model
reproduces the answer's numbers in the neighbouring cases and differs only
here:

| Case | Implied by the answer's `ab × cd × ef` entry | The third model |
| --- | --- | --- |
| 2 × 2 × 3 | (0, 0, 2, 0) → 8 | 8 |
| 2 × 2 × 5 | (0, 2, 5, 1) → 38 | 38 |
| 2 × 3 × 4 | (0, 7, 0, 0) → 28 | 28 |
| **2 × 2 × 4** | (0, 1, 1, 1) → **14** | **22** |

## 7. What I checked before reporting this

Twenty-three lines matching is not a licence to trust the twenty-fourth, so I
tried to break it.

- **Two independent programs.** Besides the literate program in
  [`verify/`](verify/), which uses this repository's XCC engine, I wrote a
  second one from scratch: different face indexing, a plain depth-first search
  instead of dancing cells, cubes identified by the least of their twenty-four
  rotated spellings instead of by the naming rule, and its own classification
  code. It shares no line with the first. It agrees on every number in this
  report, including the 22.
- **A third model** for the disputed statistic, described above, which
  reproduces the answer's own numbers in three neighbouring cases.
- **The factor of 720**, checked directly for 2 × 2 × 4: 175,680 = 244 × 720.
- **The classes account for the solutions.** For every case,
  $\sum |G| / |\mathrm{Aut}|$ over the classes equals the number of solutions
  found. This holds for the answer's numbers too, so it does not separate us —
  but it would have caught a mistake in the automorphism counts.
- **The convention-free statistics.** Counting the 244 solutions by how many
  colours show on the outside gives 4, 46, 172 and 22 for 3, 4, 5 and 6
  colours. The answer's line requires 4, 48, 178 and 14. No reordering of the
  face-colour notation can change these, since the number of distinct colours
  on the surface does not depend on how the pairs are written.
- **The unstated cases.** 2 × 2 × 6 and 2 × 2 × 7 fit in thirty cubes and are
  absent from the catalogue; both really are empty. So the catalogue is
  complete, and its silences are correct.

## 8. Method

The program is a GWEB literate program. [`verify.w`](verify/verify.w) is the
source and `gtangle` produces the Go from it; the typeset document,
[`verify.pdf`](verify/verify.pdf), is committed beside it so it can be read
without installing GWEB. The exact cover problems go to the XCC engine of this
repository.

To reproduce:

```sh
make tangle
cd taocp-7.2.2.1-exercises/147/verify && go build -o verify .
./verify -mode census                  # 30 cubes, 720 colourings, all names present
./verify -mode printed                 # both arrays, and the handedness
./verify -mode catalog                 # the whole catalogue, about 13 seconds
./verify -mode near                    # the two near misses
./verify -mode six -b 2x2x4            # 22
./verify -mode solve -b 2x2x4 -nopin   # 175680
./verify -mode solve -b 2x2x4 -dump    # every class, with its six side colours
```

Coordinates follow the answer's own convention throughout: the triple
$(x, y, z)$ with two odd entries names a face, and cell $(i, j, k)$ sits at
$(2i+1, 2j+1, 2k+1)$.

## References

Donald E. Knuth, *The Art of Computer Programming*, Volume 4B (Addison-Wesley,
2022), §7.2.2.1, exercise 147 (p. 143), answer (pp. 456–458); exercise 145 for
the even/odd coordinates; exercise 146 and its answer for the thirty cubes and
their names. The errata file amends two bibliographic details in answer 147 —
`(1893)` to `(1892)` on 7 April 2026, and `8-cube` to `eight-cube` — and
touches none of its numbers.
