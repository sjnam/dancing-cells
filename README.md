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
  over `f.Live` for the surviving (item, option) pairs; `f.Cost(opt)` and
  `f.Name(item)` read them back, and `f.Need(item)` says how many more times an
  item must still be covered (always 1 under XCC). Leaving `Bound` nil prunes on
  the incumbent alone.
- **Both engines have it.** `NewMCC()` takes the same `Minimize` and `Bound`,
  and there `Need` can exceed 1 — which is the whole point of having it.
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
| Cheapest Latin-square transversal | `go run ./examples/transversal -plain 11` |
| Partridge with a hollow centre | `go run ./examples/hollow -z 16` |

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

### Hungarian Dance No. 5

The first of two examples that use `Minimize` and `Bound`. A *transversal* of a Latin
square is one cell per row, per column, and per symbol — three "exactly once"
constraints, so it is an exact cover with 3n items and n² options. Price every
cell and the question becomes: which transversal is cheapest?

The bound is the point. Forget the symbols and what remains is a minimum-cost
assignment of the surviving rows to the surviving columns, which the Hungarian
algorithm solves *exactly* in O(n³). Dropping a constraint can only make the
answer cheaper, so it is a valid lower bound — and a strong one, because it is
the exact optimum of a subproblem rather than an estimate. Branching by dancing
cells, bounding by Hungarian: the write-up, which began with Brahms, calls it
the *Hungarian Dance technique* — a name for where two existing algorithms are
made to mesh, not a new procedure.

````console
$ go run ./examples/transversal -plain 9
   0:81   1:887   2:847    3:59  [ 4:81]  5:318   6:425   7:540   8:456
   ...
가장 싼 횡단의 값 1296, 노드 184개, 1ms
하한 없이는 노드 2125개, 1ms
````

The square is the Cayley table of Z_n, so by Hall–Paige it has transversals only
for odd n (and their counts match OEIS A006717: 15, 133, 2025, 37851 for
n = 5, 7, 9, 11). The bound pays off more the harder the problem gets:

| n | nodes without a bound | nodes with one | ratio |
| --: | --: | --: | --: |
| 13 | 155,095 | 979 | 158× |
| 15 | 1,681,693 | 6,881 | 244× |
| 17 | 8,571,751 | 16,842 | 509× |
| 19 | 117,455,633 | 82,212 | **1429×** |
| 21 | >350M (1 min, unfinished) | 268,418 | — |

That is 39× in wall clock at n = 19, and it moves the wall from about n = 19 to
about n = 27 (2 minutes). Below n ≈ 11 the bound costs more than it saves. And
for even n it does nothing at all: with no transversal there is never an
incumbent to beat, and branch-and-*bound* only works once it has something to
beat.

And the ceiling, which the write-up now states plainly: those ratios are
measured against the *same program with its bound switched off*, not against
the state of the art. Minimum-cost transversal is almost too easy to write as
an integer program, and written that way its LP relaxation is nearly tight — a
general MILP solver clears n = 27 in about a second and barely branches, where
this program spends two minutes. Ours throws a whole axis away and lands some
40% below the optimum; the LP keeps all three and falls short by under 10%.
That the Hungarian algorithm solves our relaxation *exactly* and that our
relaxation is *good* turn out to be different statements. The technique is a
frame worth knowing, but this is not the floor where it earns its keep.

Fitting the same hook to MCC turned out to be the delicate half. Under binary
branching, giving up on a branch is only safe where the force stack is empty —
otherwise the next node adopts the leftover entries as its own forced moves,
and a forced move there is not a branch at all but the inclusion of one option
with the alternatives never tried. The answers stay plausible and merely stop
being the cheapest; it took a few thousand random problems checked against full
enumeration to catch it.

### A Partridge in a Pear Tree

The other `Minimize` example, and the one that puts `Need` to work. The
[partridge puzzle](examples/partridge) packs *k* copies of the *k*×*k* square,
*k* = 1…*n*, into a square of side *n*(*n*+1)/2 — the areas match because
1³+⋯+*n*³ = (1+⋯+*n*)². The smallest order with any solution is 8. Now price it:
mark off a *z*×*z* zone at the centre of the board and charge 1 for every piece
that comes to rest **entirely inside** it. A cover of price 0 is a board where
every piece straddles the zone's edge — a *hollow heart*.

Pencil and paper settle half the question. A piece of side ≤ *n* covering a cell
reaches at most *n*−1 away from it, so cells at least that far inside the zone
can only be covered by pieces trapped in the zone. Those *trapped cells* form a
(*z*−2*n*+2)×(*z*−2*n*+2) block, and it is non-empty as soon as *z* ≥ 2*n*−1:

> A hollow heart is possible only for *z* ≤ 2*n*−2.

The bound is that argument, made dynamic. Sweep `Frame.Live`; for each uncovered
cell take the cheapest option still covering it; keep those that cost something
and are pairwise ≥ *n* apart in Chebyshev distance, so no single piece can pay
for two; sum. It finds cells that start out free and become trapped as options
die. On the order-8 board (36×36), with a 2-minute cap:

| z | minimum | no bound | `Need` bound | trapped-cell bound |
| --: | --: | --: | --: | --: |
| 8 | 0 | 7,347 / 139ms | 7,347 / 1.73s | 7,347 / 1.70s |
| 12 | 0 | 11,142 / 189ms | 11,142 / 2.60s | 10,691 / 2.47s |
| 14 | ≤ 1 | — | — | — |
| 16 | **1** | — | — | **7,923 / 1.91s** |

At *z* ≤ 12 a price-0 cover turns up almost at once, the incumbent drops to 0,
and every branch dies on `cost + rest >= incumbent` — the bound is pure
overhead. At *z* = 16 it inverts: two minutes and 6.4M nodes prove nothing
without the bound, and with it the whole tree collapses in under two seconds,
because the trapped 2×2 block forces the root bound to 1.

The `Need` bound — *size k still needs t copies but only u of its surviving
placements are free, so t−u must be paid* — is the one that reads `Frame.Need`,
which means something only under multiplicities. It is honest to report that it
does not pay here: whether a piece gets trapped depends on **where** it lands,
and lumping placements together by size cannot see that. Both bounds ship behind
`-bound`, so the table above is reproducible.

*z* = 14 = 2*n*−2 stays open: price 1 is found in two seconds, price 0 is
neither found nor ruled out. It is exactly the largest zone the pencil argument
permits, and exactly the last one where the bound returns 0 at the root.

The write-up is [`examples/hollow/hollow.w`](examples/hollow/hollow.w).

````console
$ go run ./examples/hollow -z 16
갇힌 조각 2개 (노드 7331개, 1.699s)
갇힌 조각 1개 (노드 7906개, 1.845s)
...
갇힌 조각 1개, 노드 7923개, 1.91s
````

## The source is a literate program

The engine is written in the [literate-programming](https://en.wikipedia.org/wiki/Literate_programming)
style Knuth invented for `TeX`, and it follows the same tradition as the `SSXCC`
and `SSMCC` programs it was ported from, which Knuth himself wrote as literate
`CWEB`. Knuth kept `DLX1`, `DLX2`, `DLX3` as separate programs rather than one
program with switches, and so do we:

| Document | What it is |
| --- | --- |
| [`dcells.w`](dcells.w) | the common ground — the public API (`Option`, `Result`, `Frame`), the node array both engines dance on, and the `DLX` scanner. Its opening pages tell the sparse-set story. |
| [`ssxcc.w`](ssxcc.w) | the **XCC** engine: exact cover with colors, *d*-way branching, and a closing chapter on least-cost covers. Reads start to finish on its own. |
| [`ssmcc.w`](ssmcc.w) | the **MCC** engine: multiplicities, binary branching, and its own chapter on least-cost covers. Likewise self-contained. |

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

Three of the examples are literate programs as well, and they are where the
*modelling* gets explained rather than the engine. The two Korean ones are
typeset with `luatex` (kotexgweb).

| Document | What it is |
| --- | --- |
| [`examples/words/words.w`](examples/words/words.w) | how *is there a set of five five-letter words covering 24 letters of the alphabet?* turns into a DLX input. Its answer is that colors alone — no multiplicities — pin the word count at exactly five. Carries a MetaPost figure, [`words.mp`](examples/words/words.mp). |
| [`examples/transversal/transversal.w`](examples/transversal/transversal.w) | *Hungarian Dance No. 5* — the cheapest transversal of a Latin square, branched by dancing cells and bounded by the Hungarian algorithm. Where to find a lower bound, why this one is exact, and where else the trick applies. |
| [`examples/hollow/hollow.w`](examples/hollow/hollow.w) | *A Partridge in a Pear Tree* — how large a hollow can the partridge puzzle keep at its centre. A geometric lower bound that turns a hopeless search into a two-second proof, and a `Need`-based one that honestly does not pay. |
