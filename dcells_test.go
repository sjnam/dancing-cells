//line dcells.w:1905
package dcells

//line dcells.w:1907
import (
//line dcells.w:1908
	"sort"
//line dcells.w:1909
	"strings"
//line dcells.w:1910
	"testing"
//line dcells.w:1911
)

//line dcells.w:1913
func collect(t *testing.T, input string) []string {
//line dcells.w:1914
	t.Helper()
//line dcells.w:1915
	res := NewXCC().Dance(strings.NewReader(input))
//line dcells.w:1916
	var sols []string
//line dcells.w:1917
	for sol := range res.Solutions {
//line dcells.w:1918
		opts := make([]string, len(sol))
//line dcells.w:1919
		for i, opt := range sol {
//line dcells.w:1920
			opts[i] = strings.Join(opt, " ")
//line dcells.w:1921
		}
//line dcells.w:1922
		sort.Strings(opts)
//line dcells.w:1923
		sols = append(sols, strings.Join(opts, " | "))
//line dcells.w:1924
	}
//line dcells.w:1925
	sort.Strings(sols)
//line dcells.w:1926
	return sols
//line dcells.w:1927
}

//line dcells.w:1934
func TestExactCover(t *testing.T) {
//line dcells.w:1935
	// The classic TAOCP 7.2.2.1 example: unique cover {a d f},{b g},{c e}.
//line dcells.w:1936
	input := "a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n"
//line dcells.w:1937
	sols := collect(t, input)
//line dcells.w:1938
	if len(sols) != 1 {
//line dcells.w:1939
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
//line dcells.w:1940
	}
//line dcells.w:1941
	want := "a d f | b g | c e"
//line dcells.w:1942
	if sols[0] != want {
//line dcells.w:1943
		t.Errorf("got %q, want %q", sols[0], want)
//line dcells.w:1944
	}
//line dcells.w:1945
}

//line dcells.w:1947
func TestColors(t *testing.T) {
//line dcells.w:1948
	// Secondary items x,y with colors; two exact covers.
//line dcells.w:1949
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
//line dcells.w:1950
	sols := collect(t, input)
//line dcells.w:1951
	if len(sols) != 2 {
//line dcells.w:1952
		t.Fatalf("want 2 solutions, got %d: %v", len(sols), sols)
//line dcells.w:1953
	}
//line dcells.w:1954
}

//line dcells.w:1956
func TestNoSolution(t *testing.T) {
//line dcells.w:1957
	// Item c can never be covered.
//line dcells.w:1958
	input := "a b c\na b\n"
//line dcells.w:1959
	res := NewXCC().Dance(strings.NewReader(input))
//line dcells.w:1960
	n := 0
//line dcells.w:1961
	for range res.Solutions {
//line dcells.w:1962
		n++
//line dcells.w:1963
	}
//line dcells.w:1964
	if n != 0 {
//line dcells.w:1965
		t.Errorf("want 0 solutions, got %d", n)
//line dcells.w:1966
	}
//line dcells.w:1967
}

//line dcells.w:1973
func TestMultiCharColorAndLongNames(t *testing.T) {
//line dcells.w:1974
	input := "house1 house2 | nationality\nhouse1 nationality:England\nhouse2 nationality:England\n"
//line dcells.w:1975
	sols := collect(t, input)
//line dcells.w:1976
	if len(sols) != 1 {
//line dcells.w:1977
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
//line dcells.w:1978
	}
//line dcells.w:1979
	// Each option keeps its color name in the output.
//line dcells.w:1980
	if !strings.Contains(sols[0], "nationality:England") {
//line dcells.w:1981
		t.Errorf("color name lost: %q", sols[0])
//line dcells.w:1982
	}
//line dcells.w:1983
}

//line dcells.w:1991
func nQueensCount(t *testing.T, n int) int {
//line dcells.w:1992
	t.Helper()
//line dcells.w:1993
	var b strings.Builder
//line dcells.w:1994
	for i := 0; i < n; i++ {
//line dcells.w:1995
		b.WriteString(itoa("r", i))
//line dcells.w:1996
	}
//line dcells.w:1997
	for j := 0; j < n; j++ {
//line dcells.w:1998
		b.WriteString(itoa("c", j))
//line dcells.w:1999
	}
//line dcells.w:2000
	b.WriteString("|")
//line dcells.w:2001
	for k := 0; k < 2*n-1; k++ {
//line dcells.w:2002
		b.WriteString(itoa(" a", k))
//line dcells.w:2003
	}
//line dcells.w:2004
	for k := 0; k < 2*n-1; k++ {
//line dcells.w:2005
		b.WriteString(itoa(" b", k))
//line dcells.w:2006
	}
//line dcells.w:2007
	b.WriteString("\n")
//line dcells.w:2008
	for i := 0; i < n; i++ {
//line dcells.w:2009
		for j := 0; j < n; j++ {
//line dcells.w:2010
			b.WriteString(itoa("r", i))
//line dcells.w:2011
			b.WriteString(itoa("c", j))
//line dcells.w:2012
			b.WriteString(itoa("a", i+j))
//line dcells.w:2013
			b.WriteString(itoa("b", i-j+n-1))
//line dcells.w:2014
			b.WriteString("\n")
//line dcells.w:2015
		}
//line dcells.w:2016
	}
//line dcells.w:2017
	res := NewXCC().Dance(strings.NewReader(b.String()))
//line dcells.w:2018
	n2 := 0
//line dcells.w:2019
	for range res.Solutions {
//line dcells.w:2020
		n2++
//line dcells.w:2021
	}
//line dcells.w:2022
	return n2
//line dcells.w:2023
}

//line dcells.w:2025
func itoa(prefix string, x int) string {
//line dcells.w:2026
	return prefix + string(rune('0'+x/10)) + string(rune('0'+x%10)) + " "
//line dcells.w:2027
}

//line dcells.w:2029
func TestQueens(t *testing.T) {
//line dcells.w:2030
	// Known n-queens solution counts.
//line dcells.w:2031
	for n, want := range map[int]int{6: 4, 7: 40, 8: 92} {
//line dcells.w:2032
		if got := nQueensCount(t, n); got != want {
//line dcells.w:2033
			t.Errorf("%d-queens: got %d, want %d", n, got, want)
//line dcells.w:2034
		}
//line dcells.w:2035
	}
//line dcells.w:2036
}

//line dcells.w:2043
func countMCC(t *testing.T, input string) int {
//line dcells.w:2044
	t.Helper()
//line dcells.w:2045
	res := NewMCC().Dance(strings.NewReader(input))
//line dcells.w:2046
	n := 0
//line dcells.w:2047
	for range res.Solutions {
//line dcells.w:2048
		n++
//line dcells.w:2049
	}
//line dcells.w:2050
	return n
//line dcells.w:2051
}

//line dcells.w:2053
func TestMCCMultiplicity(t *testing.T) {
//line dcells.w:2054
	// "a" must be covered exactly twice (2|a); the only cover is {ab, ac}.
//line dcells.w:2055
	input := "2|a b c\na b\na c\nb c\n"
//line dcells.w:2056
	if n := countMCC(t, input); n != 1 {
//line dcells.w:2057
		t.Errorf("exact-twice: got %d solutions, want 1", n)
//line dcells.w:2058
	}
//line dcells.w:2059
}

//line dcells.w:2061
func TestMCCSlack(t *testing.T) {
//line dcells.w:2062
	// "a" covered 1..2 times; b, c exactly once. One cover: {ab, ac}.
//line dcells.w:2063
	input := "1:2|a b c\na b\na c\nb c\n"
//line dcells.w:2064
	if n := countMCC(t, input); n != 1 {
//line dcells.w:2065
		t.Errorf("slack: got %d solutions, want 1", n)
//line dcells.w:2066
	}
//line dcells.w:2067
}

//line dcells.w:2069
func TestMCCRicher(t *testing.T) {
//line dcells.w:2070
	// Cross-checked against cmd/ssmcc: 4 solutions.
//line dcells.w:2071
	input := "1:3|a 2|b c d\na b\na c\na d\nb c\nb d\nc d\na b c\n"
//line dcells.w:2072
	if n := countMCC(t, input); n != 4 {
//line dcells.w:2073
		t.Errorf("richer: got %d solutions, want 4", n)
//line dcells.w:2074
	}
//line dcells.w:2075
}

//line dcells.w:2081
func TestMCCPlainXCC(t *testing.T) {
//line dcells.w:2082
	n := 8
//line dcells.w:2083
	var b strings.Builder
//line dcells.w:2084
	for i := 0; i < n; i++ {
//line dcells.w:2085
		b.WriteString(itoa("r", i))
//line dcells.w:2086
	}
//line dcells.w:2087
	for j := 0; j < n; j++ {
//line dcells.w:2088
		b.WriteString(itoa("c", j))
//line dcells.w:2089
	}
//line dcells.w:2090
	b.WriteString("|")
//line dcells.w:2091
	for k := 0; k < 2*n-1; k++ {
//line dcells.w:2092
		b.WriteString(itoa(" a", k))
//line dcells.w:2093
	}
//line dcells.w:2094
	for k := 0; k < 2*n-1; k++ {
//line dcells.w:2095
		b.WriteString(itoa(" b", k))
//line dcells.w:2096
	}
//line dcells.w:2097
	b.WriteString("\n")
//line dcells.w:2098
	for i := 0; i < n; i++ {
//line dcells.w:2099
		for j := 0; j < n; j++ {
//line dcells.w:2100
			b.WriteString(itoa("r", i))
//line dcells.w:2101
			b.WriteString(itoa("c", j))
//line dcells.w:2102
			b.WriteString(itoa("a", i+j))
//line dcells.w:2103
			b.WriteString(itoa("b", i-j+n-1))
//line dcells.w:2104
			b.WriteString("\n")
//line dcells.w:2105
		}
//line dcells.w:2106
	}
//line dcells.w:2107
	if got := countMCC(t, b.String()); got != 92 {
//line dcells.w:2108
		t.Errorf("8-queens via MCC: got %d, want 92", got)
//line dcells.w:2109
	}
//line dcells.w:2110
}

//line dcells.w:2112
func TestMCCColors(t *testing.T) {
//line dcells.w:2113
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
//line dcells.w:2114
	if n := countMCC(t, input); n != 2 {
//line dcells.w:2115
		t.Errorf("colors: got %d solutions, want 2", n)
//line dcells.w:2116
	}
//line dcells.w:2117
}
