// Sudoku solver: read one 81-character puzzle per line (digits 1-9, '.' or '0'
// for blanks) and print each solution. Each puzzle is turned into an exact
// cover (position / row-digit / column-digit / box-digit constraints) and
// solved with the dancing-cells library.
//
//	go run ./examples/sudoku examples/sudoku/puzzles.txt
package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"time"

	dcells "github.com/sjnam/dancing-cells"
)

// sudokuInput encodes the blanks of a puzzle as an exact-cover problem.
func sudokuInput(line []byte) io.Reader {
	var pos, row, col, box [9][9]int
	for i, j := 0, 0; i < 81; i, j = i+9, j+1 {
		for k := 0; k < 9; k++ {
			ch := line[i+k]
			if ch >= '1' && ch <= '9' {
				d := int(ch - '1')
				x := j/3*3 + k/3
				pos[j][k], row[j][d], col[k][d], box[x][d] = d+1, k+1, j+1, j+1
			}
		}
	}

	r, w := io.Pipe()
	go func() {
		defer w.Close()
		// Primary items: every unfilled position/row/col/box constraint.
		for j := 0; j < 9; j++ {
			for k := 0; k < 9; k++ {
				if pos[j][k] == 0 {
					fmt.Fprintf(w, "p%d%d ", j, k)
				}
			}
		}
		for _, t := range []struct {
			c string
			a *[9][9]int
		}{{"r", &row}, {"c", &col}, {"b", &box}} {
			for j := 0; j < 9; j++ {
				for k := 0; k < 9; k++ {
					if t.a[j][k] == 0 {
						fmt.Fprintf(w, "%s%d%d ", t.c, j, k+1)
					}
				}
			}
		}
		fmt.Fprintln(w)
		// One option per legal (position, digit) placement.
		for j := 0; j < 9; j++ {
			for k := 0; k < 9; k++ {
				for d := 0; d < 9; d++ {
					x := j/3*3 + k/3
					if pos[j][k] == 0 && row[j][d] == 0 && col[k][d] == 0 && box[x][d] == 0 {
						fmt.Fprintf(w, "p%d%d r%d%d c%d%d b%d%d\n", j, k, j, d+1, k, d+1, x, d+1)
					}
				}
			}
		}
	}()
	return r
}

func solve(line []byte) []byte {
	ans := append([]byte(nil), line...)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	res := dcells.NewDancer().WithContext(ctx).Dance(sudokuInput(line))
	sol, ok := <-res.Solutions
	if !ok {
		return nil // no solution
	}
	for _, opt := range sol {
		// opt[0]="pjk" gives the cell; opt[1]="rjd" gives the digit.
		j, k := opt[0][1]-'0', opt[0][2]-'0'
		ans[int(j)*9+int(k)] = opt[1][2]
	}
	cancel()                  // stop the solver after the first solution
	for range res.Solutions { // drain so its goroutine can exit
	}
	return ans
}

func main() {
	if len(os.Args) != 2 {
		log.Fatalf("usage: %s puzzles-file", os.Args[0])
	}
	f, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	start := time.Now()
	sc := bufio.NewScanner(f)
	for i := 0; sc.Scan(); {
		line := sc.Bytes()
		if len(line) < 81 {
			continue
		}
		i++
		q := append([]byte(nil), line[:81]...)
		fmt.Printf("Q[%5d]: %s\n", i, q)
		if a := solve(q); a != nil {
			fmt.Printf("A[%5d]: %s\n", i, a)
		} else {
			fmt.Printf("A[%5d]: (no solution)\n", i)
		}
	}
	fmt.Printf("Solving took: %v\n", time.Since(start))
}
