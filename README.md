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

| 예제 | 실행 |
| --- | --- |
| N-queens | `go run ./examples/queen 8` |
| Langford pairs | `go run ./examples/langford 4` |
| Pentominoes | `go run ./examples/pentominoes examples/pentominoes/6x10.dlx` |
| Sudoku | `go run ./examples/sudoku examples/sudoku/puzzles.txt` |
| Filomino | `go run ./examples/filomino examples/filomino/10x10.filomino.dlx` |
| Zebra puzzle | `go run ./examples/zebra` |
| Partridge (multiplicities) | `go run ./examples/partridge 8` |
| Word search | `go run ./examples/wordsearch examples/wordsearch/movie.txt 13 13` |

각 예제는 문제를 DLX 텍스트로 생성(또는 파일에서 읽어)해 `Dance`에 넘기고
`Solutions` 채널을 소비합니다 — dlx 예제와 동일한 패턴입니다. 항목 이름과 색은
임의 길이의 (멀티바이트 가능) 문자열이라 zebra(`nationality:England`)나
한글 word search도 그대로 동작합니다. 다중도가 필요한 partridge는 `NewMCC`로
풉니다. 이로써 dlx의 모든 예제가 dancing cells로 포팅됐습니다.

## Reference CLIs

`cmd/`에는 Knuth 원본을 충실히 옮긴 명령행 솔버가 있습니다(라이브러리와 별개로,
검증·비교용). 입력 형식·플래그·C 레퍼런스 동치성은 각 README를 보세요.

- [`cmd/ssxcc`](cmd/ssxcc/README.md) — XCC, d-갈래 분기 (라이브러리 엔진의 원본)
- [`cmd/ssmcc`](cmd/ssmcc/README.md) — 항목 다중도(`u:v|name`) 추가, 이진 분기
