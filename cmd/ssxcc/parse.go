package main

import (
	"fmt"
	"os"
)

// The input uses the DLX format shared by Knuth's other solvers: a line of
// item names (primary, then '|', then secondary), followed by one line per
// option listing the item names it contains. A secondary item may carry a
// one-character color as "name:c". Lines starting with '|' are comments.

// nextLine reads one input line. The returned buffer always ends with a
// newline followed by NUL padding, so C-style buf[p+j] probing stays in
// bounds and stops at the terminating NUL. slen mirrors strlen(buf).
func nextLine() (buf []byte, slen int, ok bool) {
	s, err := in.ReadString('\n')
	if len(s) == 0 && err != nil {
		return nil, 0, false
	}
	if len(s) == 0 || s[len(s)-1] != '\n' {
		s += "\n"
	}
	slen = len(s)
	buf = make([]byte, slen+12) // content + '\n', then NUL padding
	copy(buf, s)
	return buf, slen, true
}

func panicf(p int, buf []byte, msg string) {
	line := buf
	if i := indexByte(line, 0); i >= 0 {
		line = line[:i]
	}
	if len(line) > 99 {
		line = line[:99]
	}
	fmt.Fprintf(os.Stderr, "%s!\n%d: %s\n", msg, p, string(line))
	os.Exit(-666)
}

func indexByte(b []byte, c byte) int {
	for i := range b {
		if b[i] == c {
			return i
		}
	}
	return -1
}

func trimToNul(b []byte) string {
	if i := indexByte(b, 0); i >= 0 {
		return string(b[:i])
	}
	return string(b)
}

func skipSpace(buf []byte, p int) int {
	for isspace(buf[p]) {
		p++
	}
	return p
}

// readItemNames parses the first non-comment line into the item table,
// recording the primary/secondary boundary in second.
func readItemNames() {
	var buf []byte
	var slen, p int
	for {
		var ok bool
		if buf, slen, ok = nextLine(); !ok {
			break
		}
		if p = slen - 1; buf[p] != '\n' {
			panicf(p, buf, "Input line way too long")
		}
		if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
			lastItm = 1
			break
		}
	}
	if lastItm == 0 {
		panicf(p, buf, "No items")
	}
	for buf[p] != 0 {
		var nb [8]byte
		j := 0
		for ; j < 8 && !isspace(buf[p+j]); j++ {
			if buf[p+j] == ':' || buf[p+j] == '|' {
				panicf(p, buf, "Illegal character in item name")
			}
			nb[j] = buf[p+j]
		}
		if j == 8 && !isspace(buf[p+j]) {
			panicf(p, buf, "Item name too long")
		}
		l, r := packLR(&nb)
		setLname(lastItm<<2, l)
		setRname(lastItm<<2, r)
		for k := lastItm - 1; k != 0; k-- {
			if lname(k<<2) == l && rname(k<<2) == r {
				panicf(p, buf, "Duplicate item name")
			}
		}
		lastItm++
		if lastItm > maxCols {
			panicf(p, buf, "Too many items")
		}
		p = skipSpace(buf, p+j+1)
		if buf[p] == '|' {
			if second != maxCols {
				panicf(p, buf, "Item name line contains | twice")
			}
			second = lastItm
			p = skipSpace(buf, p+1)
		}
	}
}

// readOptions parses every option line, creating nodes, then finalizes the
// data structures.
func readOptions() {
	for {
		buf, slen, ok := nextLine()
		if !ok {
			break
		}
		p := slen - 1
		if buf[p] != '\n' {
			panicf(p, buf, "Option line too long")
		}
		if p = skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
			continue
		}
		spacer := lastNode // the spacer to the left of this option
		hasPrimary := false
		for buf[p] != 0 {
			var nb [8]byte
			j := 0
			for ; j < 8 && !isspace(buf[p+j]) && buf[p+j] != ':'; j++ {
				nb[j] = buf[p+j]
			}
			if j == 0 {
				panicf(p, buf, "Empty item name")
			}
			if j == 8 && !isspace(buf[p+j]) && buf[p+j] != ':' {
				panicf(p, buf, "Item name too long")
			}
			k := createNode(p, buf, &nb, spacer, &hasPrimary)
			switch {
			case buf[p+j] != ':':
				nd[lastNode].clr = 0
			case k >= second: // a secondary item may be colored
				if isspace(buf[p+j+1]) || !isspace(buf[p+j+2]) {
					panicf(p, buf, "Color must be a single character")
				}
				nd[lastNode].clr = int32(buf[p+j+1])
				p += 2
			default:
				panicf(p, buf, "Primary item must be uncolored")
			}
			p = skipSpace(buf, p+j+1)
		}
		if !hasPrimary {
			if vbose&showWarnings != 0 {
				fmt.Fprintf(os.Stderr, "Option ignored (no primary items): %s", trimToNul(buf))
			}
			for lastNode > spacer {
				k := int(nd[lastNode].itm) << 2
				setSize(k, size(k)-1)
				setPos(k, spacer-1)
				lastNode--
			}
		} else {
			nd[spacer].loc = int32(lastNode - spacer) // complete the previous spacer
			lastNode++                                // create the next spacer
			if lastNode == maxNodes {
				panicf(p, buf, "Too many nodes")
			}
			options++
			nd[lastNode].itm = int32(spacer + 1 - lastNode)
			nd[lastNode].spr = int32(options)
		}
	}
	finalize()
}

// createNode appends a node for the named item to the current option and
// returns the item's input slot index (item number << 2). It temporarily
// uses pos to detect a repeated item within the same option.
func createNode(p int, buf []byte, nb *[8]byte, spacer int, hasPrimary *bool) int {
	l, r := packLR(nb)
	k := 0
	for k = (lastItm - 1) << 2; k != 0; k -= 4 {
		if lname(k) == l && rname(k) == r {
			break
		}
	}
	if k == 0 {
		panicf(p, buf, "Unknown item name")
	}
	if pos(k) > spacer {
		panicf(p, buf, "Duplicate item name in this option")
	}
	lastNode++
	if lastNode == maxNodes {
		panicf(p, buf, "Too many nodes")
	}
	t := size(k) // how many earlier options used this item
	nd[lastNode].itm = int32(k >> 2)
	nd[lastNode].loc = int32(t)
	if (k >> 2) < second {
		*hasPrimary = true
	}
	setSize(k, t+1)
	setPos(k, lastNode)
	return k
}

// finalize lays out the final set array (names, pointers, and the active
// option lists) once all options have been read.
func finalize() {
	// Reserve space for each item in set and record its base in item[].
	active, itemlen = lastItm-1, lastItm-1
	j := primExtra
	k := 0
	for ; k < itemlen; k++ {
		item[k] = int32(j)
		j += primExtra + size((k+1)<<2)
	}
	setlen = j - 4
	if second == maxCols {
		osecond, second = active, j
	} else {
		osecond = second - 1
	}
	// Going high to low, move names and sizes to their final positions.
	for ; k != 0; k-- {
		j = int(item[k-1])
		if k == second {
			second = j // second is now an index into set
		}
		setSize(j, size(k<<2))
		if size(j) == 0 && k <= osecond {
			baditem = k
		}
		setPos(j, k-1)
		setRname(j, rname(k<<2))
		setLname(j, lname(k<<2))
	}
	// Point each node at its item's set base and fill the active lists.
	for k = 1; k < lastNode; k++ {
		if nd[k].itm < 0 {
			continue // skip a spacer
		}
		j = int(item[int(nd[k].itm)-1])
		loc := j + int(nd[k].loc)
		nd[k].itm = int32(j)
		nd[k].loc = int32(loc)
		set[loc] = int32(k)
	}
}
