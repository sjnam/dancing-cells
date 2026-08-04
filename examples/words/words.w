\input kotexgweb
\input pic

\def\title{다섯 단어로 스물네 글자}

@s Option int
@s Reader int

@* 다섯 단어로 스물네 글자.
스탠퍼드 그래프베이스(Stanford GraphBase)에 딸려 오는 \.{sgb-words.txt}에는
다섯 글자짜리 영어 단어 5757개가 쓰임새 잦은 차례로 한 줄에 하나씩 들어 있다.
이 목록을 앞에 놓고 던지는 물음이 오늘의 문제다.
$$\hbox{\it 알파벳 스물여섯 자 가운데 스물네 자를 덮는 다섯 단어가 있는가?}$$
다섯 단어면 글자 칸이 스물다섯이다. 그 스물다섯 칸으로 서로 다른
스물네 글자를 덮으려면 셈이 딱 한 가지로 맞아떨어져야 한다. 한 글자만 두 번
나오고, 스물세 글자는 한 번씩 나오며, 알파벳 두 자는 아예 쓰이지 않는다.
다른 배분은 없다.

왜 하필 스물넷일까. 스물다섯이 훨씬 깔끔했을 것이다. 다섯 단어가 글자를 하나도
나눠 갖지 않으면 스물다섯 글자가 통째로 덮이니까. 그런데 SGB 목록에는 그런 다섯
뭉치가 하나도 없다. 하나도.

넷까지는 오히려 헐렁하다. 글자를 전혀 겹치지 않는 네 단어로 스무 글자를 덮는
방법은 1{,}781{,}773가지나 된다. 그러다 다섯 번째 단어에서 벽에 부딪히는 것이다.
그래서 한 글자만 양보하기로 하면---스물다섯 칸 가운데 한 칸을 버리기로
하면---답이 8132가지 쏟아진다. 이 프로그램이 세어 줄 숫자들이다.

이것은 전형적인 덮개(covering) 문제이고, 이 저장소의 춤추는
칸(dancing cells) 엔진이 바로 그런 문제를 위한 것이다. 그러니 힘든 대목은 탐색이
아니라 번역이다. 무엇을 아이템으로 삼고 무엇을 옵션으로 삼아 DLX 입력을 지을
것인가.

답을 미리 말해 두면, 다중도(multiplicity)는 한 번도 쓰지 않는다. 색깔 있는
정확 덮개, 곧 순수한 XCC만으로 ``단어를 정확히 다섯 개 고르라''까지 저절로
강제된다. 그 요령이 이 글의 알맹이다. 프로그램의 뼈대는 번역 과정을 그대로
따라간다.

@c
package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"sort"
	"strconv"
	"strings"

	cells "github.com/sjnam/dancing-cells"
)
@<아이템과 색깔의 이름@>

@<함수들@>

func main() {
	@<명령줄을 읽는다@>
	@<단어 파일을 읽어 글자집합으로 묶는다@>
	@<덮개 문제를 풀어 답을 보여 준다@>
}

@ 명령줄은 단어 파일과, 보여 줄 해의 개수를 받는다. 개수를 0으로 주면 끝까지
세는데 40초쯤 걸린다. 첫 답은 눈 깜짝할 사이에 나온다.

@<명령줄을 읽는다@>=
if len(os.Args) < 2 {
	log.Fatalf("사용법: %s 단어파일 [보여 줄 해의 수]\n", os.Args[0])
}
limit := 10
if len(os.Args) > 2 {
	n, err := strconv.Atoi(os.Args[2])
	if err != nil {
		log.Fatal(err)
	}
	limit = n
}

@* 단어를 글자집합으로.
아이템이 알파벳 스물여섯 자라면 옵션이 볼 수 있는 것은 단어의 {\it 글자
집합\/}뿐이다. \.{alert}와 \.{alter}와 \.{later}는 이 문제에서 완전히 같은
물건이다. 그러니 애초에 단어를 글자집합으로 뭉쳐 두고, 답을 낼 때 다시 단어로
풀어놓는 편이 낫다. 5757개가 4198개로 줄어든다.

같은 글자집합인 단어 둘을 함께 고를 일은 어차피 없다. 그랬다가는 다섯 글자가
통째로 겹쳐 스무 글자밖에 못 덮는다. 그러니 뭉쳐도 잃는 답이 없다.

글자집합의 크기는 5 아니면 4, 드물게 그보다 작다. \.{crumb}처럼 다섯 글자가
다 다르면 5이고, \.{abbey}처럼 한 글자가 두 번 나오면 4이며, \.{esses}까지 가면
2다. 세어 보면 5인 것이 2845개, 4인 것이 1210개, 3 이하가 143개다. 크기가 3
이하인 글자집합은 답에 낄 수 없는데, 왜 그런지는 다음 장의 셈이 말해 준다.

@ 글자집합은 사전순으로 늘어놓은 문자열로 나타낸다. 그러면 그대로 지도의
열쇠가 되고, 동시에 옵션 줄에 적을 아이템 이름들이기도 하다. 일석이조다.

@<함수들@>=
func letterSet(w string) string {
	var seen [26]bool
	b := make([]byte, 0, len(w))
	for i := 0; i < len(w); i++ {
		if !seen[w[i]-'a'] {
			seen[w[i]-'a'] = true
			b = append(b, w[i])
		}
	}
	sort.Slice(b, func(i, j int) bool { return b[i] < b[j] })
	return string(b)
}

@ 읽어들인 결과는 글자집합에서 단어 목록으로 가는 지도다. \.{aelrt}를 물으면
\.{alert}, \.{alter}, \.{later}가 한꺼번에 나온다.
@<단어 파일을 읽어 글자집합으로 묶는다@>=
f, err := os.Open(os.Args[1])
if err != nil {
	log.Fatal(err)
}
defer f.Close()
cls := make(map[string][]string)
sc := bufio.NewScanner(f)
for sc.Scan() {
	w := strings.TrimSpace(sc.Text())
	@<다섯 글자 소문자 낱말이 아니면 건너뛴다@>
	cls[letterSet(w)] = append(cls[letterSet(w)], w)
}
if err := sc.Err(); err != nil {
	log.Fatal(err)
}

@ 목록에는 소문자 다섯 글자짜리만 들어 있지만, 남이 준 파일도 받을 수 있으니
한 번 살펴 둔다.
@<다섯 글자 소문자 낱말이 아니면 건너뛴다@>=
if len(w) != 5 {
	continue
}
if strings.IndexFunc(w, func(c rune) bool { return c < 'a' || c > 'z' }) >= 0 {
	continue
}

@* 문제를 정확 덮개로 옮기기.
답의 생김새는 앞에서 보았다. 한 글자는 두 번, 스물세 글자는 한 번, 두 글자는 영
번. 이것을 정확 덮개로 옮기자면 세 가지를 말할 수 있어야 한다. {\it 어느 두
글자를 버리는가}, {\it 어느 글자가 두 번 쓰이는가}, 그리고 {\it 단어는 정확히
다섯 개인가}.

앞의 둘은 아이템 하나씩으로 간단히 처리된다. 재미있는 것은 셋째다. 단어의
개수를 세는 장치를 따로 두지 않아도, 아이템 개수의 셈이 저절로 다섯을
강제한다.

@ 아이템은 이렇게 넷이다. 그러므로 아이템 줄은
`\.{a b c \dots\ z 빠진쌍 겹침 \| 겹친글자}'가 된다.
\smallskip
{\parindent2em
\item{$\bullet$} 알파벳 스물여섯 자 \.{a}부터 \.{z}까지. 모두 주
아이템이므로 저마다 정확히 한 번 덮인다.
\item{$\bullet$} \.{빠진쌍}. 주 아이템. 쓰이지 않는 두 글자를 지목하는 옵션이
딱 하나 뽑히게 만든다.
\item{$\bullet$} \.{겹침}. 주 아이템. 두 번 쓰인 글자가 어디서 비롯했는지
밝히는 옵션이 딱 하나 뽑히게 만든다.
\item{$\bullet$} \.{겹친글자}. 부 아이템이며 색을 받는다. 두 번 쓰인 글자가
무엇인지를 여러 옵션이 서로 합의하게 만든다.
}

@ 옵션은 다섯 갈래다. 글자집합을 $S$라 하자.
\smallskip
{\parindent=2em
\item{1.} $S$가 다섯 자인 {\it 온전한 단어}. 제 다섯 글자를 그대로 덮는다.
\item{2.} $S$가 다섯 자인 단어가 글자 $x$를 {\it 양보한 것}. $S$에서 $x$만 뺀
넉 자를 덮고 \.{겹친글자}를 $x$로 칠한다. ``나는 $x$를 쓰지만 $x$ 아이템은
남에게 맡긴다''는 뜻이다. 단어마다 다섯 개씩 생긴다.
\item{3.} $S$가 넉 자인 단어, 곧 {\it 제 안에서 글자가 겹치는 단어}. 넉 자를
덮고 \.{겹침}도 덮으며 \.{겹친글자}를 마침표로 칠한다.
\item{4.} {\it 겹친 글자} $x$를 밝히는 옵션. 아이템 $x$와 \.{겹침}을 덮고
\.{겹친글자}를 $x$로 칠한다. 스물여섯 개다.
\item{5.} {\it 빠진 쌍} $\{u,v\}$. 아이템 $u$와 $v$, 그리고 \.{빠진쌍}을
덮는다. 삼백스물다섯 개다.\par}

@ 이제 셈이다. \.{빠진쌍}이 주 아이템이니 5번 옵션은 정확히 하나 뽑힌다. 두
글자가 빠지고, 나머지 스물네 글자는 단어 쪽에서 덮여야 한다. \.{겹침}도 주
아이템이니 3번이나 4번 옵션이 정확히 하나 뽑힌다. 여기서 길이 둘로 갈린다.

{\hangindent=1em\hangafter=1\noindent
{\bf 4번이 뽑힌 경우} 그 옵션이 글자 하나를 덮으니 단어들이 덮을 몫은
$26-2-1=23$이다. 1번은 다섯 자, 2번은 넉 자를 덮으므로 온전한 단어를 $b$개,
양보한 단어를 $a$개 골랐다면 $5b+4a=23$이어야 하는데, 음이 아닌 정수 해는
$b=3$, $a=2$ 하나뿐이다. 단어 다섯 개다.\par}
{\hangindent=1em\hangafter=1\noindent
{\bf 3번이 뽑힌 경우} 그 단어가 넉 자를 덮으니 남은 몫은 $26-2-4=20$이다.
게다가 3번 옵션이 \.{겹친글자}를 마침표로 칠해 두었으므로, 색이 글자인 2번
옵션은 곁에 올 수 없다. 남은 것은 1번뿐이니 $5b=20$, 곧 $b=4$. 이번에도 단어
다섯 개다.\par}

@ 셈이 맞는다고 답이 맞는 것은 아니니 한 걸음 더 따져 두자. 4번이 뽑힌 경우,
양보한 단어 둘은 \.{겹친글자}의 색을 4번 옵션과 맞춰야 하므로 둘 다 같은 글자
$x$를 양보한 것이다. 그리고 아이템 $x$는 4번 옵션이 이미 덮었으니, 다른 어떤
단어도 $x$를 품을 수 없다. 온전한 단어는 제 글자를 빠짐없이 덮기 때문이다.
따라서 $x$는 그 두 단어에 꼭 한 번씩, 통틀어 두 번 쓰인다. 스물다섯 칸 가운데
두 칸이 $x$이고 스물세 칸이 나머지 글자이니, 서로 다른 스물네 글자다.

3번이 뽑힌 경우에는 두 번 쓰인 글자가 그 단어 안에 들어 있다. 나머지 넷은
서로도 겹치지 않고 그 단어와도 겹치지 않으니, 역시 스물네 글자다.

@ 이 셈에서 두 가지가 따라 나온다. 첫째, 크기가 3 이하인 글자집합으로는 아무
옵션도 짓지 않는다. 그런 단어가 끼면 덮는 몫이 셋 이하로 줄어 위의 두 식이 단어
여섯 개 이상을 요구하기 때문이다. 쓸 데가 없으니 애초에 만들지 않는다.

둘째, 크기가 4인 글자집합에는 2번(양보) 옵션을 짓지 않는다. 지을 수야 있지만
그러면 3번으로 이미 찾은 답을 다시 찾게 되어 같은 답이 두 번 나온다. 짓지
않아도 잃는 답은 없다. 한 글자가 두 단어에 걸쳐 겹치는 답에서는 다섯 단어가
모두 서로 다른 다섯 글자를 가져야 하니까.

@ 그림 하나로 정리하자.

\medskip
\centerline{\pic{words-1.pdf}}
\smallskip
\centerline{그림 1: 답 하나를 정확 덮개로 본 모습.}
\medskip

\noindent 칸 스물여섯 개가 아이템이고 묶음 일곱 개가 뽑힌 옵션이다. 회색은
글자를 하나 양보한 단어인데, \.{frock}과 \.{vowed}가 나란히 \.{o}를 양보했다.
짙은 칸이 그 겹친 글자이고 점선이 빠진 쌍이다. $5+5+5+4+4+1+2=26$, 아귀가 맞는다.

@* DLX 입력 짓기.
셈이 끝났으니 이제 옮겨 적기만 하면 된다. 아이템 이름은 여러 바이트짜리
문자열이어도 좋으므로 한글을 그대로 쓴다. 그 편이 답을 눈으로 읽기에도 낫다.

@<아이템과 색깔의 이름@>=
const (
	dropped = "빠진쌍"
	source  = "겹침"
	shared  = "겹친글자"
	inside  = "."
)

@ 옵션 줄은 아이템 이름을 빈칸으로 갈라 늘어놓은 것이니, 글자집합 \.{abcde}를
\.{a b c d e}로 벌려 놓는 잔손질이 필요하다.

@<함수들@>=
func spread(s string) string {
	b := make([]byte, 0, 2*len(s))
	for i := 0; i < len(s); i++ {
		if i > 0 {
			b = append(b, ' ')
		}
		b = append(b, s[i])
	}
	return string(b)
}

@ |Dance|는 |io.Reader|를 받는다. 옵션이 18631줄이나 되니 통째로 지어 놓지 말고
파이프로 흘려보내자. 푸는 쪽이 읽는 만큼만 짓게 된다. 읽는 끝 |pr|는 다음 장에서
|Dance|에게 넘긴다.

@<문제를 파이프로 흘려보낸다@>=
@<글자집합을 크기별로 갈라 정렬한다@>
pr, pw := io.Pipe()
go func() {
	bw := bufio.NewWriter(pw)
	defer func() {
		bw.Flush()
		pw.Close()
	}()
	@<아이템 줄을 쓴다@>
	@<단어 옵션을 쓴다@>
	@<겹침 옵션을 쓴다@>
	@<빠진 쌍 옵션을 쓴다@>
}()

@ 옵션을 지을 때 크기가 5인 것과 4인 것을 달리 다루므로 미리 갈라 둔다. 지도를
훑는 차례는 들쭉날쭉하니 정렬해서 입력이 늘 같게 만든다.
@<글자집합을 크기별로 갈라 정렬한다@>=
var full, repeat []string
for s := range cls {
	switch len(s) {
	case 5:
		full = append(full, s)
	case 4:
		repeat = append(repeat, s)
	}
}
sort.Strings(full)
sort.Strings(repeat)

@ 주 아이템을 먼저 늘어놓고, 세로줄 뒤에 부 아이템 하나를 놓는다.

@<아이템 줄을 쓴다@>=
for c := byte('a'); c <= 'z'; c++ {
	fmt.Fprintf(bw, "%c ", c)
}
fmt.Fprintf(bw, "%s %s | %s\n", dropped, source, shared)

@ 다섯 글자가 다 다른 단어 하나에서 온전한 옵션 하나와 양보 옵션 다섯이 한꺼번에
나온다. 2845개가 17070줄이 되는 셈이다.

@<단어 옵션을 쓴다@>=
for _, s := range full {
	fmt.Fprintln(bw, spread(s))
	for i := range len(s) {
		fmt.Fprintf(bw, "%s %s:%c\n", spread(s[:i]+s[i+1:]), shared, s[i])
	}
}

@ 겹침을 밝히는 옵션은 두 갈래다. 제 안에서 글자가 겹치는 단어와, 두 단어에
걸쳐 겹치는 글자. 앞의 것은 색이 마침표이고 뒤의 것은 색이 그 글자다.

@<겹침 옵션을 쓴다@>=
for _, s := range repeat {
	fmt.Fprintf(bw, "%s %s %s:%s\n", spread(s), source, shared, inside)
}
for c := byte('a'); c <= 'z'; c++ {
	fmt.Fprintf(bw, "%c %s %s:%c\n", c, source, shared, c)
}

@ 빠진 쌍은 순서 없는 두 글자이므로 $u<v$인 것만 짓는다.

@<빠진 쌍 옵션을 쓴다@>=
for u := byte('a'); u <= 'z'; u++ {
	for v := u + 1; v <= 'z'; v++ {
		fmt.Fprintf(bw, "%c %c %s\n", u, v, dropped)
	}
}

@* 답을 사람 말로 옮기기.
남은 일은 풀고, 돌아온 답을 사람이 읽을 수 있게 옮기는 것이다.
돌아오는 해는 |[]cells.Option|이고 옵션 하나는 아이템 이름의 목록이다. 색칠한
부 아이템은 이름과 색을 쌍점으로 이어 온다. 우리가 지은 옵션이 다섯 갈래뿐이니
되읽기도 그만큼 간단하다.

@ 탐색은 고루틴에서 돌며 해를 하나씩 채널로 보낸다. 보여 줄 만큼만 보고
그만두려면 문맥을 끊으면 된다.
@<덮개 문제를 풀어 답을 보여 준다@>=
ctx, cancel := context.WithCancel(context.Background())
defer cancel()
@<문제를 파이프로 흘려보낸다@>
xc := cells.NewXCC().WithContext(ctx)
res := xc.Dance(pr)
total := 0
for sol := range res.Solutions {
	@<해 하나를 적는다@>
	if limit > 0 && total >= limit {
		cancel()
		break
	}
}
fmt.Printf("해 %d개\n", total)

@ 엔진이 보내오는 해는 글자집합 뭉치이지 단어 뭉치가 아니다. 자리마다 그
글자집합을 쓰는 단어가 여럿 걸려 있을 수 있으니---\.{ackst}에는 \.{stack}과
\.{tacks}가 함께 걸려 있다---뽑힌 옵션을 뜯어 자리마다 후보 목록을 세워 두고,
조합을 하나씩 펼쳐 찍는다. 그래야 찍히는 줄 수가 곧 답의 가짓수가 된다.
@<해 하나를 적는다@>=
var cands [][]string
var gone, note string
src := -1
for _, opt := range sol {
	var letters, color string
	isPair, isSource := false, false
	@<옵션 하나를 뜯어본다@>
	@<뜯어본 옵션을 제자리에 놓는다@>
}
@<후보를 하나씩 바꿔 가며 찍는다@>

@ 한 글자짜리 이름은 알파벳 아이템이니 이어 붙이면 글자집합이 되고, 나머지는
우리가 지은 이름 셋 가운데 하나다.

@<옵션 하나를 뜯어본다@>=
for _, item := range opt {
	name, c, colored := strings.Cut(item, ":")
	switch {
	case colored:
		color = c
	case name == dropped:
		isPair = true
	case name == source:
		isSource = true
	default:
		letters += name
	}
}

@ 양보 옵션은 넉 자만 덮으므로, 양보한 글자를 색에서 되찾아 붙여야 원래
글자집합이 나온다. 그러고 나면 지도가 그 자리의 후보 단어들을 돌려준다. 제 안에서
글자가 겹치는 단어는 몇 째 자리인지 |src|에 적어 둔다. 그 자리에 어느 후보가
오느냐에 따라 겹침을 설명하는 말도 달라지기 때문이다.

@<뜯어본 옵션을 제자리에 놓는다@>=
switch {
case isPair:
	gone = strings.Join(strings.Split(letters, ""), " ")
case isSource && color != inside:
	note = color + "를 두 번"
case isSource:
	src = len(cands)
	cands = append(cands, cls[letters])
default:
	cands = append(cands, cls[letterSet(letters+color)])
}

@ 후보를 자리마다 하나씩 골라 보는 일은 자릿수마다 밑이 다른 수를 세는 것과
같다. |idx|를 그런 계수기로 삼아 맨 끝자리부터 올린다.

@<후보를 하나씩 바꿔 가며 찍는다@>=
idx := make([]int, len(cands))
for limit <= 0 || total < limit {
	@<이번 조합을 한 줄로 찍는다@>
	@<다음 조합으로 넘어간다@>
}

@ 겹침을 설명하는 말은 줄을 정렬하기 {\it 전에\/} 지어야 한다. 정렬하고 나면
|src| 자리가 어디로 갔는지 알 수 없기 때문이다.

@<이번 조합을 한 줄로 찍는다@>=
pick := make([]string, len(cands))
for i, c := range cands {
	pick[i] = c[idx[i]]
}
mark := note
if src >= 0 {
	mark = pick[src] + " 안에서 겹침"
}
sort.Strings(pick)
fmt.Printf("%s   (%s, %s 빠짐)\n", strings.Join(pick, " "), mark, gone)
total++

@ 맨 끝자리를 올리다가 넘치면 0으로 되돌리고 한 자리 앞으로 간다. 맨 앞자리까지
넘쳤다면 이 해의 조합을 다 본 것이다.

@<다음 조합으로 넘어간다@>=
i := len(idx) - 1
for i >= 0 && idx[i] == len(cands[i])-1 {
	idx[i] = 0
	i--
}
if i < 0 {
	break
}
idx[i]++

@* 마치며.
돌려 보면 이렇다.

$$\vbox{\halign{\tt#\hfil&\quad#\hfil\cr
frock glitz nymph squab vowed&\.{o}를 두 번 쓰고 \.{j}, \.{x}를 버렸다\cr
frock squab veldt whomp zingy&마찬가지\cr
frock glitz nymph squab vexed&\.{vexed} 안에서 겹치고 \.{j}, \.{w}를 버렸다\cr
foxed glitz nymph squab wreck&\.{e}를 두 번 쓰고 \.{j}, \.{v}를 버렸다\cr
fjord glitz nymph squab wreck&\.{r}를 두 번 쓰고 \.{v}, \.{x}를 버렸다\cr}}$$

\noindent 끝까지 찍으면 9592줄, 곧 답이 9592가지다. 엔진이 보내온 해는 8132개인데
애너그램을 펼치며 그만큼 늘었다. 옵션은 18631개, 아이템은 주 스물여덟 개와 부
하나. 색깔이 다중도 노릇을 대신해 준 덕분에 MCC는 부르지 않았다.

@ 앞에서 미뤄 둔 이야기 둘을 갚자.
스물다섯 글자를 덮는 다섯 단어는 없다. 확인하기는 오히려 더 쉬워서, 양보 옵션과
겹침 옵션을 통째로 빼고 빠진 쌍 대신 빠진 글자 하나를 지목하는 옵션 스물여섯
개를 두면 된다. 그러면 $26-1=25=5b$에서 $b=5$가 되어 서로 글자를 나눠 갖지 않는
다섯 단어를 찾게 되는데, 답이 0가지다.

네 단어로 스무 글자를 덮는 문제는 빠진 글자가 여섯이나 되어 ``빠진 쌍'' 수법이
버거워진다. 그때는 알파벳을 통째로 부 아이템으로 돌리고---부 아이템은 덮이지
않아도 좋으니까---단어를 세는 아이템 하나만 두어 그 다중도를 넷으로 못박는 편이
낫다. 이번에는 MCC가 제격인 셈이다.

그렇게 세면 1{,}781{,}773가지인데, 여기서는 애너그램을 뭉치지 않고 단어 하나하나를
옵션으로 두어야 나오는 수다. 글자집합으로 뭉쳐 세면 1{,}155{,}874가지다. 스물네
글자 문제에서 8132와 9592가 갈렸던 것과 똑같은 사정이다.

@* 색인.
