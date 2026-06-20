package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	cells "github.com/sjnam/dancing-cells"
)

func partridgeDC(n int) io.Reader {
	N := n * (n + 1) / 2
	r, w := io.Pipe()
	go func() {
		defer w.Close()
		for i := 1; i <= n; i++ {
			fmt.Fprintf(w, "%d:%d|#%d ", i, i, i)
		}
		for i := range N {
			for j := range N {
				fmt.Fprintf(w, "%d,%d ", i, j)
			}
		}
		fmt.Fprintln(w)
		for t := 1; t <= n; t++ {
			for r := 0; r < N-t+1; r++ {
				for c := 0; c < N-t+1; c++ {
					fmt.Fprintf(w, "#%d ", t)
					for rr := 0; rr < t; rr++ {
						for cc := 0; cc < t; cc++ {
							fmt.Fprintf(w, "%d,%d ", r+rr, c+cc)
						}
					}
					fmt.Fprintln(w)
				}
			}
		}
	}()
	return r
}

// fillBoard fills size[r][c] with tile size and tile[r][c] with a unique tile ID.
func fillBoard(n int, sol []cells.Option) (size, tile [][]int) {
	N := n * (n + 1) / 2
	size = make([][]int, N)
	tile = make([][]int, N)
	for i := range size {
		size[i] = make([]int, N)
		tile[i] = make([]int, N)
	}
	tileID := 0
	for _, opt := range sol {
		s, _ := strconv.Atoi(opt[0][1:]) // "#k" -> k
		tileID++
		for _, coord := range opt[1:] {
			parts := strings.Split(coord, ",")
			r, _ := strconv.Atoi(parts[0])
			c, _ := strconv.Atoi(parts[1])
			size[r][c] = s
			tile[r][c] = tileID
		}
	}
	return
}

// printBoard draws the tiling as a Unicode box-drawing diagram.
//
// To stay compact while keeping each tile roughly square, every base cell maps
// to a single text row (1 tall) and one interior column (1 wide), so the board
// is 2N+1 chars wide and N+1 rows tall. Each text row merges the horizontal grid
// line at the top of a cell row with that row's interior, rather than spending a
// separate row on it. With the terminal's ~2:1 character height/width ratio, a
// k×k tile renders as (2k-1)×k characters, which displays approximately square.
func printBoard(size, tile [][]int) {
	N := len(tile)

	tileAt := func(r, c int) int {
		if r < 0 || r >= N || c < 0 || c >= N {
			return 0
		}
		return tile[r][c]
	}

	// hBorder: horizontal line above board row r at column c.
	hBorder := func(r, c int) bool {
		return r == 0 || r == N || tileAt(r, c) != tileAt(r-1, c)
	}

	// vBorder: vertical line left of board column c at row r.
	vBorder := func(r, c int) bool {
		return c == 0 || c == N || tileAt(r, c) != tileAt(r, c-1)
	}

	// Label each tile in its bottom-right cell, where the cell's top edge is
	// interior to the tile (no horizontal line to collide with). A 1×1 tile has
	// no such cell — its only row is also its top border — so it stays blank.
	// Multi-digit sizes (≥ 10) are written right-aligned into the cell and the
	// space to its left, both of which are tile interior on the label row.
	type pos struct{ r, c int }
	tileCells := make(map[int][]pos)
	for r := range N {
		for c := range N {
			tileCells[tile[r][c]] = append(tileCells[tile[r][c]], pos{r, c})
		}
	}
	label := make([][]int, N)
	for i := range label {
		label[i] = make([]int, N)
	}
	for _, cells := range tileCells {
		maxR, maxC := cells[0].r, cells[0].c
		for _, p := range cells {
			if p.r > maxR {
				maxR = p.r
			}
			if p.c > maxC {
				maxC = p.c
			}
		}
		if s := size[cells[0].r][cells[0].c]; s > 1 {
			label[maxR][maxC] = s
		}
	}

	junc := [16]rune{
		' ', '╶', '╴', '─',
		'╷', '┌', '┐', '┬',
		'╵', '└', '┘', '┴',
		'│', '├', '┤', '┼',
	}

	// Each row is 2N+1 runes: cell (r, c) occupies junction column 2c and
	// interior column 2c+1.
	row := make([]rune, 2*N+1)
	for r := 0; r <= N; r++ {
		for c := 0; c <= N; c++ {
			// Junction at the top-left corner of cell (r, c): vertical edges run
			// up (row r-1) and down (row r); horizontal edges run left and right.
			b := 0
			if r > 0 && vBorder(r-1, c) {
				b |= 8
			}
			if r < N && vBorder(r, c) {
				b |= 4
			}
			if c > 0 && hBorder(r, c-1) {
				b |= 2
			}
			if c < N && hBorder(r, c) {
				b |= 1
			}
			row[2*c] = junc[b]

			if c < N {
				if hBorder(r, c) {
					row[2*c+1] = '─'
				} else {
					row[2*c+1] = ' '
				}
			}
		}

		// Overlay tile labels, right-aligned with the last digit in the cell's
		// interior column. Extra digits spill left into interior spaces. The
		// bottom border row (r == N) holds no labels.
		if r < N {
			for c := 0; c < N; c++ {
				if label[r][c] > 0 {
					ds := strconv.Itoa(label[r][c])
					for i, p := len(ds)-1, 2*c+1; i >= 0; i, p = i-1, p-1 {
						row[p] = rune(ds[i])
					}
				}
			}
		}
		fmt.Println(string(row))
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.TODO(), 30*time.Minute)
	defer cancel()

	n := 8
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}
	mcc := cells.NewMCC()
	mcc.PulseInterval = 30 * time.Second
	mcc = mcc.WithContext(ctx)
	res := mcc.Dance(partridgeDC(n))

	start := time.Now()
	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			case st, ok := <-res.Heartbeat:
				if !ok {
					return
				}
				fmt.Printf("%s (%v)\n", st, time.Since(start))
			}
		}
	}()

	i := 0
	for sol := range res.Solutions {
		i++
		fmt.Printf("%d:\n", i)
		size, tile := fillBoard(n, sol)
		printBoard(size, tile)
	}
}
