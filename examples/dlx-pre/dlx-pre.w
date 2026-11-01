\input kotexgweb
@s Writer int
\datethis

\def\title{정확한 덮개 앞손질}

@* 들어가며.
이 프로그램은 커누스가 TAOCP 7.2.2.1절을 쓰려고 채비하면서 스스로 배우려고 지은
``정확한 덮개 풀개'' 연작의 하나다. 그는 여러 방식이 실제로 어떻게 도는지 알고
싶어서, 서로 맞바꿔 쓸 수 있는 프로그램을 여럿 두고 실험했다.

{\mc DLX-PRE}는 정확한 덮개 문제를 푸는 대신 {\it 앞손질\/}을 한다. 표준 입력으로
들어오는 문제를 표준 출력으로 나가는 같은 값의 문제로 바꾸어 놓되, 없어도 되는
옵션과 항목을 걷어낸다.

@ 입출력 형식은 {\mc DLX1}의 것을 그대로 쓴다. 그 설명을 옮기면 이렇다.

$0$과 $1$로 된 행렬이 주어지는데, 그 항목 가운데 얼마는 ``주 항목''이고 나머지는
``부 항목''이다. 어떤 옵션이든 주 항목 가운데 적어도 하나에서 $1$을 갖는다. 문제는
옵션의 부분집합 가운데 그 합이 (i)~모든 주 항목에서 {\it 정확히\/}~$1$이고,
(ii)~모든 부 항목에서 {\it 많아야\/}~$1$인 것을 모두 찾는 것이다.

대개 아주 성긴 이 행렬을 표준 입력에 이렇게 적는다.
\smallskip\item{$\bullet$} 항목마다 한 자에서 여덟 자 사이의 이름을 붙인다.
빈칸이 아닌 ASCII 글자면 무엇이든 되지만 `\.{:}'와 `\.{\char"7C}'는 안 된다.
\smallskip\item{$\bullet$} 입력의 첫 줄에는 주 항목의 이름을 빈칸으로 나누어 모두
적고, `\.{\char"7C}'를 적고, 나머지 항목의 이름을 적는다. (모두 주 항목이면
`\.{\char"7C}'는 없어도 된다.)
\smallskip\item{$\bullet$} 그다음 줄들이 옵션인데, $1$이 놓인 항목의 이름을 늘어놓는다.
\smallskip\item{$\bullet$} 그 밖에 ``주석'' 줄을 아무 데나 끼울 수 있다.
`\.{\char"7C}'로 시작하는 줄이 그것인데, 이 프로그램은 그냥 지나친다.
파일로 갈무리해 둘 때 쓸모가 많다.
\smallskip\noindent
이 연작의 뒤쪽 프로그램들은 아껴 둔 글자 `\.{:}'와 `\.{\char"7C}'를 더 써서 더
일반적인 문제를 다룬다.

@ 이를테면 행렬
$$\pmatrix{0&0&1&0&1&1&0\cr 1&0&0&1&0&0&1\cr 0&1&1&0&0&1&0\cr
1&0&0&1&0&0&0\cr 0&1&0&0&0&0&1\cr 0&0&0&1&1&0&1\cr}$$
을 보자. 커누스의 원래 논문에 (3)으로 나온 것이다. 항목의 이름을 \.A, \.B, \.C,
\.D, \.E, \.F,~\.G라 하고 앞의 다섯을 주 항목, 뒤의 둘을 부 항목이라 하면 이렇게
적을 수 있다.
$$
\vcenter{\halign{\tt#\cr
\char"7C\ A simple example\cr
A B C D E \char"7C\ F G\cr
C E F\cr
A D G\cr
B C F\cr
A D\cr
B G\cr
D E G\cr}}
$$
(항목 이름도 옵션도 아무 차례로나 적을 수 있으니 적는 길은 이 밖에도 많다.)
답은 \.{A D}와 \.{E F C}와 \.{B G} 셋으로 이루어진 것 하나뿐이다.

@ {\mc DLX-PRE}는 이것을 확 줄인다. 먼저 \.A를 품은 옵션은 모두 \.D도 품는다는
것을 알아챈다. 그러니 항목 \.D를 행렬에서 걷어낼 수 있고, 옵션 \.{D E G}도
걷어낼 수 있다. 마찬가지로 항목 \.F를 걷어내고, 이어서 항목 \.C와 옵션 \.{B C}를
걷어낸다. 이제 \.G와 옵션 \.{A G}도 걷어낼 수 있다. 남는 것은 주 항목 \.A, \.B,
\.E 셋과 홑 옵션 \.A, \.B, \.E 셋뿐인, 시시한 문제다.

@ 또 {\mc DLX2}는 {\mc DLX1}에 ``색 다루기''를 더한 것이다. 주 항목이 아닌 항목에
``색''을 매긴 옵션은, 그 항목에 같은 색을 매기지 않은 옵션을 모두 물리친다.
하지만 주 항목이 아닌 항목의 색이 서로 맞는 옵션은 몇이든 함께 쓸 수 있다.
(앞의 형편은 옵션마다 다른 색을 매긴 특별한 경우다.)

입력 형식도 늘어난다. \.{xx}가 주 항목이 아닌 항목의 이름이면, 옵션에
\.{xx:a} 꼴을 적을 수 있다. 여기서 \.a는 색을 뜻하는 글자 하나다.

이를테면 이런 것이 간단한 시험감이다.
$$
\vcenter{\halign{\tt#\cr
\char"7C\ A simple example of color controls\cr
A B C \char"7C\ X Y\cr
A B X:0 Y:0\cr
A C X:1 Y:1\cr
X:0 Y:1\cr
B X:1\cr
C Y:1\cr}}
$$
옵션 \.{X:0 Y:1}은 주 항목이 하나도 없으니 곧바로 지워진다. 앞손질은 옵션
\.{A B X:0 Y:0}도 지운다. 그 옵션을 쓰면 항목 \.C를 덮을 길이 없어지기 때문이다.
그러면 항목 \.C도, 옵션 \.{C Y:1}도 없앨 수 있다.

@ 이 보기들이 말해 주듯, 줄여 놓은 출력은 원래 것과 딴판일 수 있다. 답의 개수는
같지만, 줄인 옵션만 들여다보아서는 원래 문제를 실제로 어떻게 풀지 알 길이 없다.
(실제로 한 손질을 거꾸로 되짚지 않는 한 그렇다.)

커누스의 {\mc SAT} 풀개에 딸린 앞손질에는 {\mc ERP}라는 짝이 있어서, 손질한 문제의
답을 원래 문제의 답으로 되돌려 주었다. {\mc DLX-PRE}에는 그런 것이 없다. 그렇지만
아래의 |showOrigNos| 선택항을 쓰면---이를테면 \.{v9}라 적고 돌리면---원래 옵션 가운데
어느 것이 답인지 알아낼 수 있다. 줄인 문제를 푸는 옵션의 집합이 곧 원래 문제를 푸는
옵션의 집합이고, 주석으로 찍히는 번호가 그 사이의 대응을 말해 준다.

이를테면 첫 문제를 \.{v9}로 돌리면 이렇게 나온다.
$$\vcenter{\halign{\tt#\cr
\ A B E\cr
\ A\cr
\char"7C\ (from 4)\cr
\ B\cr
\char"7C\ (from 5)\cr
\ E\cr
\char"7C\ (from 1)\cr
}}$$
둘째 문제도 비슷한데 이만큼 간단하지는 않다.
$$\vcenter{\halign{\tt#\cr
\ A B \char"7C\ X Y\cr
\ A X:1 Y:1\cr
\char"7C\ (from 2)\cr
\ B X:1\cr
\char"7C\ (from 3)\cr
}}$$

@ 아래 코드는 위의 설명과 마찬가지로 {\mc DLX2}에서 조금만 고쳐 베낀 것이다.

이 프로그램은 일을 마치고 나서 걸린 시간을 ``mem'' 단위로 알린다. 한 mem은 예순네
자리 낱말을 한 번 짚는 것을 뜻한다. (알리는 값에는 입력을 새기거나 출력을 꾸미는
데 드는 시간과 자리는 들어가지 않는다.)

\CEE/에서는 쉼표 연산자를 써서 |o,x=y[i]|처럼 셈과 계산을 한 줄에 얹는다.
\GO/에는 쉼표 연산자가 없으니, 값 하나를 셈하는 자리에서는 |mems++|를 앞에 붙이고,
반복문의 뒤처리처럼 식 자리에서 세야 할 때는 |mems, p = mems+1, nd[p].down|이라는
여럿 대입을 쓴다. 그래서 mem 수가 원본과 한 자리도 다르지 않다.

@ 이것은 커누스의 \.{CWEB} 프로그램 \pdfURL{\.{dlx-pre.w}}%
{https://www-cs-faculty.stanford.edu/\TILDE/knuth/programs/dlx-pre.w}를
\.{GWEB}으로 옮긴 것이다. 원본의 머리글 \.{Last-Modified}는
\.{Thu, 17 Aug 2023 02:32:32 GMT}다.

@ 큰 얼개는 이렇다.

@c
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
)

@<상수@>@;
@<자료형@>@;
@<전역 변수@>@;
@<함수들@>@;

func main() {
	@<지역 변수@>@;
	@<명령줄을 처리한다@>@;
	@<항목 이름을 읽어 들인다@>@;
	@<옵션을 읽어 들인다@>@;
	if vbose&showBasics != 0 {
		@<입력이 잘 끝났음을 알린다@>@;
	}
	if vbose&showTots != 0 {
		@<항목별 길이를 알린다@>@;
	}
	imems, mems = mems, 0
	@<문제를 줄인다@>@;
finish:
	@<줄인 문제를 내놓는다@>@;
	if vbose&showTots != 0 {
		@<항목별 길이를 알린다@>@;
	}
allDone:
	if vbose&showBasics != 0 {
		@<몇 개나 줄였는지 알린다@>@;
	}
	out.Flush()
}

@ 표준 입력과 표준 출력은 버퍼에 담아 둔다. 옵션이 수십만 개인 문제도 있으니
줄마다 시스템을 부를 수는 없다.

@<전역 변수@>=
var (
	in  = bufio.NewReaderSize(os.Stdin, 1<<16)
	out = bufio.NewWriterSize(os.Stdout, 1<<16)
)

@ @<상수@>=
const (
	maxItms  = 100000   // 항목은 많아야 이만큼
	maxNodes = 10000000 // 행렬의 $0$ 아닌 원소는 많아야 이만큼
	bufsize  = 9*maxItms + 3 // 항목 이름을 다 담을 만큼 넉넉한 버퍼
	root     = 0 // |cl[root]|가 아직 정해지지 않은 항목들로 들어가는 문이다
)

@ @<지역 변수@>=
var c, cc, dd, i, j, k, p, pp, q, qq, r, rr, rrr, t, uu, x, nn int

@* 명령줄.
얼마나 알릴지, 그리고 알고리즘의 몇 가지 성질을 명령줄 선택항으로 고를 수 있다.
\smallskip\item{$\bullet$}
`\.v$\langle\,$정수$\,\rangle$'는 |showChoices| 따위의 이진 부호로 주는데,
표준 오류에 낼 여러 가지 수다스러운 출력을 켜고 끈다.
\item{$\bullet$}
`\.d$\langle\,$정수$\,\rangle$'는 |delta|를 정한다. 앞선 보고 뒤로 mem이 대략
|delta|만큼 쌓일 때마다 표준 오류에 진행 상황을 알린다. (기본값 $10^{10}$)
\item{$\bullet$}
`\.t$\langle\,$양의 정수$\,\rangle$'는 옵션 걷어내기를 몇 판이나 되풀이할지를 정한다.
\item{$\bullet$}
`\.T$\langle\,$정수$\,\rangle$'는 |timeout|을 정한다. 어떤 항목에 들어설 때
|mems > timeout|이면 그 자리에서 그만두는데, 출력이 온전한 것은 그대로다.

@<상수@>=
const (
	showBasics   = 1    // 기본 통계. 이것이 기본값이다
	showChoices  = 2    // 두루 기록을 남긴다
	showDetails  = 4    // 더 자세한 설명
	showOrigNos  = 8    // 내놓는 옵션이 어디서 왔는지 밝힌다
	showTots     = 512  // 처음과 끝에 항목별 길이를 알린다
	showWarnings = 1024 // 주 항목 없는 옵션을 알린다
)

@ @<전역 변수@>=
var (
	vbose      = showBasics + showWarnings // 수다스러움의 정도
	buf        [bufsize]byte // 입력 버퍼
	buflen     int           // 지금 버퍼에 든 줄의 길이
	options    int64         // 여태 본 옵션의 수
	imems, mems int64        // mem 수
	thresh     int64 = 1000000000  // |mems|가 이를 넘으면 알린다
	delta      int64 = 10000000000 // 이만큼 mem이 쌓일 때마다 알린다
	timeout    int64 = 0x1fffffffffffffff // mem이 이만큼 들면 포기한다
	rounds     = maxNodes // 되풀이할 판의 최대 수
	optionsOut, itmsOut int // 여태 이만큼 줄였다
)

@ 같은 선택항이 여러 번 나오면 맨 앞의 것이 이긴다. 명령줄을 뒤에서 앞으로 훑기
때문이다.

@<명령줄을 처리한다@>=
{
	bad := false
	setInt := func(s string, ptr *int) {
		if v, err := strconv.Atoi(s); err != nil {
			bad = true
		} else {
			*ptr = v
		}
	}
	setInt64 := func(s string, ptr *int64) {
		if v, err := strconv.ParseInt(s, 10, 64); err != nil {
			bad = true
		} else {
			*ptr = v
		}
	}
	@<선택항을 훑는다@>@;
	if bad {
		fmt.Fprintf(os.Stderr,
			"쓰는 법: %s [v<n>] [d<n>] [t<n>] [T<n>] < foo.dlx > bar.dlx\n",
			os.Args[0])
		os.Exit(1)
	}
}

@ @<선택항을 훑는다@>=
for j := len(os.Args) - 1; j > 0; j-- {
	arg := os.Args[j]
	if arg == "" {
		bad = true
		continue
	}
	switch arg[0] {
	case 'v':
		setInt(arg[1:], &vbose)
	case 'd':
		setInt64(arg[1:], &delta)
		thresh = delta
	case 't':
		setInt(arg[1:], &rounds)
	case 'T':
		setInt64(arg[1:], &timeout)
	default: // 알아볼 수 없는 선택항이다
		bad = true
	}
}

@* 자료 구조.
입력 행렬의 항목마다 \KW{item} 레코드가 하나씩 있고, 옵션마다 \KW{node} 레코드의
목록이 하나씩 있다. 마디는 행렬의 $0$ 아닌 자리마다 하나씩이다.

더 자세히 말하면, 한 옵션의 마디들은 메모리에 잇달아 놓이고 그 사이사이에
``띄개(spacer)'' 마디가 놓인다. 마디들은 항목 안에서도 두겹 연결 리스트로 둥글게
이어져 있다. 항목 목록에는 머리 마디가 있지만 옵션 목록에는 없다. 항목의 머리
마디는 \KW{item} 레코드와 짝을 이루고, 그 레코드가 항목에 대한 나머지 정보를 담는다.

마디마다 요긴한 밭이 넷이다. 둘은 방금 말한 두겹 연결 리스트의 |up|과 |down|이다.
셋째는 이 마디가 든 항목을 곧바로 가리킨다. 마지막은 색을 가리키는데, 색이 없으면
$0$이다.

여기서 ``포인터''란 배열 첨자이지 \CEE/의 참조가 아니다. (참조라면 예순네 자리를
차지해 캐시를 헛되이 쓴다.) 배열 |cl|이 \KW{item}들을, 배열 |nd|가 \KW{node}들을
담는다. 항목 |cl[c]|에 짝하는 머리 마디는 |nd[c]|다.

@ 마디 하나가 여덟 바이트 낱말 둘을 차지한다는 데 눈여겨보라. |up|과 |down|을
한꺼번에 짚는 것, 그리고 |itm|과 |color|를 한꺼번에 짚는 것을 각각 mem 하나로 센다.
(\GO/의 |int|는 여덟 바이트이니 실제로는 낱말 넷을 쓰지만, 셈은 원본 그대로 둔다.
세는 것은 우리 기계가 실제로 짚는 낱말 수가 아니라 커누스가 설계한 알고리즘의
값이기 때문이다.)

이 프로그램은 |itm| 밭을 한 번 채워 놓은 뒤로는 잠깐씩 말고는 고치지 않는다.
그러나 |up|과 |down|은 자주 바뀐다. 다만 서로의 앞뒤 차례는 지킨다.

예외가 있다. 항목~|c|의 목록 머리인 마디 |nd[c]|에서는 |itm| 밭에 그 목록의
{\it 길이\/}를 담는다(머리 마디 자신은 빼고 센다). |color| 밭도 딴 데 쓴다.
커누스는 이 남다른 뜻을 또렷이 하려고 |itm| 대신 |len|, |color| 대신 |aux|라는
다른 이름을 매크로로 두었다. \GO/에는 그런 매크로가 없으니 우리는 |itm|과 |color|를
그대로 쓰되, 머리 마디를 다루는 자리마다 주석으로 밝혀 둔다.

{\it 띄개\/} 마디는 |itm|이 $0$ 이하다. 그 |up| 밭은 앞 옵션의 첫머리를, |down|
밭은 뒤 옵션의 끝을 가리킨다. 그래서 옵션 하나를 어느 쪽으로든 둥글게 훑기 쉽다.

띄개는 옵션 {\it 안\/}에도 놓인다. 그 옵션이 짧아졌을 때 그렇다. 그런 띄개의 |up|과
|down|은 그저 다음 자리와 앞 자리를 가리킨다. (띄개가 잇달아 놓이면 연결을 접어
다듬을 수도 있겠지만, 이 프로그램은 그러지 않는다.)

@<자료형@>=
type node struct {
	up, down int // 항목 안에서의 앞과 뒤
	itm      int // 이 마디가 든 항목. 머리 마디에서는 목록 길이
	color    int // 이 마디가 매긴 색. 머리 마디에서는 보조 값
}

@ \KW{item} 레코드에는 밭이 셋이다. |name|은 사용자가 붙인 이름이고, |prev|와
|next|는 이 항목이 두겹 연결 리스트에 들어 있을 때 그 이웃을 가리킨다.

|prev|와 |next|를 한꺼번에 짚는 것도 mem 하나로 센다.

@<자료형@>=
type item struct {
	name       [8]byte // 찍을 때 쓰는 이름
	prev, next int     // 이 항목의 이웃
}

@ @<전역 변수@>=
var (
	nd       []node          // 마디들의 으뜸 목록
	lastNode int             // |nd|에서 아직 안 쓴 첫 마디
	cl       [maxItms + 2]item // 항목들의 으뜸 목록
	second   = maxItms       // 주 항목과 부 항목의 경계
	lastItm  int             // |cl|에서 아직 안 쓴 첫 항목
)

@ \KW{item} 레코드 하나를 뿌리라 부른다. 아직 덮어야 할 항목들의 목록 머리 노릇을
하며, |name|이 비어 있다는 것으로 알아본다.

이름은 여덟 바이트 배열이라 여덟 자를 다 쓰면 끝에 NUL이 없다. 찍을 때는 NUL
앞까지만 잘라야 한다.

@<함수들@>=
func itmname(c int) string {
	nm := cl[c].name
	for i := 0; i < 8; i++ {
		if nm[i] == 0 {
			return string(nm[:i])
		}
	}
	return string(nm[:])
}

@ 옵션은 이름이 아니라 그 옵션이 품은 항목의 이름들로 알아본다. 다음은 옵션의
아무 마디나 하나 주면 그 옵션을 찍어 주는 함수다. 그 옵션이 제 항목에서 몇 번째인지도
함께 찍는다.

이 함수는 {\mc DLX2}의 짝과 조금 다르다. {\mc DLX2}가 `\KW{if}'를 쓴 자리에
`\KW{for}'를 쓴다. {\mc DLX-PRE}는 마디를 지우고 그 자리를 띄개로 바꾸는 일이 있기
때문이다.

이 함수도 다음의 |printItm|도 프로그램 안에서는 아무도 부르지 않는다. 손으로 벌레를
잡을 때 쓰라고 커누스가 남겨 둔 것이라 그대로 옮겼다. 자료 구조가 무엇을 뜻하는지
이만큼 또렷이 말해 주는 것도 없다.

@<함수들@>=
func printOption(p int, f io.Writer) {
	if p < lastItm || p >= lastNode || nd[p].itm <= 0 {
		fmt.Fprintf(os.Stderr, "옵션 %d은 옳지 않다!\n", p)
		return
	}
	for q := p; ; {
		fmt.Fprintf(f, " %s", itmname(nd[q].itm))
		@<마디 |q|의 색을 찍는다@>@;
		q++
		for nd[q].itm <= 0 {
			q = nd[q].up
		}
		if q == p {
			break
		}
	}
	@<이 옵션이 제 항목에서 몇 번째인지 찍는다@>@;
}

@ @<마디 |q|의 색을 찍는다@>=
if nd[q].color != 0 {
	col := nd[q].color
	if col <= 0 {
		col = nd[nd[q].itm].color // 머리 마디의 |color|는 보조 값이다
	}
	fmt.Fprintf(f, ":%c", col)
}

@ @<이 옵션이 제 항목에서 몇 번째인지 찍는다@>=
k := 1
for q := nd[nd[p].itm].down; q != p; k++ {
	if q == nd[p].itm {
		fmt.Fprint(f, " (?)\n") // 옵션이 제 항목에 없다!
		return
	}
	q = nd[q].down
}
fmt.Fprintf(f, " (%d개 중 %d번째)\n", nd[nd[p].itm].itm, k)

@ 옵션을 찍는 함수가 하나 더 있다. 진단할 때 쓴다. 이 함수는 그 옵션의 원래 번호를
돌려주고, 아직 지워지지 않은 항목들을 원래 차례대로 보인다. 원래 번호는 (음수 꼴로)
옵션 오른쪽의 띄개에 들어 있다.

@<함수들@>=
func dpoption(p int, f io.Writer) int {
	for p--; nd[p].itm > 0 || nd[p].down < p; p-- {
	}
	for q := p + 1; ; q++ {
		c := nd[q].itm
		if c < 0 {
			return -c
		}
		if c > 0 {
			fmt.Fprintf(f, " %s", itmname(c))
			if nd[q].color != 0 {
				fmt.Fprintf(f, ":%c", nd[q].color)
			}
		}
	}
}

@ 벌레를 잡을 때는 지금의 항목 목록 하나를 들여다보고 싶을 때가 있다.

@<함수들@>=
func printItm(c int) {
	if c < root || c >= lastItm {
		fmt.Fprintf(os.Stderr, "항목 %d은 옳지 않다!\n", c)
		return
	}
	if c < second {
		fmt.Fprintf(os.Stderr, "항목 %s, 길이 %d, 이웃은 %s와 %s:\n",
			itmname(c), nd[c].itm, itmname(cl[c].prev), itmname(cl[c].next))
	} else {
		fmt.Fprintf(os.Stderr, "항목 %s, 길이 %d:\n", itmname(c), nd[c].itm)
	}
	for p := nd[c].down; p >= lastItm; p = nd[p].down {
		printOption(p, os.Stderr)
	}
}

@ 벌레 이야기가 나온 김에, 자료 구조에서 겹쳐 두어 성해야 할 곳이 어그러지지
않았는지 살피는 함수도 두자.

@<상수@>=
const sanityChecking = false // 벌레가 의심스러우면 |true|로 바꾼다

@ @<함수들@>=
func sanity() {
	q := root
	for p := cl[q].next; ; q, p = p, cl[p].next {
		if cl[p].prev != q {
			fmt.Fprintf(os.Stderr, "항목 %s의 prev 밭이 잘못됐다!\n", itmname(p))
		}
		if p == root {
			break
		}
		@<항목 |p|를 살핀다@>@;
	}
}

@ @<항목 |p|를 살핀다@>=
{
	qq, k := p, 0
	for pp := nd[qq].down; ; qq, pp, k = pp, nd[pp].down, k+1 {
		if nd[pp].up != qq {
			fmt.Fprintf(os.Stderr, "마디 %d의 up 밭이 잘못됐다!\n", pp)
		}
		if pp == p {
			break
		}
		if nd[pp].itm != p {
			fmt.Fprintf(os.Stderr, "마디 %d의 itm 밭이 잘못됐다!\n", pp)
		}
	}
	if nd[p].itm != k { // 머리 마디의 |itm|은 목록 길이다
		fmt.Fprintf(os.Stderr, "항목 %s의 길이가 잘못됐다!\n", itmname(p))
	}
}

@* 행렬 읽어 들이기.
이 대목은 무식한 힘으로 밀어붙인다. 하는 일은 입력 자료를 새겨 담고 그것이 옳은지
따지는 것뿐이다.

@<함수들@>=
func panik(m string, p int) {
	fmt.Fprintf(os.Stderr, "%s!\n%d: %.99s\n", m, p, string(buf[:buflen]))
	out.Flush()
	os.Exit(666)
}

@ 표준 입력에서 줄 하나를 |buf|에 담는다. \CEE/의 |fgets|처럼 줄 끝의 개행까지
담고 그 뒤에 NUL을 붙인다. 더 읽을 것이 없으면 |false|를 돌려준다.

@<함수들@>=
func getline() bool {
	line, err := in.ReadString('\n')
	if line == "" && err != nil {
		return false
	}
	if len(line) >= bufsize {
		line = line[:bufsize-1]
	}
	buflen = len(line)
	copy(buf[:], line)
	buf[buflen] = 0
	return true
}

@ 빈칸 가려내기도 손수 한다. \CEE/의 |isspace|가 보는 것과 같은 여섯 글자다.

@<함수들@>=
func isspace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
}

@ 마디 배열은 크니 실행할 때 잡는다. 항목마다 머리 마디 하나와 적어도 다른 마디
하나가 있어야 하므로 |maxNodes|는 |maxItms|의 두 배보다 커야 한다.

@<항목 이름을 읽어 들인다@>=
nd = make([]node, maxNodes)
if maxNodes <= 2*maxItms {
	fmt.Fprintln(os.Stderr, "다시 컴파일하라. maxNodes는 maxItms의 두 배보다 커야 한다!")
	os.Exit(999)
}
@<주석 아닌 첫 줄을 찾는다@>@;
if lastItm == 0 {
	panik("항목이 하나도 없다", p)
}
@<첫 줄에서 항목 이름을 하나씩 떼어 낸다@>@;
if second == maxItms {
	second = lastItm
}
mems++
cl[root].prev = second - 1 // |root=0|이므로 |cl[second-1].next=root|다
lastNode = lastItm // 머리 마디들과 첫 띄개의 자리를 잡아 둔다
mems++
nd[lastNode].itm = 0

@ @<주석 아닌 첫 줄을 찾는다@>=
for getline() {
	mems++
	p = buflen - 1
	if buf[p] != '\n' {
		panik("입력 줄이 너무 길다", p)
	}
	@<앞쪽 빈칸을 건너뛴다@>@;
	if buf[p] == '|' || buf[p] == 0 {
		continue // 주석이거나 빈 줄이면 지나친다
	}
	lastItm = 1
	break
}

@ @<앞쪽 빈칸을 건너뛴다@>=
for p = 0; ; p++ {
	mems++
	if !isspace(buf[p]) {
		break
	}
}

@ @<첫 줄에서 항목 이름을 하나씩 떼어 낸다@>=
for {
	mems++
	if buf[p] == 0 {
		break
	}
	@<항목 이름 한 자락을 |cl[lastItm].name|에 담는다@>@;
	if j == 8 && !isspace(buf[p+j]) {
		panik("항목 이름이 너무 길다", p)
	}
	@<항목 이름이 겹치는지 본다@>@;
	@<|lastItm|을 빈 목록을 가진 새 항목으로 채비한다@>@;
	@<이름 뒤의 빈칸을 건너뛰고 세로줄을 살핀다@>@;
}

@ @<항목 이름 한 자락을 |cl[lastItm].name|에 담는다@>=
for j = 0; j < 8; j++ {
	mems++
	if isspace(buf[p+j]) {
		break
	}
	if buf[p+j] == ':' || buf[p+j] == '|' {
		panik("항목 이름에 쓸 수 없는 글자가 있다", p)
	}
	mems++
	cl[lastItm].name[j] = buf[p+j]
}

@ 이름이 여덟 자보다 짧으면 남는 자리는 $0$인 채로 둔다. |cl[lastItm]|은 아직
한 번도 쓰지 않은 자리이므로 저절로 그렇다.

@<항목 이름이 겹치는지 본다@>=
for k = 1; ; k++ {
	mems++
	if cl[k].name == cl[lastItm].name {
		break
	}
}
if k < lastItm {
	panik("항목 이름이 겹친다", p)
}

@ @<|lastItm|을 빈 목록을 가진 새 항목으로 채비한다@>=
if lastItm > maxItms {
	panik("항목이 너무 많다", p)
}
if second == maxItms {
	mems += 2
	cl[lastItm-1].next, cl[lastItm].prev = lastItm, lastItm-1
} else {
	mems++
	cl[lastItm].next, cl[lastItm].prev = lastItm, lastItm
}
mems++ // 머리 마디의 |itm|은 목록 길이인데 아직 $0$이다
nd[lastItm].up, nd[lastItm].down = lastItm, lastItm
lastItm++

@ @<이름 뒤의 빈칸을 건너뛰고 세로줄을 살핀다@>=
for p += j + 1; ; p++ {
	mems++
	if !isspace(buf[p]) {
		break
	}
}
if buf[p] == '|' {
	if second != maxItms {
		panik("항목 이름 줄에 세로줄이 둘이다", p)
	}
	second = lastItm
	for p++; ; p++ {
		mems++
		if !isspace(buf[p]) {
			break
		}
	}
}

@ {\mc DLX1}과 그 자손들에서 커누스는 옵션 번호를 그 옵션 뒤의 띄개에 넣어 두었다.
벌레 잡을 때 쓸모가 있을까 해서였을 뿐이다. 그런데 {\mc DLX-PRE}에서는 그러기를
잘했다. 사용자가 줄인 출력을 원래 옵션과 이어 보려 할 때 바로 그 번호가 필요하기
때문이다.

@<옵션을 읽어 들인다@>=
for getline() {
	mems++
	p = buflen - 1
	if buf[p] != '\n' {
		panik("옵션 줄이 너무 길다", p)
	}
	@<앞쪽 빈칸을 건너뛴다@>@;
	if buf[p] == '|' || buf[p] == 0 {
		continue // 주석이거나 빈 줄이면 지나친다
	}
	i = lastNode // 이 옵션 왼쪽의 띄개를 기억해 둔다
	@<이 줄의 항목들을 마디로 만든다@>@;
	if pp == 0 {
		@<주 항목이 없는 옵션을 물린다@>@;
	} else {
		@<이 옵션을 마무리하고 다음 띄개를 만든다@>@;
	}
}

@ @<이 줄의 항목들을 마디로 만든다@>=
for pp = 0; buf[p] != 0; {
	@<옵션 안의 항목 이름 한 자락을 떼어 낸다@>@;
	@<|buf[p]|에 적힌 항목의 마디를 만든다@>@;
	@<이 마디의 색을 정한다@>@;
	for p += j + 1; ; p++ {
		mems++
		if !isspace(buf[p]) {
			break
		}
	}
}

@ 여기서 |cl[lastItm]|은 이름을 잠깐 담아 두는 자리로 되풀이해 쓰인다. \CEE/는
|strncmp|가 NUL에서 멈추니 |name[j]|에 NUL 하나만 넣으면 됐지만, \GO/에서 배열끼리
견주면 여덟 바이트를 다 보므로 남은 자리까지 비워야 한다.

@<옵션 안의 항목 이름 한 자락을 떼어 낸다@>=
cl[lastItm].name = [8]byte{}
for j = 0; j < 8; j++ {
	mems++
	if isspace(buf[p+j]) || buf[p+j] == ':' {
		break
	}
	mems++
	cl[lastItm].name[j] = buf[p+j]
}
if j == 0 {
	panik("항목 이름이 비었다", p)
}
if j == 8 && !isspace(buf[p+j]) && buf[p+j] != ':' {
	panik("항목 이름이 너무 길다", p)
}
if j < 8 {
	mems++ // 원본은 여기서 |name[j]|에 NUL을 넣는다
}

@ @<이 마디의 색을 정한다@>=
if buf[p+j] != ':' {
	mems++
	nd[lastNode].color = 0
} else if k >= second {
	mems++
	if isspace(buf[p+j+1]) {
		panik("색은 글자 하나여야 한다", p)
	}
	mems++
	if !isspace(buf[p+j+2]) {
		panik("색은 글자 하나여야 한다", p)
	}
	mems++
	nd[lastNode].color = int(buf[p+j+1])
	p += 2
} else {
	panik("주 항목에는 색을 줄 수 없다", p)
}

@ @<|buf[p]|에 적힌 항목의 마디를 만든다@>=
for k = 0; ; k++ {
	mems++
	if cl[k].name == cl[lastItm].name {
		break
	}
}
if k == lastItm {
	panik("모르는 항목 이름이다", p)
}
mems++
if nd[k].color >= i { // 머리 마디의 |color|는 보조 값이다
	panik("이 옵션에 항목 이름이 겹친다", p)
}
lastNode++
if lastNode == maxNodes {
	panik("마디가 너무 많다", p)
}
mems++
nd[lastNode].itm = k
if k < second {
	pp = 1
}
mems++
t = nd[k].itm + 1 // 머리 마디의 |itm|은 목록 길이다
@<마디 |lastNode|를 항목 |k|의 목록에 끼워 넣는다@>@;

@ 새 마디를 끼워 넣는 일은 간단하다. 새 마디의 자리를 |nd[k]|의 보조 값에 넣어
두는데, 그래야 위의 ``항목 이름이 겹친다'' 시험이 옳게 돈다.

@<마디 |lastNode|를 항목 |k|의 목록에 끼워 넣는다@>=
mems++
nd[k].itm = t // 목록의 새 길이
nd[k].color = lastNode // |len| 다음의 |aux|에는 mem을 매기지 않는다
mems++
r = nd[k].up // 항목 목록의 ``맨 아래'' 마디
mems += 3
nd[r].down, nd[k].up = lastNode, lastNode
nd[lastNode].up, nd[lastNode].down = r, k

@ @<주 항목이 없는 옵션을 물린다@>=
if vbose&showWarnings != 0 {
	fmt.Fprintf(os.Stderr, "주 항목이 없어 옵션을 물린다: %s", string(buf[:buflen]))
}
for lastNode > i {
	@<마디 |lastNode|를 제 항목에서 뺀다@>@;
	lastNode--
}

@ @<마디 |lastNode|를 제 항목에서 뺀다@>=
mems++
k = nd[lastNode].itm
mems += 2
nd[k].itm-- // 목록 길이를 줄인다
nd[k].color = i - 1 // 보조 값도 되돌린다
mems++
q, r = nd[lastNode].up, nd[lastNode].down
mems += 2
nd[q].down, nd[r].up = r, q

@ @<이 옵션을 마무리하고 다음 띄개를 만든다@>=
mems++
nd[i].down = lastNode
lastNode++ // 다음 띄개를 만든다
if lastNode == maxNodes {
	panik("마디가 너무 많다", p)
}
options++
mems++
nd[lastNode].up = i + 1
mems++
nd[lastNode].itm = -int(options)

@ @<입력이 잘 끝났음을 알린다@>=
fmt.Fprintf(os.Stderr, "(옵션 %d개, 항목 %d+%d개, 자리 %d개를 잘 읽었다)\n",
	options, second-1, lastItm-second, lastNode-lastItm)

@ 입력을 마쳤을 때의 항목별 길이와 프로그램이 끝났을 때의 길이는 같아야 한다.
물론 입력을 제대로 줄였다면 다르겠지만. 알고리즘이 크게 어그러지지는 않았다는
안심을 주려고, 부탁하면 그 길이들을 찍는다.

@<항목별 길이를 알린다@>=
fmt.Fprint(os.Stderr, "항목별 길이:")
for k = 1; k < lastItm; k++ {
	if k == second {
		fmt.Fprint(os.Stderr, " |")
	}
	fmt.Fprintf(os.Stderr, " %d", nd[k].itm) // 머리 마디의 |itm|은 목록 길이다
}
fmt.Fprintln(os.Stderr)

@* 춤.
주 항목 $p$가 있고, $p$를 품은 옵션이라면 모두 색 없는 $c$도 품는다고 하자. 여기서
$c$는 아무 항목이나 좋다. 그러면 항목~$c$를 지울 수 있고, $c$는 품되 $p$는 품지
않는 옵션도 모두 지울 수 있다. 어차피 $p$를 덮어야 하고, 그러면 $c$는 저절로
덮이기 때문이다.

더 넓게 보면, $p$가 주 항목이고 $r$가 옵션인데 $p\notin r$이면서 $p$를 품은 옵션은
모두 $r$와 어긋난다고 하자. 그러면 옵션~$r$를 걷어낼 수 있다. 그 옵션을 고르면
$p$를 덮을 길이 없어지기 때문이다.

이 프로그램은 이 두 착상을 쓴다. $c$를 모든 항목에 걸쳐 훑으면서, 항목~$c$의
목록에 있는 옵션을 죄다 들여다보는 식이다.

이 알고리즘은 ``다항 시간''에 돌지만 빠르다고 자랑할 것은 없다. 커누스는 더
복잡하게 만들기 전에 곧이곧대로 된 알고리즘을 먼저 자리잡게 하고 싶다고 적었다.

한편 그 단순함을 지키는 한에서 가장 효율 좋고 규모를 잘 견디는 방법을 쓰려고
애썼다고도 했다. 앞손질에 드는 시간과 푸는 시간을 더한 것이 줄어들 만큼 빨라야
앞손질을 할 값어치가 있기 때문이다.

@ 바탕이 되는 일은 ``항목 감추기''다. 그 항목의 목록에 있는 옵션을 모두, 항목
밖에서는 보이지 않게 만드는 것이다. 다만 이 항목에 색을 매긴 옵션은 그냥 둔다.
감춘 옵션은 (잠깐 동안) 다른 모든 목록에서 지워진다.

{\mc DLX2}에서처럼 이 알고리즘의 깔끔한 대목은 목록을 간수하는 방식이다. 항목을
감추거나 나중에 되살릴 때 곁다리 표가 하나도 필요하지 않다. 두겹 연결 리스트에서
빠져나온 마디들이 제 옛 이웃을 그대로 기억하고 있기 때문이다. 우리는 쓰레기를
치우지 않는다.

@ 감추기는 {\mc DLX2}의 ``덮기''와 많이 닮았지만 비틀린 데가 하나 있다. 항목 $c$를
감추다가 주 항목~$p$ 가운데 하나가 비게 되면, 우리는 $c$를 걷어낼 수 있다는 것을
안다(위에서 말한 대로다). 게다가 $c$는 품되 $p$는 품지 않는 옵션도 모두 지울 수
있다는 것을 안다.

그래서 감추는 대목은 그런 $p$의 값을 전역 변수에 넣어 둔다. 그 전역 변수의 이름이
|stack|인 데는 사연이 있다. 커누스가 처음 만든 판은 여러 주 항목이 한꺼번에 비는
경우를 쓸데없이 복잡하게 다루었고, 그때는 그것들을 쌓개에 쌓았기 때문이다.

@ 감추기는 한 곳에서만 부르므로 절로 둔다. 되살리기는 두 곳에서 부르므로 함수로
둔다.

@<항목 |c|를 감춘다@>=
mems++
for rr = nd[c].down; rr >= lastItm; mems, rr = mems+1, nd[rr].down {
	mems++
	if nd[rr].color != 0 {
		continue
	}
	@<옵션 |rr|의 마디들을 다른 목록에서 뺀다@>@;
}

@ @<옵션 |rr|의 마디들을 다른 목록에서 뺀다@>=
for nn = rr + 1; nn != rr; {
	mems++
	uu, dd = nd[nn].up, nd[nn].down
	mems++
	cc = nd[nn].itm
	if cc <= 0 {
		nn = uu
		continue
	}
	mems += 2
	nd[uu].down, nd[dd].up = dd, uu
	mems++
	t = nd[cc].itm - 1 // 머리 마디의 |itm|은 목록 길이다
	mems++
	nd[cc].itm = t
	if t == 0 && cc < second {
		stack = cc
	}
	nn++
}

@ @<함수들@>=
func unhide(c int) {
	var cc, rr, nn, uu, dd, t int
	mems++
	for rr = nd[c].down; rr >= lastItm; mems, rr = mems+1, nd[rr].down {
		mems++
		if nd[rr].color != 0 {
			continue
		}
		for nn = rr + 1; nn != rr; {
			mems++
			uu, dd = nd[nn].up, nd[nn].down
			mems++
			cc = nd[nn].itm
			if cc <= 0 {
				nn = uu
				continue
			}
			mems++
			t = nd[cc].itm
			mems += 2
			nd[uu].down, nd[dd].up = nn, nn
			mems++
			nd[cc].itm = t + 1
			nn++
		}
	}
}

@ 앞손질 한 판의 큰 반복문은 이렇다.

@<문제를 줄인다@>=
for cc = 1; cc < lastItm; cc++ {
	mems++
	if nd[cc].itm == 0 { // 머리 마디의 |itm|은 목록 길이다
		@<항목 |cc|가 어떤 옵션에도 없음을 적어 둔다@>@;
	}
}
for rnd = 1; rnd < rounds; rnd++ {
	if vbose&showChoices != 0 {
		fmt.Fprintf(os.Stderr, "%d번째 판을 시작한다:\n", rnd)
	}
	change = 0
	for c = 1; c < lastItm; c++ {
		mems++
		if nd[c].itm != 0 {
			@<항목 |c|의 목록에서 옵션을 줄여 본다@>@;
		}
	}
	if change == 0 {
		break
	}
}

@ @<전역 변수@>=
var (
	rnd    int // 지금 몇 번째 판인가
	stack  int // 막힌 항목. 또는 지울 옵션 쌓개의 꼭대기
	change int // 이번 판에서 무언가 걷어냈는가?
)

@ 같은 옵션을 되풀이해 시험하지 않으려고, 대개 |c|가 그 옵션에서 메모리에 놓인
첫 원소일 때에만 걷어내 본다.

커누스가 2023년 1월 2일에 벌레 하나를 고치고 적어 둔 말이 있다. |c|가 부 항목이고
옵션~|r|에서 색이 $0$이 아니면 |r|를 걷어내 보아서는 {\it 안 된다\/}. 감추기가
|r|를 감추지 않았기 때문이다. 그래서 걷어낼 수 있는 것을 놓칠 수도 있다. 색이 있는
부 항목을 모든 옵션에서 맨 뒤에 두면 그런 일을 피할 수 있다.

@<항목 |c|의 목록에서 옵션을 줄여 본다@>=
{
	if sanityChecking {
		sanity()
	}
	@<mem이 넉넉히 쌓였으면 알린다@>@;
	if mems >= timeout {
		goto finish
	}
	stack = 0
	@<항목 |c|를 감춘다@>@;
	if stack != 0 {
		@<항목 |c|를 없애고, 딸려서 옵션도 없앤다@>@;
	} else {
		@<쓸모없는 옵션을 찾아 쌓았다가 지운다@>@;
	}
}

@ @<mem이 넉넉히 쌓였으면 알린다@>=
if delta != 0 && mems >= thresh {
	thresh += delta
	fmt.Fprintf(os.Stderr,
		" %d mem 뒤: %d.%d, 항목 %d개와 옵션 %d개를 걷어냈다\n",
		mems, rnd, c, itmsOut, optionsOut)
}

@ @<쓸모없는 옵션을 찾아 쌓았다가 지운다@>=
mems++
for r = nd[c].down; r >= lastItm; mems, r = mems+1, nd[r].down {
	@<옵션 안에서 |r| 앞의 빈 띄개를 건너뛰어 |q|를 잡는다@>@;
	mems++
	if nd[q].itm <= 0 {
		mems++
		if nd[r].color == 0 {
			// |r|는 제 옵션에서 살아남은 첫 마디이고 색이 없다
			@<옵션 |r|가 어떤 주 항목을 덮을 수 없게 만들면 쌓아 둔다@>@;
		}
	}
}
unhide(c)
for r = stack; r != 0; r = rr {
	mems += 2
	rr, nd[r].itm = nd[r].itm, c
	@<옵션 |r|를 진짜로 지운다@>@;
}

@ @<옵션 안에서 |r| 앞의 빈 띄개를 건너뛰어 |q|를 잡는다@>=
for q = r - 1; ; q-- {
	mems++
	if nd[q].down != q-1 {
		break
	}
}

@ @<항목 |c|를 없애고, 딸려서 옵션도 없앤다@>=
unhide(c)
if vbose&showDetails != 0 {
	fmt.Fprintf(os.Stderr, "항목 %s를 지운다. %s가 그렇게 만든다\n",
		itmname(c), itmname(stack))
}
mems++
for r = nd[c].down; r >= lastItm; r = rrr {
	mems++
	rrr = nd[r].down
	@<옵션 |r|를 지우거나 줄인다@>@;
}
mems++
nd[c].up, nd[c].down = c, c
mems++
nd[c].itm = 0 // 이제 항목 |c|는 없다
itmsOut++
change = 1

@ 여기서는 우리가 운전대를 쥐고 있다. 옵션 |r|가 |stack|을 품으면 그 옵션은
남기되 항목 |c|만 뺀다. 그렇지 않으면 옵션을 지운다.

@<옵션 |r|를 지우거나 줄인다@>=
for q = r + 1; q != r; {
	mems++
	cc = nd[q].itm
	if cc <= 0 {
		mems++
		q = nd[q].up
		continue
	}
	if cc == stack {
		break
	}
	q++
}
if q != r {
	@<옵션 |r|를 줄여서 남긴다@>@;
} else {
	@<옵션 |r|를 지운다@>@;
}

@ @<옵션 |r|를 줄여서 남긴다@>=
if vbose&showDetails != 0 {
	fmt.Fprint(os.Stderr, " 줄인다")
	t = dpoption(r, os.Stderr)
	fmt.Fprintf(os.Stderr, " (옵션 %d)\n", t)
}
mems++
nd[r].up, nd[r].down = r+1, r-1 // 마디 |r|를 띄개로 바꾼다
mems++
nd[r].itm = 0

@ @<옵션 |r|를 지운다@>=
if vbose&showDetails != 0 {
	fmt.Fprint(os.Stderr, " 지운다")
	t = dpoption(r, os.Stderr)
	fmt.Fprintf(os.Stderr, " (옵션 %d)\n", t)
}
optionsOut++
mems++
for q = r + 1; q != r; {
	mems++
	cc = nd[q].itm
	if cc <= 0 {
		mems++
		q = nd[q].up
		continue
	}
	mems++
	t = nd[cc].itm - 1 // 머리 마디의 |itm|은 목록 길이다
	if t == 0 {
		@<항목 |cc|가 어떤 옵션에도 없음을 적어 둔다@>@;
	}
	mems++
	nd[cc].itm = t
	mems++
	uu, dd = nd[q].up, nd[q].down
	mems += 2
	nd[uu].down, nd[dd].up = dd, uu
	q++
}

@ 이 자리에서 우리는 항목 |c|와 옵션 |r|를 감춰 두었다. 이제 그 옵션의 다른 항목들도
감추고, 그래서 다른 주 항목을 덮을 길이 없어지면 |r|를 지운다. (그런 항목을 만나면
곧바로 |pp|에 넣고 되돌아 나온다.)

그 시험을 하기 전에, |r|의 |c| 아닌 항목마다 |aux| 밭에 |r|라는 번호를 찍어 둔다.
그러면 |r| 안에 없는 항목을 막았는지 아닌지를 확실히 알 수 있다.

옵션 |r| 안의 항목 |cc|에 색 |x|가 매겨져 있을 때 ``항목 |cc|를 감춘다''는 말은,
더 정확히는 |cc|의 항목 목록에서 옵션~|r|와 어긋나는 옵션을 모두 감춘다는 뜻이다.
옵션 |rr|가 |r|와 어긋난다는 것은 |x=0|이거나 |rr|가 |cc|에 $x$ 아닌 색을 매겼다는
말이고, 그 역도 참이다.

@<옵션 |r|가 어떤 주 항목을 덮을 수 없게 만들면 쌓아 둔다@>=
{
	@<옵션 |r|의 항목마다 보조 값에 |r|를 찍는다@>@;
	blocked := false
	@<옵션 |r|의 항목들이 막는 옵션을 모두 감춘다@>@;
	@<감춘 것을 도로 되살린다@>@;
	if pp != 0 {
		@<쓸모없는 옵션 |r|에 표를 한다@>@;
	}
}

@ @<옵션 |r|의 항목마다 보조 값에 |r|를 찍는다@>=
for q = r + 1; ; {
	mems++
	cc = nd[q].itm
	if cc <= 0 {
		mems++
		q = nd[q].up
		if q > r {
			continue
		}
		break // 이 옵션은 다 보았다
	}
	mems++
	nd[cc].color = r // 머리 마디의 |color|는 보조 값이다
	q++
}

@ @<옵션 |r|의 항목들이 막는 옵션을 모두 감춘다@>=
pp = 0
q = r + 1
hiding:
for {
	mems++
	cc = nd[q].itm
	if cc <= 0 {
		mems++
		q = nd[q].up
		if q > r {
			continue
		}
		break // 이 옵션은 다 보았다
	}
	x = nd[q].color
	mems++
	for p = nd[cc].down; p >= lastItm; mems, p = mems+1, nd[p].down {
		if x > 0 {
			mems++
			if nd[p].color == x {
				continue
			}
		}
		@<옵션 |p|의 마디들을 다른 목록에서 뺀다. 막히면 |break hiding|@>@;
	}
	q++
}

@ 오래전에 커누스는 ``{\bf go to} 문을 쓰는 구조적 프로그래밍''[{\sl Computing
Surveys\/ \bf 6} (1974년 12월), 261--301]에서 반복문 하나를 뛰쳐나와 다른 반복문
한복판으로 뛰어드는 것이 때로는 옳다고 밝혔다. 그러고도 여러 해가 지난 지금까지
자기는 여전히 뛰고 있다고 원본에 적어 두었다.

바로 그 뛰기가 여기 있다. 원본은 막힌 자리에서 |goto midst|로 되살리는 반복문의
한복판으로 뛰어든다. \GO/는 블록 안으로 뛰어들 수 없으니 그 대신 |blocked|라는
깃발을 세운다. 이름표 붙인 |break hiding|으로 두 겹 반복문을 한꺼번에 빠져나오고,
되살리는 쪽에서는 그 깃발을 보고 처음이 아니라 막힌 자리에서 이어 나간다.

@<옵션 |p|의 마디들을 다른 목록에서 뺀다. 막히면 |break hiding|@>=
for qq = p + 1; qq != p; {
	mems++
	cc = nd[qq].itm
	if cc <= 0 {
		mems++
		qq = nd[qq].up
		continue
	}
	mems++
	t = nd[cc].itm - 1 // 머리 마디의 |itm|은 목록 길이다
	if t == 0 && cc < second && nd[cc].color != r {
		pp = cc
		blocked = true
		break hiding
	}
	mems++
	nd[cc].itm = t
	mems++
	uu, dd = nd[qq].up, nd[qq].down
	mems += 2
	nd[uu].down, nd[dd].up = dd, uu
	qq++
}

@ 되살리기는 감추기를 거꾸로 되짚는다. 끝까지 감추고 왔으면 |q|를 |r-1|에 두고
옵션을 거꾸로 훑으며 모두 되살린다. 막혀서 들어왔으면 |q|와 |p|와 |qq|가 이미
막힌 자리를 가리키고 있으니 거기서 이어 나간다.

@<감춘 것을 도로 되살린다@>=
if !blocked {
	q = r - 1
}
for q != r {
	if !blocked {
		mems++
		cc = nd[q].itm
		if cc <= 0 {
			mems++
			q = nd[q].down
			continue
		}
		x = nd[q].color
		mems++
		p = nd[cc].up
	}
	@<항목 |cc|의 목록을 거꾸로 훑으며 되살린다@>@;
	q--
}

@ @<항목 |cc|의 목록을 거꾸로 훑으며 되살린다@>=
for ; p >= lastItm; mems, p = mems+1, nd[p].up {
	if blocked {
		blocked = false
		qq--
		@<|qq|에서 거꾸로 훑으며 되살린다@>@;
		continue
	}
	if x > 0 {
		mems++
		if nd[p].color == x {
			continue
		}
	}
	qq = p - 1
	@<|qq|에서 거꾸로 훑으며 되살린다@>@;
}

@ @<|qq|에서 거꾸로 훑으며 되살린다@>=
for qq != p {
	mems++
	cc = nd[qq].itm
	if cc <= 0 {
		mems++
		qq = nd[qq].down
		continue
	}
	mems += 2
	nd[cc].itm++ // 목록 길이를 되돌린다
	mems++
	uu, dd = nd[qq].up, nd[qq].down
	mems += 2
	nd[uu].down, nd[dd].up = qq, qq
	qq--
}

@ 커누스가 이 프로그램을 처음 썼을 때는 이렇게 생각했다고 한다. ``옵션 |r|는 이미
감춰져 있다. 그러니 목록~|c|에서 그것을 빼내면 |unhide(c)|는 그것을 감춘 채로
둘 것이다. 바로 우리가 바라던 바다.''

그런데 크게 틀렸다. 목록~|c|를 그렇게 고치면 되살리기가 어그러진다. 목록이 무엇을
되돌리라고 더는 말해 주지 않게 된 뒤로는 제자리에 돌려놓이지 않기 때문이다.
(지우지 않은 옵션과 지운 옵션이 뒤섞인다.)

고치는 길은 그 옵션에 표를 해 두었다가 {\it 나중에\/} 지우는 것이다. 표를 한
옵션들은 |itm| 밭으로 서로 이어 둔다. 그 밭은 이제 본래의 쓸모가 없다.

@<쓸모없는 옵션 |r|에 표를 한다@>=
if vbose&showDetails != 0 {
	fmt.Fprintf(os.Stderr, " %s가 막힌다:", itmname(pp))
	t = dpoption(r, os.Stderr)
	fmt.Fprintf(os.Stderr, " (옵션 %d)\n", t)
}
optionsOut++
change = 1
mems++
nd[r].itm, stack = stack, r

@ @<옵션 |r|를 진짜로 지운다@>=
for p = r + 1; ; {
	mems++
	cc = nd[p].itm
	if cc <= 0 {
		mems++
		p = nd[p].up
		continue
	}
	mems++
	uu, dd = nd[p].up, nd[p].down
	mems += 2
	nd[uu].down, nd[dd].up = dd, uu
	mems += 2
	nd[cc].itm-- // 목록 길이를 줄인다
	if nd[cc].itm == 0 {
		@<항목 |cc|가 어떤 옵션에도 없음을 적어 둔다@>@;
	}
	if p == r {
		break
	}
	p++
}

@ @<항목 |cc|가 어떤 옵션에도 없음을 적어 둔다@>=
itmsOut++
if cc >= second {
	if vbose&showDetails != 0 {
		fmt.Fprintf(os.Stderr, " %s는 어떤 옵션에도 없다\n", itmname(cc))
	}
} else {
	@<주 항목 |cc| 때문에 풀 수 없다고 알리고 끝낸다@>@;
}

@ 어떤 옵션에도 나오지 않는 주 항목을 만날 수도 있다. 그런 경우에는 옵션을
{\it 모두\/} 지울 수 있고, 다른 항목도 모두 지울 수 있다!

@<주 항목 |cc| 때문에 풀 수 없다고 알리고 끝낸다@>=
if vbose&showDetails != 0 {
	fmt.Fprintf(os.Stderr, "주 항목 %s가 어떤 옵션에도 없다!\n", itmname(cc))
}
optionsOut = int(options)
itmsOut = lastItm - 1
fmt.Fprintf(out, "%s\n", itmname(cc)) // 내놓는 것은 이 한 줄뿐이다
goto allDone

@* 내놓기.
자, 다 했다.

@<줄인 문제를 내놓는다@>=
@<항목 이름을 내놓는다@>@;
@<옵션을 내놓는다@>@;

@ 부 항목이 하나도 남지 않았으면 세로줄을 내놓지 않는다. 그래야 깔끔하다.

@<항목 이름을 내놓는다@>=
for c, p = 1, 1; c < lastItm; c++ {
	if c == second {
		p = 0 // 여기서부터는 주 항목이 아니다
	}
	mems++
	if nd[c].itm != 0 { // 머리 마디의 |itm|은 목록 길이다
		if p == 0 {
			p = -1
			fmt.Fprint(out, " |")
		}
		fmt.Fprintf(out, " %s", itmname(c))
	}
}
fmt.Fprintln(out)

@ @<옵션을 내놓는다@>=
for c = 1; c < lastItm; c++ {
	mems++
	if nd[c].itm == 0 {
		continue
	}
	mems++
	for r = nd[c].down; r >= lastItm; mems, r = mems+1, nd[r].down {
		@<옵션 안에서 |r| 앞의 빈 띄개를 건너뛰어 |q|를 잡는다@>@;
		mems++
		if nd[q].itm <= 0 { // |r|는 제 옵션에서 살아남은 맨 왼쪽 마디다
			t = dpoption(r, out)
			fmt.Fprintln(out)
			if vbose&showOrigNos != 0 {
				fmt.Fprintf(out, "| (from %d)\n", t)
			}
		}
	}
}

@ @<몇 개나 줄였는지 알린다@>=
fmt.Fprintf(os.Stderr, "옵션 %d개와 항목 %d개를 걷어냈다. %d+%d mem이 들었고",
	optionsOut, itmsOut, imems, mems)
fmt.Fprintf(os.Stderr, " %d판을 돌았다.\n", rnd)

@* 돌려 보기.
돌리는 법은 이렇다.
$$\vbox{\halign{\tt#\hfil\cr
go run dlx-pre.go v9 < ex1.dlx\cr}}$$
여기서 \.{ex1.dlx}는 들어가며에 나온 첫 보기다. 그러면 표준 오류로
$$\vbox{\halign{\tt#\hfil\cr
(옵션 6개, 항목 5+2개, 자리 22개를 잘 읽었다)\cr
옵션 3개와 항목 4개를 걷어냈다. 428+1284 mem이 들었고 3판을 돌았다.\cr}}$$
가 나오고, 표준 출력으로 들어가며에 적어 둔 그 여섯 줄이 나온다.

@ 이 대목에는 사연이 있다. 커누스의 원본 \S3에는 그 여섯 줄이 이렇게 적혀 있다.
$$\vbox{\halign{\tt#\hfil\cr
\ A B C \char"7C\cr
\ A\cr
\char"7C\ (from 4)\cr
\ B\cr
\char"7C\ (from 5)\cr
\ C\cr
\char"7C\ (from 1)\cr}}$$
그런데 프로그램이 실제로 찍는 것은 \.C가 아니라 \.E이고, 첫 줄에 세로줄이 붙지도
않는다. 어긋난 곳이 둘이다.

@ 둘 다 원본 스스로가 말해 주는 바와 어긋난다. \S1의 마지막 문장은 남는 것이
``주 항목 \.A, \.B, \.E 셋과 홑 옵션 \.A, \.B, \.E 셋''이라고 또렷이 적고 있으니
\.C가 아니라 \.E다. 그리고 세로줄을 내놓는 대목은 부 항목이 하나라도 살아남았을
때에만 찍도록 되어 있는데, 여기서는 \.F도 \.G도 걷어냈으니 찍힐 까닭이 없다.

번호는 맞다. 옵션 $4$는 \.{A D}, $5$는 \.{B G}, $1$은 \.{C E F}이니 차례로 \.A,
\.B, \.E가 나오는 것이 옳다. 곧 \.{(from 1)}이 붙은 줄이 \.C일 수는 없다.
그 줄의 옵션에는 \.C도 \.E도 \.F도 있었지만 살아남은 것은 \.E뿐이기 때문이다.

@ 우리 판은 커누스의 \CEE/ 원본과 견주었다. 위의 두 보기와, 마디 $8$개까지의
$n$-퀸 문제, 그리고 무작위로 지은 문제 $600$개를 돌렸다. 표준 출력도, 수다스러운
기록도, mem 수도 한 자리 다르지 않았다.

@ 옮기면서 손댄 곳은 넷이다. 모두 언어에서 온 것이다.

첫째는 앞에서 말한 뛰기다. 원본은 되살리는 반복문의 한복판으로 뛰어들지만
\GO/는 블록 안으로 뛰어들 수 없어, 깃발 |blocked|와 이름표 붙인 |break hiding|으로
같은 흐름을 만들었다.

둘째, 원본이 매크로로 두었던 |len|과 |aux|라는 다른 이름이 없다. \GO/에는 밭에
별명을 붙일 길이 없으므로 머리 마디에서도 |itm|과 |color|를 그대로 쓰고, 그런
자리마다 주석을 달았다.

셋째, 항목 이름을 견줄 때 원본은 |strncmp|를 쓴다. 그것은 NUL을 만나면 멈추므로
그 뒤에 묵은 바이트가 남아 있어도 탈이 없다. \GO/에서 여덟 바이트 배열끼리
견주면 여덟 바이트를 다 보므로, 이름을 담기 전에 배열을 통째로 비운다.

넷째, 쓰이지 않는 것들을 옮기지 않았다. 원본은 \.{gb\_flip.h}를 읽어들이지만
난수를 한 번도 쓰지 않고, \.{max\_level}과 \.{cur\_node}와 \.{best\_itm}을
밝혀 두지만 쓰지 않으며, 이름표 \.{done}과 \.{backup}에는 아무도 뛰어들지 않는다.
\GO/에서는 쓰이지 않는 이름표가 컴파일 오류이므로 그 둘은 없앨 수밖에 없었다.
(난수가 정말 필요했다면 \.{SGB}의 \.{gb\_flip}에 맞선 것이
\pdfURL{go-sgb}{https://github.com/sjnam/go-sgb}의 |gbflip|에 있다.)

다섯째, 그만둘 때의 종료 부호를 양수로 바꾸었다. 원본은 |exit(-666)|처럼 음수를
쓰지만 \GO/에서는 $0$과 $125$ 사이를 권한다.

@* 색인.
