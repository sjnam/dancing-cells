# TAOCP 7.2.2.1, Exercises 29 and 30: An Audit

Written 3 September 2026, against Volume 4B, Addison-Wesley, first printing,
2022.

## Verdict

| Item | Finding |
| --- | --- |
| Exercise 29 (statement) | No error. |
| Answer 29 | Entirely correct. |
| Exercise 30 (statement) | No error. |
| Answer 30 | One defect in the printed text. |
| The parenthetical in answer 30 | Correct. |

The printed $15 \times 14$ matrix of answer 29 reproduces bit for bit from an
independent implementation, and the general construction holds up under both
proof and exhaustive test.

Answer 30 as printed is broken by exactly one tree: the single-node tree whose
root is marked a solution. Knuth's errata caught this on 22 March 2023, and the
corrected version has no defect. Across all 258,564 pairs of an ordered tree of
at most 10 nodes with a marking of its leaves, that one case is the only
failure.

The parenthetical holds both as a property of this construction and as a general
theorem about exact cover; a proof is in §3.6.

---

## 1. What the exercises ask

Algorithm X is the backtracking algorithm for exact cover. At step X3 it
selects, among the items not yet covered, one whose `LEN` — the number of
options still available to it — is smallest; this is the MRV, or
minimum-remaining-values, heuristic. Each option covering the selected item
becomes a branch of the search tree. So the shape of the search tree is
determined entirely by which item wins the `LEN` contest at each step.

Exercises 29 and 30 turn that correspondence around. **Given any tree at all,
can we manufacture an exact cover problem whose Algorithm X backtrack tree is
exactly that tree?**

### Exercise 29 [26]

> Let $T$ be any tree. Construct the 0–1 matrix of an **unsolvable** exact cover
> problem for which $T$ is the backtrack tree traversed by Algorithm X with the
> MRV heuristic. (A *unique* item should have the minimum `LEN` value whenever
> step X3 is encountered.) Illustrate your construction when $T$ is a root with
> two subtrees, each having three leaves — nine nodes in all.

### Exercise 30 [25]

> Continuing exercise 29, let $T$ be a tree in which certain leaves have been
> distinguished from the others and designated as "solutions." Can all such
> trees arise as backtrack trees in Algorithm X?

---

## 2. The construction of answer 29

> If $T$ has only a root node, let there be one column, no rows. Otherwise let
> $T$ have $d \ge 1$ subtrees $T\_1, \ldots, T\_d$, and assume that we've
> constructed matrices with rows $R\_j$ and columns $C\_j$ for each $T\_j$. Let
> $C = C\_1 \cup \cdots \cup C\_d$. The matrix for $T$ is obtained by appending
> three new columns $\{0, 1, 2\}$ and the following new rows: (i) `0 1 2` and
> all columns of $C \setminus C\_j$, for $1 \le j \le d$; (ii) $j$ and all
> columns of $C$, for $j \in \{0, 1\}$. The matrix for the example tree has 15
> columns and 14 rows.

### 2.1 Reproducing the printed matrix

Implementing the recursion from scratch and running it on the example tree
yields a matrix that agrees with the printed one **bit for bit**:

```text
011111000000000   (i)  j=1     inside subtree 1
101111000000000   (i)  j=2
110111000000000   (i)  j=3
111100000000000   (ii) j=0
111010000000000   (ii) j=1
000000011111000   (i)  j=1     inside subtree 2
000000101111000   (i)  j=2
000000110111000   (i)  j=3
000000111100000   (ii) j=0
000000111010000   (ii) j=1
000000111111111   (i)  j=1     at the root
111111000000111   (i)  j=2
111111111111100   (ii) j=0
111111111111010   (ii) j=1
```

Columns 1–3 are subtree 1's three leaves, columns 4–6 its new `0 1 2`; columns
7–12 repeat that for subtree 2; columns 13–15 are the root's new `0 1 2`.

### 2.2 Why the minimum `LEN` is always unique

At a node with $d$ subtrees, count `LEN` in the new matrix:

| column | `LEN` | why |
| --- | --- | --- |
| `2` | $d$ | the $d$ type-(i) rows, and nothing else |
| `0` | $d + 1$ | all type-(i) rows, plus type (ii) with $j = 0$ |
| `1` | $d + 1$ | all type-(i) rows, plus type (ii) with $j = 1$ |
| $c \in C\_j$ | $L\_j(c) + d + 1$ | see below |

Here $L\_j(c)$ abbreviates the count of $c$ inside $T\_j$'s own matrix. The rest
of its tally is the $d - 1$ type-(i) rows with $j' \ne j$, which all contain
$C\_j$, plus both type-(ii) rows.

Since $L\_j(c) \ge 0$, no column of $C$ can fall below $d + 1$. So **column `2`
is always the strict minimum**, and the exercise's requirement — that a unique
item attain the minimum whenever step X3 is reached — holds automatically.

The margin is thin exactly where it matters. For a leaf, $L\_j(c) = 0$, giving
$d + 1$, just one more than $d$. Manufacturing that margin is the whole purpose
of the two type-(ii) rows: without them, `0`, `1`, and `2` would all have
`LEN` $= d$ and the minimum would not be unique.

Note that type-(ii) rows do not contain column `2`. Since every branch is taken
on column `2`, **type-(ii) rows are never selected**. They exist solely to
inflate two counts.

### 2.3 The recursion lands exactly right

Branching on column `2` offers exactly the $d$ type-(i) rows. Choosing the
$j\text{th}$ covers `0`, `1`, `2`, and $C \setminus C\_j$. Then

- the other type-(i) rows contain `0`, so they go;
- both type-(ii) rows contain `0` or `1`, so they go;
- rows of $R\_{j'}$ for $j' \ne j$ touch $C\_{j'}$, which lies inside
  $C \setminus C\_j$, so they go;
- rows of $R\_j$ live entirely inside $C\_j$, so they **survive intact**.

What remains is precisely the matrix for $T\_j$. The induction goes through
cleanly. At the bottom, one column with no rows gives `LEN` $= 0$, and step X4
finds an empty list and backtracks at once — that is a leaf of $T$. Hence the
whole problem is **unsolvable**, as required.

### 2.4 Counting

For a tree with $N$ nodes, $I$ internal and $L$ leaves:

$$\text{columns} = 3I + L, \qquad \text{rows} = (N - 1) + 2I$$

The example has $N = 9$, $I = 3$, $L = 6$, so $3 \cdot 3 + 6 = 15$ columns and
$8 + 6 = 14$ rows — exactly what the book states.

### 2.5 Test results

A faithful Algorithm X with MRV was written separately from the library,
recording the children of every node visited so that the search tree could be
compared directly with $T$.

| test | result |
| --- | --- |
| the example tree | 9 nodes, 0 solutions, backtrack tree $= T$ |
| 4,500 random trees, up to 24 nodes | 0 mismatches |
| all ordered trees up to 10 nodes | 0 mismatches |
| the example matrix through `ssxcc` | 0 solutions |

In none of these runs, at any step X3, did two columns share the minimum.

---

## 3. Answer 30 and the erratum

### 3.1 As printed

> Yes, assuming that duplicate options are permitted. Use the previous
> construction, but change $C \setminus C\_j$ to $C$ if $T\_j$ is a solution
> node. (Without duplicate options, no two solution nodes can be siblings.)

The altered type-(i) row covers `0 1 2` together with all of $C$, leaving
nothing — which is to say, a solution. And the `LEN` arithmetic survives: for a
solution leaf $T\_j$, every $c \in C\_j$ now appears in all $d$ type-(i) rows,
giving `LEN` $= L\_j(c) + d + 2$, still above $d$. Column `2` remains the unique
minimum.

### 3.2 The counterexample

**Exactly one tree breaks it: the one-node tree whose root is designated a
solution.**

The printed answer modifies the *parent's* row — and a root has no parent. The
rule never fires, the base case ("one column, no rows") stands unchanged, and
the problem is unsolvable:

```text
### single node marked a solution, printed answer
tree *: 1 nodes
matrix: 1 columns, 0 rows
Algorithm X: 1 nodes, 0 solutions, 0 non-unique minima
backtrack tree = .            <- a failure leaf, not a solution
shape equals T: false
```

The backtrack tree has the right number of nodes, but that node is a failure
where the specification calls for a solution.

### 3.3 The erratum

Knuth had already caught this. From `err4b.textxt`, dated 22 March 2023:

```tex
\bugonpage 4b.421 in answer 30 (23.03.22)
construction, but change `$C{\setminus}C_j$' to `$C$' if
$T_j$ is a solution node. \becomes
construction; but if $T$ is just a root node
marked as a solution, let there be no rows and no columns.
\endchange
```

The corrected answer 30 reads:

> Yes, assuming that duplicate options are permitted. Use the previous
> construction; but if $T$ is just a root node marked as a solution, let there
> be no rows and no columns. (Without duplicate options, no two solution nodes
> can be siblings.)

```text
### single node marked a solution, erratum
tree *: 1 nodes
matrix: 0 columns, 0 rows
Algorithm X: 1 nodes, 1 solutions, 0 non-unique minima
backtrack tree = *
shape equals T: true
```

### 3.4 The erratum is a simplification, not a patch

What stands out is that the erratum **deletes** the rule
$C \setminus C\_j \to C$ altogether — and solution leaves are still handled
correctly. A solution leaf *is* a root node marked as a solution, considered as
a subtree, so under the new rule its matrix is empty; hence $C\_j = \emptyset$,
and $C \setminus C\_j$ **automatically** equals $C$. The special case the printed
answer spelled out by hand falls out of the base case for free.

A side effect is smaller matrices: one column fewer per solution leaf.

```text
### (***) as printed          ### (***) with the erratum
matrix: 6 columns, 5 rows     matrix: 3 columns, 5 rows
111111                        111
111111                        111
111111                        111
111100                        100
111010                        010
-> 4 nodes, 3 solutions       -> 4 nodes, 3 solutions
```

### 3.5 Exhaustive comparison

Every ordered tree of at most 10 nodes was generated, with every way of
designating a subset of its leaves as solutions — 258,564 pairs. For each, four
things were checked: that the backtrack tree has the same shape as $T$; that
the node counts agree; that the minimum `LEN` is unique at every step X3; and
that the number of solutions found equals the number of designated solution
leaves.

| construction | pairs tested | failures |
| --- | --- | --- |
| as printed | 258,564 | 1, the tree `*`, and nothing else |
| with the erratum | 258,564 | 0 |

The printed answer's defect is precisely the one the erratum names. On the other
258,563 pairs it works perfectly well.

### 3.6 The parenthetical

> (Without duplicate options, no two solution nodes can be siblings.)

The erratum leaves this sentence standing, and it is correct — not merely as a
property of this construction, but as a **general theorem about exact cover**.

*Proof.* Suppose that at some node of the search, two options $o$ and $o'$ each
complete a solution outright. Then each of them covers every item still
remaining. But a surviving option's support lies entirely within the remaining
items — any option touching a covered item has already been removed. Hence $o$
and $o'$ are equal as sets: they are duplicate options. ∎

The argument breaks in the presence of secondary items, but exercises 29 and 30
concern 0–1 matrices, that is, pure exact cover.

The empirical check agrees. Over all 52,466 pairs with trees of at most 9 nodes,
"the matrix contains duplicate rows" and "some node has two or more
solution-leaf children" coincided **exactly**.

---

## 4. An aside: dancing cells visits only 3 nodes

Running our `ssxcc` on the example matrix reports 3 nodes, not 9:

```text
(14 options, 15+0 items, 104 entries successfully read)
Altogether 0 solutions, 191 updates, 3 nodes.
```

This is no contradiction. The exercise is about Algorithm X, and dancing cells
detects failure one level sooner. At `ssxcc.go:380`, `hide` returns false the
moment an active primary item's size would drop to zero, and `commitOption` at
`ssxcc.go:344` refuses to descend into that branch at all. So the six leaves
that Algorithm X would visit are never reached, leaving $1 + 2 = 3$ nodes.

Solution counts are engine-independent and agreed everywhere. Below, using the
erratum's construction:

| tree | solution leaves | Algorithm X nodes / solutions | `ssxcc` |
| --- | --- | --- | --- |
| `((...)(...))` | 0 | 9 / 0 | 0 |
| `((.*.)(*.*))` | 3 | 9 / 3 | 3 |
| `(***)` | 3 | 4 / 3 | 3 |
| `((*)(..))` | 1 | 6 / 1 | 1 |

---

## 5. Method

One program did the work, kept in [`verify/`](verify/). It is a GWEB literate
program — [`verify.w`](verify/verify.w) is the source, and `gtangle` produces
the Go from it — so the reasoning above can be read alongside the code that
justifies it. The typeset document, [`verify.pdf`](verify/verify.pdf), is
committed beside the source, so it can be read without installing GWEB. The
program does four things.

1. **Builds the matrix** from a tree. A `-errata` flag swaps between the
   printed answer 30 and the corrected one.
2. **Runs a faithful Algorithm X.** The library is deliberately not used here:
   our `ssxcc` uses a different heuristic (forced-item propagation, early
   starvation detection) and so traverses a different tree. This implementation
   follows MRV literally and records the children of every node visited,
   returning the search tree whole, and counts how often step X3 finds a
   minimum that is not unique.
3. **Generates exhaustively** — every ordered tree on $n$ nodes, and all $2^L$
   ways of designating its leaves.
4. **Cross-checks against `ssxcc`.** It emits the matrix as DLX text and feeds
   it to the library, comparing the solution count with the number of
   designated solution leaves.

To reproduce:

```sh
make tangle                        # gtangle verify.w -> verify.go
cd taocp-7.2.2.1-exercises/29-30/verify && go build -o ex29 .
./ex29 -mode book                  # reproduce the printed 15x14 matrix
./ex29 -mode all -upto 10          # exhaustive, as printed -> 1 failure
./ex29 -mode all -upto 10 -errata  # exhaustive, erratum    -> 0 failures
./ex29 -mode ssxcc -errata -spec '((.*.)(*.*))'   # cross-check
```

`make pdf` regenerates `verify.pdf` from `verify.w`. In a tree spec, `.` is an
ordinary leaf, `*` a leaf designated a solution, and parentheses an internal
node; the example tree of exercise 29 is `((...)(...))`.

---

## 6. References

- D. E. Knuth, *The Art of Computer Programming*, Volume 4B (Addison-Wesley,
  2022), §7.2.2.1, exercises 29–30 (p. 126), answers (p. 421).
- D. E. Knuth, *Changes to Volume 4B*,
  <https://cs.stanford.edu/~knuth/err4b.textxt>, entry
  `\bugonpage 4b.421 in answer 30 (23.03.22)`.
