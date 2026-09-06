\input kotexgweb

\def\title{스도쿠 무리 풀기}

@s Option int
@s Reader int
@s Buffer int
@s Context int
@s Duration int
@s Time int
@s In int
@s Out int
@s result int

@* 들어가며.
스도쿠를 정확한 덮개로 옮기는 것은 이 분야의 고전이다. $9\times9$ 판에 1부터
9까지를 채우되 가로줄, 세로줄, $3\times3$ 상자마다 아홉 수가 한 번씩 나와야
한다는 규칙은, 그대로 네 갈래의 ``정확히 한 번''이 된다.
\smallskip\item{$\bullet$} \.{p\it jk\/}: 칸 $(j,k)$에 수가 하나 놓인다.
\smallskip\item{$\bullet$} \.{r\it jd\/}: $j$번째 가로줄에 수 $d$가 한 번 놓인다.
\smallskip\item{$\bullet$} \.{c\it kd\/}: $k$번째 세로줄에 수 $d$가 한 번 놓인다.
\smallskip\item{$\bullet$} \.{b\it xd\/}: $x$번째 상자에 수 $d$가 한 번 놓인다.
\smallskip\noindent
옵션 하나는 ``칸 $(j,k)$에 수 $d$를 놓는다''는 뜻으로 이 넷을 하나씩 품는다.
부 항목도 색도 없다. 스도쿠는 맨몸의 정확한 덮개다.

@ 다만 여기에는 한 가지 손질을 더한다. 이미 채워진 칸이 만드는 항목은 아예
적지 않는다. 문제에 5가 박혀 있는 칸은 더 채울 것이 없고, 그 줄과 그 상자에서
5는 이미 쓰였다. 그러니 항목 줄에 넣을 것은 {\it 아직 빈\/} 칸과 {\it 아직 안
쓰인\/} 수뿐이고, 옵션도 그것들만 짝지어 만든다. 단서가 서른 개쯤 되는 흔한
문제라면 항목이 324개에서 200개 남짓으로, 옵션은 729개에서 200개 안팎으로 준다.
탐색을 시작하기도 전에 문제의 절반이 사라지는 셈이다.

@ 이 예제가 다른 것들과 다른 점은 푸는 대상이 하나가 아니라는 것이다. 스도쿠
문제집은 한 줄에 한 문제씩 수천 개가 들어 있고, 문제들은 서로 아무 상관이 없다.
|cells.NewXCC()|가 만드는 풀개는 저마다 제 상태만 들고 있으므로 여러 개를 동시에
돌려도 서로 건드리지 않는다. 그러니 CPU 수만큼 한꺼번에 풀되, 찍어 내는 차례는
입력 차례를 지켜야 한다. 그 두 가지를 함께 해내는 것이 아래의
{\it 차례 지키는 부채꼴 모으기\/}다.

@ 뼈대는 이렇다. 문제를 한 줄씩 읽어 채널에 흘리고, 여럿을 한꺼번에 풀고,
돌아온 것을 차례대로 찍는다.
@c
package main

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"runtime"
	"runtime/debug"
	"time"

	cells "github.com/sjnam/dancing-cells"
)

@<자료형@>
@<함수들@>

func main() {
	@<쓰레기 수거를 늦춘다@>
	@<문제 파일을 연다@>
	@<문제를 한 줄씩 흘려보낸다@>
	@<푼 것을 차례대로 찍는다@>
}

@ 문제마다 풀개를 새로 만드니 할당이 잦다. 힙이 더 자란 뒤에 수거하도록 해
두면 수거에 드는 품이 눈에 띄게 준다.
@<쓰레기 수거를 늦춘다@>=
debug.SetGCPercent(400)

@ @<문제 파일을 연다@>=
if len(os.Args) != 2 {
	log.Fatalf("usage: %s puzzles-file", os.Args[0])
}
f, err := os.Open(os.Args[1])
if err != nil {
	log.Fatal(err)
}
defer f.Close()

start := time.Now()

@ 한 줄이 한 문제다. 앞의 81글자만 쓰고 나머지는 버린다---문제집에 등급이나
이름이 뒤에 붙어 있는 일이 흔하기 때문이다. 빈칸은 `\.{.}'이든 `\.{0}'이든
1--9가 아니면 다 빈칸으로 친다.
@<문제를 한 줄씩 흘려보낸다@>=
lines := make(chan []byte, 256)
go func() {
	defer close(lines)
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		if line := sc.Bytes(); len(line) >= 81 {
			lines <- append([]byte(nil), line[:81]...)
		}
	}
}()

@ @<푼 것을 차례대로 찍는다@>=
out := bufio.NewWriter(os.Stdout)
defer out.Flush()
i := 0
for r := range orderedMap(lines, runtime.NumCPU(), solve) {
	i++
	fmt.Fprintf(out, "Q[%5d]: %s\n", i, r.q)
	if r.a != nil {
		fmt.Fprintf(out, "A[%5d]: %s\n", i, r.a)
	} else {
		fmt.Fprintf(out, "A[%5d]: (no solution)\n", i)
	}
}
out.Flush()
fmt.Printf("Solving took: %v\n", time.Since(start))

@* 문제 하나를 덮개로.
먼저 문제를 훑어 이미 채워진 것을 표 넷에 적어 둔다. |pos[j][k]|가 0이 아니면
그 칸은 이미 찼다는 뜻이고, |row[j][d]|가 0이 아니면 $j$번째 줄에서 수 $d$가
이미 쓰였다는 뜻이다. 적어 두는 값은 무엇이든 상관없으므로 나중에 눈으로
좇기 좋도록 자리 번호에 1을 더한 것을 넣는다.
@<빈칸과 안 쓰인 수를 적어 둔다@>=
var pos, row, col, box [9][9]int
for i, j := 0, 0; i < 81; i, j = i+9, j+1 {
	for k := range 9 {
		if ch := line[i+k]; ch >= '1' && ch <= '9' {
			d := int(ch - '1')
			x := j/3*3 + k/3
			pos[j][k], row[j][d], col[k][d], box[x][d] = d+1, k+1, j+1, j+1
		}
	}
}

@ 문제 글은 파이프가 아니라 메모리 버퍼에 짓는다. 문제 하나가 작고 수천 개를
연달아 풀 것이므로, 짓는 쪽과 읽는 쪽이 고루틴을 오가며 주고받는 값이 여기서는
품에 견주어 남는 것이 없다.
@<덮개 문제 글을 짓는다@>=
var b bytes.Buffer
b.Grow(8192)
@<아직 안 덮인 항목만 적는다@>
@<놓을 수 있는 자리마다 옵션을 적는다@>

@ 네 갈래를 차례로 적는다. 칸은 이름이 \.{p\it jk\/}이고, 나머지 셋은 갈래
글자에 줄 번호와 수를 붙인다.
@<아직 안 덮인 항목만 적는다@>=
for j := range 9 {
	for k := range 9 {
		if pos[j][k] == 0 {
			fmt.Fprintf(&b, "p%d%d ", j, k)
		}
	}
}
for _, t := range []struct {
	c string
	a *[9][9]int
}{{"r", &row}, {"c", &col}, {"b", &box}} {
	for j := range 9 {
		for k := range 9 {
			if t.a[j][k] == 0 {
				fmt.Fprintf(&b, "%s%d%d ", t.c, j, k+1)
			}
		}
	}
}
b.WriteByte('\n')

@ 옵션은 ``빈칸에, 그 줄에도 그 칸에도 그 상자에도 아직 없는 수를'' 놓는 경우
하나하나다. 네 조건을 한 줄로 물어보면 그만이다.
@<놓을 수 있는 자리마다 옵션을 적는다@>=
for j := range 9 {
	for k := range 9 {
		for d := range 9 {
			x := j/3*3 + k/3
			if pos[j][k] == 0 && row[j][d] == 0 && col[k][d] == 0 && box[x][d] == 0 {
				fmt.Fprintf(&b, "p%d%d r%d%d c%d%d b%d%d\n", j, k, j, d+1, k, d+1, x, d+1)
			}
		}
	}
}

@* 한 판 풀기.
문제 하나와 그 답을 함께 들고 다니는 그릇이다. 답이 |nil|이면 풀리지 않은
문제다.
@<자료형@>=
type result struct{ q, a []byte }

@ 잘 만든 스도쿠는 답이 하나뿐이므로 첫 덮개만 받으면 된다. 받자마자 문맥을
끊고 채널을 마저 비워 주는데, 그래야 아직 춤추고 있는 고루틴이 보내려다 막힌
자리에서 풀려나 끝난다. 이 뒷정리를 빠뜨리면 문제 수천 개를 푸는 동안 고루틴이
그만큼 쌓인다.
@<함수들@>=
func solve(line []byte) result {
	ans := append([]byte(nil), line...)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	res := cells.NewXCC().WithContext(ctx).Dance(sudokuInput(line))
	sol, ok := <-res.Solutions
	if !ok {
		return result{line, nil} // 답이 없다
	}
	@<덮개를 읽어 답을 채운다@>
	cancel()
	for range res.Solutions { // 풀개가 끝날 수 있도록 비워 준다
	}
	return result{line, ans}
}

@ 옵션은 \.{p\it jk\/}로 시작하고 그다음이 \.{r\it jd\/}이므로, 첫 이름에서 칸을
읽고 둘째 이름의 끝 글자에서 수를 읽으면 된다.
@<덮개를 읽어 답을 채운다@>=
for _, opt := range sol {
	j, k := opt[0][1]-'0', opt[0][2]-'0'
	ans[int(j)*9+int(k)] = opt[1][2]
}

@ 문제 글을 짓는 일은 |solve|가 부르는 곳이 한 군데뿐이지만, 만들어 낸 것을
|Dance|에 곧바로 넘겨야 하니 함수로 둔다.
@<함수들@>=
func sudokuInput(line []byte) io.Reader {
	@<빈칸과 안 쓰인 수를 적어 둔다@>
	@<덮개 문제 글을 짓는다@>
	return bytes.NewReader(b.Bytes())
}

@* 차례를 지키는 부채꼴 모으기.
문제 여럿을 한꺼번에 풀면서 답은 입력 차례로 내놓아야 한다. 흔히 쓰는 수는
답에 번호를 달아 두었다가 나중에 정렬하는 것인데, 여기서는 그럴 것 없이
{\it 약속\/}을 줄 세운다. 일감마다 결과가 하나 들어갈 채널을 미리 만들어
그 채널을 차례대로 늘어놓고, 일은 아무 차례로나 끝나게 둔다. 읽는 쪽은 늘어선
채널을 차례로 기다리기만 하면 저절로 입력 차례가 된다.

한꺼번에 도는 일감은 |n|개로 묶되, 늘어세우는 자리는 그보다 훨씬 넉넉하게
$64n$개를 둔다. 그래야 어쩌다 오래 걸리는 문제 하나가 맨 앞에 있어도 뒤의
일꾼들이 놀지 않는다.
@<함수들@>=
func orderedMap[In, Out any](in <-chan In, n int, work func(In) Out) <-chan Out {
	window := 64 * n
	futures := make(chan chan Out, window)
	@<일감을 띄우며 약속을 줄 세운다@>
	@<줄 선 차례대로 거두어 내보낸다@>
	return out
}

@ 세마포가 한꺼번에 도는 수를 |n|으로 묶는다. 자리를 얻은 다음에야 채널을
만들어 줄에 세우므로, 줄에 선 것은 이미 돌고 있거나 곧 돌 일감이다.
@<일감을 띄우며 약속을 줄 세운다@>=
go func() {
	defer close(futures)
	sem := make(chan struct{}, n)
	for v := range in {
		sem <- struct{}{}
		ch := make(chan Out, 1)
		futures <- ch
		go func(v In, ch chan Out) {
			ch <- work(v)
			<-sem
		}(v, ch)
	}
}()

@ @<줄 선 차례대로 거두어 내보낸다@>=
out := make(chan Out)
go func() {
	defer close(out)
	for ch := range futures {
		out <- <-ch
	}
}()

@* 색인.
