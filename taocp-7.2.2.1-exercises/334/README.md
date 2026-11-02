# TAOCP 7.2.2.1, Exercise 334: A Careful Reading

Written 4 September 2026, against Volume 4B, Addison-Wesley, first printing,
2022, and the errata file as of that date. Revised 2 November 2026, after
Knuth's reply showed that two of the discrepancies I reported were a bug in my
own program; see [What went wrong in the first version](#7-what-went-wrong-in-the-first-version).

This is one reader's response to the request on Knuth's [news
page](https://www-cs-faculty.stanford.edu/~knuth/news.html): read an exercise
and its answer very carefully, then report back.

## What I found

| Item | Finding |
| --- | --- |
| Exercise 334 (statement) | No error. Amended for wording, 4 June 2025. |
| Answer 334, the method | Correct, and it works exactly as described. |
| Answer 334, cube count 1,130,634 | Reproduced exactly. |
| Answer 334, cube cubie sets 13,842 | A typo for 15,842; Knuth has confirmed. |
| Answer 334, X-wall counts 612 / 275 | Reproduced exactly. |
| Answer 334, W-wall counts 282 / 33 | Reproduced exactly. |

The method the answer describes is right, and following it reproduces every
number in the answer. The one exception is the cube's 13,842 sets of cubies,
which differs from my 15,842 in a single digit; Knuth confirms it is a typo.

The first version of these notes said otherwise. It reported 162 / 22 for the
W-wall and 494 / 208 for the X-wall, and called those discrepancies in the
answer. They were not: my program missed some placements of the pieces, in a
way that could not show up in the cube but did show up in the two walls.
Section 7 explains how.

Everything the exercise itself says is correct, and so is every piece of
geometric data printed in the answer — the visible counts, the list of cubies
that may hide, the distances, and the aside about cubie 450 being below ground.

## 1. The exercise

The seven Soma pieces cannot build the W-wall of Fig. 75; exercise 326 proves
it by a factoring argument. Exercise 334 relaxes the goal: build something that
merely *looks* like the W-wall from the front, the way a film set looks like a
town. The same is asked for the X-wall and for the 3 × 3 × 3 cube, and all
seven pieces must be used.

The one technical fact the exercise supplies is the projection its pictures
use:

$$(x, y, z) \mapsto (30x - 42y,\ 14x + 10y + 45z)\,u$$

Here is one of the façades this reading finds. From the front it cannot be told
from the W-wall of Fig. 75; from behind you can see straight through it, and
the two cubies doing the cheating.

![One W-wall façade, drawn from the front and then from behind and
below](wwall.png)

## 2. What the projection fixes

The three axes go to (30, 14), (−42, 10) and (0, 45): z straight up, x to the
right and slightly up, y to the left and slightly up. The line of sight is the
kernel of the map. Solving 30x = 42y together with 14x + 10y + 45z = 0 gives
the kernel direction (315, 225, −148), so the viewer stands at (−315, −225,
148) and sees each cubie's top face together with its −x and −y faces. That is
exactly the three-faced look of the book's illustrations.

Two consequences matter.

**The problem is well posed.** The kernel is a lattice vector, so two cubies
*can* project onto each other — but only 315 steps apart, far outside any
region in play. Within the board the projection is one-to-one on cubies.
Therefore a picture determines its visible cubies exactly, and "the façade
looks right" means precisely "the façade contains every visible cubie of the
target and every other cubie of the façade is hidden". No weaker condition and
no stronger one.

**Moving away means +x or +y.** Both increase depth away from the viewer, which
is what makes the answer's notion of distance work.

## 3. The Soma pieces

Piece 1 is the bent tricube; the other six are tetracubes, so the set has
3 + 6 × 4 = 27 cubies. I took the coordinates of the bent piece and of the ell
from §7.2.2.1 itself, which gives `1 000 001 010` as a placement of the first
and lists the ell's canonical placements as shifts of (000, 010, 020, 100).

The check that the seven shapes are the right seven is the cube:

| | Knuth | Here |
| --- | --- | --- |
| options for the 3 × 3 × 3 cube | 688 | 688 |
| solutions | 11,520 | 11,520 |

Only the 24 rotations are used. Allowing reflections as well is not merely
unphysical — it breaks this check at once, turning 11,520 into 54,048.

## 4. Distance: recovering a word the answer does not define

The answer bounds the search with a sentence that carries the whole argument:

> Infinitely many cubies lie behind a wall; but it suffices to consider only
> the hidden ones whose distance is at most 27 − v from the v visible ones.

"Distance" is not defined anywhere. It cannot be ordinary face-adjacency
distance: that gives the X-wall the profile (10, 7, 5, 3, 3, 2, 1) rather than
the answer's (9, 7, 6, 3, 3, 2, 1).

The reading that works is this. A hidden cubie q is reached from a visible
cubie v by stepping away from the viewer, so

$$d(q) = \min_v\ (q_x - v_x) + (q_y - v_y) + |q_z - v_z|$$

over the visible cubies v with $v_x \le q_x$ and $v_y \le q_y$. Under this
reading two independent pieces of the answer's own data come out exactly right:

| Data printed in the answer | Here |
| --- | --- |
| W-wall, distance 1 | 241 242 251 252 331 332 421 422 521 522 |
| W-wall, distance 2 | 341 342 351 352 431 432 531 532 621 622 |
| X-wall, distance profile | (9, 7, 6, 3, 3, 2, 1) |
| 450 is "invisible at distance 2" | 451 is at distance 1, so 450 is at 2 |

Two shapes fitted by one rule, plus the parenthetical aside, is enough for me
to be confident this is what was meant.

## 5. Gravity: recovering a rule the answer does not state

The answer says to reject the solutions that "are disconnected or violate the
gravity constraint of exercise 333", and exercise 333 gives pictures rather
than a rule. Its structures include a cantilever and a hollow mushroom, so
overhangs are clearly allowed; what is not allowed is a piece floating in
mid-air.

Since Soma pieces are rigid bodies, the test belongs to the piece and not to
the cubie:

> A piece stands if one of its cubies is on the floor, or if one of its cubies
> rests directly on a cubie of another piece. Equivalently, a piece stands
> unless it could be slid straight down without hitting anything.

Applied to the cube together with connectedness, this gives **1,130,634** — the
answer's number, to all seven digits. That is the strongest single check in
this reading, and it is what persuades me that the projection, the visibility
test, the piece set and the filters are all the ones the answer used.

Two other readings were tried and fail: requiring every cubie to have support
directly beneath it leaves only the solid cube, and requiring the centre of
mass to lie over the footprint removes almost nothing.

## 6. The three façades

Each façade must show every visible cubie of its target and may add any hidden
cubies within distance 27 − v. Every placement of every piece in that region is
an option, the visible cubies are primary items, the hidden ones secondary.

| | W-wall | X-wall | Cube |
| --- | --- | --- | --- |
| cubies of the target | 27 | 27 | 27 |
| visible, v | 25 | 19 | 19 |
| cubies that may hide | 20 | 31 | 27 |
| options | 1011 | 979 | 1138 |
| solutions of the cover problem | 282 | 1197 | 2,540,780 |
| of those, connected | 282 | 1034 | 1,384,332 |
| of those, also standing | **282** | **612** | **1,130,634** |
| different sets of cubies | **33** | **275** | **15,842** |
| the answer says | 282 / 33 | 612 / 275 | 1,130,634 / 13,842 |

Knuth's own run of the cube agrees at every stage: 2,540,780 solutions, of
which 1,384,332 are connected and 1,130,634 are also stable. For the W-wall he
sent me his input file and his 282 solutions; all of them are connected and
stable, as they are here.

## 7. What went wrong in the first version

A placement of a piece is fixed once you say which cubie of the turned shape
goes into which cell. My first program tried only one cubie per shape: the
least corner of the shape's bounding box. It slid that corner into each cell of
the region in turn and kept the placement if the other cubies fitted too.

But the corner of the bounding box need not be a cubie of the shape. A tee
lying flat with its crossbar behind its stem leaves it empty, and so does the
claw turned upside down. For such a shape, a placement whose corner falls
*outside* the region was never generated, even though every one of its cubies
lies inside.

Whether that loses anything depends on the shape of the region, not on the size
of the search:

| | W-wall | X-wall | Cube |
| --- | --- | --- | --- |
| options, first version | 974 | 944 | 1138 |
| options, corrected | 1011 | 979 | 1138 |
| options lost | 37 | 35 | 0 |
| standing façades lost | 120 of 282 | 118 of 612 | 0 |

The cube's region is a box with hidden cubies stacked behind it, and nothing
was lost there. The census of 688 options and 11,520 solutions is inside a box
too. The walls bend, and a piece wrapping around a bend from behind has its
bounding-box corner out in the empty space in front of the wall. Of the 37
W-wall options lost, 31 have their corner in column 22, just in front of the
middle bend at 33, and the other six in columns 12 and 21 beside it. The X-wall
lost 35 the same way. So the hardest of the three counts agreed with Knuth to
the last digit while the two easy ones did not.

Knuth's reply in November 2026 included his input file for the W-wall. Its
cell names are the answer's with 1 subtracted from x and y (his 511 is the
answer's 621), and its 25 primary and 20 secondary items are exactly the
visible cubies and the pool used here. So only the options could differ, and
listing the options this program generates showed the missing ones at once.
For example, the bent piece on the answer's 231, 321, 331 (his `W 121 211 221`)
has its bounding-box corner at 221, which is not in the region.

The corrected program tries every cubie of the shape against every cell and
keeps each placement once. It reproduces 282 / 33 and 612 / 275, and the cube is
unchanged. Its 282 W-wall solutions are exactly Knuth's 282, compared one by
one as sets of pieces. The 162 of the first version are among them; the other
120 each use at least one of the 37 lost options.

The comparison turned up one more slip, which changed no count: I had the
names of the two twists the wrong way round, so that my L-twist was always his
R. The program now uses the coordinates from his file for both.

## 8. What I checked, and why it did not catch this

The cube's exact agreement had made me distrust my own wall numbers, so I tried
to break them. Those checks are listed here with what each was really worth,
since most of them shared the faulty step.

- **Two programs.** A Python prototype and the Go program in
  [`verify/`](verify/) shared no code and agreed on every number, so the
  prototype must have missed the same placements, most likely in the same way.
  Two programs built on one idea check the coding, not the idea.
- **Three solvers** for the W-wall: Knuth's XCC engine, a hand-written exact
  cover, and solving each of the 190 possible pairs of extra cubies separately.
  All three were given the same options, so they tested the solving and not
  the options.
- **A larger pool.** Widening the hidden-cubie pool beyond the answer's 20 cells
  leaves the W-wall at 282 with the corrected program; within the box I sweep
  it grows to 42 cells and stops. The answer's bound is sound.
- **Underground cubies.** Allowing them makes no difference to the cover
  problem; with the floor lowered, the gravity test rejects everything.
- **A weaker requirement.** Since the projection is one-to-one on cubies,
  "the picture matches" cannot be weaker than "every visible cubie is present".
  This is a proof, not an experiment, and it still stands.
- **The X-wall's shape.** I enumerated every 27-cubie shape made of two
  crossing walls. Exactly five have v = 19, and only the symmetric 5 × 5 cross
  matches both the figure and the answer's distance profile. With the corrected
  program it gives 612, as the answer says.
- **Mirror pieces.** Allowing reflections gives the W-wall 1132 solutions in
  34 sets (the first version said 600 in 22), and it breaks the cube check by
  turning 11,520 into 54,048.
- **The answer's own example.** The first of the three structures the answer
  draws "as seen from behind and below" shows 11 exposed bottom faces where the
  bare W-wall shows 9, so it uses exactly two extra cubies, as this model
  requires. Counting its faces by colour narrowed it to three of the 22 sets of
  the first version. Those 22 sets are all among the 33, so the illustration is
  still inside the solution set; I have not repeated the colour count against
  the 11 new sets.
- **The answer's own parity argument.** Answer 326 shows the W-wall has ten
  cubies with x, y and z all odd while the pieces can cover at most nine. So
  both extra cubies must sit at even positions. Of the 20 cells available, 331,
  351 and 531 are odd, and none of them appears in any of the 33 sets.

## 9. Method

The program is a GWEB literate program. [`verify.w`](verify/verify.w) is the
source and `gtangle` produces the Go from it; the typeset document,
[`verify.pdf`](verify/verify.pdf), is committed beside it so it can be read
without installing GWEB. The exact cover problems go to the MCC/XCC engine of
this repository.

To reproduce:

```sh
make tangle
cd taocp-7.2.2.1-exercises/334/verify && go build -o verify .
./verify -mode census              # 688 options, 11520 solutions
./verify -shape wwall -v           # v = 25, the two distance shells, 282
./verify -shape xwall -v           # v = 19, the profile (9,7,6,3,3,2,1), 612
./verify -shape cube               # 1130634
```

Timings come from a single desktop machine and are indicative only.
Coordinates are written as three digits, `xyz`, matching the answer's own
convention, with the floor at z = 1.

## References

Donald E. Knuth, *The Art of Computer Programming*, Volume 4B (Addison-Wesley,
2022), §7.2.2.1, exercise 334 (p. 166), answer (pp. 508–509); exercise 326 and
its answer for the factoring proof; exercise 333 for the gravity structures;
the discussion of the Soma cube at (39)–(40) for the 688 options and 11,520
solutions.
