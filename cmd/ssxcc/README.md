# ssxcc — XCC solver with "dancing cells" (Go)

A Go port of Donald E. Knuth's CWEB program
[`SSXCC`](https://www-cs-faculty.stanford.edu/~knuth/programs/ssxcc.w). It solves
exact cover with colors (XCC) using **sparse-set** ("dancing cells") data
structures instead of dancing **links**.

It accepts the same DLX input format as the original. The port is written in
idiomatic Go: the original's `goto`-based state machine became recursion, its
hand-written command-line parser became the `flag` package, and the single
monolith was split into role-based files. Knuth's signature `mems` instrumentation
was removed.

## Build & run

From the module root:

```sh
go run ./cmd/ssxcc -m 1 cmd/ssxcc/examples/exactcover.dlx   # print every solution
go run ./cmd/ssxcc < cmd/ssxcc/examples/exactcover.dlx      # stdin also works
python3 cmd/ssxcc/examples/queens.py 8 | go run ./cmd/ssxcc -m 1
go build -o ssxcc ./cmd/ssxcc                               # build a binary
```

## Input format (DLX)

- The first non-comment line lists item names. Those left of `|` are primary
  (must be covered); those to the right are secondary (covered at most once, and
  may take a color).
- Each later line is one option, listing the item names it contains. A secondary
  item may carry a one-character color as `name:c`.
- Lines starting with `|`, and blank lines, are comments/ignored.

```text
a b c d e f g          # 7 primary items
c e
a d g
...
```

## Command-line flags

It uses the `flag` package, so flags are given like `-v 6` (space) or `-v=6`.

| Flag | Meaning |
| --- | --- |
| `-v <n>` | verbose bitmask (1 basics, 2 choices, 4 details, 128 profile, 256 full state, 512 totals, 1024 warnings, 2048 max degree) |
| `-m <n>` | print every n-th solution (`-m 0` = count only, the default) |
| `-s <n>` | randomize the item list with seed n (via gb_flip) |
| `-d <n>` | progress report every n search nodes (0 = never) |
| `-c`/`-C`/`-l <n>` | limit the levels of trace output |
| `-t <n>` | stop after n solutions (0 = unlimited) |
| `-T <n>` | give up after n search nodes (0 = unlimited) |
| `-S <file>` | write a search-tree shape file |

> The original's `-d`/`-T` were measured in mems; since the mems instrumentation
> was removed, here they are measured in **search nodes**.

## File layout

| File | Role |
| --- | --- |
| `main.go` | `flag` parsing, I/O setup, final reporting |
| `parse.go` | DLX input parser (`readItemNames`, `readOptions`, `createNode`, `finalize`) |
| `dance.go` | recursive search (`search`/`chooseItem`/`commitOption`/`hide`) and sparse-set operations |
| `state.go` | global state, types, field accessors, name encoding, output/`sanity` helpers |
| `gbflip.go` | a port of Knuth's portable RNG gb_flip (for the `-s` shuffle) |

### About the recursive structure

The original manages backtracking positions directly with `goto`, an optimization
that skips saving domain sizes on forced moves. This port replaces that with plain
recursion that saves/restores symmetrically at every level. Since save/restore is
**pure bookkeeping that does not affect the search path**, the solutions, their
order, the node count, and the update count all match the original exactly (a
forced level just does a little redundant size-saving).

## Equivalence with the original

Against a reference built with `ctangle ssxcc.w && cc -std=gnu89 ssxcc.c -o
ssxcc_ref`, every output matches except the removed mems/bytes/ccost: the
solutions and their order, `count`/`updates`/`nodes`/`maxdeg`/profile, the shape
file, and the `-v 2`/`-v 4` traces.

E.g. 13-queens: `73712 solutions, 29080172 updates, 1278828 nodes` — identical for
C and Go.

For the sister program that adds multiplicities, see
[`../ssmcc`](../ssmcc/README.md).
