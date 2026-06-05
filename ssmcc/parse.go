package main

import (
	"fmt"
	"os"
)

// The input is the DLX/DLX3 format: a line of item names (primary, then '|',
// then secondary), followed by one option per line. A primary item name may
// carry a multiplicity prefix "low:high|" or "high|" (default 1:1). A
// secondary item in an option may carry a one-character color "name:c".

func nextLine() (buf []byte, slen int, ok bool) {
	s, err := in.ReadString('\n')
	if len(s) == 0 && err != nil {
		return nil, 0, false
	}
	if len(s) == 0 || s[len(s)-1] != '\n' {
		s += "\n"
	}
	slen = len(s)
	buf = make([]byte, slen+12)
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

// convPrefix parses the j digits buf[p:p+j] as a nonnegative integer.
func convPrefix(buf []byte, p, j int) int {
	q := 0
	for pp := p; pp < p+j; pp++ {
		if buf[pp] < '0' || buf[pp] > '9' {
			panicf(p, buf, "Illegal digit in bound spec")
		}
		q = 10*q + int(buf[pp]-'0')
	}
	return q
}

// scanBoundedName parses an optional "low:high|" or "high|" multiplicity prefix
// and then the item name starting at buf[p]. It returns the 8-byte name, its
// length j, the index np of the name's first character (after any prefix), and
// the lower/upper bounds.
func scanBoundedName(buf []byte, p int) (nb [8]byte, j, np, lower, upper int) {
	istage := 0
	if second != maxCols {
		istage = 2 // secondary section: no bounds allowed
	}
	np = p
restart:
	nb = [8]byte{}
	for j = 0; j < 8 && !isspace(buf[np+j]); j++ {
		switch buf[np+j] {
		case ':':
			if istage != 0 {
				panicf(np, buf, "Illegal `:' in item name")
			}
			lower = convPrefix(buf, np, j)
			istage, np = 1, np+j+1
			goto restart
		case '|':
			if istage > 1 {
				panicf(np, buf, "Illegal `|' in item name")
			}
			upper = convPrefix(buf, np, j)
			if upper == 0 {
				panicf(np, buf, "Upper bound is zero")
			}
			if istage == 0 {
				lower = upper
			} else if lower > upper {
				panicf(np, buf, "Lower bound exceeds upper bound")
			}
			istage, np = 2, np+j+1
			goto restart
		default:
			nb[j] = buf[np+j]
		}
	}
	switch istage {
	case 1:
		panicf(np, buf, "Lower bound without upper bound")
	case 0:
		lower, upper = 1, 1
	}
	if j == 0 {
		panicf(np, buf, "Item name empty")
	}
	if j == 8 && !isspace(buf[np+j]) {
		panicf(np, buf, "Item name too long")
	}
	return
}

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
		nb, j, np, lower, upper := scanBoundedName(buf, p)
		l, r := packLR(&nb)
		slot := lastItm * ipropcount
		setLname(slot, l)
		setRname(slot, r)
		setSlack(slot, upper-lower)
		setBound(slot, upper)
		for k := lastItm - 1; k != 0; k-- {
			if lname(k*ipropcount) == l && rname(k*ipropcount) == r {
				panicf(np, buf, "Duplicate item name")
			}
		}
		lastItm++
		if lastItm > maxCols {
			panicf(np, buf, "Too many items")
		}
		p = skipSpace(buf, np+j+1)
		if buf[p] == '|' {
			if second != maxCols {
				panicf(p, buf, "Item name line contains | twice")
			}
			second = lastItm
			p = skipSpace(buf, p+1)
		}
	}
}

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
		spacer := lastNode
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
			case k >= second:
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
				k := int(nd[lastNode].itm) * ipropcount
				setSize(k, size(k)-1)
				setPos(k, spacer-1)
				lastNode--
			}
		} else {
			nd[spacer].loc = int32(lastNode - spacer)
			lastNode++
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
// returns its input slot index (item number * ipropcount).
func createNode(p int, buf []byte, nb *[8]byte, spacer int, hasPrimary *bool) int {
	l, r := packLR(nb)
	k := 0
	for k = (lastItm - 1) * ipropcount; k > 0; k -= ipropcount {
		if lname(k) != l {
			continue
		}
		if rname(k) == r {
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
	t := size(k)
	nd[lastNode].itm = int32(k / ipropcount)
	nd[lastNode].loc = int32(t)
	if (k / ipropcount) < second {
		*hasPrimary = true
	}
	setSize(k, t+1)
	setPos(k, lastNode)
	return k
}

// finalize lays out the final set array and deactivates optionless items.
func finalize() {
	active, itemlen = lastItm-1, lastItm-1
	j := primExtra
	k := 0
	for ; k < itemlen; k++ {
		item[k] = int32(j)
		extra := primExtra
		if k+2 >= second {
			extra = secondExtra
		}
		j += extra + size((k+1)*ipropcount)
		if j < int(item[k])+ipropcount {
			j = int(item[k]) + ipropcount
		}
	}
	setlen = j - ipropcount
	if second == maxCols {
		osecond, second = active, j
	} else {
		osecond = second - 1
	}
	for ; k != 0; k-- {
		j = int(item[k-1])
		if k == second {
			second = j
		}
		setSize(j, size(k*ipropcount))
		setPos(j, k-1)
		setRname(j, rname(k*ipropcount))
		setLname(j, lname(k*ipropcount))
		setSlack(j, slack(k*ipropcount))
		setBound(j, bound(k*ipropcount))
		if k <= osecond {
			if size(j) < bound(j)-slack(j) {
				baditem = k
			} else if size(j) == 0 {
				force[forced] = int32(j)
				forced++
			}
		} else if size(j) == 0 {
			force[forced] = int32(j)
			forced++
		}
	}
	for k = 1; k < lastNode; k++ {
		if nd[k].itm < 0 {
			continue
		}
		j = int(item[int(nd[k].itm)-1])
		loc := j + int(nd[k].loc)
		nd[k].itm = int32(j)
		nd[k].loc = int32(loc)
		set[loc] = int32(k)
	}
	deactivateOptionless()
}

// deactivateOptionless removes primary items whose lower bound is 0 and that
// have no options; they simply never appear in a solution.
func deactivateOptionless() {
	for forced != 0 {
		forced--
		j := int(force[forced])
		if vbose&showDetails != 0 {
			fmt.Fprint(os.Stderr, "Deactivating optionless item")
			printItemName(j, os.Stderr)
			fmt.Fprintln(os.Stderr)
		}
		active--
		i := int(item[active])
		pp := pos(j)
		item[active] = int32(j)
		item[pp] = int32(i)
		setPos(j, active)
		setPos(i, pp)
	}
}
