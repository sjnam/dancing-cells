\input kotexgweb

\def\title{XCCDC}

@s Context int
@s Duration int
@s Ticker int
@s Reader int
@s Builder int
@s Time int

@** 들어가며.
이 글은 {\tt XCCDC}다. 색깔이 붙은 정확 덮개를 또 한 번, 희소 집합 위에서 또 한
번 추되, 이번에는 풀이기가 훨씬 멀리 내다본다. 패키지 |dcells|의 셋째 엔진이고,
다른 둘이 그렇듯 그것만 떼어 읽어도 되도록 썼다. 타입 |Option|과 |Result|, 함수
|ensure|, 그리고 {\tt DLX} 훑개는 짝이 되는 글 \.{dcells.w}의 것이고, 셋이 함께
춤추는 바탕인 희소 집합도 아래에 짧게 되새기되 느긋한 이야기는 거기에 있다.

이 프로그램의 조상은 {\tt SSXCC}(\.{ssxcc.w})다. 크누스는 거기에 자료 구조와
알고리즘을 {\it 빼지 않고 더해서\/} 이 프로그램의 원본을 얻었다. 문제도 같은
문제이고---주 아이템은 꼭 한 번 덮이고, 부 아이템은 몇 번이든 덮이되 그것을
건드리는 옵션이 색에 뜻을 모아야 한다---답도 같은 답이다. 다른 것은 탐색 나무의
마디 하나가 무언가에 매달리기 전에 얼마나 많은 품을 들일 뜻이 있느냐다.

프로그램 {\tt SSXCC}는 한 걸음을 내다본다. 옵션이 바닥난 아이템을 알아보고,
옵션이 하나뿐인 아이템을 알아본다. 프로그램 {\tt XCCDC}는 {\it 도메인
일관성\/}을 지키는데, 그것은 그 착상의 전부이면서 그 이상이다. 어떤 옵션을 {\it
쓰기만 해도\/} 다른 어딘가의 주 아이템이 덮일 길을 잃는다면, 그 옵션은 그 자리에서
내버린다. 말하자면 전처리기 {\tt DLX-PRE}를 마디마다, 바닥까지, 몇 번이고 다시
돌리는 셈이다. 마디는 비싸지고, 그 수는 훨씬 줄어든다. 그 거래가 값을 하는지는
오롯이 문제에 달렸는데, 두 엔진을 한 패키지에 함께 두는 까닭이 바로 그것이다.

이 저장소의 \.{examples} 디렉터리에 있는 두 문제가 그 거래의 양면을 보여 준다.
크기 $15\times15$의 필로미노 퍼즐에서 {\tt SSXCC}는 마디를 133{,}639개 들르고
11초가 걸리는데, {\tt XCCDC}는 82개를 들르고 50밀리초가 걸린다. 크기 $2\times2$의
구멍이 뚫린 $8\times8$ 판의 펜토미노 채우기에서 {\tt XCCDC}는 또 마디를 훨씬 적게 쓰지만
---93{,}833개에 맞선 12{,}295개다---그것을 얻는 데 여섯 배의 시간이 들고, 그
사이에 백만 개가 넘는 옵션을 솎아 낸다. 제 문제가 둘 가운데 어느 쪽인지를 미리
알려 주는 문제는 없다.
@c
package dcells

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"time"
)

@<일관성 장치@>
@<엔진@>
@<입력 단계@>

@ 희소 집합이 모든 것의 바닥이니, 한 문단으로 적어 둔다. 전체 집합
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
되풀이하는 것이다. 밑자리 바로 아래 칸들이 그 살림살이를 담는데, 여기서는 옵션
둘이 나란히 설 수 있는지 따질 때 쓰는 필드 둘까지 거기에 든다. 아래에 이름 붙인
접근자가 그것을 읽고 쓴다.

@ 풀이기 구조체는 상태의 덩이 여럿을 모아 지었다. 덩이마다 이름을 붙였으니
구조체 자체가 제 관심사의 목록으로 읽힌다. 먼저 공개된 손잡이다. 필드 |Debug|는
|dlx| 라이브러리가 |stderr|에 찍는 것과 같은 짤막한 입력 요약과 마무리 통계를
켜고, 첫 가지치기에 대한 제 몫의 한 줄을 덧붙인다. 필드 |PulseInterval|이
양수이면 이따금 맥박을 보내 달라는 뜻이다.
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

@ ``업데이트''는 희소 집합의 맞바꿈 한 번이고, ``노드''는 탐색에 한 번 들르는
것이며, ``솎기''는 받쳐 줄 것이 없어 내버린 옵션 하나다. 이 엔진이 있는 까닭이
바로 그 솎기다.
@<탐색 통계@>=
updates uint64
nodes   uint64
purges  uint64
options uint64
count   uint64

@ @<출력 채널@>=
solStream chan []Option
heartbeat chan string
pulse     *time.Ticker

@** 도메인 일관성.
주어진 {\tt XCC} 문제를 이항 제약 충족 문제로 읽어 보자. 변수는 주 아이템이다.
주 아이템~$p$의 도메인은 $p$를 담은 옵션들의 집합인데, 춤이 이미 $p$를 위해
지키고 있는 바로 그 희소 집합이다. 그리고 서로 다른 주 아이템 $p\ne p'$마다
제약이 하나 있다. 아이템 $p$의 옵션 $o$와 $p'$의 옵션 $o'$가 나란히 설 수 있는
것은, $o$와 $o'$가 {\it 어울릴\/} 때뿐이다. 어울린다는 것은 둘이 같거나, 아니면
겹치는 아이템이 없되 0이 아닌 색에 뜻을 모으는 부 아이템만은 겹쳐도 된다는 뜻이다.

그러면 도메인 일관성은 이런 성질이다. 모든 $p\ne p'$에 대해, 그리고 $p$의
도메인에 든 모든 $o$에 대해, 그와 어울리는 $o'$가 $p'$의 도메인에 하나는 있다.
뒤집어 말하면 이렇고, 외우기에는 이쪽이 낫다. 옵션 $o$를 고르는 일이, 그 옵션이
담고 있지 않은 어느 주 아이템의 도메인도 쓸어버려서는 안 된다. 이 시험에 떨어진
옵션은 어느 해에도 나타날 수 없으므로 치워 버리는데, 그러다 보면 그 이웃이 다시
떨어지기도 한다. 어느 도메인이 비면 지금의 부분 문제에는 해가 아예 없다는 뜻이고,
아니면 물결이 잦아들어 모든 도메인이 비지 않고 일관된 것이 된다. 분기는 그러고
나서 한다.

@ 그 성질을 다시 셈하지 않고 {\it 지켜 내는\/} 것이 재주의 전부다. 여기 쓴
얼개는 Christian Bessi\`ere의 알고리즘 AC-6 [{\sl Artificial Intelligence\/
\bf65} (1994), 179--190]과 Christophe Lecoutre, Fred Hemery의 AC3rm [{\sl IJCAI
Proceedings\/ \bf20} (2007), 125--130]을 {\it 증인\/}을 두는 방식으로 아우른
것이다. 머릿속에는 배열 $S[o,p]$가 있다고 치자. 옵션 $o$와 주 아이템 $p$마다
하나씩인데, $p\in o$이면 표시~$\#$이고, 그렇지 않으면 $o$와 어울리면서 $p$를 담은
어떤 옵션 $o'$이다. 배열 $S$의 칸 하나하나가 일관성 조건의 한 귀퉁이가 성립한다는
증인이고, 증인이 서 있는 동안에는 따져 볼 것이 없다.
@^Bessi\`ere, Christian@>
@^Lecoutre, Christophe@>
@^Hemery, Fred@>

@ 그 배열은 어디에도 저장하지 않는다. 저장하는 것은 그 역이다. 옵션 $o'$마다
$o'$의 {\it 방아쇠 목록\/}을 지니는데, $S[o,p]=o'$인 쌍 $(o,p)$을 모두 모은
것이다. 옵션 $o'$이 사라지면 그것이 데리고 가는 증인이 바로 그들이므로, 그
방아쇠 목록이 당겨지고 뚫린 구멍마다 새 증인을 찾아야 한다. 옵션 $o$마다 {\it
수선 목록\/}도 하나씩 있는데, 제게 당겨졌으나 아직 구멍이 메워지지 않은 쌍
$(o',p)$을 모은 것이다. 그리고 큐~$Q$가 메울 구멍이 하나라도 남은 옵션을 모두
담는다. 방아쇠와 수선은 스택이고 큐는 선입선출이며, 셋 모두 익숙한 방식대로
필드 |info|와 |link|를 가진 칸들의 배열 |pool| 하나에 산다.

@ 그 장치가 여기 있는데, 춤이 그것에 기대는 차례대로 늘어놓았다.
@<일관성 장치@>=
@<옵션 접근자@>
@<링크 창고@>
@<어울림 따지기@>
@<옵션 물리기@>
@<수선 목록 되돌리기@>
@<큐 비우기@>
@<일관성 세우기@>

@ 코드에 앞서 낱말 둘을 짚어 둔다. 옵션은 속으로는 그 바로 앞 사이막 노드의
색인으로 부르고, 아이템은 주든 부든 배열 |set| 안의 제 밑자리로 부른다. 그러니
아래에서 ``옵션 |opt|''라 하면 언제나 사이막 색인이고, 탐색이 옵션을 노드 색인으로
주고받는 것은 |optionOf|가 그것을 고쳐 부르기 전까지다.

@ 크누스는 옵션의 동적인 필드 셋을 어차피 놀고 있던 노드 안에 밀어 넣었고, 이
이식판도 그 꼼수를 그대로 둔다. 좋은 꼼수이기 때문이다. 옵션 |opt|의 방아쇠
스택 꼭대기는 |nd[opt].clr|에, 수선 스택 꼭대기는 |nd[opt].xtra|에, 그리고 다음
장이 풀어 놓을 |age|는 |nd[opt+1].xtra|에 산다. 사이막에는 제 색도 제 자리도
없고, 옵션의 첫 노드는 그 |xtra|를 아무도 탐내지 않는 유일한 노드다. 값
|fixit(opt)|이 0이 아닌 것은 옵션 $o$가 큐에 들어 있는 것과 꼭 같은 말이다.
@^Knuth, Donald Ervin@>
@<옵션 접근자@>=
func (s *XCCDC) trigger(opt int) int { return int(s.nd[opt].clr) }
func (s *XCCDC) fixit(opt int) int   { return int(s.nd[opt].xtra) }
func (s *XCCDC) age(opt int) int     { return int(s.nd[opt+1].xtra) }

func (s *XCCDC) setTrigger(opt, v int) { s.nd[opt].clr = int32(v) }
func (s *XCCDC) setFixit(opt, v int)   { s.nd[opt].xtra = int32(v) }
func (s *XCCDC) setAge(opt, v int)     { s.nd[opt+1].xtra = int32(v) }

@ 창고의 칸은 정수 쌍이고, \.{ssxcc.w}가 제 저장 스택을 위해 선언한 타입
|twoints|가 그대로 알맞다. 필드 |l|이 |info|이고 |r|이 |link|다. 0번 칸은 칸이
아니라 빈 목록의 머리이므로, 링크가 0이면 목록의 끝이다. 마땅히 그래야 한다.
풀려난 칸은 손으로 거두어 다시 쓴다. 탐색 한 번에 수백만 개를 얻고 놓을 수 있기
때문이다.
@<링크 창고@>=
func (s *XCCDC) getavail() int {
	if p := int(s.pool[0].r); p != 0 {
		s.pool[0].r = s.pool[p].r
		return p // info(p)에 무엇이 있었든 부르는 쪽이 알아서 한다
	}
	s.poolptr++
	s.pool = ensure(s.pool, s.poolptr)
	return s.poolptr - 1
}

func (s *XCCDC) putavail(p int) {
	s.pool[p].r = s.pool[0].r
	s.pool[0].r = int32(p)
}

@ 방아쇠 목록과 수선 목록의 칸은 둘씩 짝을 이룬다. 앞의 것은 옵션을, 뒤의 것은
주 아이템을 댄다. 그러니 쌍 $(o,p)$은 칸 $c$와 $c'$를 차지하여
$\\{link}(c)=c'$, $\\{info}(c)=o$, $\\{info}(c')=p$이고, $\\{link}(c')$가 다음
칸으로 이어진다. 방아쇠를 수선으로 바꾸는 데 저장 두 번이 들 뿐 새로 얻는 칸이
없는 것은 그래서이고, 이렇게 벌여 놓은 뜻이 거기에 있다.

@ 우리가 하는 큰일 가운데 하나가 주어진 옵션~$O$와 어울리는 옵션을 찾는 일이다.
옵션 $O$의 아이템마다 |compatStamp|의 지금 값을 찍어 두고, 부 아이템이면 $O$가
거기에 주는 색까지 적어 두는 식으로 한다. 그러면 후보는 뜻이 다른 아이템에 찍힌
도장을 만나는 순간 떨어진다. 아이템 $I$가 옵션 $O$에 든 것은 |mark(I)|이 그
도장과 같다는 말과 꼭 같으니, 도장은 매번 새것이어야 한다. 도장이 자리를 다 쓰면
모든 표시를 0으로 되돌리고 처음부터 다시 찍는데, 스무 억 번의 어울림 시험을
치러야 한 번 일어나는 채비이고 그때까지는 아무것도 들지 않는다.
@<어울림 따지기@>=
func (s *XCCDC) markItems(opt int) {
	@<어울림 도장을 새로 찍는다@>
	for nn := opt + 1; s.nd[nn].itm > 0; nn++ {
		ii := int(s.nd[nn].itm)
		s.setMark(ii, s.compatStamp)
		if ii >= s.second {
			if c := int(s.nd[nn].clr); c != 0 {
				s.setMatch(ii, c)
			} else {
				s.setMatch(ii, -1) // 색 없는 아이템은 어느 색과도 맞지 않는다
			}
		}
	}
}

@ @<어울림 도장을 새로 찍는다@>=
if s.compatStamp == maxStamp {
	for k := 0; k < s.itemlen; k++ {
		s.setMark(int(s.item[k]), 0)
	}
	s.compatStamp = 0
}
s.compatStamp++

@ 이제 시험 자체다. 우리 손에 쥐어지는 것은 어떤 옵션~$O'$의 한복판 어딘가에
있는 노드 |p|인데, 아이템의 집합에서 옵션이 제 모습을 드러내는 방식이 그러하기
때문이다. 그리고 우리는 두 가지를 한꺼번에 답해야 한다. 옵션 $O'$이 도장 찍힌
옵션과 어울리는가, 그리고 $O'$은 어디서 시작하는가. 둘 다 돌아가며 걷는 한 번의
걸음에서 떨어진다. 사이막은 |itm|이 양수가 아니고 그 값은 바로 앞 옵션 길이에
음수를 붙인 것이므로, 사이막을 만나면 그 옵션 제 사이막이 어디 있는지 알게 되고
걸음을 첫머리로 감아 돌릴 수 있다. 들어올 때 딛었던 노드로 돌아오면 끝이다.
돌려주는 사이막은 답이 ``그렇다''일 때만 뜻이 있다.
@<어울림 따지기@>=
func (s *XCCDC) compatible(p int) (opt int, ok bool) {
	opt = p
	for nn := p + 1; nn != p; nn++ {
		jj := int(s.nd[nn].itm)
		switch {
		case jj <= 0:
			opt = nn + jj - 1 // 사이막이다. 그 옵션 제 사이막으로 되돌아간다
			nn = opt
		case s.mark(jj) == s.compatStamp:
			if jj < s.second || s.nd[nn].clr == 0 ||
				int(s.nd[nn].clr) != s.match(jj) {
				return opt, false
			}
		}
	}
	return opt, true
}

@ 까닭이 무엇이든 옵션 하나가 사라질 때 일어나는 일이 여기 있다. 먼저 그 옵션이
제 아이템들의 집합에서 떠난다. 그러다 어느 주 아이템의 도메인이 빌 참이면 하던
일을 통째로 접는다. 지금의 부분 문제에는 가망이 없기 때문이다. 그렇지 않으면 그
옵션의 방아쇠 목록이 당겨진다. 그 옵션이 대 주던 증인은 모두 갈아 치워야 하므로,
그 칸들은 그 증인에 기대고 있던 옵션들의 수선 목록으로 옮겨 가고, 그 옵션들은
큐에 든다.

메서드 |optOut|의 나머지는 제값을 몇 곱절로 해내는 살림이다. 방아쇠 목록은 길고,
거기 든 것의 태반은 이미 살아 있지 않고 한동안 그대로일 옵션에 대한 것이다.
그들을 몇 번이고 지나쳐 걷는 대신, 다음 장의 주제인 {\it 나이\/}로 바구니에
나눠 담고 어린 것이 뒤에 오도록 목록을 다시 지으며, ``이 아래는 모두 셈에 들
만큼 나이를 먹지 않았다''고 이르는 표를 끼워 넣는다. 바구니는 |trigHead|와
|trigTail|인데, 부를 때마다 비어 있고 나올 때도 비워 둔다.
@<옵션 물리기@>=
func (s *XCCDC) optOut(opt, act int) bool {
	@<옵션 |opt|를 아직 씻기지 않은 아이템들의 집합에서 지우거나 실패한다@>
	s.setAge(opt, s.curAge)
	s.purges++
	tmin, cutoff := infiniteAge, -1
	hintP, hintQ, pp := 0, 0, 0
	for p := s.trigger(opt); p != 0; p = pp {
		q := int(s.pool[p].r)
		optp, ii := int(s.pool[p].l), int(s.pool[q].l)
		pp = int(s.pool[q].r)
		if optp < 0 {
			@<방아쇠 귀띔을 믿거나 버린다@>
		}
		@<이 칸이 죽었는지 가리고, 죽었으면 |t|를 정한다@>
		if !dead {
			@<방아쇠를 옵션 |optp|의 수선으로 바꾼다@>
			continue
		}
		if t < 0 {
			s.putavail(p) // 이만큼 어린 옵션은 영영 돌아오지 않는다
			s.putavail(q)
			continue
		}
		@<이 칸을 나이 |t|의 바구니에 담는다@>
	}
	@<바구니에서 옵션 |opt|의 방아쇠 목록을 다시 짓는다@>
	return true
}

@ 앞선 단계에서 씻긴 부 아이템은 집합이 얼어붙어 있으니 건드려서는 안 된다.
값 |active|와 부르는 쪽이 준 |act| 사이에 놓인 아이템은 바로 지금 씻기고 있는
것들이고, 그들은 우리가 건사한다. 지우기 자체는 \.{ssxcc.w}의 희소 집합
삭제인데, 여기서는 아이템 쪽이 아니라 옵션 쪽에서 바라본 모습이다.
@<옵션 |opt|를 아직 씻기지 않은 아이템들의 집합에서 지우거나 실패한다@>=
for nn := opt + 1; ; nn++ {
	ii := int(s.nd[nn].itm)
	if ii <= 0 {
		break
	}
	p := int(s.nd[nn].loc)
	if p >= s.second && s.pos(ii) >= act {
		continue // 아이템 ii는 이 가지가 열리기 전에 씻겼다
	}
	sz := s.size(ii) - 1
	if sz == 0 && p < s.second {
		@<그만둔다: 옵션 |opt|가 이 아이템의 마지막 옵션이었다@>
	}
	nnp := int(s.set[ii+sz])
	s.setSize(ii, sz)
	s.set[ii+sz], s.set[p] = int32(nn), int32(nnp)
	s.nd[nn].loc, s.nd[nnp].loc = int32(ii+sz), int32(p)
	s.updates++
}

@ 지금 고른 것들을 도메인 일관된 무엇으로도 이어 갈 수 없으니, 큐에서 기다리던
수선 목록은 모두 제자리로 돌아가야 한다. 그것을 되돌리는 일은 해도 그만인 살림이
아니다. 그 칸들이 어느 증인이 치워졌는지를 적어 둔 유일한 기록이고, 뒤에 올
가지가 그것을 쓸 것이기 때문이다.
@<그만둔다: 옵션 |opt|가 이 아이템의 마지막 옵션이었다@>=
for s.qfront != s.qrear {
	p := s.qfront
	s.qfront = int(s.pool[p].r)
	waiting := int(s.pool[p].l)
	s.putavail(p)
	s.revertFixits(waiting)
}
return false

@ 수선을 도로 방아쇠로 바꾸는 일은 그것을 수선으로 만든 움직임을 칸 하나하나까지
거꾸로 밟는 것이다.
@<수선 목록 되돌리기@>=
func (s *XCCDC) revertFixits(opt int) {
	var pp int
	for p := s.fixit(opt); p != 0; p = pp {
		q := int(s.pool[p].r)
		optp := int(s.pool[p].l)
		pp = int(s.pool[q].r)
		s.pool[p].l = int32(opt)
		s.pool[q].r = int32(s.trigger(optp))
		s.setTrigger(optp, p)
	}
	s.setFixit(opt, 0)
}

@ 옵션 |opt|의 방아쇠 목록에 든 칸 $(o,p)$이 {\it 죽었다\/}는 것은, 그 증인에
기대던 옵션~$o$ 자신이 살아 있지 않거나, 덮이기를 기다리던 아이템~$p$가 이미
덮였다는 뜻이다. 나이 시험이 첫 물음을 값싸게 가려 줄 수 있을 때는 그렇게 한다.
살아 있지 않은 옵션의 나이는 많아야 |curAge|이므로, 그보다 나이가 많은 옵션은
틀림없이 살아 있다. 그럴 수 없을 때는 들여다본다. 옵션이 살아 있다는 것은 그
첫 아이템의 집합에 아직 제가 보인다는 말과 꼭 같은데, 입력 단계가 옵션마다 {\it
주\/} 아이템으로 시작할 것을 고집한 보람이 여기서 돌아온다. 씻긴 부 아이템은
아무것도 일러 주지 못하기 때문이다.
@<이 칸이 죽었는지 가리고, 죽었으면 |t|를 정한다@>=
t, dead := -1, false
if a := s.age(optp); a <= s.curAge {
	jj := int(s.nd[optp+1].itm) // optp의 첫 아이템, 언제나 주 아이템이다
	if int(s.nd[optp+1].loc) >= jj+s.size(jj) {
		t, dead = a, true
	}
}
if !dead && s.pos(ii) >= s.active {
	t, dead = s.curAge, true
}

@ 살아 있는 칸은 메워야 할 구멍이 된다. 그 두 칸은 베껴지는 일 없이 옵션 |opt|의
방아쇠 목록에서 |optp|의 수선 목록으로 옮겨 가고, 그전에 구멍이 없던 옵션은 이제
큐에 오른다. 이때 나이를 무한으로 두는데, 그래야 나중에 |emptyQueue|가 그 옵션이
기다리는 사이에 솎였는지를 가려낼 수 있다.
@<방아쇠를 옵션 |optp|의 수선으로 바꾼다@>=
s.pool[p].l = int32(opt)
s.pool[q].r = int32(s.fixit(optp))
if s.fixit(optp) == 0 {
	r := s.getavail()
	s.pool[s.qrear].r = int32(r)
	s.pool[s.qrear].l = int32(optp)
	s.qrear = r
	s.setAge(optp, infiniteAge)
}
s.setFixit(optp, p)

@ @<이 칸을 나이 |t|의 바구니에 담는다@>=
if s.trigHead[t] == 0 {
	s.trigTail[t] = int32(q)
}
s.pool[q].r = s.trigHead[t]
s.trigHead[t] = int32(p)
if t < tmin {
	tmin = t
}

@ 물결이 사는 곳이 큐다. 큐에 오른 옵션마다 구멍이 있고, 구멍마다 문제가 된
아이템의 도메인을 훑어 어울리는 옵션을 찾는다. 그러면 새 증인을 얻거나---흔한
쪽이고, 훑기가 대개 대뜸 멎으니 값도 싸다---아니면 그 옵션이 마지막 받침을 잃은
것이니 솎아 내야 하고, 그러면 큐에 옵션이 더 오른다. 큐가 마침내 비면 살아남은
옵션들은 도메인 일관된 것이다.
@<큐 비우기@>=
func (s *XCCDC) emptyQueue() bool {
	for s.qfront != s.qrear {
		p := s.qfront
		opt := int(s.pool[p].l)
		s.qfront = int(s.pool[p].r)
		s.putavail(p)
		if s.age(opt) != infiniteAge {
			s.revertFixits(opt) // 그사이에 opt 자신이 솎였다
			continue
		}
		s.markItems(opt)
		@<옵션 |opt|의 구멍마다 새 증인을 찾는다@>
	}
	return true
}

@ @<옵션 |opt|의 구멍마다 새 증인을 찾는다@>=
var pp int
for p := s.fixit(opt); p != 0; p = pp {
	q := int(s.pool[p].r)
	ii := int(s.pool[q].l) // opt에 없는 주 아이템
	pp = int(s.pool[q].r)
	found := false
	for c, end := ii, ii+s.size(ii); c < end; c++ {
		if optp, ok := s.compatible(int(s.set[c])); ok {
			@<옵션 |optp|를 |opt|와 |ii|의 증인으로 적는다@>
			found = true
			break
		}
	}
	if !found {
		@<받침이 없으니 옵션 |opt|를 솎아 내거나 실패한다@>
		break
	}
}
s.setFixit(opt, 0)

@ 구멍을 적어 두었던 두 칸이 옵션 |optp|의 방아쇠 목록 머리가 된다. 새 증인이
옛 증인이 놓은 짐을 그대로 지는 것이다.
@<옵션 |optp|를 |opt|와 |ii|의 증인으로 적는다@>=
s.pool[p].l = int32(opt)
s.pool[q].r = int32(s.trigger(optp))
s.setTrigger(optp, p)

@ 아직 들여다보지 않은 구멍은 옵션 |opt|가 솎이기 전에 제가 떠나온 목록으로
돌아간다. 곧이어 |optOut|이 옵션 |opt| 제 방아쇠 목록을 걸을 참이고, 그때 세상이
온전한 모습이기를 바라기 때문이다.
@<받침이 없으니 옵션 |opt|를 솎아 내거나 실패한다@>=
s.setFixit(opt, p)
s.revertFixits(opt)
if !s.optOut(opt, s.active) {
	return false
}

@ 공을 굴리기 시작하는 일은 탐색이 열리기 전에 같은 착상을 모든 옵션에 한꺼번에
들이대는 것이다. 이때 모든 |mark| 필드가 0이고 살아 있지 않은 아이템도 없으므로,
아래 코드는 큐의 속 반복문에 새 칸을 얻는 일만 더한 것이다. 옵션마다 제가 담지
않은 주 아이템마다 증인을 찾고, 찾지 못한 옵션은 그 자리에서 솎인다. 그러고 남는
것이 주어진 옵션들의 도메인 일관된 가장 큰 부분 집합이고, 춤이 참으로 푸는 문제가
바로 그것이다.
@<일관성 세우기@>=
func (s *XCCDC) establishDC() bool {
	s.curAge = -1
	s.qfront = s.getavail()
	s.qrear = s.qfront
	for opt := 0; opt < s.lastNode; opt += int(s.nd[opt].loc) + 1 {
		s.markItems(opt)
		@<옵션 |opt|에 없는 주 아이템마다 증인을 찾는다@>
	}
	return s.emptyQueue()
}

@ 여기서 솎이는 옵션은 |curAge|가 $-1$인 채로 솎인다는 것을 눈여겨보라. 탐색이
앞으로 쓸 어떤 나이보다도 어린 값이다. 방아쇠 목록에 바구니에 담지 않고 그냥
버려도 되는 칸이 생기는 까닭이 그것이고, 이 훑기에서는 바구니에 아무것도 담기지
않는 까닭도 그것이다.
@<옵션 |opt|에 없는 주 아이템마다 증인을 찾는다@>=
for k := 0; k < s.osecond; k++ {
	ii := int(s.item[k])
	if s.mark(ii) == s.compatStamp {
		continue // ii는 opt 안에 있으니 증인이 필요 없다
	}
	found := false
	for c, end := ii, ii+s.size(ii); c < end; c++ {
		if optp, ok := s.compatible(int(s.set[c])); ok {
			p := s.getavail()
			q := s.getavail()
			s.pool[p].r = int32(q)
			s.pool[q].l = int32(ii)
			@<옵션 |optp|를 |opt|와 |ii|의 증인으로 적는다@>
			found = true
			break
		}
	}
	if !found {
		if !s.optOut(opt, s.active) {
			return false
		}
		break // opt는 사라졌다. 다음 것으로 간다
	}
}

@ 그 첫 훑기에서 솎인 옵션은 살아남은 옵션들의 방아쇠 목록에 실린 쓸모없는 짐이고
영영 돌아오지도 않으므로, 두고두고 넘어 다니는 대신 한 번에 쓸어 낸다.
@<첫 방아쇠 목록을 추린다@>=
for opt := 0; opt < s.lastNode; opt += int(s.nd[opt].loc) + 1 {
	if s.age(opt) < 0 {
		continue
	}
	qq, pp := -1, 0
	for p := s.trigger(opt); p != 0; p = pp {
		q := int(s.pool[p].r)
		optp := int(s.pool[p].l)
		pp = int(s.pool[q].r)
		if s.age(optp) < 0 {
			s.putavail(p)
			s.putavail(q)
			if qq < 0 {
				s.setTrigger(opt, pp)
			} else {
				s.pool[qq].r = int32(pp)
			}
		} else {
			qq = q
		}
	}
}

@** 엔진.
이제 풀이기 자체다. 겉모양은 세 엔진이 함께 지니는 것이고---행렬을 읽고, 고루틴을
띄우고, 해를 채널로 건넨다---속모양이 {\tt SSXCC}와 갈라서는 자리다.

전략은 여전히 덮기 가장 어려워 보이는 아이템, 곧 집합이 지금 가장 작은 아이템에서
분기하는 것이다. 그런데 프로그램 {\tt SSXCC}는 거기서 그 아이템의 옵션을 하나씩
차례로 떠보는 $d$갈래 뻗기를 하지만, 여기서는 그럴 수 없다. 옵션 하나를 떠본
뒤에는 그것을 {\it 치우고\/} 도메인 일관성을 다시 세워야 하고, 그러면 부분 문제가
통째로 달라지므로 방금 가장 어려워 보이던 아이템이 지금 물어야 할 아이템이 아닐
수 있다. 그래서 분기는 이진이다. 가장 좋은 아이템 $p_1$을 골라 그 첫 옵션을
떠보고, 돌아오는 길에 그 옵션을 치우고 도메인을 다시 일관되게 만들고, 새로 가장
좋은 아이템~$p_2$를 골라 {\it 그것의\/} 첫 옵션을 떠보고, 그렇게 일관되면서 비지
않은 도메인이 하나도 남지 않을 때까지 이어 간다.

@ 그 $k$번의 떠보기는 모두 같은 {\it 단계\/}에 속한다. 고른 옵션 $s$개짜리 부분
해를 $s+1$개짜리로 늘리려는 시도들이기 때문이다. 이진 탐색 나무는 그 하나하나를
제 몫의 {\it 층\/}에 적으므로, 한 단계는 층의 토막이고 둘을 헷갈려서는 안 된다.
이 이식판에서 한 단계는 |search| 한 번의 부름이고 그 안의 층들은 그 반복문이
도는 것인데, 형제들은 그냥 되돌기만 하는 자리에 이 |search|는 되돌기 안에 반복문을
둔 까닭이 그것이다. 되짚기는 크누스의 원본이 그랬듯 두 결로 온다. 고른 것이
어긋났으나 고를 것이 더 남았을 때 {\it 단계 안에서\/} 되짚는 것이 반복문의 다음
차례이고, 일관된 것이 하나도 남지 않았을 때 {\it 앞 단계로\/} 되짚는 것이 돌아
나오는 것이다.

@ 고른 것들 $c_1,\ldots,c_s$가 정해졌을 때 아직 살아 있는 아이템을 $I_s$라 하고,
그 가운데 주 아이템을 $P_s$라 하자. 주어진 그대로의 옵션들을 $O_{-1}$이라 하고,
$c_1,\ldots,c_s$와 어울리면서 도메인 일관된 가장 큰 집합을
$O_s\hbox{$^{\rm init}$}$이라 하고, 이 단계가 이미 몇 가지를 살펴 버린 뒤에 거기
남은 것을 $O_s$라 하자. 그러면 탐색은
$$O_{-1}\supseteq O_0^{\rm init}\supseteq O_0\supset O_1^{\rm init}\supseteq
O_1\supset\cdots\supset O_s^{\rm init}\supseteq O_s$$
를 따라 내려가고, 첫 것 말고는 모두 도메인 일관된 집합이다. 되짚을 때 증인 배열을
되돌릴 필요가 없는 까닭이 이 둥지 구조다. 증인은 증인이고, 더 큰 옵션 집합에서
성했던 받침은 더 작은 집합에서도 여전히 성하다. 그러니 여기서 되돌리는 것은 희소
집합의 크기뿐이다.

@ 코드에 앞서 작은 선언이 둘 있다. 아이템마다 배열 |set|의 제 밑자리 바로 아래에
다섯 칸을 맡아 두는데, 크기와 자리와 아이템 번호, 어울림 표시, 그리고 씻기는
동안 맞춰야 할 색이다. 그리고 노드는 \.{dcells.w}가 정해 둔 셋 말고 넷째 필드를
지닌다. 옵션의 수선 목록과 나이를 담는 |xtra|인데, 그래서 이 엔진은 저쪽 노드
타입을 빌리지 않고 제 노드 타입을 따로 선언한다.
@<살림살이@>=
const (
	dcExtra     = 5       // 아이템 밑자리 아래에 맡아 두는 set 칸
	dcIprop     = 5       // 입력 단계의 자리 간격
	infiniteAge = 1 << 29 // 솎인 옵션이 가질 수 없는 나이
	maxStamp    = 1<<31 - 1
)

type dcnode struct {
	itm, loc, clr, xtra int32 // itm과 clr은 입력 뒤 굳고, loc이 춤춘다
}

@ 엔진이 여기 있는데, 이야기되는 차례대로 늘어놓았다.
@<엔진@>=
@<살림살이@>
@<풀이기 상태@>
@<풀이기 짓기@>
@<집합 접근자@>
@<이름 가두기@>
@<춤 띄우기@>
@<탐색@>
@<아이템 고르기@>
@<옵션 들이기@>
@<옵션 솎아 내기@>
@<되돌리기 장치@>
@<해에 들르기@>
@<맥박@>
@<옵션 알리기@>

@* 상태와 짓기.
타입 |XCCDC|의 값 하나가 한 셈의 상태를 통째로 지닌다. 행렬 배열, 이름표, 앞
장의 받침 얼개, 그리고 탐색이 걸어온 길을 적는 배열들이다.
@<풀이기 상태@>=
type XCCDC struct {
	@<풀이기 손잡이@>
	ctx context.Context

	@<행렬 배열@>
	@<이름표@>
	@<받침 얼개@>
	@<되짚기 배열@>
	@<탐색 통계@>
	@<출력 채널@>
}

@ @<행렬 배열@>=
nd       []dcnode
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

@ 창고는 방아쇠 목록과 수선 목록과 큐를 모두 담고, 바구니 배열 둘은 |optOut|이
쓰는 빈터라 그것이 도는 동안 말고는 비어 있다. 도장 셋 가운데 |compatStamp|는
어울림 시험 하나를 다음 것과 갈라 주고, |curStamp|와 |biggestStamp|는 단계에
날짜를 매겨 방아쇠 귀띔이 철 지났는지 알아볼 수 있게 한다.
@<받침 얼개@>=
pool         []twoints // info는 .l, link는 .r. 0번 칸이 빈 목록의 머리다
poolptr      int
qfront       int
qrear        int
trigHead     []int32 // 나이로 찾는 바구니, 목록을 다시 지을 때 쓴다
trigTail     []int32
compatStamp  int
curStamp     int32
biggestStamp int32

@ 되짚기는 두 형제보다 적은 것을 바란다. 되돌리는 것이 크기뿐이기 때문이다.
배열 |chosen|은 단계마다 고른 옵션을 담아 그대로 내놓을 수 있게 하고,
|stageStamp|는 방아쇠 귀띔을 위해 단계에 날짜를 매기며, |curAge|는 탐색이
지금 치우는 옵션이 얼마나 단단히 걸러진 것인지를 |optOut|에게 일러 주는
필드다.
@<되짚기 배열@>=
chosen     []int32
stageStamp []int32
savestack  []twoints
saveptr    int
curAge     int

@ 갓 지은 풀이기에는 파수 값과, 비었으되 nil은 아닌 표들이 있어야 한다. 창고는
맡아 둔 칸 하나와 처음 쓸 수 있는 칸 하나로 시작한다. 따로 이르지 않으면 맥박은
꺼져 있고 문맥은 끊기는 일이 없는 배경 문맥이다. 메서드 |WithContext|는 얕은
복사본을 돌려주어 원본을 그대로 다시 쓸 수 있게 하고, nil 문맥은 그 자리에서
물리친다. 메서드 |Updates|와 |Nodes|와 |Purges|는 채널 |Solutions|를 다 비우고
나면 탐색 통계를 알려 준다.
@<풀이기 짓기@>=
func NewXCCDC() *XCCDC {
	return &XCCDC{
		second:     secondUnset,
		names:      []string{""}, // 아이템 번호는 1부터다
		nameIndex:  make(map[string]int),
		colorNames: []string{""}, // 0번 색은 "색 없음"이다
		colorIndex: make(map[string]int),
		pool:       make([]twoints, 2),
		poolptr:    1,
		ctx:        context.Background(),
	}
}

func (s *XCCDC) WithContext(ctx context.Context) *XCCDC {
	if ctx == nil {
		panic("dcells: nil context")
	}
	c := *s
	c.ctx = ctx
	return &c
}

func (s *XCCDC) Updates() uint64 { return s.updates }
func (s *XCCDC) Nodes() uint64   { return s.nodes }
func (s *XCCDC) Purges() uint64  { return s.purges }

@ 희소 집합 접근자를 살로 빚으면 이렇다. 맡아 둔 칸을 이름으로 읽고 쓰면
``밑자리에서 넷 아래''라는 셈이 알고리즘 밖으로 물러난다. 접근자 |mark|와
|match|는 {\tt SSXCC}에는 쓸 데가 없던 둘이다.
@<집합 접근자@>=
func (s *XCCDC) size(x int) int   { return int(s.set[x-1]) }
func (s *XCCDC) pos(x int) int    { return int(s.set[x-2]) }
func (s *XCCDC) itemNo(x int) int { return int(s.set[x-3]) }
func (s *XCCDC) mark(x int) int   { return int(s.set[x-4]) }
func (s *XCCDC) match(x int) int  { return int(s.set[x-5]) }

func (s *XCCDC) setSize(x, v int)   { s.set[x-1] = int32(v) }
func (s *XCCDC) setPos(x, v int)    { s.set[x-2] = int32(v) }
func (s *XCCDC) setItemNo(x, v int) { s.set[x-3] = int32(v) }
func (s *XCCDC) setMark(x, v int)   { s.set[x-4] = int32(v) }
func (s *XCCDC) setMatch(x, v int)  { s.set[x-5] = int32(v) }

@ 이름을 가두는 일은 처음 온 것을 적어 두고 겹친 것을 물리치는 일이다. 색을
가두는 일은 다시 만나면 있던 번호를 기꺼이 돌려주는데, 여러 옵션이 한 색을 나눠
쓸 수 있기 때문이다. 이것은 다른 두 엔진의 코드를 받는 쪽만 셋째로 바꾸어 그대로
옮긴 것이다. Go에는 메서드 몸통 하나를 세 타입이 곱게 나눠 쓸 방법이 없다.
@<이름 가두기@>=
func (s *XCCDC) internName(name string) (num int, ok bool) {
	if _, dup := s.nameIndex[name]; dup {
		return 0, false
	}
	num = len(s.names)
	s.names = append(s.names, name)
	s.nameIndex[name] = num
	return num, true
}

func (s *XCCDC) internColor(name string) int {
	if id, ok := s.colorIndex[name]; ok {
		return id
	}
	id := len(s.colorNames)
	s.colorNames = append(s.colorNames, name)
	s.colorIndex[name] = id
	return id
}

@* 춤.
메서드 |Dance|는 행렬을 읽고(틀린 입력이면 panic한다) 채널을 열고 탐색을
고루틴으로 띄운다. 곧바로 돌아오고, 고루틴은 일을 마치면 채널 둘을 닫으므로 해를
|range|로 훑는 쪽은 저절로 끝난다. 여기에 |Minimize|는 없다. 분기한정은 다른 두
엔진의 몫이고, 크누스의 원본에는 값이라는 개념이 없다.
@<춤 띄우기@>=
func (s *XCCDC) Dance(rd io.Reader) *Result {
	s.inputMatrix(rd)
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
		@<도메인을 일관되게 만든 다음 춤춘다@>
		@<총계를 알린다@>
	}()

	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}
}

@ 값 |baditem|이 가리키는 것은 옵션이 하나도 없이 입력을 마친 주 아이템인데,
그것이 있으면 문제는 뻔하게 풀리지 않는다. 첫 훑기가 누군가의 도메인을 비워도
마찬가지다. 어느 쪽이든 탐색은 일어나지 않고 채널은 그냥 닫힌다.
@<도메인을 일관되게 만든 다음 춤춘다@>=
if s.baditem == 0 && s.establishDC() {
	@<첫 방아쇠 목록을 추린다@>
	@<첫 가지치기를 알린다@>
	s.search(0)
}

@ 손잡이 |Debug|를 켜면 |dlx| 라이브러리가 찍는 것과 같은 요약 줄로 탐색을
감싸는데, ``solutions''의 단수와 복수를 가리는 잔소리까지 같다. 거기에 제 몫의
한 줄을 더한다. 첫 가지도 뻗기 전에 첫 일관성 훑기가 옵션을 몇 개나 내버렸는가다.
제약이 잘 걸린 문제라면 그 수가 대개 거의 전부다.
@<입력 요약을 알린다@>=
if s.Debug {
	fmt.Fprintf(os.Stderr,
		"(%d options, %d+%d items, %d entries successfully read)\n",
		s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
}

@ @<첫 가지치기를 알린다@>=
if s.Debug {
	fmt.Fprintf(os.Stderr, "Domain consistency purged %d of %d options.\n",
		s.purges, s.options)
}

@ @<총계를 알린다@>=
if s.Debug {
	plural := "s"
	if s.count == 1 {
		plural = ""
	}
	fmt.Fprintf(os.Stderr,
		"Altogether %d solution%s, %d updates, %d nodes, %d purges.\n",
		s.count, plural, s.updates, s.nodes, s.purges)
}

@ 그리고 여기가 탐색이다. 단계마다 부름 한 번, 층마다 반복문 한 바퀴다. 층마다
마디를 하나 세고, 문맥에 그만둘 틈을 주고, 맥박을 내밀고, 어디서 분기할지 고르개에
묻는다. 차수가 |infSize|이면 살아 있는 주 아이템이 하나도 없다는 뜻이고, 곧 부분
해가 해라는 뜻이다. 그렇지 않으면 그 아이템에 살아남은 첫 옵션을 집어 떠본다.

값 |false|를 돌려주는 것은 ``탐색을 통째로 걷어 올려라''는 뜻으로, 부르는 쪽이
떠났거나 문맥을 끊었을 때이며 모든 단계를 거슬러 올라간다. 값 |true|를 돌려주는
것은 ``앞 단계로 물러나라''는 뜻일 뿐이다.
@<탐색@>=
func (s *XCCDC) search(stage int) bool {
	@<단계에 들어선다@>
	mark := s.saveptr
	for {
		s.nodes++
		select {
		case <-s.ctx.Done():
			return false
		default:
		}
		s.tick()

		best, t := s.chooseItem()
		if t == infSize {
			return s.visit(stage)
		}
		opt := int(s.set[best])
		s.chosen = ensure(s.chosen, stage+1)
		s.chosen[stage] = int32(opt)
		if t != 1 {
			s.saveSizes()
		}
		@<옵션 |opt|를 떠보고, 살아남으면 다음 단계로 간다@>
		if t == 1 {
			return true // 고를 것이 없었으니 달리 갈 길도 없다
		}
		@<옵션 |opt|를 치우고 이 단계에 머물거나 되짚는다@>
	}
}

@ 크기는 층마다 한 번, 그것도 고르기가 참된 고르기일 때만 저장한다. 옵션이
하나뿐인 아이템은 돌아올 자리를 남기지 않으므로 강제된 수는 아무것도 저장하지
않은 채 두고, 그 뒤에 오는 층은 다시 들를 일이 없다. 아래에 ``차수 1'' 시험이 두
번 나오는 까닭이 그것이다. 한 번은 저장을 건너뛰려고, 한 번은 다시 떠보기를
건너뛰려고.
@<단계에 들어선다@>=
s.stageStamp = ensure(s.stageStamp, stage+1)
s.trigHead = ensure(s.trigHead, 2*stage+2)
s.trigTail = ensure(s.trigTail, 2*stage+2)
@<지금 도장을 새로 찍는다@>
s.stageStamp[stage] = s.curStamp

@ 옵션을 들이면 그 아이템들이 덮이고 그것과 어울리지 않는 것이 모두 솎인다.
그러고 나서 큐를 비우면 도메인 일관성이 되살아나는데, 그러다 훨씬 많은 것이
솎이기도 한다. 둘 가운데 하나라도 어긋나면 이 가지는 죽었지만, 이 단계에는 아직
다른 길이 있을 수 있다.
@<옵션 |opt|를 떠보고, 살아남으면 다음 단계로 간다@>=
s.curAge = stage + stage + 1
if s.includeOption(opt) && s.emptyQueue() {
	if !s.search(stage + 1) {
		return false
	}
}

@ 돌아와서는---다 훑은 부분 나무에서 왔든 첫발도 떼지 못한 고르기에서 왔든
---크기를 되돌리고 그 옵션을 걸러 낸다. 그것 없이 도메인을 일관되게 만들 수
없다면 이 단계는 끝났으니 물러나고, 그럴 수 있다면 반복문이 한 바퀴 돌아 고르개가
다시 말하는데, 그때 부분 문제는 지난번에 보던 것보다 엄격히 작다.
@<옵션 |opt|를 치우고 이 단계에 머물거나 되짚는다@>=
s.restoreSizes(mark)
s.curAge = stage + stage
if !s.purgeOption(opt, s.active) || !s.emptyQueue() {
	return true
}

@ 어느 아이템에서 분기할 것인가. 옵션이 가장 적은 것이고 비기면 왼쪽인데,
{\tt SSXCC}와 똑같다. 다만 그 엔진의 강제 스택은 없다. 도메인 일관성이 강제된
수를 이미 제 방식으로 처리했기 때문이다. 크기 0은 나올 수 없다. 도메인이 비는
아이템은 고르개에게 묻기 훨씬 전에 가지 전체를 데리고 쓰러진다. 훑기는 크기~1을
만나면 일찍 멎는데, 그것을 이길 것이 없기 때문이다.
@<아이템 고르기@>=
func (s *XCCDC) chooseItem() (best, score int) {
	score = infSize
	for k := 0; score > 1 && k < s.active; k++ {
		x := int(s.item[k])
		if x >= s.second {
			continue // 부 아이템에서는 분기하지 않는다
		}
		switch sz := s.size(x); {
		case sz < score:
			best, score = x, sz
		case sz == score && x < best:
			best = x
		}
	}
	return best, score
}

@* 나이와 귀띔.
어떤 문제에 옵션이 1000개, 아이템이 100개 있다고 하자. 그러면 증인 배열의 칸은
100{,}000개이고 거의 모두가 참된 받침이며, 참된 받침은 저마다 어느 방아쇠 목록의
한 칸이다. 목록은 어마어마하다. 그런데 몇 번 고르고 나면 옵션이 100개, 덮이지 않은
아이템이 30개밖에 남지 않을 수 있으니, 그 칸 가운데 셈에 들 수 있는 것은 많아야
3000개다. 나머지 97{,}000개를 번번이 지나쳐 걸어야 한다면 일관성을 지키는 일은
가망이 없을 것이다. 살 길은 방아쇠 목록을 들여다볼 때마다 마음대로 다시 늘어놓아도
된다는 것, 그리고 그것을 들여다보는 때는 그 옵션이 방금 살아 있지 않게 된 때뿐이라는
것이다.

@ 그래서 물러난 옵션마다 {\it 나이\/}를 찍고, 나이가 그것이 얼마나 단단히
밀려났는지를 말해 준다. 어떤 옵션이 $O_s^{\rm init}$을 떠나되 $O_s$에는 닿지
못했다면---곧 이 단계가 그것을 떠보고 지나갔다면---나이는 $2s$이고, $O_s$를
떠나되 $O_{s+1}^{\rm init}$에는 닿지 못했다면---곧 방금 고른 것과 어울리지
않는다면---나이는 $2s+1$이다. 뒤집으면 시험이 된다. 살아 있지 않은 옵션이
$O_s^{\rm init}$에 드는 것은 나이가 $2s$ 이상일 때와 꼭 같고, $O_s$에 드는 것은
나이가 $2s+1$ 이상일 때와 꼭 같다. 어린 옵션은 적은 가정만으로 일찍 솎인 것들이다.
가장 오래 밖에 머물 것들이고, 목록 맨 아래에 두고 싶은 것이 바로 그들이다. 그래서
|optOut|이 바구니 정렬을 하여 어린 것을 뒤로 보낸다.

@ 정렬만 해서는 여전히 목록 전체를 걸어야 한다. 그래서 |optOut|은 {\it 귀띔\/}도
끼워 넣는다. 옵션 자리에 음수 $-c-1$이 들어앉은 칸은 ``이 아래의 칸은 모두 나이가
$c$보다 어리다''는 말이고, 곧 그 가운데 아직 살아 있을 수 있는 것은 하나도 없다는
말이다. 뒤에 온 이가 그 귀띔을 믿으면 거기서 멈춰도 된다.

믿는 데는 조심이 든다. 귀띔이 적힌 뒤로 탐색 나무가 움직였기 때문이다. 옵션 $o$의
나이가 $2s$라 하자. 그러면 $o$는 $O_s^{\rm init}$에 있고 $O_s$에는 없으며, 단계
$s-1$로 되짚지도 않고 단계~$s$로 새로 들어오지도 않는 동안 $O_s$는 줄어들기만
하므로 $o$는 밖에 머물고 귀띔은 참으로 남는다. 나이가 $2s+1$이라 하자. 그러면
$o$는 $O_s$에 있고 $O_{s+1}^{\rm init}$에는 없으며, 귀띔은 단계 $s+1$에 새로
들어설 때까지 성하다. 두 경우 모두 귀띔에 단계 $\lfloor(c+1)/2\rfloor$의 도장을
찍어 두면 덮이고, 단계마다 들어설 때 새 도장을 받는다. 장치의 전부가 그것이고,
여느 칸이 아이템을 담는 자리에 귀띔은 도장을 담는 까닭도 그것이다.
@<방아쇠 귀띔을 믿거나 버린다@>=
c := -optp - 1
if c < s.curAge && ii == int(s.stageStamp[(c+1)>>1]) {
	hintP, hintQ, cutoff = p, q, c
	break // 이 아래는 모두 살아 있지 않음이 알려져 있다
}
s.putavail(p) // 이 귀띔은 철이 지났다
s.putavail(q)
continue

@ 목록을 다시 짓는 일은 이제 걸음이 닿지 못한 나머지 앞에 바구니를 쌓는 일이다.
비지 않은 바구니마다 제 몫의 새 귀띔을 받되, 지금 나이의 바구니만은 받지 못한다.
바로 이 순간에 솎인 옵션은 아무것에 대해서도 증거가 되지 못하므로 귀띔을 얻을
값이 없다. 살아남은 귀띔이 바구니들이 이미 말하는 것보다 적게 말한다면, 귀띔 둘을
잇달아 두느니 그것을 버린다.
@<바구니에서 옵션 |opt|의 방아쇠 목록을 다시 짓는다@>=
pp = 0
if hintP != 0 {
	pp = hintP
	if tmin <= cutoff {
		pp = int(s.pool[hintQ].r) // 바구니들이 이 귀띔을 품는다
		s.putavail(hintP)
		s.putavail(hintQ)
	}
}
for t := tmin; t < s.curAge; t++ {
	if s.trigHead[t] == 0 {
		continue
	}
	s.pool[int(s.trigTail[t])].r = int32(pp)
	@<바구니 앞에 새 귀띔을 단다@>
	s.trigHead[t] = 0
}
if s.curAge >= 0 && s.trigHead[s.curAge] != 0 {
	s.pool[int(s.trigTail[s.curAge])].r = int32(pp)
	pp = int(s.trigHead[s.curAge])
	s.trigHead[s.curAge] = 0
}
s.setTrigger(opt, pp)

@ 앞 문단에서 |curAge|에 씌운 조건은 첫 훑기를 위한 것이다. 그 훑기는 나이 $-1$로
돌고 어느 바구니에도 아무것도 담지 않는다.
@<바구니 앞에 새 귀띔을 단다@>=
p := s.getavail()
q := s.getavail()
s.pool[p].l = int32(-t - 1)
s.pool[p].r = int32(q)
s.pool[q].l = s.stageStamp[(t+1)>>1]
s.pool[q].r = s.trigHead[t]
pp = p

@ 단계마다 어떤 귀띔이 지니고 있을 수 있는 것보다 큰 도장을 받고, 그 아래 단계들의
도장은 서로 달라야 한다. 아직 쓰이지 않은 귀띔이 그것을 인용할 수 있기 때문이다.
늘기만 하는 계수기가 두 조건을 다 채우고, 정수에 끝이 없다면 영영 채울 것이다.
정수에는 끝이 있으니, 아주 오랜만에 한 번---스무 억 단계에 들어서고 나면---번호를
새로 매겨야 한다. 그 순간 프로그램 안의 모든 귀띔이 참인지 알 수 없게 되므로, 죄다
버리고 지금 열려 있는 단계의 수부터 다시 센다.
@<지금 도장을 새로 찍는다@>=
s.biggestStamp++
if s.biggestStamp == maxStamp {
	@<모든 방아쇠 목록에서 귀띔을 모두 걷어 낸다@>
	for k := 0; k < stage; k++ {
		s.stageStamp[k] = int32(k)
	}
	s.biggestStamp = int32(stage)
}
s.curStamp = s.biggestStamp

@ 귀띔은 칸 둘이고 제 목록의 마지막 칸인 적이 없다. 위의 다시 짓는 코드가 귀띔
뒤에 언제나 그것을 부른 바구니를 두기 때문이다. 그러니 귀띔을 걷어 낸다는 것은 그
아래 칸을 그 자리에 베껴 넣는 일이다.
@<모든 방아쇠 목록에서 귀띔을 모두 걷어 낸다@>=
for k := 0; k < s.lastNode; k += int(s.nd[k].loc) + 1 {
	for p := s.trigger(k); p != 0; p = int(s.pool[p].r) {
		if s.pool[p].l < 0 {
			q := int(s.pool[p].r)
			r := int(s.pool[q].r)
			s.pool[p].l, s.pool[p].r = s.pool[r].l, s.pool[r].r
			s.putavail(q)
			s.putavail(r)
		}
	}
}

@* 분기의 동작.
옵션을 들이는 자리가 덮기가 일어나는 자리다. 먼저 그 옵션의 아이템이 모두 살아
있는 목록을 떠나고, 부 아이템은 저마다 그 옵션이 주는 색을 기억해 둔다. 그런 다음
그 아이템을 차례로 돌며 더는 쓸 수 없게 된 옵션을 솎아 낸다. 주 아이템이면 그것을
담은 다른 옵션이 모두 그렇고, 색이 붙은 부 아이템이면 뜻이 다른 옵션이 모두
그러한데, 씻어 내기와 덮기는 같은 훑기를 두 각도에서 본 것이다. 그 옵션이 색을
주지 않은 부 아이템은 주 아이템처럼 그대로 덮인다.
@<옵션 들이기@>=
func (s *XCCDC) includeOption(node int) bool {
	opt := s.optionOf(node)
	@<옵션 |opt|의 아이템을 모두 물리며 그 색을 적어 둔다@>
	for k := s.active; k < s.oactive; k++ {
		x := int(s.item[k])
		end := x + s.size(x) - 1
		if x >= s.second && s.match(x) != 0 {
			@<아이템 |x|를 씻어 내며 뜻이 다른 옵션을 솎아 낸다@>
		} else {
			@<아이템 |x|를 덮으며 옵션 |opt| 말고는 다 솎아 낸다@>
		}
	}
	@<옵션 |opt| 자신을 물린다@>
	return true
}

@ 이 자리에서 옵션 |opt|의 아이템이 살아 있지 않다는 것은 앞선 단계에서 씻긴 부
아이템이라는 말과 꼭 같다. 나머지는 모두 지금 물러난다. 물러나는 아이템들은
|item[active..oactive)|라는 덩이를 이루고, 아래 반복문들은 바로 그 덩이를 걷는다.
@<옵션 |opt|의 아이템을 모두 물리며 그 색을 적어 둔다@>=
p := s.active
s.oactive = s.active
for q := opt + 1; s.nd[q].itm > 0; q++ {
	c := int(s.nd[q].itm)
	pp := s.pos(c)
	if pp < p {
		p--
		cc := int(s.item[p])
		s.item[p], s.item[pp] = int32(c), int32(cc)
		if c >= s.second {
			s.setMatch(c, int(s.nd[q].clr))
		}
		s.setPos(cc, pp)
		s.setPos(c, p)
		s.updates++
	}
}
s.active = p

@ 두 반복문 모두 오른쪽에서 왼쪽으로 도는데, 솎이는 옵션이 떠나면서 집합의
오른쪽 끝, 곧 줄어든 크기가 방금 비워 준 자리로 맞바뀌기 때문이다. 반대로 걸으면
살아남은 것들을 밟게 된다.
@<아이템 |x|를 씻어 내며 뜻이 다른 옵션을 솎아 낸다@>=
c := s.match(x)
for ; end >= x; end-- {
	optp := int(s.set[end])
	if int(s.nd[optp].clr) != c && !s.purgeOption(optp, s.oactive) {
		return false
	}
}

@ @<아이템 |x|를 덮으며 옵션 |opt| 말고는 다 솎아 낸다@>=
for ; end >= x; end-- {
	optp := s.optionOf(int(s.set[end]))
	if optp != opt && !s.optOut(optp, s.oactive) {
		return false
	}
}

@ 여기 하나는 {\tt SSXCC}에 짝이 없다. 고른 옵션 자신도 살아 있지 않게 되고, 그
옵션이 덮는 주 아이템들은 크기 1의 도메인이 아니라 {\it 빈\/} 도메인을 남긴 채
남는다. 이것을 |optOut|을 불러서 이루려 든다면 아주 잘못이다. 그 메서드는 바로
그것을 물리치려고 있기 때문이다. 옵션이 바닥난 주 아이템은 거기서는 재앙이고
여기서는 경사다. 그래서 곧이곧대로 말한다. 옵션 |opt|의 방아쇠 목록에는 아무 일도
일어날 필요가 없다. 살아 있지 않은 주 아이템에 걸친 살아 있는 옵션은 없기 때문이다.
@<옵션 |opt| 자신을 물린다@>=
for k := s.active; k < s.oactive; k++ {
	x := int(s.item[k])
	if x < s.second {
		s.setSize(x, 0)
	}
}
s.setAge(opt, s.curAge)

@ 탐색도 위의 씻어 내기 반복문도 옵션을 그 안의 노드로 부르므로, 둘 다
|purgeOption|을 거친다. 사이막은 |itm|이 양수가 아닌데, 메서드 |optionOf|가
거슬러 찾아가는 것이 그것이다.
@<옵션 솎아 내기@>=
func (s *XCCDC) purgeOption(node, act int) bool {
	return s.optOut(s.optionOf(node), act)
}

func (s *XCCDC) optionOf(node int) int {
	for node--; s.nd[node].itm > 0; node-- {
	}
	return node
}

@ 끝으로 되짚기인데, Solnon의 재주 그 이상도 이하도 아니다. 분기하기 전에 살아
있는 아이템의 {\it 크기\/}를 한 번에 저장해 두었다가, 끝나면 그대로 도로 박는다.
자리와 집합의 내용은 손볼 것이 없고---맞바꿈은 어느 집합이든 제 자신의 순열로
남겨 두었고, 되돌린 크기는 바로 그만큼의 칸을 다시 들인다---증인 배열도 그러한데,
이 장 머리의 둥지 논증이 보인 바다. 단계가 기억해 둘 것은 제가 열릴 때의 스택
포인터뿐이므로, 메서드 |restoreSizes|는 거기까지의 거리에서 살아 있는 아이템의
수를 되찾을 수 있다.
@^Solnon, Christine@>
@<되돌리기 장치@>=
func (s *XCCDC) saveSizes() {
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
	for p := 0; p < s.active; p++ {
		x := int(s.item[p])
		s.savestack[s.saveptr+p] = twoints{int32(x), int32(s.size(x))}
	}
	s.saveptr += s.active
}

func (s *XCCDC) restoreSizes(mark int) {
	s.active = s.saveptr - mark
	s.saveptr = mark
	for p := 0; p < s.active; p++ {
		e := s.savestack[mark+p]
		s.setSize(int(e.l), int(e.r))
	}
}

@* 알리기.
해에 닿으면 스택 |chosen|에서 그것을 빚어---단계마다 옵션 하나씩---채널로
내려보낸다. 보내는 일이 발을 맞추는 자리다. 받는 쪽이 훑기를 버렸거나 문맥이
끊겼으면 select의 다른 팔이 당겨지고 탐색은 통째로 걷힌다.
@<해에 들르기@>=
func (s *XCCDC) visit(stage int) bool {
	s.count++
	sol := make([]Option, stage)
	for k := 0; k < stage; k++ {
		sol[k] = s.option(int(s.chosen[k]))
	}
	select {
	case <-s.ctx.Done():
		return false
	case s.solStream <- sol:
		return true
	}
}

@ 맥박은 철저히 되면 좋고 아니면 마는 것이다. 박동이 울렸으면 진행 상황 한 줄을
내밀되, 받으려고 기다리는 이가 없으면 버리고 춤을 이어 간다. 탐색의 어느 대목도
맥박 때문에 멈춰 서지 않는다.
@<맥박@>=
func (s *XCCDC) tick() {
	if s.pulse == nil {
		return
	}
	select {
	case <-s.pulse.C:
		select {
		case s.heartbeat <- fmt.Sprintf("%d nodes, %d solutions, %d purges so far",
			s.nodes, s.count, s.purges):
		default:
		}
	default:
	}
}

@ 탐색은 고른 옵션을 그 안의 노드로만 알고 있다. 그 옵션을 알리려면 첫 노드까지
거슬러 갔다가 앞으로 걸으며 아이템마다 이름을 대고 색이 있으면 붙인다. 다른 두
엔진과 다른 데가 하나 있어 적어 둔다. 이 엔진은 옵션마다 주 아이템으로 시작할
것을 고집하고 그렇지 않으면 입력 때 노드를 옮겨 놓으므로, 부 아이템으로 글이
시작하던 옵션은 그 첫 주 아이템이 앞에 나온 채로 알려진다. 그 첫 아이템 뒤로는
적힌 차례를 지킨다.
@<옵션 알리기@>=
func (s *XCCDC) option(p int) Option {
	for s.nd[p-1].itm > 0 {
		p-- // 옵션의 첫 노드로 간다
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

@** DLX 입력 읽기.
형식 {\tt DLX}---아이템 줄 하나, 그다음 옵션마다 한 줄---는 \.{dcells.w}에
적혀 있고, 이 단계가 기대는 작은 훑개도 거기 있다. 함수 |nextLine|과 |token|과
|skipSpace|, 그리고 부르는 쪽이 애초에 쓰지 말았어야 할 틀린 입력을 알리는
|failf|다. 여기 남는 것은 {\it 이\/} 엔진의 배열을 아는 몫이다. 읽기는 두
걸음이다. 아이템 줄을 읽고, 옵션을 읽는다. 그런 다음 춤이 기다리는 희소 집합을
깔아 두는 {\it 마무리\/}가 따른다.
@<입력 단계@>=
func (s *XCCDC) inputMatrix(rd io.Reader) {
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
func (s *XCCDC) readItemNames(br *bufio.Reader) {
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
시작된다.
@<옵션 읽기@>=
func (s *XCCDC) readOptions(br *bufio.Reader) {
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

@ 옵션 하나를 읽는 일은 이름과, 있다면 색을 훑는 반복문이다. 주 아이템을 하나도
대지 않은 옵션은 고를 수가 없으므로---그것을 맡겨 봐야 덮이는 것이 없다---말없이
노드 하나하나까지 되감는다. 크누스의 풀이기들은 여기서 경고를 찍지만 우리는 그냥
버린다. 참된 옵션은 사이막 노드로 봉해 토막이 갈린 채로 있게 한다.
@<옵션 읽기@>=
func (s *XCCDC) readOption(buf []byte) {
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

@ 이름 뒤에 쌍점을 두고 색이 올 수 있는데, 부 아이템에만 그렇다. 메서드
|createNode|가 노드를 끝이 아닌 다른 자리에 둘 수 있으므로 제가 쓴 자리를
돌려주고, 색은 그리로 간다.
@<아이템 이름 하나와 그 색을 훑는다@>=
name, next := token(buf, p, true)
if name == "" {
	failf("empty item name")
}
m, known := s.nameIndex[name]
if !known {
	failf("unknown item name: %s", name)
}
at := s.createNode(m, spacer, &hasPrimary)
if buf[next] == ':' {
	if m < s.second {
		failf("primary item must be uncolored: %s", name)
	}
	color, ce := token(buf, next+1, false)
	if color == "" {
		failf("missing color after %s:", name)
	}
	s.nd[at].clr = int32(s.internColor(color))
	next = ce
}
p = skipSpace(buf, next)

@ 되감기는 짓다 만 노드를 하나씩 물리고 입력 단계의 자리에서 그 몫을 도로
거둔다. 주 아이템이 없는 옵션의 노드는 모두 |lastNode|보다 한 칸 뒤에 앉아
있는데, 아래의 옮겨 놓기가 그들을 거기에 두었기 때문이다.
@<옵션을 되감는다@>=
for s.lastNode > spacer {
	slot := int(s.nd[s.lastNode+1].itm) * dcIprop
	s.setSize(slot, s.size(slot)-1)
	s.setPos(slot, spacer-1)
	s.lastNode--
}

@ 입력이 도는 동안 배열 |set|은 성긴 |dcIprop| 간격으로 쓰이는데, 아이템마다
맡아 둘 칸이 들어갈 만큼이다. 메서드 |createNode|는 거기에 아이템 |m|의 노드를
하나 더 세고, 한 옵션 안에서 같은 아이템이 되풀이되면 그 아이템을 마지막으로 본
자리가 이미 이 옵션 안이라는 것으로 알아챈다.

옵션마다 주 아이템이 앞에 서도록 보장하는 옮겨 놓기도 여기 있다. 주 아이템을
아직 보지 못한 동안에는 노드를 한 칸 앞질러 써서 첫 칸을 비워 두고, 처음 닿은 주
아이템이 그 칸을 차지하며, 그 뒤로는 여느 때처럼 쓴다. 이 재주에 아이템마다 견줌
한 번이 들고, 그 값으로 방아쇠 목록이 기대는 값싼 ``이 옵션이 아직 살아 있는가''
시험을 얻는다.
@<옵션 읽기@>=
func (s *XCCDC) createNode(m, spacer int, hasPrimary *bool) int {
	slot := m * dcIprop
	s.set = ensure(s.set, slot)
	if s.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", s.names[m])
	}
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+2)
	at := s.lastNode
	if !*hasPrimary {
		if m < s.second {
			at, *hasPrimary = spacer+1, true
		} else {
			at = s.lastNode + 1
		}
	}
	t := s.size(slot)
	s.nd[at].itm = int32(m)
	s.nd[at].loc = int32(t)
	s.nd[at].clr = 0
	s.setSize(slot, t+1)
	s.setPos(slot, s.lastNode)
	return at
}

@ 마무리는 성긴 입력 셈을 춤이 쓸 참된 배치로 바꾸는데, 자료를 세 번 훑는다.
@<입력 마무리@>=
func (s *XCCDC) finalize() {
	@<set 배열을 깐다@>
	@<아이템 머리를 채운다@>
	@<노드가 가리키는 곳을 고친다@>
}

@ 첫 훑기는 아이템마다 배열 |set| 안의 촘촘한 밑자리를 내주고---그 아래에
|dcExtra|칸을 맡겨 둔 채---주와 부의 경계를 그 좌표로 옮긴다. 아이템 줄에
\.{\|}가 없는 문제에는 부 아이템이 없고, |second|는 배열 |set|에서 쓰인 몫 바로
뒤에 내려앉는다.
@<set 배열을 깐다@>=
s.active, s.itemlen = s.lastItm-1, s.lastItm-1
s.item = ensure(s.item, s.itemlen)
s.set = ensure(s.set, s.itemlen*dcIprop+1) // 입력 자리를 모두 읽을 수 있게

j := dcExtra
k := 0
for ; k < s.itemlen; k++ {
	s.item[k] = int32(j)
	j += dcExtra + s.size((k+1)*dcIprop)
}
s.setlen = j - dcExtra
s.set = ensure(s.set, j+1)
if s.second == secondUnset {
	s.osecond, s.second = s.active, j
} else {
	s.osecond = s.second - 1
}

@ 둘째 훑기는 거꾸로 돌아 입력 셈을 그 자리가 덮이기 전에 읽어 내며, 아이템마다
크기와 자리와 번호를 채우고 어울림 표시를 지우며, 옵션 하나 없이 끝난 주 아이템이
있으면 |baditem|으로 표시한다.
@<아이템 머리를 채운다@>=
for ; k != 0; k-- {
	base := int(s.item[k-1])
	if k == s.second {
		s.second = base
	}
	s.setSize(base, s.size(k*dcIprop))
	if s.size(base) == 0 && k <= s.osecond {
		s.baditem = k
	}
	s.setPos(base, k-1)
	s.setItemNo(base, k)
	s.setMark(base, 0)
}

@ 셋째 훑기는 노드마다 |itm|과 |loc|을 아이템 번호와 아이템별 셈에서 참된 |set|
색인으로 고쳐 쓰고, 노드를 제자리에 떨어뜨린다. 이것이 끝나면 희소 집합은 춤출
채비가 된 것이다.
@<노드가 가리키는 곳을 고친다@>=
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

@** 테스트.
문학적 프로그램이라면 제가 살아 있다는 증거를 스스로 지니는 것이 옳다. 이 마지막
부분은 같은 원본에서 짜이되 {\it 따로\/} 선 파일 \.{xccdc\_test.go}로 tangle되는데,
주된 출력이 아니라 곁딸린 출력의 이름을 대는 \.{GWEB}의 파일 출력 제어 코드를 쓴
덕이다.

도우미는 해의 무리를 표준 모양으로 빚는다. 옵션 안의 아이템 이름을 정렬하고,
해 안의 옵션을 정렬하고, 끝으로 해들 자체를 정렬한다. 옵션 안의 이름을 정렬하는
일은 다른 두 엔진에서보다 여기서 더 중한데, 이 엔진은 옵션의 첫 주 아이템을 제
차례가 아닌 자리에 알릴 수 있기 때문이다. 정렬해 두면 아래의 견줌이 그것에
아랑곳하지 않는다.
@(xccdc_test.go@>=
package dcells

import (
	"fmt"
	"slices"
	"sort"
	"strings"
	"testing"
)

func canonDC(res *Result) []string {
	var sols []string
	for sol := range res.Solutions {
		opts := make([]string, len(sol))
		for i, opt := range sol {
			names := append([]string(nil), opt...)
			sort.Strings(names)
			opts[i] = strings.Join(names, " ")
		}
		sort.Strings(opts)
		sols = append(sols, strings.Join(opts, " | "))
	}
	sort.Strings(sols)
	return sols
}

func danceDC(input string) []string {
	return canonDC(NewXCCDC().Dance(strings.NewReader(input)))
}

@ 가장 수수한 테스트는 교과서의 그것이다. {\sl TAOCP\/} 7.2.2.1에 나오는 크누스의
옵션 여섯 개짜리 예인데, 그 유일한 정확 덮개가 $\{a\,d\,f\}$, $\{b\,g\}$,
$\{c\,e\}$이다. 나머지 둘은 색 기계를 살피고, 덮일 수 없는 아이템이 있으면 해가
아예 없음을 확인한다. 마지막 것은 탐색에 닿지도 못하는데, 첫 일관성 훑기가
도메인을 비우기 때문이다.
@(xccdc_test.go@>=
func TestDCExactCover(t *testing.T) {
	input := "a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n"
	sols := danceDC(input)
	if len(sols) != 1 {
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
	}
	if want := "a d f | b g | c e"; sols[0] != want {
		t.Errorf("got %q, want %q", sols[0], want)
	}
}

func TestDCColors(t *testing.T) {
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
	if sols := danceDC(input); len(sols) != 2 {
		t.Fatalf("want 2 solutions, got %d: %v", len(sols), sols)
	}
}

func TestDCNoSolution(t *testing.T) {
	if sols := danceDC("a b c\na b\n"); len(sols) != 0 {
		t.Errorf("want 0 solutions, got %d", len(sols))
	}
}

@ 부 아이템으로 시작하는 옵션은 주 아이템을 앞에 세우는 옮겨 놓기를 부려 본다.
덮개 둘을 여전히 다 찾아야 하고, 알려지는 옵션마다 색 없는 주 아이템이 머리에
와야 한다. 그것이 방아쇠 목록이 기대는 불변식이고, 그것이 눈에 보이는 여기서
살핀다.
@(xccdc_test.go@>=
func TestDCSecondaryFirst(t *testing.T) {
	input := "a b | x y\nx:A y:B a\ny:B b\nx:A b\n"
	n := 0
	for sol := range NewXCCDC().Dance(strings.NewReader(input)).Solutions {
		n++
		for _, opt := range sol {
			if strings.ContainsRune(opt[0], ':') {
				t.Errorf("option %v does not lead with a primary item", opt)
			}
		}
	}
	if n != 2 {
		t.Errorf("want 2 solutions, got %d", n)
	}
}

@ 정확 덮개 풀이기를 참으로 시험하는 것은 다른 풀이기와 뜻이 맞는지다. 아래
문제는 저마다 두 엔진을 다 거치고, 표준 모양으로 빚은 해의 무리가 꼭 같아야
한다. 수만 같아서는 안 된다. 마지막 둘에는 색이 붙은 부 아이템이 있는데,
어울림 시험이 제값을 하는 자리가 거기다.
@(xccdc_test.go@>=
func TestDCAgreesWithXCC(t *testing.T) {
	inputs := []string{
		"a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n",
		"a b c\na b c\na b\nc\na\nb c\n",
		"p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n",
		"a b | x y\nx:A y:B a\ny:B b\nx:A b\n",
		queensDC(6),
		queensDC(7),
		langfordDC(4),
		langfordDC(5),
	}
	for i, in := range inputs {
		want := canonDC(NewXCC().Dance(strings.NewReader(in)))
		got := canonDC(NewXCCDC().Dance(strings.NewReader(in)))
		if !slices.Equal(want, got) {
			t.Errorf("problem %d: XCC found %d covers, XCCDC found %d",
				i, len(want), len(got))
		}
	}
}

@ 문제를 지어내는 함수 둘인데, 이 글의 테스트가 홀로 서도록 여기에 두었다.
차수 $n$의 퀸 판은 행과 열을 주 아이템으로, 두 대각선 무리를 부 아이템으로
삼는다. 랭포드 짝은 수 $1,\ldots,n$을 두 번씩 놓되 $k$의 두 벌이 $k+1$만큼
떨어지게 하는 것으로, $n\bmod4$가 0이나~3일 때 해가 있다.
@(xccdc_test.go@>=
func queensDC(n int) string {
	var b strings.Builder
	for i := 0; i < n; i++ {
		fmt.Fprintf(&b, "r%02d ", i)
	}
	for j := 0; j < n; j++ {
		fmt.Fprintf(&b, "c%02d ", j)
	}
	b.WriteString("|")
	for k := 0; k < 2*n-1; k++ {
		fmt.Fprintf(&b, " a%02d b%02d", k, k)
	}
	b.WriteString("\n")
	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			fmt.Fprintf(&b, "r%02d c%02d a%02d b%02d\n", i, j, i+j, i-j+n-1)
		}
	}
	return b.String()
}

func langfordDC(n int) string {
	var b strings.Builder
	for k := 1; k <= n; k++ {
		fmt.Fprintf(&b, "d%d ", k)
	}
	for i := 0; i < 2*n; i++ {
		fmt.Fprintf(&b, "s%02d ", i)
	}
	b.WriteString("\n")
	for k := 1; k <= n; k++ {
		for i := 0; i+k+1 < 2*n; i++ {
			fmt.Fprintf(&b, "d%d s%02d s%02d\n", k, i, i+k+1)
		}
	}
	return b.String()
}

@ 끝으로 누구나 아는 수들이다. 차수 $n=6$, 7, 8의 퀸 문제에 해가 4개, 40개,
92개다. 이 테스트는 두 엔진이 그것을 얻는 데 무엇을 치렀는지도 적어 두는데, 이
프로그램이 있는 까닭이 온통 거기에 있다. 마디 수가 눈여겨볼 칸이고, 솎은 수는
그것을 얻는 데 얼마나 멀리 내다보아야 했는지를 말해 준다.
@(xccdc_test.go@>=
func TestDCQueens(t *testing.T) {
	for n, want := range map[int]int{6: 4, 7: 40, 8: 92} {
		in := queensDC(n)
		dc := NewXCCDC()
		got := 0
		for range dc.Dance(strings.NewReader(in)).Solutions {
			got++
		}
		if got != want {
			t.Errorf("%d-queens: got %d solutions, want %d", n, got, want)
		}
		x := NewXCC()
		for range x.Dance(strings.NewReader(in)).Solutions {
		}
		t.Logf("%d-queens: XCCDC %d nodes, %d updates, %d purges;"+
			" XCC %d nodes, %d updates",
			n, dc.Nodes(), dc.Updates(), dc.Purges(), x.Nodes(), x.Updates())
	}
}

@** 색인.
