# ssmcc — exact cover with multiplicities + colors ("dancing cells", Go)

A Go port of Donald E. Knuth's CWEB program
[`SSMCC`](https://www-cs-faculty.stanford.edu/~knuth/programs/ssmcc.w). It extends
the sister program [`ssxcc`](../ssxcc/README.md) (exact cover with colors) with
**item multiplicities** — an extension Filip Stappers added in 2023 by folding in
the multiplicity machinery of DLX3.

Key differences from `ssxcc`:

- **Multiplicity `[low..high]`**: a primary item can be required to be covered
  *u..v* times rather than exactly once. Give it in the input as `low:high|name`
  or `high|name`, tracked with `bound` (residual capacity) and `slack`
  (= high − low).
- **Binary branching**: instead of `ssxcc`'s d-way branching, each node is
  labeled with an item i and an option o and branches two ways. The *left* child
  includes o (covering i once more); the *right* child removes o (i still
  uncovered). `level` is the tree depth; `stage` is the number of left branches
  (= options in the partial solution).
- The branching heuristic picks the item minimizing the branching degree
  `l+s−b+1` (l = size, b = residual bound, s = min(slack, b)). Degree 1 means a
  forced item.

The original's inert **weight** scaffolding (never read by the search) and its
`-w`/`-W` flags are omitted, as is Knuth's `mems` instrumentation (like the
`ssxcc` port).

## Build & run

From the module root:

```sh
go run ./cmd/ssmcc -m 1 cmd/ssmcc/examples/multiplicity.dlx
python3 cmd/ssmcc/examples/queens.py 8 | go run ./cmd/ssmcc -m 1
go build -o ssmcc ./cmd/ssmcc        # build a binary
```

## Input format

Same as [`ssxcc`](../ssxcc/README.md), except a primary item name may carry a
multiplicity prefix.

```text
2|a b c        # a must be covered exactly twice; b, c once (the default)
a b
a c
b c
```

`1:3|a` means "cover a 1–3 times"; `2|a` means "cover a exactly twice". Secondary
items cannot have a multiplicity, and may take a color as `name:c` inside an
option.

The command-line flags are the same as [`ssxcc`](../ssxcc/README.md) (minus the
weight-related `-w`/`-W`).

## File layout

| File | Role |
| --- | --- |
| `main.go` | `flag` parsing, I/O, reporting |
| `parse.go` | DLX/DLX3 parser (including the `scanBoundedName` multiplicity prefix) |
| `dance.go` | binary-branching recursive search (`includeOption`/`removeOption`/`chooseBest`) |
| `state.go` | global state, types, accessors (including `bound`/`slack`), output |
| `gbflip.go` | the gb_flip RNG |

## Equivalence with the original

Against the `ctangle ssmcc.w` reference, every output that defines the actual
computation matches: the solutions and their order, `count`/`updates`/`nodes`/
`maxdeg`/profile, the shape file, the `-v 4` item-scan trace, and the `-s`
randomized order.

Sample checks:

| Input | solutions | updates | nodes |
| --- | --- | --- | --- |
| 8-queens | 92 | 17291 | 1284 |
| 11-queens | 2680 | 1078409 | 72063 |
| 13-queens | 73712 | 24751853 | 1722083 |
| Langford L(2,8) | 300 | 38466 | 3097 |

> **Known difference**: the low-level `-v 2` (show_choices) "Backtracking to stage
> N" lines and a few `-v 4` (show_details) "can't cover"/"deactivating" messages
> are not reproduced. They are debug traces tied to the original's explicit `goto`
> backtracking loop (some even contain an `item[ii]` typo in the original), while
> the recursive version backtracks implicitly. The computed results are
> unaffected.
