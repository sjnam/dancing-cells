# TAOCP 7.2.2.1, Exercise 129: A Careful Reading

Written 5 September 2026, against Volume 4B, Addison-Wesley, first printing,
2022, and the errata file as of that date.

This is one reader's response to the request on Knuth's [news
page](https://www-cs-faculty.stanford.edu/~knuth/news.html): read an exercise
and its answer very carefully, then report back.

## What I found

| Item | Finding |
| --- | --- |
| Exercise 129 (statement) | No error. |
| Answer 129, "only 180° rotation applies" | Confirmed exhaustively. |
| Answer 129, the 768 paired options | 768 exactly; 68,024,064 solutions. |
| Answer 129, the six strong types (sum 1,417,168) | Confirmed. |
| Answer 129, the plane-tiling proviso (40,208) | Reproduced exactly. |
| Answer 129, the six weak types (sum 609,203) | Confirmed. |
| Answer 129, strong reflection is impossible | Confirmed exhaustively. |
| Answer 129, the twelve top-down numbers | Confirmed; and the 261 twice more. |
| Answer 129, left-right: 194 | Confirmed. |
| Answer 129, left-right: 281,618 | **Should be 294,457**; see sections 11-13. |

Every number came out exactly except one. The left-right weak count is short by
12,839, and the shortfall is a single missing case: of the ways the four
single-colour tiles can sit, answer 129's six types cover all but one, and that
one holds 12,839 essentially distinct patterns. Sections 11 to 13 pin it down.
Everything else in the exercise and the answer stands.

What took the work was not the searching but the *bridge*: the answer counts
patterns that are essentially distinct, while a dancing-links run counts
labelled placements in a hexagon that is nailed down. Section 4 below sets up
that bridge, and every number after it is an identity of the form

> raw count = (multiplier) × (what the answer prints).

Those identities are what makes this a check rather than a coincidence: each
one has to come out on the nose, and each one would fail if the answer's six
type-counts were off by even one. Six of the seven do come out on the nose. The
seventh is the subject of the last three sections.

| Family | Identity | Measured |
| --- | --- | --- |
| answer 126, white border | — | 11,853,792 |
| strong, half-turn | 48 · 1,417,168 | **68,024,064** |
| strong, half-turn, tiling the plane | 48 · 40,208 | **1,929,984** |
| weak, half-turn | 144 · 1,417,168 + 288 · 609,203 | **379,522,656** |
| weak, top-down reflection | 96 · 41,608 + 48 · 261 | **4,006,896**, thrice |
| strong half-turn and weak top-down | 16 · 261 | **4,176** (all three) |
| weak under both reflections | 96 · 194 + 48 · 261 | **31,152** |
| weak, left-right reflection | 96 · 281,618 + 48 · 261 | **28,280,400** |

## 1. What the exercise asks

Exercise 126 has already put MacMahon's 24 four-coloured triangles into the
hexagon of (59): 24 triangle positions, 24 tiles, 42 edges, and 24 · 64 = 1536
options, one for each way to drop a tile into a position.

Exercise 129 asks which of those placements are *symmetric*, in either of two
senses:

* **strong symmetry** — a rotation or reflection that leaves the pattern
  unchanged apart from a permutation of the colours;
* **weak symmetry** — a rotation or reflection that preserves the *colour
  patches*, that is the set of boundaries between differently coloured
  regions, without any condition on the colours themselves.

"Exactly how many essentially different symmetrical patterns are possible, in
a hexagon?"

**A condition that quietly goes away.** Answer 126 adds a primary item `*` and
one option that paints every boundary edge with colour `a`; its 11,853,792
solutions are the ones with a pure-white border. Answer 129 says its options
are "the options of answer 126", but it cannot mean that, because it then
reports 68,024,064 solutions — more than answer 126 has altogether. Exercise
129 is about the hexagon with a *free* border, and the models below leave the
border unconstrained. (The base model, run with the border option restored,
does give 11,853,792, which is how I convinced myself I had answer 126 right
before building anything on top of it.)

## 2. The hexagon and its twelve symmetries

Answer 124's coordinates make the symmetries easy. Write a triangle as a
triple of barycentric coordinates summing to 2 (for an up-triangle) or 1 (for
a down-triangle):

$$(x,y) \mapsto (x-1,\; y-1,\; 4-x-y), \qquad (x,y)' \mapsto (x-1,\; y-1,\; 3-x-y).$$

Then the twelve symmetries of the hexagon are the six permutations of the
three coordinates, each with an optional "flip" $c \mapsto 1-c$. The
coordinates are also the three edge directions, so a symmetry permutes a
triangle's three edges exactly as it permutes the coordinates — which is the
only fact the models need.

Running through all twelve:

| Symmetry | Order | Fixed triangles | Fixed edges |
| --- | --- | --- | --- |
| identity | 1 | 24 | 42 |
| half-turn | 2 | 0 | 0 |
| two rotations by 120° | 3 | 0 | 0 |
| two rotations by 60° | 6 | 0 | 0 |
| three reflections (the "top-down" kind) | 2 | 0 | 4 |
| three reflections (the "left-right" kind) | 2 | 4 | 2 |

The last two rows are exactly what the answer says: "Top-bottom reflection
preserves the values of four edges, but all triangles change; left-right
reflection preserves the values of four triangles and two edges."

## 3. Strong symmetry is only the half-turn

The answer disposes of this in one clause — "Only 180° rotation applies,
because of the four single-color tiles" — and it is worth checking by machine,
because it is the hinge everything else hangs on.

A strong symmetry is a pair $(h, \pi)$: a hexagon symmetry $h$ and a colour
permutation $\pi$ with $h$ carrying the pattern to its $\pi$-recolouring. Since
$h$ and $\pi$ have the same order and there are only ten involutions of four
colours, this is a small finite search: build the model for each $(h, \pi)$ and
count.

* **Reflections.** All six reflections against all ten involutions: 60 models,
  **0 solutions in every one**. Strong reflection symmetry is impossible, just
  as the answer argues by hand.
* **The half-turn.** Against the four involutions with fixed points (including
  the identity): **0 solutions**. Only the three fixed-point-free involutions
  survive, which is what licenses the answer's "assume that rotation changes
  $a \leftrightarrow d$, $b \leftrightarrow c$".
* **Rotations of order 3 and 6** cannot be strong at all: a colour permutation
  of order 3 or 6 on four colours would have to fix a colour, and its solid
  tile would then have to sit on a fixed triangle, of which there are none.

## 4. The bridge from raw counts to essentially distinct patterns

Let $\Gamma = H \times C$, where $H$ is the group of twelve hexagon symmetries
and $C$ the 24 colour permutations, so $|\Gamma| = 288$. Two placements are
*essentially the same* exactly when they lie in one $\Gamma$-orbit, and that
orbit is what the answer calls an essentially distinct pattern.

Two facts pin the arithmetic down.

**Stabilizers have order 1 or 2.** A pair $(h,\pi)$ fixing a placement is
precisely a strong symmetry of it. Section 3 leaves only the half-turn, so the
stabilizer of a placement is trivial, or of order 2 when the placement is
strongly symmetric. Hence an orbit has 288 placements, or 144 when it is a
strong one.

**Weak symmetry is a property of the orbit, twisted by conjugation.** Write
$W(h)$ for the set of placements whose colour patches $h$ preserves. Colours do
not enter, so a placement $(g,\pi)p$ lies in $W(h)$ exactly when the conjugate
$g^{-1} h g$ is a weak symmetry of $p$. Counting the pairs $(g,\pi)$ that work
and dividing by the stabilizer order $s$ gives

$$
|O \cap W(h)| \;=\;
\frac{24 \cdot \#\{g \in H : g^{-1} h g \text{ is weak for } p\}}{s}.
$$

For the half-turn, which is central, the numerator is $24 \cdot 12 = 288$, so
the intersection is $288/s$ — every placement of the orbit, as it must be. For
a reflection $\tau$, the conjugates of $\tau$ are the three reflections of its
own kind; when only $\tau$ itself is a weak symmetry of the pattern, the $g$
that work are the four that commute with $\tau$, and the numerator is
$24 \cdot 4 = 96$, so the intersection is $96/s$.

So a raw count from Algorithm C is a fixed linear combination of the answer's
numbers, with the strong classes weighted at half. Every identity below is an
instance.

## 5. Strong symmetry: 1,417,168

Pairing the options as the answer describes — one option per orbit of the
half-turn, its two triangles coloured so that the rotation swaps
$a \leftrightarrow d$ and $b \leftrightarrow c$ — gives **768 options**, matching
the answer exactly. (The pairing discards the 256 colourings whose two halves
would use the same tile twice.)

| | Answer 129 | Here |
| --- | --- | --- |
| paired options | 768 | 768 |
| solutions | 68,024,064 | **68,024,064** (7 m 37 s, 3.0 × 10⁸ nodes) |

The orbit of a strong pattern holds 144 placements, and its three
fixed-point-free involutions share them equally, so 48 of them are strong for
the pinned involution:

$$68{,}024{,}064 = 48 \times 1{,}417{,}168 .$$

That is the answer's $80768+164964+77660+819832+88772+185172$, confirmed as a
sum.

## 6. The plane-tiling proviso: 40,208

The bracketed remark notes that the illustrated pattern tiles the plane by
translation alone, and that "exactly 40208 of the essentially distinct
solutions satisfy this additional proviso". The condition is that opposite
boundary edges agree: `-04 = -20`, `-14 = -30`, `/03 = /41`, and so on.

Gluing each of the six opposite pairs into a single secondary item and running
the same 768 options:

$$1{,}929{,}984 = 48 \times 40{,}208 . \qquad \text{(22 s)}$$

## 7. Weak symmetry under the half-turn: 609,203

Answer 129 gives each triangle orbit a secondary item carrying a three-bit code
of which of its corners separate two colours. There are twelve such items, one
per orbit of the half-turn, and 1536 options again.

The half-turn is central, so by section 4 the raw count is the whole of every
orbit that is weakly symmetric — the strong ones (144 placements each) and the
weak-but-not-strong ones (288 each):

| | Predicted | Here |
| --- | --- | --- |
| solutions | $144 \cdot 1{,}417{,}168 + 288 \cdot 609{,}203$ | |
| | $= 204{,}072{,}192 + 175{,}450{,}464$ | |
| | $= 379{,}522{,}656$ | **379,522,656** (12 h 55 m, 3.1 × 10¹⁰ nodes) |

The answer's $24516+45818+22202+341301+44690+130676 = 609{,}203$ is confirmed
to the last digit, and so is 1,417,168 a second time — the two are separated
here by a factor of two, so an error in either would have shown.

## 8. Weak symmetry under a top-down reflection

These are the three reflections that fix no triangle. The model gives each
orbit $\{t, \tau(t)\}$ one patch item, read through $\tau$ from the second
triangle so that both report the same value.

By section 4 each weak-but-not-strong class contributes 96 placements and each
strong class 48:

| | Predicted | Here |
| --- | --- | --- |
| solutions | $96 \cdot 41608 + 48 \cdot 261 = 4006896$ | **4,006,896** |

and that came out for **all three** of the top-down reflections separately
(1 h 31 m, 1 h 44 m, 2 h 6 m). Here $261 = 88+98+75$ and
$41{,}608 = 1108+12827+8086+3253+12145+4189$, so this one identity confirms all
twelve of the printed numbers at once.

The 261 "special" placements — strongly symmetric under the rotation *and*
weakly symmetric under the reflection — can also be counted directly, by
putting the patch items on top of the paired options of section 5. A special
class contributes $4 \cdot 8 / 2 = 16$ placements, and

$$4{,}176 = 16 \times 261$$

came out for each of the three reflections. That is a second, independent sight
of the same 261.

## 9. Weak symmetry under a left-right reflection, and the 194

These are the three reflections that fix four triangles. Combining a left-right
reflection with the half-turn gives a top-down one, so a pattern weakly
symmetric under both is weakly symmetric under a group of order four. Answer
129 says 194 of the essentially distinct left-right patterns are top-down
symmetric too.

Imposing both conditions at once — one patch item per orbit of the
four-element group — gives

$$31{,}152 = 96 \times 194 \;+\; 48 \times 261 ,$$

which is the identity of section 4 applied to a class weakly symmetric under
both reflections. So **194** is confirmed, and 261 for a third time.

## 10. A condition my first model forgot

A left-right reflection fixes four triangles, and that is exactly where my
first attempt went wrong. Answer 129 introduces its patch items "for each
triangle $(x,y)$ or $(x,y)'$ with $y > 1$" — one per *orbit*. I wrote the same
thing for reflections: one item per orbit, with the non-representative reading
its mask through the symmetry. For the top-down reflections that is right,
because no triangle is fixed and every orbit has two members.

For a left-right reflection it is wrong. A fixed triangle is an orbit of one,
so its item appears in only its own options and constrains nothing — yet the
reflection still shuffles that triangle's three corners, so its own colour
changes have to sit symmetrically about the axis. What has to be invariant is
the partition of the triangle's three edges by colour, and of the five such
partitions only three survive the swap: all three edges alike, the two the axis
swaps alike and unlike the third, and all three different. That leaves
$4 + 4\cdot3 + 4\cdot3\cdot2 = 40$ of the 64 colourings. The model has to say so.

The symptom was a raw count of 227,537,328 from each of the three left-right
reflections — 8.4 times what section 4 predicts, and not any combination
$96a + 48b$ of the answer's numbers. With the condition restored the option
count drops from 1536 to $1536 - 4 \cdot 24 = 1440$. The three top-down runs
were unaffected, since with no fixed triangle they never reach the code path at
all.

I set this out because it is the obvious suspect for what follows, and it had
to be cleared before anything could be claimed. Section 13 clears it.

## 11. The left-right count does not come out

With the fixed-triangle condition in place, two of the three left-right
reflections, run separately, both give

$$
28{,}280{,}400 ,
$$

where section 4 and the answer's numbers predict
$96 \cdot 281618 + 48 \cdot 261 = 27{,}047{,}856$. The gap is

$$
1{,}232{,}544 = 96 \times 12{,}839 ,
$$

a whole number of classes at the multiplier section 4 demands. That is the
first thing worth noticing: a mistake in the model would not be so tidy.

The one way the arithmetic could bend is a bigger multiplier. Section 4 gives a
class 96 placements when exactly one left-right reflection is weak for it, but
288 when all three are --- and all three would mean the pattern is also weakly
symmetric under a rotation by 120°. So I asked for those directly:

| Group imposed | Options | Solutions |
| --- | --- | --- |
| the three left-right reflections and the two 120° rotations | 1248 | **0** |
| the two 120° rotations alone | 1536 | **0** |

Nothing is weakly symmetric under a three-fold rotation at all. So the
multiplier is 96 everywhere, no class contributes 288, and the count says there
are

$$
(28{,}280{,}400 - 48 \cdot 261)/96 = 186{,}846 + 107{,}611 = 294{,}457
$$

essentially distinct weak-not-strong patterns with left-right symmetry, where
the answer says 281,618.

## 12. Cutting the family where the answer cuts it

The introduction to `verify.w` says this program cannot check the answer's six
types one at a time, because the types are a bookkeeping device of its own.
That is true of the types, but the family can be cut into pieces the case
analysis has to respect, and the answer names the cut itself: a reflection
carries solid triangles to solid triangles, so it permutes the four
single-colour tiles, and the split is by which of them it fixes.

**Sixteen pieces.** A left-right reflection fixes four triangles. Telling the
model, for each of them, whether it must carry a solid tile cuts the family
into sixteen disjoint pieces, and they must add up to 28,280,400. They do:

| Solid tiles on the fixed triangles | Raw | Classes |
| --- | --- | --- |
| none | 17,949,744 | 186,846 + 261 strong |
| 02′ and 31 | 3,396,000 | 3,396,000/96 = **35,375** |
| 12 and 21′ | 2,425,056 | 2,425,056/96 = **25,261** |
| 02′ and 21′ | 2,254,800 | 2,254,800/48 = **46,975** |
| 12 and 31 | 2,254,800 | (the same classes again) |
| any odd number of them | 0 | — |
| any other pair, or all four | 0 | — |

The odd ones are empty for a reason worth stating: the solid tiles the
reflection does not fix pair up, so an even number of them is fixed. The
answer's own sentence is "If **aaa** is fixed, assume that **ddd** is also
fixed", and that is why.

**And they are the answer's three types.** The half-turn commutes with the
reflection and carries its four fixed triangles to each other, swapping
02′ with 31 and 12 with 21′. So the four possible pairs fall into three orbits:
{02′,31} and {12,21′} are each carried to themselves, while {02′,21′} and
{12,31} are exchanged --- which is why those two have equal counts and are one
type between them, at 48 placements per class rather than 96. Three types,
exactly as the answer says, and

$$
46{,}975 + 35{,}375 + 25{,}261 = 107{,}611
$$

on the nose, each number separately. This is the branch that leans hardest on
the fixed-triangle condition of section 10, and it is perfect.

**Forty-five more pieces.** The other branch --- no solid tile fixed, the
answer's "otherwise assume that **ddd** is opposite **aaa**" --- holds
17,949,744 placements. There the four solid tiles fill two of the reflection's
ten two-element orbits, so naming the two orbits cuts it into
$\binom{10}{2} = 45$ pieces. Those add up to 17,949,744 as well, 33 of them
non-empty, and the half-turn groups them into 18 classes the same way it
grouped the four masks above.

One of those eighteen has exactly **12,839** classes: the one where the solid
tiles fill the orbits {20′, 22′} and {11′, 12′}, or equivalently, after a
half-turn, {11, 13} and {21, 22}. Each of the two configurations holds 616,272
placements, so together

$$
1{,}232{,}544 = 96 \times 12{,}839 .
$$

The other seventeen hold 174,007 weak-not-strong classes between them, and all
261 of the strong ones. And 174,007 is exactly the sum of the answer's six
numbers $3711+56706+5889+60297+38311+9093$.

So the six types of that branch account for seventeen of the eighteen groups,
and miss one. The missing type has no strong placements in it, which fits: the
answer's strong counts (75, 0, 98, 0, 0, 88) already add to the 261 that the
other groups hold.

## 13. A second opinion on every solution

All of this rests on a model that says "weakly symmetric" in terms of three-bit
patch items --- the very thing section 10 got wrong the first time. So the
program has a second opinion that shares nothing with it. Each solution is
turned back into a colouring of the 42 edges; its colour patches are rebuilt
from scratch by union-find, two edges of a triangle joining when their colours
agree; and each of the twelve symmetries is then asked directly whether it
carries that partition to itself, and whether it carries the colouring to a
recolouring of itself.

That gives, for each solution, its stabilizer order $s$ and the number $N$ of
$g$ with $g^{-1}\tau g$ weak. Summing $s/(24N)$ counts classes with no
multiplier taken on faith at all. Run on the model of section 9, where the
answer's numbers are known to be right, it says:

| | Placements | Classes |
| --- | --- | --- |
| $N=4$, $s=2$ | 12,528 | **261** |
| $N=4$, $s=1$ | 18,624 | **194** |

which is 194 and 261 recovered from first principles rather than divided out.
Run over the whole 17,949,744-placement branch:

* **not one solution failed the patch test** --- every one is genuinely weakly
  symmetric under the reflection;
* every one has $N = 4$, so no class hides a bigger multiplier;
* the strong ones number 12,528 placements, which is **261** classes exactly;
* the rest number 17,937,216, which is **186,846** classes exactly.

And the two configurations of the missing group, checked the same way, are
616,272 placements each, none of them failing, all with $N=4$ and $s=1$.

**So the correction is:** answer 129's "six types of this kind yield ... (3711,
56706, 5889, 60297, 38311, 9093) non-strong solutions" is missing a seventh
case worth 12,839, and the grand total

> "So there's a grand total of 281618 essentially distinct weak-not-strong
> placements with left-right symmetry"

should read **294,457**. The 107,611 of the other branch, the 194, the 261 and
the twelve top-down numbers are all correct.

## 14. What I checked before reporting this

* The base model of answer 126, with the border option restored, gives
  11,853,792 — so the geometry, the tile set and the edge sharing are right
  before any symmetry is imposed.
* All twelve symmetries map the hexagon onto itself, and their fixed-triangle
  and fixed-edge counts match the answer's prose.
* Strong reflection symmetry: 60 models, no solutions.
* Strong rotation with a colour involution that has a fixed point: no
  solutions.
* Every symmetric count is an exact multiple of the multiplier section 4
  predicts — never off by one, never a near miss.
* The number 261 comes out three separate ways (sections 8 and 9), and
  1,417,168 twice (sections 5 and 7).

## 15. Method

Everything is one XCC problem or another, solved with the sparse-set dancing
cells solver in this repository. `verify/verify.w` is the literate program;
it builds the hexagon, the twelve symmetries, and each of the models above, and
prints the identities. Its modes:

| Mode | What it does | Time |
| --- | --- | --- |
| `-mode syms` | the table of section 2 | instant |
| `-mode base` | answer 126, border pinned | 4 min |
| `-mode strongref` | the sweep of section 3 | 3 s |
| `-mode strong` | section 5 | 9 min |
| `-mode tile` | section 6 | 24 s |
| `-mode special` | the 261, three ways | 2 s |
| `-mode weak -g rot` | section 7 | 13 h |
| `-mode weak -g top` | section 8 | 1.5–2 h |
| `-mode weak -g left` | section 10 | 3 h |
| `-mode weak -g both` | section 9 | 1.5 min |

The three long counts were first made with a stand-alone program written while
working the exercise out; `verify.w` grew afterwards, out of the parts that
turned out to matter. To be sure the two agree I had both print their problems
(`-dump`) and compared them item for item: same options, same grouping of
options into orbits, same partition of each orbit's options by patch value. So
the models are the same problem under different item names, and the long counts
belong to `verify.w` as much as to the program that first produced them. The
same goes for the split of section 12: the stand-alone program and `verify.w`
give 616,272 for each of the two configurations of the missing group, so the
12,839 is not an artefact of either one.

Times are on one core of an Apple M-series laptop.

## References

* D. E. Knuth, *The Art of Computer Programming*, Volume 4B, §7.2.2.1,
  exercise 129 and its answer.
* P. A. MacMahon, *New Mathematical Pastimes* (Cambridge, 1921).
* Kate Jones, user manual for *Multimatch III* (Kadon Enterprises, 1991), where
  the strongly and weakly symmetric arrangements were first found.
