\input kotexgweb

\def\title{SSXCC}

@s Context int
@s Duration int
@s Ticker int
@s Reader int
@s Builder int
@s Time int

@** 들어가며.
이 글은 {\tt SSXCC}다. 색깔이 붙은 정확 덮개를 희소 집합 위에서 추는 춤이고,
|dcells| 패키지의 두 엔진 가운데 하나이며, 그것만 떼어 읽어도 되도록 썼다.
짝이 되는 글 \.{dcells.w}에서 빌려 오는 것---타입 |Option|과 |Result|, 배열
|nd|, 함수 |ensure|, 그리고 {\tt DLX} 텍스트를 낱말로 바꾸는 훑개---은 거기에
적혀 있다. 춤을 추는 바탕인 희소 집합도 아래에 짧게 되새기되, 느긋한 이야기는
거기에 있다.

{\it 주\/} 아이템은 꼭 한 번 덮여야 하고, {\it 부\/} 아이템은 몇 번이든 덮여도
좋되 그것을 건드리는 옵션이 모두 같은 색에 뜻을 모아야 한다. 분기는 알고리즘~X가
하던 그대로다. 살아남은 옵션이 가장 적은 아이템을 골라 그 옵션을 모두 시도하는
{\it $d$갈래\/} 뻗기다. 형제인 {\tt SSMCC}(\.{ssmcc.w})는 ``꼭 한 번''을 범위로
느슨하게 풀어 주므로 분기하는 법이 달라야 한다. 둘이 깃발 하나로 갈리는 한
프로그램이 아니라 따로 선 두 프로그램인 까닭이 그것이다.

뒤쪽의 한 장은 첫 물음 위에 둘째 물음을 얹는다. 옵션마다 값이 매겨지고 나면
``덮개가 있는가''는 ``가장 싼 덮개는 무엇인가''가 되고, 같은 탐색이 분기한정으로
거기에 답한다.
@c
package dcells

import (
	"bufio"
	"cmp"
	"context"
	"fmt"
	"io"
	"os"
	"slices"
	"strings"
	"time"
)

@<엔진@>
@<값 따지기@>
@<입력 단계@>

@ 희소 집합이 이 춤의 전부이니, 한 문단으로 적어 둔다. 전체 집합
$U=\{x_0,\ldots,x_{n-1}\}$의 부분 집합 $S$를 나타내려면, 서로 역순열인 두 배열
$p$와 $q$, 그리고 개수~$s$를 둔다. 그러면 $S$의 원소는 정확히
$x_{p_0},\ldots,x_{p_{s-1}}$이다. 원소 $x_k$가 $S$에 든 것은 $q_k<s$와 같은
말이다. 원소를 빼려면 $s-1$번 자리로 맞바꾸고 $s$를 줄이며, 넣으려면 $s$번
자리로 맞바꾸고 $s$를 늘린다. 리스트도 링크도 없다. 춤을 배운 두 순열이 있을
뿐이다. Preston Briggs와 Linda Torczon이 Aho, Hopcroft, Ullman의 연습문제
하나에서 이 착상을 길어 올린 것이 1993년이다 [{\sl ACM Letters on Programming
Languages and Systems\/ \bf2}, 59--69].
@^Briggs, Preston@>
@^Torczon, Linda@>

@ 행렬은 납작한 배열 셋에 들어앉는다. 배열 |nd|는 옵션을 {\it 노드\/}의
토막으로 담는데, 옵션의 아이템마다 노드 하나이고 솔기는 사이막 노드가 짚어
준다. 배열 |item|은 아직 살아 있는 아이템을 늘어놓아 위 순열~$p$ 노릇을 한다.
그리고 배열 |set|은 아이템마다 그것을 지금 담고 있는 옵션들을 간직한다.
아이템의 이름은 배열 |set|의 밑자리 색인~|x|이고, 살아남은 옵션은 |set[x]|와
그 뒤의 |size(x)-1|칸이며, |pos(x)|가 $q$ 노릇을 하여 이 아이템이
|item[pos(x)]|에 앉아 있음을 적어 둔다. 그러면 아이템을 덮는다는 것은 개수를
줄이고 배열 칸 둘을 맞바꾸는 일에 지나지 않는다. 희소 집합의 삭제를 그저
되풀이하는 것이다. 밑자리 바로 아래 칸들이 그 살림살이를 담고, 아래에 이름
붙인 접근자가 그것을 읽고 쓴다.

@ 풀이기 구조체는 상태의 덩이 여럿을 모아 지었다. 덩이마다 이름을 붙였으니
구조체 자체가 제 관심사의 목록으로 읽힌다. 먼저 공개된 손잡이다. 필드 |Debug|는
|dlx| 라이브러리가 |stderr|에 찍는 것과 같은 짤막한 입력 요약과 마무리 통계를
켠다. 필드 |PulseInterval|이 양수이면 이따금 맥박을 보내 달라는 뜻이다.
@<풀이기 손잡이@>=
Debug         bool          // 입력 요약과 마무리 통계를 stderr에 찍는다
PulseInterval time.Duration // 양수이면 이따금 Heartbeat 문자열을 내준다

@ 이름과 색은 아무 문자열이어도 좋으므로 엔진이 그것을 작은 정수로 가둔다.
이름 하나하나가 작은 정수가 되고(0번은 자리지기이므로 1부터다) 색도 마찬가지다.
맵은 겹친 이름을 찾아내는 구실도 함께 한다.
@<이름표@>=
names      []string // 아이템 번호(1부터)로 찾는, 가둬 둔 아이템 이름
nameIndex  map[string]int
colorNames []string // 색 번호(1부터, 0은 "색 없음")로 찾는, 가둬 둔 색 이름
colorIndex map[string]int

@ 탐색은 다음 수가 더는 선택이 아닌 아이템을 {\it 강제 스택\/}에 쌓아 두고---강제
이동은 이 이야기에 거듭 나오는 인물이다---탐색에 든 품을 세는 계수기를 지닌다.
``업데이트''는 희소 집합의 맞바꿈 한 번이고, ``노드''는 되도는 탐색에 한 번
들르는 것이다.
@<강제 스택@>=
force  []int32
forced int

@ @<탐색 통계@>=
updates uint64
nodes   uint64
options uint64
count   uint64

@ @<출력 채널@>=
solStream chan []Option
heartbeat chan string
pulse     *time.Ticker


@** 엔진.
이제 풀이기 자체를 처음부터 본다. 알고리즘은 희소 집합의 옷을 입은 알고리즘~X이고,
한 문단이면 다 적힌다. 남은 옵션이 가장 적은 살아 있는 주 아이템을 {\it
고른다}. 그런 아이템이 없으면 부분해가 곧 해다. 그 아이템을 {\it 덮는다}.
살아 있는 목록에서 빼내고, 더는 쓸 수 없게 된 옵션을 모두 숨긴다. 그런 다음 그
아이템의 옵션을 차례로 {\it 시도한다}. 옵션을 맡기고(그러면 그 옵션의 다른
아이템도 모두 덮인다) 되돌아 들어갔다가 되돌린다. 나머지는 살림살이인데, 그
동사 하나하나가 배열 맞바꿈 몇 번으로 끝나도록 고른 살림살이다.

엔진은 네 악장으로 펼쳐지고, 뒤따르는 묶음이 그것을 따라간다. 상태와 짓기,
춤---공개된 출발점과 되도는 탐색과 고르개, 덮는 기계---맡기기와 숨기기, 그리고
시도를 되돌릴 수 있게 하는 되돌리기 장치, 끝으로 해를 부르는 쪽에 건네는 작은
보고 창구들이다.
@<엔진@>=
@<살림살이@>
@<풀이기 상태@>
@<풀이기 짓기@>
@<집합 접근자@>
@<이름 가두기@>
@<춤 띄우기@>
@<탐색@>
@<아이템 고르기@>
@<옵션 맡기기@>
@<부딪히는 옵션 숨기기@>
@<아이템 덮기@>
@<되돌리기 장치@>
@<해에 들르기@>
@<맥박@>
@<옵션 알리기@>

@ 짧은 선언 둘이 엔진의 문을 연다. 아이템마다 배열 |set|의 밑자리 바로 아래에
칸 넷을 잡아 둔다. 크기와 위치와 아이템 번호, 그리고 여분 하나다. 그리고
저장 스택의 칸마다 아이템 하나와 분기 전의 크기를 함께 적어 두므로, 되돌리기는
그 짝을 도로 써 넣는 일이 된다.
@<살림살이@>=
const primExtra = 4 // 아이템 밑자리 아래에 잡아 두는 set 칸의 수

type twoints struct {
	l, r int32
}

@* 상태와 짓기.
값 |XCC| 하나가 계산 하나의 상태를 통째로 싣는다. 앞에서 마련한 공용 덩이
말고도, 행렬 배열인 |nd|와 |item|과 |set|을 지니는데 |second|가 주 아이템과 부
아이템의 경계를 짚어 준다. 그리고 탐색이 걸어온 길을 적는 배열들을 지닌다.
배열 |choice|는 층마다 고른 옵션을 담고, |saved|와 |savestack|은 되짚기에 쓸
크기를 찍어 둔다.
@<풀이기 상태@>=
type XCC struct {
	@<풀이기 손잡이@>
	ctx context.Context

	@<행렬 배열@>
	@<이름표@>
	@<강제 스택@>
	@<되짚기 배열@>
	@<값 살림살이@>
	@<탐색 통계@>
	@<출력 채널@>
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

@ @<되짚기 배열@>=
choice    []int32
saved     []int32
savestack []twoints
saveptr   int

@ 갓 지은 풀이기에는 파수꾼 값들과 (비었으되 nil은 아닌) 표들이 있어야 한다.
맥박은 처음에 꺼져 있고 문맥은 끊기는 일이 없는 바탕 문맥이다. 탐색을 끊을 수
있게 하려면 시작하기 전에 문맥을 건네면 된다. 메서드 |WithContext|는 얕은
사본을 돌려주므로 원래 풀이기는 그대로 다시 쓸 수 있고, nil 문맥은 대놓고
물리친다. 그러지 않으면 춤 속 깊은 데서 알 수 없는 당황으로 튀어나올 것이다.
메서드 |Updates|와 |Nodes|는 채널 |Solutions|를 다 비우고 난 뒤에 탐색 통계를
일러 준다.
@<풀이기 짓기@>=
func NewXCC() *XCC {
	return &XCC{
		second:     secondUnset,
		names:      []string{""}, // 아이템 번호는 1부터다
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // 색 0은 "색 없음"을 뜻한다
		colorIndex: make(map[string]int),
		ctx:        context.Background(),
	}
}

func (s *XCC) WithContext(ctx context.Context) *XCC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *s
	c.ctx = ctx
	return &c
}

func (s *XCC) Updates() uint64 { return s.updates }
func (s *XCC) Nodes() uint64   { return s.nodes }

@ 희소 집합의 접근자를 여기 살로 적는다. 밑자리가 |x|인 아이템이라면 |x| 바로
아래에 잡아 둔 칸들이 그 크기와 배열 |item| 안에서의 위치와 아이템 번호를
담고, 넷째 칸은 여분이다. 이름으로 읽고 쓰면 ``밑자리에서 둘 아래''라는 셈이
알고리즘 쪽으로 새어 나가지 않는다.
@<집합 접근자@>=
func (s *XCC) size(x int) int   { return int(s.set[x-1]) }
func (s *XCC) pos(x int) int    { return int(s.set[x-2]) }
func (s *XCC) itemNo(x int) int { return int(s.set[x-3]) }

func (s *XCC) setSize(x, v int)   { s.set[x-1] = int32(v) }
func (s *XCC) setPos(x, v int)    { s.set[x-2] = int32(v) }
func (s *XCC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

@ 이름을 가두는 일은 처음 본 것이면 적어 두고 겹친 것이면 물리친다. 색을 가두는
일은 나중에 다시 보면 이미 있는 번호를 기꺼이 돌려주는데, 여러 옵션이 한 색을
함께 쓸 수 있기 때문이다.
@<이름 가두기@>=
func (s *XCC) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

func (s *XCC) internColor(name string) int {
	if id, ok := s.colorIndex[name]; ok {
		return id
	}
	id := len(s.colorNames)
	s.colorNames = append(s.colorNames, name)
	s.colorIndex[name] = id
	return id
}

@* 춤.
메서드 |Dance|는 행렬을 읽고(입력이 틀렸으면 당황한다) 채널을 열고 고루틴에서
탐색을 띄운다. 곧바로 돌아오며, 고루틴은 일을 마치면 두 채널을 닫으므로 해를
|range|로 훑던 쪽이 저절로 끝맺는다.
@<춤 띄우기@>=
func (s *XCC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)
	@<탐색 고루틴을 띄운다@>
}

@ 띄우는 대목을 함수가 아니라 절로 둔 까닭은, 뒤 장의 |Minimize|가 제 채비를
마친 뒤에 바로 이 줄들을 쓰고 싶어 하기 때문이다. 옵션이 하나도 없는 채로 입력이
끝난 주 아이템, 곧 |baditem|이 있으면 문제 전체가 대놓고 풀리지 않으므로,
탐색을 건너뛰고 채널만 닫는다.
@<탐색 고루틴을 띄운다@>=
s.solStream = make(chan []Option)
s.heartbeat = make(chan string)

go func() {
	defer close(s.solStream)
	defer close(s.heartbeat)

	@<입력 요약을 알린다@>
	if s.PulseInterval > 0 {
		s.pulse = time.NewTicker(s.PulseInterval)
		defer s.pulse.Stop()
	}

	if s.baditem == 0 {
		s.search(0)
	}

	@<총계를 알린다@>
}()

return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}

@ 필드 |Debug|가 켜져 있으면 |dlx| 라이브러리가 찍는 것과 같은 요약 줄로 탐색을
앞뒤에서 감싼다. ``solutions''의 단수와 복수를 따지는 깐깐함까지 그대로다.
@<입력 요약을 알린다@>=
if s.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
}

@ @<총계를 알린다@>=
if s.Debug {
	plural := "s"
	if s.count == 1 {
		plural = ""
	}
	fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
		s.count, plural, s.updates, s.nodes)
}

@ 탐색은 되도는 함수 하나다. 마디마다 걸음을 세고, 문맥에 그만둘 틈을 주고,
맥박을 내민다. 그런 다음---덮개를 모두가 아니라 가장 싼 것을 찾는 길이라면---이
가지를 이제껏 찾은 최선과 견주어 보고, 그러고 나서야 |chooseItem|에게 어디서
분기할지 묻는다. 여기서든 아래에서든 |false|를 돌려주는 것은 ``탐색을 통째로
풀고 나가라''는 뜻이다. 부르던 쪽이 떠났거나 문맥이 끊겼다는 말이고, 그 뜻은 모든
층을 타고 위로 번진다.
@<탐색@>=
func (s *XCC) search(level int) bool {
	s.nodes++
	select {
	case <-s.ctx.Done():
		return false
	default:
	}
	s.tick()
	@<이 가지가 cutoff를 이길 수 없으면 그만둔다@>
	@<이 마디가 더는 감당할 수 없는 옵션을 쓸어 낸다@>

	best, solution := s.chooseItem()
	if solution {
		return s.visit(level)
	}
	@<|best|를 덮고 그 옵션을 차례로 시도한다@>
	return true
}

@ 아이템 |best|를 덮는 일은 그 아이템 자신에서 시작한다. 메서드 |swapOut|이
살아 있는 목록에서 그것을 물리고, |hide|가---무슨 일이 있어도 |best|를 덮기로
마음먹은 참이니 살피지 않는 꼴로---그 옵션들을 저마다 건드리는 {\it 다른\/}
아이템의 집합에서 지운다. 정작 |best| 자신의 집합에 남은 것은 손대지 않는데,
그것이 바로 시도할 후보들이다. 살아 있는 크기를 모두 한 번 찍어 둔 다음
반복한다. 후보를 하나 골라 맡기고, 되돌아 들어갔다가, 크기를 되돌리고, 다시
돈다. 메서드 |restoreSizes|는 맡기기가 잘됐든 아니든 도는 것에 눈여겨보자.
실패한 |commitOption|도 부서진 자리를 반쯤 남기므로 똑같이 되돌려야 한다.
누적값 |s.cost|는 고르기에 따라 오르내려, 마디마다 그 위에서 맡긴 옵션들의 값을
꼭 담는다. 그리고 아직 덮이지 않은 아이템이 무는 세금 |s.taxDue|는 이 옵션이
치르는 세금만큼 내렸다 오른다.
@<|best|를 덮고 그 옵션을 차례로 시도한다@>=
s.swapOut(best)
s.oactive = s.active
s.hide(best, 0, 0)
s.saveSizes(level)
s.choice = ensure(s.choice, level+1)
for c := best; c < best+s.size(best); c++ {
	opt := int(s.set[c])
	s.choice[level] = int32(opt)
	@<이 옵션의 값을 셈한다@>
	@<cutoff가 이미 넘어선 옵션이면 건너뛴다@>
	s.cost += price
	s.taxDue -= tax
	if s.commitOption(opt) {
		if !s.search(level + 1) {
			return false
		}
	}
	s.restoreSizes(level)
	s.cost -= price
	s.taxDue += tax
}

@ 어느 아이템에서 분기할 것인가. Christine Solnon과 크누스는 저 오래된 ``남은
값이 가장 적은 것''(minimum remaining values) 규칙에 제 몫을 하는 주름을 하나
보탰다. 옵션이 {\it 하나\/}로 줄어든 아이템은 강제 이동이니 곧바로 집어 드는
것이 낫고---이 대목이 알맹이인데---누구의 크기도 저장하지 않고 집어 들 수 있다.
그런 아이템은 강제 스택에서 기다린다. 그래서 먼저 스택을 비우고(기다리는 사이에
덮여 버린 아이템은 건너뛴다) 그러고 나서야 가장 비어 가는 주 아이템을 찾아
훑는다. 훑다가 새 외톨이를 쌓았다면 그 가운데 하나가 대신 뽑힌다. 점수 |score|가
|infSize|에서 끝내 나아지지 않았다면 살아 있는 주 아이템이 하나도 없다는 뜻이고,
그것이 곧 해다.
@^Solnon, Christine@>
@^Knuth, Donald Ervin@>
@<아이템 고르기@>=
func (s *XCC) chooseItem() (best int, solution bool) {
	for s.forced != 0 {
		s.forced--
		if f := int(s.force[s.forced]); s.pos(f) < s.active {
			return f, false
		}
	}
	@<살아 있는 주 아이템 가운데 가장 비어 가는 것을 훑는다@>
	if s.forced != 0 {
		s.forced--
		return int(s.force[s.forced]), false
	}
	return best, score == infSize
}

@ 동점이면 가장 왼쪽 아이템이 이기는데, 크누스의 풀이기와 같은 규칙이다. 크기
0은 여기서 나올 수 없다. 메서드 |hide|가 살아 있는 주 아이템을 굶기는 일을
막기 때문이다. 그래서 빈 경우는 스스로를 적어 두고 지나간다.
@<살아 있는 주 아이템 가운데 가장 비어 가는 것을 훑는다@>=
score := infSize
for k := 0; k < s.active; k++ {
	x := int(s.item[k])
	if x >= s.second {
		continue // 부 아이템에서는 분기하지 않는다
	}
	switch sz := s.size(x); {
	case sz == 0:
		// 닿지 않는다: hide는 살아 있는 주 아이템을 굶기지 않는다
	case sz == 1:
		s.force = ensure(s.force, s.forced+1)
		s.force[s.forced] = int32(x)
		s.forced++
	case sz < score || (sz == score && x < best):
		best, score = x, sz
	}
}

@* 덮기와 되돌리기.
옵션 |opt|를 맡기는 자리가 참으로 덮는 일이 일어나는 자리이고, 그 옵션의 노드를
두 번 훑는다. (옵션의 노드는 잇달아 놓여 있고 |itm|이 0 이하인 사이막이 양옆을
싼다. 노드 |opt| 바로 다음부터 사이막의 어긋난 값을 따라가면 옵션을 한 바퀴 돌게
된다.) 첫 훑기는 그 옵션의 다른 아이템을 모두 살아 있는 목록에서 빼내어, 앞으로
어떤 고르기도 거기에 내려앉지 못하게 한다. 둘째 훑기는 이제 부딪히게 된 옵션을
숨긴다. 주 아이템 가운데 하나라도 덮을 길이 끊기면 맡기기를 그만두는데, 이때
강제 스택도 비운다. 거기 걸려 있던 것들은 이 가지와 함께 죽었다.
@<옵션 맡기기@>=
func (s *XCC) commitOption(opt int) bool {
	@<|opt|의 아이템을 살아 있는 목록에서 빼낸다@>
	@<|opt|의 아이템마다 숨기거나 씻어 낸다@>
	return true
}

@ @<|opt|의 아이템을 살아 있는 목록에서 빼낸다@>=
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
		s.updates++
	}
	q++
}
s.active = p

@ 둘째 훑기는 아이템의 두 갈래를 가른다. 주 아이템은 지금 통째로 덮이는
참이므로 그것을 쓰는 다른 옵션은 모두 물러나야 한다. 부 아이템은 {\it 씻기는\/}
참이다. 맡긴 색에 뜻을 모으는 옵션은 살아남고 나머지는 물러난다. 그리고 이
코드가 물려받은 Solnon의 깨달음은, 씻기와 덮기가 한 훑기를 두 각도에서 본 것일
뿐이라 |hide| 하나가 둘을 다 해낸다는 것이다. 앞서 이미 씻긴 부 아이템(그
|pos|가 |oactive| 너머에 있다)은 통째로 건너뛴다.
@<|opt|의 아이템마다 숨기거나 씻어 낸다@>=
for q := opt + 1; q != opt; {
	c := int(s.nd[q].itm)
	if c < 0 {
		q += c
		continue
	}
	switch {
	case c < s.second:
		if !s.hide(c, 0, 1) {
			s.forced = 0
			return false
		}
	case s.pos(c) < s.oactive:
		if !s.hide(c, int(s.nd[q].clr), 1) {
			s.forced = 0
			return false
		}
	}
	q++
}

@ 메서드 |hide|는 아이템 |c|의 집합에 남아 있는 옵션을 훑으며 저마다 {\it 그\/}
옵션의 다른 아이템들의 집합에서 지운다. 색이 주어지면(|c|가 부 아이템이면) 그
색을 함께 쓰는 옵션은 남는데, 그것이 씻기다. 깃발 |check|는 아직 누가 거부권을
가지고 있는지를 |hide|에게 일러 준다. 분기할 아이템 자신을 숨길 때는 아니지만,
맡기는 동안에는 옵션이 0으로 떨어진 주 아이템이 이 가지를 죽이고 하나로 떨어진
주 아이템은 강제 이동이 된다.
@<부딪히는 옵션 숨기기@>=
func (s *XCC) hide(c, color, check int) bool {
	for rr, end := c, c+s.size(c); rr < end; rr++ {
		tt := int(s.set[rr])
		if color != 0 && int(s.nd[tt].clr) == color {
			continue
		}
		@<옵션 |tt|를 그 다른 아이템들의 집합에서 지운다@>
	}
	return true
}

@ 여기에 드디어 희소 집합의 삭제가 제집에서 나온다. 크기를 줄이고, 떠나는 노드를
비워진 마지막 칸으로 맞바꾸고, |loc| 필드 둘을 손본다. 위치 |pos|가 |oactive|에
닿거나 그 너머인 아이템은 이번 맡기기가 빼낸 것이라 나중에 되돌릴 때를 위해
집합이 성해야 하므로 건드리지 않는다.
@<옵션 |tt|를 그 다른 아이템들의 집합에서 지운다@>=
for nn := tt + 1; nn != tt; {
	u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
	if u < 0 {
		nn += u
		continue
	}
	if s.pos(u) < s.oactive {
		ss := s.size(u) - 1
		@<아이템 |u|가 바닥나 가면 거부하거나 강제한다@>
		nnp := int(s.set[u+ss])
		s.setSize(u, ss)
		s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
		s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
		s.updates++
	}
	nn++
}

@ @<아이템 |u|가 바닥나 가면 거부하거나 강제한다@>=
if ss <= 1 && check != 0 && u < s.second && s.pos(u) < s.active {
	if ss == 0 {
		return false
	}
	s.force = ensure(s.force, s.forced+1)
	s.force[s.forced] = int32(u)
	s.forced++
}

@ 고른 아이템 자신을 덮는 일은 배열 |item|에 대고 하는 맨 희소 집합 삭제
하나다.
@<아이템 덮기@>=
func (s *XCC) swapOut(x int) {
	p := s.active - 1
	s.active = p
	pp := s.pos(x)
	cc := int(s.item[p])
	s.item[p], s.item[pp] = int32(x), int32(cc)
	s.setPos(cc, pp)
	s.setPos(x, p)
	s.updates++
}

@ 끝으로 되짚기다. 크누스가 희소 집합으로 처음 지어 본 판은 삭제를 거꾸로
하나하나 되돌렸는데, 나아가는 쪽과 발을 맞춰 손봐야 하는 거울상 코드였다. 여기서
따른 Solnon의 제안은 다행히 더 무디다. 분기하기 전에 살아 있는 아이템의 {\it
크기\/}를 한 번에 저장해 두었다가, 끝나면 그대로 도로 박는다. 위치와 집합의
내용은 손볼 것이 없다. 맞바꿈은 어느 집합이든 제 자신의 순열로 남겨 두었고, 크기를
되돌리면 바로 그만큼의 칸이 다시 살아난다. 배열 |saved|는 층마다 저장 스택이
얼마나 깊었는지를 적어 두는데, 그것이 곧 그때 몇 개의 아이템이 살아 있었는지를
|restoreSizes|에게 일러 주는 값이기도 하다.
@^Solnon, Christine@>
@<되돌리기 장치@>=
func (s *XCC) saveSizes(level int) {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		s.savestack[s.saveptr+p] = twoints{s.item[p], int32(s.size(int(s.item[p])))}
	}
	s.saveptr += s.active
	s.saved = ensure(s.saved, level+2)
	s.saved[level+1] = int32(s.saveptr)
}

func (s *XCC) restoreSizes(level int) {
	s.saveptr = int(s.saved[level+1])
	s.active = s.saveptr - int(s.saved[level])
	for p := -s.active; p < 0; p++ {
		e := s.savestack[s.saveptr+p]
		s.setSize(int(e.l), int(e.r))
	}
}

@* 알리기.
해에 닿으면 스택 |choice|에서 그것을 빚어내---층마다 옵션 하나다---채널로
내려보낸다. 보내는 그 자리가 걸음을 맞추는 자리다. 받아 가던 쪽이 훑기를
그만두었거나 문맥이 끊겼으면 select의 다른 팔이 켜지고 탐색이 통째로 풀린다.
값을 따지는 길이라면, 여기까지 온 덮개는 연단에 오른 것 가운데 가장 비싼 것보다
싸다. 메서드 |search|의 머리에 있는 검사가 그것을 이길 수 없는 가지를 모두 돌려보냈기
때문이다. 그러니 두말없이 그 자리를 차지한다. (맨 |Dance|에는 연단이 없고 그것을
찾지도 않는다.)
@<해에 들르기@>=
func (s *XCC) visit(level int) bool {
	s.count++
	if s.minimizing {
		@<새 덮개를 연단에 올린다@>
	}
	sol := make([]Option, level)
	for k := 0; k < level; k++ {
		sol[k] = s.option(int(s.choice[k]))
	}
	select {
	case <-s.ctx.Done():
		return false
	case s.solStream <- sol:
		return true
	}
}

@ 맥박은 철저히 되는 대로다. 맥이 뛰었으면 진행 줄을 내밀되, 받으려고 기다리는
이가 없으면 버리고 춤을 이어 간다. 탐색의 어느 대목도 맥박 때문에 막히는 일은
없다.
@<맥박@>=
func (s *XCC) tick() {
	if s.pulse == nil {
		return
	}
	select {
	case <-s.pulse.C:
		select {
		case s.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", s.nodes, s.count):
		default:
		}
	default:
	}
}

@ 탐색은 고른 옵션을 그 안의 노드 하나로만 알고 있다. 옵션을 알리려면 그
첫 노드까지 거슬러 갔다가(사이막은 |itm|이 0 이하다) 앞으로 나아가며 아이템마다
이름을 대고 색이 있으면 붙인다. 그 결과는 어느 노드에서 시작했든 상관없이
아이템의 입력 순서대로이므로, 부르는 쪽이 |opt[0]|, |opt[1]|,~\dots\ 하고 자리로
집어 쓸 수 있다.
@<옵션 알리기@>=
func (s *XCC) option(p int) Option {
	for s.nd[p-1].itm > 0 {
		p-- // 옵션의 첫 노드로 옮긴다
	}
	var opt Option
	for q := p; s.nd[q].itm > 0; q++ {
		name := s.names[s.itemNo(int(s.nd[q].itm))]
		if c := s.nd[q].clr; c != 0 {
			name += ":" + s.colorNames[c]
		}
		opt = append(opt, name)
	}
	return opt
}

@** 가장 싼 덮개.
정확 덮개가 아무도 다 들여다볼 마음이 없을 만큼 많은 문제가 흔하고, 그럴 때
재미있는 물음은 {\it 어느 것이냐\/}가 아니라 {\it 얼마나 싸냐\/}가 된다. 옵션마다
값을 매기고 값의 합이 가장 작은 덮개를 달라는 것이다. 최소비용 배정, 최소무게
완전 짝짓기, 가장 싼 집합 분할---저마다 이 물음이 모자를 바꿔 쓴 것이고, 저마다
값표를 덧댄 정확 덮개다.

분기한정이 거기에 답한다. 이제껏 찾은 가장 좋은 덮개의 값인 {\it 최선값\/}을
쥐고 있되, 첫 덮개가 나오기 전에는 무한대다. 마디마다 이 가지가 그것을 이길 수
있기나 한지 묻고, 아니면 돌아선다. 그 합의 절반은 정확히 알고 있다. 이 마디 위에서
맡긴 옵션들에는 값이 있다. 나머지 절반은 부르는 쪽이 덮개를 마저 짓는 데 적어도
얼마가 드는지를 {\it 하한\/}으로 일러 줄 수 있다. 그런 신탁이 없어도 최선값
하나만으로 가지는 쳐진다. 다 지은 덮개보다 이미 비싸진 부분 덮개는 가망이
없으니, 그만큼은 공짜로 얻는다.

크누스의 {\tt DLX5}에서 빌려 온 다듬기가 셋이다. 그 프로그램은 그가 알고리즘~X에
돈 세는 법을 처음 가르친 춤추는 링크 풀이기다. 첫째는 주 아이템마다 매기는
{\it 세금\/}이다. 부르는 쪽이 하한을 주든 말든, 탐색이 제 하한을 공짜로 갖게
된다. 그 이야기는 세금을 걷는 자리에 적는다. 둘째는 그 세금을 한 번 더 부려
마디마다 그 마디가 더는 감당할 수 없는 옵션을 쓸어 내는 것이다. 프로그램
{\tt DLX5}는 정렬된 리스트로 그렇게 하는데 희소 집합은 정렬을 간직할 수 없으므로,
여기서는 다른 모양을 띤다. 셋째는 가장 싼 덮개 하나가 아니라 가장 싼 $k$개를
찾는 것이다. 이제껏 찾은 가장 좋은 덮개 $k$개의 값을 {\it 연단\/}에 올려 두고 그
가운데 가장 비싼 것을 {\it cutoff\/}로 삼는다. 가지가 들여다볼 값어치가 있으려면
이겨야 하는 값이다. 여기서 $k=1$이면 연단에는 덮개 하나가 서 있고 cutoff는 곧 최선값이다.
(cutoff 규칙 자체는 오래되었다. Garfinkel과 Nemhauser가 최소비용 정확 덮개를
푸는 첫 프로그램 가운데 하나에서 썼다 [{\sl Operations Research\/ \bf17} (1969),
848--856].)
@^Knuth, Donald Ervin@>
@^Garfinkel, Robert Sidney@>
@^Nemhauser, George Lann@>

@ 이 장의 어느 것도 |Dance|를 건드리지 않는다. 값을 따지는 출발점은 |Minimize|라는
둘째 출발점이고, 그것을 쓰지 않을 때 탐색은 예전에 돌던 코드를 그대로 돌되 불리언
검사 하나만큼 가난해진다. 부르는 쪽에 새로 드러나는 이름은 셋이다. 출발점 자신과
손잡이 |Bound|와 |Best|다. 하한 함수가 들여다보는 |Frame|은 두 엔진이 같은 것을
내주므로 \.{dcells.w}에 있고, 여기 남는 것은 이 엔진이 그 창에 내놓는 답 넷이다.
@<값 따지기@>=
@<값 따지는 출발점@>
@<창에 답하기@>

@ 하한 신탁도 다른 것과 같은 손잡이이고, 다른 것처럼 그냥 두어도 된다. 필드
|Bound|는 값을 따지는 탐색의 마디마다 불리며, 제 앞의 부분 덮개를 {\it 마저
짓는\/} 데 드는 값의 하한을 돌려주어야 한다. 넘겨짚어 크게 말하면 안 된다.
그러면 탐색이 답을 가지치기로 날려 버린다. 0을 돌려주는 것은 언제나 안전하고
언제나 쓸모없다. 곧 해로 드러날 마디에서는 창이 비어 있으니 성한 하한이라면
무엇이든 0이다.
@<풀이기 손잡이@>=
Bound func(Frame) int // 앞으로 치를 값의 하한, nil이어도 된다

@ 연단의 크기도 손잡이다. 필드 |Best|는 가장 싼 덮개 |Best|개를 찾아 달라는
뜻이고, 0으로 두면 하나, 곧 맨 최소화를 뜻한다.
@<풀이기 손잡이@>=
Best int // Minimize에서 가장 싼 덮개를 몇 개나 찾을 것인가

@ 살림살이의 감춰진 절반이다. 옵션은 읽힌 차례로 $1,2,\ldots$의 번호를 받고,
배열 |optNo|는 노드마다 그것이 속한 옵션의 번호를 알려 주며, |optCost|는 부르는
쪽이 매긴 값을, |optTax|는 그 값 가운데 세금인 몫을 담는다. 모두 |Minimize|가
지어 주기 전까지는 nil인 채인데, 필드 |minimizing|이 뜻하는 바가 바로 그것이다.
@<값 살림살이@>=
minimizing bool
optNo      []int32 // 노드 -> 그 노드가 속한 옵션
optCost    []int32 // 옵션 번호 -> 부르는 쪽이 매긴 값
optTax     []int64 // 옵션 번호 -> 그 값에 든 세금
itemBase   []int32 // 아이템 번호 -> set 안의 밑자리
cost       int64   // 이제껏 맡긴 옵션들의 값
taxDue     int64   // 아직 덮이지 않은 주 아이템들의 세금 합
podium     []int64 // 이제껏 가장 싼 덮개 Best개의 값, 최대 힙
byNet      []pricedOpt // 모든 옵션, 순값이 비싼 것부터
sweptAt    []int32     // 층 -> 그 마디가 byNet의 어디까지 쓸었는가

@ 메서드 |Minimize|는 |Dance|와 같은 입력을 읽고, 값을 매기고, 같은 탐색을
띄운다. 필드 |Best|를 그냥 두면 채널 |Solutions|로 닿는 것은 앞의 것보다 반드시
싼 덮개의 사슬이다. 그러니 가장 새것만 쥐고 있던 쪽은 끝에 최적인 것을 쥐게
되고, 나아지는 과정을 보고 싶은 쪽은 오는 대로 다 찍으면 된다. 덮개가 아예 없는
문제라면 아무것도 닿지 않는다.

필드 |Best|를 $k>1$로 두면 사슬은 더는 한 방향이 아니다. 이제껏 본 $k$번째로 싼
것보다 싸면 그때마다 덮개가 닿고, 탐색이 끝나고 나면 닿은 것 가운데 가장 싼
$k$개가 이 문제의 가장 싼 덮개 $k$개다. 덮개가 $k$개보다 적은 문제라면 그
전부다. 까닭은 cutoff가 오르는 일이 없기 때문이다. 돌려보낸 덮개는 그날의
cutoff보다 싸지 않았고, 그러니 끝에 연단에 선 $k$개보다도 싸지 않다. 값이 같은
덮개들 가운데 어느 것이 연단에 오르는지는 운에 달렸다.

값표를 조각이 아니라 함수로 받는 까닭은, 옵션의 번호가 부르는 쪽이 세고 있기에는
성가신 것이기 때문이다. 빈 줄과 주석과 주 아이템을 하나도 대지 않은 옵션은 번호를
쓰지 않고 지나간다. 그래서 번호와 옵션 자신을, 그것도 해가 닿을 때와 똑같은
모양으로 건네고 답을 받는다. 번호는 어차피 쥐고 있을 값어치가 있다. 나중에
|Bound| 함수가 보게 될 바로 그 손잡이다.
@<값 따지는 출발점@>=
func (s *XCC) Minimize(rd io.Reader, cost func(o int, opt Option) int) *Result {
	s.inputMatrix(rd)
	@<옵션에 값을 매긴다@>
	@<주 아이템마다 세금을 걷는다@>
	@<옵션을 순값 순서로 줄 세운다@>
	@<연단을 차린다@>
	s.minimizing = true
	@<탐색 고루틴을 띄운다@>
}

@ 값매기기는 노드를 한 번 훑는 일이다. 참된 노드는 |itm|이 양수이고 사이막은
그렇지 않으므로, 앞의 것이 사이막인 노드가 새 옵션을 여는 노드다. 거기서 옵션
번호를 하나 올리고, 그 옵션이 얼마인지 부르는 쪽에 묻고, 뒤따르는 노드의 토막에
그 번호를 칠한다.
@<옵션에 값을 매긴다@>=
s.optNo = make([]int32, s.lastNode+1)
s.optCost = make([]int32, int(s.options)+1)
o := int32(0)
for k := 1; k < s.lastNode; k++ {
	if s.nd[k].itm <= 0 {
		continue // 옵션과 옵션 사이의 사이막
	}
	if s.nd[k-1].itm <= 0 {
		o++
		s.optCost[o] = int32(cost(int(o), s.option(k)))
	}
	s.optNo[k] = o
}
@<아이템을 번호로 찾을 표를 짓는다@>

@ 창은 아이템을 그 {\it 번호\/}로 묻는데 춤은 아이템을 배열 |set| 안의 {\it
밑자리\/}로 알고 있으니, 그 둘을 이어 줄 표가 하나 있어야 한다. 밑자리는 지금
모두 배열 |item|에 마무리가 남겨 둔 차례대로 앉아 있고, 저마다 제 번호를 달고
있다.
@<아이템을 번호로 찾을 표를 짓는다@>=
s.itemBase = make([]int32, s.itemlen+1)
for k := 0; k < s.itemlen; k++ {
	base := int(s.item[k])
	s.itemBase[s.itemNo(base)] = int32(base)
}

@ 이제 세금이다. 어느 덮개든 주 아이템마다 그 집합에서 옵션을 꼭 하나 가져가므로,
아이템에 세금~$t$를 매기고 그 아이템을 담은 옵션마다 값에서 $t$를 깎으면 모든
덮개가 똑같이 $t$만큼 싸진다. 가장 싼 덮개는 여전히 가장 싸다. 옵션의 값에서 그
아이템들의 세금을 모두 뺀 나머지를 크누스는 {\it 순값\/}이라 부른다. 세금 $t$로
그 아이템을 매길 그때 그 아이템의 옵션들 가운데 가장 작은 순값을 고르면, 두 가지
일이 함께 일어난다. 어느 순값도 음수가 되지 않는다. 그 아이템을 담은 옵션은
그전에 적어도 $t$였기 때문이다. 그리고 그 아이템의 집합에서 가장 싼 옵션은 이제
순값이 0이 되고, 그 뒤로도 줄곧 0이다. 나중에 걷는 세금이 그것을 넘을 수 없기
때문이다.

답이 달라지지도 않는데 왜 이 수고를 하는가. 부분 덮개에 쌓인 값은 이 자리바꿈을
보지 못하지만 앞으로 올 덮개들은 보기 때문이다. 덮개를 마저 짓는 옵션들은 아직
살아 있는 주 아이템을 저마다 꼭 한 번씩 나눠 덮어야 하고, 그 옵션 하나하나가 제
세금에 음수가 아닌 순값을 더한 값을 문다. 그러니 살아 있는 아이템들의 세금
|taxDue|가 앞으로 치를 값의 하한이다. 옵션을 하나도 들여다보지 않고 얻고, 맡긴
옵션마다 뺄셈 한 번으로 새로 고쳐지는 하한이다. 프로그램 {\tt DLX5}가 순값끼리
견주어 얻는 것과 정확히 같은 것을, 부르는 쪽의 화폐로 적은 셈이다.

덤이 하나 딸려 온다. 이 논증은 값이 양수이기를 어디서도 바라지 않는다. 세금은
음수여도 되고, 음수가 되어서는 안 되는 것은 순값이다. 그러니 부르는 쪽은 옵션에
음수 값을 매겨도 된다. 옵션마다 주 아이템을 하나는 담고 있기만 하면 되는데, 이
엔진에서는 언제나 그렇다. 하나도 담지 않은 옵션은 입력이 버리기 때문이다.
@<주 아이템마다 세금을 걷는다@>=
s.optTax = make([]int64, len(s.optCost))
s.taxDue = 0
for k := 0; k < s.active; k++ {
	x := int(s.item[k])
	if x >= s.second || s.size(x) == 0 {
		continue // 부 아이템은 세금을 물지 않고, 옵션이 없는 아이템도 그렇다
	}
	@<아이템 |x|의 옵션 가운데 가장 작은 순값 |t|를 찾는다@>
	for c := x; c < x+s.size(x); c++ {
		s.optTax[s.optNo[int(s.set[c])]] += t
	}
	s.taxDue += t
}

@ 옵션의 순값은 그 값에서 이제껏 문 세금을 뺀 것이다.
@<아이템 |x|의 옵션 가운데 가장 작은 순값 |t|를 찾는다@>=
t := infCost
for c := x; c < x+s.size(x); c++ {
	o := s.optNo[int(s.set[c])]
	t = min(t, int64(s.optCost[o])-s.optTax[o])
}

@ 연단은 |Best|개의 빈자리로 시작하고 자리마다 값이 |infCost|이므로, 처음 오는
|Best|개의 덮개는 겨룰 것 없이 올라선다.
@<연단을 차린다@>=
s.podium = make([]int64, max(s.Best, 1))
for i := range s.podium {
	s.podium[i] = infCost
}

@ 여기가 |search|의 머리에 끼워 넣은 가지치기 검사다. 값 |true|를 돌려주면 이
가지를 버리고 탐색은 다른 데서 이어 간다. 값 |false|를 돌려주는 것은 문맥이 끊겼을
때뿐이다. 덮개의 나머지가 치를 값은 적어도 아직 물어야 할 세금만큼이고, 적어도
부르는 쪽의 |Bound|가 말하는 만큼이다. 그러니 둘 가운데 큰 쪽만큼은 된다.
cutoff는 연단의 꼭대기다. 견줌이 |>|가 아니라 |>=|이므로 cutoff와 비기기만 한
덮개도 잘린다. 손잡이 |Best|가 하나일 때 닿는 덮개가 반드시 싸지는 까닭이 그것이다.
@<이 가지가 cutoff를 이길 수 없으면 그만둔다@>=
if s.minimizing {
	rest := s.taxDue
	if s.Bound != nil {
		rest = max(rest, int64(s.Bound(Frame{s})))
	}
	if s.cost+rest >= s.podium[0] {
		return true
	}
}

@ 그리고 여기가 옵션 하나의 값과 거기 든 세금을 그 안의 노드로 찾아 오는
자리다. 가지마다 두 번 찾는데, 내려갈 때 한 번 올라올 때 한 번이다. 맨 |Dance|는
표를 지은 적이 없으니 검사 말고는 무는 것이 없다.
@<이 옵션의 값을 셈한다@>=
price, tax := int64(0), int64(0)
if s.minimizing {
	o := s.optNo[opt]
	price, tax = int64(s.optCost[o]), s.optTax[o]
}

@ 새 덮개는 연단에서 가장 비싼 것을 밀어내고 그 자리에 오르는데, 가장 비싼 것은
힙의 뿌리에 있다. 새로 온 것도 뿌리에서 시작해 제 자식 가운데 더 비싼 쪽과
자리를 바꿔 가며 가라앉고, 두 자식 모두 저보다 비싸지 않으면 멎는다. 새 뿌리가
곧 새 cutoff다.
@<새 덮개를 연단에 올린다@>=
h, i := s.podium, 0
for j := 1; j < len(h); j = 2*i + 1 {
	if j+1 < len(h) && h[j+1] > h[j] {
		j++ // 더 비싼 자식
	}
	if h[j] <= s.cost {
		break
	}
	h[i] = h[j]
	i = j
}
h[i] = s.cost

@ 세금은 하한을 내주는 데서 그치지 않는다. 어떤 마디가 값 |cost|어치 옵션을
맡겼고 아직 |taxDue|만큼 세금을 물어야 한다고 하자. 그리고 순값이 $\nu(o)$인
옵션 $o$를 생각하자. 이 마디 아래에서 옵션 $o$를 쓰는 덮개는 적어도
$|cost|+|taxDue|+\nu(o)$를 문다. 이미 맡긴 옵션들, 그다음 제 아이템들의 세금에
$\nu(o)$를 더해 무는 옵션 $o$ 자신, 그다음 남에게 남겨 둔 아이템들의 세금이다.
그 합이 cutoff보다 낮지 않다면 옵션 $o$는 이 마디 아래 어디서도 쓸모가 없다.
더 깊이 갈수록 $|cost|+|taxDue|$는 오르기만 한다. 맡기는 옵션마다 음수가 아닌
제 순값을 보태기 때문이다. 그리고 cutoff는 내리기만 한다. 값
$|cutoff|-|cost|-|taxDue|$를 그 마디의 {\it 예산\/}이라 부르자. 순값이 예산
아래가 아닌 옵션은 버려도 된다.

프로그램 {\tt DLX5}는 아이템마다 리스트를 순값 순서로 정렬해 두어 이것을 싸게
해낸다. 그러면 아이템을 덮다가 예산을 넘는 옵션을 만나는 순간 멈추면 된다. 이
재주는 리스트가 정렬된 채로 있어야 쓸 수 있고, 춤추는 링크는 그것을 지켜 준다.
노드를 링크에서 빼내도 이웃들의 차례는 그대로이기 때문이다. 희소 집합은 그렇지
않다. 삭제는 떠나는 옵션을 집합의 마지막 것과 맞바꾸므로, 한 번만 지워도 차례가
영영 흐트러진다. 그래서 우리는 움직이지 않는 다른 것을 정렬한다. 모든 옵션을
순값이 비싼 것부터 늘어놓은 줄 |byNet|이다. 한 마디의 예산을 넘는 옵션은 그
줄의 앞토막을 이루고, 예산은 내려갈수록 줄기만 하므로 자식의 앞토막은 부모의
앞토막을 늘인 것이 된다. 그러니 마디마다 부모가 멈춘 자리에서 이어받아, 순값이
예산 아래가 아닌 동안 앞으로 걸으며, 지나치는 옵션을 아직 그것을 담고 있는 살아
있는 아이템들의 집합에서 지운다. 배열 |sweptAt[level]|이 어디서 멈췄는지를 적어
둔다.

되돌리는 데는 아무것도 들지 않는다. 그 삭제는 |hide|가 하는 것과 같은 희소 집합
맞바꿈이고, 부모가 다음으로 넘어갈 때 |restoreSizes|가 도로 써 넣는 크기가
자식이 쓸어 낸 옵션을 모두 다시 들인다. 춤추는 칸이 앞서는 자리가 여기다.
프로그램 {\tt DLX5}는 덮을 때 쓴 문턱값 그대로 되덮어야 하는데 그 사이에 제
cutoff가 움직이기 때문이지만, 되돌린 크기는 그런 것에 아랑곳하지 않는다. 다만
건드려도 되는 것은 {\it 살아 있는\/} 아이템의 집합뿐이다. 조상이 분기한 아이템은
살아 있지 않고, 그 조상의 반복문이 바로 이 순간 그 집합을 훑고 있다. 거기서 칸을
맞바꾸면 그 반복문이 옵션 하나를 건너뛰고 다른 하나를 두 번 시도하게 된다.

쓸기는 그 뒤의 모든 것을 날카롭게 만든다. 옵션이 죄다 예산을 넘는 아이템은 죽은
것이니 그 가지를 그 자리에서 그만둔다. 메서드 |chooseItem|이 견주는 크기는 이제
이 마디가 감당할 수 있는 옵션만 세고, 그래서 남은 값이 가장 적은 것을 고르는
규칙이 문제를 있는 그대로 보게 된다. 그리고 부르는 쪽의 |Bound|도 |Frame|으로
그 줄어든 행렬을 본다.
@<이 마디가 더는 감당할 수 없는 옵션을 쓸어 낸다@>=
if s.minimizing {
	budget := s.podium[0] - s.cost - s.taxDue
	p := 0
	if level > 0 {
		p = int(s.sweptAt[level-1])
	}
	for ; p < len(s.byNet) && s.byNet[p].net >= budget; p++ {
		@<옵션 |s.byNet[p]|를 살아 있는 집합에서 지우거나 그만둔다@>
	}
	s.sweptAt = ensure(s.sweptAt, level+1)
	s.sweptAt[level] = int32(p)
}

@ 지우는 일은 |hide|의 그것인데 두 가지가 다르다. 옵션이 이미 어떤 집합에서는
빠져 있을 수 있다. 위에서 맡기며 숨겼거나 조상이 쓸어 냈거나 한 것인데, 그런
집합에서는 할 일이 없다. 그리고 옵션이 하나도 남지 않은 주 아이템은 이 가지를
끝낸다. 옵션 하나를 지우다 말고 그만두면 어떤 집합에서는 지워지고 어떤 집합에서는
남지만, 해로울 것이 없다. 바로 다음에 일어날 일이 부모의 |restoreSizes|이기
때문이다. 뿌리에는 부모가 없고, 거기서 그만둔다는 것은 탐색이 끝났다는 뜻이다.
@<옵션 |s.byNet[p]|를 살아 있는 집합에서 지우거나 그만둔다@>=
for nn := int(s.byNet[p].node); s.nd[nn].itm > 0; nn++ {
	u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
	if s.pos(u) >= s.active || v >= u+s.size(u) {
		continue // 살아 있지 않은 아이템이거나, 이 옵션이 이미 떠난 집합이다
	}
	ss := s.size(u) - 1
	if ss == 0 && u < s.second {
		return true // 주 아이템에 감당할 수 있는 옵션이 하나도 남지 않았다
	}
	nnp := int(s.set[u+ss])
	s.setSize(u, ss)
	s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
	s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
	s.updates++
}

@ 줄은 세금을 걷고 난 뒤에 한 번 늘어놓는다. 그때부터 순값이 굳기 때문이다.
줄의 칸은 \.{dcells.w}의 타입 |pricedOpt|인데, 위의 지우기가 걷기 시작하는
자리인 옵션의 첫 노드와 그 순값이다. 안정 정렬이라 순값이 같은 옵션은 입력
순서를 지킨다.
@<옵션을 순값 순서로 줄 세운다@>=
s.byNet = s.byNet[:0]
for k := 1; k < s.lastNode; k++ {
	if s.nd[k].itm > 0 && s.nd[k-1].itm <= 0 {
		o := s.optNo[k]
		s.byNet = append(s.byNet,
			pricedOpt{int32(k), int64(s.optCost[o]) - s.optTax[o]})
	}
}
slices.SortStableFunc(s.byNet, func(a, b pricedOpt) int {
	return cmp.Compare(b.net, a.net)
})

@ 손위 형제들을 들여다보는 사이에 옵션이 예산 밖으로 밀려날 수 있다. 그들이
찾아내는 덮개마다 cutoff를 끌어내리기 때문이다. 메서드 |search|의 머리가 그런 옵션을
돌려보내기는 하겠지만, 그것은 |commitOption|이 제 일을 다 하고 난 뒤다. 먼저
살피면 견줌 한 번이면 된다.
@<cutoff가 이미 넘어선 옵션이면 건너뛴다@>=
if s.minimizing && s.cost+price+s.taxDue-tax >= s.podium[0] {
	continue
}

@ 프로그램 {\tt DLX5}의 착상 하나는 재 보고 들이지 않았다. 그 프로그램 끝머리에서
크누스는 남은 옵션들의 ``아이템당 값''으로 더 센 하한을 지을 수 있겠다고 귀띔하고는,
알아볼 겨를이 없었다고 덧붙인다. 내가 재 본 판은 이렇다. 살아 있는 옵션의 순값을
그 옵션이 덮는 살아 있는 주 아이템들에게 똑같이 나눠 주고, 아이템마다 제 옵션들이
준 몫 가운데 가장 작은 것을 쥐게 한 다음, 그 몫들을 모두 더해 올림한다. 그 합은
앞으로 치를 순값의 하한이다. 덮개를 마저 짓는 옵션들이 제 순값을 몫으로 고스란히
나눠 주고, 아이템마다 적어도 제 가장 작은 몫은 받기 때문이다. 쓸기 뒤에 |taxDue|에
더해 보았더니 이 글의 모든 테스트를 통과했다.

그런데 값을 하지 못했고, 그 까닭이 배울 만하다. 가장 싼 횡단 예제
(\.{examples/transversal})에서 부르는 쪽의 하한 없이 돌렸을 때 노드는 2배에서
2.6배로 줄었지만 시간은 $n=21$과 23에서 15퍼센트에서 23퍼센트밖에 줄지 않았고,
$n=19$에서는 오히려 느려졌다. 부르는 쪽의 헝가리안 하한과 함께 쓰면 달라지는 것이
거의 없었다. 텅 빈 심장 파티지(\.{examples/hollow})에서는 노드를 하나도 줄이지
못하고 탐색을 열 배 느리게 만들었다. 세금이 이미 아이템마다 가장 싼 옵션을,
그것도 한 옵션을 두 번 세는 일 없이 더해 주고, 쓸기가 이미 마디가 감당할 수 없는
것을 버린다. 몫이 새로 알아낼 것은 적은데, 그것을 셈하려면 마디마다 살아 있는
칸을 두 번씩 훑어야 한다. 제 문제가 앞쪽 부류임을 아는 이라면 |Bound|로 이 하한을
그대로 건넬 수 있다.

@ 이 엔진이 창에 내놓는 답 넷이 여기 있다. 행렬의 살아 있는 몫을 걷는다는 것은
살아 있는 아이템을 걷되 부 아이템은 건너뛰고---그들은 제 몫으로 요구하는 것이
없다---살아남은 아이템마다 그 집합을 훑는다는 뜻이다.
@<창에 답하기@>=
func (s *XCC) eachLive(yield func(item, opt int) bool) {
	for k := 0; k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue
		}
		i := s.itemNo(x)
		for c := x; c < x+s.size(x); c++ {
			if !yield(i, int(s.optNo[int(s.set[c])])) {
				return
			}
		}
	}
}

@ 나머지 셋은 찾아보기다. 엔진 |XCC|에서 아직 살아 있는 아이템은 꼭 한 번 더
덮이기를 바라는데, 여기서 ``정확''이 뜻하는 바가 그것이 전부다. 부 아이템은
바라는 것이 없다.
@<창에 답하기@>=
func (s *XCC) optionCost(opt int) int { return int(s.optCost[opt]) }
func (s *XCC) itemName(item int) string { return s.names[item] }

func (s *XCC) itemNeed(item int) int {
	if int(s.itemBase[item]) < s.second {
		return 1
	}
	return 0
}

@** DLX 입력 읽기.
형식 {\tt DLX}---아이템 줄 하나, 그다음 옵션마다 한 줄---는 \.{dcells.w}에
적혀 있고, 이 단계가 기대는 작은 훑개도 거기 있다. 함수 |nextLine|과 |token|과
|skipSpace|, 그리고 부르는 쪽이 애초에 쓰지 말았어야 할 틀린 입력을 알리는
|failf|다. 여기 남는 것은 {\it 이\/} 엔진의 배열을 아는 몫이고, 춤을 모는 쪽이
부르는 차례대로 적는다. 읽기는 두 걸음이다. 아이템 줄을 읽고, 옵션을 읽는다. 그런
다음 춤이 기다리는 희소 집합을 깔아 두는 {\it 마무리\/}가 따른다.
@<입력 단계@>=
func (s *XCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

@<아이템 이름 읽기@>
@<옵션 읽기@>
@<입력 마무리@>

@ 아이템 줄은 비지도 주석도 아닌 첫 줄이다. 낱말 하나씩 걸으며, 외따로 선
\.{\|}는 주 아이템에서 부 아이템으로 넘어가라는 뜻이고(한 번만 나올 수 있다),
그 밖의 것은 이름이라 가두기 전에 금지된 글자 \.{:}과 \.{\|}이 들었는지, 겹치지는
않는지 살핀다. 끝에 이르면 |lastItm|이 아이템 수에 하나를 더한 값인데, |names[0]|을
쓰지 않기 때문이다.
@<아이템 이름 읽기@>=
func (s *XCC) readItemNames(br *bufio.Reader) {
	@<아이템 줄을 찾는다@>
	for buf[p] != 0 {
		name, next := token(buf, p, false)
		if name == "|" {
			if s.second != secondUnset {
				failf("item name line contains | twice")
			}
			s.second = len(s.names) // 다음 아이템의 번호
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
	s.lastItm = len(s.names) // 아이템 수 + 1 (names[0]은 쓰지 않는다)
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

@ 남은 줄은 저마다 옵션 하나다. 빈 줄과 주석은 건너뛰고, 흐름이 끝나면 마무리가
켜진다.
@<옵션 읽기@>=
func (s *XCC) readOptions(br *bufio.Reader) {
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

@ 옵션 하나를 읽는 일은 이름과, 있다면 색을 훑는 반복이다. 주 아이템을 하나도
대지 않은 옵션은 고를 수가 없으므로---맡겨 봐야 덮이는 것이 없다---노드를 하나씩
조용히 되감아 버린다. 크누스의 풀이기는 여기서 경고를 찍지만 이쪽은 그냥
버린다. 참된 옵션은 사이막 노드로 봉해 토막이 서로 갈리게 둔다.
@<옵션 읽기@>=
func (s *XCC) readOption(buf []byte) {
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

@ 이름 뒤에 쌍점을 두고 색이 따라올 수 있는데, 부 아이템에서만 그렇다.
@<아이템 이름 하나와 그 색을 훑는다@>=
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

@ 되감기는 반쯤 지은 노드를 하나씩 걷어 내고 입력 단계의 칸에 세어 둔 것도
도로 물린다.
@<옵션을 되감는다@>=
for s.lastNode > spacer {
	slot := int(s.nd[s.lastNode].itm) << 2
	s.setSize(slot, s.size(slot)-1)
	s.setPos(slot, spacer-1)
	s.lastNode--
}

@ 입력을 읽는 동안 배열 |set|은 |m<<2|이라는 성긴 간격으로 쓰인다. 아이템마다
잡아 둘 칸이 들어갈 만큼이다. 그리고 |createNode|는 거기에 아이템 |m|의 노드를
하나 더 세어 두는데, 그 아이템을 마지막으로 본 자리가 이미 이 옵션 안이면 한
옵션에 같은 아이템이 두 번 나온 것이니 그것을 잡아낸다.
@<옵션 읽기@>=
func (s *XCC) createNode(m, spacer int, hasPrimary *bool) {
	slot := m << 2
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

@ 마무리는 성기게 세어 둔 입력을 춤이 쓸 참된 배치로 바꾸는데, 자료를 세 번
훑는다.
@<입력 마무리@>=
func (s *XCC) finalize() {
	@<set 배열을 깐다@>
	@<아이템 머리를 채운다@>
	@<노드가 가리키는 곳을 고친다@>
}

@ 첫 훑기는 아이템마다 배열 |set|에 촘촘한 밑자리를 내주고---그 아래에 |primExtra|
칸을 잡아 둔다---주 아이템과 부 아이템의 경계를 그 좌표로 옮긴다. 아이템 줄에
\.{\|}가 없는 문제에는 부 아이템이 없고, 그때 |second|는 배열 |set|에서 쓰이는
몫 바로 너머에 내려앉는다.
@<set 배열을 깐다@>=
s.active, s.itemlen = s.lastItm-1, s.lastItm-1
s.item = ensure(s.item, s.itemlen)
s.set = ensure(s.set, (s.itemlen<<2)+1) // 입력 칸을 모두 읽을 수 있게

j := primExtra
k := 0
for ; k < s.itemlen; k++ {
	s.item[k] = int32(j)
	j += primExtra + s.size((k+1)<<2)
}
s.setlen = j - primExtra
s.set = ensure(s.set, j+1)
if s.second == secondUnset {
	s.osecond, s.second = s.active, j
} else {
	s.osecond = s.second - 1
}

@ 둘째 훑기는 거꾸로 도는데, 세어 둔 입력을 그 칸이 덮이기 전에 읽기 위해서다.
아이템마다 크기와 위치와 번호를 채우고, 옵션이 하나도 없이 끝난 주 아이템이
있으면 |baditem|으로 표시한다.
@<아이템 머리를 채운다@>=
for ; k != 0; k-- {
	base := int(s.item[k-1])
	if k == s.second {
		s.second = base
	}
	s.setSize(base, s.size(k<<2))
	if s.size(base) == 0 && k <= s.osecond {
		s.baditem = k
	}
	s.setPos(base, k-1)
	s.setItemNo(base, k)
}

@ 셋째 훑기는 노드마다 |itm|과 |loc|을 아이템 번호와 아이템별 셈에서 참된 |set|
색인으로 고쳐 쓰고, 노드를 제자리에 떨어뜨린다. 이것으로 희소 집합은 춤출 채비를
마친다.
@<노드가 가리키는 곳을 고친다@>=
for k = 1; k < s.lastNode; k++ {
	if s.nd[k].itm < 0 {
		continue
	}
	base := int(s.item[int(s.nd[k].itm)-1])
	loc := base + int(s.nd[k].loc)
	s.nd[k].itm = int32(base)
	s.nd[k].loc = int32(loc)
	s.set[loc] = int32(k)
}

@** 테스트.
문학적 프로그램이라면 제가 살아 있다는 증거를 스스로 지니는 것이 옳다. 이 마지막
부분은 같은 원본에서 짜이되 {\it 따로\/} 선 파일 \.{ssxcc\_test.go}로 tangle되는데,
주된 출력이 아니라 곁딸린 출력의 이름을 대는 \.{GWEB}의 파일 출력 제어 코드를
쓴 덕이다. 그러면 |go test|가 답을 이미 아는 작은 문제로 엔진을 부려 본다.

함께 쓰는 도우미 |collect|는 풀이기를 돌리고 해마다 그것을 하나의 표준 문자열로
빚는다. 옵션 안의 아이템 이름을 정렬하고, 해 안의 옵션을 정렬하고, 끝으로 해들
자체를 정렬한다. 그러면 테스트가 어떤 차례로 찾았는지에 아랑곳없이 바라는 값과
견줄 수 있다.
@(ssxcc_test.go@>=
package dcells

import (
	"fmt"
	"math/rand"
	"sort"
	"strings"
	"testing"
)

func collect(t *testing.T, input string) []string {
	t.Helper()
	res := NewXCC().Dance(strings.NewReader(input))
	var sols []string
	for sol := range res.Solutions {
		opts := make([]string, len(sol))
		for i, opt := range sol {
			opts[i] = strings.Join(opt, " ")
		}
		sort.Strings(opts)
		sols = append(sols, strings.Join(opts, " | "))
	}
	sort.Strings(sols)
	return sols
}

@ 가장 담백한 테스트는 교과서의 그것이다. {\sl TAOCP\/} 7.2.2.1에 나오는 크누스의
옵션 여섯 짜리 보기인데, 그 정확 덮개는 $\{a\,d\,f\}$, $\{b\,g\}$, $\{c\,e\}$
하나뿐이다. 나머지 둘은 색을 다루는 기계를 살피고, 덮을 수 없는 아이템이 있으면
해가 하나도 나오지 않음을 확인한다.
@(ssxcc_test.go@>=
func TestExactCover(t *testing.T) {
	// TAOCP 7.2.2.1의 고전적인 보기: 덮개는 {a d f},{b g},{c e} 하나뿐이다.
	input := "a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n"
	sols := collect(t, input)
	if len(sols) != 1 {
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
	}
	want := "a d f | b g | c e"
	if sols[0] != want {
		t.Errorf("got %q, want %q", sols[0], want)
	}
}

func TestColors(t *testing.T) {
	// 색이 붙은 부 아이템 x, y가 있고 정확 덮개는 둘이다.
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
	sols := collect(t, input)
	if len(sols) != 2 {
		t.Fatalf("want 2 solutions, got %d: %v", len(sols), sols)
	}
}

func TestNoSolution(t *testing.T) {
	// 아이템 c는 덮일 길이 없다.
	input := "a b c\na b\n"
	res := NewXCC().Dance(strings.NewReader(input))
	n := 0
	for range res.Solutions {
		n++
	}
	if n != 0 {
		t.Errorf("want 0 solutions, got %d", n)
	}
}

@ 아이템 이름과 색은 아무 문자열이어도 되므로, 다음 테스트는 여러 글자짜리
색(\.{England})을 써서 그 이름이 출력까지 살아 남는지를 본다. 얼룩말 퍼즐과
낱말 찾기 예제가 기대는 것이 바로 그것이다.
@(ssxcc_test.go@>=
func TestMultiCharColorAndLongNames(t *testing.T) {
	input := "house1 house2 | nationality\n" +
		"house1 nationality:England\nhouse2 nationality:England\n"
	sols := collect(t, input)
	if len(sols) != 1 {
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
	}
	// 옵션마다 색 이름이 출력에 그대로 남는다.
	if !strings.Contains(sols[0], "nationality:England") {
		t.Errorf("color name lost: %q", sols[0])
	}
}

@ 좀 더 매운 연습은 $n$-퀸 문제를 정확 덮개로 적는 것이다. 행과 열이 주 아이템이고
두 대각선 무리가 부 아이템인데, 해의 수가 알려진 값(각각 $n=6,7,8$에 4, 40,
92)과 맞는지 본다. 판을 짓는 일과 그 덮개를 세는 일을 따로 둔 까닭은, 아래의
최소화 테스트가 같은 판에 다른 값을 매겨 쓰고 싶어 하기 때문이다.
@(ssxcc_test.go@>=
func nQueensInput(n int) string {
	var b strings.Builder
	@<$n$-퀸의 아이템 줄을 쓴다@>
	@<$n$-퀸의 옵션을 쓴다@>
	return b.String()
}

@ 행과 열이 주 아이템이고, 퀸이 덮지 않고 남겨도 되는 두 대각선 무리가 부
아이템이다. 두 자리로 적는 |itoa|는 지어내는 이름을 짧고 가지런하게 둔다.
@<$n$-퀸의 아이템 줄을 쓴다@>=
for i := 0; i < n; i++ {
	b.WriteString(itoa("r", i))
}
for j := 0; j < n; j++ {
	b.WriteString(itoa("c", j))
}
b.WriteString("|")
for k := 0; k < 2*n-1; k++ {
	b.WriteString(itoa(" a", k))
}
for k := 0; k < 2*n-1; k++ {
	b.WriteString(itoa(" b", k))
}
b.WriteString("\n")

@ 칸마다 옵션 하나이고, 그 칸에서 만나는 행과 열과 두 대각선을 댄다. 그 차례가
아래의 값매기기가 기대는 차례다.
@<$n$-퀸의 옵션을 쓴다@>=
for i := 0; i < n; i++ {
	for j := 0; j < n; j++ {
		b.WriteString(itoa("r", i))
		b.WriteString(itoa("c", j))
		b.WriteString(itoa("a", i+j))
		b.WriteString(itoa("b", i-j+n-1))
		b.WriteString("\n")
	}
}

@ @(ssxcc_test.go@>=
func nQueensCount(t *testing.T, n int) int {
	t.Helper()
	res := NewXCC().Dance(strings.NewReader(nQueensInput(n)))
	n2 := 0
	for range res.Solutions {
		n2++
	}
	return n2
}

func itoa(prefix string, x int) string {
	return prefix + string(rune('0'+x/10)) + string(rune('0'+x%10)) + " "
}

func TestQueens(t *testing.T) {
	// 알려진 n-퀸 해의 수.
	for n, want := range map[int]int{6: 4, 7: 40, 8: 92} {
		if got := nQueensCount(t, n); got != want {
			t.Errorf("%d-queens: got %d, want %d", n, got, want)
		}
	}
}

@ 최소화에는 손으로 따져 볼 만큼 작은 문제를 준다. 아이템 |a|, |b|, |c| 위에
값이 매겨진 옵션이 다섯이고 덮개는 꼭 셋이다. 덮개 $\{abc\}$가 10, $\{ab\}+\{c\}$가 3,
$\{a\}+\{bc\}$가 7이다. 값은 옵션이 찍히는 모양을 열쇠로 삼아 적어 두었는데,
그래야 테스트가 돌려받은 덮개를 값을 매길 때와 똑같은 방식으로 더할 수 있다.
탐색이 어떤 차례로 이들과 마주치든 닿는 덮개는 그때마다 반드시 싸져야 하고,
마지막 것은 3이어야 한다.
@(ssxcc_test.go@>=
func TestMinimize(t *testing.T) {
	input := "a b c\na b c\na b\nc\na\nb c\n"
	price := map[string]int{"a b c": 10, "a b": 1, "c": 2, "a": 4, "b c": 3}
	res := NewXCC().Minimize(strings.NewReader(input),
		func(_ int, opt Option) int { return price[strings.Join(opt, " ")] })
	var seen []int
	for sol := range res.Solutions {
		c := 0
		for _, opt := range sol {
			c += price[strings.Join(opt, " ")]
		}
		seen = append(seen, c)
	}
	@<덮개가 나아지며 3에서 끝나는지 살핀다@>
}

@ @<덮개가 나아지며 3에서 끝나는지 살핀다@>=
if len(seen) == 0 {
	t.Fatal("no cover found")
}
for i := 1; i < len(seen); i++ {
	if seen[i] >= seen[i-1] {
		t.Fatalf("costs not strictly decreasing: %v", seen)
	}
}
if got := seen[len(seen)-1]; got != 3 {
	t.Errorf("cheapest cover costs %d, want 3", got)
}

@ 더 매운 테스트는 $n$-퀸 판에 값을 매긴다. 퀸 하나의 값은 주대각선에서 떨어진
거리의 제곱이므로, 가장 싼 배치는 그 선에 바싹 붙은 것이다. 차수 $n=8$의 해 92개를
모두 세어 가장 작은 것을 취하면 이겨야 할 답이 나온다. 메서드 |Minimize|는 하한
함수를 달고도 달지 않고도 같은 수에 닿아야 한다.
@(ssxcc_test.go@>=
func queenPrice(opt Option) int {
	d := digits(opt[0]) - digits(opt[1]) // 행 아이템, 그다음이 열 아이템
	if d < 0 {
		d = -d
	}
	return d * d
}

func digits(name string) int { return int(name[1]-'0')*10 + int(name[2]-'0') }

func coverPrice(sol []Option) int {
	c := 0
	for _, opt := range sol {
		c += queenPrice(opt)
	}
	return c
}

@ 값이 음수만 아니라면 언제나 옳은 하한이 여기 있다. 아직 살아 있는 아이템은
저마다 살아남은 옵션 가운데 하나로 덮여야 하므로, 그 가운데 가장 싼 것이 그
아이템 몫의 바닥이다. 그리고 그런 바닥 가운데 가장 비싼 것이 전체의 바닥이다.
필드 |Live|가 한 아이템의 옵션을 몰아서 내주므로, 이 훑기가 바라는 모양이 바로
그것이다.
@(ssxcc_test.go@>=
func cheapestPerItem(f Frame) int {
	bound, item, low := 0, -1, 0
	for i, opt := range f.Live {
		if i != item {
			bound = max(bound, low)
			item, low = i, f.Cost(opt)
		} else if c := f.Cost(opt); c < low {
			low = c
		}
	}
	return max(bound, low)
}

func minCostQueens(n int, bound func(Frame) int) (price int, nodes uint64) {
	s := NewXCC()
	s.Bound = bound
	res := s.Minimize(strings.NewReader(nQueensInput(n)),
		func(_ int, opt Option) int { return queenPrice(opt) })
	price = -1
	for sol := range res.Solutions {
		price = coverPrice(sol)
	}
	return price, s.Nodes()
}

@ @(ssxcc_test.go@>=
func TestMinimizeQueens(t *testing.T) {
	const n = 8
	want := -1
	res := NewXCC().Dance(strings.NewReader(nQueensInput(n)))
	for sol := range res.Solutions {
		if c := coverPrice(sol); want < 0 || c < want {
			want = c
		}
	}
	plain, nodes := minCostQueens(n, nil)
	if plain != want {
		t.Errorf("Minimize found %d, want %d", plain, want)
	}
	bounded, fewer := minCostQueens(n, cheapestPerItem)
	if bounded != want {
		t.Errorf("Minimize with a bound found %d, want %d", bounded, want)
	}
	t.Logf("%d nodes without a bound, %d with one", nodes, fewer)
}

@ 가장 싼 덮개 $k$개를 달라는 것도 같은 방식으로, 목록 전체와 맞대어 살핀다.
7-퀸 판에는 해가 마흔 개 있다. 그것을 모두 값매기고, |Best|를 다섯으로 두었을 때
|Minimize|가 내주는 것 가운데 가장 싼 다섯의 값이 마흔 개 가운데 가장 싼 다섯의
값과 같아야 한다.
@(ssxcc_test.go@>=
func TestMinimizeBest(t *testing.T) {
	const n, k = 7, 5
	var all []int
	for sol := range NewXCC().Dance(strings.NewReader(nQueensInput(n))).Solutions {
		all = append(all, coverPrice(sol))
	}
	s := NewXCC()
	s.Best = k
	var got []int
	res := s.Minimize(strings.NewReader(nQueensInput(n)),
		func(_ int, opt Option) int { return queenPrice(opt) })
	for sol := range res.Solutions {
		got = append(got, coverPrice(sol))
	}
	@<|got|의 가장 싼 |k|개를 |all|의 가장 싼 |k|개와 견준다@>
}

@ @<|got|의 가장 싼 |k|개를 |all|의 가장 싼 |k|개와 견준다@>=
sort.Ints(all)
sort.Ints(got)
if len(got) < k {
	t.Fatalf("only %d covers arrived, want at least %d", len(got), k)
}
for i := 0; i < k; i++ {
	if got[i] != all[i] {
		t.Fatalf("the %d cheapest: got %v, want %v", k, got[:k], all[:k])
	}
}
t.Logf("%d of the %d covers arrived", len(got), len(all))

@ 세금 덕에 음수 값도 쓸 수 있다. 아이템 |a|와 |b| 위에서 옵션 $\{ab\}$와
$\{a\}$와 $\{b\}$가 저마다 $-1$이므로, $-2$인 $\{a\}+\{b\}$가 $-1$인 $\{ab\}$를
이긴다. 탐색은 마침 $\{ab\}$를 먼저 찾는데, 쌓인 값만으로 가지를 치는 탐색이라면
최선값만큼 이미 비싸진 $\{a\}$를 거기서 돌려보내고 $\{b\}$가 그것을 더 싸게
만들어 준다는 것을 끝내 모른다.
@(ssxcc_test.go@>=
func TestMinimizeNegative(t *testing.T) {
	res := NewXCC().Minimize(strings.NewReader("a b\na b\na\nb\n"),
		func(_ int, _ Option) int { return -1 })
	got := 0
	for sol := range res.Solutions {
		got = -len(sol)
	}
	if got != -2 {
		t.Errorf("cheapest cover costs %d, want -2", got)
	}
}

@ 쓸기는 숨기고 씻어 내는 일이 함께 벌어지는 탐색 한복판에서 옵션을 지우므로,
그런 것을 털어내는 테스트를 받는다. 작은 무작위 문제를 |Dance|로 덮개를 모두
세는 길과 |Minimize|로 푸는 길, 두 길로 풀어 사백 번 맞대어 본다. 문제마다 주
아이템이 셋에서 다섯, 부 아이템이 둘이고, 옵션은 주 아이템의 무작위 부분 집합에
색이 붙은 부 아이템 한둘을 얹은 것이며, 값은 $-10$에서 29까지다. 세금이 빨아들일
음수 값이 있게 하려는 것이다. 메서드 |Minimize|는 가장 싼 덮개를, |Best|가
셋이면 가장 싼 셋을 찾아내야 한다.
@(ssxcc_test.go@>=
func randomXCCProblem(rng *rand.Rand) (input string, price map[string]int) {
	names := []string{"a", "b", "c", "d", "e"}[:3+rng.Intn(3)]
	var b strings.Builder
	b.WriteString(strings.Join(names, " "));b.WriteString(" | x y\n")
	price = map[string]int{}
	for i := 0; i < 4+rng.Intn(10); i++ {
		@<값이 매겨진 무작위 옵션 하나를 쓴다@>
	}
	return b.String(), price
}

@ 옵션은 주 아이템을 저마다 2분의 1의 확률로 집어 들되 적어도 하나는 들고, 부
아이템은 저마다 3분의 1의 확률로 두 색 가운데 하나를 달아 집어 든다.
@<값이 매겨진 무작위 옵션 하나를 쓴다@>=
var opt []string
for _, name := range names {
	if rng.Intn(2) == 0 {
		opt = append(opt, name)
	}
}
if len(opt) == 0 {
	opt = append(opt, names[rng.Intn(len(names))])
}
for _, sec := range []string{"x", "y"} {
	if rng.Intn(3) == 0 {
		opt = append(opt, sec+":"+string(rune('A'+rng.Intn(2))))
	}
}
line := strings.Join(opt, " ")
price[line] = rng.Intn(40) - 10
b.WriteString(line);b.WriteString("\n")

@ @(ssxcc_test.go@>=
func TestMinimizeMatchesSearch(t *testing.T) {
	rng := rand.New(rand.NewSource(11))
	for trial := 0; trial < 400; trial++ {
		input, price := randomXCCProblem(rng)
		cost := func(sol []Option) int {
			c := 0
			for _, opt := range sol {
				c += price[strings.Join(opt, " ")]
			}
			return c
		}
		var all []int
		for sol := range NewXCC().Dance(strings.NewReader(input)).Solutions {
			all = append(all, cost(sol))
		}
		sort.Ints(all)
		@<가장 싼 하나와 가장 싼 셋을 구해 견준다@>
	}
}

@ @<가장 싼 하나와 가장 싼 셋을 구해 견준다@>=
for _, k := range []int{1, 3} {
	s := NewXCC()
	s.Best = k
	var got []int
	r := s.Minimize(strings.NewReader(input),
		func(_ int, opt Option) int { return price[strings.Join(opt, " ")] })
	for sol := range r.Solutions {
		got = append(got, cost(sol))
	}
	sort.Ints(got)
	m := min(k, len(all))
	if len(got) < m || fmt.Sprint(got[:m]) != fmt.Sprint(all[:m]) {
		t.Fatalf("trial %d, Best %d: got %v, want %v\n%s", trial, k, got, all[:m], input)
	}
}

@** 색인.
