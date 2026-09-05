# TAOCP 7.2.2.1, Exercises 305 and 306: A Careful Reading

Written 5 September 2026, against Volume 4B, Addison-Wesley, first printing,
2022, and the errata file as of that date.

This is one reader's response to the request on Knuth's [news
page](https://www-cs-faculty.stanford.edu/~knuth/news.html): read an exercise
and its answer very carefully, then report back.

## What I found

| Item | Finding |
| --- | --- |
| Exercises 305 and 306 (statements) | No error. |
| Answer 305, the coordinates | Right; its four placements are one piece. |
| Answer 305(a), 4 · 183, and four options per piece | Reproduced exactly. |
| Answer 305(a), the eight symmetric-shape classes | Right; see section 4. |
| Answer 305(b), 501484 and the 164 | Reproduced exactly. |
| Answer 305(c), 288 = 2 · 4 + 4 · 70 | Reproduced exactly. |
| Answer 305(d), 2 · 2696, 2 · 95, 2 · 3 | Reproduced exactly. |
| Answer 305(e), 69120 and 157398 | Reproduced exactly. |
| Answer 306, (0, 0, 4 · 9, 8 · 8) | Right; two restrictions go unsaid. |
| Answer 306, six spurious classes and eleven solutions | Reproduced exactly. |
| Answer 306, five of eleven without the defect | Right; see section 9. |

Every number in both answers came out. Two of them came out only after working
out what a phrase had to mean; those are sections 4 and 9 below, and they are
the only places where a reader is left to guess.

| | Answer | Here |
| --- | --- | --- |
| 305(a) 5×5 windmill | 4 · 183 | **732** |
| 305(b) 4×5 box | 2 · 4 + 4 · 125369 | **501,484** |
| 305(c) 2×10 box | 2 · 4 + 4 · 70 | **288** |
| 305(d) 7×7, upper layer a 4×5 rectangle | 2 · 2696 | **5,392** |
| 305(e) 8×8 | 2 · 4 + 4 · 17278 | **69,120** |
| 305(e) 9×9 | 2 · 75 + 4 · 39312 | **157,398** |
| 306, 3×9 / 4×8 / 5×7 / 6×6 | 0, 0, 4 · 9, 8 · 8 | **0, 0, 36, 64** |
| 306, essentially different | eleven | **11** |

## 1. What the exercises ask

Scale a square grid by $1/\sqrt2$ and turn it by 45°, and half its vertices land
on the original ones while the other half land at the centres of the original
cells. So a small tilted square of area 2 can be glued over an ordinary domino
of area 4 + 4, giving a two-layer piece. There are ten of them: the **windmill
dominoes**.

Exercise 305 asks for five things: (a) an arrangement of four of them whose
upper layer looks like a windmill; (b) all ten inside a 4 × 5 box; (c) all ten
inside a 2 × 10 box; (d) all ten with the upper layer filling a
$(4/\sqrt2) \times (5/\sqrt2)$ rectangle; (e) the same for
$(2/\sqrt2) \times (10/\sqrt2)$. Exercise 306 asks for the arrangements in which
the twenty large squares form a snake-in-the-box cycle and so do the twenty
small ones.

## 2. The pieces and the coordinates

Answer 305's coordinates are the even/odd scheme of exercise 145: the large
square in row $i$ and column $j$ is the pair $(2i+1)(2j+1)$, and a small tilted
square is the midpoint of the two large squares it straddles. So a point with
two odd coordinates is a large square, a point with one is a small one, and a
point with none is a corner of the large grid.

Building the ten: take a large domino, collect the small squares that touch
either of its two squares, pair each with a diagonal neighbour, and reduce
under quarter turns and even slides. Exactly ten come out — and reflections are
*not* allowed in that reduction, since a windmill domino and its mirror image
are different pieces.

The check that this is the right set is the one the answer hands over. It
prints four placements of "the leftmost piece":

$$
\{13, 15, 12, 23\},\quad \{33, 53, 23, 32\},\quad
\{33, 31, 34, 23\},\quad \{31, 11, 41, 32\}.
$$

They are indeed the four quarter turns of a single piece, and that piece is one
of my ten.

A count worth having for later: fixing a large domino's position and
orientation, there are exactly **20** ways to glue a small domino onto it, one
for each of the ten pieces in one of its (at most two) matching turns.

## 3. Which layer has to be filled

This is the hinge of exercise 305, and the answer states it only by implication.

| | Lower layer (large squares) | Upper layer (small squares) |
| --- | --- | --- |
| (a), (b), (c) | fills the box exactly | must merely not overlap |
| (d), (e) | must merely not overlap | fills a rectangle exactly |

Parts (b) and (c) say "inside a 4 × 5 box, without overlapping": the box is
filled, and the upper layer is free to arrange itself however it likes inside.
Parts (d) and (e) say "the upper layer fills a rectangle": now it is the small
squares that must tile exactly, and the large ones are only forbidden to
overlap.

Reading this the wrong way round gives zero solutions in (b), which is how I
found out: 31 small squares cannot be covered exactly by 20.

In the exact cover problem this is the difference between a primary item and a
secondary one, and nothing else changes.

## 4. Part (a), and what "a symmetric shape" means

Part (a) is a 5 × 5 box with the small squares of every option restricted to
one of the four blades $\{34,45\}$, $\{47,56\}$, $\{76,65\}$, $\{63,54\}$ — a
pinwheel turning about the middle of the box. Only four pieces are used, so the
piece items are secondary; the eight small squares are the primary ones.

| | Answer | Here |
| --- | --- | --- |
| options per piece | four | **four**, for each of the ten |
| solutions | 4 · 183 | **732**, in 183 classes of four |

The answer then says: "Here are six of the eight classes of equivalent
solutions whose large squares form a symmetric shape."

Eight is not what I get if "symmetric shape" means what it usually means. Of
the 183 classes, **21** have a large-square shape that some reflection or turn
about its own centre carries to itself; 16 of those have a mirror symmetry.
Eight is the count of classes whose large squares are symmetric about the
horizontal or the vertical axis **of the 5 × 5 frame** — that is, whose picture
as drawn in the box is left-right or top-bottom symmetric.

To be sure, I recovered all six printed pictures cell by cell:

```text
#####      ##.##      .#.#.      ###        #.#        .#.
..#..      .#.#.      .#.#.      ###        #.#        ###
..#..      .#.#.      ##.##      .#.        #.#        ###
..#..                            .#.        #.#        .#.
```

All six are symmetric about a vertical axis and all six sit centred in the
frame, so both readings agree on them; but only the narrow reading gives eight.
The five classes whose large squares are symmetric about a *diagonal* are not
among the answer's eight — for example

```text
.##
###
###
```

is carried to itself by the main diagonal, but by nothing else.

## 5. Parts (b) and (c)

| | Answer | Here |
| --- | --- | --- |
| (b) 4 × 5, options | — | 396 |
| (b) solutions | 2 · 4 + 4 · 125369 | **501,484**: 4 of 2, 125,369 of 4 |
| (c) 2 × 10, options | — | 240 |
| (c) solutions | 288 = 2 · 4 + 4 · 70 | **288**: 4 classes of 2, 70 of 4 |

Answer 305(b) also mentions "the 164 asymmetric classes whose small squares do
at least form a symmetric shape". There are 664 such arrangements. Dividing by
four gives 166, which is wrong: eight of the 664 lie in the four classes of
size two. Take those out and $656/4 = 164$ exactly.

That is a small trap worth naming, because it is the same one the answer's own
notation $2 \cdot 4 + 4 \cdot 125369$ is designed to avoid: a class contributes
as many arrangements as its stabilizer allows, never simply the group order.

## 6. Parts (d) and (e)

The upper layer has to fill a rectangle of twenty small squares, which is
tilted 45° relative to the large grid. Answer 305 gives its corners, and they
check out as rectangles in the small-square lattice: {47, 74, 8b, b8} is 4 × 5
for part (d), and {34, 43, cd, dc} and {45, 54, de, ed} are each 2 × 10 for the
two cases of part (e).

| | Answer | Here |
| --- | --- | --- |
| (d) 7 × 7 | 2 · 2696, all asymmetric | **5,392**, 2,696 classes of 2 |
| (d) fitting a 5 × 5 box | 2 · 95 | **190** |
| (d) the printed symmetric shape | 2 · 3 | **6** |
| (e) 8 × 8 | 2 · 4 + 4 · 17278 | **69,120**: 4 classes of 2, 17,278 of 4 |
| (e) 9 × 9 | 2 · 75 + 4 · 39312 | **157,398**: 75 classes of 2, 39,312 of 4 |

The "2 · 3" needed pinning down. Fourteen distinct large-square shapes among
the 5,392 arrangements are symmetric, and three of them are realised by exactly
six arrangements apiece, so the count alone does not say which one is drawn. I
read the upper layer off the printed picture instead — the ten white dominoes
of its 5 × 4 grid — and searched for arrangements with that upper layer. There
are 37, and exactly one has a symmetric large-square shape:

```text
.###.
####.
#####
#####
..###
```

which is realised by six arrangements. So 2 · 3 is right, and it is that shape.

## 7. Exercise 306, and why the answer's model did not finish here

Answer 306 describes one large problem for Algorithm M: an item `pxy` deciding
whether square `xy` is used, an item `#xy` giving a used square exactly two
used neighbours, and items of multiplicity $[0 .. 3]$ forbidding a bare
4-cycle. It warns that nonsharp branching is needed.

Built exactly as described, that problem did not finish on even the 3 × 9 case
here in the time I was willing to give it. So I took the structure apart
instead, and the decomposition turns out to be short.

**An induced cycle has no chords.** So if two large squares share an edge and
both lie on the cycle, they are neighbours *along* the cycle. The ten large
dominoes are therefore a perfect matching of a 20-cycle — and a cycle of length
20 has exactly **two** perfect matchings. The same argument applies to the
upper layer.

That gives a three-step algorithm:

1. Enumerate the snake-in-the-box 20-cycles. This is a small exact cover
   problem in its own right: two items per cell, an item of multiplicity
   $[20 .. 20]$ to fix the size, and the answer's own $[0..3]$ items to forbid a
   4-cycle. Connectivity is checked afterwards.
2. Take each of the cycle's two matchings.
3. Give each large domino one of its twenty small dominoes, keeping the ten
   pieces distinct and the upper layer growing towards a cycle.

| Box | 20-cycles filling it |
| --- | --- |
| 3 × 9 | 1 |
| 4 × 8 | 71 |
| 5 × 7 | 687 |
| 6 × 6 | 1,398 |

Step 1 takes 0.06 seconds; the whole of exercise 306 takes four and a half
minutes.

## 8. What answer 306 counts

Two restrictions have to be honoured to land on the answer's numbers, and
neither is stated as a restriction.

* **No 4-cycle.** That is the point of the $[0..3]$ items, and it is said.
* **The upper layer may not leave the box.** Answer 306 introduces its items
  only for $0 < x < 2n$ and $0 < y < 2m$. A small square can perfectly well
  hang over the edge of the large squares' bounding box, and the search finds
  arrangements where it does; the answer's model cannot see them.

With both imposed:

| Box | Answer 306 | Here |
| --- | --- | --- |
| 3 × 9 | 0 | **0** |
| 4 × 8 | 0 | **0** |
| 5 × 7 | 4 · 9 | **36 arrangements, 9 classes** |
| 6 × 6 | 8 · 8 | **64 arrangements, 8 classes** |

And the answer is right that Algorithm M's numbers are not the answer to the
exercise, because 2-regularity is not connectivity. Insisting on one cycle:

| Box | Arrangements | Classes |
| --- | --- | --- |
| 5 × 7 | 36 | 9 |
| 6 × 6 | 16 | 2 |

The 48 arrangements (6 classes) that drop out at 6 × 6 all have an upper layer
made of an 8-cycle and a 12-cycle, exactly as the answer says. So there are
$9 + 2 = 11$ essentially different solutions.

No genuine solution is lost by the second restriction: all 52 surviving
arrangements keep their upper layer inside the box. It only affects spurious
ones.

## 9. The "defect"

The answer closes with: "The middle two examples show two of the large squares
touching at a corner. The definition of snake-in-the-box cycles allows this to
happen; but five of the eleven solutions don't have this 'defect'."

Read plainly, every one of the eleven has it. An induced cycle in a grid turns
corners, and at every turn two of its cells touch diagonally; the boundary ring
of a 6 × 6 square is a snake-in-the-box 20-cycle and it has four such contacts
at its corners.

What must be meant is a corner contact between two cells that are **not two
steps apart round the cycle** — a place where the ring doubles back and pinches
itself, rather than merely turns. Counting those:

| Box | pinch | do not |
| --- | --- | --- |
| 5 × 7 | 5 | 4 |
| 6 × 6 | 1 | 1 |
| total | 6 | **5** |

Five of the eleven, as the answer says.

## 10. What I checked before reporting this

* The piece set reproduces the four placements the answer prints for its
  leftmost piece, and they are four turns of one piece.
* Every count in part (b) and part (c) is stable under transposing the box
  (5 × 4 and 10 × 2 give the same numbers), so no coordinate convention is
  being smuggled in.
* Every class count is computed from stabilizer orders, never by dividing by
  the group order; the answer's own $2 \cdot a + 4 \cdot b$ notation is the check
  that this is being done right.
* The 20-cycle enumeration was checked against the one shape that can be
  written down by hand: the boundary ring of a 3 × 9 box, which is the unique
  20-cycle filling it.

Four defects in my own programs, all caught by a number that failed to come
out, are worth recording:

1. **Small squares primary in parts (b) and (c).** Zero solutions, because 31
   small squares cannot be covered exactly by 20. This is section 3.
2. **Filtering the upper-layer condition after the search in exercise 306.** A
   20-cycle can be paved by the ten dominoes in millions of ways, almost none
   of them wanted; the condition has to be inside the search.
3. **Counting a piece's own edge twice.** The two small squares of a piece are
   diagonal neighbours, so they contribute an edge of the upper layer's cycle.
   Counting it once for each endpoint gave both squares degree two the instant
   they were placed, and every branch died: all four box sizes returned zero.
4. **A pruning test that looked at the wrong square.** "Can this square still
   gain a neighbour?" was being answered by asking whether a later domino could
   reach *that square*, which is always no, since it is already occupied. It has
   to ask about the square's *neighbours*. With this fixed, 5 × 7 gave 36.

The third and fourth are the reason section 7's decomposition is presented with
its prunings spelled out: they are where the work is, and where the mistakes
are.

## 11. Method

Everything is an XCC or MCC problem solved with the sparse-set dancing cells
solver in this repository, except the last step of exercise 306, which is a
direct search with two prunings. `verify/verify.w` is the literate program.

| Mode | What it does | Time |
| --- | --- | --- |
| `-mode pieces` | the ten, and the answer's four placements | instant |
| `-mode a` … `-mode e9` | the five parts of exercise 305 | 9 ms to 16 s |
| `-mode shapes` | the distinct large-square shapes of part (d) | 0.2 s |
| `-mode snake` | the whole of exercise 306 | 4 min 35 s |

Times are on one core of an Apple M-series laptop.

## References

* D. E. Knuth, *The Art of Computer Programming*, Volume 4B, §7.2.2.1,
  exercises 305 and 306 and their answers.
* S. Grabarchuk, *Cubism For Fun* **41** (October 1996), 30–32, where the
  snake-in-the-box arrangement of exercise 306 was posed.
