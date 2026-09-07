\input kotexgweb

\def\title{도미노 덮기 세기}

@s Option int
@s Diagram int
@s Int int
@s Rand int
@s Builder int
@s board int

@* 들어가며.
$8\times8$ 체스판을 $1\times2$ 도미노 서른두 개로 빈틈없이 덮는 방법은 몇
가지인가? 답은 12{,}988{,}816가지다. $10\times10$이면 258{,}584{,}046{,}368가지,
$12\times12$이면 53{,}060{,}477{,}521{,}960{,}000가지다.

이 수들은 세어서 얻은 것이 아니다. 1961년에 P.~W. Kasteleyn이, 그리고 같은
해에 H.~N.~V. Temperley와 M.~E. Fisher가 따로, 닫힌 꼴을 찾아냈다. $m\times n$
판이면
$$\prod_{j=1}^{m}\prod_{k=1}^{n}\left(4\cos^2{\pi j\over m+1}+
4\cos^2{\pi k\over n+1}\right)^{1/4}$$
이다. 격자 그래프의 완전 매칭을 세는 문제가 행렬식으로 풀린다는, 통계물리학에서
나온 아름다운 결과다.
@^Kasteleyn, Pieter W.@>
@^Temperley, H. N. V.@>
@^Fisher, Michael E.@>

@ 그런데 이것을 {\it 정확한 덮개\/}로 풀면 어떻게 되는가. 옮기는 길은 이보다
더 맨몸일 수 없다. 판의 칸마다 주 항목 하나, 도미노를 놓을 수 있는 자리마다
옵션 하나이고, 그 옵션은 칸 두 개를 품는다. 부 항목도 색도 다중도도 없다.

그러고 나면 우리 엔진들은 답을 하나씩 채널로 흘려보낸다. $8\times8$이면 1300만
개를 흘려보내는 데 마디 5010만 개를 밟고 18초가 걸린다. $10\times10$이면 마디가
1조 개라 나흘쯤 걸리고, $12\times12$이면 $2\times10^{17}$개라 몇백 년이 걸린다.
{\bf 답을 하나씩 보는 한 이 문제는 셀 수 없다.}

@ 그래서 이 예제는 |zdd| 엔진을 쓴다. 도미노 덮기는 그 엔진이 이기도록 생긴
문제다. 판의 왼쪽 절반을 어떻게 덮었든, 남은 것은 ``아직 안 덮인 칸의 모양''
하나로 결정되고, 그 모양의 가짓수는 덮는 방법의 가짓수보다 어마어마하게 적다.
$12\times12$ 판에서 서로 다른 부분문제는 5만 2천 개뿐이고, 그래서 5경 3천조
가지를 0.3초에 센다. 마디 7만 개짜리 그림 하나가 그 전부를 담는다.

@ 세는 것으로 끝이 아니다. 다이어그램을 지어 두면 열거로는 닿을 수 없는 물음
셋을 더 물을 수 있고, 이 예제는 그 셋을 모두 묻는다.
\smallskip\item{$\bullet$} {\it 공식이 맞는가.} 카스텔레인의 곱과 우리가 센 수를
맞대어 본다. 한쪽은 해석적이고 다른 한쪽은 정확한 정수다.
\smallskip\item{$\bullet$} {\it 하나만 보여 다오.} 전체에서 {\bf 고르게\/} 뽑은
덮기 하나. 1300만 개를 늘어놓고 고르는 것이 아니라 그림 위를 한 번 걷는다.
\smallskip\item{$\bullet$} {\it 가장 값진 것은 무엇인가.} 칸마다 값을 매기고
도미노의 점수를 그 두 값의 곱이라 하면, 가장 무거운 덮기를 찾는 일은 격자
그래프의 {\it 최대 무게 완전 매칭\/}이다. 전통적으로는 헝가리안이나 블로섬
알고리즘의 몫이고 \.{examples/transversal}이 그 길을 갔지만, 여기서는 다이어그램
위의 동적 계획법 한 번으로 끝난다.

@ 판은 세 가지를 다룬다. 그냥 직사각형, 마주 보는 두 모서리를 잘라낸 것, 그리고
{\it 아즈텍 다이아몬드\/}다. 잘라낸 판은 유명한 연습문제다---흑백을 칠해 보면
같은 색 두 칸이 사라지므로 덮을 수 없고, 우리는 그것을 몇 밀리초 만에 0으로
확인한다. 아즈텍 다이아몬드는 차수 $n$일 때 덮는 방법이 정확히 $2^{n(n+1)/2}$
가지라는 것이 알려져 있어(Elkies, Kuperberg, Larsen, Propp, 1992), 우리가 센
수를 {\bf 정수끼리 딱 맞대어\/} 볼 수 있다.
@^Elkies, Noam D.@>
@^Propp, James@>

@ 아즈텍 다이아몬드에는 덤이 하나 붙는다. 고르게 뽑은 덮기를 그려 놓고 보면
네 모서리가 규칙적인 벽돌쌓기로 {\it 얼어붙고\/} 어지러운 자리는 가운데
동그라미 안에 갇힌다. 그 동그라미가 판에 내접하는 원으로 다가간다는 것이
Jockusch, Propp, Shor가 1998년에 증명한 {\it 북극권 정리\/}다. 차수 10쯤이면
눈에 보이기 시작한다---아래 그림에서 위아래 뾰족한 자리가 계단처럼 가지런한
것이 그것이다. 이 프로그램이 뽑는 표본은 $3.6\times10^{16}$가지 전체에 대해
고르므로, 그 그림은 정말로 ``무작위 덮기가 대개 어떻게 생겼는가''를 보여 준다.
@^Jockusch, William@>
@^Shor, Peter W.@>

@ 뼈대는 이렇다.
@c
package main

import (
	"flag"
	"fmt"
	"math"
	"math/big"
	"math/rand/v2"
	"os"
	"strings"

	cells "github.com/sjnam/dancing-cells"
	"github.com/sjnam/dancing-cells/zdd"
)

@<자료 구조@>
@<함수들@>

func main() {
	@<명령줄을 읽는다@>
	@<판을 만든다@>
	@<덮개 문제와 값을 짓는다@>
	@<다이어그램을 짓고 세어 본다@>
	@<공식과 맞대어 본다@>
	@<고르게 뽑은 덮기 하나를 그린다@>
	@<가장 무거운 덮기를 찾아 그린다@>
}

@ 판은 칸이 있고 없고의 격자다. |in[r][c]|가 참인 칸만 덮어야 한다.
@<자료 구조@>=
type board struct {
	rows, cols int
	in         [][]bool
	name       string
}

@ @<명령줄을 읽는다@>=
aztecOrder := flag.Int("aztec", 0, "아즈텍 다이아몬드의 차수")
cut := flag.Bool("cut", false, "마주 보는 두 모서리를 잘라낸다")
seed := flag.Uint64("seed", 20260907, "난수 씨앗")
flag.Parse()

rows, cols := 8, 8
if a := flag.Args(); len(a) == 2 {
	fmt.Sscan(a[0], &rows)
	fmt.Sscan(a[1], &cols)
}

@ 아즈텍 다이아몬드 차수 $n$은 계단 모양이다. 가운데 두 줄이 가장 길어 $2n$칸이고,
위아래로 갈수록 양쪽에서 한 칸씩 줄어든다. 칸 수는 모두 $2n(n+1)$개다.
@<판을 만든다@>=
var b board
switch {
case *aztecOrder > 0:
	n := *aztecOrder
	b = newBoard(2*n, 2*n, fmt.Sprintf("아즈텍 다이아몬드 차수 %d", n))
	for i := range 2 * n {
		k := min(i, 2*n-1-i)
		for c := n - 1 - k; c <= n+k; c++ {
			b.in[i][c] = true
		}
	}
default:
	b = newBoard(rows, cols, fmt.Sprintf("%d×%d 판", rows, cols))
	for r := range rows {
		for c := range cols {
			b.in[r][c] = true
		}
	}
	if *cut {
		b.in[0][0], b.in[rows-1][cols-1] = false, false
		b.name += " (마주 보는 두 모서리를 잘라냄)"
	}
}

@ @<함수들@>=
func newBoard(rows, cols int, name string) board {
	in := make([][]bool, rows)
	for r := range in {
		in[r] = make([]bool, cols)
	}
	return board{rows, cols, in, name}
}

func (b board) has(r, c int) bool {
	return r >= 0 && r < b.rows && c >= 0 && c < b.cols && b.in[r][c]
}

@* 문제 짓기.
항목은 칸이고 이름은 \.{\it rr\tt.\it cc\/}다. 옵션은 이웃한 두 칸을 묶은
것이니, 칸마다 오른쪽 이웃과 아래쪽 이웃 둘만 보면 빠짐없이 한 번씩 나온다.

값은 칸마다 하나씩 난수로 뽑아 두고, 도미노의 점수는 덮은 두 칸의 곱으로
삼는다. 곱으로 하는 데는 까닭이 있다---합으로 하면 어느 덮기든 점수가 판 전체의
합으로 같아져 물음이 사라진다.
@<덮개 문제와 값을 짓는다@>=
rnd := rand.New(rand.NewPCG(*seed, 0x5DEECE66D))
val := make([][]int, b.rows)
for r := range val {
	val[r] = make([]int, b.cols)
	for c := range val[r] {
		val[r][c] = 1 + rnd.IntN(9)
	}
}

var sb strings.Builder
var weight []int // 옵션 번호로 찾는 점수. weight[0]은 안 쓴다
@<항목 줄을 적는다@>
@<도미노를 놓을 수 있는 자리마다 옵션을 적는다@>

@ @<항목 줄을 적는다@>=
cellsUsed := 0
for r := range b.rows {
	for c := range b.cols {
		if b.in[r][c] {
			fmt.Fprintf(&sb, "%02d.%02d ", r, c)
			cellsUsed++
		}
	}
}
sb.WriteByte('\n')

@ @<도미노를 놓을 수 있는 자리마다 옵션을 적는다@>=
weight = append(weight, 0)
for r := range b.rows {
	for c := range b.cols {
		if !b.in[r][c] {
			continue
		}
		for _, d := range [2][2]int{{0, 1}, {1, 0}} {
			rr, cc := r+d[0], c+d[1]
			if !b.has(rr, cc) {
				continue
			}
			fmt.Fprintf(&sb, "%02d.%02d %02d.%02d\n", r, c, rr, cc)
			weight = append(weight, val[r][c]*val[rr][cc])
		}
	}
}

@* 세기.
여기서부터가 이 예제의 알맹이다. |Dance|는 답을 흘려보내지 않고 다이어그램
하나를 지어 돌려준다. |Count|는 그 위를 걷는 것이므로, 답이 몇 개든 걸리는 시간은
{\bf 그림의 크기\/}에 달렸지 답의 개수에 달리지 않았다.
@<다이어그램을 짓고 세어 본다@>=
s := zdd.New()
d := s.Dance(strings.NewReader(sb.String()))
n := d.Count()

fmt.Printf("%s: 칸 %d개, 도미노 자리 %d개\n", b.name, cellsUsed, d.Options())
fmt.Printf("덮는 방법: %s가지\n", comma(n))
fmt.Printf("  다이어그램 마디 %d개, 탐색 마디 %d개, 서명 %d개, 적중 %d번\n",
	d.Nodes(), s.Nodes(), s.Signatures(), s.Hits())
if n.Sign() == 0 {
	@<덮을 수 없는 판이면 여기서 끝낸다@>
}

@ 잘라낸 체스판이 그렇다. 흑백을 칠해 보면 마주 보는 두 모서리는 같은 색이라,
서른한 개의 도미노가 검은 칸 서른 개와 흰 칸 서른두 개를 덮어야 하는 꼴이 된다.
도미노는 언제나 두 색을 하나씩 덮으므로 그럴 수 없다. 우리 프로그램은 그 논증을
모르지만 답은 안다.
@<덮을 수 없는 판이면 여기서 끝낸다@>=
fmt.Println("덮을 수 없는 판이다.")
os.Exit(0)

@* 공식과 맞대어 보기.
아즈텍 다이아몬드는 정수끼리 맞댈 수 있다. 차수 $n$이면 정확히
$2^{n(n+1)/2}$가지이므로 |big.Int|로 지어 견주면 그만이다. 직사각형 판은
카스텔레인의 곱을 부동소수점으로 계산해 상대 오차를 보인다---|float64|가 담을
수 있는 유효숫자가 열대여섯 자리이니, 그만큼 맞으면 맞은 것이다.
@<공식과 맞대어 본다@>=
switch {
case *aztecOrder > 0:
	want := new(big.Int).Lsh(big.NewInt(1), uint(*aztecOrder*(*aztecOrder+1)/2))
	fmt.Printf("  2^(n(n+1)/2) = %s ... %s\n", comma(want), verdict(n.Cmp(want) == 0))
case !*cut:
	@<카스텔레인의 곱과 견준다@>
}

@ 곱을 그대로 계산하면 넘치므로 로그를 더한다. 네제곱근은 4로 나누는 것이 된다.
@<카스텔레인의 곱과 견준다@>=
lg := 0.0
for j := 1; j <= b.rows; j++ {
	for k := 1; k <= b.cols; k++ {
		cj := math.Cos(math.Pi * float64(j) / float64(b.rows+1))
		ck := math.Cos(math.Pi * float64(k) / float64(b.cols+1))
		lg += math.Log(4*cj*cj + 4*ck*ck)
	}
}
approx := math.Exp(lg / 4)
exact, _ := new(big.Float).SetInt(n).Float64()
fmt.Printf("  카스텔레인의 곱 = %.6e (상대오차 %.1e)\n",
	approx, math.Abs(approx-exact)/exact)

@* 물어보기.
고르게 뽑는다는 말은 말 그대로다. 다이어그램의 갈림길마다 양쪽 가지에 달린
해의 수에 비례해 동전을 던지면, 전체 $10^{16}$가지 가운데 어느 하나가 나올
확률이 모두 같아진다. 걷는 길이는 그림의 깊이뿐이다.
@<고르게 뽑은 덮기 하나를 그린다@>=
if sol, ok := d.Random(rnd); ok {
	fmt.Printf("\n고르게 뽑은 덮기 하나 (점수 %d):\n", score(d, sol, weight))
	draw(b, sol)
}

@ 그리고 가장 무거운 것. 답이 몇 개 안 되는 판이라면 그 자리에서 일일이 세어
확인한다---{\it 이 저장소는 프로그램이 검사하지 않은 것을 주장하지 않는다.}
@<가장 무거운 덮기를 찾아 그린다@>=
best, wt, ok := d.MaxWeight(weight)
if !ok {
	return
}
fmt.Printf("\n가장 무거운 덮기 (점수 %d):\n", wt)
draw(b, best)
if n.IsInt64() && n.Int64() <= 200000 {
	@<모두 훑어 최대가 맞는지 확인한다@>
}

@ @<모두 훑어 최대가 맞는지 확인한다@>=
top := 0
for sol := range d.Solutions() {
	if v := score(d, sol, weight); v > top {
		top = v
	}
}
fmt.Printf("  %s개를 모두 훑어 본 최대값 %d ... %s\n",
	comma(n), top, verdict(top == wt))

@* 그림과 잔손질.
그림은 \.{examples/partridge}에서 쓴 방법 그대로다. 칸 하나를 한 줄 높이에 두
글자 너비로 잡고, 각 줄은 그 줄 위쪽의 가로 금과 그 줄의 속을 겹쳐 찍는다.
판 밖은 조각 번호 0으로 치므로 판의 테두리가 저절로 그려지고, 아즈텍
다이아몬드의 계단 모양도 따로 손댈 것 없이 나온다.
@<함수들@>=
func draw(b board, sol []cells.Option) {
	tile := make([][]int, b.rows)
	for r := range tile {
		tile[r] = make([]int, b.cols)
	}
	for i, opt := range sol {
		for _, nm := range opt {
			var r, c int
			fmt.Sscanf(nm, "%d.%d", &r, &c)
			tile[r][c] = i + 1
		}
	}
	@<금이 어디에 있는지 정한다@>
	@<줄마다 찍는다@>
}

@ @<금이 어디에 있는지 정한다@>=
at := func(r, c int) int {
	if r < 0 || r >= b.rows || c < 0 || c >= b.cols {
		return 0
	}
	return tile[r][c]
}
hBorder := func(r, c int) bool { return at(r, c) != at(r-1, c) }
vBorder := func(r, c int) bool { return at(r, c) != at(r, c-1) }

@ 이음매에 찍을 글자는 네 방향으로 금이 뻗었는지를 네 비트로 적은 자리에 있다.
1이 오른쪽, 2가 왼쪽, 4가 아래, 8이 위다.
@<줄마다 찍는다@>=
junc := [16]rune{
	' ', '╶', '╴', '─',
	'╷', '┌', '┐', '┬',
	'╵', '└', '┘', '┴',
	'│', '├', '┤', '┼',
}
row := make([]rune, 2*b.cols+1)
for r := 0; r <= b.rows; r++ {
	for c := 0; c <= b.cols; c++ {
		k := 0
		if vBorder(r-1, c) {
			k |= 8
		}
		if vBorder(r, c) {
			k |= 4
		}
		if hBorder(r, c-1) {
			k |= 2
		}
		if hBorder(r, c) {
			k |= 1
		}
		row[2*c] = junc[k]
		if c < b.cols {
			row[2*c+1] = ' '
			if hBorder(r, c) {
				row[2*c+1] = '─'
			}
		}
	}
	fmt.Println(strings.TrimRight(string(row), " "))
}

@ 나머지는 잔손질이다. |score|는 덮기 하나의 점수를 매기는데, 다이어그램이
옵션을 번호가 아니라 이름으로 돌려주므로 이름에서 번호를 되찾는 표를 한 번
지어 둔다. |comma|는 큰 수에 세 자리마다 쉼표를 찍고, |verdict|는 맞았는지를
말한다.
@<함수들@>=
func score(d *zdd.Diagram, sol []cells.Option, weight []int) int {
	num := make(map[string]int, d.Options())
	for k := 1; k <= d.Options(); k++ {
		num[strings.Join(d.Option(k), " ")] = k
	}
	total := 0
	for _, opt := range sol {
		total += weight[num[strings.Join(opt, " ")]]
	}
	return total
}

@ @<함수들@>=
func comma(n *big.Int) string {
	s := n.String()
	var out []byte
	for i, c := range []byte(s) {
		if i > 0 && (len(s)-i)%3 == 0 {
			out = append(out, ',')
		}
		out = append(out, c)
	}
	return string(out)
}

func verdict(ok bool) string {
	if ok {
		return "맞다"
	}
	return "틀리다"
}

@* 색인.
