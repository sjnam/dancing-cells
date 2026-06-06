// Pentominoes tiling: read a pre-generated exact-cover input (cells + the 12
// pentomino pieces O..Z) and print each tiling as a grid of piece letters.
//
//	go run ./examples/pentominoes examples/pentominoes/6x10.dlx
package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	dcells "github.com/sjnam/dancing-cells"
)

func main() {
	if len(os.Args) != 2 {
		log.Fatalf("usage: %s dlx-file", os.Args[0])
	}
	fd, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	defer fd.Close()

	// The board dimensions come from the file name, e.g. "6x10.dlx".
	dim := strings.Split(strings.Split(filepath.Base(os.Args[1]), ".")[0], "x")
	nr, _ := strconv.Atoi(dim[0])
	nc, _ := strconv.Atoi(dim[1])

	box := make([][]string, nr)
	for i := range box {
		box[i] = make([]string, nc)
		for j := range box[i] {
			box[i][j] = "."
		}
	}

	res := dcells.NewXCC().Dance(fd)
	i := 0
	for sol := range res.Solutions {
		i++
		// opt[0] is the piece letter; opt[1:] are its cells, two base-36 digits.
		for _, opt := range sol {
			for _, cell := range opt[1:] {
				x, _ := strconv.ParseInt(cell[0:1], 36, 0)
				y, _ := strconv.ParseInt(cell[1:2], 36, 0)
				box[x][y] = opt[0]
			}
		}
		fmt.Printf("%d:\n", i)
		for _, row := range box {
			fmt.Println(strings.Join(row, " "))
		}
		fmt.Println()
	}
}
