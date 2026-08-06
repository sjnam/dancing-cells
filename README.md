# Dancing Cells

Exact cover with colors (XCC), solved with Donald E. Knuth's sparse-set
**"dancing cells"** technique instead of dancing links. This repository is the
dancing-cells counterpart to [`sjnam/dlx`](https://github.com/sjnam/dlx) and
exposes the same library API, so the dlx example programs port over almost
unchanged.

The library is a **literate program**: its whole source lives in three English
[GWEB](https://github.com/sjnam/gweb) documents — [`dcells.w`](dcells.w),
[`ssxcc.w`](ssxcc.w), and [`ssmcc.w`](ssmcc.w) — see
[The source is a literate program](#the-source-is-a-literate-program) below.

## Library

```go
package main

import (
    "fmt"
    "strings"

    cells "github.com/sjnam/dancing-cells"
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
    xc := cells.NewXCC()
    res := xc.Dance(strings.NewReader(input))

    for sol := range res.Solutions {
        for _, opt := range sol {
            fmt.Println(opt) // opt is []string, e.g. [a d f]
        }
    }
}
```

- `NewXCC()` returns an `*XCC`; set `Debug = true` for an input summary and
  final stats on stderr, like dlx.
- `Dance(io.Reader) *Result` parses the DLX text and returns
  `Result{ Solutions <-chan []Option, Heartbeat <-chan string }`.
- An `Option` is `[]string`, the option's item names (a colored secondary item
  appears as `name:c`). The list is always in input order, so `opt[0]`,
  `opt[1]`, … can be indexed positionally.
- The search runs in a goroutine and blocks on each send, so ranging over
  `Solutions` paces it. `WithContext(ctx)` aborts the search when `ctx` is
  cancelled (and lets you stop after the first solution without leaking).

### Least-cost covers (`Minimize`)

When every option carries a price and you want the cheapest cover rather than
every cover, use `Minimize` instead of `Dance`:

```go
xc := cells.NewXCC()
res := xc.Minimize(strings.NewReader(input), func(o int, opt cells.Option) int {
    return price(opt) // o is the option's number, 1, 2, … in input order
})
for sol := range res.Solutions {
    // each cover is strictly cheaper than the one before; the last is optimal
}
```

- The price function is called once per option, right after the input is read.
- Branch and bound: a branch that cannot beat the best cover so far is
  abandoned, so `Solutions` delivers a strictly improving chain.
- `xc.Bound = func(f cells.Frame) int { … }` supplies a lower bound on the cost
  of *finishing* the partial cover at each node — never an overestimate. Range
  over `f.Live` for the surviving (item, option) pairs, and use `f.Cost(opt)`
  and `f.Name(item)` to read them back. Leaving `Bound` nil prunes on the
  incumbent alone.
- `Dance` is untouched by any of this.

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
strict superset of `NewXCC` (the partridge example uses it).

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
| Five words, 24 letters | `go run ./examples/words examples/words/sgb-words.txt 5` |

Each example generates the problem as DLX text (or reads it from a file),
passes it to `Dance`, and consumes the `Solutions` channel — the same pattern as
the dlx examples. Item names and colors are arbitrary-length (possibly
multibyte) strings, so zebra (`nationality:England`) and the Korean word search
work as-is. Partridge, which needs multiplicities, is solved with `NewMCC`. With
that, every dlx example is now ported to dancing cells.

### Langford pairing

````console
$ go run ./examples/langford 4
[2 3 4 2 1 3 1 4]
````

### Pentominoes

- 12 pieces: **O P Q R S T U V W X Y Z**

````console
$ cd example/pentominoes
$ go run main.go 8x8.dlx
Solution: 1
P P P W U U U Y
P P W W U T U Y
Z W W T T T Y Y
Z Z Z     T X Y
R R Z     X X X
V R R S S S X Q
V R S S Q Q Q Q
V V V O O O O O

Solution: 2
W P P P U U U Y
W W P P U T U Y
Z W W T T T Y Y
Z Z Z     T X Y
R R Z     X X X
V R R S S S X Q
V R S S Q Q Q Q
V V V O O O O O

Solution: 3
V V V Z W W Q Q
V Z Z Z R W W Q
V Z P R R R W Q
O P P     R X Q
O P P     X X X
O U U S S S X T
O U S S Y T T T
O U U Y Y Y Y T

...
````

### Nqueen

````console
$ go run ./examples/queen 8
1:
Q . . . . . . .
. . . . . Q . .
. . . . . . . Q
. . Q . . . . .
. . . . . . Q .
. . . Q . . . .
. Q . . . . . .
. . . . Q . . .

2:
Q . . . . . . .
. . . . Q . . .
. . . . . . . Q
. . . . . Q . .
. . Q . . . . .
. . . . . . Q .
. Q . . . . . .
. . . Q . . . .

...
````

### Sudoku

````console
$ cd examples/sudoku
$ go run main.go puzzles.txt
Q[    1]: ..43..2.9..5..9..1.7..6..43..6..2.8719...74...5..83...6.....1.5..35.869..4291.3..
A[    1]: 864371259325849761971265843436192587198657432257483916689734125713528694542916378
Q[    2]: .4.1...5.1.7..396.52...8..........17...9.68..8.3.5.62..9..6.5436...8.7..25..971..
A[    2]: 346179258187523964529648371965832417472916835813754629798261543631485792254397186
Q[    3]: 6..12.384..8459.72.....6..5...264.3..7..8...694...3...31.....5..897.....5.2...19.
A[    3]: 695127384138459672724836915851264739273981546946573821317692458489715263562348197
Q[    4]: 4972.....1..4....5....16.9862.3...4.3..9.......1.726....2..587....6....453..97.61
A[    4]: 497258316186439725253716498629381547375964182841572639962145873718623954534897261
Q[    5]: ..591.3.8..94.3.6..275..1...3....2.1...82...7..6..7..4....8....64.15.7..89....42.
A[    5]: 465912378189473562327568149738645291954821637216397854573284916642159783891736425
...
Q[70098]: ..2.....9.3...25....61..37..........2..4..13...7..6.4...18.....76...54....9..76..
A[70098]: 472653819138792564956148372694531287285479136317286945521864793763915428849327651
Q[70099]: .3............1..87..58........24.5..4.8739....36.....9.......2..5..2.912.....7.4
A[70099]: 438297165659431278721586349167924853542873916893615427974168532385742691216359784
Solving took: 2.142709417s
````

### Filomino

````console
$ cd examples/filomino

| ..3.3...3.
| ..131...43
| 64...141..
| .6...4.4..
| 64...141..
| ..434...12
| ..3.3...2.
| ..434...12
| 24...161..
| .2...6.6..

$ go run main.go 10x10.filomino.dlx
3 3 3 1 3 3 2 2 3 3
4 4 1 3 1 3 4 4 4 3
6 4 4 3 3 1 4 1 2 2
6 6 6 6 4 4 1 4 4 4
6 4 3 3 4 1 4 1 4 2
4 4 4 3 4 3 4 4 1 2
3 3 3 1 3 3 4 2 2 1
2 4 4 3 4 4 6 6 1 2
2 4 4 3 4 1 6 1 3 2
1 2 2 3 4 6 6 6 3 3
````

### Word Search

What is Word search? <https://thewordsearch.com/>

````console
$ cd examples/wordsearch
$ go run main.go movie.txt 13 13
봄게하대위게하밀은마기생충
돼여힘다장시제국설국열차타
지변름의인여의변해밀양며신
가명호가도봄날은간다리생과
우량장인을원엽가더날파활함
물생화파괴겨강기휘마이의께
에인홍물밤골울기적올란발죄
빠한련과막것극그친인드견와
진콤낮동의태아구리씨그보벌
날달투나택시운전사고가녀이
다컴는억추의인살박쥐봄아카
웰수다오수정씨자금한절친바
복스시아오하행산부적의공공

$ go run main.go mathematicians.txt 15 15
H I L B E R T L C A N T O R O
X O L F W Q F F O H H C R I K
G T C A T A L A N R E T S D O
C T Q S M I N K O W S K I R T
G E S Y L V E S T E R V R A M
F N A W N O R R E P Y K T M E
S I A B E L U A D N A L V A L
J T W E I E R S T R A S S D L
S U I Z T I W R U H L X C A I
U D Z E C R E H S I A L G H N
B O R E L W D N A R T R E B X
D G R A M T S U I N E B O R F
R U N G E O J J E N S E N C X
F F O K R A M E E T I M R E H
E K N O P P L E S N E H X S N
````

### Zebra puzzle

Five people, from five different countries, have five different occupations,
own five different pets, drink five different beverages, and live in a row of
five different colored houses.

- The Englishman lives in a red house.
- The painter comes from Japan.
- The yellow house hosts a diplomat.
- The coffee-lover's house is green.
- The Norwegian's house is hte leftmost.
- The dog's owner is from Spain.
- The milk drinker lives in the middle house.
- The violinist drinks orange juice.
- The white house is just left of the green one.
- The Ukrainian drinks tea.
- The Norwegian lives next to the blue house.
- The sculptor breeds snails.
- The horse lives next to the diplomat.
- The nurse lives next to the fox.

Who trains the zebra, and who prefers to drink just plain water?

````console
$ go run ./examples/zebra
Norway      Ukraine     England     Spain       Japan
diplomat    nurse       sculptor    violinist   painter
fox         horse       snail       dog         zebra
water       tea         milk        orange      coffee
yellow      blue        red         white       green
````

### Partridge puzzle

````console
$ go run ./examples/partridge 8
┌───┬───┬─────────┬─────────────┬─────────────┬─────────────┬───────────┐
│  2│  2│         │             │             │             │           │
├───┴───┤         │             │             │             │           │
│       │         │             │             │             │           │
│       │        5│             │             │             │           │
│      4├─────────┤             │             │             │          6│
├───────┤         │            7│            7│            7├───────────┤
│       │         ├─────────────┴─┬───────────┴───┬─────────┤           │
│       │         │               │               │         │           │
│      4│        5│               │               │         │           │
├─────┬─┴─────────┤               │               │         │           │
│     │           │               │               │        5│          6│
│    3│           │               │               ├─────┬───┴───────────┤
├─────┤           │               │               │     │               │
│     │           │              8│              8│    3│               │
│    3│          6├─┬───────────┬─┴─────┬─────────┴─────┤               │
├─────┴───┬───────┴─┤           │       │               │               │
│         │         │           │       │               │               │
│         │         │           │      4│               │               │
│         │         │           ├───────┤               │              8│
│        5│        5│          6│       │               ├───────────────┤
├─────────┴─────┬───┴───────────┤       │               │               │
│               │               │      4│              8│               │
│               │               ├───────┴───┬───────────┤               │
│               │               │           │           │               │
│               │               │           │           │               │
│               │               │           │           │               │
│               │               │           │           │              8│
│              8│              8│          6│          6├───────────────┤
├─────────────┬─┴───────────┬───┴─────────┬─┴───────────┤               │
│             │             │             │             │               │
│             │             │             │             │               │
│             │             │             │             │               │
│             │             │             │             │               │
│             │             │             │             │               │
│            7│            7│            7│            7│              8│
└─────────────┴─────────────┴─────────────┴─────────────┴───────────────┘

$ go run ./examples/partridge 9
┌─────────────────┬───────────────┬─────────────────┬─────────────────┬───────────┬───────┐
│                 │               │                 │                 │           │       │
│                 │               │                 │                 │           │       │
│                 │               │                 │                 │           │      4│
│                 │               │                 │                 │           ├───────┤
│                 │               │                 │                 │          6│       │
│                 │               │                 │                 ├───────────┤       │
│                 │              8│                 │                 │           │      4│
│                9├─────┬─────────┤                9│                9│           ├───────┤
├─────────────┬───┤     │         ├───────┬─────┬───┴───────┬─────────┤           │       │
│             │  2│    3│         │       │     │           │         │           │       │
│             ├───┴─────┤         │       │    3│           │         │          6│      4│
│             │         │        5│      4├─────┤           │         ├───┬───────┴───────┤
│             │         ├─────────┴───────┤     │           │        5│  2│               │
│             │         │                 │    3│          6├─┬───────┴───┤               │
│            7│        5│                 ├─────┴───┬───────┴─┤           │               │
├───────────┬─┴─────────┤                 │         │         │           │               │
│           │           │                 │         │         │           │               │
│           │           │                 │         │         │           │               │
│           │           │                 │        5│        5│          6│              8│
│           │           │                 ├─────────┴─────┬───┴───────────┼───────────────┤
│          6│          6│                9│               │               │               │
├───────────┴─┬─────────┴───┬─────────────┤               │               │               │
│             │             │             │               │               │               │
│             │             │             │               │               │               │
│             │             │             │               │               │               │
│             │             │             │               │               │               │
│             │             │             │              8│              8│              8│
│            7│            7│            7├───────────────┼───────────────┼───────────────┤
├─────────────┼─────────────┼─────────────┤               │               │               │
│             │             │             │               │               │               │
│             │             │             │               │               │               │
│             │             │             │               │               │               │
│             │             │             │               │               │               │
│             │             │             │               │               │               │
│            7│            7│            7│              8│              8│              8│
├─────────────┴───┬─────────┴───────┬─────┴───────────┬───┴─────────────┬─┴───────────────┤
│                 │                 │                 │                 │                 │
│                 │                 │                 │                 │                 │
│                 │                 │                 │                 │                 │
│                 │                 │                 │                 │                 │
│                 │                 │                 │                 │                 │
│                 │                 │                 │                 │                 │
│                 │                 │                 │                 │                 │
│                9│                9│                9│                9│                9│
└─────────────────┴─────────────────┴─────────────────┴─────────────────┴─────────────────┘

$ go run ./examples/partridge 10
┌───────────────────┬───────────────────┬───────────┬─────────────┬───────────────┬─────────────┬─────────────┐
│                   │                   │           │             │               │             │             │
│                   │                   │           │             │               │             │             │
│                   │                   │           │             │               │             │             │
│                   │                   │           │             │               │             │             │
│                   │                   │          6│             │               │             │             │
│                   │                   ├───┬───────┤            7│               │            7│            7│
│                   │                   │  2│       ├─────────────┤              8├─┬─────────┬─┴─────────────┤
│                   │                   ├───┤       │             ├───────────────┴─┤         │               │
│                 10│                 10│  2│      4│             │                 │         │               │
├─────────────────┬─┴───────────────┬───┴───┴───────┤             │                 │         │               │
│                 │                 │               │             │                 │        5│               │
│                 │                 │               │             │                 ├─────────┤               │
│                 │                 │               │            7│                 │         │               │
│                 │                 │               ├─────────────┤                 │         │              8│
│                 │                 │               │             │                 │         ├───────┬───────┤
│                 │                 │               │             │                9│        5│       │       │
│                 │                 │              8│             ├───────┬─────────┴─────────┤       │       │
│                9│                9├───────────────┤             │       │                   │      4│      4│
├─────────────────┼─────────────────┤               │             │       │                   ├───────┴───────┤
│                 │                 │               │            7│      4│                   │               │
│                 │                 │               ├─────────┬───┴───────┤                   │               │
│                 │                 │               │         │           │                   │               │
│                 │                 │               │         │           │                   │               │
│                 │                 │               │         │           │                   │               │
│                 │                 │              8│        5│           │                   │               │
│                 │                 ├─────────────┬─┴───┬─────┤          6│                 10│              8│
│                9│                9│             │     │     ├───────────┴───┬───────────────┼───────────────┤
├─────────────────┼─────────────────┤             │    3│    3│               │               │               │
│                 │                 │             ├─────┴─────┤               │               │               │
│                 │                 │             │           │               │               │               │
│                 │                 │             │           │               │               │               │
│                 │                 │            7│           │               │               │               │
│                 │                 ├─────────────┤           │               │               │               │
│                 │                 │             │          6│              8│              8│              8│
│                 │                 │             ├───────────┴───────┬───────┴───────────┬───┴───────────────┤
│                9│                9│             │                   │                   │                   │
├───────────┬─────┴───────────┬─────┤             │                   │                   │                   │
│           │                 │     │             │                   │                   │                   │
│           │                 │    3│            7│                   │                   │                   │
│           │                 ├─────┴───┬─────────┤                   │                   │                   │
│           │                 │         │         │                   │                   │                   │
│          6│                 │         │         │                   │                   │                   │
├───────────┤                 │         │         │                   │                   │                   │
│           │                 │        5│        5│                 10│                 10│                 10│
│           │                9├─────────┴─────────┼───────────────────┼───────────────────┼───────────────────┤
│           ├─────────────────┤                   │                   │                   │                   │
│           │                 │                   │                   │                   │                   │
│          6│                 │                   │                   │                   │                   │
├───────────┤                 │                   │                   │                   │                   │
│           │                 │                   │                   │                   │                   │
│           │                 │                   │                   │                   │                   │
│           │                 │                   │                   │                   │                   │
│           │                 │                   │                   │                   │                   │
│          6│                9│                 10│                 10│                 10│                 10│
└───────────┴─────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┘

````

### Five words that cover 24 letters

`sgb-words.txt` is the Stanford GraphBase list of 5757 five-letter English
words. Five of them fill 25 letter slots; can those slots cover 24 distinct
letters of the alphabet? (Twenty-five cannot be done — no five words on this
list are pairwise letter-disjoint.) The write-up is
[`examples/words/words.w`](examples/words/words.w).

````console
$ go run ./examples/words examples/words/sgb-words.txt 8
frock glitz nymph squab vowed   (o를 두 번, j x 빠짐)
frock squab veldt whomp zingy   (o를 두 번, j x 빠짐)
frock glitz nymph squab vexed   (vexed 안에서 겹침, j w 빠짐)
foxed glitz nymph squab wreck   (e를 두 번, j v 빠짐)
fjord glitz nymph squab wreck   (r를 두 번, v x 빠짐)
frock glitz jived nymph squab   (i를 두 번, w x 빠짐)
frock glitz nymph squab waved   (a를 두 번, j x 빠짐)
foxed glitz nymph squab wrack   (a를 두 번, j v 빠짐)
해 8개
````

Pass `0` instead of `8` to enumerate them all: 9592 answers in about 40 seconds.
The solver itself returns 8132 — one per letter set — and each is expanded into
the words that realize it, since anagrams like `stack` and `tacks` share a
letter set and are interchangeable in an answer.

## The source is a literate program

The engine is written in the [literate-programming](https://en.wikipedia.org/wiki/Literate_programming)
style Knuth invented for `TeX`, and it follows the same tradition as the `SSXCC`
and `SSMCC` programs it was ported from, which Knuth himself wrote as literate
`CWEB`. Knuth kept `DLX1`, `DLX2`, `DLX3` as separate programs rather than one
program with switches, and so do we:

| Document | What it is |
| --- | --- |
| [`dcells.w`](dcells.w) | the common ground — the public API (`Option`, `Result`), the node array both engines dance on, and the `DLX` scanner. Its opening pages tell the sparse-set story. |
| [`ssxcc.w`](ssxcc.w) | the **XCC** engine: exact cover with colors, *d*-way branching, and a closing chapter on least-cost covers. Reads start to finish on its own. |
| [`ssmcc.w`](ssmcc.w) | the **MCC** engine: multiplicities, binary branching. Likewise self-contained. |

All three tangle into the one Go package `dcells`, so `NewXCC()` and `NewMCC()`
still come from a single import.

The [`Makefile`](Makefile) drives the GWEB tools:

```sh
make            # gtangle the .w files → .go, then build
make pdf        # gweave → typeset every document
make clean      # remove everything the .w files generate
```

Only the `.w` files are checked in — every `.go` and every typeset document is
generated, so `make` is the first thing to run in a fresh clone. Because `gtangle` emits `//line` directives, a Go compiler error
points straight back at the line in the `.w` file it came from.

[`examples/words`](examples/words/words.w) is a fourth literate program, this
one in Korean, and it is where the modelling ideas get explained rather than the
engine: how *is there a set of five five-letter words covering 24 letters of the
alphabet?* turns into a DLX input. Its answer is that colors alone — no
multiplicities — are enough to pin the word count at exactly five. It is typeset
with `luatex` (kotexgweb) and carries a MetaPost figure, [`words.mp`](examples/words/words.mp).

## Reference CLIs

`cmd/` holds faithful command-line ports of Knuth's original programs (separate
from the library, for verification and comparison). See each README for the
input format, flags, and equivalence with the C reference.

- [`cmd/ssxcc`](cmd/ssxcc/README.md) — XCC, d-way branching (the origin of the library engine)
- [`cmd/ssmcc`](cmd/ssmcc/README.md) — adds item multiplicities (`u:v|name`), binary branching
