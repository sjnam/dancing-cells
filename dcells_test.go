//line dcells.w:1726
package dcells

//line dcells.w:1728
import (
//line dcells.w:1729
	"sort"
//line dcells.w:1730
	"strings"
//line dcells.w:1731
	"testing"
//line dcells.w:1732
)

//line dcells.w:1734
func collect(t *testing.T, input string) []string {
//line dcells.w:1735
	t.Helper()
//line dcells.w:1736
	res := NewXCC().Dance(strings.NewReader(input))
//line dcells.w:1737
	var sols []string
//line dcells.w:1738
	for sol := range res.Solutions {
//line dcells.w:1739
		opts := make([]string, len(sol))
//line dcells.w:1740
		for i, opt := range sol {
//line dcells.w:1741
			opts[i] = strings.Join(opt, " ")
//line dcells.w:1742
		}
//line dcells.w:1743
		sort.Strings(opts)
//line dcells.w:1744
		sols = append(sols, strings.Join(opts, " | "))
//line dcells.w:1745
	}
//line dcells.w:1746
	sort.Strings(sols)
//line dcells.w:1747
	return sols
//line dcells.w:1748
}

//line dcells.w:1755
func TestExactCover(t *testing.T) {
//line dcells.w:1756
	// The classic TAOCP 7.2.2.1 example: unique cover {a d f},{b g},{c e}.
//line dcells.w:1757
	input := "a b c d e f g\nc e\na d g\nb c f\na d f\nb g\nd e g\n"
//line dcells.w:1758
	sols := collect(t, input)
//line dcells.w:1759
	if len(sols) != 1 {
//line dcells.w:1760
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
//line dcells.w:1761
	}
//line dcells.w:1762
	want := "a d f | b g | c e"
//line dcells.w:1763
	if sols[0] != want {
//line dcells.w:1764
		t.Errorf("got %q, want %q", sols[0], want)
//line dcells.w:1765
	}
//line dcells.w:1766
}

//line dcells.w:1768
func TestColors(t *testing.T) {
//line dcells.w:1769
	// Secondary items x,y with colors; two exact covers.
//line dcells.w:1770
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
//line dcells.w:1771
	sols := collect(t, input)
//line dcells.w:1772
	if len(sols) != 2 {
//line dcells.w:1773
		t.Fatalf("want 2 solutions, got %d: %v", len(sols), sols)
//line dcells.w:1774
	}
//line dcells.w:1775
}

//line dcells.w:1781
func TestMultiCharColorAndLongNames(t *testing.T) {
//line dcells.w:1782
	input := "house1 house2 | nationality\nhouse1 nationality:England\nhouse2 nationality:England\n"
//line dcells.w:1783
	sols := collect(t, input)
//line dcells.w:1784
	if len(sols) != 1 {
//line dcells.w:1785
		t.Fatalf("want 1 solution, got %d: %v", len(sols), sols)
//line dcells.w:1786
	}
//line dcells.w:1787
	// Each option keeps its color name in the output.
//line dcells.w:1788
	if !strings.Contains(sols[0], "nationality:England") {
//line dcells.w:1789
		t.Errorf("color name lost: %q", sols[0])
//line dcells.w:1790
	}
//line dcells.w:1791
}

//line dcells.w:1793
func TestNoSolution(t *testing.T) {
//line dcells.w:1794
	// Item c can never be covered.
//line dcells.w:1795
	input := "a b c\na b\n"
//line dcells.w:1796
	res := NewXCC().Dance(strings.NewReader(input))
//line dcells.w:1797
	n := 0
//line dcells.w:1798
	for range res.Solutions {
//line dcells.w:1799
		n++
//line dcells.w:1800
	}
//line dcells.w:1801
	if n != 0 {
//line dcells.w:1802
		t.Errorf("want 0 solutions, got %d", n)
//line dcells.w:1803
	}
//line dcells.w:1804
}

//line dcells.w:1811
func nQueensCount(t *testing.T, n int) int {
//line dcells.w:1812
	t.Helper()
//line dcells.w:1813
	var b strings.Builder
//line dcells.w:1814
	for i := 0; i < n; i++ {
//line dcells.w:1815
		b.WriteString(itoa("r", i))
//line dcells.w:1816
	}
//line dcells.w:1817
	for j := 0; j < n; j++ {
//line dcells.w:1818
		b.WriteString(itoa("c", j))
//line dcells.w:1819
	}
//line dcells.w:1820
	b.WriteString("|")
//line dcells.w:1821
	for k := 0; k < 2*n-1; k++ {
//line dcells.w:1822
		b.WriteString(itoa(" a", k))
//line dcells.w:1823
	}
//line dcells.w:1824
	for k := 0; k < 2*n-1; k++ {
//line dcells.w:1825
		b.WriteString(itoa(" b", k))
//line dcells.w:1826
	}
//line dcells.w:1827
	b.WriteString("\n")
//line dcells.w:1828
	for i := 0; i < n; i++ {
//line dcells.w:1829
		for j := 0; j < n; j++ {
//line dcells.w:1830
			b.WriteString(itoa("r", i))
//line dcells.w:1831
			b.WriteString(itoa("c", j))
//line dcells.w:1832
			b.WriteString(itoa("a", i+j))
//line dcells.w:1833
			b.WriteString(itoa("b", i-j+n-1))
//line dcells.w:1834
			b.WriteString("\n")
//line dcells.w:1835
		}
//line dcells.w:1836
	}
//line dcells.w:1837
	res := NewXCC().Dance(strings.NewReader(b.String()))
//line dcells.w:1838
	n2 := 0
//line dcells.w:1839
	for range res.Solutions {
//line dcells.w:1840
		n2++
//line dcells.w:1841
	}
//line dcells.w:1842
	return n2
//line dcells.w:1843
}

//line dcells.w:1845
func itoa(prefix string, x int) string {
//line dcells.w:1846
	return prefix + string(rune('0'+x/10)) + string(rune('0'+x%10)) + " "
//line dcells.w:1847
}

//line dcells.w:1849
func TestQueens(t *testing.T) {
//line dcells.w:1850
	// Known n-queens solution counts.
//line dcells.w:1851
	for n, want := range map[int]int{6: 4, 7: 40, 8: 92} {
//line dcells.w:1852
		if got := nQueensCount(t, n); got != want {
//line dcells.w:1853
			t.Errorf("%d-queens: got %d, want %d", n, got, want)
//line dcells.w:1854
		}
//line dcells.w:1855
	}
//line dcells.w:1856
}

//line dcells.w:1864
func countMCC(t *testing.T, input string) int {
//line dcells.w:1865
	t.Helper()
//line dcells.w:1866
	res := NewMCC().Dance(strings.NewReader(input))
//line dcells.w:1867
	n := 0
//line dcells.w:1868
	for range res.Solutions {
//line dcells.w:1869
		n++
//line dcells.w:1870
	}
//line dcells.w:1871
	return n
//line dcells.w:1872
}

//line dcells.w:1874
func TestMCCMultiplicity(t *testing.T) {
//line dcells.w:1875
	// "a" must be covered exactly twice (2|a); the only cover is {ab, ac}.
//line dcells.w:1876
	input := "2|a b c\na b\na c\nb c\n"
//line dcells.w:1877
	if n := countMCC(t, input); n != 1 {
//line dcells.w:1878
		t.Errorf("exact-twice: got %d solutions, want 1", n)
//line dcells.w:1879
	}
//line dcells.w:1880
}

//line dcells.w:1882
func TestMCCSlack(t *testing.T) {
//line dcells.w:1883
	// "a" covered 1..2 times; b, c exactly once. One cover: {ab, ac}.
//line dcells.w:1884
	input := "1:2|a b c\na b\na c\nb c\n"
//line dcells.w:1885
	if n := countMCC(t, input); n != 1 {
//line dcells.w:1886
		t.Errorf("slack: got %d solutions, want 1", n)
//line dcells.w:1887
	}
//line dcells.w:1888
}

//line dcells.w:1890
func TestMCCRicher(t *testing.T) {
//line dcells.w:1891
	// Cross-checked against cmd/ssmcc: 4 solutions.
//line dcells.w:1892
	input := "1:3|a 2|b c d\na b\na c\na d\nb c\nb d\nc d\na b c\n"
//line dcells.w:1893
	if n := countMCC(t, input); n != 4 {
//line dcells.w:1894
		t.Errorf("richer: got %d solutions, want 4", n)
//line dcells.w:1895
	}
//line dcells.w:1896
}

//line dcells.w:1898
func TestMCCPlainXCC(t *testing.T) {
//line dcells.w:1899
	n := 8
//line dcells.w:1900
	var b strings.Builder
//line dcells.w:1901
	for i := 0; i < n; i++ {
//line dcells.w:1902
		b.WriteString(itoa("r", i))
//line dcells.w:1903
	}
//line dcells.w:1904
	for j := 0; j < n; j++ {
//line dcells.w:1905
		b.WriteString(itoa("c", j))
//line dcells.w:1906
	}
//line dcells.w:1907
	b.WriteString("|")
//line dcells.w:1908
	for k := 0; k < 2*n-1; k++ {
//line dcells.w:1909
		b.WriteString(itoa(" a", k))
//line dcells.w:1910
	}
//line dcells.w:1911
	for k := 0; k < 2*n-1; k++ {
//line dcells.w:1912
		b.WriteString(itoa(" b", k))
//line dcells.w:1913
	}
//line dcells.w:1914
	b.WriteString("\n")
//line dcells.w:1915
	for i := 0; i < n; i++ {
//line dcells.w:1916
		for j := 0; j < n; j++ {
//line dcells.w:1917
			b.WriteString(itoa("r", i))
//line dcells.w:1918
			b.WriteString(itoa("c", j))
//line dcells.w:1919
			b.WriteString(itoa("a", i+j))
//line dcells.w:1920
			b.WriteString(itoa("b", i-j+n-1))
//line dcells.w:1921
			b.WriteString("\n")
//line dcells.w:1922
		}
//line dcells.w:1923
	}
//line dcells.w:1924
	if got := countMCC(t, b.String()); got != 92 {
//line dcells.w:1925
		t.Errorf("8-queens via MCC: got %d, want 92", got)
//line dcells.w:1926
	}
//line dcells.w:1927
}

//line dcells.w:1929
func TestMCCColors(t *testing.T) {
//line dcells.w:1930
	input := "p q r | x y\np q x:A y:B\np r x:A y:A\np x:B\nq x:A\nr y:B\n"
//line dcells.w:1931
	if n := countMCC(t, input); n != 2 {
//line dcells.w:1932
		t.Errorf("colors: got %d solutions, want 2", n)
//line dcells.w:1933
	}
//line dcells.w:1934
}
