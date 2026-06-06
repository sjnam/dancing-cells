// Sudoku solver: read one 81-character puzzle per line (digits 1-9, '.' or '0'
// for blanks) and print each solution. Each puzzle becomes an exact cover
// (position / row-digit / column-digit / box-digit constraints) solved with the
// dancing-cells library.
//
// Puzzles are solved in parallel across all CPUs while results are emitted in
// input order (an "ordered fan-in"), since the puzzles are independent and each
// NewXCC() is fully self-contained.
//
//	go run ./examples/sudoku examples/sudoku/puzzles.txt
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

	dcells "github.com/sjnam/dancing-cells"
)

// sudokuInput encodes the blanks of a puzzle as an exact-cover problem. The DLX
// text is built in memory (no io.Pipe) so generation and parsing don't ping-pong
// across a goroutine boundary per puzzle.
func sudokuInput(line []byte) io.Reader {
	var pos, row, col, box [9][9]int
	for i, j := 0, 0; i < 81; i, j = i+9, j+1 {
		for k := 0; k < 9; k++ {
			if ch := line[i+k]; ch >= '1' && ch <= '9' {
				d := int(ch - '1')
				x := j/3*3 + k/3
				pos[j][k], row[j][d], col[k][d], box[x][d] = d+1, k+1, j+1, j+1
			}
		}
	}

	var b bytes.Buffer
	b.Grow(8192)
	// Primary items: every unfilled position/row/col/box constraint.
	for j := 0; j < 9; j++ {
		for k := 0; k < 9; k++ {
			if pos[j][k] == 0 {
				fmt.Fprintf(&b, "p%d%d ", j, k)
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
					fmt.Fprintf(&b, "%s%d%d ", t.c, j, k+1)
				}
			}
		}
	}
	b.WriteByte('\n')
	// One option per legal (position, digit) placement.
	for j := 0; j < 9; j++ {
		for k := 0; k < 9; k++ {
			for d := 0; d < 9; d++ {
				x := j/3*3 + k/3
				if pos[j][k] == 0 && row[j][d] == 0 && col[k][d] == 0 && box[x][d] == 0 {
					fmt.Fprintf(&b, "p%d%d r%d%d c%d%d b%d%d\n", j, k, j, d+1, k, d+1, x, d+1)
				}
			}
		}
	}
	return bytes.NewReader(b.Bytes())
}

type result struct{ q, a []byte }

func solve(line []byte) result {
	ans := append([]byte(nil), line...)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	res := dcells.NewXCC().WithContext(ctx).Dance(sudokuInput(line))
	sol, ok := <-res.Solutions
	if !ok {
		return result{line, nil} // no solution
	}
	for _, opt := range sol {
		// opt[0]="pjk" gives the cell; opt[1]="rjd" gives the digit.
		j, k := opt[0][1]-'0', opt[0][2]-'0'
		ans[int(j)*9+int(k)] = opt[1][2]
	}
	cancel()                  // stop after the first solution
	for range res.Solutions { // drain so the solver goroutine can exit
	}
	return result{line, ans}
}

// orderedMap applies work to every input concurrently (n at a time) and returns
// the results in input order. The lookahead window is kept well above n so that
// an occasional slow item doesn't stall the other workers (head-of-line).
func orderedMap[In, Out any](in <-chan In, n int, work func(In) Out) <-chan Out {
	window := 64 * n
	futures := make(chan chan Out, window)
	go func() {
		defer close(futures)
		sem := make(chan struct{}, n)
		for v := range in {
			sem <- struct{}{} // limit concurrency to n
			ch := make(chan Out, 1)
			futures <- ch // preserve input order (buffered to the window)
			go func(v In, ch chan Out) {
				ch <- work(v)
				<-sem
			}(v, ch)
		}
	}()

	out := make(chan Out)
	go func() {
		defer close(out)
		for ch := range futures {
			out <- <-ch
		}
	}()
	return out
}

func main() {
	// This is an allocation-heavy batch workload (a fresh solver per puzzle),
	// so let the heap grow more between collections to cut GC overhead.
	debug.SetGCPercent(400)

	if len(os.Args) != 2 {
		log.Fatalf("usage: %s puzzles-file", os.Args[0])
	}
	f, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	start := time.Now()

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
}
