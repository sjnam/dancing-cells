\input kotexgweb

\def\title{Dancing Cells and ZDDs}

@s Func int
@s ZDD int
@s big.Int int
@s Seq int
@s Rand int
@s Reader int
@s Builder int
@s Option int

@** 들어가며.
패키지 |dcells|의 세 엔진은 해를 하나씩 건네준다. 답이 백 개쯤인 퍼즐에는 알맞은
모양이고, $10^{16}$개인 퍼즐에는 틀린 모양이다. 들여다볼 수도 없고, 들여다보아
셀 수도 없으며, 들여다보아 가장 좋은 것을 골라낼 수야 더욱 없다. 이 프로그램은
해를 하나도 적어 내지 않고 그런 물음에 답한다. 다른 엔진들이 읽는 것과 같은
{\tt DLX} 입력을 읽고 {\it ZDD\/}를, 곧 그 경로가 바로 정확 덮개인 영 억제 결정
다이어그램을 돌려준다.

이것을 되게 하는 착상이 둘인데 우리 것이 아니다. 첫째는 Masaaki Nishino, Norihito
Yasuda, Shin-ichi Minato, Masaaki Nagata의 것으로, 그들의 ``Dancing with decision
diagrams'' [{\sl AAAI\/ \bf31} (2017), 868--874]는 옵션 몇 개를 고르고 남은 부분
문제가 {\it 어느 아이템이 남았느냐\/}에만 달렸을 뿐 고른 차례에는 달리지 않았음을
짚었다. 그러니 이제껏 푼 부분 문제를 기억하는 탐색은 같은 것을 두 번 풀 까닭이
없다. 크누스는 그것을 {\tt DLX6}에 넣고 색깔까지 아우르도록 늘였다. 둘째 착상은
부분 문제의 답이 수가 아니라 {\it 집합족\/}이라는 것이고, ZDD가 바로 집합족을
위한 것이다. 우리 ZDD는 패키지 |bdd|(\.{github.com/sjnam/bdd})에서 오는데, 크누스의
{\tt BDD15}를 Go로 옮긴 것이다. 그러니 이 이야기의 두 짝인 {\sl TAOCP\/} 7.2.2.1과
7.1.4가 한 프로그램에서 만나는 셈이다.
@^Nishino, Masaaki@>
@^Yasuda, Norihito@>
@^Minato, Shin-ichi@>
@^Nagata, Masaaki@>
@^Knuth, Donald Ervin@>

@ 그것이 값을 하는지는 엔진이 아니라 문제의 성질이고, 이 프로그램에 손을 뻗기
전에 대놓고 말해 두는 편이 낫다. 아래 표의 셋째 칸은 이 엔진이 들르는 탐색
마디의 수이고, 마지막 칸은 캐시를 아예 두지 않은 다른 엔진들이 들르는 수를 그것으로
나눈 값이다. 가장 큰 판 둘의 마지막 칸은 어림값인데, $5.3\times10^{16}$개의 타일
깔기를 세어 보겠다고 나설 사람이 없기 때문이다.
$$\vbox{\halign{\hfil\tt#\quad&\hfil#\hfil\quad&\hfil#\hfil\quad&\hfil#\cr
\omit\hfil{\rm 문제}\hfil\quad&{\rm 해의 수}&{\rm 탐색 마디}&
   {\rm 아낌}\cr
\noalign{\smallskip\hrule\smallskip}
domino 8$\times$8&12{,}988{,}816&2{,}317&21{,}600$\times$\cr
domino 10$\times$10&258{,}584{,}046{,}368&13{,}560&$7.4\times10^7$\cr
domino 12$\times$12&$5.3\times10^{16}$&74{,}023&$2.8\times10^{12}$\cr
pentominoes 6$\times$10&9{,}356&822{,}828&1.5$\times$\cr
langford 11&17{,}792&130{,}724&1.3$\times$\cr
8 queens&92&869&1.1$\times$\cr}}$$
그 수들 뒤의 규칙은 단출하다. 캐시는 맨 탐색이 이미 푼 부분 문제에 다시 썼을 품을
아껴 주므로, 그 탐색의 마디 수가 그 가운데 {\it 서로 다른\/} 부분 문제의 수를
넘어서는 배수만큼 이긴다. 고른 모양의 판을 타일로 덮는 문제는 작고 서로 상관없는
조각으로 나뉘고 해가 천문학적으로 많으니, 거의 모든 부분 문제가 되풀이된다.
펜토미노 열둘은 모두 다르므로 되풀이되는 것이 거의 없고, 1.5배를 아끼자고 서명
700{,}000개짜리 캐시를 무는 것은 밑지는 거래다. 그런 것에는 다른 엔진을 쓰라.

@ 다이어그램을 짓고 그 값으로 얻는 것은 나중에 무엇이든 물어볼 수 있는 힘이다.
세는 일은 DAG를 한 번 걷는 일이니 $5.3\times10^{16}$개의 타일 깔기가 1초도 안 되어
세어지고, 무게를 아무렇게나 주고 가장 무거운 해를 고르는 일도 또 한 번의 걸음이라
$2.6\times10^{11}$개 가운데 가장 좋은 것을 1밀리초 안에 찾으며, 고르게 무작위인
해도 세 번째 걸음이다. 어느 것도 낱낱이 세어서는 될 일이 아니다. 이 패키지는
다이어그램을 |bdd| 손잡이와 함께 건네주므로, 그 패키지가 할 수 있는 일---다른
집합족과의 합집합, 제한, 다이어그램을 줄이는 재배치---도 모두 쓸 수 있다.
@c
// zdd 패키지는 정확 덮개 문제의 모든 해를 ZDD 하나로 나타낸다.
package zdd

import (
	"bufio"
	"fmt"
	"io"
	"iter"
	"math/big"
	"math/rand/v2"
	"os"
	"strings"

	"github.com/sjnam/bdd"
	cells "github.com/sjnam/dancing-cells"
)

@<풀이기@>
@<다이어그램@>
@<입력 단계@>

@** 서명.
모든 것은 탐색 상태 둘이 언제 같은 상태인지를 가리는 데 달렸다. 크누스의 답은,
그리고 우리 답은 {\it 서명\/}이다. 앞날이 기대는 몫만 뽑아 표준 모양으로 적은
것이다.

어떤 옵션이 지금의 부분 문제에 살아남는 것은, 덮인 주 아이템을 하나도 담지 않고
씻긴 부 아이템마다 그 색에 뜻을 모을 때와 꼭 같다. 그것은 아이템만을 두고 하는
말이고 고른 옵션은 거기 나오지 않으니, 살아남은 옵션은 아이템 상태의 함수이며
서명이 적어 두어야 할 것은 아이템 상태가 전부다. 같은 아이템 상태에 닿은 두 가지는
살아남은 옵션의 집합이 같고 따라서 해의 집합족도 같으니, 하나는 다른 하나의 메모로
답해도 된다.

@ 거기 드는 아이템은 세 갈래다.

{\it 살아 있는 주\/} 아이템은 제 번호로 적힌다. {\it 살아 있는 부\/} 아이템도
적히되, 살아남은 옵션이 아직 그것을 대고 있는 동안만이다. 집합이 한 번 비고 나면
그 아이템은 다시는 무엇도 옭아맬 수 없으니, 그것을 적어 두면 실은 같은 상태인
것들이 갈라진다. 희소 집합이 그 시험을 거저 내주는데, |size(x)|가 곧 아이템 |x|에
살아남은 옵션의 수이기 때문이다.

{\it 씻긴\/} 부 아이템이 까다로운 쪽이다. 그것은 더는 살아 있지 않지만---이 엔진도
{\tt SSXCC}처럼 옵션이 아이템에 매달리는 순간 그것을 물린다---씻긴 그 색이 여전히
옵션을 걸러 내므로, 제 색을 달고 서명에 나와야 한다. 색 없이 덮인 아이템은 적을
것이 없다. 아무도 그것을 다시 쓸 수 없고, 그것은 사라졌다는 말과 같다.

@ 적는 모양은 표준이어야 하는데, 뻔해 보이는 적는 법은 그렇지 못하다. 희소 집합은
탐색이 도는 동안 배열 |item|을 뒤섞으므로, 똑같은 상태 둘이 제 아이템을 서로 다른
차례로 내놓을 수 있다. 그래서 우리는 아이템 {\it 번호\/}를 1부터 |itemlen|까지
차례로 걸으며 하나씩 찾아보는데, 배열 |itemBase|가 있는 까닭이 그것이다. 칸
하나하나는 가변 정수가 된다. 그저 있기만 한 아이템은 |2i|이고, 씻긴 아이템은
|2i+1| 뒤에 그 색이 따른다.
@<서명 짓기@>=
func (s *Solver) signature() string {
	s.sig = s.sig[:0]
	for i := 1; i <= s.itemlen; i++ {
		x := int(s.itemBase[i])
		switch {
		case s.pos(x) < s.active:
			if x < s.second || s.size(x) > 0 {
				s.sig = varint(s.sig, 2*i)
			}
		case x >= s.second && s.clr[i] != 0:
			s.sig = varint(s.sig, 2*i+1)
			s.sig = varint(s.sig, int(s.clr[i]))
		}
	}
	return string(s.sig)
}

func varint(b []byte, v int) []byte {
	for v >= 0x80 {
		b = append(b, byte(v)|0x80)
		v >>= 7
	}
	return append(b, byte(v))
}

@** 엔진.
춤은 {\tt SSXCC}의 것이고 분기하는 법도 덮는 법도 그대로다. 살아남은 옵션이 가장
적은 주 아이템을 골라 물리고, 그 옵션을 하나씩 떠본다. 다른 것은 양 끝뿐이다.
프로그램 {\tt SSXCC}가 해를 채널로 내려보내는 자리에서 이 엔진은 ZDD의 |Unit|을,
곧 더 고를 옵션이 없는 빈 집합 하나만을 원소로 갖는 집합족을 돌려준다. 그리고
{\tt SSXCC}가 옵션을 돌며 그 곁효과를 노리는 자리에서 이 엔진은 옵션이 돌려주는
것을 모은다.

강제 스택은 없앴다. 프로그램 {\tt SSXCC}는 옵션이 하나뿐인 아이템을 아무 크기도
저장하지 않고 집어 들려고 그것을 두지만, 여기서는 서명의 이야기를 흐리기만 할
터이고, 그것이 사 주던 것의 태반은 메모 캐시가 품는다.
@<풀이기@>=
@<살림살이@>
@<풀이기 상태@>
@<풀이기 짓기@>
@<집합 접근자@>
@<이름 가두기@>
@<서명 짓기@>
@<춤 띄우기@>
@<탐색@>
@<아이템 고르기@>
@<옵션 맡기기@>
@<부딪히는 옵션 숨기기@>
@<아이템 덮기@>
@<되돌리기 장치@>
@<옵션 알리기@>

@ @<살림살이@>=
const (
	zExtra      = 4       // 아이템 밑자리 아래에 맡아 두는 set 칸
	zIprop      = 4       // 입력 단계의 자리 간격
	infSize     = 1 << 30 // "분기할 아이템이 없다" => 해다
	secondUnset = 1 << 30 // "주와 부의 경계가 아직 없다"는 파수 값
)

type node struct {
	itm, loc, clr int32
}

type twoints struct {
	l, r int32
}

@* 상태와 짓기.
타입 |Solver|의 값 하나가 한 셈을 지닌다. 행렬 배열 말고도 옵션 번호---옵션마다
번호를 받는데 그것이 ZDD에서 그 옵션의 원소다---와 서명이 읽는 색 칸, 그리고
메모 캐시 자신을 지닌다.
@<풀이기 상태@>=
type Solver struct {
	Debug bool // 입력 요약과 마무리 통계를 stderr에 찍는다
	MRV   bool // 옵션이 가장 적은 아이템에서 분기한다. |New|가 켜 둔다

	@<행렬 배열@>
	@<이름표@>
	@<옵션 번호@>
	@<되짚기 배열@>
	@<메모 캐시@>
}

@ @<행렬 배열@>=
nd       []node
lastNode int
item     []int32
second   int
lastItm  int
set      []int32
itemlen  int
setlen   int
active   int
oactive  int
baditem  int
osecond  int
itemBase []int32 // 아이템 번호 -> set 안의 밑자리

@ @<이름표@>=
names      []string
nameIndex  map[string]int
colorNames []string
colorIndex map[string]int

@ 옵션은 읽힌 차례로 $1,2,\ldots$의 번호를 받는다. 배열 |optNo|는 노드를 그것이
속한 옵션의 번호로 데려가고, |optFirst|는 번호를 그 옵션의 첫 노드로 도로 데려가
다이어그램에서 읽어 낸 해를 다시 아이템 이름으로 바꿀 수 있게 한다. ZDD의 원소
$k$는 옵션 $k+1$인데, 패키지 |bdd|가 원소를 0부터 세기 때문이다.
@<옵션 번호@>=
options  int
optNo    []int32
optFirst []int32

@ @<되짚기 배열@>=
saved     []int32
savestack []twoints
saveptr   int
clr       []int32 // 아이템 번호 -> 그 아이템이 씻긴 색
sig       []byte  // 서명을 빚을 빈터

@ @<메모 캐시@>=
z     *bdd.ZDD
memo  map[string]bdd.Func
nodes uint64
hits  uint64

@ @<풀이기 짓기@>=
func New() *Solver {
	return &Solver{
		MRV:        true,
		second:     secondUnset,
		names:      []string{""}, // 아이템 번호는 1부터다
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // 0번 색은 "색 없음"이다
		colorIndex: make(map[string]int),
	}
}

func (s *Solver) Nodes() uint64      { return s.nodes }
func (s *Solver) Hits() uint64       { return s.hits }
func (s *Solver) Signatures() int    { return len(s.memo) }

@ @<집합 접근자@>=
func (s *Solver) size(x int) int   { return int(s.set[x-1]) }
func (s *Solver) pos(x int) int    { return int(s.set[x-2]) }
func (s *Solver) itemNo(x int) int { return int(s.set[x-3]) }

func (s *Solver) setSize(x, v int)   { s.set[x-1] = int32(v) }
func (s *Solver) setPos(x, v int)    { s.set[x-2] = int32(v) }
func (s *Solver) setItemNo(x, v int) { s.set[x-3] = int32(v) }

@ @<이름 가두기@>=
func (s *Solver) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

func (s *Solver) internColor(name string) int {
	if id, ok := s.colorIndex[name]; ok {
		return id
	}
	id := len(s.colorNames)
	s.colorNames = append(s.colorNames, name)
	s.colorIndex[name] = id
	return id
}

@* 춤.
메서드 |Dance|는 행렬을 읽고 다이어그램을 지어 돌려준다. 형제들과 달리 고루틴을
띄우지 않는다. 발을 맞출 흐름이 없고, 돌아올 때 답이 통째로 다 되어 있기 때문이다.
덮일 수 없는 아이템이 있거나 아이템이 아예 없는 문제는 빈 집합족을 내놓는다.
@<춤 띄우기@>=
func (s *Solver) Dance(rd io.Reader) *Diagram {
	s.inputMatrix(rd)
	s.z = bdd.NewZDD(s.options)
	s.memo = make(map[string]bdd.Func)
	@<입력 요약을 알린다@>
	root := s.z.Empty()
	if s.baditem == 0 {
		root = s.search()
	}
	@<총계를 알린다@>
	return &Diagram{s: s, z: s.z, root: root}
}

@ @<입력 요약을 알린다@>=
if s.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
}

@ @<총계를 알린다@>=
if s.Debug {
	fmt.Fprintf(os.Stderr,
		"Altogether %s solutions, %d ZDD nodes,"+
			" %d search nodes, %d signatures, %d hits.\n",
		s.z.Count(root).String(), s.z.Size(root), s.nodes, len(s.memo), s.hits)
}

@ 여기가 탐색이다. 지금의 부분 덮개를 마저 짓는 모든 길의 집합족으로 답하는데, 첫
세 줄이 이 프로그램의 착상 전부다. 주 아이템이 하나도 남지 않았으면 길이 하나
있는 것이고(더 고르지 않는 길이다), 덮어 줄 것이 없는 아이템이 있으면 길이 하나도
없는 것이며, 전에 본 적 있는 상태이면 찾아보면 된다.
@<탐색@>=
func (s *Solver) search() bdd.Func {
	s.nodes++
	best, score := s.chooseItem()
	if score == infSize {
		return s.z.Unit()
	}
	if score == 0 {
		return s.z.Empty()
	}
	key := s.signature()
	if f, ok := s.memo[key]; ok {
		s.hits++
		return f
	}
	@<아이템 |best|의 옵션을 모두 떠보고 합집합을 짓는다@>
	s.memo[key] = res
	return res
}

@ 아이템 |best|를 덮는 일은 {\tt SSXCC}에서와 똑같이 간다. 아이템을 물리고, 더는
쓸 수 없게 된 옵션을 숨기고, 크기를 찍어 두고, 후보를 하나씩 떠본다. 새로운 것은
반복문의 마지막 줄이다. 이 옵션을 {\it 쓰는\/} 해의 집합족은 아래쪽 집합족의
원소마다 그 옵션을 보탠 것이고, 그것이 곧 ZDD의 곱 |Join(Elt(o), sub)|이다. 이
마디 전체의 집합족은 후보들에 대한 그것들의 합집합이다. 다이어그램 마디를 손으로
빚지 않고 이렇게 짓는 데 시간이 조금 들지만, 그 값으로 제대로 차례가 잡히고 줄어든
ZDD를 얻는다. 크누스의 {\tt DLX6}이 내놓는 것보다 나은데, 그 프로그램은 제 출력이
``일반적으로 제대로 차례가 잡혀 있지 않다''고 일러 두기 때문이다.
@<아이템 |best|의 옵션을 모두 떠보고 합집합을 짓는다@>=
res := s.z.Empty()
s.swapOut(best)
s.oactive = s.active
s.hide(best, 0, 0)
lo := s.saveptr
s.saveSizes()
hi := s.saveptr
for c := best; c < best+s.size(best); c++ {
	opt := int(s.set[c])
	if s.commitOption(opt) {
		sub := s.search()
		res = s.z.Union(res, s.z.Join(s.z.Elt(int(s.optNo[opt])-1), sub))
	}
	s.restoreSizes(lo, hi)
}

@ 비기면 왼쪽 아이템이 이기는데, 여기서 그 규칙은 장식이 아니다. 메모 캐시가
값을 하게 만드는 것이 바로 그것이다. 희소 집합은 탐색이 도는 동안 배열 |item|을
뒤섞으므로 ``크기가 가장 작은 것 가운데 첫째''는 여기까지 어떻게 왔는지에 달렸지만,
``크기가 가장 작은 것 가운데 번호가 가장 작은 것''은 오직 상태에만 달렸다. 앞의
것으로 분기하면 같은 부분 문제에 이르는 두 길이 그것을 서로 다른 모양으로 헤집고,
저마다 제 자손과 제 서명을 낳는다. 재 보았다. 크기 $4\times4$의 도미노 판에서 그
규칙을 빼면 서명이 두 배가 되고, $8\times8$ 판에 이르면 500배를 문다.
{\bf 분기 규칙은 서명의 함수여야 한다.}

크기가 0인 일은 뿌리 아래에서는 일어날 수 없다. 메서드 |hide|가 살아 있는 주
아이템을 굶겨 죽이도록 두지 않기 때문이다. 그렇지만 파일에서 읽은 문제의 뿌리는
그럴 수 있으므로, 없는 셈 치지 않고 알린다.
@<아이템 고르기@>=
func (s *Solver) chooseItem() (best, score int) {
	score = infSize
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // 부 아이템에서는 분기하지 않는다
		}
		sz := s.size(x)
		if sz == 0 {
			return x, 0
		}
		@<아이템 |x|가 지금 것을 이기면 그것을 쥔다@>
	}
	return best, score
}

@ 옵션이 가장 적은 것을 먼저 보는 것은 그저 기본값일 뿐이다. 크누스의 연습문제
7.2.2.1--264는 단계 Z3이 대신 {\it 번호가 가장 작은\/} 살아 있는 아이템을 집으면
어찌 되는지 묻고, 그렇게 하면 다이어그램이 옵션 번호 차례로 나온다고 답한다.
우리 것은 어느 쪽이든 차례가 잡혀 있고---패키지 |bdd|가 지으면서 줄이므로
집합족이 다이어그램을 정하고 분기 규칙은 거기에 손댈 수 없다---다만 {\it 탐색\/}의
모양이 달라지는데, 길고 가는 영역을 타일로 덮는 문제에서는 그 쓸기가 \.{MRV}가
하는 것보다 훨씬 싸다. 필드 |MRV|를 끄면 그것을 달라는 뜻이다.
@<아이템 |x|가 지금 것을 이기면 그것을 쥔다@>=
if !s.MRV {
	if score == infSize || x < best {
		best, score = x, sz
	}
	continue
}
if sz < score || (sz == score && x < best) {
	best, score = x, sz
}

@* 덮기와 되돌리기.
엔진의 나머지는 {\tt SSXCC}의 것이니, 다른 데서만 다시 이야기한다. 맡긴 옵션의
노드를 첫 번째로 훑을 때 그 아이템들을 살아 있는 목록에서 빼내며 부 아이템마다
어느 색으로 씻기는지를 적어 두는데, 그것이 더 깊은 층에서 서명이 읽을 |clr|
칸이다. 두 번째 훑기는 이제 부딪히게 된 옵션을 숨긴다.
@<옵션 맡기기@>=
func (s *Solver) commitOption(opt int) bool {
	@<옵션 |opt|의 아이템을 살아 있는 목록에서 빼낸다@>
	@<옵션 |opt|의 아이템마다 숨기거나 씻어 낸다@>
	return true
}

@ @<옵션 |opt|의 아이템을 살아 있는 목록에서 빼낸다@>=
p := s.active
s.oactive = s.active
for q := opt + 1; q != opt; {
	c := int(s.nd[q].itm)
	if c < 0 {
		q += c
		continue
	}
	if pp := s.pos(c); pp < p {
		p--
		cc := int(s.item[p])
		s.item[p], s.item[pp] = int32(c), int32(cc)
		s.setPos(cc, pp)
		s.setPos(c, p)
		if c >= s.second {
			s.clr[s.itemNo(c)] = s.nd[q].clr
		}
	}
	q++
}
s.active = p

@ @<옵션 |opt|의 아이템마다 숨기거나 씻어 낸다@>=
for q := opt + 1; q != opt; {
	c := int(s.nd[q].itm)
	if c < 0 {
		q += c
		continue
	}
	switch {
	case c < s.second:
		if !s.hide(c, 0, 1) {
			return false
		}
	case s.pos(c) < s.oactive:
		if !s.hide(c, int(s.nd[q].clr), 1) {
			return false
		}
	}
	q++
}

@ @<부딪히는 옵션 숨기기@>=
func (s *Solver) hide(c, color, check int) bool {
	for rr, end := c, c+s.size(c); rr < end; rr++ {
		tt := int(s.set[rr])
		if color != 0 && int(s.nd[tt].clr) == color {
			continue
		}
		@<옵션 |tt|를 그 다른 아이템들의 집합에서 지운다@>
	}
	return true
}

@ @<옵션 |tt|를 그 다른 아이템들의 집합에서 지운다@>=
for nn := tt + 1; nn != tt; {
	u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
	if u < 0 {
		nn += u
		continue
	}
	if s.pos(u) < s.oactive {
		ss := s.size(u) - 1
		if ss == 0 && check != 0 && u < s.second && s.pos(u) < s.active {
			return false
		}
		nnp := int(s.set[u+ss])
		s.setSize(u, ss)
		s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
		s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
	}
	nn++
}

@ @<아이템 덮기@>=
func (s *Solver) swapOut(x int) {
	p := s.active - 1
	s.active = p
	pp := s.pos(x)
	cc := int(s.item[p])
	s.item[p], s.item[pp] = int32(x), int32(cc)
	s.setPos(cc, pp)
	s.setPos(x, p)
}

@ 되짚기는 Solnon의 것이다. 분기하기 전에 살아 있는 아이템의 크기를 저장해 두었다가
끝나면 그대로 도로 박는다. 층은 제 저장의 양옆에 있는 스택 포인터 |lo|와 |hi|를
기억한다. 그 둘 사이의 거리가 그때 살아 있던 아이템의 수이고, 더 깊은 층은 |hi|
위에 쌓았다가 잊히는 것으로 되돌려진다.
@^Solnon, Christine@>
@<되돌리기 장치@>=
func (s *Solver) saveSizes() {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		x := int(s.item[p])
		s.savestack[s.saveptr+p] = twoints{int32(x), int32(s.size(x))}
	}
	s.saveptr += s.active
}

func (s *Solver) restoreSizes(lo, hi int) {
	s.saveptr = hi
	s.active = hi - lo
	for p := 0; p < s.active; p++ {
		e := s.savestack[lo+p]
		s.setSize(int(e.l), int(e.r))
	}
}

@ 다이어그램은 옵션을 번호로만 알고 있으므로, 옵션을 알리는 일은 입력 단계가
그 옵션을 위해 적어 둔 첫 노드에서 시작해 사이막까지 달리며 아이템마다 이름을
대고 색이 있으면 붙이는 일이다.
@<옵션 알리기@>=
func (s *Solver) option(o int) cells.Option {
	var opt cells.Option
	for q := int(s.optFirst[o]); s.nd[q].itm > 0; q++ {
		name := s.names[s.itemNo(int(s.nd[q].itm))]
		if c := s.nd[q].clr; c != 0 {
			name += ":" + s.colorNames[c]
		}
		opt = append(opt, name)
	}
	return opt
}

@** 다이어그램.
메서드 |Dance|가 돌려주는 것은 다 지어진 ZDD의 손잡이에, 원소 번호를 다시 옵션
이름으로 바꿀 만큼의 풀이기를 곁들인 것이다. 밖으로 드러내 둘 값이 있는 필드는
이 패키지를 떠날 때 필요한 둘이다. 메서드 |ZDD|가 |bdd| 손잡이와 집합족을
내주고, 그러면 그 패키지가 할 수 있는 일은 무엇이든 할 수 있다. 메서드 |Profile|,
|Subsets|, |Quotient|, 다이어그램을 줄이는 |SiftAll|, 어딘가 다른 데서 온
집합족과의 합집합 따위다.
@<다이어그램@>=
type Diagram struct {
	s    *Solver
	z    *bdd.ZDD
	root bdd.Func
}

func (d *Diagram) ZDD() (*bdd.ZDD, bdd.Func) { return d.z, d.root }

@ 감싸 둘 값이 있는 물음 셋은 패키지 |bdd|를 아예 몰라도 되는 셋이다. 메서드
|Count|가 이 프로그램 전체의 까닭이다. DAG를 걷는 것이므로 답이 해의 수가 아니라
다이어그램의 크기에 비례하는 시간에 닿고, |big.Int|로 닿는데 우리가 세고 있는 수가
달리 들어앉을 데가 없기 때문이다. 메서드 |Nodes|는 다이어그램의 크기이고,
|Options|는 그 전체 집합의 크기다.
@<다이어그램@>=
func (d *Diagram) Count() *big.Int { return d.z.Count(d.root) }
func (d *Diagram) Nodes() int      { return d.z.Size(d.root) }
func (d *Diagram) Options() int    { return d.s.options }

@ 옵션의 이름은 다른 엔진들이 부르는 그대로 제 아이템 이름들이고, 색이 붙은 부
아이템은 \.{name:color}로 나온다. 메서드 |Option|은 다이어그램에서 나오는 옵션
번호를 받는데 그것은 1부터이고, ZDD 제 원소는 그보다 하나 작다.
@<다이어그램@>=
func (d *Diagram) Option(o int) cells.Option { return d.s.option(o) }

func (d *Diagram) solution(elts []int) []cells.Option {
	sol := make([]cells.Option, len(elts))
	for i, e := range elts {
		sol[i] = d.s.option(e + 1)
	}
	return sol
}

@ 해가 들여다볼 만큼 적을 때는 여전히 하나씩 들여다볼 수 있다. 이 수열은
다이어그램을 걸으므로 훑기 전에는 아무것도 들지 않고, 일찍 빠져나가는 쪽은 제가
본 것만큼만 문다.
@<다이어그램@>=
func (d *Diagram) Solutions() iter.Seq[[]cells.Option] {
	return func(yield func([]cells.Option) bool) {
		for elts := range d.z.Subsets(d.root) {
			if !yield(d.solution(elts)) {
				return
			}
		}
	}
}

@ 그리고 낱낱이 세어서는 아예 답할 수 없는 물음 둘이다. 메서드 |Random|은 해를
고르게 무작위로 뽑는데, 해가 몇 개이든 그 전체에 대해 고르다. 메서드 |MaxWeight|는
옵션 번호마다 무게가 주어졌을 때 무게의 합이 가장 큰 해를 찾는다. 둘 다 DAG 위의
걸음이다. 무게 조각은 옵션 번호로 찾으므로 |w[1]|이 첫 옵션의 무게이고 |w[0]|은
셈에 들지 않는데, 그러면 번호 매김이 |Option|의 그것과 같아진다.
@<다이어그램@>=
func (d *Diagram) Random(r *rand.Rand) ([]cells.Option, bool) {
	elts, ok := d.z.Random(d.root, r)
	if !ok {
		return nil, false
	}
	return d.solution(elts), true
}

func (d *Diagram) MaxWeight(w []int) ([]cells.Option, int, bool) {
	ew := make([]int, d.s.options)
	for k := range ew {
		if k+1 < len(w) {
			ew[k] = w[k+1]
		}
	}
	elts, wt, ok := d.z.MaxWeight(d.root, ew)
	if !ok {
		return nil, 0, false
	}
	return d.solution(elts), wt, true
}

@** DLX 입력 읽기.
형식 {\tt DLX}는 \.{dcells.w}에 적혀 있다. 이 패키지는 제 패키지로 따로 서 있어
그 글의 훑개를 빌려 올 수 없으므로, 필요한 몇 줄이 여기 나온다. 나머지 단계는
{\tt SSXCC}의 것에 옵션 번호 매김을 더한 것이다.
@<입력 단계@>=
func (s *Solver) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

@<입력 훑개@>
@<아이템 이름 읽기@>
@<옵션 읽기@>
@<입력 마무리@>

@ 틀린 입력은 달래 가며 다룰 실행 중의 사정이 아니라 프로그래밍 잘못이므로,
파서는 panic으로 말썽을 알린다. 함수 |nextLine|은 한 줄을 NUL로 끝나는 버퍼에
읽어 들여, 내용보다 한 바이트 더 훑어도 테두리 안에 있게 한다. 함수 |token|은
다음 낱말을 들어 올리되 공백이나 NUL에서, 그리고 |stopColon|이 켜져 있으면 쌍점에서
멎는다.
@<입력 훑개@>=
type parseError struct{ msg string }

func (e *parseError) Error() string { return e.msg }

func failf(format string, a ...any) {
	panic(&parseError{fmt.Sprintf(format, a...)})
}

func isspace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
}

func nextLine(br *bufio.Reader) (buf []byte, ok bool) {
	str, err := br.ReadString('\n')
	if len(str) == 0 && err != nil {
		return nil, false
	}
	buf = make([]byte, len(str)+1)
	copy(buf, str)
	return buf, true
}

@ @<입력 훑개@>=
func skipSpace(buf []byte, p int) int {
	for isspace(buf[p]) {
		p++
	}
	return p
}

func token(buf []byte, p int, stopColon bool) (string, int) {
	start := p
	for buf[p] != 0 && !isspace(buf[p]) && !(stopColon && buf[p] == ':') {
		p++
	}
	return string(buf[start:p]), p
}

func ensure[T any](s []T, n int) []T {
	if n <= len(s) {
		return s
	}
	if n <= cap(s) {
		return s[:n]
	}
	t := make([]T, n, max(cap(s)*2, n, 64))
	copy(t, s)
	return t
}

@ @<아이템 이름 읽기@>=
func (s *Solver) readItemNames(br *bufio.Reader) {
	@<아이템 줄을 찾는다@>
	for buf[p] != 0 {
		name, next := token(buf, p, false)
		if name == "|" {
			if s.second != secondUnset {
				failf("item name line contains | twice")
			}
			s.second = len(s.names)
		} else {
			if strings.ContainsAny(name, ":|") {
				failf("illegal character in item name: %q", name)
			}
			if _, ok := s.internName(name); !ok {
				failf("duplicate item name: %s", name)
			}
		}
		p = skipSpace(buf, next)
	}
	s.lastItm = len(s.names)
}

@ @<아이템 줄을 찾는다@>=
var buf []byte
var p int
found := false
for {
	var ok bool
	if buf, ok = nextLine(br); !ok {
		break
	}
	if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
		found = true
		break
	}
}
if !found {
	failf("no items")
}

@ @<옵션 읽기@>=
func (s *Solver) readOptions(br *bufio.Reader) {
	for {
		buf, ok := nextLine(br)
		if !ok {
			break
		}
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
			continue
		}
		s.readOption(buf)
	}
	s.finalize()
}

@ 주 아이템을 하나도 대지 않은 옵션은 고를 수가 없으므로 말없이 되감는다. 참된
옵션은 사이막으로 봉하고 다음 옵션 번호를 받는다.
@<옵션 읽기@>=
func (s *Solver) readOption(buf []byte) {
	spacer := s.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {
		@<아이템 이름 하나와 그 색을 훑는다@>
	}

	if !hasPrimary {
		@<옵션을 되감는다@>
		return
	}
	s.nd[spacer].loc = int32(s.lastNode - spacer)
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	s.options++
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
}

@ @<아이템 이름 하나와 그 색을 훑는다@>=
name, next := token(buf, p, true)
if name == "" {
	failf("empty item name")
}
m, known := s.nameIndex[name]
if !known {
	failf("unknown item name: %s", name)
}
s.createNode(m, spacer, &hasPrimary)
if buf[next] == ':' {
	if m < s.second {
		failf("primary item must be uncolored: %s", name)
	}
	color, ce := token(buf, next+1, false)
	if color == "" {
		failf("missing color after %s:", name)
	}
	s.nd[s.lastNode].clr = int32(s.internColor(color))
	next = ce
} else {
	s.nd[s.lastNode].clr = 0
}
p = skipSpace(buf, next)

@ @<옵션을 되감는다@>=
for s.lastNode > spacer {
	slot := int(s.nd[s.lastNode].itm) * zIprop
	s.setSize(slot, s.size(slot)-1)
	s.setPos(slot, spacer-1)
	s.lastNode--
}

@ @<옵션 읽기@>=
func (s *Solver) createNode(m, spacer int, hasPrimary *bool) {
	slot := m * zIprop
	s.set = ensure(s.set, slot)
	if s.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", s.names[m])
	}
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	t := s.size(slot)
	s.nd[s.lastNode].itm = int32(m)
	s.nd[s.lastNode].loc = int32(t)
	if m < s.second {
		*hasPrimary = true
	}
	s.setSize(slot, t+1)
	s.setPos(slot, s.lastNode)
}

@ 마무리는 희소 집합을 깔고, 다른 엔진들이 달라고 할 때만 짓는 표 둘을 더 짓는다.
서명이 걷는 |itemBase|와, ZDD의 원소에 이름을 주는 옵션 번호다.
@<입력 마무리@>=
func (s *Solver) finalize() {
	@<set 배열을 깐다@>
	@<아이템 머리를 채운다@>
	@<노드가 가리키는 곳을 고친다@>
	@<옵션에 번호를 매기고 아이템을 번호로 찾을 표를 짓는다@>
}

@ @<set 배열을 깐다@>=
s.active, s.itemlen = s.lastItm-1, s.lastItm-1
s.item = ensure(s.item, s.itemlen)
s.set = ensure(s.set, s.itemlen*zIprop+1)

j := zExtra
k := 0
for ; k < s.itemlen; k++ {
	s.item[k] = int32(j)
	j += zExtra + s.size((k+1)*zIprop)
}
s.setlen = j - zExtra
s.set = ensure(s.set, j+1)
if s.second == secondUnset {
	s.osecond, s.second = s.active, j
} else {
	s.osecond = s.second - 1
}

@ @<아이템 머리를 채운다@>=
for ; k != 0; k-- {
	base := int(s.item[k-1])
	if k == s.second {
		s.second = base
	}
	s.setSize(base, s.size(k*zIprop))
	if s.size(base) == 0 && k <= s.osecond {
		s.baditem = k
	}
	s.setPos(base, k-1)
	s.setItemNo(base, k)
}

@ @<노드가 가리키는 곳을 고친다@>=
for k = 1; k < s.lastNode; k++ {
	if s.nd[k].itm <= 0 {
		continue
	}
	base := int(s.item[int(s.nd[k].itm)-1])
	loc := base + int(s.nd[k].loc)
	s.nd[k].itm = int32(base)
	s.nd[k].loc = int32(loc)
	s.set[loc] = int32(k)
}

@ 한 번 더 훑어 옵션에 번호를 매긴다. 앞의 것이 사이막인 노드가 새 옵션을 여는
노드이므로 번호는 곧 입력 차례이고, 배열 |optFirst|는 옵션마다 어디서 시작하는지를
기억해 두어 나중에 다시 이름을 댈 수 있게 한다.
@<옵션에 번호를 매기고 아이템을 번호로 찾을 표를 짓는다@>=
s.optNo = make([]int32, s.lastNode+1)
s.optFirst = make([]int32, s.options+1)
o := int32(0)
for k = 1; k < s.lastNode; k++ {
	if s.nd[k].itm <= 0 {
		continue
	}
	if s.nd[k-1].itm <= 0 {
		o++
		s.optFirst[o] = int32(k)
	}
	s.optNo[k] = o
}
s.itemBase = make([]int32, s.itemlen+1)
for k = 0; k < s.itemlen; k++ {
	base := int(s.item[k])
	s.itemBase[s.itemNo(base)] = int32(base)
}
s.clr = make([]int32, s.itemlen+1)

@** 테스트.
문학적 프로그램이라면 제가 살아 있다는 증거를 스스로 지니는 것이 옳다. 이 부분은
같은 원본에서 짜여 \.{zdd\_test.go}로 tangle된다. 앞의 것들은 이 저장소의 엔진이면
누구나 치르는 시험이다. 크누스의 옵션 여섯 개짜리 예, 색 기계, 그리고 해가 아예
없는 문제다.
@(zdd_test.go@>=
package zdd

import (
	"fmt"
	"math/rand/v2"
	"sort"
	"strings"
	"testing"

	cells "github.com/sjnam/dancing-cells"
)

func count(t *testing.T, input string) string {
	t.Helper()
	return New().Dance(strings.NewReader(input)).Count().String()
}

func TestExactCover(t *testing.T) {
	input := "a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n"
	if got := count(t, input); got != "1" {
		t.Errorf("want 1 cover, got %s", got)
	}
}

func TestColors(t *testing.T) {
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
	if got := count(t, input); got != "2" {
		t.Errorf("want 2 covers, got %s", got)
	}
}

func TestNoSolution(t *testing.T) {
	if got := count(t, "a b c\na b\n"); got != "0" {
		t.Errorf("want 0 covers, got %s", got)
	}
}

@ 다이어그램은 이웃한 엔진과 뜻이 맞아야 하는데, 수만이 아니라 해 하나하나가
맞아야 한다. 양쪽 모두 표준 모양으로 빚는다. 옵션 안의 이름을 정렬하고, 해 안의
옵션을 정렬하고, 무리 안의 해를 정렬한다. 그러면 견줌이 어느 쪽이 어떤 차례로
내놓는지에 달리지 않는다.
@(zdd_test.go@>=
func canon(sols [][]cells.Option) []string {
	out := make([]string, 0, len(sols))
	for _, sol := range sols {
		opts := make([]string, len(sol))
		for i, opt := range sol {
			names := append([]string(nil), opt...)
			sort.Strings(names)
			opts[i] = strings.Join(names, " ")
		}
		sort.Strings(opts)
		out = append(out, strings.Join(opts, " | "))
	}
	sort.Strings(out)
	return out
}

func TestAgreesWithXCC(t *testing.T) {
	for _, in := range []string{
		"a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n",
		"p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n",
		queens(6), queens(7), dominoes(4, 4), dominoes(4, 6),
	} {
		var want [][]cells.Option
		for sol := range cells.NewXCC().Dance(strings.NewReader(in)).Solutions {
			want = append(want, sol)
		}
		var got [][]cells.Option
		for sol := range New().Dance(strings.NewReader(in)).Solutions() {
			got = append(got, sol)
		}
		w, g := canon(want), canon(got)
		if len(w) != len(g) {
			t.Fatalf("XCC found %d covers, the diagram %d", len(w), len(g))
		}
		for i := range w {
			if w[i] != g[i] {
				t.Fatalf("cover %d differs:\n%s\n%s", i, w[i], g[i])
			}
		}
	}
}

@ 문제를 지어내는 함수 둘이다. 차수 $n$의 퀸 판은 이 저장소의 글이면 어디서나
쓰는 그것이고, 도미노 판은 격자 그래프의 완전 짝짓기를 달라는 것인데 이 엔진이
있는 까닭이 바로 그 문제다. 칸마다 주 아이템 하나이고, 도미노를 놓는 자리마다
그 칸 둘을 덮는 옵션 하나다.
@(zdd_test.go@>=
func queens(n int) string {
	var b strings.Builder
	for i := range n {
		fmt.Fprintf(&b, "r%02d ", i)
	}
	for j := range n {
		fmt.Fprintf(&b, "c%02d ", j)
	}
	b.WriteString("|")
	for k := 0; k < 2*n-1; k++ {
		fmt.Fprintf(&b, " a%02d b%02d", k, k)
	}
	b.WriteString("\n")
	for i := range n {
		for j := range n {
			fmt.Fprintf(&b, "r%02d c%02d a%02d b%02d\n", i, j, i+j, i-j+n-1)
		}
	}
	return b.String()
}

func dominoes(rows, cols int) string {
	var b strings.Builder
	for r := range rows {
		for c := range cols {
			fmt.Fprintf(&b, "%x%x ", r, c)
		}
	}
	b.WriteString("\n")
	for r := range rows {
		for c := range cols {
			if c+1 < cols {
				fmt.Fprintf(&b, "%x%x %x%x\n", r, c, r, c+1)
			}
			if r+1 < rows {
				fmt.Fprintf(&b, "%x%x %x%x\n", r, c, r+1, c)
			}
		}
	}
	return b.String()
}

@ 누구나 아는 수들이다. 퀸을 놓는 법이 92, 352, 724가지이고, 크기 $2n\times2n$의
판을 도미노로 덮는 법의 수가
$\hbox{A004003}=2,\,36,\,6728,\,12{,}988{,}816,\,258{,}584{,}046{,}368$이다.
마지막 것이 이 연습의 핵심인데, 여기서는 몇 밀리초에 세어지는 반면 그 타일 깔기를
하나씩 늘어놓자면 $8\times8$ 경우 하나만으로도 다른 엔진들이 탐색 마디 5천만 개와
18초를 쓴다.
@(zdd_test.go@>=
func TestQueenCounts(t *testing.T) {
	for n, want := range map[int]string{6: "4", 7: "40", 8: "92", 9: "352", 10: "724"} {
		if got := count(t, queens(n)); got != want {
			t.Errorf("%d queens: got %s, want %s", n, got, want)
		}
	}
}

func TestDominoCounts(t *testing.T) {
	want := []string{"2", "36", "6728", "12988816", "258584046368"}
	for i, w := range want {
		n := 2 * (i + 1)
		d := New().Dance(strings.NewReader(dominoes(n, n)))
		if got := d.Count().String(); got != w {
			t.Errorf("%dx%d dominoes: got %s, want %s", n, n, got, w)
		}
		t.Logf("%2dx%-2d %18s tilings, %6d ZDD nodes, %7d search nodes",
			n, n, d.Count(), d.Nodes(), d.s.Nodes())
	}
}

@ 끝으로 낱낱이 세어서는 답할 수 없는 물음 둘이다. 둘 다 $10\times10$ 판에 묻는데,
그 $2.6\times10^{11}$가지 타일 깔기를 들여다볼 사람은 없다. 무작위로 뽑은 것도 가장
무거운 것도 참된 타일 깔기여야 하고---도미노 쉰 개, 두 번 덮인 칸 없음---가장
무거운 것은 무작위로 뽑은 천 개보다 가볍지 않아야 한다.
@(zdd_test.go@>=
func TestRandomAndMaxWeight(t *testing.T) {
	d := New().Dance(strings.NewReader(dominoes(10, 10)))
	w := make([]int, d.Options()+1)
	for k := 1; k <= d.Options(); k++ {
		w[k] = (k * 37) % 101
	}
	best, wt, ok := d.MaxWeight(w)
	if !ok {
		t.Fatal("no heaviest tiling")
	}
	@<해 |best|가 참된 타일 깔기인지 살핀다@>
	r := rand.New(rand.NewPCG(1, 2))
	for i := 0; i < 1000; i++ {
		sol, ok := d.Random(r)
		if !ok {
			t.Fatal("no random tiling")
		}
		if len(sol) != 50 {
			t.Fatalf("random tiling has %d dominoes, want 50", len(sol))
		}
		if got := weigh(d, sol, w); got > wt {
			t.Fatalf("random tiling weighs %d, heavier than the maximum %d", got, wt)
		}
	}
}

@ @<해 |best|가 참된 타일 깔기인지 살핀다@>=
if len(best) != 50 {
	t.Fatalf("heaviest tiling has %d dominoes, want 50", len(best))
}
seen := map[string]bool{}
for _, opt := range best {
	for _, cell := range opt {
		if seen[cell] {
			t.Fatalf("cell %s covered twice", cell)
		}
		seen[cell] = true
	}
}

@ 해의 무게를 다는 일은 옵션의 번호를 다시 찾는 일인데, 다이어그램은 그것을
돌려주지 않는다. 그래서 테스트는 그저 찍힌 옵션으로 맞춰 보는데, 두 도미노가 같은
칸 쌍을 덮는 일이 없으니 여기서는 그것으로 하나가 가려진다.
@(zdd_test.go@>=
func weigh(d *Diagram, sol []cells.Option, w []int) int {
	num := map[string]int{}
	for k := 1; k <= d.Options(); k++ {
		num[strings.Join(d.Option(k), " ")] = k
	}
	total := 0
	for _, opt := range sol {
		total += w[num[strings.Join(opt, " ")]]
	}
	return total
}

@** 색인.
