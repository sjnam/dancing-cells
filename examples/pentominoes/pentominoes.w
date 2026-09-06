\input kotexgweb

\def\title{펜토미노 깔기}

@s Option int
@s Reader int

@* 들어가며.
정사각형 다섯 개를 변끼리 붙여 만들 수 있는 조각은---뒤집고 돌린 것을 같다고
치면---열두 가지다. Solomon Golomb이 1953년 하버드 수학 동아리에서 이것들에
{\it 폴리오미노\/}라는 이름을 붙이고 이듬해 {\sl American Mathematical
Monthly\/}에 실으면서 널리 알려졌다. 크누스는 열두 조각에 알파벳 뒷쪽 열두 글자
$$\hbox{\tt O\quad P\quad Q\quad R\quad S\quad T\quad U\quad V\quad W\quad
X\quad Y\quad Z}$$
를 붙여 부른다. 글자 모양이 조각 모양을 닮았다.
@^Golomb, Solomon W.@>

조각 열둘의 넓이를 더하면 $12\times5=60$이니, $6\times10$이나 $5\times12$ 같은
직사각형에 빈틈없이 깔 수 있을 성싶다. 실제로 $6\times10$에는 답이 있고, 판을
돌리고 뒤집어 같아지는 것을 하나로 세면 2339가지다. 이 프로그램은 그것들을
낱낱이 그려 준다---판의 대칭까지 다른 답으로 세므로 9356가지가 나온다.

@ 정확한 덮개로 옮기는 길은 펜토미노 문제가 교과서에 실리는 까닭 그 자체다.
덮어야 할 것이 두 갈래인데 둘 다 주 항목이다.
\smallskip\item{$\bullet$} {\it 칸\/} 60개. 판의 칸마다 정확히 한 조각이 덮어야 한다.
\smallskip\item{$\bullet$} {\it 조각\/} 12개. 조각마다 정확히 한 번 놓여야 한다.
\smallskip\noindent
옵션 하나는 ``조각 \.X를 이 다섯 칸에 놓는다''는 뜻이니 항목 여섯을 품는다.
조각 하나와 칸 다섯이다. 판을 돌리고 뒤집은 자리까지 모두 옵션으로 적으면
$6\times10$ 판에서 2056개가 나온다.

@ 그 옵션 목록을 짓는 일은 이 프로그램의 몫이 아니다. 크누스의 \.{polyomino-dlx}가
조각 데이터로부터 미리 지어 둔 \.{.dlx} 파일을 그대로 읽는다. 파일 첫머리의
주석에 조각 데이터가 그대로 남아 있어, 어떤 자료에서 나온 문제인지 파일만 보면
알 수 있다.
$$
\vcenter{\halign{\tt#\hfil\cr
\char"7C\ [0-5][0-9]\cr
\char"7C\ O 00 01 02 03 04\cr
\char"7C\ P 00 01 10 11 20\cr
\quad\vdots\cr
\char"7C\ this file was created by polyomino-dlx from that data\cr}}
$$
칸 이름은 두 자리 36진수로 행과 열을 적은 것이고, 옵션 줄은 조각 글자로 시작해
칸 다섯이 뒤따른다. 그러니 |opt[0]|이 조각이고 |opt[1:]|이 그 자리다.

@ 판의 크기는 파일 이름에서 읽는다. \.{6x10.dlx}는 여섯 줄 열 칸이라는 뜻이다.
$8\times8$ 판처럼 가운데가 뚫린 것도 같은 식으로 다루어진다---뚫린 칸은 항목으로
적히지 않았으니 어느 옵션도 그것을 말하지 않고, 판에는 처음 넣어 둔 점이 그대로
남는다.
@c
package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	cells "github.com/sjnam/dancing-cells"
)

func main() {
	@<파일을 열고 판 크기를 알아낸다@>
	@<판을 비워 둔다@>
	@<답마다 판을 그린다@>
}

@ @<파일을 열고 판 크기를 알아낸다@>=
if len(os.Args) != 2 {
	log.Fatalf("usage: %s dlx-file", os.Args[0])
}
fd, err := os.Open(os.Args[1])
if err != nil {
	log.Fatal(err)
}
defer fd.Close()

dim := strings.Split(strings.Split(filepath.Base(os.Args[1]), ".")[0], "x")
nr, _ := strconv.Atoi(dim[0])
nc, _ := strconv.Atoi(dim[1])

@ 판은 한 번만 만들어 두고 답마다 다시 쓴다. 덮개는 판을 남김없이 덮으므로
지워 둘 것이 없다---덮이지 않는 칸은 애초에 판에 없는 칸뿐이고, 그 자리는
처음 넣어 둔 점으로 남아 있어야 맞다.
@<판을 비워 둔다@>=
box := make([][]string, nr)
for i := range box {
	box[i] = make([]string, nc)
	for j := range box[i] {
		box[i][j] = "."
	}
}

@ 옵션 하나가 조각 하나의 자리다. 칸 이름 두 글자를 36진수로 풀어 그 자리에
조각 글자를 적는다.
@<답마다 판을 그린다@>=
res := cells.NewXCC().Dance(fd)
i := 0
for sol := range res.Solutions {
	i++
	for _, opt := range sol {
		for _, cell := range opt[1:] {
			x, _ := strconv.ParseInt(cell[0:1], 36, 0)
			y, _ := strconv.ParseInt(cell[1:2], 36, 0)
			box[x][y] = opt[0]
		}
	}
	fmt.Printf("%d:\n", i)
	for _, row := range box {
		fmt.Println(strings.Join(row, " "))
	}
	fmt.Println()
}

@* 색인.
