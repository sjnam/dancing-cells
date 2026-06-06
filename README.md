# Dancing Cells

Exact cover with colors (XCC), solved with Donald E. Knuth's sparse-set
**"dancing cells"** technique instead of dancing links. This repository is the
dancing-cells counterpart to [`sjnam/dlx`](https://github.com/sjnam/dlx) and
exposes the same library API, so the dlx example programs port over almost
unchanged.

The engine is a Go port of Knuth's
[`SSXCC`](https://www-cs-faculty.stanford.edu/~knuth/programs/ssxcc.w);
its solutions and search statistics match the original C program exactly.

## Library

```go
package main

import (
    "fmt"
    "strings"

    dcells "github.com/sjnam/dancing-cells"
)

func main() {
    input := `a b c d e f g
c e
a d g
b c f
a d f
b g
d e g
`
    xc := dcells.NewDancer()
    res := xc.Dance(strings.NewReader(input))

    for sol := range res.Solutions {
        for _, opt := range sol {
            fmt.Println(opt) // opt is []string, e.g. [a d f]
        }
    }
}
```

- `NewDancer()` returns a `*Solver`; set `Debug = true` for an input summary and
  final stats on stderr, like dlx.
- `Dance(io.Reader) *Result` parses the DLX text and returns
  `Result{ Solutions <-chan []Option, Heartbeat <-chan string }`.
- An `Option` is `[]string`, the option's item names (a colored secondary item
  appears as `name:c`). The list is always in input order, so `opt[0]`,
  `opt[1]`, … can be indexed positionally.
- The search runs in a goroutine and blocks on each send, so ranging over
  `Solutions` paces it. `WithContext(ctx)` aborts the search when `ctx` is
  cancelled (and lets you stop after the first solution without leaking).

### Input format (DLX)

The first non-comment line lists item names: primary items, then `|`, then
secondary items (which may be colored inside options). Each later line is one
option. Lines beginning with `|` are comments.

### Multiplicities (`NewMCC`)

`NewMCC()` returns an `*MCC` with the same `Dance`/`Result`/`Option` API but
allows a primary item to be covered a *range* of times (Knuth's SSMCC, binary
branching). Give a multiplicity prefix in the item line: `low:high|name` or
`high|name` (default `1:1`). For example `2|a` means item `a` must be covered
exactly twice. With default multiplicities it solves ordinary XCC, so it is a
strict superset of `NewDancer` (the partridge example uses it).

## Examples

| Example | Run |
| --- | --- |
| N-queens | `go run ./examples/queen 8` |
| Langford pairs | `go run ./examples/langford 4` |
| Pentominoes | `go run ./examples/pentominoes examples/pentominoes/6x10.dlx` |
| Sudoku | `go run ./examples/sudoku examples/sudoku/puzzles.txt` |
| Filomino | `go run ./examples/filomino examples/filomino/10x10.filomino.dlx` |
| Zebra puzzle | `go run ./examples/zebra` |
| Partridge (multiplicities) | `go run ./examples/partridge 8` |
| Word search | `go run ./examples/wordsearch examples/wordsearch/movie.txt 13 13` |

Each example generates the problem as DLX text (or reads it from a file),
passes it to `Dance`, and consumes the `Solutions` channel — the same pattern as
the dlx examples. Item names and colors are arbitrary-length (possibly
multibyte) strings, so zebra (`nationality:England`) and the Korean word search
work as-is. Partridge, which needs multiplicities, is solved with `NewMCC`. With
that, every dlx example is now ported to dancing cells.

## Reference CLIs

`cmd/` holds faithful command-line ports of Knuth's original programs (separate
from the library, for verification and comparison). See each README for the
input format, flags, and equivalence with the C reference.

- [`cmd/ssxcc`](cmd/ssxcc/README.md) — XCC, d-way branching (the origin of the library engine)
- [`cmd/ssmcc`](cmd/ssmcc/README.md) — adds item multiplicities (`u:v|name`), binary branching
