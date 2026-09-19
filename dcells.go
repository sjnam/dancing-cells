// Package dcells solves exact cover (XCC, MCC) with dancing cells.
//
//line dcells.w:79
//line dcells.w:80
package dcells

import (
	"bufio"
	"fmt"
)

//line dcells.w:134
const (
	infSize     = 1 << 30        // "no item to branch on" => a solution
	secondUnset = 1 << 30        // sentinel for "no primary/secondary boundary yet"
	infCost     = int64(1) << 62 // "no cover found yet"
)

//line dcells.w:147
type node struct {
	itm, loc, clr int32 // itm and clr are fixed after input; loc dances
}

//line dcells.w:160
type Option []string

type Result struct {
	Solutions <-chan []Option
	Heartbeat <-chan string
}

//line dcells.w:183
type Frame struct{ v frameView }

func (f Frame) Live(yield func(item, opt int) bool) { f.v.eachLive(yield) }

//line dcells.w:186
func (f Frame) Cost(opt int) int { return f.v.optionCost(opt) }

//line dcells.w:187
func (f Frame) Name(item int) string { return f.v.itemName(item) }

//line dcells.w:188
func (f Frame) Need(item int) int { return f.v.itemNeed(item) }

//line dcells.w:195
type frameView interface {
	eachLive(yield func(item, opt int) bool)
	optionCost(opt int) int
	itemName(item int) string
	itemNeed(item int) int
}

//line dcells.w:208
type pricedOpt struct {
	node int32 // the option's first node
	net  int64 // its price less the tax it pays
}

//line dcells.w:218
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

//line dcells.w:258
type parseError struct{ msg string }

func (e *parseError) Error() string { return e.msg }

func failf(format string, a ...any) {
	panic(&parseError{fmt.Sprintf(format, a...)})
}

//line dcells.w:271
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

//line dcells.w:289
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
