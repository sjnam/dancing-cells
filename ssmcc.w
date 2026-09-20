\input kotexgweb

\def\title{SSMCC}

@s Context int
@s Duration int
@s Ticker int
@s Reader int
@s Builder int
@s Time int

@** 들어가며.
이 글은 {\tt SSMCC}다. {\it 다중도\/}가 붙은 정확 덮개를 희소 집합 위에서 추는
춤이고, |dcells| 패키지의 둘째 엔진이며, 형제가 그렇듯 그것만 떼어 읽어도 되도록
썼다. 타입 |Option|과 |Result|, 배열 |nd|, 함수 |ensure|, 그리고 {\tt DLX}
훑개는 짝이 되는 글 \.{dcells.w}의 것이다. 두 엔진이 함께 춤추는 바탕인 희소
집합도 아래에 짧게 되새기되, 느긋한 이야기는 거기에 있다.

여기서 주 아이템은 범위 $[u..v]$를 달고 다닌다. 적어도 $u$번, 많아야 $v$번
덮여야 한다는 뜻이고, 맨 정확 덮개는 $[1..1]$인 경우다. 그 작은 차이가 탐색의
셈법을 꽤 바꾸어 놓아서, {\tt SSXCC}(\.{ssxcc.w})의 $d$갈래 뻗기보다 {\it
이진\/} 분기---이 옵션을 들이거나, 내치거나---가 더 낫게 된다. 두 엔진이 따로
선 프로그램인 까닭이 그것이다. 크누스의 풀이기 계보에 이 확장을 더한 것은 Filip
Stappers로, 2023년의 일이다.
@^Stappers, Filip@>
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
	"strconv"
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
|item[pos(x)]|에 앉아 있음을 적어 둔다. 그러면 아이템에서 옵션 하나를 지운다는
것은 개수를 줄이고 배열 칸 둘을 맞바꾸는 일에 지나지 않는다. 희소 집합의 삭제를
그저 되풀이하는 것이다. 밑자리 바로 아래 칸들이 그 살림살이를 담는데, 여기서는
아이템의 여유와 한도까지 거기에 든다. 아래에 이름 붙인 접근자가 그것을 읽고
쓴다.

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
이 풀이기는 맨 정확 덮개보다 넉넉한 물음에 답한다. 엔진 |MCC|에서 주 아이템은
{\it 다중도\/} $[u..v]$를 달고 다닌다. 적어도 $u$번, 많아야 $v$번 덮여야 한다는
뜻이고, 맨 정확 덮개는 $[1..1]$인 경우다. 그런 아이템마다 두 수가 따라다닌다.
아이템의 {\it 한도\/}는 남은 그릇이다. 앞으로 몇 번 더 덮이기를 바라는가이고,
옵션이 들어올 때마다 하나씩 줄어든다. 아이템의 {\it 여유\/}는 $v-u$, 곧 제약이
가진 헐렁함이며 끝까지 변하지 않는다. 크누스의 풀이기 계보에 이 확장을 더한 것은
Filip Stappers로, 2023년의 일이다.

다중도는 분기의 모양을 바꾼다. 여러 번 덮여도 되는 아이템은 제 옵션을 $d$갈래로
한 번 뻗는다고 해서 치워지지 않으므로, 엔진 |MCC|는 {\it 이진\/}으로 분기한다.
탐색의 마디마다 아이템 하나와 그 옵션 하나를 대고 두 가지를 묻는 것이다. 그
옵션을 {\it 들일까}, 아니면 {\it 내치고\/} 다시 고를까. 분기할 아이템은 {\it
분기 차수\/} $\ell+s-b+1$이 가장 작은 것인데, 여기서 $\ell$은 살아남은 옵션의
수, $b$는 한도, $s=\min(\hbox{여유},b)$이다. 차수가~1이면 그 수는 강제된
것이다. 탐색의 두 좌표를 헷갈려서는 안 된다. {\it 단계\/}는 이제껏 들인 옵션의
수(왼쪽 가지만)를 세는 데 반해, 오른쪽 가지는 옵션 하나가 줄어든 채 같은 단계로
다시 들어간다.

엔진은 형제와 같은 네 악장으로 펼쳐진다. 상태와 짓기, 고르개를 거느린 이진 춤,
분기의 동작---옵션을 들이고 내치는 일과 둘이 함께 쓰는 희소 집합 수술, 그리고
되돌리기 장치---끝으로 알리는 부서들이다.
@<엔진@>=
@<살림살이@>
@<풀이기 상태@>
@<풀이기 짓기@>
@<집합 접근자@>
@<이름 가두기@>
@<춤 띄우기@>
@<탐색@>
@<강제 이동@>
@<아이템 고르기@>
@<옵션 들이기@>
@<옵션 내치기@>
@<아이템 물리기@>
@<되돌리기 장치@>
@<해에 들르기@>
@<맥박@>
@<옵션 알리기@>

@* 상태와 짓기.
엔진 |MCC|의 아이템은 |XCC|의 아이템보다 자리 둘이 더 있어야 한다. 여유와 한도를
둘 자리다.
@<살림살이@>=
const (
	mccExtra = 5 // 아이템 밑자리 아래의 set 칸: size, pos, itemNo, slack, bound
	mccIprop = 5 // 입력 단계의 자리 간격
)

type threeints struct{ l, s, b int32 }

@ 엔진 |MCC|의 상태는 |XCC|의 그것을 거의 필드 하나하나까지 되비춘다---함께 쓰는
덩이는 아예 같은 절이다---다만 |oactive|도 |choice|도 |saved|도 없다. 이진 분기는
제가 걸어온 길을 |included|에 적고(단계마다 옵션 하나씩, 그대로 내놓을 수 있게),
크기와 한도의 세값 쌍을 쌓아 둔 스택으로 되감기 때문이다.
@<풀이기 상태@>=
type MCC struct {
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
baditem  int
osecond  int

@ @<되짚기 배열@>=
included  []int32 // 단계마다 들인 옵션, 해를 내놓을 때 쓴다
savestack []threeints
saveptr   int

@ 짓기와 끊기는 |XCC|의 이야기를 되풀이한다.
@<풀이기 짓기@>=
func NewMCC() *MCC {
	return &MCC{
		second:     secondUnset,
		names:      []string{""},
		nameIndex:  make(map[string]int),
		colorNames: []string{""},
		colorIndex: make(map[string]int),
		ctx:        context.Background(),
	}
}

func (m *MCC) WithContext(ctx context.Context) *MCC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *m
	c.ctx = ctx
	return &c
}

func (m *MCC) Updates() uint64 { return m.updates }
func (m *MCC) Nodes() uint64   { return m.nodes }

@ 접근자 식구는 둘이 늘었다. 자리 |slack|과 |bound|를 맡는 것들이다.
@<집합 접근자@>=
func (m *MCC) size(x int) int   { return int(m.set[x-1]) }
func (m *MCC) pos(x int) int    { return int(m.set[x-2]) }
func (m *MCC) itemNo(x int) int { return int(m.set[x-3]) }
func (m *MCC) slack(x int) int  { return int(m.set[x-4]) }
func (m *MCC) bound(x int) int  { return int(m.set[x-5]) }

func (m *MCC) setSize(x, v int)   { m.set[x-1] = int32(v) }
func (m *MCC) setPos(x, v int)    { m.set[x-2] = int32(v) }
func (m *MCC) setItemNo(x, v int) { m.set[x-3] = int32(v) }
func (m *MCC) setSlack(x, v int)  { m.set[x-4] = int32(v) }
func (m *MCC) setBound(x, v int)  { m.set[x-5] = int32(v) }

@ 이름 가두기는 |XCC|의 코드를 받는 쪽만 바꾸어 그대로 옮긴 것이다. Go에는 메서드
몸통 하나를 두 타입이 곱게 나눠 쓸 방법이 없고, 작은 여섯 줄이 추상 하나보다 싸다.
@<이름 가두기@>=
func (m *MCC) internName(name string) (num int, ok bool) {
	if _, dup := m.nameIndex[name]; dup {
		return 0, false
	}
	num = len(m.names)
	m.names = append(m.names, name)
	m.nameIndex[name] = num
	return num, true
}

func (m *MCC) internColor(name string) int {
	if id, ok := m.colorIndex[name]; ok {
		return id
	}
	id := len(m.colorNames)
	m.colorNames = append(m.colorNames, name)
	m.colorIndex[name] = id
	return id
}

@* 이진 춤.
띄우는 일도 |XCC|의 |Dance|와 쌍둥이다.
@<춤 띄우기@>=
func (m *MCC) Dance(rd io.Reader) *Result {
	m.inputMatrix(rd)
	@<탐색 고루틴을 띄운다@>
}

@ 띄우기를 함수가 아니라 절로 적어 둔 까닭은, 뒷장의 |Minimize|가 제 채비를 마친
뒤에 바로 이 줄들을 원하기 때문이다.
@<탐색 고루틴을 띄운다@>=
m.solStream = make(chan []Option)
m.heartbeat = make(chan string)

go func() {
	defer close(m.solStream)
	defer close(m.heartbeat)

	@<입력 요약을 알린다@>
	if m.PulseInterval > 0 {
		m.pulse = time.NewTicker(m.PulseInterval)
		defer m.pulse.Stop()
	}

	if m.baditem == 0 {
		m.search(0)
	}

	@<총계를 알린다@>
}()

return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}

@ @<입력 요약을 알린다@>=
if m.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
}

@ @<총계를 알린다@>=
if m.Debug {
	plural := "s"
	if m.count == 1 {
		plural = ""
	}
	fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
		m.count, plural, m.updates, m.nodes)
}

@ 이제 이진 춤이다. 여느 때처럼 마디를 세고 끊겼는지 살피고 맥박을 뛴 다음,
더 얕은 마디에서 덮다가 남겨 둔 강제 아이템이 있으면 그것이 무엇보다 먼저다.
그다음---가장 싼 덮개를 찾는 길이라면---이 가지가 이제껏 가장 좋은 것을 이길 수
있기나 한지 묻는다. 그다음 고르개가 말하는데, 고르는 김에 새 강제 아이템을
찾아내기도 한다. 그리고 차수가 |infSize|라는 것은 주 아이템이 하나도 남지
않았다는 뜻이니 해다. 참되게 분기하는 것은 그러고 나서다.

앞의 둘을 어느 쪽에 둘지는 취향의 문제가 아니다. 가지를 버린다는 것은 |search|의
한복판에서 돌아 나온다는 뜻이고, 그것이 안전한 곳은 강제 스택이 비어 있는
자리뿐인데, 위의 처리 반복문이 스택을 비워 두고 나오는 자리가 바로 거기다. 스택에
무언가 남은 채로 가지를 버리면 {\it 다음\/} 마디가 그것을 제 것인 양 주워 갈
터이고, 이진 분기에서 강제 이동은 분기가 아예 아니다. 옵션 하나를 들이고 다른
것은 거들떠보지도 않는다. 그러면 탐색이 소리 없이 해를 잃는다. (형제는 이 일을
겪지 않는다. 거기서 철 지난 강제 아이템은 어느 아이템으로 뻗을지를 고를 뿐이고,
살아 있는 주 아이템이라면 무엇으로 뻗든 언제나 성하기 때문이다.)
@<탐색@>=
func (m *MCC) search(stage int) bool {
	m.nodes++
	select {
	case <-m.ctx.Done():
		return false
	default:
	}
	m.tick()

	@<남아 있던 강제 아이템을 처리한다@>
	@<이 가지가 cutoff를 이길 수 없으면 그만둔다@>
	@<이 마디가 더는 감당할 수 없는 옵션을 쓸어 낸다@>

	best, score := m.chooseBest()
	if m.forced != 0 {
		m.forced--
		return m.forcedMove(stage, int(m.force[m.forced]))
	}
	if score == infSize {
		return m.visit(stage)
	}
	@<아이템 |best|에서 왼쪽과 오른쪽으로 분기한다@>
	return true
}

@ 강제 스택에 쌓인 아이템은 쌓인 뒤에 물러났을 수도 있다. 그런 것은 말없이 버린다.
@<남아 있던 강제 아이템을 처리한다@>=
for m.forced != 0 {
	m.forced--
	if bi := int(m.force[m.forced]); m.pos(bi) < m.active {
		return m.forcedMove(stage, bi)
	}
}

@ 분기 자체다. 상태를 한 번 저장해 두고 아이템 |best|에 살아남은 첫 옵션 |opt|를
떠본다. {\it 왼쪽\/} 자식은 그것을 들이고 |stage+1|로 나아가며, {\it 오른쪽\/}
자식은 상태를 되돌린 뒤 그 옵션을 내치고 {\it 같은\/} 단계로 다시 들어가 새로
고른다. 차수가~1이면 오른쪽 자식은 없다. 그 옵션을 내치면 아이템이 굶어 죽기
때문이다. 그래서 품의 절반이 사라진다. 어느 쪽이든 나올 때 저장 스택은 들어올
때 그대로다.
@<아이템 |best|에서 왼쪽과 오른쪽으로 분기한다@>=
mark, swept := m.saveState(), m.swept
opt := int(m.set[best])
m.included = ensure(m.included, stage+1)
m.included[stage] = int32(opt)

@<이 옵션의 값을 셈한다@>
m.cost += price
m.taxDue -= tax
if m.includeOption(opt) {
	if !m.search(stage + 1) {
		m.saveptr = mark
		return false
	}
}
m.cost -= price
m.taxDue += tax
m.swept = swept
if score != 1 {
	m.restoreState(mark)
	if m.removeOption(opt) {
		if !m.search(stage) {
			m.saveptr = mark
			return false
		}
	}
}
m.saveptr = mark

@ 강제된 아이템에는 둘 수 있는 수가 딱 하나뿐이고 달리 갈 길이 없으니, 그것을
두고 {\it 아무것도 저장하지 않은 채\/} 앞으로 나아간다. Solnon이 2023년에 일러
준 대로, 강제 이동을 알아보는 뜻이 온통 거기에 있다. 그것이 남긴 자취는 때가
되면 어느 조상의 |restoreState|가 지운다. 들이기가 실패했을 때 조용히 |true|를
돌려주는 것을 눈여겨보라. 그 가지는 죽었어도 탐색 전체는 계속된다.
@^Solnon, Christine@>
@<강제 이동@>=
func (m *MCC) forcedMove(stage, bi int) bool {
	opt := int(m.set[bi])
	m.included = ensure(m.included, stage+1)
	m.included[stage] = int32(opt)
	@<이 옵션의 값을 셈한다@>
	m.cost += price
	m.taxDue -= tax
	ok := true
	if m.includeOption(opt) {
		ok = m.search(stage + 1)
	}
	m.cost -= price
	m.taxDue += tax
	return ok
}

@ 고르개는 살아 있는 주 아이템마다 분기 차수 $\ell+s-b+1$을 달아 보고 가장 작은
것을 쥔다. 비기면 여유가 작은 쪽, 그다음 크기가 큰 쪽, 그다음 왼쪽에 있는
쪽인데, 크누스가 실험으로 다듬은 차례다. 차수가~1로 떨어진 아이템은 강제된
것이고, 그것이 아직 한 번보다 많이 덮이기를 바랄 수 있으므로 |bound-slack|번
쌓는다. 그래야 꼭 덮여야 하는 횟수마다 차례가 돌아온다.
@^Knuth, Donald Ervin@>
@<아이템 고르기@>=
func (m *MCC) chooseBest() (best, score int) {
	score = infSize
	bestS, bestL := 0, 0
	for k := 0; k < m.active; k++ {
		x := int(m.item[k])
		if x >= m.second {
			continue
		}
		s := m.slack(x)
		if b := m.bound(x); s > b {
			s = b
		}
		t := m.size(x) + s - m.bound(x) + 1
		switch {
		case t == 1:
			for i := m.bound(x) - m.slack(x); i > 0; i-- {
				m.force = ensure(m.force, m.forced+1)
				m.force[m.forced] = int32(x)
				m.forced++
			}
		case t <= score && (t < score || (s <= bestS && (s < bestS ||
			(m.size(x) >= bestL && (m.size(x) > bestL || x < best))))):
			score, best, bestS, bestL = t, x, s, m.size(x)
		}
	}
	return best, score
}

@* 분기의 동작.
옵션을 들인다는 것은---먼저 그 옵션의 첫머리로 되감은 다음---그 노드를 걸으며
아이템마다 |coverOrCommit|으로 셈을 치르는 일이다. 이미 살아 있지 않은 아이템을
만났을 때, 부 아이템이면 괜찮고(앞서 씻긴 것이다) 주 아이템이면 있을 수 없는
일이다. 어디서든 |false|가 나오면 어떤 아이템이 덮일 수 없게 되었다는 뜻이고,
부르는 쪽의 가지는 죽는다.
@<옵션 들이기@>=
func (m *MCC) includeOption(opt int) bool {
	for m.nd[opt-1].itm > 0 {
		opt--
	}
	for ; ; opt++ {
		ii := int(m.nd[opt].itm)
		if ii <= 0 {
			break
		}
		pp := int(m.nd[opt].loc)
		if m.pos(ii) >= m.active {
			if ii >= m.second {
				continue // 이미 씻긴 부 아이템
			}
			return false // 성한 살아 있는 옵션이라면 일어날 수 없다
		}
		if !m.coverOrCommit(ii, opt, pp) {
			return false
		}
	}
	return true
}

@ 들인 옵션의 아이템 |ii| 하나에게는(그 노드는 |cur|이고 아이템 |ii|의 집합
|p|번 자리에 앉아 있다) 두 갈래 앞날이 있다. 주 아이템이라면 먼저 한도 한 칸을
치르고, 그것으로 한도가 바닥나면---또는 아이템 |ii|가 부 아이템이면---그
아이템은 할 일을 다 했으니 판을 떠난다. 그렇지 않으면 아이템 |ii|는 아직 더
덮이기를 바라므로 제 집합에서 이 옵션만 떨군다.
@<옵션 들이기@>=
func (m *MCC) coverOrCommit(ii, cur, p int) bool {
	if ii < m.second {
		m.setBound(ii, m.bound(ii)-1)
	}
	if ii >= m.second || m.bound(ii) == 0 {
		@<아이템 |ii|를 아주 덮거나 씻어 낸다@>
	} else {
		@<더 덮이길 바라는 아이템 |ii|에서 옵션 |cur|를 떨군다@>
	}
	return true
}

@ 아이템을 마치게 한다는 것은 {\it 부딪히는\/} 옵션을 모두 나머지 행렬에서
치운다는 뜻이다. 다만 아이템 |ii|가 부 아이템이고 맡긴 노드가 색을 달고 있으면,
그 색에 뜻을 모으는 옵션은 치우지 않고 씻어 낸다. 그러고 나서 아이템 자신이
물러난다. (반복문이 거꾸로 도는 것은 |removeFromOtherSets|가 일하면서 집합을
뒤섞기 때문이다.)
@<아이템 |ii|를 아주 덮거나 씻어 낸다@>=
ss := m.size(ii)
c := 0
if ii >= m.second {
	c = int(m.nd[cur].clr)
}
for s := ii + ss - 1; s >= ii; s-- {
	if s == p {
		continue
	}
	optp := int(m.set[s])
	if c == 0 || int(m.nd[optp].clr) != c {
		if !m.removeFromOtherSets(optp) {
			return false
		}
	}
}
m.deactivate(ii)

@ 아직 더 덮이기를 바라는 아이템은 이 옵션 하나만 잃는다. 다만 그러다 제 집합이
|bound-slack|보다 작아진다면, 곧 앞으로 모을 수 있으리라 바라는 최소치 아래로
밀린다면 그 가지는 죽는다. 바라는 바가 이미 0인 아이템의 마지막 옵션을 떨구는
것은 그저 그 아이템을 물러나게 하는 일이다.
@<더 덮이길 바라는 아이템 |ii|에서 옵션 |cur|를 떨군다@>=
ss := m.size(ii) - 1
if ss < m.bound(ii)-m.slack(ii) {
	m.forced = 0
	return false // 아이템 ii가 지워질 참이다
}
if ss == 0 {
	m.deactivate(ii)
} else {
	@<아이템 |ii|의 집합 |p|번 자리에서 옵션 |cur|를 맞바꿔 뺀다@>
}

@ 서로 다른 세 대목이 똑같은 다섯 줄의 희소 집합 수술을 바라므로, 한 번만
이름 붙여 둔다. 떠나는 옵션이 아이템 |ii|의 집합에서 마지막으로 살아 있는 칸과
자리를 바꾸고, 양쪽의 |loc| 필드를 고쳐 준다.
@<아이템 |ii|의 집합 |p|번 자리에서 옵션 |cur|를 맞바꿔 뺀다@>=
nnp := int(m.set[ii+ss])
m.setSize(ii, ss)
m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
m.updates++

@ 부딪히는 옵션을 치운다는 것은 그것이 든 살아 있는 집합에서 모두 지우는
일이다. 씻긴 부 아이템은 건너뛰고, 늘 그렇듯 덮일 수 있는 최소치 아래로 밀리는
주 아이템이 없는지 살핀다.
@<옵션 내치기@>=
func (m *MCC) removeFromOtherSets(optp int) bool {
	cur := optp
	for m.nd[cur-1].itm > 0 {
		cur--
	}
	for ; ; cur++ {
		ii := int(m.nd[cur].itm)
		if ii <= 0 {
			break
		}
		p := int(m.nd[cur].loc)
		if p >= m.second && m.pos(ii) >= m.active {
			continue
		}
		ss := m.size(ii) - 1
		if p < m.second {
			if ss < m.bound(ii)-m.slack(ii) {
				m.forced = 0
				return false
			}
			if ss == 0 {
				m.deactivate(ii)
			}
		}
		if ss > 0 {
			@<아이템 |ii|의 집합 |p|번 자리에서 옵션 |cur|를 맞바꿔 뺀다@>
		}
	}
	return true
}

@ 탐색의 오른쪽 가지도 똑같은 지우기를 바란다. 옵션 |cur|를 맡기지 않은 채
치우는 일인데, |removeFromOtherSets|와 딱 한 군데가 다르다. 여기서 |false|는
여느 ``덮을 수 없다''일 뿐이고, 그것을 듣는 쪽은 어차피 되짚으려던 참이므로 강제
스택을 건드리지 않고 둔다.
@<옵션 내치기@>=
func (m *MCC) removeOption(cur int) bool {
	for m.nd[cur-1].itm > 0 {
		cur--
	}
	for ; ; cur++ {
		ii := int(m.nd[cur].itm)
		if ii <= 0 {
			break
		}
		p := int(m.nd[cur].loc)
		if p >= m.second && m.pos(ii) >= m.active {
			continue
		}
		ss := m.size(ii) - 1
		if p < m.second {
			if ss < m.bound(ii)-m.slack(ii) {
				return false
			}
			if ss == 0 {
				m.deactivate(ii)
			}
		}
		if ss > 0 {
			@<아이템 |ii|의 집합 |p|번 자리에서 옵션 |cur|를 맞바꿔 뺀다@>
		}
	}
	return true
}

@ 아이템을 물러나게 하는 것은 배열 |item| 위에서 하는 희소 집합 삭제, 그것을 또
한 번 하는 일이다.
@<아이템 물리기@>=
func (m *MCC) deactivate(ii int) {
	m.active--
	p := m.pos(ii)
	iii := int(m.item[m.active])
	m.item[m.active], m.item[p] = int32(ii), int32(iii)
	m.setPos(ii, m.active)
	m.setPos(iii, p)
}

@ 이진 분기는 크기만 저장하고 넘어갈 수 없다. 한도도 바뀌기 때문이다. 그래서
메서드 |saveState|는 살아 있는 아이템마다 크기를, 주 아이템이면 한도까지 함께
찍어 두고, |restoreState|가 되감을 표를 돌려준다. 엔진 |XCC|의 되돌리기 장치를
다중도에 맞게 옮긴 것이다.
@<되돌리기 장치@>=
func (m *MCC) saveState() int {
	mark := m.saveptr
	m.savestack = ensure(m.savestack, m.saveptr+m.active)
	for p := 0; p < m.active; p++ {
		x := int(m.item[p])
		e := threeints{l: int32(x), s: int32(m.size(x))}
		if x < m.second {
			e.b = int32(m.bound(x))
		}
		m.savestack[m.saveptr] = e
		m.saveptr++
	}
	return mark
}

func (m *MCC) restoreState(mark int) {
	m.active = m.saveptr - mark
	for p := 0; p < m.active; p++ {
		e := m.savestack[mark+p]
		m.setSize(int(e.l), int(e.s))
		if int(e.l) < m.second {
			m.setBound(int(e.l), int(e.b))
		}
	}
	m.saveptr = mark
}

@* 알리기.
해를 내놓는 일은 스택 |included|를 읽는 일이다. 발을 맞추는 select도, 값을
따지는 탐색이 지키는 연단도 |XCC|의 그것과 같다.
@<해에 들르기@>=
func (m *MCC) visit(stage int) bool {
	m.count++
	if m.minimizing {
		@<새 덮개를 연단에 올린다@>
	}
	sol := make([]Option, stage)
	for k := 0; k < stage; k++ {
		sol[k] = m.option(int(m.included[k]))
	}
	select {
	case <-m.ctx.Done():
		return false
	case m.solStream <- sol:
		return true
	}
}

@ @<맥박@>=
func (m *MCC) tick() {
	if m.pulse == nil {
		return
	}
	select {
	case <-m.pulse.C:
		select {
		case m.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", m.nodes, m.count):
		default:
		}
	default:
	}
}

@ @<옵션 알리기@>=
func (m *MCC) option(p int) Option {
	for m.nd[p-1].itm > 0 {
		p--
	}
	var opt Option
	for q := p; m.nd[q].itm > 0; q++ {
		name := m.names[m.itemNo(int(m.nd[q].itm))]
		if c := m.nd[q].clr; c != 0 {
			name += ":" + m.colorNames[c]
		}
		opt = append(opt, name)
	}
	return opt
}

@** 가장 싼 덮개.
다중도가 문제에게 {\it 몇 번\/}이냐를 말하게 해 주었다면, 값은 {\it 얼마나
비싸냐\/}를 말하게 해 준다. 옵션마다 값을 매기고 나면 물음은 ``덮개가 있는가''가
아니라 ``가장 싼 덮개는 무엇인가''가 되고, 형제가 그러듯 같은 탐색이 분기한정으로
거기에 답한다. 이제껏 찾은 가장 좋은 덮개의 값인 {\it 최선값\/}을 쥐고 있되 첫
덮개가 나오기 전에는 무한대이고, 마디마다 이 가지가 그것을 이길 수 있기나 한지
묻고, 아니면 돌아선다. 그 이야기는 \.{ssxcc.w}가 느긋하게 한다. 여기서는 이진
춤이 어디서 다른지만 말하면 된다.

다른 데가 하나 있는데 반가운 쪽이다. 쌓이는 값은 옵션을 들이는 {\it 왼쪽\/}
가지에서만 오르고, 고르는 일을 뺀 들이기인 강제 이동도 같은 식으로 문다.
{\it 오른쪽\/} 가지는 옵션 하나를 내치고 같은 단계로 다시 들어갈 뿐이니, 사는
것도 무는 것도 없다. 그래서 옵션의 값을 더했다가 도로 빼는 자리가 딱 한 군데,
그리고 강제 이동에 그 쌍둥이가 하나 있을 뿐이다.

크누스의 {\tt DLX5}에서 \.{ssxcc.w}가 빌려 온 다듬기 셋도 함께 따라온다. 주
아이템에 매겨 하한을 공짜로 내주는 {\it 세금}, 마디마다 그 마디가 더는 감당할 수
없는 옵션을 지우는 {\it 쓸기}, 그리고 이제껏 찾은 가장 싼 덮개 $k$개를 올려 두고
그 가운데 가장 비싼 것을 가지가 이겨야 할 {\it cutoff\/}로 삼는 {\it 연단\/}이다.
세금과 쓸기는 여기서 둘 다 다시 생각해야 하고, 그 생각은 저마다 그 일이 일어나는
자리에 적는다.
@^Knuth, Donald Ervin@>

@ 이 장의 어느 것도 |Dance|를 건드리지 않는다. 값을 따지는 출발점은 |Minimize|라는
둘째 출발점이고, 그것을 쓰지 않을 때 탐색은 예전에 돌던 코드를 그대로 돌되 불리언
검사 하나만큼 가난해진다. 하한 함수가 들여다보는 |Frame|은 두 엔진이 같은 것을
내주므로 \.{dcells.w}에 있고, 여기 남는 것은 이 엔진이 그 창에 내놓는 답 넷이다.
@<값 따지기@>=
@<값 따지는 출발점@>
@<창에 답하기@>

@ 하한 신탁도 다른 것과 같은 손잡이이고, 다른 것처럼 그냥 두어도 된다. 필드
|Bound|는 값을 따지는 탐색의 마디마다 불리며, 제 앞의 부분 덮개를 {\it 마저
짓는\/} 데 드는 값의 하한을 돌려주어야 한다. 넘겨짚어 크게 말하면 안 된다.
그러면 탐색이 답을 가지치기로 날려 버린다. 0을 돌려주는 것은 언제나 안전하고
언제나 쓸모없다.
@<풀이기 손잡이@>=
Bound func(Frame) int // 앞으로 치를 값의 하한, nil이어도 된다

@ 필드 |Best|는 가장 싼 덮개 |Best|개를 찾아 달라는 뜻이고, 0으로 두면 하나를
뜻한다.
@<풀이기 손잡이@>=
Best int // Minimize에서 가장 싼 덮개를 몇 개나 찾을 것인가

@ 살림살이의 감춰진 절반인데, 필드 하나하나가 |XCC|의 그것과 같다. 옵션은 읽힌
차례로 $1,2,\ldots$의 번호를 받고, 배열 |optNo|는 노드마다 그것이 속한 옵션의
번호를 알려 주며, |optCost|는 부르는 쪽이 매긴 값을, |optTax|는 그 값 가운데
세금인 몫을 담고, |itemBase|는 창이 쓰는 번호와 춤이 쓰는 밑자리를 이어 준다.
모두 |Minimize|가 지어 주기 전까지는 nil인 채인데, 필드 |minimizing|이 뜻하는
바가 바로 그것이다.
@<값 살림살이@>=
minimizing bool
optNo      []int32 // 노드 -> 그 노드가 속한 옵션
optCost    []int32 // 옵션 번호 -> 부르는 쪽이 매긴 값
optTax     []int64 // 옵션 번호 -> 그 값에 든 세금
itemBase   []int32 // 아이템 번호 -> set 안의 밑자리
cost       int64   // 이제껏 들인 옵션들의 값
taxDue     int64   // 앞으로 올 덮기가 아직 물어야 할 세금
podium     []int64 // 이제껏 가장 싼 덮개 Best개의 값, 최대 힙
byNet      []pricedOpt // 모든 옵션, 순값이 비싼 것부터
swept      int         // 지금 마디가 byNet의 어디까지 쓸었는가

@ 메서드 |Minimize|는 |Dance|와 같은 입력을 읽고, 값을 매기고, 같은 탐색을
띄운다. 채널 |Solutions|로 닿는 것은 앞의 것보다 반드시 싼 덮개의 사슬이니, 가장
새것만 쥐고 있던 쪽은 끝에 최적인 것을 쥐게 된다. 값표를 조각이 아니라 함수로
받는 까닭은, 옵션의 번호가 부르는 쪽이 세고 있기에는 성가신 것이기 때문이다. 빈
줄과 주석과 주 아이템을 하나도 대지 않은 옵션은 번호를 쓰지 않고 지나간다. 그래서
번호와 옵션 자신을, 그것도 해가 닿을 때와 똑같은 모양으로 건네고 답을 받는다.
필드 |Best|를 $k>1$로 두면 이제껏 본 $k$번째로 싼 것보다 싸면 그때마다 덮개가
닿고, 끝에 닿은 것 가운데 가장 싼 $k$개가 이 문제의 가장 싼 덮개 $k$개다. 까닭은
\.{ssxcc.w}에 적혀 있다.
@<값 따지는 출발점@>=
func (m *MCC) Minimize(rd io.Reader, cost func(o int, opt Option) int) *Result {
	m.inputMatrix(rd)
	@<옵션에 값을 매긴다@>
	@<다중도가 정해진 아이템마다 세금을 걷는다@>
	@<순값이 음수이면 물리친다@>
	@<옵션을 순값 순서로 줄 세운다@>
	@<연단을 차린다@>
	m.minimizing = true
	@<탐색 고루틴을 띄운다@>
}

@ 값매기기는 노드를 한 번 훑는 일이다. 참된 노드는 |itm|이 양수이고 사이막은
그렇지 않으므로, 앞의 것이 사이막인 노드가 새 옵션을 여는 노드다. 거기서 옵션
번호를 하나 올리고, 그 옵션이 얼마인지 부르는 쪽에 묻고, 뒤따르는 노드의 토막에
그 번호를 칠한다.
@<옵션에 값을 매긴다@>=
m.optNo = make([]int32, m.lastNode+1)
m.optCost = make([]int32, int(m.options)+1)
o := int32(0)
for k := 1; k < m.lastNode; k++ {
	if m.nd[k].itm <= 0 {
		continue // 옵션과 옵션 사이의 사이막
	}
	if m.nd[k-1].itm <= 0 {
		o++
		m.optCost[o] = int32(cost(int(o), m.option(k)))
	}
	m.optNo[k] = o
}
@<아이템을 번호로 찾을 표를 짓는다@>

@ 창은 아이템을 그 {\it 번호\/}로 묻는데 춤은 아이템을 배열 |set| 안의 {\it
밑자리\/}로 알고 있으니, 그 둘을 이어 줄 표가 하나 있어야 한다. 마무리가 아이템
하나둘을 이미 물러나게 했을 수 있고 그러면 배열 |item|이 흐트러지지만, 밑자리는
저마다 그 안 어딘가에 제 번호를 달고 있다.
@<아이템을 번호로 찾을 표를 짓는다@>=
m.itemBase = make([]int32, m.itemlen+1)
for k := 0; k < m.itemlen; k++ {
	base := int(m.item[k])
	m.itemBase[m.itemNo(base)] = int32(base)
}

@ 글 \.{ssxcc.w}의 세금은 사실 하나에 기대고 있었다. 어느 덮개든 주 아이템마다
그 집합에서 옵션을 꼭 하나 가져간다는 것이다. 엔진 |MCC|에서 다중도 $[u..v]$인
아이템은 제 옵션 가운데 $u$개에서 $v$개 사이로 덮이므로, 거기에 세금~$t$를 매기면
어떤 덮개는 $t$만큼, 어떤 덮개는 $2t$만큼 싸지고, 가장 싼 덮개가 더는 가장 싸지
않을 수 있다. 그렇지만 $u=v$일 때는, 곧 여유가 0일 때는 어느 덮개든 그 아이템의
옵션을 꼭 $v$개 가져가므로 모든 덮개가 똑같이 $vt$만큼 싸지고, 논증이 예전처럼
지나간다. 그래서 그런 아이템에만 세금을 걷고 나머지는 그냥 둔다. 뿌리에서
아이템의 |bound|가 곧 그 $v$다.

하한도 그대로 지나간다. 앞으로 올 옵션들은 세금을 문 아이템마다 그 |bound|가
지금 말하는 횟수만큼 더 덮으므로, 그들이 지고 있는 세금의 합은 살아서 세금을 문
아이템들에 대한 $\sum t\cdot|bound|$다. 그리고 옵션 하나를 들이면 그 안의 세금
낸 아이템마다 한도가 하나씩 줄어드니 그 합은 정확히 그 옵션 제 세금만큼 줄어든다.
그러니 필드 |taxDue|는 예전과 똑같은 뺄셈으로 지킬 수 있다.
@<다중도가 정해진 아이템마다 세금을 걷는다@>=
m.optTax = make([]int64, len(m.optCost))
m.taxDue = 0
for k := 0; k < m.active; k++ {
	x := int(m.item[k])
	if x >= m.second || m.slack(x) != 0 || m.size(x) == 0 {
		continue
	}
	@<아이템 |x|의 옵션 가운데 가장 작은 순값 |t|를 찾는다@>
	for c := x; c < x+m.size(x); c++ {
		m.optTax[m.optNo[int(m.set[c])]] += t
	}
	m.taxDue += t * int64(m.bound(x))
}

@ @<아이템 |x|의 옵션 가운데 가장 작은 순값 |t|를 찾는다@>=
t := infCost
for c := x; c < x+m.size(x); c++ {
	o := m.optNo[int(m.set[c])]
	t = min(t, int64(m.optCost[o])-m.optTax[o])
}

@ 세금을 문 아이템을 담은 옵션은 \.{ssxcc.w}에서처럼 순값이 음수가 아니다. 그런
아이템을 하나도 담지 않은 옵션은 부르는 쪽이 매긴 값을 그대로 지니는데, 그 값이
음수이면 세금 하한도 맨 cutoff 검사도 성하지 않다. 이미 cutoff만큼 비싸진 부분
덮개가 앞으로 더 싸질 수 있기 때문이다. 그런 것은 제대로 뒤질 수 없으니, 틀린
입력을 알리듯 그렇다고 말한다.
@<순값이 음수이면 물리친다@>=
for o := 1; o < len(m.optCost); o++ {
	if net := int64(m.optCost[o]) - m.optTax[o]; net < 0 {
		panic(fmt.Sprintf("dcells: option %d has negative net cost %d; "+
			"no item of fixed multiplicity absorbs it", o, net))
	}
}

@ @<연단을 차린다@>=
m.podium = make([]int64, max(m.Best, 1))
for i := range m.podium {
	m.podium[i] = infCost
}
m.swept = 0

@ 옵션의 줄은 \.{ssxcc.w}에서처럼 순값이 비싼 것부터 늘어놓는다.
@<옵션을 순값 순서로 줄 세운다@>=
m.byNet = m.byNet[:0]
for k := 1; k < m.lastNode; k++ {
	if m.nd[k].itm > 0 && m.nd[k-1].itm <= 0 {
		o := m.optNo[k]
		m.byNet = append(m.byNet,
			pricedOpt{int32(k), int64(m.optCost[o]) - m.optTax[o]})
	}
}
slices.SortStableFunc(m.byNet, func(a, b pricedOpt) int {
	return cmp.Compare(b.net, a.net)
})

@ 글 \.{ssxcc.w}의 쓸기는 그대로 옮겨 온다. 순값이 그 마디의 예산
$|cutoff|-|cost|-|taxDue|$ 아래가 아닌 옵션은 그 마디 아래에서 아무 구실도 할 수
없고, 예산을 넘는 옵션은 |byNet|의 앞토막을 이루며 내려갈수록 늘기만 한다. 여기서
다른 것이 둘이다.

첫째는 마디가 제 부모가 어디서 멈췄는지를 어떻게 아는가다. 이진 분기에서는
오른쪽 자식이 부모와 같은 단계로 다시 들어가므로, 단계는 \.{ssxcc.w}에서 층이
하던 것처럼 멈춘 자리를 가리키는 색인 노릇을 하지 못한다. 그래서 필드 |m.swept|가
지금 돌고 있는 마디의 멈춘 자리를 쥐고 있고, 분기하는 마디가 왼쪽 자식이
돌아온 뒤 오른쪽 자식이 나서기 전에 제 값을 도로 써 넣는다. 강제 이동은 그런
시중이 필요 없다. 자식이 하나뿐이고 그 답을 그대로 위로 올릴 뿐이며, 분기한 조상이
모든 것을 도로 놓기 때문이다.

둘째는 지우기 자체인데, |removeOption|의 그것과 딱 한 군데가 다르다. 앞으로 더
덮여야 하는 횟수 아래로 밀리는 주 아이템이 가지를 죽이는 것은 거기서와 같다.
그렇지만 |removeOption|이 집합의 마지막 칸을 그 자리에 두고 크기를 1로 남겨 두는
데 반해, 쓸기는 언제나 그 칸을 치우고 집합이 마른 아이템은 주든 부든 물러나게
한다. 물러난 아이템은 이 마디 아래에서 다시 덮이거나 씻길 일이 없으니, 뒤따르는
어느 걸음도 죽은 옵션을 산 것으로 잘못 볼 수 없다. 그리고 조상의 |restoreState|가
그 아이템을 도로 데려온다. 건드려도 되는 것은 살아 있는 아이템의 집합이고, 그
안에서도 아직 살아 있는 칸뿐이다. 왼쪽 가지에 앞서 건너뛰는 검사는 \.{ssxcc.w}에
있던 것과 달리 여기에는 필요 없다. 왼쪽 자식은 이 마디가 쓸고 난 바로 다음에
방금 고른 옵션을 들이므로, 그 옵션은 예산 안에 있다.
@<이 마디가 더는 감당할 수 없는 옵션을 쓸어 낸다@>=
if m.minimizing {
	budget := m.podium[0] - m.cost - m.taxDue
	for ; m.swept < len(m.byNet) && m.byNet[m.swept].net >= budget; m.swept++ {
		@<옵션 |m.byNet[m.swept]|를 살아 있는 집합에서 지우거나 그만둔다@>
	}
}

@ @<옵션 |m.byNet[m.swept]|를 살아 있는 집합에서 지우거나 그만둔다@>=
for cur := int(m.byNet[m.swept].node); m.nd[cur].itm > 0; cur++ {
	ii, p := int(m.nd[cur].itm), int(m.nd[cur].loc)
	if m.pos(ii) >= m.active || p >= ii+m.size(ii) {
		continue // 살아 있지 않은 아이템이거나, 이 옵션이 이미 떠난 집합이다
	}
	ss := m.size(ii) - 1
	if ii < m.second && ss < m.bound(ii)-m.slack(ii) {
		return true // 이 아이템은 더는 넉넉히 덮일 수 없다
	}
	@<아이템 |ii|의 집합 |p|번 자리에서 옵션 |cur|를 맞바꿔 뺀다@>
	if ss == 0 {
		m.deactivate(ii) // 집합에 남은 것이 없다
	}
}

@ 여기가 |search|의 머리에 끼워 넣은 가지치기 검사다. 값 |true|를 돌려주면 이
가지를 버리고 탐색은 다른 데서 이어 간다. 값 |false|를 돌려주는 것은 문맥이
끊겼을 때뿐이다. 덮개의 나머지가 치를 값은 적어도 아직 물어야 할 세금만큼이고,
적어도 부르는 쪽의 |Bound|가 말하는 만큼이다. cutoff는 연단의 꼭대기다. 견줌이
|>|가 아니라 |>=|이므로 cutoff와 비기기만 한 덮개도 잘린다. 손잡이 |Best|가
하나일 때 닿는 덮개가 반드시 싸지는 까닭이 그것이고, |visit|이 아무것도 견주지
않고 제 덮개를 연단에 올려도 되는 까닭도 그것이다.
@<이 가지가 cutoff를 이길 수 없으면 그만둔다@>=
if m.minimizing {
	rest := m.taxDue
	if m.Bound != nil {
		rest = max(rest, int64(m.Bound(Frame{m})))
	}
	if m.cost+rest >= m.podium[0] {
		return true
	}
}

@ 그리고 여기가 옵션 하나의 값과 거기 든 세금을 그 안의 노드로 찾아 오는
자리다. 맨 |Dance|는 표를 지은 적이 없으니 검사 말고는 무는 것이 없다.
@<이 옵션의 값을 셈한다@>=
price, tax := int64(0), int64(0)
if m.minimizing {
	o := m.optNo[opt]
	price, tax = int64(m.optCost[o]), m.optTax[o]
}

@ 연단은 \.{ssxcc.w}의 그 힙이다. 새로 온 것이 뿌리에 있던 가장 비싼 덮개를
밀어내고, 저보다 비싼 자식이 있는 동안 가라앉는다.
@<새 덮개를 연단에 올린다@>=
h, i := m.podium, 0
for j := 1; j < len(h); j = 2*i + 1 {
	if j+1 < len(h) && h[j+1] > h[j] {
		j++ // 더 비싼 자식
	}
	if h[j] <= m.cost {
		break
	}
	h[i] = h[j]
	i = j
}
h[i] = m.cost

@ 이제 이 엔진이 창에 내놓는 답 넷이다. 행렬의 살아 있는 몫을 걷는다는 것은
살아 있는 아이템을 걷되 부 아이템은 건너뛰고---그들은 제 몫으로 요구하는 것이
없다---살아남은 아이템마다 그 집합을 훑는다는 뜻이다.
@<창에 답하기@>=
func (m *MCC) eachLive(yield func(item, opt int) bool) {
	for k := 0; k < m.active; k++ {
		x := int(m.item[k])
		if x >= m.second {
			continue
		}
		i := m.itemNo(x)
		for c := x; c < x+m.size(x); c++ {
			if !yield(i, int(m.optNo[int(m.set[c])])) {
				return
			}
		}
	}
}

@ 남은 셋 가운데 둘은 그냥 찾아보기다. 나머지 하나는 여기서 |XCC|와 다른 것을
뜻하는 유일한 답이고, 다중도가 있는 문제에 하한 함수를 쓸 수 있게 하는 것이 바로
그것이다. 아이템의 {\it 한도\/}는 앞으로 몇 번 더 덮여도 받아 주겠는가이고 그
{\it 여유\/}는 그 가운데 몇 번은 없어도 되는가이니, 참으로 아직 요구하는 수는 그
차이이고, 0보다 작아지는 일은 없다.
@<창에 답하기@>=
func (m *MCC) optionCost(opt int) int  { return int(m.optCost[opt]) }
func (m *MCC) itemName(item int) string { return m.names[item] }

func (m *MCC) itemNeed(item int) int {
	x := int(m.itemBase[item])
	if x >= m.second {
		return 0
	}
	return max(m.bound(x)-m.slack(x), 0)
}

@** DLX 입력 읽기.
형식 {\tt DLX}와 그것을 낱말로 씹어 주는 훑개는 \.{dcells.w}에 있고, 여기 남는
것은 {\it 이\/} 엔진의 배열을 아는 몫이다. 글 \.{ssxcc.w}의 XCC 입력 단계와
꽤나 나란하므로, 아래 이야기는 다중도가 바꾸어 놓는 것만 짚는다. 그것은 주로
아이템 줄인데, 주 아이템을 \.{high\|name}이나 \.{low:high\|name}으로 적을 수
있고 이름만 적으면 $[1..1]$을 뜻한다.
@<입력 단계@>=
func (m *MCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	m.readItemNames(br)
	m.readOptions(br)
}

@<다중도 읽기@>
@<아이템 이름 읽기@>
@<옵션 읽기@>
@<입력 마무리@>

@ 아이템 낱말은 \.{name}이거나($[1..1]$이 된다) \.{high\|name}이거나
\.{low:high\|name}이다. 주 아이템과 부 아이템을 가르는 외따로 선 \.{\|}는 여기가
아니라 부르는 쪽이 맡는다. 부 아이템은 다중도를 달 수 없고, 위끝이 0인 것은 말이
되지 않으며, 아래끝이 위끝보다 클 수도 없다.
@<다중도 읽기@>=
func mustAtoi(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		failf("illegal number in bound spec: %q", s)
	}
	return n
}

func parseItemSpec(tok string, inSecondary bool) (name string, lower, upper int) {
	if i := strings.IndexByte(tok, '|'); i >= 0 {
		@<이름 앞에 붙은 다중도를 떼어 낸다@>
	} else {
		name, lower, upper = tok, 1, 1
	}
	if name == "" {
		failf("item name empty: %q", tok)
	}
	if strings.ContainsAny(name, ":|") {
		failf("illegal character in item name: %q", name)
	}
	return
}

@ @<이름 앞에 붙은 다중도를 떼어 낸다@>=
if inSecondary {
	failf("secondary item cannot have a multiplicity: %q", tok)
}
spec, nm := tok[:i], tok[i+1:]
if j := strings.IndexByte(spec, ':'); j >= 0 {
	lower, upper = mustAtoi(spec[:j]), mustAtoi(spec[j+1:])
} else {
	upper = mustAtoi(spec)
	lower = upper
}
if upper == 0 {
	failf("upper bound is zero: %q", tok)
}
if lower > upper {
	failf("lower bound exceeds upper bound: %q", tok)
}
name = nm

@ 아이템 줄을 읽는 일이 XCC 판과 다른 데는 한 마디뿐이다. 이름은 저마다
|parseItemSpec|을 거쳐 오고, 그 여유($upper-lower$)와 한도($upper$)는 마무리가
주워 가도록 아이템의 성긴 입력 자리에 놓인다.
@<아이템 이름 읽기@>=
func (m *MCC) readItemNames(br *bufio.Reader) {
	@<아이템 줄을 찾는다@>
	for buf[p] != 0 {
		tok, next := token(buf, p, false)
		if tok == "|" {
			if m.second != secondUnset {
				failf("item name line contains | twice")
			}
			m.second = len(m.names) // 다음 아이템의 번호
		} else {
			name, lower, upper := parseItemSpec(tok, m.second != secondUnset)
			num, ok := m.internName(name)
			if !ok {
				failf("duplicate item name: %s", name)
			}
			slot := num * mccIprop
			m.set = ensure(m.set, slot)
			m.setSlack(slot, upper-lower)
			m.setBound(slot, upper)
		}
		p = skipSpace(buf, next)
	}
	m.lastItm = len(m.names)
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

@ 옵션은 XCC 파서와 똑같이 읽되 자리 간격만 |mccIprop|이다.
@<옵션 읽기@>=
func (m *MCC) readOptions(br *bufio.Reader) {
	for {
		buf, ok := nextLine(br)
		if !ok {
			break
		}
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
			continue
		}
		m.readOption(buf)
	}
	m.finalize()
}

@ @<옵션 읽기@>=
func (m *MCC) readOption(buf []byte) {
	spacer := m.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {
		@<아이템 이름 하나와 그 색을 훑는다@>
	}

	if !hasPrimary {
		@<옵션을 되감는다@>
		return
	}
	m.nd[spacer].loc = int32(m.lastNode - spacer)
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	m.options++
	m.nd[m.lastNode].itm = int32(spacer + 1 - m.lastNode)
}

@ @<아이템 이름 하나와 그 색을 훑는다@>=
name, next := token(buf, p, true)
if name == "" {
	failf("empty item name")
}
num, known := m.nameIndex[name]
if !known {
	failf("unknown item name: %s", name)
}
m.createNode(num, spacer, &hasPrimary)
if buf[next] == ':' {
	if num < m.second {
		failf("primary item must be uncolored: %s", name)
	}
	color, ce := token(buf, next+1, false)
	if color == "" {
		failf("missing color after %s:", name)
	}
	m.nd[m.lastNode].clr = int32(m.internColor(color))
	next = ce
} else {
	m.nd[m.lastNode].clr = 0
}
p = skipSpace(buf, next)

@ @<옵션을 되감는다@>=
for m.lastNode > spacer {
	slot := int(m.nd[m.lastNode].itm) * mccIprop
	m.setSize(slot, m.size(slot)-1)
	m.setPos(slot, spacer-1)
	m.lastNode--
}

@ @<옵션 읽기@>=
func (m *MCC) createNode(num, spacer int, hasPrimary *bool) {
	slot := num * mccIprop
	m.set = ensure(m.set, slot)
	if m.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", m.names[num])
	}
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	t := m.size(slot)
	m.nd[m.lastNode].itm = int32(num)
	m.nd[m.lastNode].loc = int32(t)
	if num < m.second {
		*hasPrimary = true
	}
	m.setSize(slot, t+1)
	m.setPos(slot, m.lastNode)
}

@ 마무리는 같은 세 훑기를 돌고 나서, 벌써부터 아무 구실도 못 할 것이 빤한
아이템을 물러나게 한다.
@<입력 마무리@>=
func (m *MCC) finalize() {
	@<set 배열을 깐다@>
	@<아이템 머리를 채운다@>
	@<노드가 가리키는 곳을 고친다@>
	m.deactivateOptionless()
}

@ @<set 배열을 깐다@>=
m.active, m.itemlen = m.lastItm-1, m.lastItm-1
m.item = ensure(m.item, m.itemlen)
m.set = ensure(m.set, m.itemlen*mccIprop+1) // 입력 자리를 모두 읽을 수 있게

j := mccExtra
k := 0
for ; k < m.itemlen; k++ {
	m.item[k] = int32(j)
	j += mccExtra + m.size((k+1)*mccIprop)
}
m.setlen = j - mccExtra
m.set = ensure(m.set, j+1)
if m.second == secondUnset {
	m.osecond, m.second = m.active, j
} else {
	m.osecond = m.second - 1
}

@ 크기와 자리와 번호에 더해, 이 훑기는 주 아이템마다 그 여유와 한도를 베껴
넣는다. 그리고 |baditem|의 뜻이 날카로워진다. 치명적인 말썽은 제 {\it 아래끝\/}에도
닿지 못하는 주 아이템이다. 아래끝이~0이고 옵션이 없는 주 아이템은 말썽이 아니라
그저 나타나지 않을 뿐이므로, 옵션 없는 부 아이템과 함께 마지막 훑기를 위해
쌓아 둔다.
@<아이템 머리를 채운다@>=
for ; k != 0; k-- {
	base := int(m.item[k-1])
	if k == m.second {
		m.second = base
	}
	m.setSize(base, m.size(k*mccIprop))
	m.setItemNo(base, k)
	m.setSlack(base, m.slack(k*mccIprop))
	m.setBound(base, m.bound(k*mccIprop))
	m.setPos(base, k-1)
	switch {
	case k <= m.osecond && m.size(base) < m.bound(base)-m.slack(base):
		m.baditem = k
	case m.size(base) == 0:
		m.force = ensure(m.force, m.forced+1)
		m.force[m.forced] = int32(base)
		m.forced++
	}
}

@ @<노드가 가리키는 곳을 고친다@>=
for k = 1; k < m.lastNode; k++ {
	if m.nd[k].itm < 0 {
		continue
	}
	base := int(m.item[int(m.nd[k].itm)-1])
	loc := base + int(m.nd[k].loc)
	m.nd[k].itm = int32(base)
	m.nd[k].loc = int32(loc)
	m.set[loc] = int32(k)
}

@ 마지막 훑기는 옵션 없는 아이템의 스택을 비우며 하나하나 물러나게 하여, 탐색이
그들을 두고 고민할 일이 아예 없게 한다.
@<입력 마무리@>=
func (m *MCC) deactivateOptionless() {
	for m.forced != 0 {
		m.forced--
		j := int(m.force[m.forced])
		m.active--
		i := int(m.item[m.active])
		pp := m.pos(j)
		m.item[m.active], m.item[pp] = int32(j), int32(i)
		m.setPos(j, m.active)
		m.setPos(i, pp)
	}
}

@** 테스트.
문학적 프로그램이라면 제가 살아 있다는 증거를 스스로 지니는 것이 옳다. 이 마지막
부분은 같은 원본에서 짜이되 {\it 따로\/} 선 파일 \.{ssmcc\_test.go}로 tangle되는데,
주된 출력이 아니라 곁딸린 출력의 이름을 대는 \.{GWEB}의 파일 출력 제어 코드를 쓴
덕이다. 도우미 |countMCC|는 풀이기가 찾아내는 것의 수를 셀 뿐이고, 아래 경우들은
꼭 맞는 횟수(\.{2\|a}), 여유가 있는 범위(\.{1:2\|a}), 그리고 \.{cmd/ssmcc}로
맞춰 본 좀 더 푸짐한 섞음을 떠본다.
@(ssmcc_test.go@>=
package dcells

import (
	"fmt"
	"math/rand"
	"sort"
	"strings"
	"testing"
)

func countMCC(t *testing.T, input string) int {
	t.Helper()
	res := NewMCC().Dance(strings.NewReader(input))
	n := 0
	for range res.Solutions {
		n++
	}
	return n
}

func TestMCCMultiplicity(t *testing.T) {
	// 아이템 "a"는 꼭 두 번 덮여야 하고(2|a), 덮개는 {ab, ac} 하나뿐이다.
	input := "2|a b c\na b\na c\nb c\n"
	if n := countMCC(t, input); n != 1 {
		t.Errorf("exact-twice: got %d solutions, want 1", n)
	}
}

func TestMCCSlack(t *testing.T) {
	// 아이템 "a"는 1..2번, b와 c는 꼭 한 번씩. 덮개는 {ab, ac} 하나다.
	input := "1:2|a b c\na b\na c\nb c\n"
	if n := countMCC(t, input); n != 1 {
		t.Errorf("slack: got %d solutions, want 1", n)
	}
}

func TestMCCRicher(t *testing.T) {
	// cmd/ssmcc로 맞춰 보았다. 해는 4개.
	input := "1:3|a 2|b c d\na b\na c\na d\nb c\nb d\nc d\na b c\n"
	if n := countMCC(t, input); n != 4 {
		t.Errorf("richer: got %d solutions, want 4", n)
	}
}

@ 끝으로 이 엔진이 맨 엔진을 품고 있음을 살피는 검사 둘이다. 다중도를 그냥 두면
여느 XCC를 그대로 되풀이해야 하고---8-퀸의 해 92개가 그것이다---색 기계도 거기서
돌아야 한다.
@(ssmcc_test.go@>=
func TestMCCPlainXCC(t *testing.T) {
	n := 8
	var b strings.Builder
	for i := 0; i < n; i++ {
		b.WriteString(fmt.Sprintf("r%02d ", i))
	}
	for j := 0; j < n; j++ {
		b.WriteString(fmt.Sprintf("c%02d ", j))
	}
	b.WriteString("|")
	for k := 0; k < 2*n-1; k++ {
		b.WriteString(fmt.Sprintf(" a%02d ", k))
	}
	for k := 0; k < 2*n-1; k++ {
		b.WriteString(fmt.Sprintf(" b%02d ", k))
	}
	b.WriteString("\n")
	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			b.WriteString(fmt.Sprintf("r%02d ", i))
			b.WriteString(fmt.Sprintf("c%02d ", j))
			b.WriteString(fmt.Sprintf("a%02d ", i+j))
			b.WriteString(fmt.Sprintf("b%02d ", i-j+n-1))
			b.WriteString("\n")
		}
	}
	if got := countMCC(t, b.String()); got != 92 {
		t.Errorf("8-queens via MCC: got %d, want 92", got)
	}
}

func TestMCCColors(t *testing.T) {
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
	if n := countMCC(t, input); n != 2 {
		t.Errorf("colors: got %d solutions, want 2", n)
	}
}

@ 최소화에는 손으로 따져 볼 만큼 작은 문제를 준다. 아이템 \.{a}는 두 번 덮이기를
바라고 \.{b}와 \.{c}는 한 번씩 바라는데, 값이 매겨진 옵션 여섯 가운데 그것을 모두
채우는 짜임은 셋뿐이다. 덮개 $\{ab,ac\}$가~9, $\{ac,a,b\}$가~14, $\{ab,a,c\}$가~15이다.
값은 옵션이 찍히는 모양을 열쇠로 삼아 적어 두었다. 그래야 돌아온 덮개를 매길 때와
같은 식으로 더할 수 있다.
@(ssmcc_test.go@>=
func priceOfCover(sol []Option, price map[string]int) int {
	c := 0
	for _, opt := range sol {
		c += price[strings.Join(opt, " ")]
	}
	return c
}

func TestMCCMinimize(t *testing.T) {
	input := "2|a b c\na b\na c\na\nb c\nb\nc\n"
	price := map[string]int{"a b": 5, "a c": 4, "a": 9, "b c": 2, "b": 1, "c": 1}
	res := NewMCC().Minimize(strings.NewReader(input),
		func(_ int, opt Option) int { return price[strings.Join(opt, " ")] })
	got := -1
	for sol := range res.Solutions {
		got = priceOfCover(sol, price)
	}
	if got != 9 {
		t.Errorf("cheapest cover costs %d, want 9", got)
	}
}

@ 메서드 |Need|는 하한 함수가 |XCC|에서는 갖지 못하는 것이므로 제 몫의 테스트를
받는다. 뿌리에서, 아직 아무것도 덮이지 않았을 때, 아이템마다 꼭 제 아래끝
다중도만큼을 바라고 있어야 한다.
@(ssmcc_test.go@>=
func TestMCCNeed(t *testing.T) {
	input := "2|a 1:3|b c\na b\na c\nb\na\nb c\n"
	seen := map[string]int{}
	s := NewMCC()
	s.Bound = func(f Frame) int {
		if len(seen) == 0 {
			for i := range f.Live {
				seen[f.Name(i)] = f.Need(i)
			}
		}
		return 0
	}
	r := s.Minimize(strings.NewReader(input), func(_ int, _ Option) int { return 1 })
	for range r.Solutions {
	}
	for name, want := range map[string]int{"a": 2, "b": 1, "c": 1} {
		if seen[name] != want {
			t.Errorf("Need(%s) = %d at the root, want %d", name, seen[name], want)
		}
	}
}

@ 값이 하나도 음수가 아닐 때면 언제나 성한 하한이 여기 있다. 앞으로 $k$번 더
덮이기를 바라는 아이템은 제 집합에 살아남은 것 가운데 서로 다른 옵션 $k$개를
가져가야 하고, 그 하나하나가 적어도 거기서 가장 싼 것만큼은 문다. 그러니 그 가장
싼 값의 $k$배가 이 아이템이 앞으로 질 몫의 바닥이고, 그런 바닥 가운데 가장 비싼
것이 전체의 바닥이다. 필드 |Live|는 한 번에 아이템 하나의 옵션들을 건네주므로,
이 훑기가 바라는 모양이 꼭 그것이다.
@(ssmcc_test.go@>=
func cheapestTimesNeed(f Frame) int {
	bound, item, low, need := 0, -1, 0, 0
	flush := func() {
		if item >= 0 && low*need > bound {
			bound = low * need
		}
	}
	for i, opt := range f.Live {
		if i != item {
			flush()
			item, low, need = i, f.Cost(opt), f.Need(i)
		} else if c := f.Cost(opt); c < low {
			low = c
		}
	}
	flush()
	return bound
}

@ 그리고 여기, 제 밥값을 하는 테스트가 있다. 다중도가 있는 작은 문제를 마구잡이로
지어---아이템의 빈 것 아닌 부분 집합마다 옵션 하나씩이되 주사위가 빼라면 빼고,
옵션의 3분의 1쯤은 부 아이템~|x|를 두 색 가운데 하나로 달고 있다---가장 싼 덮개를
두 갈래로 구한다. 메서드 |Dance|로 덮개를 모조리 세는 길과, 하한을 주고 또 주지 않고
|Minimize|로 구하는 길이다. 셋이 모두 맞아야 하고, 그것을 사백 번 잇달아 한다.

이것이 진짜 버그를 잡아낸 모양의 테스트다. 예전에 |search|의 엉뚱한 자리에서
가지를 치면 강제 스택에 칸이 남았고, 다음 마디가 그것을 제 강제 이동으로 삼았다.
이진 분기에서 그것은 옵션 하나에 매달리고 나머지는 아예 시도하지 않는다는 뜻이다.
답은 모두 그럴듯해 보였다. 다만 이따금, 가장 싼 것이 아니었을 뿐이다.
@(ssmcc_test.go@>=
func randomMCCProblem(rng *rand.Rand) (input string, price map[string]int) {
	names := []string{"a", "b", "c", "d"}[:3+rng.Intn(2)]
	var b strings.Builder
	@<무작위 아이템 줄을 쓴다@>
	@<웬만한 부분 집합마다 값이 매겨진 옵션을 쓴다@>
	return b.String(), price
}

@ @<무작위 아이템 줄을 쓴다@>=
for _, name := range names {
	switch rng.Intn(3) {
	case 0:
		fmt.Fprintf(&b, "%s ", name)
	case 1:
		fmt.Fprintf(&b, "2|%s ", name)
	default:
		fmt.Fprintf(&b, "1:2|%s ", name)
	}
}
b.WriteString("| x\n")

@ @<웬만한 부분 집합마다 값이 매겨진 옵션을 쓴다@>=
price = map[string]int{}
for mask := 1; mask < 1<<len(names); mask++ {
	if rng.Intn(3) == 0 {
		continue // 이것은 빼고 간다
	}
	var opt []string
	for i, name := range names {
		if mask&(1<<i) != 0 {
			opt = append(opt, name)
		}
	}
	if rng.Intn(3) == 0 {
		opt = append(opt, "x:"+string(rune('A'+rng.Intn(2))))
	}
	line := strings.Join(opt, " ")
	price[line] = rng.Intn(40)
	b.WriteString(line);b.WriteString("\n")
}

@ @(ssmcc_test.go@>=
func TestMCCMinimizeMatchesSearch(t *testing.T) {
	rng := rand.New(rand.NewSource(7))
	for trial := 0; trial < 400; trial++ {
		input, price := randomMCCProblem(rng)
		@<덮개를 모두 세어 가장 싼 것을 쥔다@>
		@<하한을 주고 또 주지 않고 최소화해 견준다@>
		@<가장 싼 셋을 달라 하고 견준다@>
	}
}

@ 모조리 세는 길은 값을 모두 정렬해 쥐고 있는다. 아래 연단 테스트가 그 가운데
가장 작은 것 말고도 더 바라기 때문이다.
@<덮개를 모두 세어 가장 싼 것을 쥔다@>=
var all []int
res := NewMCC().Dance(strings.NewReader(input))
for sol := range res.Solutions {
	all = append(all, priceOfCover(sol, price))
}
sort.Ints(all)
want := -1
if len(all) > 0 {
	want = all[0]
}

@ @<하한을 주고 또 주지 않고 최소화해 견준다@>=
for _, bound := range []func(Frame) int{nil, cheapestTimesNeed} {
	s := NewMCC()
	s.Bound = bound
	r := s.Minimize(strings.NewReader(input),
		func(_ int, opt Option) int { return price[strings.Join(opt, " ")] })
	got, last := -1, -1
	for sol := range r.Solutions {
		got = priceOfCover(sol, price)
		if last >= 0 && got >= last {
			t.Fatalf("trial %d: costs not improving (%d after %d)", trial, got, last)
		}
		last = got
	}
	if got != want {
		t.Fatalf("trial %d: got %d, want %d\n%s", trial, got, want, input)
	}
}

@ 손잡이 |Best|를 셋으로 두면, 닿는 가장 싼 덮개 셋의 값은 이 문제의 가장 싼
덮개 셋의 값이어야 한다. 덮개가 셋보다 적은 문제라면 그 전부가 닿아야 한다.
@<가장 싼 셋을 달라 하고 견준다@>=
s := NewMCC()
s.Best = 3
var got []int
r := s.Minimize(strings.NewReader(input),
	func(_ int, opt Option) int { return price[strings.Join(opt, " ")] })
for sol := range r.Solutions {
	got = append(got, priceOfCover(sol, price))
}
sort.Ints(got)
k := min(3, len(all))
if len(got) < k || fmt.Sprint(got[:k]) != fmt.Sprint(all[:k]) {
	t.Fatalf("trial %d: three cheapest %v, want %v\n%s", trial, got, all[:k], input)
}

@ 다중도가 정해진 아이템을 담은 옵션에는 음수 값을 매겨도 된다. 그 아이템의
세금이 그것을 빨아들이기 때문이다. 글 \.{ssxcc.w}에 나온 그 예다. 옵션마다 값이
$-1$이고, $\{a\}+\{b\}$가~$-2$로 $\{ab\}$의~$-1$을 이겨야 한다. 탐색은 $\{ab\}$를
먼저 만나는데도 그렇다.
@(ssmcc_test.go@>=
func TestMCCMinimizeNegative(t *testing.T) {
	res := NewMCC().Minimize(strings.NewReader("a b\na b\na\nb\n"),
		func(_ int, _ Option) int { return -1 })
	got := 0
	for sol := range res.Solutions {
		got = -len(sol)
	}
	if got != -2 {
		t.Errorf("cheapest cover costs %d, want -2", got)
	}
}

@ 옵션 $\{c\}$는 여유가 있는 아이템만 담고 있으므로 그 음수 값을 빨아들일 세금이
없고, 그러면 |Minimize|는 틀린 답을 내놓느니 물리쳐야 한다. (옵션 $\{a\}$의~$-1$은
그것만으로는 괜찮다.)
@(ssmcc_test.go@>=
func TestMCCMinimizeRefusesNegative(t *testing.T) {
	defer func() {
		if recover() == nil {
			t.Error("a negative price on option c was accepted")
		}
	}()
	NewMCC().Minimize(strings.NewReader("a 0:1|c\na\nc\n"),
		func(_ int, _ Option) int { return -1 })
}

@** 색인.
