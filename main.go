// Command ssxcc is an XCC (exact cover with colors) solver that uses
// sparse-set "dancing cells" data structures rather than dancing links.
//
// It is a Go port of Donald E. Knuth's CWEB program SSXCC
// (https://www-cs-faculty.stanford.edu/~knuth/programs/ssxcc.w), accepting the
// same DLX input format. Input is read from a file argument, or from standard
// input when none is given:
//
//	ssxcc [flags] [file.dlx]
//	ssxcc -m 1 < file.dlx
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
)

func main() {
	flag.IntVar(&vbose, "v", showBasics+showWarnings,
		"verbose output bitmask (1 basics, 2 choices, 4 details, 128 profile,\n"+
			"256 full state, 512 totals, 1024 warnings, 2048 max degree)")
	flag.IntVar(&spacing, "m", 0, "print every m-th solution (0 = count only)")
	flag.IntVar(&randomSeed, "s", 0, "randomize the item order using this seed")
	flag.Uint64Var(&delta, "d", 0, "print a progress report every d search nodes (0 = never)")
	flag.IntVar(&showChoicesMax, "c", 1<<30, "show choices only below this level")
	flag.IntVar(&showLevelsMax, "C", 1<<30, "show at most this many levels in state reports")
	flag.IntVar(&showChoicesGap, "l", 1<<30, "show details only within this many levels of the deepest")
	flag.Uint64Var(&maxcount, "t", 0, "stop after this many solutions (0 = unlimited)")
	flag.Uint64Var(&nodeTimeout, "T", 0, "give up after this many search nodes (0 = unlimited)")
	flag.StringVar(&shapeName, "S", "", "write a search-tree shape file to this path")
	flag.Parse()

	flag.Visit(func(f *flag.Flag) {
		if f.Name == "s" {
			randomizing = true
		}
	})
	thresh = delta
	if randomizing {
		gbInitRand(int64(randomSeed))
	}
	if shapeName != "" {
		f, err := os.Create(shapeName)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Sorry, I can't open file `%s' for writing!\n", shapeName)
		} else {
			shapeFile = f
			shapeOut = bufio.NewWriter(f)
		}
	}

	src := os.Stdin
	if flag.NArg() >= 1 {
		f, err := os.Open(flag.Arg(0))
		if err != nil {
			fmt.Fprintf(os.Stderr, "Can't open %s: %v\n", flag.Arg(0), err)
			os.Exit(-1)
		}
		defer f.Close()
		src = f
	}
	in = bufio.NewReader(src)
	out = bufio.NewWriter(os.Stdout)

	allocate()
	readItemNames()
	readOptions()
	report()
}

// report prints the input summary, runs the search, and prints final stats.
func report() {
	if vbose&showBasics != 0 {
		fmt.Fprintf(os.Stderr, "(%d options, %d+%d items, %d entries successfully read)\n",
			options, osecond, itemlen-osecond, lastNode)
	}
	if vbose&showTots != 0 {
		fmt.Fprint(os.Stderr, "Item totals:")
		for k := range itemlen {
			if k == second {
				fmt.Fprint(os.Stderr, " |")
			}
			fmt.Fprintf(os.Stderr, " %d", size(int(item[k])))
		}
		fmt.Fprintln(os.Stderr)
	}

	switch {
	case baditem != 0:
		if vbose&showChoices != 0 {
			fmt.Fprint(os.Stderr, "Item")
			printItemName(int(item[baditem-1]), os.Stderr)
			fmt.Fprintln(os.Stderr, " has no options!")
		}
	default:
		solve()
	}

	out.Flush()
	if shapeOut != nil {
		shapeOut.Flush()
		shapeFile.Close()
	}

	if vbose&showProfile != 0 {
		printProfile()
	}
	if vbose&showMaxDeg != 0 {
		fmt.Fprintf(os.Stderr, "The maximum branching degree was %d.\n", maxdeg)
	}
	if vbose&showBasics != 0 {
		plural := "s"
		if count == 1 {
			plural = ""
		}
		fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
			count, plural, updates, nodes)
	}
	if sanityChecking {
		fmt.Fprintln(os.Stderr, "sanity_checking was on!")
	}
}
