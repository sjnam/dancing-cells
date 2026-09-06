\input kotexgweb

\def\title{파티지 퍼즐}

@s Option int
@s Reader int
@s Context int
@s Duration int
@s Time int
@s pos int

@* 들어가며.
캐럴 ``The Twelve Days of Christmas''는 배나무 위의 자고새 한 마리로 시작해
날마다 선물을 하나씩 늘려 간다. 1978년에 Robert Wainwright가 어떤 퍼즐에
{\it 파티지\/}(partridge, 자고새)라는 이름을 붙인 것은 그 셈이 꼭 같아서였다.
$1\times1$ 한 장, $2\times2$ 두 장, $3\times3$ 세 장, 그렇게 $n\times n$을
$n$장 준비한다.
@^Wainwright, Robert@>

넓이가 맞아떨어지는 것이 이 퍼즐의 씨앗이다.
$$1^3+2^3+\cdots+n^3=(1+2+\cdots+n)^2$$
이므로 조각들의 넓이를 다 더하면 변이 $N=n(n+1)/2$인 정사각형과 정확히 같다.
그렇다고 실제로 들어맞는다는 보장은 없어서, $n$이 일곱 이하면 해가 하나도 없고
$n=8$이 가장 작게 풀리는 차수다. 그때 판은 $36\times36$이고 해는 2332가지다.

이 프로그램은 그 해들을 찾아 상자 그림으로 그려 준다. 판 한가운데를 얼마나
비워 둘 수 있는가 하는 딸린 물음은 \.{examples/hollow}에서 따로 다룬다.

@* 다중도로 옮기기.
파티지는 이 저장소에서 |MCC| 엔진을 쓰는 유일한 예제다. 까닭은 조각이
{\it 여럿씩\/}이기 때문이다.

$k\times k$ 조각은 $k$장이다. 이것을 |XCC|로 적자면 조각마다 다른 이름을 주어야
하는데---\.{\#3a}, \.{\#3b}, \.{\#3c}처럼---그러면 똑같이 생긴 세 조각의 자리를
맞바꾼 것들이 죄다 다른 해로 세어진다. $n=8$이면 그런 헛세기가
$1!\,2!\cdots8!$배, 곧 20조 배쯤 된다.

다중도는 그것을 한마디로 말한다. 항목 \.{\#3}에 붙인 \.{3:3}은 ``이 항목은
{\bf 정확히 세 번\/} 덮여라''는 뜻이다. 조각 셋을 구별하지 않으니 맞바꾼 것은
애초에 한 가지로만 세어진다.
$$\hbox{\tt 3:3\char"7C\#3}$$

@ 항목은 두 갈래다. 조각 크기 \.{\#1}$\ldots$\.{\#n\/}은 다중도 $k{:}k$를
달고, 판의 칸 \.{\it r\tt,\it c\/}는 $N^2$개가 모두 여느 주 항목이다. 옵션
하나는 ``$t\times t$ 조각을 왼쪽 위 모서리가 $(r,c)$인 자리에 놓는다''는 뜻으로,
크기 항목 하나와 칸 항목 $t^2$개를 품는다.
@<덮개 문제를 만든다@>=
N := n * (n + 1) / 2
r, w := io.Pipe()
go func() {
	defer w.Close()
	@<항목 줄을 적는다@>
	@<놓을 수 있는 자리마다 옵션을 적는다@>
}()

@ @<항목 줄을 적는다@>=
for i := 1; i <= n; i++ {
	fmt.Fprintf(w, "%d:%d|#%d ", i, i, i)
}
for i := range N {
	for j := range N {
		fmt.Fprintf(w, "%d,%d ", i, j)
	}
}
fmt.Fprintln(w)

@ @<놓을 수 있는 자리마다 옵션을 적는다@>=
for t := 1; t <= n; t++ {
	for r := 0; r < N-t+1; r++ {
		for c := 0; c < N-t+1; c++ {
			fmt.Fprintf(w, "#%d ", t)
			for rr := 0; rr < t; rr++ {
				for cc := 0; cc < t; cc++ {
					fmt.Fprintf(w, "%d,%d ", r+rr, c+cc)
				}
			}
			fmt.Fprintln(w)
		}
	}
}

@* 뼈대.
$n=8$이면 첫 해가 나오기까지 한참 걸린다. 그래서 두 가지를 달아 둔다. 문맥에
30분짜리 시한을 두어 끝없이 돌지 않게 하고, |PulseInterval|을 켜 30초마다
맥박을 받는다. 맥박은 별도 고루틴이 받아 지금까지 밟은 마디 수와 흐른 시간을
찍어 준다---오래 도는 탐색에서 이것이 있고 없고는 마음가짐이 다르다.
@c
package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	cells "github.com/sjnam/dancing-cells"
)

func main() {
	@<차수와 시한을 정한다@>
	@<덮개 문제를 만든다@>
	@<풀면서 맥박을 받는다@>
	@<해마다 판을 그린다@>
}

@ @<차수와 시한을 정한다@>=
ctx, cancel := context.WithTimeout(context.TODO(), 30*time.Minute)
defer cancel()

n := 8
if len(os.Args) > 1 {
	if v, err := strconv.Atoi(os.Args[1]); err == nil {
		n = v
	}
}

@ @<풀면서 맥박을 받는다@>=
mcc := cells.NewMCC()
mcc.PulseInterval = 30 * time.Second
mcc = mcc.WithContext(ctx)
res := mcc.Dance(r)

start := time.Now()
go func() {
	for {
		select {
		case <-ctx.Done():
			return
		case st, ok := <-res.Heartbeat:
			if !ok {
				return
			}
			fmt.Printf("%s (%v)\n", st, time.Since(start))
		}
	}
}()

@ @<해마다 판을 그린다@>=
i := 0
for sol := range res.Solutions {
	i++
	fmt.Printf("%d:\n", i)
	@<덮개를 두 장의 표로 옮긴다@>
	@<판을 상자 그림으로 그린다@>
}

@* 덮개를 표로.
그림을 그리려면 칸마다 두 가지를 알아야 한다. 그 칸을 덮은 조각의 {\it 크기\/}와
그 조각의 {\it 신원\/}이다. 크기만으로는 안 된다---같은 크기의 두 조각이 나란히
붙어 있을 때 그 사이에 금을 그어야 하는지 알 수 없기 때문이다. 그래서 옵션을
훑으면서 조각마다 일련번호를 매겨 |tile|에 적고, 크기는 |size|에 적는다.
@<덮개를 두 장의 표로 옮긴다@>=
N := n * (n + 1) / 2
size := make([][]int, N)
tile := make([][]int, N)
for i := range size {
	size[i] = make([]int, N)
	tile[i] = make([]int, N)
}
tileID := 0
for _, opt := range sol {
	s, _ := strconv.Atoi(opt[0][1:]) // 조각 이름에서 크기를 뜯는다
	tileID++
	for _, coord := range opt[1:] {
		parts := strings.Split(coord, ",")
		r, _ := strconv.Atoi(parts[0])
		c, _ := strconv.Atoi(parts[1])
		size[r][c] = s
		tile[r][c] = tileID
	}
}

@* 상자 그림.
$36\times36$ 판을 화면에 담자면 칸 하나에 글자를 몇 개나 줄 수 있는지부터
따져야 한다. 터미널 글자는 세로가 가로의 두 배쯤 되므로, 칸 하나를
{\bf 한 줄 높이에 두 글자 너비\/}로 잡으면 대충 정사각형으로 보인다. 그래서
판 전체가 $2N+1$글자 너비에 $N+1$줄이 된다.

한 줄 높이라는 것은 가로 금을 그을 자리가 따로 없다는 뜻이다. 그래서 각 줄은
{\it 그 줄 위쪽의 가로 금\/}과 {\it 그 줄의 속\/}을 겹쳐 찍는다. 금이 없는
자리는 빈칸이 되고, 금이 있는 자리는 `\.{─}'가 된다. 이렇게 하면 $k\times k$
조각이 $(2k-1)\times k$글자로 그려져 눈에는 정사각형에 가깝다.

@ 금을 그을지 말지는 이웃한 두 칸이 같은 조각인지로 정해진다. 판 밖은 조각
번호 0으로 치므로 테두리는 저절로 금이 된다.
@<판을 상자 그림으로 그린다@>=
tileAt := func(r, c int) int {
	if r < 0 || r >= N || c < 0 || c >= N {
		return 0
	}
	return tile[r][c]
}
hBorder := func(r, c int) bool { // 칸 (r,c) 위쪽의 가로 금
	return r == 0 || r == N || tileAt(r, c) != tileAt(r-1, c)
}
vBorder := func(r, c int) bool { // 칸 (r,c) 왼쪽의 세로 금
	return c == 0 || c == N || tileAt(r, c) != tileAt(r, c-1)
}
@<조각마다 크기를 적을 자리를 고른다@>
@<줄마다 금과 숫자를 겹쳐 찍는다@>

@ 조각의 크기를 어디에 적을 것인가. 조각의 {\bf 오른쪽 아래 칸\/}에 적는다.
그 칸의 윗변은 조각의 속이라 가로 금과 부딪치지 않기 때문이다. $1\times1$
조각에는 그런 칸이 없으므로---하나뿐인 줄이 곧 위쪽 테두리다---비워 둔다.
두 자리 수는 오른쪽으로 맞추어 왼쪽 칸까지 넘어가 적는데, 그 자리도 같은 조각의
속이라 넘어가도 된다.
@<조각마다 크기를 적을 자리를 고른다@>=
type pos struct{ r, c int }
tileCells := make(map[int][]pos)
for r := range N {
	for c := range N {
		tileCells[tile[r][c]] = append(tileCells[tile[r][c]], pos{r, c})
	}
}
label := make([][]int, N)
for i := range label {
	label[i] = make([]int, N)
}
for _, cs := range tileCells {
	maxR, maxC := cs[0].r, cs[0].c
	for _, p := range cs {
		if p.r > maxR {
			maxR = p.r
		}
		if p.c > maxC {
			maxC = p.c
		}
	}
	if s := size[cs[0].r][cs[0].c]; s > 1 {
		label[maxR][maxC] = s
	}
}

@ 금이 만나는 자리에 찍을 글자는 열여섯 가지다. 위아래좌우 네 방향으로 금이
뻗었는지를 네 비트로 적으면 그것이 곧 표의 자리 번호가 된다---1은 오른쪽,
2는 왼쪽, 4는 아래, 8은 위다.
@<이음매 글자표@>=
junc := [16]rune{
	' ', '╶', '╴', '─',
	'╷', '┌', '┐', '┬',
	'╵', '└', '┘', '┴',
	'│', '├', '┤', '┼',
}

@ 줄 하나는 $2N+1$글자다. 칸 $(r,c)$는 이음매 자리 $2c$와 속 자리 $2c+1$을
차지한다.
@<줄마다 금과 숫자를 겹쳐 찍는다@>=
@<이음매 글자표@>
row := make([]rune, 2*N+1)
for r := 0; r <= N; r++ {
	for c := 0; c <= N; c++ {
		@<이음매와 그 오른쪽 속을 채운다@>
	}
	@<숫자를 겹쳐 찍는다@>
	fmt.Println(string(row))
}

@ 칸 $(r,c)$의 왼쪽 위 모서리에서 위로 뻗는 금은 윗줄 $(r-1,c)$의 세로 금이고,
아래로 뻗는 금은 이 줄의 세로 금이다. 좌우로 뻗는 금은 왼쪽 칸과 이 칸의
가로 금이다.
@<이음매와 그 오른쪽 속을 채운다@>=
b := 0
if r > 0 && vBorder(r-1, c) {
	b |= 8
}
if r < N && vBorder(r, c) {
	b |= 4
}
if c > 0 && hBorder(r, c-1) {
	b |= 2
}
if c < N && hBorder(r, c) {
	b |= 1
}
row[2*c] = junc[b]

if c < N {
	if hBorder(r, c) {
		row[2*c+1] = '─'
	} else {
		row[2*c+1] = ' '
	}
}

@ 마지막으로 숫자를 얹는다. 마지막 자릿수가 칸의 속 자리에 오도록 오른쪽으로
맞추고, 자릿수가 더 있으면 왼쪽으로 넘어간다. 맨 아래 테두리 줄에는 적을 것이
없다.
@<숫자를 겹쳐 찍는다@>=
if r < N {
	for c := 0; c < N; c++ {
		if label[r][c] > 0 {
			ds := strconv.Itoa(label[r][c])
			for i, p := len(ds)-1, 2*c+1; i >= 0; i, p = i-1, p-1 {
				row[p] = rune(ds[i])
			}
		}
	}
}

@* 색인.
