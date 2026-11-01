\input kotexgweb
\input luamplib.sty

@s bufio.Writer int

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
\.{wordcube}이고, 챔피언 자리에는 {\it 춤추는 링크\/}(dancing links)나 {\it 춤추는
칸\/}(dancing cells)이 앉는다.

@ 놀랍게도 옮겨 적은 결과가 아주 작다. 기본 항목 $15$개, 보조 항목 $35$개가 전부다.
정육면체를 다루기 까다롭게 만드는 바로 그 대칭이, 정확 덮개로 옮길 때는 오히려
문제를 줄여 준다. 어떻게 그렇게 되는지가 이 글의 알맹이고, 프로그램 자체는 그
설명을 그대로 받아 적은 것이라 짧다.

@c
package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

const (
	n     = 5                       // 정육면체 한 변, 곧 낱말 길이
	lines = n * (n + 1) / 2         // 낱말이 놓일 줄의 수, 15
	cells = n * (n + 1) * (n + 2) / 6 // 서로 다른 칸의 수, 35
	nolimit = 1 << 30               // 낱말 수를 제한하지 않았다는 뜻
)

@<전역 변수@>@;
@<함수들@>@;

func main() {
	@<명령줄을 처리한다@>@;
	@<낱말을 읽는다@>@;
	@<항목 줄을 찍는다@>@;
	@<선택지를 찍는다@>@;
	@<마무리하고 알린다@>@;
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
한 줄에서''라는 뜻이 된다. 명령줄에 \.{-d}를 주면 이 판을 찍는다.

@* 항목 줄.
찍는 일은 이제 받아 적기다. 출력이 몇 MB나 되므로 버퍼를 하나 두른다.

@<전역 변수@>=
var (
	words    []string  // 읽어 들인 다섯 글자 낱말
	wordFile = "sgb-words.txt"
	maxWords = nolimit  // 앞에서부터 이만큼만 쓴다
	distinct bool       // |-d|: 낱말이 겹치지 않게 한다
	out      *bufio.Writer
)

@ 첫 줄은 주석이다. 어떤 파일로 어떻게 만든 것인지 적어 두면 나중에 파일만 보고도
알 수 있다.

@<항목 줄을 찍는다@>=
out = bufio.NewWriter(os.Stdout)
fmt.Fprintf(out, "| word-cube-dlx %s", wordFile)
if maxWords != nolimit {
	fmt.Fprintf(out, ":%d", maxWords)
}
if distinct {
	out.WriteString(" -d")
}
out.WriteByte('\n')
@<기본 항목과 보조 항목의 이름을 찍는다@>@;

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
			@<줄 $(i,j)$에 낱말 |w|를 놓는 선택지@>@;
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

@* 낱말과 명령줄.
명령줄은 커누스의 것을 따른다. 낱말 파일 이름 뒤에 \.{:500}처럼 콜론과 수를 붙이면
앞에서부터 그만큼만 쓴다. 정확 덮개 쪽은 사전이 커질수록 급히 무거워지므로, 이
손잡이가 있어야 실험을 할 수 있다. 여기에 우리 것으로 \.{-d} 하나를 더 얹었다.

@<명령줄을 처리한다@>=
for _, a := range os.Args[1:] {
	switch {
	case a == "-d":
		distinct = true
	case strings.HasPrefix(a, "-"):
		usage()
	default:
		wordFile = a
	}
}
@<낱말 수 제한을 떼어 낸다@>@;

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
	fmt.Fprintf(os.Stderr, "사용법: %s [-d] 낱말파일[:개수]\n", os.Args[0])
	os.Exit(1)
}

@ 낱말 파일은 한 줄에 한 낱말씩이다. 길이가 $n$인 것만 골라 담되, 여기서는
\.{wordcube.w}와 달리 정렬하지 않는다. 접두사로 찾을 일이 없으니 파일에 있는
차례 그대로 두면 된다---그래야 \.{:500} 같은 제한이 ``앞에서부터 $500$개''라는
뜻으로 또렷해진다.

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
	}
}
f.Close()
@<읽다가 탈이 났으면 접는다@>@;

@ 낱말이 하나도 없으면 찍어 봐야 헛일이다. 항목만 있고 선택지가 없는 \.{DLX}
파일은 해결기가 곧바로 ``해 없음''이라 답할 뿐이다.

@<읽다가 탈이 났으면 접는다@>=
if err := sc.Err(); err != nil {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
if len(words) == 0 {
	fmt.Fprintf(os.Stderr, "파일 %s에 %d글자 낱말이 하나도 없다!\n", wordFile, n)
	os.Exit(1)
}

@ 다 찍었으면 버퍼를 비우고, 무엇을 얼마나 찍었는지 표준 오류로 알린다. 표준 출력은
해결기에게 그대로 흘려 보내야 하므로 여기에 아무것도 섞지 않는다.

@<마무리하고 알린다@>=
out.Flush()
sec := cells
if distinct {
	sec += len(words)
}
fmt.Fprintf(os.Stderr, "낱말 %d개로 항목 %d+%d개, 선택지 %d개를 찍었다.\n",
	len(words), lines, sec, lines*len(words))

@* 돌려 보기.
이제 겨루기다. 만든 파일을 춤추는 칸 해결기에 넘긴다.
$$\vbox{\halign{\.{#}\hfil\cr
word-cube-dlx sgb-words.txt > wordcube.dlx\cr
ssxcc -m 0 < wordcube.dlx\cr}}$$
셈이 맞는지부터 보자. 사전을 잘라 가며 \.{wordcube}와 맞대어 보면 개수가 똑같다.
낱말 $3000$개면 둘 다 $3$개, $3500$개면 둘 다 $83$개다. 여기에 \.{-d}를 준 판은 $3500$개
사전에서 $60$개를 내는데, 이것도 \.{wordcube}가 ``모두 다른 것''으로 센 수와 같다.
해결기가 내놓은 해를 받아 $5\times5\times5$ 배열을 도로 짓고 세 축 $75$줄이 모두
사전에 있는지 따로 확인해 보아도 어긋나는 것이 없다. 자르지 않은 사전으로 끝까지
돌리면 해가 $83{,}576$개다---\.{wordcube}가 내는 수와 한 치도 다르지 않다.

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

@ 그러니 결론은 이렇다. 정확 덮개로 옮기는 일 자체는 훌륭하게 된다. 파일은 항목
$15+35$개로 놀랄 만큼 작고, 대칭은 이름을 정렬하는 것만으로 공짜로 지켜지며,
``모두 다른 낱말''이라는 곁가지 물음까지 항목 하나로 덤으로 딸려 온다. 옮겨 적은
것이 옳다는 것도 확인했다. 다만 노드값이 여전히 만만치 않으니, 큰 사전에서 개수를
얻는 일은 \.{wordcube} 쪽이 열여섯 배쯤 빠르다.

이것이 실망스러운 결말은 아니다. 커누스가 \.{word-rect-dlx.w}를 내놓은 뜻도 바로 이
겨루기를 붙여 보자는 것이었다. 어느 쪽이 이기는지는 겨뤄 봐야 아는 일이고, 진
쪽에도 배울 것이 있다---여기서는 ``나무는 더 잘 치는데 노드가 비싸다''는 것이 그
배울 거리다.

@* 색인.
