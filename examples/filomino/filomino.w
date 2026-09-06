\input kotexgweb

\def\title{필로미노}

@s Option int
@s Reader int

@* 들어가며.
{\it 필로미노\/}(Fillomino)는 일본의 퍼즐 잡지 {\sl 니코리\/}가 1994년에 선보인
격자 퍼즐이다. 규칙은 셋뿐이다.
\smallskip\item{$\bullet$} 판을 조각(폴리오미노)으로 남김없이 나눈다.
\smallskip\item{$\bullet$} 칸이 $n$개인 조각에는 그 칸마다 $n$을 적는다.
\smallskip\item{$\bullet$} 크기가 같은 두 조각은 변을 맞대지 못한다. 모서리로만
닿는 것은 괜찮다.
\smallskip\noindent
문제로 주어지는 것은 몇몇 칸의 수뿐이고, 나머지는 풀어서 채운다. 셋째 규칙이
이 퍼즐의 묘미다. 그것이 없으면 조각을 아무렇게나 잘라도 되므로 답이 헤아릴 수
없이 많아진다.

@ 이 프로그램이 읽는 \.{.dlx} 파일은 \.{filomino-dlx}가 문제 격자에서 미리
지어 둔 것이다. 파일 첫머리 주석에 원래 문제가 그대로 남아 있다.
$$
\vcenter{\halign{\tt#\hfil\cr
\char"7C\ filomino-dlx:\cr
\char"7C\ ..4.....\cr
\char"7C\ .32..26.\cr
\quad\vdots\cr}}
$$
옵션 하나가 조각 하나다. 이를테면
$$\hbox{\tt 12 13 v212 h212 v222 v213 h214 v223}$$
은 ``칸 \.{12}과 \.{13}을 묶어 크기 2짜리 조각을 만든다''는 뜻이다.

@ 이름이 두 갈래인 것이 이 인코딩의 요령이다. 두 글자짜리 \.{12}는 {\it 칸\/}
이고 주 항목이다---판의 칸은 저마다 정확히 한 조각에 들어가야 한다. 세 글자
넘는 \.{v212}, \.{h212} 따위는 조각의 {\it 테두리 변\/}이고 부 항목인데,
이름에 조각의 크기가 박혀 있다.

셋째 규칙이 여기서 저절로 지켜진다. 크기가 같은 두 조각이 변을 맞대면 그
변에 붙은 같은 이름을 둘이 함께 달라고 하는 꼴이 되는데, 부 항목은 많아야 한 번
덮이므로 그런 덮개는 애초에 만들어지지 않는다. 판 가장자리의 변은 이웃이 있을
수 없으니 아예 적히지 않는다---그래서 구석 칸 하나짜리 조각의 옵션은
$$\hbox{\tt 00 h101 v110}$$
처럼 변이 넷이 아니라 둘뿐이다.

@ 남은 일은 덮개 하나를 받아 판에 수를 적어 넣는 것뿐이다. 옵션에서 두 글자짜리
이름만 세면 그것이 곧 조각의 크기이므로, 그 수를 그 칸들에 적으면 된다.
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

@<함수들@>

func main() {
	@<파일을 열고 판 크기를 알아낸다@>
	@<첫 덮개로 판을 채운다@>
	@<판을 찍는다@>
}

@ 칸 이름은 행과 열을 한 글자씩 16진수로 적은 것이다.
@<함수들@>=
func digit(b byte) int {
	r := b
	if r >= 'a' && r <= 'f' {
		r = r - 'a' + 10
	} else {
		r = r - '0'
	}

	return int(r)
}

@ 판의 크기는 펜토미노 예제와 마찬가지로 파일 이름에서 읽는다.
\.{8x8.filomino.dlx}는 여덟 줄 여덟 칸이다.
@<파일을 열고 판 크기를 알아낸다@>=
args := os.Args
if len(args) != 2 {
	log.Fatalf("%s dlx-file\n", args[0])
}

dlxInput := args[1]
fd, err := os.Open(dlxInput)
if err != nil {
	log.Fatal(err)
}

dlxInput = filepath.Base(dlxInput)
name := strings.Split(dlxInput, ".")
dimen := strings.Split(name[0], "x")
nr, _ := strconv.Atoi(dimen[0])
nc, _ := strconv.Atoi(dimen[1])

@ 잘 만든 필로미노 문제는 답이 하나뿐이므로 첫 덮개만 받아 오면 된다. 나머지
옵션 이름---테두리 변---은 여기서 볼 일이 없다.
@<첫 덮개로 판을 채운다@>=
xc := cells.NewXCC()
res := xc.Dance(fd)

box := make([][]int, nr)
for i := range box {
	box[i] = make([]int, nc)
}

for _, opt := range <-res.Solutions {
	n := 0
	var coor [][2]int
	for _, c := range opt {
		if len(c) == 2 {
			n++
			coor = append(coor, [2]int{digit(c[0]), digit(c[1])})
		}
	}
	for i := 0; i < n; i++ {
		box[coor[i][0]][coor[i][1]] = n
	}
}

@ @<판을 찍는다@>=
for j := range nr {
	for k := range nc {
		fmt.Printf("%d ", box[j][k])
	}
	fmt.Println()
}

@* 색인.
