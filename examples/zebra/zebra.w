\input kotexgweb

\def\title{얼룩말 퍼즐}

@s Option int
@s Reader int

@* 들어가며.
색깔이 다른 집 다섯 채가 한 줄로 늘어서 있고, 국적도 직업도 애완동물도 즐겨
마시는 것도 다 다른 다섯 사람이 산다. 여기에 단서 열넷이 주어진다. 영국 사람은
빨간 집에 산다, 화가는 일본에서 왔다, 노르웨이 사람은 맨 왼쪽 집에 산다,
$\ldots$ 그리고 물음은 둘이다.
$$\hbox{\it 얼룩말을 기르는 사람은 누구이고, 맹물을 마시는 사람은 누구인가?}$$
1962년 {\sl Life International\/}에 실린 이 퍼즐은 흔히 아인슈타인이 지었다거나
루이스 캐럴이 지었다고 이야기되지만 둘 다 근거가 없다. 이름은 마지막 물음에서
왔다.

@ 이 퍼즐이 이 저장소에 있는 까닭은 {\it 색\/} 때문이다. 앞의 예제들은 색을 쓰지
않았다. 왕비도 펜토미노도 랭퍼드도 ``이 자리를 누가 차지하는가''를 묻는 문제라
항목을 덮느냐 마느냐로 끝난다. 얼룩말 퍼즐은 그렇지 않다. 여기서 묻는 것은
``집 3의 국적은 무엇인가''처럼 {\it 값\/}이고, 단서 여럿이 같은 칸을 두고 저마다
한마디씩 한다. 그러면서 서로 어긋나지 않아야 한다.

색이 있는 정확한 덮개는 바로 그것을 말하는 물건이다. 부 항목은 여러 옵션이
함께 덮어도 되지만 {\bf 색이 같아야만\/} 된다. 그러니 부 항목을 ``빈칸''으로,
색을 ``그 칸에 적힌 값''으로 삼으면, 단서 둘이 같은 칸을 말할 때 저절로 합의를
요구하게 된다.

@ 항목은 두 갈래다.

{\it 주 항목\/}은 단서다. \.{\#1}부터 \.{\#16}까지 열여섯 개이고, 저마다 정확히
한 번 덮여야 한다. 단서 하나를 덮는 옵션들은 그 단서가 참이 되는 여러 경우이니,
``정확히 한 번''은 곧 ``이 단서를 이런 식으로 만족시킨다''를 하나 고르라는 뜻이다.

{\it 부 항목\/}은 빈칸이다. 집이 다섯이고 물어볼 것이 다섯 가지이니 스물다섯
개다. 국적 \.{N0}$\ldots$\.{N4}, 직업 \.{J0}$\ldots$\.{J4}, 애완동물
\.{P0}$\ldots$\.{P4}, 음료 \.{D0}$\ldots$\.{D4}, 집 색 \.{C0}$\ldots$\.{C4}.
뒤의 숫자가 집 번호다. 값은 색으로 적는다---\.{N0:England}는 ``집 0의 국적은
영국''이라는 뜻이다.

@ 이 옮김에서 눈여겨볼 것이 하나 있다. 다섯 국적이 {\it 서로 다르다\/}는 말을
어디에도 적지 않았다. 색은 같은 칸을 두고 다투는 것만 막을 뿐, 두 칸이 같은
값을 갖는 것은 막지 않는다. 그런데도 답이 하나로 떨어진다. 단서 열여섯이
서로 맞물려 그만큼을 이미 못박기 때문이다. 적어도 되는 것을 적지 않고 문제를
푸는 것도 모형을 짓는 재주의 하나다.

@ 뼈대는 짧다. 문제 글을 짓고, 풀고, 답을 표로 읽어 준다.
@c
package main

import (
	"fmt"
	"strings"

	cells "github.com/sjnam/dancing-cells"
)

func main() {
	@<덮개 문제 글을 짓는다@>
	@<풀어서 표를 채운다@>
	@<표를 찍는다@>
}

@ 항목 줄이 먼저다. 단서 열여섯을 적고 `\.{\char"7C}'를 그은 다음 빈칸 스물다섯을
적는다. 한 줄이 길어 세 도막으로 나누어 적었을 뿐, 이어 붙이면 한 줄이다.
@<덮개 문제 글을 짓는다@>=
input := "|Zebra Puzzle\n" +
	"#1 #2 #3 #4 #5 #6 #7 #8 #9 #10 #11 #12 #13 #14 #15 #16" +
	" | N0 N1 N2 N3 N4 J0 J1 J2 J3 J4" +
	" P0 P1 P2 P3 P4 D0 D1 D2 D3 D4 C0 C1 C2 C3 C4\n"

@ 첫 넷은 가장 단순한 꼴이다. ``$A$인 사람은 $B$다''는 어느 집인지를 모르므로
집 다섯 곳마다 옵션 하나씩, 모두 다섯 개가 된다. 이를테면 첫 단서는 집 $i$에
대해 \.{\#1 N\it i\tt:England C\it i\tt:red}가 되어, 그 집의 국적 칸과 색 칸에
동시에 값을 박는다. 두 칸을 한 옵션이 함께 물고 있는 것이 요점이다---색이 하나만
맞아서는 안 된다.
@<덮개 문제 글을 짓는다@>=
input += `|The Englishman lives in a red house.
#1 N0:England C0:red
#1 N1:England C1:red
#1 N2:England C2:red
#1 N3:England C3:red
#1 N4:England C4:red
|The painter comes from Japan.
#2 N0:Japan J0:painter
#2 N1:Japan J1:painter
#2 N2:Japan J2:painter
#2 N3:Japan J3:painter
#2 N4:Japan J4:painter
|The yellow house hosts a diplomat.
#3 J0:diplomat C0:yellow
#3 J1:diplomat C1:yellow
#3 J2:diplomat C2:yellow
#3 J3:diplomat C3:yellow
#3 J4:diplomat C4:yellow
|The coffee-lover's house is green.
#4 D0:coffee C0:green
#4 D1:coffee C1:green
#4 D2:coffee C2:green
#4 D3:coffee C3:green
#4 D4:coffee C4:green
`

@ 다음 넷에는 다른 꼴이 섞인다. \.{\#5}와 \.{\#7}은 집을 대놓고 가리키므로
옵션이 {\it 하나\/}뿐이다. 옵션이 하나인 항목은 엔진이 곧바로 강제 수로 처리하니,
이런 단서가 몇 개만 있어도 탐색이 크게 줄어든다.
@<덮개 문제 글을 짓는다@>=
input += `|The Norwegian's house is the leftmost.
#5 N0:Norway
|The dog's owner is from Spain.
#6 N0:Spain P0:dog
#6 N1:Spain P1:dog
#6 N2:Spain P2:dog
#6 N3:Spain P3:dog
#6 N4:Spain P4:dog
|The milk drinker lives in the middle house.
#7 D2:milk
|The violinist drinks orange juice.
#8 J0:violinist D0:orange
#8 J1:violinist D1:orange
#8 J2:violinist D2:orange
#8 J3:violinist D3:orange
#8 J4:violinist D4:orange
`

@ \.{\#9}와 \.{\#11}은 {\it 이웃\/}을 말한다. ``흰 집은 초록 집 바로 왼쪽''은
방향이 정해져 있으므로 옵션이 넷이다. 그러나 ``노르웨이 사람은 파란 집 옆에
산다''는 어느 쪽 옆인지 말하지 않으므로, 왼쪽인 경우 넷과 오른쪽인 경우 넷을
모두 적어 여덟이 된다. 방향이 없는 단서는 옵션이 두 배로 늘어난다.
@<덮개 문제 글을 짓는다@>=
input += `|The white house is just left of the green one.
#9 C0:white C1:green
#9 C1:white C2:green
#9 C2:white C3:green
#9 C3:white C4:green
|The Ukrainian drinks tea.
#10 N0:Ukraine D0:tea
#10 N1:Ukraine D1:tea
#10 N2:Ukraine D2:tea
#10 N3:Ukraine D3:tea
#10 N4:Ukraine D4:tea
|The Norwegian lives next to the blue house.
#11 N0:Norway C1:blue
#11 N1:Norway C2:blue
#11 N2:Norway C3:blue
#11 N3:Norway C4:blue
#11 C0:blue N1:Norway
#11 C1:blue N2:Norway
#11 C2:blue N3:Norway
#11 C3:blue N4:Norway
`

@ \.{\#13}과 \.{\#14}도 방향 없는 이웃 단서라 여덟씩이다.
@<덮개 문제 글을 짓는다@>=
input += `|The sculptor breeds snails.
#12 J0:sculptor P0:snail
#12 J1:sculptor P1:snail
#12 J2:sculptor P2:snail
#12 J3:sculptor P3:snail
#12 J4:sculptor P4:snail
|The horse lives next to the diplomat.
#13 J0:diplomat P1:horse
#13 J1:diplomat P2:horse
#13 J2:diplomat P3:horse
#13 J3:diplomat P4:horse
#13 P0:horse J1:diplomat
#13 P1:horse J2:diplomat
#13 P2:horse J3:diplomat
#13 P3:horse J4:diplomat
|The nurse lives next to the fox.
#14 J0:nurse P1:fox
#14 J1:nurse P2:fox
#14 J2:nurse P3:fox
#14 J3:nurse P4:fox
#14 P0:fox J1:nurse
#14 P1:fox J2:nurse
#14 P2:fox J3:nurse
#14 P3:fox J4:nurse
`

@ 마지막 둘은 단서가 아니라 {\it 물음\/}이다. ``누군가는 얼룩말을 기른다''와
``누군가는 맹물을 마신다''를 단서처럼 적어 넣지 않으면, 얼룩말과 물은 어느 칸에도
나타나지 않아 답에서 빠져 버린다. 아무 집이나 될 수 있으니 옵션은 다섯씩이다.
물음을 제약으로 바꾸어 넣는 이 수법은 퍼즐을 덮개로 옮길 때 두고두고 쓰인다.
@<덮개 문제 글을 짓는다@>=
input += `|Somebody trains a zebra.
#15 P0:zebra
#15 P1:zebra
#15 P2:zebra
#15 P3:zebra
#15 P4:zebra
|Somebody prefers to drink just plain water
#16 D0:water
#16 D1:water
#16 D2:water
#16 D3:water
#16 D4:water
`

@ 답은 덮개 하나다. 옵션의 첫 이름은 단서 번호이므로 건너뛰고, 나머지
\.{N0:Norway} 꼴을 갈라 표에 적어 넣는다. 앞 글자가 어느 표인지를, 뒤 숫자가
집 번호를 말해 준다.
@<풀어서 표를 채운다@>=
res := cells.NewXCC().Dance(strings.NewReader(input))

answer := map[byte][]string{
	'N': make([]string, 5),
	'J': make([]string, 5),
	'P': make([]string, 5),
	'D': make([]string, 5),
	'C': make([]string, 5),
}

for _, opt := range <-res.Solutions {
	for _, nd := range opt[1:] {
		kv := strings.Split(nd, ":")
		answer[kv[0][0]][kv[0][1]-'0'] = kv[1]
	}
}

@ 찍는 차례는 국적, 직업, 애완동물, 음료, 집 색으로 못박는다. 맵을 그냥 훑으면
Go가 차례를 뒤섞으므로 돌릴 때마다 줄 차례가 달라진다.
@<표를 찍는다@>=
for _, k := range []byte{'N', 'J', 'P', 'D', 'C'} {
	for _, l := range answer[k] {
		fmt.Printf("%-12s", l)
	}
	fmt.Println()
}

@* 색인.
