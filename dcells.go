// dcells 패키지는 춤추는 칸으로 정확 덮개(XCC, MCC, XCCDC)를 푼다.
//
//line dcells.w:86
//line dcells.w:87
package dcells

import (
	"bufio"
	"fmt"
)

//line dcells.w:139
const (
	infSize     = 1 << 30        // "분기할 아이템이 없다" 곧 해를 찾았다
	secondUnset = 1 << 30        // "주/부 아이템의 경계가 아직 없다"는 파수꾼
	infCost     = int64(1) << 62 // "아직 덮개를 하나도 못 찾았다"
)

//line dcells.w:152
type node struct {
	itm, loc, clr int32 // itm과 clr은 입력 뒤에 굳고, loc은 춤춘다
}

//line dcells.w:164
type Option []string

type Result struct {
	Solutions <-chan []Option
	Heartbeat <-chan string
}

//line dcells.w:186
type Frame struct{ v frameView }

func (f Frame) Live(yield func(item, opt int) bool) { f.v.eachLive(yield) }

//line dcells.w:189
func (f Frame) Cost(opt int) int { return f.v.optionCost(opt) }

//line dcells.w:190
func (f Frame) Name(item int) string { return f.v.itemName(item) }

//line dcells.w:191
func (f Frame) Need(item int) int { return f.v.itemNeed(item) }

//line dcells.w:197
type frameView interface {
	eachLive(yield func(item, opt int) bool)
	optionCost(opt int) int
	itemName(item int) string
	itemNeed(item int) int
}

//line dcells.w:210
type pricedOpt struct {
	node int32 // 옵션의 첫 노드
	net  int64 // 값에서 그 옵션이 무는 세금을 뺀 것
}

//line dcells.w:220
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

//line dcells.w:257
type parseError struct{ msg string }

func (e *parseError) Error() string { return e.msg }

func failf(format string, a ...any) {
	panic(&parseError{fmt.Sprintf(format, a...)})
}

//line dcells.w:270
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

//line dcells.w:287
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
