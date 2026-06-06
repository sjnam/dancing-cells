package dcells

import (
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
	// "a" must be covered exactly twice (2|a); the only cover is {ab, ac}.
	input := `2|a b c
a b
a c
b c
`
	if n := countMCC(t, input); n != 1 {
		t.Errorf("exact-twice: got %d solutions, want 1", n)
	}
}

func TestMCCSlack(t *testing.T) {
	// "a" covered 1..2 times; b, c exactly once. One cover: {ab, ac}.
	input := `1:2|a b c
a b
a c
b c
`
	if n := countMCC(t, input); n != 1 {
		t.Errorf("slack: got %d solutions, want 1", n)
	}
}

func TestMCCRicher(t *testing.T) {
	// Cross-checked against cmd/ssmcc: 4 solutions.
	input := `1:3|a 2|b c d
a b
a c
a d
b c
b d
c d
a b c
`
	if n := countMCC(t, input); n != 4 {
		t.Errorf("richer: got %d solutions, want 4", n)
	}
}

func TestMCCPlainXCC(t *testing.T) {
	// With default multiplicities the MCC engine solves ordinary XCC. 8-queens
	// has 92 solutions.
	n := 8
	var b strings.Builder
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
	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			b.WriteString(itoa("r", i))
			b.WriteString(itoa("c", j))
			b.WriteString(itoa("a", i+j))
			b.WriteString(itoa("b", i-j+n-1))
			b.WriteString("\n")
		}
	}
	if got := countMCC(t, b.String()); got != 92 {
		t.Errorf("8-queens via MCC: got %d, want 92", got)
	}
}

func TestMCCColors(t *testing.T) {
	input := `p q r | x y
p q x:A y:B
p r x:A y:A
p x:B
q x:A
r y:B
`
	if n := countMCC(t, input); n != 2 {
		t.Errorf("colors: got %d solutions, want 2", n)
	}
}
