\input kotexgweb

\def\title{낱말 찾기 퍼즐 짓기}

@s Option int
@s Reader int
@s Rand int

@* 들어가며.
낱말 찾기(word search)는 글자가 빼곡한 네모판에서 정해진 낱말들을 찾아내는
놀이다. 낱말은 가로로도 세로로도 비스듬히도 놓이고, 거꾸로 적히기도 한다. 푸는
쪽은 눈으로 훑으면 되지만, {\bf 짓는\/} 쪽은 만만치 않다. 낱말들이 서로 겹치되
겹치는 자리에서는 글자가 같아야 하고, 판을 벗어나서도 안 된다.

이 프로그램은 낱말 목록과 판 크기를 받아 그런 판을 지어 준다. 짓는 일이 바로
색이 있는 정확한 덮개 문제다.

@ 얼룩말 퍼즐이 색을 ``값''으로 썼다면 여기서는 색이 곧 {\bf 글자\/}다.
\smallskip\item{$\bullet$} {\it 주 항목\/}은 낱말이다. 낱말마다 정확히 한 번
놓여야 한다.
\smallskip\item{$\bullet$} {\it 부 항목\/}은 판의 칸이다. 칸은 비어 있어도
되고---그런 자리는 나중에 아무 글자로 채운다---여러 낱말이 함께 지나가도 되지만,
지나가는 낱말들이 그 칸에 적을 글자에 {\bf 합의해야\/} 한다.
\smallskip\noindent
그것이 색이 하는 일 그대로다. 옵션 하나는 ``낱말 \.{W}를 이 자리들에 이렇게
놓는다''는 뜻으로, 낱말 항목 하나와 색 붙은 칸 항목 여럿을 품는다.
$$\hbox{\tt W\quad\it rc\tt:W$_0$\quad\it rc\tt:W$_1$\quad$\ldots$}$$
낱말 둘이 한 칸에서 교차하면 둘 다 그 칸을 말하게 되는데, 글자가 다르면 색이
어긋나 그 조합은 애초에 만들어지지 않는다. 교차 검사를 따로 짤 일이 없다.

@ 놓는 방향은 여덟이다. 가로, 세로, 오른쪽 위로 비스듬히, 오른쪽 아래로
비스듬히---넷이고, 낱말을 거꾸로 적으면 그 넷의 반대 방향이 나와 여덟이 된다.
그래서 낱말마다 바로 쓴 것과 뒤집어 쓴 것 두 벌을 놓고, 각각에 대해 판의 모든
시작 칸과 네 방향을 훑는다.

칸 이름은 행과 열을 한 글자씩 16진수로 적는다. 그래서 판은 한 변이 열여섯 칸을
넘을 수 없다.

@ 뼈대는 셋이다. 명령줄을 읽고, 덮개 문제를 만들어 풀고, 답마다 판을 그린다.
@c
package main

import (
	"fmt"
	"io"
	"log"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"unicode/utf8"

	cells "github.com/sjnam/dancing-cells"
)

func main() {
	@<명령줄을 읽는다@>
	@<덮개 문제를 만든다@>
	@<답마다 판을 그린다@>
}

@ 받는 것은 낱말 파일과 판의 너비, 높이다. 낱말은 빈칸으로 나뉘어 있기만 하면
되므로 줄바꿈으로 적든 한 줄에 몰아 적든 상관없다.
@<명령줄을 읽는다@>=
args := os.Args
if len(args) != 4 {
	log.Fatalf("usage: %s input-file wd ht\n", args[0])
}

wd, _ := strconv.Atoi(args[2])
ht, _ := strconv.Atoi(args[3])
buf, err := os.ReadFile(args[1])
if err != nil {
	log.Fatal(err)
}
words := strings.Fields(string(buf))

@ @<덮개 문제를 만든다@>=
pr, pw := io.Pipe()
go func() {
	defer func() { _ = pw.Close() }()
	@<항목 줄을 적는다@>
	@<옵션을 적는다@>
}()

@ 항목 줄에는 낱말을 먼저 적고, `\.{\char"7C}' 뒤에 칸을 모두 적는다. 낱말이
주 항목이고 칸이 부 항목이다.
@<항목 줄을 적는다@>=
fmt.Fprint(pw, strings.Join(words, " "))
fmt.Fprint(pw, " | ")
for i := range ht {
	for j := range wd {
		fmt.Fprintf(pw, "%x%x ", i, j)
	}
}
fmt.Fprintln(pw)

@ 옵션은 낱말마다, 바로 쓴 것과 뒤집어 쓴 것마다, 시작 칸마다, 방향 넷마다
하나씩이다. 낱말이 한글이면 바이트가 아니라 글자 수로 세어야 하므로
|utf8.RuneCountInString|과 |[]rune|을 쓴다.
@<옵션을 적는다@>=
for _, word := range words {
	wlen := utf8.RuneCountInString(word)
	runew := []rune(word)
	@<낱말을 뒤집어 |rev|에 담는다@>
	for _, a := range [][]rune{runew, rev} {
		for r := range ht {
			for c := range wd {
				@<칸 |(r,c)|에서 시작하는 네 방향을 적는다@>
			}
		}
	}
}

@ @<낱말을 뒤집어 |rev|에 담는다@>=
rev := make([]rune, wlen)
for i, ch := range runew {
	rev[wlen-1-i] = ch
}

@ 네 방향이 저마다 판을 벗어나지 않는지 살핀다. 가로는 오른쪽으로, 세로는
아래로, 그리고 비스듬한 둘은 왼쪽 아래와 오른쪽 아래로 간다.
@<칸 |(r,c)|에서 시작하는 네 방향을 적는다@>=
if c+wlen <= wd { // 가로
	fmt.Fprintf(pw, "%s ", word)
	for i := range wlen {
		fmt.Fprintf(pw, "%x%x:%c ", r, c+i, a[i])
	}
	fmt.Fprintln(pw)
}
if r+wlen <= ht { // 세로
	fmt.Fprintf(pw, "%s ", word)
	for i := range wlen {
		fmt.Fprintf(pw, "%x%x:%c ", r+i, c, a[i])
	}
	fmt.Fprintln(pw)
}
if r+wlen <= ht && c-wlen+1 >= 0 { // 왼쪽 아래로
	fmt.Fprintf(pw, "%s ", word)
	for i := range wlen {
		fmt.Fprintf(pw, "%x%x:%c ", r+i, c-i, a[i])
	}
	fmt.Fprintln(pw)
}
if r+wlen <= ht && c+wlen <= wd { // 오른쪽 아래로
	fmt.Fprintf(pw, "%s ", word)
	for i := range wlen {
		fmt.Fprintf(pw, "%x%x:%c ", r+i, c+i, a[i])
	}
	fmt.Fprintln(pw)
}

@ 덮개 하나가 판 하나다. 낱말을 다 놓고 나면 빈칸이 남는데, 그 자리를 아무
글자로 채우는 것이 낱말 찾기의 마지막 손질이다. 채움 글자는 난수로 뽑으므로
같은 낱말 배치라도 돌릴 때마다 판이 달라진다.
@<답마다 판을 그린다@>=
res := cells.NewXCC().Dance(pr)
i := 0
for sol := range res.Solutions {
	i++
	fmt.Printf("%d:\n", i)
	@<덮개 |sol|을 판으로 그린다@>
	fmt.Println()
}

@ 옵션의 첫 이름은 낱말이니 건너뛰고, 나머지 \.{\it rc\tt:\it x} 꼴을 갈라
그 칸에 그 글자를 적는다.
@<덮개 |sol|을 판으로 그린다@>=
board := make([][]rune, ht)
for i := 0; i < ht; i++ {
	board[i] = make([]rune, wd)
}
for _, opt := range sol {
	for _, pos := range opt[1:] {
		chr := strings.Split(pos, ":")
		@<칸 이름 |chr[0]|을 풀어 |x|와 |y|를 얻는다@>
		board[x][y], _ = utf8.DecodeRuneInString(chr[1])
	}
}
@<빈칸을 채워 판을 찍는다@>

@ @<칸 이름 |chr[0]|을 풀어 |x|와 |y|를 얻는다@>=
var v [2]int
for i := 0; i < 2; i++ {
	if ch := chr[0][i]; ch < '0'+10 {
		v[i] = int(ch - '0')
	} else if ch >= 'a' {
		v[i] = int(ch - 'a' + 10)
	}
}
x, y := v[0], v[1]

@ 채움 글자를 어느 글자판에서 뽑을지는 놓인 낱말을 보고 정한다. 첫 줄에서 처음
만나는 글자가 한 바이트면 로마자 퍼즐로 보아 \.A$\ldots$\.Z에서 뽑고, 아니면
한글 퍼즐로 보아 가$\ldots$힣에서 뽑는다. 로마자일 때만 글자 사이에 빈칸을 두는데,
한글은 글자가 이미 넓어 그냥 붙여 찍는 편이 낫기 때문이다.
@<빈칸을 채워 판을 찍는다@>=
ascii := true
for i := 0; i < wd; i++ {
	if board[0][i] != 0 {
		ascii = utf8.RuneLen(board[0][i]) <= 1
		break
	}
}

for i := 0; i < ht; i++ {
	for j := 0; j < wd; j++ {
		if board[i][j] == 0 {
			if ascii {
				board[i][j] = rune('A' + rand.Intn(26))
			} else {
				board[i][j] = rune('가' + rand.Intn(int('힣'-'가')))
			}
		}
		fmt.Printf("%c", board[i][j])
		if ascii {
			fmt.Print(" ")
		}
	}
	fmt.Println()
}

@* 색인.
