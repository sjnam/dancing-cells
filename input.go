package dcells

import (
	"bufio"
	"fmt"
	"io"
)

// The input is the DLX format shared by Knuth's solvers: a line of item names
// (primary, then '|', then secondary), followed by one option per line listing
// the item names it contains. A secondary item in an option may carry a
// one-character color as "name:c". Lines beginning with '|' are comments.

type parseError struct{ msg string }

func (e *parseError) Error() string { return e.msg }

func failf(format string, a ...any) {
	panic(&parseError{fmt.Sprintf(format, a...)})
}

// inputMatrix parses the whole problem from rd into the solver's structures.
func (s *Solver) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	s.readItemNames(br)
	s.readOptions(br)
}

// nextLine reads one input line, returning it as a NUL-terminated, NUL-padded
// byte buffer (so C-style buf[p+j] probing stays in bounds), plus strlen(buf).
func nextLine(br *bufio.Reader) (buf []byte, slen int, ok bool) {
	str, err := br.ReadString('\n')
	if len(str) == 0 && err != nil {
		return nil, 0, false
	}
	if len(str) == 0 || str[len(str)-1] != '\n' {
		str += "\n"
	}
	slen = len(str)
	buf = make([]byte, slen+12)
	copy(buf, str)
	return buf, slen, true
}

func skipSpace(buf []byte, p int) int {
	for isspace(buf[p]) {
		p++
	}
	return p
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

func (s *Solver) readItemNames(br *bufio.Reader) {
	var buf []byte
	var slen, p int
	for {
		var ok bool
		if buf, slen, ok = nextLine(br); !ok {
			break
		}
		if p = slen - 1; buf[p] != '\n' {
			failf("input line way too long")
		}
		if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
			s.lastItm = 1
			break
		}
	}
	if s.lastItm == 0 {
		failf("no items")
	}
	for buf[p] != 0 {
		s.set = ensure(s.set, (s.lastItm<<2)+1)
		var nb [8]byte
		j := 0
		for ; j < 8 && !isspace(buf[p+j]); j++ {
			if buf[p+j] == ':' || buf[p+j] == '|' {
				failf("illegal character in item name: %q", trimToNul(buf))
			}
			nb[j] = buf[p+j]
		}
		if j == 8 && !isspace(buf[p+j]) {
			failf("item name too long: %q", trimToNul(buf))
		}
		l, r := packLR(&nb)
		s.setLname(s.lastItm<<2, l)
		s.setRname(s.lastItm<<2, r)
		for k := s.lastItm - 1; k != 0; k-- {
			if s.lname(k<<2) == l && s.rname(k<<2) == r {
				failf("duplicate item name: %s", decodeName(l, r))
			}
		}
		s.lastItm++
		p = skipSpace(buf, p+j+1)
		if buf[p] == '|' {
			if s.second != secondUnset {
				failf("item name line contains | twice")
			}
			s.second = s.lastItm
			p = skipSpace(buf, p+1)
		}
	}
}

func (s *Solver) readOptions(br *bufio.Reader) {
	for {
		buf, slen, ok := nextLine(br)
		if !ok {
			break
		}
		p := slen - 1
		if buf[p] != '\n' {
			failf("option line too long")
		}
		if p = skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
			continue
		}
		spacer := s.lastNode
		hasPrimary := false
		for buf[p] != 0 {
			var nb [8]byte
			j := 0
			for ; j < 8 && !isspace(buf[p+j]) && buf[p+j] != ':'; j++ {
				nb[j] = buf[p+j]
			}
			if j == 0 {
				failf("empty item name")
			}
			if j == 8 && !isspace(buf[p+j]) && buf[p+j] != ':' {
				failf("item name too long: %q", trimToNul(buf))
			}
			k := s.createNode(&nb, spacer, &hasPrimary)
			switch {
			case buf[p+j] != ':':
				s.nd[s.lastNode].clr = 0
			case k >= s.second:
				if isspace(buf[p+j+1]) || !isspace(buf[p+j+2]) {
					failf("color must be a single character: %q", trimToNul(buf))
				}
				s.nd[s.lastNode].clr = int32(buf[p+j+1])
				p += 2
			default:
				failf("primary item must be uncolored: %q", trimToNul(buf))
			}
			p = skipSpace(buf, p+j+1)
		}
		if !hasPrimary {
			for s.lastNode > spacer {
				k := int(s.nd[s.lastNode].itm) << 2
				s.setSize(k, s.size(k)-1)
				s.setPos(k, spacer-1)
				s.lastNode--
			}
		} else {
			s.nd[spacer].loc = int32(s.lastNode - spacer)
			s.lastNode++
			s.nd = ensure(s.nd, s.lastNode+1)
			s.options++
			s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
		}
	}
	s.finalize()
}

// createNode appends a node for the named item to the current option and
// returns its input slot index (item number << 2), marking hasPrimary.
func (s *Solver) createNode(nb *[8]byte, spacer int, hasPrimary *bool) int {
	l, r := packLR(nb)
	k := 0
	for k = (s.lastItm - 1) << 2; k > 0; k -= 4 {
		if s.lname(k) != l {
			continue
		}
		if s.rname(k) == r {
			break
		}
	}
	if k == 0 {
		failf("unknown item name: %s", decodeName(l, r))
	}
	if s.pos(k) > spacer {
		failf("duplicate item name in this option: %s", decodeName(l, r))
	}
	s.lastNode++
	s.nd = ensure(s.nd, s.lastNode+1)
	t := s.size(k)
	s.nd[s.lastNode].itm = int32(k >> 2)
	s.nd[s.lastNode].loc = int32(t)
	if (k >> 2) < s.second {
		*hasPrimary = true
	}
	s.setSize(k, t+1)
	s.setPos(k, s.lastNode)
	return k
}

// finalize lays out the final set array (names, pointers, active lists) once
// all options have been read.
func (s *Solver) finalize() {
	s.active, s.itemlen = s.lastItm-1, s.lastItm-1
	s.item = ensure(s.item, s.itemlen)
	j := primExtra
	k := 0
	for ; k < s.itemlen; k++ {
		s.item[k] = int32(j)
		j += primExtra + s.size((k+1)<<2)
	}
	s.setlen = j - 4
	s.set = ensure(s.set, j+1)
	if s.second == secondUnset {
		s.osecond, s.second = s.active, j
	} else {
		s.osecond = s.second - 1
	}
	for ; k != 0; k-- {
		base := int(s.item[k-1])
		if k == s.second {
			s.second = base
		}
		s.setSize(base, s.size(k<<2))
		if s.size(base) == 0 && k <= s.osecond {
			s.baditem = k
		}
		s.setPos(base, k-1)
		s.setRname(base, s.rname(k<<2))
		s.setLname(base, s.lname(k<<2))
	}
	for k = 1; k < s.lastNode; k++ {
		if s.nd[k].itm < 0 {
			continue
		}
		base := int(s.item[int(s.nd[k].itm)-1])
		loc := base + int(s.nd[k].loc)
		s.nd[k].itm = int32(base)
		s.nd[k].loc = int32(loc)
		s.set[loc] = int32(k)
	}
}
