\input kotexgweb

\def\title{여덟 왕비}

@s Option int
@s Reader int

@* 들어가며.
1848년에 Max Bezzel이 체스 잡지에 물음 하나를 실었다. 여덟 왕비를 체스판에
서로 잡히지 않게 놓을 수 있는가? 왕비는 가로세로와 두 대각선으로 얼마든지
멀리 가므로, 여덟이 서로 손대지 않으려면 한 줄에 하나, 한 칸에 하나, 한
대각선에 많아야 하나여야 한다. 두 해 뒤 Franz Nauck이 답이 92가지임을 알렸고,
가우스도 이 문제를 붙들고 한동안 씨름했다.
@^Bezzel, Max@>
@^Nauck, Franz@>
@^Gauss, Carl Friedrich@>

이 프로그램은 그것을 $n$까지 늘려, 답을 하나씩 판으로 그려 준다.

@ 정확한 덮개로 옮기면 왕비 문제의 속살이 드러난다. 덮어야 할 것이 네 갈래인데,
그 성질이 둘로 갈린다.

{\it 가로줄\/}과 {\it 세로줄\/}은 저마다 {\bf 꼭 한 번\/} 덮여야 한다. 왕비가
$n$개이고 줄이 $n$개이니 비둘기집이 딱 맞아떨어진다. 그러니 이 둘은 주 항목이다.

{\it 대각선\/}은 다르다. 대각선은 $2n-1$개씩 두 갈래인데 왕비는 $n$개뿐이니
대부분의 대각선은 비어 있어야 한다. ``많아야 하나''는 정확한 덮개의 말로 하면
{\bf 부 항목\/}이다. 부 항목은 덮이지 않아도 되고, 덮이더라도 색만 맞으면
여럿이 함께 덮을 수 있다. 여기서는 색을 쓰지 않으므로 ``많아야 하나''가 그대로
나온다.

이 갈림이 이 예제의 요점이다. 주 항목과 부 항목의 차이를 이보다 또렷하게
보여 주는 문제는 드물다.

@ 그러니 칸 $(j,k)$에 왕비를 놓는 옵션은 항목 넷을 품는다. 가로줄 \.{r\it j},
세로줄 \.{c\it k}, 그리고 두 대각선 \.{a\it(j+k)}와 \.{b\it(n-1-j+k)}이다.
$$\hbox{\tt r\it j\quad\tt c\it k\quad\tt a\it(j+k)\quad\tt b\it(n-1-j+k)}$$
다만 대각선 이름 가운데 둘은 아예 적지 않는다. 판의 두 모서리를 지나는
대각선은 칸이 하나뿐이라 부딪칠 상대가 없으니, 항목으로 둘 까닭이 없다.
그것이 아래에서 |t != 0 && t < nn|을 살피는 까닭이다.

@ 항목 이름은 두 글자로 맞춘다. 갈래를 나타내는 글자 하나에 번호 한 글자다.
번호를 한 글자에 담으려면 열 개의 숫자로는 모자라니 소문자와 대문자까지 끌어
쓴다---$0$부터 $9$까지는 숫자, 10부터 35까지는 \.a부터 \.z, 36부터 61까지는
\.A부터 \.Z다. 대각선 번호가 $2n-3$까지 가므로 이 62자리로 $n\le32$까지 담긴다.
@<함수들@>=
func encode(x int) byte {
	if x < 10 {
		return byte('0') + byte(x)
	} else if x < 36 {
		return byte('a') + byte(x) - 10
	} else {
		return byte('A') + byte(x) - 36
	}
}

@ 이제 재미있는 대목이다. 항목 줄에 이름을 적는 {\bf 차례\/}가 푸는 속도를
바꾼다. 엔진은 남은 옵션이 가장 적은 항목을 골라 가지를 치는데, 같은 수라면
{\it 먼저 적힌\/} 항목을 고른다. 그러니 항목 줄의 차례가 곧 동점일 때의
우선순위다.

왕비 문제에서는 판 가운데 줄이 어렵다. 가운데 칸일수록 대각선을 많이 지나
남을 더 옥죄기 때문이다. 어려운 것부터 손대는 편이 나으므로, 가로세로 이름을
$0,1,2,\ldots$가 아니라 {\bf 가운데서 바깥으로\/} 적는다. $n=8$이면
$$4,\;3,\;5,\;2,\;6,\;1,\;7,\;0$$
차례다. 아래 셈이 그 수열을 만든다---짝수 번째는 $n+j$, 홀수 번째는 $n-1-j$를
반으로 접는다.
@<항목 줄을 적는다@>=
for j := range n {
	t := n + j
	if j&1 != 0 {
		t = n - 1 - j
	}
	t = t >> 1
	fmt.Fprintf(w, "r%c c%c ", encode(t), encode(t))
}
fmt.Fprint(w, "|")
for j := 1; j < nn; j++ {
	fmt.Fprintf(w, " a%c b%c", encode(j), encode(j))
}
fmt.Fprintln(w)

@ 뼈대는 셋으로 나뉜다. 명령줄을 읽고, 문제를 만들어 풀고, 답마다 판을 그린다.
@c
package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"strconv"

	cells "github.com/sjnam/dancing-cells"
)

@<함수들@>

func main() {
	@<명령줄을 읽는다@>
	@<덮개 문제를 만든다@>
	@<답마다 판을 그린다@>
}

@ @<명령줄을 읽는다@>=
args := os.Args
if len(args) != 2 {
	fmt.Printf("usage: %s n\n", args[0])
	return
}
n, _ := strconv.Atoi(args[1])

@ 문제는 파이프에 곧바로 적어 내린다. 대각선의 수 |nn|이 62를 넘으면 이름을 한
글자에 담을 수 없으니 거기서 멈춘다.
@<덮개 문제를 만든다@>=
nn := n + n - 2
if nn > 62 {
	log.Fatal("Sorry , I can't currently handle n>32!")
}
r, w := io.Pipe()
go func() {
	defer func() { _ = w.Close() }()
	@<항목 줄을 적는다@>
	@<옵션을 적는다@>
}()

@ 옵션은 칸마다 하나씩, 모두 $n^2$개다.
@<옵션을 적는다@>=
for j := range n {
	for k := 0; k < n; k++ {
		fmt.Fprintf(w, "r%c c%c", encode(j), encode(k))
		t := j + k
		if t != 0 && t < nn {
			fmt.Fprintf(w, " a%c", encode(t))
		}
		t = n - 1 - j + k
		if t != 0 && t < nn {
			fmt.Fprintf(w, " b%c", encode(t))
		}
		fmt.Fprintln(w)
	}
}

@ 덮개 하나가 왕비 $n$개의 자리다. 옵션에서 \.r로 시작하는 이름과 \.c로
시작하는 이름을 찾아 그 칸에 왕비를 세운다. 번호는 한 글자이므로 32진수로 읽으면
그만이다. 둘을 다 찾았으면 남은 이름은 대각선이니 더 볼 것 없이 빠져나온다.
@<답마다 판을 그린다@>=
res := cells.NewXCC().Dance(r)
board := make([][]string, n)
for r := range n {
	board[r] = make([]string, n)
}
i := 0
for solution := range res.Solutions {
	i++
	@<판을 비우고 왕비를 세운다@>
	@<판을 찍는다@>
}

@ @<판을 비우고 왕비를 세운다@>=
for r := 0; r < n; r++ {
	for c := 0; c < n; c++ {
		board[r][c] = "."
	}
}
for _, opt := range solution {
	var r, c int64
	found := 0
	for _, rc := range opt {
		switch t := rc[0]; t {
		case 'r':
			r, _ = strconv.ParseInt(rc[1:], 32, 0)
			found++
		case 'c':
			c, _ = strconv.ParseInt(rc[1:], 32, 0)
			found++
		}
		if found == 2 {
			break
		}
	}
	board[r][c] = "Q"
}

@ @<판을 찍는다@>=
fmt.Printf("%d:\n", i)
for r := range n {
	for c := range n {
		fmt.Printf("%s ", board[r][c])
	}
	fmt.Println()
}
fmt.Println()

@* 색인.
