\input kotexgweb
\input luamplib.sty

@s Writer int
@s Reader int
@s Result int

% 두 그림 모두 낱말과 항목 이름을 타자체로 적는다.
\everymplib{defaultfont := "cmtt10"; defaultscale := 0.95;}

\def\title{단어 정육면체를 정확 덮개로}

% 그림 설명. \centerline과 달리 길면 여러 줄로 접힌다.
\def\figcap#1{\smallskip{\narrower\noindent #1\par}\medskip}

@* 들어가며.
딸린 프로그램 \pdfURL{\.{wordcube.w}}%
{https://github.com/sjnam/gweb-examples/blob/main/wordcube.w}는
대칭 단어 정육면체를 손수 짠 백트래킹으로 센다.
정렬된 사전에서 접두사에 맞는 구간을 이진 탐색으로 잡아 한 줄씩 내려가는, 그
문제에 꼭 맞게 재단한 방법이다. 이 프로그램은 정반대 쪽에서 같은 문제에
다가간다. 정육면체를 통째로 {\it 정확 덮개\/}(exact cover) 문제 하나로 옮겨
적어, 범용 해결기에게 넘겨 버리는 것이다.

본은 커누스의 \pdfURL{\.{word-rect-dlx.w}}%
{https://www-cs-faculty.stanford.edu/\TILDE/knuth/programs/word-rect-dlx.w}에서
얻었다. 그 프로그램은 $m\times n$ 낱말 직사각형을 \.{DLX} 파일로 옮기는데, 첫머리에
이렇게 적혀 있다: ``이것은 트라이 구조를 쓰는 프로그램 \.{BACK-MXN-WORDS-NEW}와
{\it 겨루기로\/} 되어 있다.'' 우리도 같은 겨루기를 붙여 보자---우리 쪽 도전자는
\.{wordcube}이고, 챔피언 자리에는 {\it 춤추는 칸\/}(dancing cells)이 앉는다.

@ 처음 판은 커누스의 것처럼 \.{DLX} 파일을 찍기만 했고, 그 파일을 커누스의 \CEE/
프로그램 \.{ssxcc}에 넘겨 풀었다. 이 저장소로 옮겨 오면서(2026년 11월) 나는
해결기를 프로그램 안으로 들였다. 이제는 \.{DLX} 문서를 파이프로 이 저장소의 춤추는
칸 엔진에 곧바로 흘려 넣고, 엔진이 돌려주는 해를 받아 정육면체로 도로 지은 다음,
세 축의 낱말이 모두 사전에 있는지까지 손수 검사한다. 엔진은 둘 가운데 고를 수 있다.
여느 \.{XCC}와, 마디마다 도메인 일관성을 지키는 \.{XCCDC}다. 파일만 찍던 예전
쓰임새도 \.{-p} 깃발로 남겨 두었다---\.{ssxcc}와 맞대어 볼 때는 그것이 있어야 한다.

@ 놀랍게도 옮겨 적은 결과가 아주 작다. 기본 항목 $15$개, 보조 항목 $35$개가 전부다.
정육면체를 다루기 까다롭게 만드는 바로 그 대칭이, 정확 덮개로 옮길 때는 오히려
문제를 줄여 준다. 어떻게 그렇게 되는지가 이 글의 알맹이고, 프로그램 자체는 그
설명을 그대로 받아 적은 것이라 짧다.

@c
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	cells "github.com/sjnam/dancing-cells"
)

const (
	n       = 5                         // 정육면체 한 변, 곧 낱말 길이
	nlines  = n * (n + 1) / 2           // 낱말이 놓일 줄의 수, 15
	ncells  = n * (n + 1) * (n + 2) / 6 // 서로 다른 칸의 수, 35
	nolimit = 1 << 30                   // 낱말 수를 제한하지 않았다는 뜻
)

@<전역 변수@>

@<함수들@>

func main() {
	@<명령줄을 처리한다@>
	@<낱말을 읽는다@>
	if dlxOnly {
		@<\.{DLX} 파일만 찍고 물러난다@>
	}
	@<춤추는 칸으로 정육면체를 센다@>
	@<센 것을 알린다@>
}

@* 정확 덮개로 옮기기.
먼저 \.{DLX} 파일이 무엇인지 짧게 되짚자. 첫 줄에 {\it 항목\/}(item)들의 이름이
오는데, 세로막대 앞의 것은 {\it 기본\/}(primary) 항목이고 뒤의 것은 {\it 보조\/}
(secondary) 항목이다. 그다음 줄들은 저마다 하나의 {\it 선택지\/}(option), 곧
항목 이름들의 목록이다. 해란 선택지의 부분집합으로서, 기본 항목은 {\it 정확히
한 번\/} 덮고 보조 항목은 {\it 많아야 한 번\/} 덮는 것을 말한다. 보조 항목에는
\.{항목:색}처럼 {\it 색\/}(color)을 달 수 있는데, 그러면 여러 선택지가 그 항목을
함께 덮어도 된다---색이 모두 같기만 하다면. 세로막대로 시작하는 줄은 주석이다.

@ 옮기기 전에 \.{wordcube.w}의 보기를 하나 다시 불러 두자. 아래는 대칭 단어
정육면체 하나를 셋째 축으로 읽어 $(i,j)$칸마다 낱말 $a_{ij\ast}$를 적은 표다.
$$
\mplibcode
% cell[i][j] is the word C_{ij*}; the table is symmetric.
string cell[][];
cell[0][0]:="aster"; cell[0][1]:="scale"; cell[0][2]:="tacos"; cell[0][3]:="elope"; cell[0][4]:="reset";
cell[1][0]:="scale"; cell[1][1]:="codex"; cell[1][2]:="adopt"; cell[1][3]:="leper"; cell[1][4]:="extra";
cell[2][0]:="tacos"; cell[2][1]:="adopt"; cell[2][2]:="cover"; cell[2][3]:="opera"; cell[2][4]:="strap";
cell[3][0]:="elope"; cell[3][1]:="leper"; cell[3][2]:="opera"; cell[3][3]:="perks"; cell[3][4]:="erase";
cell[4][0]:="reset"; cell[4][1]:="extra"; cell[4][2]:="strap"; cell[4][3]:="erase"; cell[4][4]:="taper";
beginfig(1);
  numeric w, h;
  w := 54; h := 20;
  for i=0 upto 4:
    for j=0 upto 4:
      if i=j:
        fill (j*w,-(i+1)*h)--((j+1)*w,-(i+1)*h)--((j+1)*w,-i*h)--(j*w,-i*h)--cycle
          withcolor (1, 0.92, 0.78);
      fi
      label(cell[i][j], (j*w+.5w, -i*h-.5h));
    endfor
  endfor
  for k=0 upto 5:
    draw (k*w, 0)--(k*w, -5h);
    draw (0, -k*h)--(5w, -k*h);
  endfor
endfig;
\endmplibcode
$$
\figcap{{\bf 그림 1}: 대칭 단어 정육면체 하나를 낱말 표로 편 모습(\.{wordcube.w}의 그림 1을
다시 그렸다. 음영은 대각 낱말이다). 표가 대칭이니 실제로 정해야 할 낱말은 대각선 위쪽 $15$개뿐이고, 바로 그
$15$개가 기본 항목이 된다.}

@ 이제 옮겨 적자. 딸린 글 \.{wordcube.w}에서 보았듯 대칭 정육면체에서 독립인 것은 첨자를
정렬한 것들뿐이다. 낱말이 놓이는 줄은 $i\le j$인 짝 $(i,j)$마다 하나씩 $15$개,
칸은 크기 $3$짜리 다중집합 $\{a,b,c\}$마다 하나씩 ${5+2\choose3}=35$개다. 이 둘이
그대로 항목이 된다.

\smallskip
\item{$\bullet$} 기본 항목 \.{L$ij$}는 ``줄 $(i,j)$는 낱말 하나를 받아야 한다''를 뜻한다.
\item{$\bullet$} 보조 항목 \.{$abc$}는 칸 $\{a,b,c\}$이고, 그 색이 그 칸의 글자다.
\smallskip

\noindent 선택지는 ``줄 $(i,j)$에 낱말 $w$를 놓는다''는 것 하나하나다. 그런 선택지는
기본 항목 \.{L$ij$} 하나와, 색이 달린 보조 항목 다섯 개로 이루어진다. 낱말의
$c$번째 글자가 놓이는 자리가 칸 $\{i,j,c\}$이므로,
$$\hbox{\.{L$ij$}\quad$\{i,j,0\}$\.{:}$w_0$\quad$\{i,j,1\}$\.{:}$w_1$\quad
$\ldots$\quad$\{i,j,4\}$\.{:}$w_4$}$$
이다. 낱말이 $5757$개이니 선택지는 모두 $15\times5757=86{,}355$개다.

@ 색이 하는 일이 곧 정육면체의 맞물림이다. 칸 하나를 여러 줄이 함께 건드리는데,
색이 같아야 한다는 요구가 바로 ``그 칸의 글자는 하나''라는 말이기 때문이다.
앞선 글 \.{wordcube.w}의 보기를 그대로 가져와 보자. 칸 $\{1,2,3\}$은 낱말 \.{adopt}
$(a_{12\ast})$의 넷째 글자이면서 \.{leper}$(a_{13\ast})$의 셋째 글자이고
\.{opera}$(a_{23\ast})$의 둘째 글자다. 그러니 이 세 낱말을 고르는 세 선택지가
모두 항목 \.{123}을 덮고, 셋 다 색이 \.{p}라야 한다.
$$
\mplibcode
beginfig(1);
  numeric tw, v; tw := 46; v := 20;
  string nm[], tok[][]; numeric pos[];
  nm[0] := "L12"; pos[0] := 3;
  tok[0][0] := "012:a"; tok[0][1] := "112:d"; tok[0][2] := "122:o";
  tok[0][3] := "123:p"; tok[0][4] := "124:t";
  nm[1] := "L13"; pos[1] := 2;
  tok[1][0] := "013:l"; tok[1][1] := "113:e"; tok[1][2] := "123:p";
  tok[1][3] := "133:e"; tok[1][4] := "134:r";
  nm[2] := "L23"; pos[2] := 1;
  tok[2][0] := "023:o"; tok[2][1] := "123:p"; tok[2][2] := "223:e";
  tok[2][3] := "233:r"; tok[2][4] := "234:a";
  for r=0 upto 2:
    label.lft(nm[r], (-10, -r*v));
    for c=0 upto 4:
      if c = pos[r]:
        fill (c*tw-4,-r*v-7)--(c*tw+30,-r*v-7)--(c*tw+30,-r*v+9)--
             (c*tw-4,-r*v+9)--cycle withcolor (1, .92, .78);
      fi
      label.rt(tok[r][c], (c*tw, -r*v));
    endfor
  endfor
  draw (pos[0]*tw+13, 13)--(pos[2]*tw+13, -2v-13) withcolor .6white;
  label.rt(btex 셋의 색이 같아야 한다 etex, (pos[2]*tw+18, -2v-16));
endfig;
\endmplibcode
$$
\figcap{{\bf 그림 2}: 낱말 \.{adopt}, \.{leper}, \.{opera}를 저마다 제 줄에 놓는 세
선택지. 칸 이름은 첨자를 정렬해 적은 것이라, 서로 다른 자리에 있는 세 글자가
모두 항목 \.{123}이 된다. 정확 덮개 해결기는 색이 어긋나는 순간 그 가지를 접는다.}

\noindent 그림에서 이름을 정렬해 적는 것이 얼마나 야무진 장치인지 보인다. 대칭을
따로 검사하는 코드가 한 줄도 없다. 이름을 정렬해 부르는 것만으로 대칭이 저절로
지켜진다.

@ 셈이 맞는지 세어 보자. 줄 $15$개가 저마다 칸 다섯 개를 건드리니 (칸,줄) 짝은
$75$개다. 다른 쪽에서 세면, 첨자가 모두 다른 칸 $\{a,b,c\}$는 ${5\choose3}=10$개이고
줄 $(a,b),(a,c),(b,c)$ 셋이 건드린다. 두 개만 같은 칸 $\{a,a,b\}$는 $5\cdot4=20$개이고
줄 $(a,a)$와 $(a,b)$ 둘이 건드린다. 셋 다 같은 칸 $\{a,a,a\}$는 $5$개이고 줄 $(a,a)$
하나뿐이다. 합하면 $10\cdot3+20\cdot2+5\cdot1=75$로 맞아떨어진다.

@ 여기에 덤이 하나 붙는다. 프로그램 \.{wordcube}는 정육면체를 다 세고 나서 ``열다섯 낱말이
모두 다른 것''을 따로 세는데, 그 셈은 항목 하나로 공짜로 얻을 수 있다. 낱말 $w$마다
{\it 색 없는\/} 보조 항목 \.{W$w$}를 만들어 그 낱말을 쓰는 선택지 열다섯에 모두
붙이면 된다. 색 없는 보조 항목은 많아야 한 번 덮이므로, 이것이 곧 ``한 낱말은 많아야
한 줄에서''라는 뜻이 된다. 명령줄에 \.{-d}를 주면 이 판을 푼다. 주지 않아도 그 수는
나온다. 해를 받아 정육면체를 지을 때 \.{wordcube}처럼 곁에서 세기 때문이다. 그러니
\.{-d}는 같은 셈을 엔진에게 떠맡기는 판이고, 두 수가 맞는지가 또 하나의 검사가 된다.

@* 항목 줄.
찍는 일은 이제 받아 적기다. 다만 찍을 곳이 두 군데다. 여느 때는 엔진에게 이어진
파이프에 찍고, \.{-p}를 주면 표준 출력에 찍는다. 그래서 이 일만은 함수 |emit|로
두어 두 곳에서 부른다. 출력이 몇 MB나 되므로 버퍼를 하나 두르고, 끝날 때 비운다.

@<함수들@>=
func emit(w io.Writer) {
	out := bufio.NewWriter(w)
	defer out.Flush()
	@<항목 줄을 찍는다@>
	@<선택지를 찍는다@>
}

@ 프로그램 전체가 함께 보는 것은 낱말과 명령줄에서 얻은 깃발들이다.

@<전역 변수@>=
var (
	words      []string                // 읽어 들인 다섯 글자 낱말
	inDict     = make(map[string]bool) // 사전에 있는 낱말인가
	wordFile   = "sgb-words.txt"
	maxWords   = nolimit // 앞에서부터 이만큼만 쓴다
	distinct   bool      // |-d|: 낱말이 겹치지 않게 한다
	dlxOnly    bool      // |-p|: DLX 파일만 찍는다
	consistent bool      // |-c|: XCCDC 엔진으로 푼다
)

@ 첫 줄은 주석이다. 어떤 파일로 어떻게 만든 것인지 적어 두면 나중에 파일만 보고도
알 수 있다. 엔진은 주석을 건너뛰므로 파이프로 흘려도 탈이 없다.

@<항목 줄을 찍는다@>=
fmt.Fprintf(out, "| word-cube-dlx %s", wordFile)
if maxWords != nolimit {
	fmt.Fprintf(out, ":%d", maxWords)
}
if distinct {
	out.WriteString(" -d")
}
out.WriteByte('\n')
@<기본 항목과 보조 항목의 이름을 찍는다@>

@ 기본 항목은 $i\le j$인 줄들이고, 보조 항목은 $a\le b\le c$인 칸들이다. 여기에
\.{-d}일 때만 낱말 항목이 붙는다.

@<기본 항목과 보조 항목의 이름을 찍는다@>=
for i := 0; i < n; i++ {
	for j := i; j < n; j++ {
		fmt.Fprintf(out, "L%d%d ", i, j)
	}
}
out.WriteByte('|')
for a := 0; a < n; a++ {
	for b := a; b < n; b++ {
		for c := b; c < n; c++ {
			fmt.Fprintf(out, " %d%d%d", a, b, c)
		}
	}
}
if distinct {
	for _, w := range words {
		fmt.Fprintf(out, " W%s", w)
	}
}
out.WriteByte('\n')

@* 선택지.
줄 $15$개와 읽어 들인 낱말 하나하나의 모든 짝마다 선택지 한 줄씩이다.

@<선택지를 찍는다@>=
for i := 0; i < n; i++ {
	for j := i; j < n; j++ {
		for _, w := range words {
			@<줄 $(i,j)$에 낱말 |w|를 놓는 선택지@>
		}
	}
}

@ 낱말의 $c$번째 글자는 칸 $\{i,j,c\}$에 놓이고, 그 글자가 곧 색이다.

@<줄 $(i,j)$에 낱말 |w|를 놓는 선택지@>=
fmt.Fprintf(out, "L%d%d", i, j)
for c := 0; c < n; c++ {
	fmt.Fprintf(out, " %s:%c", cell(i, j, c), w[c])
}
if distinct {
	fmt.Fprintf(out, " W%s", w)
}
out.WriteByte('\n')

@ 칸의 이름은 첨자 셋을 정렬해 붙여 쓴 것이다. 셋을 줄 세우는 데는 비교 세 번짜리
정렬 그물이면 넉넉하다. 한 자리 숫자로 적으므로 이 이름 짓기는 $n\le10$에서만
통한다(커누스는 열여섯 자리 십육진 숫자를 썼다). 이 함수는 항목 줄과 선택지 두
곳에서 부른다.

@<함수들@>=
func cell(i, j, c int) string {
	if i > j {
		i, j = j, i
	}
	if j > c {
		j, c = c, j
	}
	if i > j {
		i, j = j, i
	}
	return string([]byte{'0' + byte(i), '0' + byte(j), '0' + byte(c)})
}

@ 깃발 \.{-p}를 주었으면 찍기만 하고 끝낸다. 무엇을 얼마나 찍었는지는 표준 오류로
알린다. 표준 출력은 해결기에게 그대로 흘려 보내야 하므로 여기에 아무것도 섞지 않는다.

@<\.{DLX} 파일만 찍고 물러난다@>=
emit(os.Stdout)
sec := ncells
if distinct {
	sec += len(words)
}
fmt.Fprintf(os.Stderr, "낱말 %d개로 항목 %d+%d개, 선택지 %d개를 찍었다.\n",
	len(words), nlines, sec, nlines*len(words))
return

@* 춤추는 칸에 넘기기.
엔진의 메서드 |Dance|는 |io.Reader|를 받는다. 선택지가 $86{,}355$줄이나 되니
통째로 지어 놓지 말고 파이프로 흘려보내자. 고루틴 하나가 |emit|로 파이프의 쓰는
끝에 찍고, 다 찍으면 그 끝을 닫는다. 읽는 끝 |pr|는 엔진에게 넘긴다.

@<춤추는 칸으로 정육면체를 센다@>=
pr, pw := io.Pipe()
go func() {
	emit(pw)
	pw.Close()
}()
@<엔진을 고른다@>
t0 := time.Now()
count, diff := 0, 0     // 정육면체의 수와, 그중 낱말이 모두 다른 것의 수
var first [n][n][n]byte // 처음 찾은 정육면체
for sol := range eng.Dance(pr).Solutions {
	@<해를 정육면체로 도로 짓는다@>
	@<세 축의 $75$줄이 모두 사전에 있는지 본다@>
	if count == 0 {
		first = cube
	}
	count++
}
took := time.Since(t0)

@ 두 엔진 |cells.NewXCC()|와 |cells.NewXCCDC()|는 형이 다르지만, 여기서 쓰는
메서드 셋은 똑같이 갖고 있다. 그 셋만 담은 인터페이스 하나로 받으면 고르는 곳이 이
한 군데로 줄어든다.

@<엔진을 고른다@>=
var eng interface {
	Dance(io.Reader) *cells.Result
	Nodes() uint64
	Updates() uint64
}
if consistent {
	eng = cells.NewXCCDC()
} else {
	eng = cells.NewXCC()
}

@ 해는 선택지 열다섯 개다. 라이브러리는 선택지를 입력에 적은 차례 그대로 돌려주므로
자리로 찾아 읽으면 된다. 첫 이름 \.{L$ij$}에서 줄 $(i,j)$를 얻고, 이어지는 다섯 이름
\.{$abc$:$x$}의 끝 글자를 차례로 모으면 그 줄의 낱말이 된다. 낱말을 모으는 김에
겹치는지도 본다.

@<해를 정육면체로 도로 짓는다@>=
var cube [n][n][n]byte
seen := make(map[string]bool, nlines)
for _, opt := range sol {
	i, j := int(opt[0][1]-'0'), int(opt[0][2]-'0')
	var w [n]byte
	for c := 0; c < n; c++ {
		x := opt[1+c][len(opt[1+c])-1]
		w[c] = x
		@<글자 |x|를 칸 $\{i,j,c\}$의 여섯 자리에 놓는다@>
	}
	seen[string(w[:])] = true
}
if len(seen) == nlines {
	diff++
}

@ 대칭 정육면체에서는 칸 $\{i,j,c\}$의 글자가 첨자를 어떻게 늘어놓든 같다. 그러니
첨자의 순열 여섯 자리에 모두 놓는다. 이미 다른 글자가 앉아 있다면 색이 제 몫을 못
한 것이니, 그런 일은 없어야 한다---없다는 것을 여기서 확인한다.

@<글자 |x|를 칸 $\{i,j,c\}$의 여섯 자리에 놓는다@>=
for _, p := range [6][3]int{{i, j, c}, {i, c, j}, {j, i, c},
	{j, c, i}, {c, i, j}, {c, j, i}} {
	if y := cube[p[0]][p[1]][p[2]]; y != 0 && y != x {
		fmt.Fprintf(os.Stderr, "칸 %v에 %c와 %c가 부딪힌다!\n", p, y, x)
		os.Exit(1)
	}
	cube[p[0]][p[1]][p[2]] = x
}

@ 다 지었으면 세 축으로 $25$줄씩 모두 읽어 사전에 있는지 본다. 정육면체가 대칭이니
세 축의 낱말은 같은 것들이지만, 그것을 믿지 않고 세 축을 다 읽는 것이 검사의 뜻이다.

@<세 축의 $75$줄이 모두 사전에 있는지 본다@>=
for x := 0; x < n; x++ {
	for y := 0; y < n; y++ {
		var u, v, t [n]byte
		for z := 0; z < n; z++ {
			u[z], v[z], t[z] = cube[x][y][z], cube[x][z][y], cube[z][x][y]
		}
		for _, s := range [3][n]byte{u, v, t} {
			if !inDict[string(s[:])] {
				fmt.Fprintf(os.Stderr, "%s는 사전에 없다!\n", s[:])
				os.Exit(1)
			}
		}
	}
}

@ 끝으로 처음 찾은 정육면체를 그림 1처럼 $5\times5$ 낱말 표로 보이고, 센 것을
\.{wordcube}와 같은 꼴로 알린다. 그래야 두 프로그램의 출력을 나란히 놓고 볼 수 있다.

@<센 것을 알린다@>=
if count > 0 {
	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			fmt.Printf("%s ", first[i][j][:])
		}
		fmt.Println()
	}
}
fmt.Printf("대칭 단어 정육면체는 모두 %d개다", count)
fmt.Printf(" (그중 열다섯 낱말이 모두 다른 것은 %d개, 노드 %d개, 갱신 %d번, %v).\n",
	diff, eng.Nodes(), eng.Updates(), took.Round(time.Millisecond))

@* 낱말과 명령줄.
명령줄은 커누스의 것을 따른다. 낱말 파일 이름 뒤에 \.{:500}처럼 콜론과 수를 붙이면
앞에서부터 그만큼만 쓴다. 정확 덮개 쪽은 사전이 커질수록 급히 무거워지므로, 이
손잡이가 있어야 실험을 할 수 있다. 여기에 우리 것으로 깃발 셋을 더 얹었다. 낱말이
겹치지 않게 하는 \.{-d}, 엔진을 \.{XCCDC}로 바꾸는 \.{-c}, 풀지 않고 \.{DLX} 파일만
찍는 \.{-p}다.

@<명령줄을 처리한다@>=
for _, a := range os.Args[1:] {
	switch {
	case a == "-d":
		distinct = true
	case a == "-c":
		consistent = true
	case a == "-p":
		dlxOnly = true
	case strings.HasPrefix(a, "-"):
		usage()
	default:
		wordFile = a
	}
}
@<낱말 수 제한을 떼어 낸다@>

@ 콜론은 뒤에서부터 찾는다. 디렉터리 이름에 콜론이 들어 있어도 탈이 없도록.

@<낱말 수 제한을 떼어 낸다@>=
if k := strings.LastIndexByte(wordFile, ':'); k >= 0 {
	m, err := strconv.Atoi(wordFile[k+1:])
	if err != nil || m <= 0 {
		usage()
	}
	maxWords, wordFile = m, wordFile[:k]
}

@ 잘못된 명령줄을 만나면 하소연하고 물러난다. 두 곳에서 부르므로 함수로 둔다.

@<함수들@>=
func usage() {
	fmt.Fprintf(os.Stderr, "사용법: %s [-d] [-c | -p] 낱말파일[:개수]\n", os.Args[0])
	os.Exit(1)
}

@ 낱말 파일은 한 줄에 한 낱말씩이다. 길이가 $n$인 것만 골라 담되, 여기서는
\.{wordcube.w}와 달리 정렬하지 않는다. 접두사로 찾을 일이 없으니 파일에 있는
차례 그대로 두면 된다---그래야 \.{:500} 같은 제한이 ``앞에서부터 $500$개''라는
뜻으로 또렷해진다. 검사에 쓸 사전 |inDict|도 여기서 함께 채운다.

@<낱말을 읽는다@>=
f, err := os.Open(wordFile)
if err != nil {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
sc := bufio.NewScanner(f)
for sc.Scan() && len(words) < maxWords {
	if s := sc.Text(); len(s) == n {
		words = append(words, s)
		inDict[s] = true
	}
}
f.Close()
@<읽다가 탈이 났으면 접는다@>

@ 낱말이 하나도 없으면 풀어 봐야 헛일이다. 항목만 있고 선택지가 없는 문제에는
해결기가 곧바로 ``해 없음''이라 답할 뿐이다.

@<읽다가 탈이 났으면 접는다@>=
if err := sc.Err(); err != nil {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
if len(words) == 0 {
	fmt.Fprintf(os.Stderr, "파일 %s에 %d글자 낱말이 하나도 없다!\n", wordFile, n)
	os.Exit(1)
}

@* 돌려 보기.
이제 겨루기다. 그냥 돌리면 \.{XCC} 엔진이, \.{-c}를 주면 \.{XCCDC} 엔진이 푼다.
커누스의 \.{ssxcc}와 겨루려면 \.{-p}로 파일을 찍어 넘긴다.
$$\vbox{\halign{\.{#}\hfil\cr
word-cube-dlx sgb-words.txt:3000\cr
word-cube-dlx -c sgb-words.txt:3000\cr
word-cube-dlx -p sgb-words.txt > wordcube.dlx\cr
ssxcc -m 0 < wordcube.dlx\cr}}$$
셈이 맞는지부터 보자. 사전을 잘라 가며 \.{wordcube}와 맞대어 보면 개수가 똑같다.
낱말 $3000$개면 둘 다 $3$개, $3500$개면 둘 다 $83$개다. 낱말이 모두 다른 것은
$3500$개 사전에서 $60$개인데, \.{-d}를 주어 엔진에게 센 것도, 곁에서 센 것도,
\.{wordcube}가 센 것도 모두 이 수다. 엔진이 내놓은 해를 정육면체로 도로 지어
세 축 $75$줄을 사전에 비추는 검사도 한 번도 어긋나지 않는다. 자르지 않은 사전으로
끝까지 돌리면 해가 $83{,}576$개이고 그 가운데 낱말이 모두 다른 것이 $75{,}130$개다---둘
다 \.{wordcube}가 내는 수와 한 치도 다르지 않다.

@ 그런데 시간은 딴판이다. 아래는 같은 기계에서 잰 것이다(\.{ssxcc}는 커누스의 \CEE/
판이다).

\medskip
{\ninepoint\baselineskip=12pt
\halign to\hsize{\hfil#\tabskip=0pt plus1fil&\hfil#&\hfil#&\hfil#&\hfil#&
 \hfil#\tabskip=0pt\cr
\noalign{\hrule\smallskip}
낱말&정육면체&\.{wordcube} 노드&\.{wordcube} 시간&\.{ssxcc} 노드&\.{ssxcc} 시간\cr
\noalign{\smallskip\hrule\smallskip}
2000&0&72{,}056&0.08초&58{,}090&7.4초\cr
2500&0&263{,}577&0.28초&164{,}414&19.0초\cr
3000&3&851{,}588&0.88초&475{,}321&41.7초\cr
3500&83&2{,}028{,}871&2.1초&1{,}152{,}552&80.9초\cr
5757&83{,}576&98{,}042{,}779&1분 41초&57{,}113{,}536&26분 36초\cr
\noalign{\smallskip\hrule}
}}
\medskip

\noindent 눈여겨볼 것은 노드 수다. 춤추는 칸이 나무를 오히려 {\it 더 잘 친다\/}.
가장 옹색한 항목을 골라 분기하고 색을 칠할 때마다 제약이 온 사방으로 번지니, 밟는
노드가 절반 안팎이다. 맞수인 \.{wordcube}의 선행 배제도 만만치 않은 가지치기인데도 그렇다.

@ 그런데도 시간에서 크게 진다. 까닭은 노드 하나의 값이다. 칸 항목 하나에 걸린
선택지가 $3\times5757$개나 되므로, 색 한 번 칠하는 데 수천 개를 훑어야 한다.
낱말 $3000$개짜리 실행에서 노드 $475{,}321$개에 갱신이 $193$억 번, 곧 노드마다
$4$만 번꼴이었다. 이에 견주어 \.{wordcube}는 같은 일을 정렬된 사전에서 이진 탐색 {\it 한 번\/}으로
끝낸다---접두사에 맞는 낱말들이 이미 한 구간에 모여 있으니까. 범용 도구가 문제의
결을 모른다는 것이 이런 대목에서 값을 치른다.

@ 그런데 노드값이 늘 같지는 않다. 오히려 규모가 커질수록 싸진다. 낱말 $3500$개짜리
실행에서는 노드마다 갱신이 $32{,}000$번인데, 자르지 않은 사전에서는 $10{,}900$번으로
떨어진다. 탐색이 깊어질수록 이미 덮인 항목들이 남은 목록을 짧게 만들어, 색 한 번
칠하는 값이 내려가기 때문이다. 그래서 격차도 함께 좁아진다. 낱말 $2000$개에서 아흔
배가 넘던 것이 $3000$개에서 마흔일곱 배, $3500$개에서 서른아홉 배, 그리고 전체
사전에서는 열여섯 배가 된다. 그래도 열여섯 배는 열여섯 배다.

@ 이제 이 저장소의 두 엔진을 같은 기계에 올려 보자. 아래 표의 \.{XCC}와 \.{XCCDC}가
이 프로그램을 그냥, 그리고 \.{-c}를 주어 돌린 것이다. \.{ssxcc} 열은 앞 표에서
옮겨 왔다.

\medskip
{\ninepoint\baselineskip=12pt
\halign to\hsize{\hfil#\tabskip=0pt plus1fil&\hfil#&\hfil#&\hfil#&
 \hfil#\tabskip=0pt\cr
\noalign{\hrule\smallskip}
낱말&\.{ssxcc} 시간&\.{XCC} 시간&\.{XCCDC} 노드&\.{XCCDC} 시간\cr
\noalign{\smallskip\hrule\smallskip}
2000&7.4초&11.7초&4{,}327&59.0초\cr
2500&19.0초&28.7초&7{,}942&2분 17초\cr
3000&41.7초&1분 5초&13{,}534&4분 26초\cr
3500&80.9초&2분 5초&23{,}656&8분 34초\cr
5757&26분 36초&37분 14초&1{,}949{,}051&1시간 50분\cr
\noalign{\smallskip\hrule}
}}
\medskip

\noindent 엔진 \.{XCC}는 \.{ssxcc}를 \GO/로 옮긴 것이라 노드 수가 앞 표의 것과 하나도
다르지 않다. 갱신 수도 앞에서 적은 $193$억 번, 노드마다 $32{,}000$번과
$10{,}900$번과 들어맞는다. 같은 나무를 같은 차례로 밟는다는 뜻이다. 시간은 \CEE/
판의 $1.4$--$1.6$배인데, 그것이 \GO/로 옮긴 값이다.

@ 엔진 \.{XCCDC}는 이야기가 다르다. 노드가 $2000$개 사전에서 $13$분의~$1$, $3500$개에서
$49$분의~$1$, 전체 사전에서 $29$분의~$1$로 줄어든다. 이 엔진은 어떤 선택지를
{\it 쓰기만 해도\/} 다른 어느 줄에 놓을 낱말이 하나도 남지 않게 된다면 그 선택지를
미리 내버리고, 그 치움이 더 번지지 않을 때까지 되풀이한다. 정육면체에서는 줄 하나가
많게는 여덟 줄과 칸을 나눠 가지므로, 낱말 하나를 놓아 보는 일이 이웃 여덟 줄을
한꺼번에 시험하는 일이 된다. \.{wordcube}의 선행 배제를 엔진이 스스로, 그것도 모든
줄에 대해 한 겹 더 깊이 하는 셈이다.

@ 그런데 노드가 그만큼 줄어도 시간은 오히려 늘어, \.{XCC}의 세 배에서 다섯 배가 든다. 노드
하나가 훨씬 비싸기 때문이다. 선택지를 하나 버릴 때마다 그 선택지를 받침으로 삼던 다른
선택지들이 새 받침을 찾아야 하고, 그 살림이 노드마다 일어난다. 갱신 수만 보면
오히려 \.{XCCDC}가 열여섯 배쯤 적은데(낱말 $3500$개에서 $22.5$억 번 대 $371$억 번),
엔진이 희소 집합에서 칸을 맞바꾸는 일만 갱신으로 세고 받침을 찾는 일은 세지 않기
때문이다. 그래서 두 엔진의 갱신 수는 맞대어 볼 수 없다.

라이브러리의 첫 문서 \.{dcells.w}가 ``그 거래가 값을 하는지는 오롯이 문제에 달렸다''고 한 바로 그
거래다. 마디를 비싸게 사서 그 수를 줄이는데, 이 문제에서는 그 값을 못 한다. 노드값이
원래 비싼 문제에 더 비싼 노드를 얹은 꼴이다. 격차는 $2000$개에서 다섯 배, $3500$개에서
네 배, 전체 사전에서 세 배로 좁아지기는 한다. 그래도 세 배는 세 배이고, \.{wordcube}의
$1$분 $41$초에 견주면 예순여섯 배다.

@ 그러니 결론은 이렇다. 정확 덮개로 옮기는 일 자체는 훌륭하게 된다. 파일은 항목
$15+35$개로 놀랄 만큼 작고, 대칭은 이름을 정렬하는 것만으로 공짜로 지켜지며,
``모두 다른 낱말''이라는 곁가지 물음까지 항목 하나로 덤으로 딸려 온다. 옮겨 적은
것이 옳다는 것도 확인했다. 다만 노드값이 여전히 만만치 않으니, 큰 사전에서 개수를
얻는 일은 \.{wordcube} 쪽이 열여섯 배쯤 빠르다. 도메인 일관성을 지키는 엔진으로
바꾸어도 마찬가지다. 나무는 훨씬 더 잘 치지만 노드가 더 비싸서, 오히려 더 진다.

이것이 실망스러운 결말은 아니다. 커누스가 \.{word-rect-dlx.w}를 내놓은 뜻도 바로 이
겨루기를 붙여 보자는 것이었다. 어느 쪽이 이기는지는 겨뤄 봐야 아는 일이고, 진
쪽에도 배울 것이 있다---여기서는 ``나무는 더 잘 치는데 노드가 비싸다''는 것이 그
배울 거리다. \.{XCCDC}에 와서는 그 말이 한 번 더 참이 된다.

@* 색인.
