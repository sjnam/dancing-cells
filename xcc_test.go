package dcells

import (
	"sort"
	"strings"
	"testing"
)

// collect runs the solver on the given input and returns each solution as a
// sorted, joined string, plus the whole set sorted, for stable comparison.
func collect(t *testing.T, input string) []string {
	t.Helper()
	res := NewDancer().Dance(strings.NewReader(input))
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

func TestExactCover(t *testing.T) {
	// The classic TAOCP 7.2.2.1 example: unique cover {a d f},{b g},{c e}.
	input := `a b c d e f g
c e
a d g
b c f
a d f
b g
d e g
`
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
	// Secondary items x,y with colors; two exact covers.
	input := `p q r | x y
p q x:A y:B
p r x:A y:A
p x:B
q x:A
r y:B
`
	sols := collect(t, input)
	if len(sols) != 2 {
		t.Fatalf("want 2 solutions, got %d: %v", len(sols), sols)
	}
}

func TestMultiCharColorAndLongNames(t *testing.T) {
	// Arbitrary-length item names and multi-character color names (as the
	// zebra/wordsearch examples need).
	input := `house1 house2 | nationality
house1 nationality:England
house2 nationality:England
`
	sols := collect(t, input)
	if len(sols) != 1 {
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
	}
	// Each option keeps its color name in the output.
	if !strings.Contains(sols[0], "nationality:England") {
		t.Errorf("color name lost: %q", sols[0])
	}
}

func TestNoSolution(t *testing.T) {
	// Item c can never be covered.
	input := `a b c
a b
`
	res := NewDancer().Dance(strings.NewReader(input))
	n := 0
	for range res.Solutions {
		n++
	}
	if n != 0 {
		t.Errorf("want 0 solutions, got %d", n)
	}
}

// nQueens returns solution count for the n-queens problem encoded as XCC.
func nQueensCount(t *testing.T, n int) int {
	t.Helper()
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
	res := NewDancer().Dance(strings.NewReader(b.String()))
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
	// Known n-queens solution counts.
	for n, want := range map[int]int{6: 4, 7: 40, 8: 92} {
		if got := nQueensCount(t, n); got != want {
			t.Errorf("%d-queens: got %d, want %d", n, got, want)
		}
	}
}
