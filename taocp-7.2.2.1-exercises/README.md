# Careful Readings of TAOCP §7.2.2.1

Knuth's [news page](https://www-cs-faculty.stanford.edu/~knuth/news.html) asks
readers to take one exercise of *The Art of Computer Programming*, read it and
its answer very carefully, and report back. This directory holds one such
reading per exercise, written against Volume 4B, Addison-Wesley, first printing,
2022, and against the
[errata file](https://www-cs-faculty.stanford.edu/~knuth/err4b.textxt) of the
day. Section 7.2.2.1 is the dancing-links section, so most of these questions
come down to an exact cover problem, and the engines of the
[repository above](..) do the searching.

The news page lists nineteen exercises for §7.2.2.1. **All nineteen have a
reading here.**

Each exercise's directory holds the report itself as `README.md` — which is
what GitHub shows when you open it — and the program behind it as a
[GWEB](https://github.com/sjnam/gweb) literate program in `verify/verify.w`,
with `verify/verify.pdf` beside it so it can be read without installing GWEB.
Nothing is claimed that the program does not check.

## The nineteen readings

| Exercise | What the news page asks | What came out |
| --- | --- | --- |
| [29, 30](029-030) | Characterize all search trees that can arise with Algorithm X | answer 30 is broken by the one-node tree |
| [55](055) | Determine the fewest clues needed to force highly symmetric sudoku solutions | confirmed, and the hard half done more cheaply |
| [104](104) | Construct infinitely many "perfect" *n*-tone rows | confirmed |
| [121](121) | Determine which of the 92 Wang tiles in exercise 2.3.4.3–5 can actually be used when tiling the whole plane | every claim confirmed against the errata |
| [129](129) | Enumerate all the symmetrical solutions to MacMahon's triangle-tiling problem | **281,618 should be 294,457** |
| [147](147) | Construct all of the "bricks" that can be made with MacMahon's 30 six-colored cubes | one catalogue line of twenty-four differs |
| [151, 152](151-152) | Arrange all of the path dominoes into a single loop | confirmed |
| [196](196) | Analyze the running time of Algorithm X on bounded permutation problems | seven parts confirmed; answer (h) drops two factorial signs and opens a series with the wrong term, and answer (i) misstates the branching |
| [262](262) | Study the ZDDs for domino and diamond tilings that tend to have large "frozen" regions | every number confirmed; one item bound is missing from part (b) |
| [305, 306](305-306) | Find optimum arrangements of the windmill dominoes | confirmed |
| [320](320) | Find all ways to make a convex shape from the fourteen tetraboloes | confirmed |
| [323](323) | Find all ways to make a skewed rectangle from the ten tetraskews | the 3648 belongs to a 2 × 22 frame, not 2 × 21 |
| [334](334) | Build fake solutions for Soma-cube shapes | three counts do not reproduce |
| [337](337) | Design a puzzle that makes several kinds of "dice" from the same bent tricubes | confirmed |
| [346](346) | Pack space optimally with small tripods | confirmed, and 65/108 improves to 5/8 |
| [375](375) | Determine the smallest incomparable dissections of rectangles into rectangles | every number confirmed but one: the fourth diagram of (b) reaches 47, not 56 |
| [387](387) | Classify the types of symmetry that a polycube might have | two of the eleven pictures are not minimal |
| [432](432) | Find the most interesting 3×3 kakuro puzzles | the puzzle called hardest cannot exist |
| [442](442) | Enumerate all hitori covers of small grids | every count confirmed; one range entry is wrong |

## What came out

Nine of the nineteen answers came out with nothing left to report — and two of
those nine only because the errata file had already caught what was there. The
other ten each turned up something. Everything below is stated in the reading
that found it, with the program that found it beside it; this page is only the
index.

### Numbers that do not reproduce

| Exercise | Where | Printed | What came out |
| --- | --- | --- | --- |
| [129](129) | left-right reflection, weak | 281,618 | **294,457** |
| [147](147) | the 2×2×4 line of the catalogue | six entries | **four of them disagree** |
| [196](196) | answer (h), the product | $\Pi\_n = \lfloor (n{+}1)/2 \rfloor \lfloor (n{+}2)/2 \rfloor$ | **both factorial signs are missing** |
| [196](196) | answer (h), the series for $4e-1$ | 6 + 4/1! + 5/2! + ⋯ | **the leading term is 2, not 6** |
| [323](323) | the 2×21 frame | 3648 | **72**; 3648 is the 2×22 count |
| [334](334) | the cube's cubie sets | 13,842 | **15,842** |
| [334](334) | the X-wall | 612 / 275 | **494 / 208** |
| [334](334) | the W-wall | 282 / 33 | **162 / 22** |
| [375](375) | best semiperimeter, fourth diagram of (b) | 56 | **47**, in a 30 × 17 rectangle |
| [432](432) | second rows of the easy puzzles | a list | **231 is missing from it** |
| [432](432) | asymmetric puzzles with no forced move | 4011 | **at most 3360**; 3172 here |
| [432](432) | of those, with no magic block | 570 | **576** |
| [442](442) | the black-cell range matrix | entry (1, 1) | **wrong**, and the book contradicts it elsewhere |

### Claims that fail

- **[29, 30](029-030).** Answer 30 as printed is broken by exactly one tree:
  the single-node tree whose root is marked a solution. Knuth's errata caught
  this on 22 March 2023. Over all 258,564 pairs of an ordered tree of at most
  ten nodes with a marking of its leaves, that one case is the only failure —
  so the corrected version has no defect at all.
- **[196](196).** Answer (i) says its example branches on
  $Y\_9$, then $X\_2$, then $Y\_8$; it branches on
  $Y\_9$, then $X\_1$, then $Y\_8$, then $X\_2$. And "the first branch is on
  $Y\_n$" fails in 1324 of the 9055 cases, the smallest being 33355, which
  branches on $Y\_4$.
- **[262](262).** The items of part (b), written out as the answer prints them,
  give a problem with no tilings at all: one bound is missing. Everything the
  recipe is meant to produce is confirmed once it is restored.
- **[387](387).** The exercise asks for examples "using the minimum number of
  cubies," and two of the drawings use more: the type (v) example spends eight
  cubies where six suffice, and the type (vi) example at least seven where six
  suffice. The sentence about them also says "these twelve examples" where
  there are **eleven**.
- **[432](432).** The puzzle the answer calls the hardest, 6 19 6 / 8 11 10,
  cannot exist: its across clues total 31 and its down clues total 29, and both
  are the sum of the same seven digits.

### Smaller things

- **[121](121).** The statement of part (c) prints (2, 3, 3, 57) for
  (2, 2, 3, 57) — the errata of 7 January 2023 say so, and the corrected
  numbers are what came out. The reading also notes the misprinted cell of the
  block in answer 2.3.4.3–5, which the Volume 1 errata have carried since
  22 July 2005; that only dates the printing worked from.
- **[104](104).** The statement was amended for clarity on 15 September 2025,
  and answer (a) leaves one step of its argument implicit.
- **[151](151-152).** The exercise calls the path in its figure a "Hamiltonian
  cycle." It is a single closed loop, as the same sentence goes on to say, but
  it is not Hamiltonian on any natural reading.
- **[305, 306](305-306).** Every number comes out, but two of them only after
  working out what a phrase had to mean; those are the only places where a
  reader is left to guess.
- **[337](337).** The coordinates alone do not say which of the two dice is
  left-handed. The answer's own picture settles it, in favour of what the
  exercise says.
- **[442](442).** The three ZDD sizes at *m* = *n* = 9 do not reproduce, and
  this is explicitly *not* offered as a correction: a reduced ZDD is canonical
  only once the variable order is fixed, and the answer does not say which
  order its frontier used. All 81 counts read off both diagrams agree.

### Beyond the book

A reading that finds nothing wrong can still add something.

- **[55](055).** The answer settles the negative half by reporting a SAT
  instance that came back unsatisfiable, at 177 megamems for the 19-clue case.
  The answer's own lower-bound argument, pushed one step further, says exactly
  where the clues have to go: 0.13 seconds to rule out 18 clues, 8.8 seconds
  for 19. The two exhibited puzzles are counted as well — one of exactly 189,
  and one of exactly 648.
- **[104](104).** The argument for part (a) proves more than it claims. A
  perfect row *is* a table of discrete logarithms, and the converse is easy, so
  the perfect rows are exactly those tables — $\varphi(n)$ of them for each
  $n$, one per primitive root. The "amazing" 12-tone row is the one belonging
  to the smallest primitive root of 13.
- **[129](129).** The 12,839 missing patterns are not a slip in arithmetic but
  a missing *case*: of the ways the four single-colour tiles can sit, the
  answer's six types cover all but one. Every other count is confirmed through
  an identity of the form *raw count = multiplier × what the answer prints*,
  which has to come out on the nose and would fail if any type-count were off
  by one.
- **[151, 152](151-152).** The 8×12 array of exercise 152, for which the answer
  prints no arrangement, was found and is drawn. No 64-cell rectangle at all
  admits the 32 non-crossing pieces, not just the chessboard. And the
  chessboard mission misses by exactly one piece, which turns the failed puzzle
  into a sharp one.
- **[196](196).** The general rule behind answer (i)'s update count, which the
  answer states only for its example, is worked out and checked against every
  canonical sequence with $n \le 9$ — 6917 of them.
- **[346](346).** The $7/9$ of part (b) and a number better than part (c)'s
  65/108 both fall out of a single construction the answer does not mention,
  small enough to check by hand. It gives **5/8**.
- **[375](375).** The motley counts of exercise 365 and the claim of answer
  374(d) come out as by-products, and order 9 is settled: nine pieces need a
  square of side at least 28, so they cannot beat 27.
- **[387](387).** The answer gives the minimum number of cubies for one of the
  eleven types. The reading works it out for all eleven.

## How a reading is put together

Every reading is written the same way. The program is independent of the book:
it builds the objects from the exercise's own definitions, searches with the
engines in the directory above (or with a dancing-links or linear-programming
routine of its own where that is what the exercise is about), and prints the
quantities the answer prints. Where a number can be reached two ways, it is —
a brute-force mode that uses no theory sits beside the fast one in most of
these programs, and the two have to agree.

Reports are in English, and so are the literate programs; both are typeset with
`luatex`, because several of them draw their figures with `luamplib`.

## Building

```sh
make          # tangle every verify.w and build
make test     # go test ./...
make vet      # go vet ./...
make pdf      # weave and typeset every reading, and draw its figures
make clean    # remove everything the .w files generate, verify.pdf excepted
```

Adding a reading means putting its directory name in `EXERCISES` in the
[Makefile](Makefile), which brings the tangle, typeset and clean rules with it,
plus one `$(eval $(call figure,...))` line if the reading draws a picture.

Each program also runs on its own:

```sh
cd 375/verify && gtangle verify.w && go run . -mode all
```

The modes differ from reading to reading; the last section of each `README.md`
lists them.
