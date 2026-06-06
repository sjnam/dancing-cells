package dcells

import (
	"bufio"
	"io"
	"strconv"
	"strings"
)

func (m *MCC) inputMatrix(rd io.Reader) {
	br := bufio.NewReader(rd)
	m.readItemNames(br)
	m.readOptions(br)
}

func mustAtoi(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		failf("illegal number in bound spec: %q", s)
	}
	return n
}

// parseItemSpec splits an item token into its name and multiplicity bounds. A
// token may be "name" (default 1:1), "high|name", or "low:high|name". The lone
// "|" separator is handled by the caller.
func parseItemSpec(tok string, inSecondary bool) (name string, lower, upper int) {
	if i := strings.IndexByte(tok, '|'); i >= 0 {
		if inSecondary {
			failf("secondary item cannot have a multiplicity: %q", tok)
		}
		spec, nm := tok[:i], tok[i+1:]
		if j := strings.IndexByte(spec, ':'); j >= 0 {
			lower, upper = mustAtoi(spec[:j]), mustAtoi(spec[j+1:])
		} else {
			upper = mustAtoi(spec)
			lower = upper
		}
		if upper == 0 {
			failf("upper bound is zero: %q", tok)
		}
		if lower > upper {
			failf("lower bound exceeds upper bound: %q", tok)
		}
		name = nm
	} else {
		name, lower, upper = tok, 1, 1
	}
	if name == "" {
		failf("item name empty: %q", tok)
	}
	if strings.ContainsAny(name, ":|") {
		failf("illegal character in item name: %q", name)
	}
	return
}

func (m *MCC) readItemNames(br *bufio.Reader) {
	var buf []byte
	var p int
	found := false
	for {
		var ok bool
		if buf, ok = nextLine(br); !ok {
			break
		}
		if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
			found = true
			break
		}
	}
	if !found {
		failf("no items")
	}
	for buf[p] != 0 {
		tok, next := token(buf, p, false)
		if tok == "|" {
			if m.second != secondUnset {
				failf("item name line contains | twice")
			}
			m.second = len(m.names) // the next item's number
		} else {
			name, lower, upper := parseItemSpec(tok, m.second != secondUnset)
			num, ok := m.internName(name)
			if !ok {
				failf("duplicate item name: %s", name)
			}
			slot := num * mccIprop
			m.set = ensure(m.set, slot)
			m.setSlack(slot, upper-lower)
			m.setBound(slot, upper)
		}
		p = skipSpace(buf, next)
	}
	m.lastItm = len(m.names)
}

func (m *MCC) readOptions(br *bufio.Reader) {
	for {
		buf, ok := nextLine(br)
		if !ok {
			break
		}
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
			continue
		}
		m.readOption(buf)
	}
	m.finalize()
}

func (m *MCC) readOption(buf []byte) {
	spacer := m.lastNode
	hasPrimary := false
	for p := skipSpace(buf, 0); buf[p] != 0; {
		name, next := token(buf, p, true)
		if name == "" {
			failf("empty item name")
		}
		num, known := m.nameIndex[name]
		if !known {
			failf("unknown item name: %s", name)
		}
		m.createNode(num, spacer, &hasPrimary)
		if buf[next] == ':' {
			if num < m.second {
				failf("primary item must be uncolored: %s", name)
			}
			color, ce := token(buf, next+1, false)
			if color == "" {
				failf("missing color after %s:", name)
			}
			m.nd[m.lastNode].clr = int32(m.internColor(color))
			next = ce
		} else {
			m.nd[m.lastNode].clr = 0
		}
		p = skipSpace(buf, next)
	}

	if !hasPrimary {
		for m.lastNode > spacer {
			slot := int(m.nd[m.lastNode].itm) * mccIprop
			m.setSize(slot, m.size(slot)-1)
			m.setPos(slot, spacer-1)
			m.lastNode--
		}
		return
	}
	m.nd[spacer].loc = int32(m.lastNode - spacer)
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	m.options++
	m.nd[m.lastNode].itm = int32(spacer + 1 - m.lastNode)
}

func (m *MCC) createNode(num, spacer int, hasPrimary *bool) {
	slot := num * mccIprop
	m.set = ensure(m.set, slot)
	if m.pos(slot) > spacer {
		failf("duplicate item name in this option: %s", m.names[num])
	}
	m.lastNode++
	m.nd = ensure(m.nd, m.lastNode+1)
	t := m.size(slot)
	m.nd[m.lastNode].itm = int32(num)
	m.nd[m.lastNode].loc = int32(t)
	if num < m.second {
		*hasPrimary = true
	}
	m.setSize(slot, t+1)
	m.setPos(slot, m.lastNode)
}

func (m *MCC) finalize() {
	m.active, m.itemlen = m.lastItm-1, m.lastItm-1
	m.item = ensure(m.item, m.itemlen)
	m.set = ensure(m.set, m.itemlen*mccIprop+1) // all input slots readable

	j := mccExtra
	k := 0
	for ; k < m.itemlen; k++ {
		m.item[k] = int32(j)
		j += mccExtra + m.size((k+1)*mccIprop)
	}
	m.setlen = j - mccExtra
	m.set = ensure(m.set, j+1)
	if m.second == secondUnset {
		m.osecond, m.second = m.active, j
	} else {
		m.osecond = m.second - 1
	}

	for ; k != 0; k-- {
		base := int(m.item[k-1])
		if k == m.second {
			m.second = base
		}
		m.setSize(base, m.size(k*mccIprop))
		m.setItemNo(base, k)
		m.setSlack(base, m.slack(k*mccIprop))
		m.setBound(base, m.bound(k*mccIprop))
		m.setPos(base, k-1)
		switch {
		case k <= m.osecond && m.size(base) < m.bound(base)-m.slack(base):
			m.baditem = k
		case m.size(base) == 0:
			m.force = ensure(m.force, m.forced+1)
			m.force[m.forced] = int32(base)
			m.forced++
		}
	}

	for k = 1; k < m.lastNode; k++ {
		if m.nd[k].itm < 0 {
			continue
		}
		base := int(m.item[int(m.nd[k].itm)-1])
		loc := base + int(m.nd[k].loc)
		m.nd[k].itm = int32(base)
		m.nd[k].loc = int32(loc)
		m.set[loc] = int32(k)
	}

	m.deactivateOptionless()
}

// deactivateOptionless removes primary items with lower bound 0 and no options
// (they simply never appear) and any optionless secondary items.
func (m *MCC) deactivateOptionless() {
	for m.forced != 0 {
		m.forced--
		j := int(m.force[m.forced])
		m.active--
		i := int(m.item[m.active])
		pp := m.pos(j)
		m.item[m.active], m.item[pp] = int32(j), int32(i)
		m.setPos(j, m.active)
		m.setPos(i, pp)
	}
}
