// Package dcells solves exact cover (XCC, MCC) with dancing cells.
//
//line dcells.w:75
//line dcells.w:76
package dcells

//line dcells.w:78
import (
//line dcells.w:79
	"bufio"
//line dcells.w:80
	"context"
//line dcells.w:81
	"fmt"
//line dcells.w:82
	"io"
//line dcells.w:83
	"os"
//line dcells.w:84
	"strconv"
//line dcells.w:85
	"strings"
//line dcells.w:86
	"time"
//line dcells.w:87
)

//line dcells.w:131
const (
//line dcells.w:132
	primExtra = 4 // set entries reserved below each item's base
//line dcells.w:133
	infSize = 1 << 30 // "no item to branch on" => a solution
//line dcells.w:134
	secondUnset = 1 << 30 // sentinel for "no primary/secondary boundary yet"
//line dcells.w:135
)

//line dcells.w:144
type node struct {
//line dcells.w:145
	itm, loc, clr int32 // itm and clr are fixed after input; loc dances
//line dcells.w:146
}

//line dcells.w:157
type Option []string

//line dcells.w:159
type Result struct {
//line dcells.w:160
	Solutions <-chan []Option
//line dcells.w:161
	Heartbeat <-chan string
//line dcells.w:162
}

//line dcells.w:170
type twoints struct {
//line dcells.w:171
	l, r int32
//line dcells.w:172
}

//line dcells.w:174
type threeints struct{ l, s, b int32 }

//line dcells.w:181
func ensure[T any](s []T, n int) []T {
//line dcells.w:182
	if n <= len(s) {
//line dcells.w:183
		return s
//line dcells.w:184
	}
//line dcells.w:185
	if n <= cap(s) {
//line dcells.w:186
		return s[:n]
//line dcells.w:187
	}
//line dcells.w:188
	t := make([]T, n, max(cap(s)*2, n, 64))
//line dcells.w:189
	copy(t, s)
//line dcells.w:190
	return t
//line dcells.w:191
}

//line dcells.w:268
type XCC struct {
//line dcells.w:269

//line dcells.w:199
	Debug bool // print input summary and final stats to stderr
//line dcells.w:200
	PulseInterval time.Duration // if > 0, offer periodic Heartbeat strings

//line dcells.w:270
	ctx context.Context

//line dcells.w:272

//line dcells.w:281
	nd []node
//line dcells.w:282
	lastNode int
//line dcells.w:283
	item []int32
//line dcells.w:284
	second int
//line dcells.w:285
	lastItm int
//line dcells.w:286
	set []int32
//line dcells.w:287
	itemlen int
//line dcells.w:288
	setlen int
//line dcells.w:289
	active int
//line dcells.w:290
	oactive int
//line dcells.w:291
	baditem int
//line dcells.w:292
	osecond int

//line dcells.w:273

//line dcells.w:206
	names []string // interned item names, by item number (1-based)
//line dcells.w:207
	nameIndex map[string]int
//line dcells.w:208
	colorNames []string // interned colors, by id (1-based; 0 means "no color")
//line dcells.w:209
	colorIndex map[string]int

//line dcells.w:274

//line dcells.w:216
	force []int32
//line dcells.w:217
	forced int

//line dcells.w:275

//line dcells.w:295
	choice []int32
//line dcells.w:296
	saved []int32
//line dcells.w:297
	savestack []twoints
//line dcells.w:298
	saveptr int

//line dcells.w:276

//line dcells.w:220
	updates uint64
//line dcells.w:221
	nodes uint64
//line dcells.w:222
	options uint64
//line dcells.w:223
	count uint64

//line dcells.w:277

//line dcells.w:226
	solStream chan []Option
//line dcells.w:227
	heartbeat chan string
//line dcells.w:228
	pulse *time.Ticker

//line dcells.w:278
}

//line dcells.w:308
func NewXCC() *XCC {
//line dcells.w:309
	return &XCC{
//line dcells.w:310
		second: secondUnset,
//line dcells.w:311
		names: []string{""}, // item numbers are 1-based
//line dcells.w:312
		nameIndex: make(map[string]int),
//line dcells.w:313
		colorNames: []string{""}, // color 0 means "no color"
//line dcells.w:314
		colorIndex: make(map[string]int),
//line dcells.w:315
		ctx: context.Background(),
//line dcells.w:316
	}
//line dcells.w:317
}

//line dcells.w:319
func (s *XCC) WithContext(ctx context.Context) *XCC {
//line dcells.w:320
	if ctx == nil {
//line dcells.w:321
		panic("dcells: nil context")
//line dcells.w:322
	}
//line dcells.w:323
	c := *s
//line dcells.w:324
	c.ctx = ctx
//line dcells.w:325
	return &c
//line dcells.w:326
}

//line dcells.w:328
func (s *XCC) Updates() uint64 { return s.updates }

//line dcells.w:329
func (s *XCC) Nodes() uint64 { return s.nodes }

//line dcells.w:337
func (s *XCC) size(x int) int { return int(s.set[x-1]) }

//line dcells.w:338
func (s *XCC) pos(x int) int { return int(s.set[x-2]) }

//line dcells.w:339
func (s *XCC) itemNo(x int) int { return int(s.set[x-3]) }

//line dcells.w:341
func (s *XCC) setSize(x, v int) { s.set[x-1] = int32(v) }

//line dcells.w:342
func (s *XCC) setPos(x, v int) { s.set[x-2] = int32(v) }

//line dcells.w:343
func (s *XCC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

//line dcells.w:349
func (s *XCC) internName(name string) (num int, ok bool) {
//line dcells.w:350
	if _, dup := s.nameIndex[name]; dup {
//line dcells.w:351
		return 0, false
//line dcells.w:352
	}
//line dcells.w:353
	num = len(s.names)
//line dcells.w:354
	s.names = append(s.names, name)
//line dcells.w:355
	s.nameIndex[name] = num
//line dcells.w:356
	return num, true
//line dcells.w:357
}

//line dcells.w:359
func (s *XCC) internColor(name string) int {
//line dcells.w:360
	if id, ok := s.colorIndex[name]; ok {
//line dcells.w:361
		return id
//line dcells.w:362
	}
//line dcells.w:363
	id := len(s.colorNames)
//line dcells.w:364
	s.colorNames = append(s.colorNames, name)
//line dcells.w:365
	s.colorIndex[name] = id
//line dcells.w:366
	return id
//line dcells.w:367
}

//line dcells.w:377
func (s *XCC) Dance(rd io.Reader) *Result {
//line dcells.w:378
	s.inputMatrix(rd)

//line dcells.w:380
	s.solStream = make(chan []Option)
//line dcells.w:381
	s.heartbeat = make(chan string)

//line dcells.w:383
	go func() {
//line dcells.w:384
		defer close(s.solStream)
//line dcells.w:385
		defer close(s.heartbeat)

//line dcells.w:387

//line dcells.w:406
		if s.Debug {
//line dcells.w:407
			fmt.Fprintf(os.Stderr,
//line dcells.w:408
				"(%d options, %d+%d items, %d entries successfully read)\n",
//line dcells.w:409
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
//line dcells.w:410
		}

//line dcells.w:388
		if s.PulseInterval > 0 {
//line dcells.w:389
			s.pulse = time.NewTicker(s.PulseInterval)
//line dcells.w:390
			defer s.pulse.Stop()
//line dcells.w:391
		}

//line dcells.w:393
		if s.baditem == 0 {
//line dcells.w:394
			s.search(0)
//line dcells.w:395
		}

//line dcells.w:397

//line dcells.w:413
		if s.Debug {
//line dcells.w:414
			plural := "s"
//line dcells.w:415
			if s.count == 1 {
//line dcells.w:416
				plural = ""
//line dcells.w:417
			}
//line dcells.w:418
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
//line dcells.w:419
				s.count, plural, s.updates, s.nodes)
//line dcells.w:420
		}

//line dcells.w:398
	}()

//line dcells.w:400
	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}
//line dcells.w:401
}

//line dcells.w:428
func (s *XCC) search(level int) bool {
//line dcells.w:429
	s.nodes++
//line dcells.w:430
	select {
//line dcells.w:431
	case <-s.ctx.Done():
//line dcells.w:432
		return false
//line dcells.w:433
	default:
//line dcells.w:434
	}
//line dcells.w:435
	s.tick()

//line dcells.w:437
	best, solution := s.chooseItem()
//line dcells.w:438
	if solution {
//line dcells.w:439
		return s.visit(level)
//line dcells.w:440
	}
//line dcells.w:441

//line dcells.w:455
	s.swapOut(best)
//line dcells.w:456
	s.oactive = s.active
//line dcells.w:457
	s.hide(best, 0, 0)
//line dcells.w:458
	s.saveSizes(level)
//line dcells.w:459
	s.choice = ensure(s.choice, level+1)
//line dcells.w:460
	for c := best; c < best+s.size(best); c++ {
//line dcells.w:461
		opt := int(s.set[c])
//line dcells.w:462
		s.choice[level] = int32(opt)
//line dcells.w:463
		if s.commitOption(opt) {
//line dcells.w:464
			if !s.search(level + 1) {
//line dcells.w:465
				return false
//line dcells.w:466
			}
//line dcells.w:467
		}
//line dcells.w:468
		s.restoreSizes(level)
//line dcells.w:469
	}

//line dcells.w:442
	return true
//line dcells.w:443
}

//line dcells.w:481
func (s *XCC) chooseItem() (best int, solution bool) {
//line dcells.w:482
	for s.forced != 0 {
//line dcells.w:483
		s.forced--
//line dcells.w:484
		if f := int(s.force[s.forced]); s.pos(f) < s.active {
//line dcells.w:485
			return f, false
//line dcells.w:486
		}
//line dcells.w:487
	}
//line dcells.w:488

//line dcells.w:500
	score := infSize
//line dcells.w:501
	for k := 0; k < s.active; k++ {
//line dcells.w:502
		x := int(s.item[k])
//line dcells.w:503
		if x >= s.second {
//line dcells.w:504
			continue // secondary items are not branched on
//line dcells.w:505
		}
//line dcells.w:506
		switch sz := s.size(x); {
//line dcells.w:507
		case sz == 0:
//line dcells.w:508
			// unreachable: hide never starves an active primary item
//line dcells.w:509
		case sz == 1:
//line dcells.w:510
			s.force = ensure(s.force, s.forced+1)
//line dcells.w:511
			s.force[s.forced] = int32(x)
//line dcells.w:512
			s.forced++
//line dcells.w:513
		case sz < score || (sz == score && x < best):
//line dcells.w:514
			best, score = x, sz
//line dcells.w:515
		}
//line dcells.w:516
	}

//line dcells.w:489
	if s.forced != 0 {
//line dcells.w:490
		s.forced--
//line dcells.w:491
		return int(s.force[s.forced]), false
//line dcells.w:492
	}
//line dcells.w:493
	return best, score == infSize
//line dcells.w:494
}

//line dcells.w:528
func (s *XCC) commitOption(opt int) bool {
//line dcells.w:529

//line dcells.w:535
	p := s.active
//line dcells.w:536
	s.oactive = s.active
//line dcells.w:537
	for q := opt + 1; q != opt; {
//line dcells.w:538
		c := int(s.nd[q].itm)
//line dcells.w:539
		if c < 0 {
//line dcells.w:540
			q += c
//line dcells.w:541
			continue
//line dcells.w:542
		}
//line dcells.w:543
		if pp := s.pos(c); pp < p {
//line dcells.w:544
			p--
//line dcells.w:545
			cc := int(s.item[p])
//line dcells.w:546
			s.item[p], s.item[pp] = int32(c), int32(cc)
//line dcells.w:547
			s.setPos(cc, pp)
//line dcells.w:548
			s.setPos(c, p)
//line dcells.w:549
			s.updates++
//line dcells.w:550
		}
//line dcells.w:551
		q++
//line dcells.w:552
	}
//line dcells.w:553
	s.active = p

//line dcells.w:530

//line dcells.w:563
	for q := opt + 1; q != opt; {
//line dcells.w:564
		c := int(s.nd[q].itm)
//line dcells.w:565
		if c < 0 {
//line dcells.w:566
			q += c
//line dcells.w:567
			continue
//line dcells.w:568
		}
//line dcells.w:569
		switch {
//line dcells.w:570
		case c < s.second:
//line dcells.w:571
			if !s.hide(c, 0, 1) {
//line dcells.w:572
				s.forced = 0
//line dcells.w:573
				return false
//line dcells.w:574
			}
//line dcells.w:575
		case s.pos(c) < s.oactive:
//line dcells.w:576
			if !s.hide(c, int(s.nd[q].clr), 1) {
//line dcells.w:577
				s.forced = 0
//line dcells.w:578
				return false
//line dcells.w:579
			}
//line dcells.w:580
		}
//line dcells.w:581
		q++
//line dcells.w:582
	}

//line dcells.w:531
	return true
//line dcells.w:532
}

//line dcells.w:592
func (s *XCC) hide(c, color, check int) bool {
//line dcells.w:593
	for rr, end := c, c+s.size(c); rr < end; rr++ {
//line dcells.w:594
		tt := int(s.set[rr])
//line dcells.w:595
		if color != 0 && int(s.nd[tt].clr) == color {
//line dcells.w:596
			continue
//line dcells.w:597
		}
//line dcells.w:598

//line dcells.w:609
		for nn := tt + 1; nn != tt; {
//line dcells.w:610
			u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
//line dcells.w:611
			if u < 0 {
//line dcells.w:612
				nn += u
//line dcells.w:613
				continue
//line dcells.w:614
			}
//line dcells.w:615
			if s.pos(u) < s.oactive {
//line dcells.w:616
				ss := s.size(u) - 1
//line dcells.w:617

//line dcells.w:628
				if ss <= 1 && check != 0 && u < s.second && s.pos(u) < s.active {
//line dcells.w:629
					if ss == 0 {
//line dcells.w:630
						return false
//line dcells.w:631
					}
//line dcells.w:632
					s.force = ensure(s.force, s.forced+1)
//line dcells.w:633
					s.force[s.forced] = int32(u)
//line dcells.w:634
					s.forced++
//line dcells.w:635
				}

//line dcells.w:618
				nnp := int(s.set[u+ss])
//line dcells.w:619
				s.setSize(u, ss)
//line dcells.w:620
				s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
//line dcells.w:621
				s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
//line dcells.w:622
				s.updates++
//line dcells.w:623
			}
//line dcells.w:624
			nn++
//line dcells.w:625
		}

//line dcells.w:599
	}
//line dcells.w:600
	return true
//line dcells.w:601
}

//line dcells.w:640
func (s *XCC) swapOut(x int) {
//line dcells.w:641
	p := s.active - 1
//line dcells.w:642
	s.active = p
//line dcells.w:643
	pp := s.pos(x)
//line dcells.w:644
	cc := int(s.item[p])
//line dcells.w:645
	s.item[p], s.item[pp] = int32(x), int32(cc)
//line dcells.w:646
	s.setPos(cc, pp)
//line dcells.w:647
	s.setPos(x, p)
//line dcells.w:648
	s.updates++
//line dcells.w:649
}

//line dcells.w:660
func (s *XCC) saveSizes(level int) {
//line dcells.w:661
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
//line dcells.w:662
	for p := 0; p < s.active; p++ {
//line dcells.w:663
		s.savestack[s.saveptr+p] = twoints{s.item[p], int32(s.size(int(s.item[p])))}
//line dcells.w:664
	}
//line dcells.w:665
	s.saveptr += s.active
//line dcells.w:666
	s.saved = ensure(s.saved, level+2)
//line dcells.w:667
	s.saved[level+1] = int32(s.saveptr)
//line dcells.w:668
}

//line dcells.w:670
func (s *XCC) restoreSizes(level int) {
//line dcells.w:671
	s.saveptr = int(s.saved[level+1])
//line dcells.w:672
	s.active = s.saveptr - int(s.saved[level])
//line dcells.w:673
	for p := -s.active; p < 0; p++ {
//line dcells.w:674
		e := s.savestack[s.saveptr+p]
//line dcells.w:675
		s.setSize(int(e.l), int(e.r))
//line dcells.w:676
	}
//line dcells.w:677
}

//line dcells.w:685
func (s *XCC) visit(level int) bool {
//line dcells.w:686
	s.count++
//line dcells.w:687
	sol := make([]Option, level)
//line dcells.w:688
	for k := 0; k < level; k++ {
//line dcells.w:689
		sol[k] = s.option(int(s.choice[k]))
//line dcells.w:690
	}
//line dcells.w:691
	select {
//line dcells.w:692
	case <-s.ctx.Done():
//line dcells.w:693
		return false
//line dcells.w:694
	case s.solStream <- sol:
//line dcells.w:695
		return true
//line dcells.w:696
	}
//line dcells.w:697
}

//line dcells.w:703
func (s *XCC) tick() {
//line dcells.w:704
	if s.pulse == nil {
//line dcells.w:705
		return
//line dcells.w:706
	}
//line dcells.w:707
	select {
//line dcells.w:708
	case <-s.pulse.C:
//line dcells.w:709
		select {
//line dcells.w:710
		case s.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", s.nodes, s.count):
//line dcells.w:711
		default:
//line dcells.w:712
		}
//line dcells.w:713
	default:
//line dcells.w:714
	}
//line dcells.w:715
}

//line dcells.w:723
func (s *XCC) option(p int) Option {
//line dcells.w:724
	for s.nd[p-1].itm > 0 {
//line dcells.w:725
		p-- // move to the option's first node
//line dcells.w:726
	}
//line dcells.w:727
	var opt Option
//line dcells.w:728
	for q := p; s.nd[q].itm > 0; q++ {
//line dcells.w:729
		name := s.names[s.itemNo(int(s.nd[q].itm))]
//line dcells.w:730
		if c := s.nd[q].clr; c != 0 {
//line dcells.w:731
			name += ":" + s.colorNames[c]
//line dcells.w:732
		}
//line dcells.w:733
		opt = append(opt, name)
//line dcells.w:734
	}
//line dcells.w:735
	return opt
//line dcells.w:736
}

//line dcells.w:784
const (
//line dcells.w:785
	mccExtra = 5 // set entries below each item base: size, pos, itemNo, slack, bound
//line dcells.w:786
	mccIprop = 5 // input-phase slot spacing
//line dcells.w:787
)

//line dcells.w:795
type MCC struct {
//line dcells.w:796

//line dcells.w:199
	Debug bool // print input summary and final stats to stderr
//line dcells.w:200
	PulseInterval time.Duration // if > 0, offer periodic Heartbeat strings

//line dcells.w:797
	ctx context.Context

//line dcells.w:799

//line dcells.w:808
	nd []node
//line dcells.w:809
	lastNode int
//line dcells.w:810
	item []int32
//line dcells.w:811
	second int
//line dcells.w:812
	lastItm int
//line dcells.w:813
	set []int32
//line dcells.w:814
	itemlen int
//line dcells.w:815
	setlen int
//line dcells.w:816
	active int
//line dcells.w:817
	baditem int
//line dcells.w:818
	osecond int

//line dcells.w:800

//line dcells.w:206
	names []string // interned item names, by item number (1-based)
//line dcells.w:207
	nameIndex map[string]int
//line dcells.w:208
	colorNames []string // interned colors, by id (1-based; 0 means "no color")
//line dcells.w:209
	colorIndex map[string]int

//line dcells.w:801

//line dcells.w:216
	force []int32
//line dcells.w:217
	forced int

//line dcells.w:802

//line dcells.w:821
	included []int32 // option included at each stage, for solution output
//line dcells.w:822
	savestack []threeints
//line dcells.w:823
	saveptr int

//line dcells.w:803

//line dcells.w:220
	updates uint64
//line dcells.w:221
	nodes uint64
//line dcells.w:222
	options uint64
//line dcells.w:223
	count uint64

//line dcells.w:804

//line dcells.w:226
	solStream chan []Option
//line dcells.w:227
	heartbeat chan string
//line dcells.w:228
	pulse *time.Ticker

//line dcells.w:805
}

//line dcells.w:827
func NewMCC() *MCC {
//line dcells.w:828
	return &MCC{
//line dcells.w:829
		second: secondUnset,
//line dcells.w:830
		names: []string{""},
//line dcells.w:831
		nameIndex: make(map[string]int),
//line dcells.w:832
		colorNames: []string{""},
//line dcells.w:833
		colorIndex: make(map[string]int),
//line dcells.w:834
		ctx: context.Background(),
//line dcells.w:835
	}
//line dcells.w:836
}

//line dcells.w:838
func (m *MCC) WithContext(ctx context.Context) *MCC {
//line dcells.w:839
	if ctx == nil {
//line dcells.w:840
		panic("dcells: nil context")
//line dcells.w:841
	}
//line dcells.w:842
	c := *m
//line dcells.w:843
	c.ctx = ctx
//line dcells.w:844
	return &c
//line dcells.w:845
}

//line dcells.w:847
func (m *MCC) Updates() uint64 { return m.updates }

//line dcells.w:848
func (m *MCC) Nodes() uint64 { return m.nodes }

//line dcells.w:852
func (m *MCC) size(x int) int { return int(m.set[x-1]) }

//line dcells.w:853
func (m *MCC) pos(x int) int { return int(m.set[x-2]) }

//line dcells.w:854
func (m *MCC) itemNo(x int) int { return int(m.set[x-3]) }

//line dcells.w:855
func (m *MCC) slack(x int) int { return int(m.set[x-4]) }

//line dcells.w:856
func (m *MCC) bound(x int) int { return int(m.set[x-5]) }

//line dcells.w:858
func (m *MCC) setSize(x, v int) { m.set[x-1] = int32(v) }

//line dcells.w:859
func (m *MCC) setPos(x, v int) { m.set[x-2] = int32(v) }

//line dcells.w:860
func (m *MCC) setItemNo(x, v int) { m.set[x-3] = int32(v) }

//line dcells.w:861
func (m *MCC) setSlack(x, v int) { m.set[x-4] = int32(v) }

//line dcells.w:862
func (m *MCC) setBound(x, v int) { m.set[x-5] = int32(v) }

//line dcells.w:868
func (m *MCC) internName(name string) (num int, ok bool) {
//line dcells.w:869
	if _, dup := m.nameIndex[name]; dup {
//line dcells.w:870
		return 0, false
//line dcells.w:871
	}
//line dcells.w:872
	num = len(m.names)
//line dcells.w:873
	m.names = append(m.names, name)
//line dcells.w:874
	m.nameIndex[name] = num
//line dcells.w:875
	return num, true
//line dcells.w:876
}

//line dcells.w:878
func (m *MCC) internColor(name string) int {
//line dcells.w:879
	if id, ok := m.colorIndex[name]; ok {
//line dcells.w:880
		return id
//line dcells.w:881
	}
//line dcells.w:882
	id := len(m.colorNames)
//line dcells.w:883
	m.colorNames = append(m.colorNames, name)
//line dcells.w:884
	m.colorIndex[name] = id
//line dcells.w:885
	return id
//line dcells.w:886
}

//line dcells.w:891
func (m *MCC) Dance(rd io.Reader) *Result {
//line dcells.w:892
	m.inputMatrix(rd)

//line dcells.w:894
	m.solStream = make(chan []Option)
//line dcells.w:895
	m.heartbeat = make(chan string)

//line dcells.w:897
	go func() {
//line dcells.w:898
		defer close(m.solStream)
//line dcells.w:899
		defer close(m.heartbeat)

//line dcells.w:901

//line dcells.w:918
		if m.Debug {
//line dcells.w:919
			fmt.Fprintf(os.Stderr,
//line dcells.w:920
				"(%d options, %d+%d items, %d entries successfully read)\n",
//line dcells.w:921
				m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
//line dcells.w:922
		}

//line dcells.w:902
		if m.PulseInterval > 0 {
//line dcells.w:903
			m.pulse = time.NewTicker(m.PulseInterval)
//line dcells.w:904
			defer m.pulse.Stop()
//line dcells.w:905
		}

//line dcells.w:907
		if m.baditem == 0 {
//line dcells.w:908
			m.search(0)
//line dcells.w:909
		}

//line dcells.w:911

//line dcells.w:925
		if m.Debug {
//line dcells.w:926
			plural := "s"
//line dcells.w:927
			if m.count == 1 {
//line dcells.w:928
				plural = ""
//line dcells.w:929
			}
//line dcells.w:930
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
//line dcells.w:931
				m.count, plural, m.updates, m.nodes)
//line dcells.w:932
		}

//line dcells.w:912
	}()

//line dcells.w:914
	return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}
//line dcells.w:915
}

//line dcells.w:940
func (m *MCC) search(stage int) bool {
//line dcells.w:941
	m.nodes++
//line dcells.w:942
	select {
//line dcells.w:943
	case <-m.ctx.Done():
//line dcells.w:944
		return false
//line dcells.w:945
	default:
//line dcells.w:946
	}
//line dcells.w:947
	m.tick()

//line dcells.w:949

//line dcells.w:966
	for m.forced != 0 {
//line dcells.w:967
		m.forced--
//line dcells.w:968
		if bi := int(m.force[m.forced]); m.pos(bi) < m.active {
//line dcells.w:969
			return m.forcedMove(stage, bi)
//line dcells.w:970
		}
//line dcells.w:971
	}

//line dcells.w:951
	best, score := m.chooseBest()
//line dcells.w:952
	if m.forced != 0 {
//line dcells.w:953
		m.forced--
//line dcells.w:954
		return m.forcedMove(stage, int(m.force[m.forced]))
//line dcells.w:955
	}
//line dcells.w:956
	if score == infSize {
//line dcells.w:957
		return m.visit(stage)
//line dcells.w:958
	}
//line dcells.w:959

//line dcells.w:980
	mark := m.saveState()
//line dcells.w:981
	opt := int(m.set[best])
//line dcells.w:982
	m.included = ensure(m.included, stage+1)
//line dcells.w:983
	m.included[stage] = int32(opt)

//line dcells.w:985
	if m.includeOption(opt) {
//line dcells.w:986
		if !m.search(stage + 1) {
//line dcells.w:987
			m.saveptr = mark
//line dcells.w:988
			return false
//line dcells.w:989
		}
//line dcells.w:990
	}
//line dcells.w:991
	if score != 1 {
//line dcells.w:992
		m.restoreState(mark)
//line dcells.w:993
		if m.removeOption(opt) {
//line dcells.w:994
			if !m.search(stage) {
//line dcells.w:995
				m.saveptr = mark
//line dcells.w:996
				return false
//line dcells.w:997
			}
//line dcells.w:998
		}
//line dcells.w:999
	}
//line dcells.w:1000
	m.saveptr = mark

//line dcells.w:960
	return true
//line dcells.w:961
}

//line dcells.w:1009
func (m *MCC) forcedMove(stage, bi int) bool {
//line dcells.w:1010
	opt := int(m.set[bi])
//line dcells.w:1011
	m.included = ensure(m.included, stage+1)
//line dcells.w:1012
	m.included[stage] = int32(opt)
//line dcells.w:1013
	if m.includeOption(opt) {
//line dcells.w:1014
		return m.search(stage + 1)
//line dcells.w:1015
	}
//line dcells.w:1016
	return true
//line dcells.w:1017
}

//line dcells.w:1026
func (m *MCC) chooseBest() (best, score int) {
//line dcells.w:1027
	score = infSize
//line dcells.w:1028
	bestS, bestL := 0, 0
//line dcells.w:1029
	for k := 0; k < m.active; k++ {
//line dcells.w:1030
		x := int(m.item[k])
//line dcells.w:1031
		if x >= m.second {
//line dcells.w:1032
			continue
//line dcells.w:1033
		}
//line dcells.w:1034
		s := m.slack(x)
//line dcells.w:1035
		if b := m.bound(x); s > b {
//line dcells.w:1036
			s = b
//line dcells.w:1037
		}
//line dcells.w:1038
		t := m.size(x) + s - m.bound(x) + 1
//line dcells.w:1039
		switch {
//line dcells.w:1040
		case t == 1:
//line dcells.w:1041
			for i := m.bound(x) - m.slack(x); i > 0; i-- {
//line dcells.w:1042
				m.force = ensure(m.force, m.forced+1)
//line dcells.w:1043
				m.force[m.forced] = int32(x)
//line dcells.w:1044
				m.forced++
//line dcells.w:1045
			}
//line dcells.w:1046
		case t <= score && (t < score || (s <= bestS && (s < bestS ||
//line dcells.w:1047
			(m.size(x) >= bestL && (m.size(x) > bestL || x < best))))):
//line dcells.w:1048
			score, best, bestS, bestL = t, x, s, m.size(x)
//line dcells.w:1049
		}
//line dcells.w:1050
	}
//line dcells.w:1051
	return best, score
//line dcells.w:1052
}

//line dcells.w:1061
func (m *MCC) includeOption(opt int) bool {
//line dcells.w:1062
	for m.nd[opt-1].itm > 0 {
//line dcells.w:1063
		opt--
//line dcells.w:1064
	}
//line dcells.w:1065
	for ; ; opt++ {
//line dcells.w:1066
		ii := int(m.nd[opt].itm)
//line dcells.w:1067
		if ii <= 0 {
//line dcells.w:1068
			break
//line dcells.w:1069
		}
//line dcells.w:1070
		pp := int(m.nd[opt].loc)
//line dcells.w:1071
		if m.pos(ii) >= m.active {
//line dcells.w:1072
			if ii >= m.second {
//line dcells.w:1073
				continue // secondary item already purified
//line dcells.w:1074
			}
//line dcells.w:1075
			return false // cannot happen for a well-formed active option
//line dcells.w:1076
		}
//line dcells.w:1077
		if !m.coverOrCommit(ii, opt, pp) {
//line dcells.w:1078
			return false
//line dcells.w:1079
		}
//line dcells.w:1080
	}
//line dcells.w:1081
	return true
//line dcells.w:1082
}

//line dcells.w:1090
func (m *MCC) coverOrCommit(ii, cur, p int) bool {
//line dcells.w:1091
	if ii < m.second {
//line dcells.w:1092
		m.setBound(ii, m.bound(ii)-1)
//line dcells.w:1093
	}
//line dcells.w:1094
	if ii >= m.second || m.bound(ii) == 0 {
//line dcells.w:1095

//line dcells.w:1108
		ss := m.size(ii)
//line dcells.w:1109
		c := 0
//line dcells.w:1110
		if ii >= m.second {
//line dcells.w:1111
			c = int(m.nd[cur].clr)
//line dcells.w:1112
		}
//line dcells.w:1113
		for s := ii + ss - 1; s >= ii; s-- {
//line dcells.w:1114
			if s == p {
//line dcells.w:1115
				continue
//line dcells.w:1116
			}
//line dcells.w:1117
			optp := int(m.set[s])
//line dcells.w:1118
			if c == 0 || int(m.nd[optp].clr) != c {
//line dcells.w:1119
				if !m.removeFromOtherSets(optp) {
//line dcells.w:1120
					return false
//line dcells.w:1121
				}
//line dcells.w:1122
			}
//line dcells.w:1123
		}
//line dcells.w:1124
		m.deactivate(ii)

//line dcells.w:1096
	} else {
//line dcells.w:1097

//line dcells.w:1131
		ss := m.size(ii) - 1
//line dcells.w:1132
		if ss < m.bound(ii)-m.slack(ii) {
//line dcells.w:1133
			m.forced = 0
//line dcells.w:1134
			return false // ii would be wiped out
//line dcells.w:1135
		}
//line dcells.w:1136
		if ss == 0 {
//line dcells.w:1137
			m.deactivate(ii)
//line dcells.w:1138
		} else {
//line dcells.w:1139

//line dcells.w:1146
			nnp := int(m.set[ii+ss])
//line dcells.w:1147
			m.setSize(ii, ss)
//line dcells.w:1148
			m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
//line dcells.w:1149
			m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
//line dcells.w:1150
			m.updates++

//line dcells.w:1140
		}

//line dcells.w:1098
	}
//line dcells.w:1099
	return true
//line dcells.w:1100
}

//line dcells.w:1156
func (m *MCC) removeFromOtherSets(optp int) bool {
//line dcells.w:1157
	cur := optp
//line dcells.w:1158
	for m.nd[cur-1].itm > 0 {
//line dcells.w:1159
		cur--
//line dcells.w:1160
	}
//line dcells.w:1161
	for ; ; cur++ {
//line dcells.w:1162
		ii := int(m.nd[cur].itm)
//line dcells.w:1163
		if ii <= 0 {
//line dcells.w:1164
			break
//line dcells.w:1165
		}
//line dcells.w:1166
		p := int(m.nd[cur].loc)
//line dcells.w:1167
		if p >= m.second && m.pos(ii) >= m.active {
//line dcells.w:1168
			continue
//line dcells.w:1169
		}
//line dcells.w:1170
		ss := m.size(ii) - 1
//line dcells.w:1171
		if p < m.second {
//line dcells.w:1172
			if ss < m.bound(ii)-m.slack(ii) {
//line dcells.w:1173
				m.forced = 0
//line dcells.w:1174
				return false
//line dcells.w:1175
			}
//line dcells.w:1176
			if ss == 0 {
//line dcells.w:1177
				m.deactivate(ii)
//line dcells.w:1178
			}
//line dcells.w:1179
		}
//line dcells.w:1180
		if ss > 0 {
//line dcells.w:1181

//line dcells.w:1146
			nnp := int(m.set[ii+ss])
//line dcells.w:1147
			m.setSize(ii, ss)
//line dcells.w:1148
			m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
//line dcells.w:1149
			m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
//line dcells.w:1150
			m.updates++

//line dcells.w:1182
		}
//line dcells.w:1183
	}
//line dcells.w:1184
	return true
//line dcells.w:1185
}

//line dcells.w:1192
func (m *MCC) removeOption(cur int) bool {
//line dcells.w:1193
	for m.nd[cur-1].itm > 0 {
//line dcells.w:1194
		cur--
//line dcells.w:1195
	}
//line dcells.w:1196
	for ; ; cur++ {
//line dcells.w:1197
		ii := int(m.nd[cur].itm)
//line dcells.w:1198
		if ii <= 0 {
//line dcells.w:1199
			break
//line dcells.w:1200
		}
//line dcells.w:1201
		p := int(m.nd[cur].loc)
//line dcells.w:1202
		if p >= m.second && m.pos(ii) >= m.active {
//line dcells.w:1203
			continue
//line dcells.w:1204
		}
//line dcells.w:1205
		ss := m.size(ii) - 1
//line dcells.w:1206
		if p < m.second {
//line dcells.w:1207
			if ss < m.bound(ii)-m.slack(ii) {
//line dcells.w:1208
				return false
//line dcells.w:1209
			}
//line dcells.w:1210
			if ss == 0 {
//line dcells.w:1211
				m.deactivate(ii)
//line dcells.w:1212
			}
//line dcells.w:1213
		}
//line dcells.w:1214
		if ss > 0 {
//line dcells.w:1215

//line dcells.w:1146
			nnp := int(m.set[ii+ss])
//line dcells.w:1147
			m.setSize(ii, ss)
//line dcells.w:1148
			m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
//line dcells.w:1149
			m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
//line dcells.w:1150
			m.updates++

//line dcells.w:1216
		}
//line dcells.w:1217
	}
//line dcells.w:1218
	return true
//line dcells.w:1219
}

//line dcells.w:1223
func (m *MCC) deactivate(ii int) {
//line dcells.w:1224
	m.active--
//line dcells.w:1225
	p := m.pos(ii)
//line dcells.w:1226
	iii := int(m.item[m.active])
//line dcells.w:1227
	m.item[m.active], m.item[p] = int32(ii), int32(iii)
//line dcells.w:1228
	m.setPos(ii, m.active)
//line dcells.w:1229
	m.setPos(iii, p)
//line dcells.w:1230
}

//line dcells.w:1237
func (m *MCC) saveState() int {
//line dcells.w:1238
	mark := m.saveptr
//line dcells.w:1239
	m.savestack = ensure(m.savestack, m.saveptr+m.active)
//line dcells.w:1240
	for p := 0; p < m.active; p++ {
//line dcells.w:1241
		x := int(m.item[p])
//line dcells.w:1242
		e := threeints{l: int32(x), s: int32(m.size(x))}
//line dcells.w:1243
		if x < m.second {
//line dcells.w:1244
			e.b = int32(m.bound(x))
//line dcells.w:1245
		}
//line dcells.w:1246
		m.savestack[m.saveptr] = e
//line dcells.w:1247
		m.saveptr++
//line dcells.w:1248
	}
//line dcells.w:1249
	return mark
//line dcells.w:1250
}

//line dcells.w:1252
func (m *MCC) restoreState(mark int) {
//line dcells.w:1253
	m.active = m.saveptr - mark
//line dcells.w:1254
	for p := 0; p < m.active; p++ {
//line dcells.w:1255
		e := m.savestack[mark+p]
//line dcells.w:1256
		m.setSize(int(e.l), int(e.s))
//line dcells.w:1257
		if int(e.l) < m.second {
//line dcells.w:1258
			m.setBound(int(e.l), int(e.b))
//line dcells.w:1259
		}
//line dcells.w:1260
	}
//line dcells.w:1261
	m.saveptr = mark
//line dcells.w:1262
}

//line dcells.w:1268
func (m *MCC) visit(stage int) bool {
//line dcells.w:1269
	m.count++
//line dcells.w:1270
	sol := make([]Option, stage)
//line dcells.w:1271
	for k := 0; k < stage; k++ {
//line dcells.w:1272
		sol[k] = m.option(int(m.included[k]))
//line dcells.w:1273
	}
//line dcells.w:1274
	select {
//line dcells.w:1275
	case <-m.ctx.Done():
//line dcells.w:1276
		return false
//line dcells.w:1277
	case m.solStream <- sol:
//line dcells.w:1278
		return true
//line dcells.w:1279
	}
//line dcells.w:1280
}

//line dcells.w:1283
func (m *MCC) tick() {
//line dcells.w:1284
	if m.pulse == nil {
//line dcells.w:1285
		return
//line dcells.w:1286
	}
//line dcells.w:1287
	select {
//line dcells.w:1288
	case <-m.pulse.C:
//line dcells.w:1289
		select {
//line dcells.w:1290
		case m.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", m.nodes, m.count):
//line dcells.w:1291
		default:
//line dcells.w:1292
		}
//line dcells.w:1293
	default:
//line dcells.w:1294
	}
//line dcells.w:1295
}

//line dcells.w:1298
func (m *MCC) option(p int) Option {
//line dcells.w:1299
	for m.nd[p-1].itm > 0 {
//line dcells.w:1300
		p--
//line dcells.w:1301
	}
//line dcells.w:1302
	var opt Option
//line dcells.w:1303
	for q := p; m.nd[q].itm > 0; q++ {
//line dcells.w:1304
		name := m.names[m.itemNo(int(m.nd[q].itm))]
//line dcells.w:1305
		if c := m.nd[q].clr; c != 0 {
//line dcells.w:1306
			name += ":" + m.colorNames[c]
//line dcells.w:1307
		}
//line dcells.w:1308
		opt = append(opt, name)
//line dcells.w:1309
	}
//line dcells.w:1310
	return opt
//line dcells.w:1311
}

//line dcells.w:1342
type parseError struct{ msg string }

//line dcells.w:1344
func (e *parseError) Error() string { return e.msg }

//line dcells.w:1346
func failf(format string, a ...any) {
//line dcells.w:1347
	panic(&parseError{fmt.Sprintf(format, a...)})
//line dcells.w:1348
}

//line dcells.w:1355
func isspace(c byte) bool {
//line dcells.w:1356
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
//line dcells.w:1357
}

//line dcells.w:1359
func nextLine(br *bufio.Reader) (buf []byte, ok bool) {
//line dcells.w:1360
	str, err := br.ReadString('\n')
//line dcells.w:1361
	if len(str) == 0 && err != nil {
//line dcells.w:1362
		return nil, false
//line dcells.w:1363
	}
//line dcells.w:1364
	buf = make([]byte, len(str)+1)
//line dcells.w:1365
	copy(buf, str)
//line dcells.w:1366
	return buf, true
//line dcells.w:1367
}

//line dcells.w:1373
func skipSpace(buf []byte, p int) int {
//line dcells.w:1374
	for isspace(buf[p]) {
//line dcells.w:1375
		p++
//line dcells.w:1376
	}
//line dcells.w:1377
	return p
//line dcells.w:1378
}

//line dcells.w:1380
func token(buf []byte, p int, stopColon bool) (string, int) {
//line dcells.w:1381
	start := p
//line dcells.w:1382
	for buf[p] != 0 && !isspace(buf[p]) && !(stopColon && buf[p] == ':') {
//line dcells.w:1383
		p++
//line dcells.w:1384
	}
//line dcells.w:1385
	return string(buf[start:p]), p
//line dcells.w:1386
}

//line dcells.w:1391
func (s *XCC) inputMatrix(rd io.Reader) {
//line dcells.w:1392
	br := bufio.NewReader(rd)
//line dcells.w:1393
	s.readItemNames(br)
//line dcells.w:1394
	s.readOptions(br)
//line dcells.w:1395
}

//line dcells.w:1407
func (s *XCC) readItemNames(br *bufio.Reader) {
//line dcells.w:1408

//line dcells.w:1430
	var buf []byte
//line dcells.w:1431
	var p int
//line dcells.w:1432
	found := false
//line dcells.w:1433
	for {
//line dcells.w:1434
		var ok bool
//line dcells.w:1435
		if buf, ok = nextLine(br); !ok {
//line dcells.w:1436
			break
//line dcells.w:1437
		}
//line dcells.w:1438
		if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
//line dcells.w:1439
			found = true
//line dcells.w:1440
			break
//line dcells.w:1441
		}
//line dcells.w:1442
	}
//line dcells.w:1443
	if !found {
//line dcells.w:1444
		failf("no items")
//line dcells.w:1445
	}

//line dcells.w:1409
	for buf[p] != 0 {
//line dcells.w:1410
		name, next := token(buf, p, false)
//line dcells.w:1411
		if name == "|" {
//line dcells.w:1412
			if s.second != secondUnset {
//line dcells.w:1413
				failf("item name line contains | twice")
//line dcells.w:1414
			}
//line dcells.w:1415
			s.second = len(s.names) // the next item's number
//line dcells.w:1416
		} else {
//line dcells.w:1417
			if strings.ContainsAny(name, ":|") {
//line dcells.w:1418
				failf("illegal character in item name: %q", name)
//line dcells.w:1419
			}
//line dcells.w:1420
			if _, ok := s.internName(name); !ok {
//line dcells.w:1421
				failf("duplicate item name: %s", name)
//line dcells.w:1422
			}
//line dcells.w:1423
		}
//line dcells.w:1424
		p = skipSpace(buf, next)
//line dcells.w:1425
	}
//line dcells.w:1426
	s.lastItm = len(s.names) // items + 1 (names[0] is unused)
//line dcells.w:1427
}

//line dcells.w:1450
func (s *XCC) readOptions(br *bufio.Reader) {
//line dcells.w:1451
	for {
//line dcells.w:1452
		buf, ok := nextLine(br)
//line dcells.w:1453
		if !ok {
//line dcells.w:1454
			break
//line dcells.w:1455
		}
//line dcells.w:1456
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
//line dcells.w:1457
			continue
//line dcells.w:1458
		}
//line dcells.w:1459
		s.readOption(buf)
//line dcells.w:1460
	}
//line dcells.w:1461
	s.finalize()
//line dcells.w:1462
}

//line dcells.w:1470
func (s *XCC) readOption(buf []byte) {
//line dcells.w:1471
	spacer := s.lastNode
//line dcells.w:1472
	hasPrimary := false
//line dcells.w:1473
	for p := skipSpace(buf, 0); buf[p] != 0; {
//line dcells.w:1474

//line dcells.w:1490
		name, next := token(buf, p, true)
//line dcells.w:1491
		if name == "" {
//line dcells.w:1492
			failf("empty item name")
//line dcells.w:1493
		}
//line dcells.w:1494
		m, known := s.nameIndex[name]
//line dcells.w:1495
		if !known {
//line dcells.w:1496
			failf("unknown item name: %s", name)
//line dcells.w:1497
		}
//line dcells.w:1498
		s.createNode(m, spacer, &hasPrimary)
//line dcells.w:1499
		if buf[next] == ':' {
//line dcells.w:1500
			if m < s.second {
//line dcells.w:1501
				failf("primary item must be uncolored: %s", name)
//line dcells.w:1502
			}
//line dcells.w:1503
			color, ce := token(buf, next+1, false)
//line dcells.w:1504
			if color == "" {
//line dcells.w:1505
				failf("missing color after %s:", name)
//line dcells.w:1506
			}
//line dcells.w:1507
			s.nd[s.lastNode].clr = int32(s.internColor(color))
//line dcells.w:1508
			next = ce
//line dcells.w:1509
		} else {
//line dcells.w:1510
			s.nd[s.lastNode].clr = 0
//line dcells.w:1511
		}
//line dcells.w:1512
		p = skipSpace(buf, next)

//line dcells.w:1475
	}

//line dcells.w:1477
	if !hasPrimary {
//line dcells.w:1478

//line dcells.w:1517
		for s.lastNode > spacer {
//line dcells.w:1518
			slot := int(s.nd[s.lastNode].itm) << 2
//line dcells.w:1519
			s.setSize(slot, s.size(slot)-1)
//line dcells.w:1520
			s.setPos(slot, spacer-1)
//line dcells.w:1521
			s.lastNode--
//line dcells.w:1522
		}

//line dcells.w:1479
		return
//line dcells.w:1480
	}
//line dcells.w:1481
	s.nd[spacer].loc = int32(s.lastNode - spacer)
//line dcells.w:1482
	s.lastNode++
//line dcells.w:1483
	s.nd = ensure(s.nd, s.lastNode+1)
//line dcells.w:1484
	s.options++
//line dcells.w:1485
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
//line dcells.w:1486
}

//line dcells.w:1529
func (s *XCC) createNode(m, spacer int, hasPrimary *bool) {
//line dcells.w:1530
	slot := m << 2
//line dcells.w:1531
	s.set = ensure(s.set, slot)
//line dcells.w:1532
	if s.pos(slot) > spacer {
//line dcells.w:1533
		failf("duplicate item name in this option: %s", s.names[m])
//line dcells.w:1534
	}
//line dcells.w:1535
	s.lastNode++
//line dcells.w:1536
	s.nd = ensure(s.nd, s.lastNode+1)
//line dcells.w:1537
	t := s.size(slot)
//line dcells.w:1538
	s.nd[s.lastNode].itm = int32(m)
//line dcells.w:1539
	s.nd[s.lastNode].loc = int32(t)
//line dcells.w:1540
	if m < s.second {
//line dcells.w:1541
		*hasPrimary = true
//line dcells.w:1542
	}
//line dcells.w:1543
	s.setSize(slot, t+1)
//line dcells.w:1544
	s.setPos(slot, s.lastNode)
//line dcells.w:1545
}

//line dcells.w:1550
func (s *XCC) finalize() {
//line dcells.w:1551

//line dcells.w:1561
	s.active, s.itemlen = s.lastItm-1, s.lastItm-1
//line dcells.w:1562
	s.item = ensure(s.item, s.itemlen)
//line dcells.w:1563
	s.set = ensure(s.set, (s.itemlen<<2)+1) // all input slots readable

//line dcells.w:1565
	j := primExtra
//line dcells.w:1566
	k := 0
//line dcells.w:1567
	for ; k < s.itemlen; k++ {
//line dcells.w:1568
		s.item[k] = int32(j)
//line dcells.w:1569
		j += primExtra + s.size((k+1)<<2)
//line dcells.w:1570
	}
//line dcells.w:1571
	s.setlen = j - primExtra
//line dcells.w:1572
	s.set = ensure(s.set, j+1)
//line dcells.w:1573
	if s.second == secondUnset {
//line dcells.w:1574
		s.osecond, s.second = s.active, j
//line dcells.w:1575
	} else {
//line dcells.w:1576
		s.osecond = s.second - 1
//line dcells.w:1577
	}

//line dcells.w:1552

//line dcells.w:1583
	for ; k != 0; k-- {
//line dcells.w:1584
		base := int(s.item[k-1])
//line dcells.w:1585
		if k == s.second {
//line dcells.w:1586
			s.second = base
//line dcells.w:1587
		}
//line dcells.w:1588
		s.setSize(base, s.size(k<<2))
//line dcells.w:1589
		if s.size(base) == 0 && k <= s.osecond {
//line dcells.w:1590
			s.baditem = k
//line dcells.w:1591
		}
//line dcells.w:1592
		s.setPos(base, k-1)
//line dcells.w:1593
		s.setItemNo(base, k)
//line dcells.w:1594
	}

//line dcells.w:1553

//line dcells.w:1600
	for k = 1; k < s.lastNode; k++ {
//line dcells.w:1601
		if s.nd[k].itm < 0 {
//line dcells.w:1602
			continue
//line dcells.w:1603
		}
//line dcells.w:1604
		base := int(s.item[int(s.nd[k].itm)-1])
//line dcells.w:1605
		loc := base + int(s.nd[k].loc)
//line dcells.w:1606
		s.nd[k].itm = int32(base)
//line dcells.w:1607
		s.nd[k].loc = int32(loc)
//line dcells.w:1608
		s.set[loc] = int32(k)
//line dcells.w:1609
	}

//line dcells.w:1554
}

//line dcells.w:1614
func (m *MCC) inputMatrix(rd io.Reader) {
//line dcells.w:1615
	br := bufio.NewReader(rd)
//line dcells.w:1616
	m.readItemNames(br)
//line dcells.w:1617
	m.readOptions(br)
//line dcells.w:1618
}

//line dcells.w:1631
func mustAtoi(s string) int {
//line dcells.w:1632
	n, err := strconv.Atoi(s)
//line dcells.w:1633
	if err != nil || n < 0 {
//line dcells.w:1634
		failf("illegal number in bound spec: %q", s)
//line dcells.w:1635
	}
//line dcells.w:1636
	return n
//line dcells.w:1637
}

//line dcells.w:1639
func parseItemSpec(tok string, inSecondary bool) (name string, lower, upper int) {
//line dcells.w:1640
	if i := strings.IndexByte(tok, '|'); i >= 0 {
//line dcells.w:1641

//line dcells.w:1655
		if inSecondary {
//line dcells.w:1656
			failf("secondary item cannot have a multiplicity: %q", tok)
//line dcells.w:1657
		}
//line dcells.w:1658
		spec, nm := tok[:i], tok[i+1:]
//line dcells.w:1659
		if j := strings.IndexByte(spec, ':'); j >= 0 {
//line dcells.w:1660
			lower, upper = mustAtoi(spec[:j]), mustAtoi(spec[j+1:])
//line dcells.w:1661
		} else {
//line dcells.w:1662
			upper = mustAtoi(spec)
//line dcells.w:1663
			lower = upper
//line dcells.w:1664
		}
//line dcells.w:1665
		if upper == 0 {
//line dcells.w:1666
			failf("upper bound is zero: %q", tok)
//line dcells.w:1667
		}
//line dcells.w:1668
		if lower > upper {
//line dcells.w:1669
			failf("lower bound exceeds upper bound: %q", tok)
//line dcells.w:1670
		}
//line dcells.w:1671
		name = nm

//line dcells.w:1642
	} else {
//line dcells.w:1643
		name, lower, upper = tok, 1, 1
//line dcells.w:1644
	}
//line dcells.w:1645
	if name == "" {
//line dcells.w:1646
		failf("item name empty: %q", tok)
//line dcells.w:1647
	}
//line dcells.w:1648
	if strings.ContainsAny(name, ":|") {
//line dcells.w:1649
		failf("illegal character in item name: %q", name)
//line dcells.w:1650
	}
//line dcells.w:1651
	return
//line dcells.w:1652
}

//line dcells.w:1678
func (m *MCC) readItemNames(br *bufio.Reader) {
//line dcells.w:1679

//line dcells.w:1704
	var buf []byte
//line dcells.w:1705
	var p int
//line dcells.w:1706
	found := false
//line dcells.w:1707
	for {
//line dcells.w:1708
		var ok bool
//line dcells.w:1709
		if buf, ok = nextLine(br); !ok {
//line dcells.w:1710
			break
//line dcells.w:1711
		}
//line dcells.w:1712
		if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
//line dcells.w:1713
			found = true
//line dcells.w:1714
			break
//line dcells.w:1715
		}
//line dcells.w:1716
	}
//line dcells.w:1717
	if !found {
//line dcells.w:1718
		failf("no items")
//line dcells.w:1719
	}

//line dcells.w:1680
	for buf[p] != 0 {
//line dcells.w:1681
		tok, next := token(buf, p, false)
//line dcells.w:1682
		if tok == "|" {
//line dcells.w:1683
			if m.second != secondUnset {
//line dcells.w:1684
				failf("item name line contains | twice")
//line dcells.w:1685
			}
//line dcells.w:1686
			m.second = len(m.names) // the next item's number
//line dcells.w:1687
		} else {
//line dcells.w:1688
			name, lower, upper := parseItemSpec(tok, m.second != secondUnset)
//line dcells.w:1689
			num, ok := m.internName(name)
//line dcells.w:1690
			if !ok {
//line dcells.w:1691
				failf("duplicate item name: %s", name)
//line dcells.w:1692
			}
//line dcells.w:1693
			slot := num * mccIprop
//line dcells.w:1694
			m.set = ensure(m.set, slot)
//line dcells.w:1695
			m.setSlack(slot, upper-lower)
//line dcells.w:1696
			m.setBound(slot, upper)
//line dcells.w:1697
		}
//line dcells.w:1698
		p = skipSpace(buf, next)
//line dcells.w:1699
	}
//line dcells.w:1700
	m.lastItm = len(m.names)
//line dcells.w:1701
}

//line dcells.w:1723
func (m *MCC) readOptions(br *bufio.Reader) {
//line dcells.w:1724
	for {
//line dcells.w:1725
		buf, ok := nextLine(br)
//line dcells.w:1726
		if !ok {
//line dcells.w:1727
			break
//line dcells.w:1728
		}
//line dcells.w:1729
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
//line dcells.w:1730
			continue
//line dcells.w:1731
		}
//line dcells.w:1732
		m.readOption(buf)
//line dcells.w:1733
	}
//line dcells.w:1734
	m.finalize()
//line dcells.w:1735
}

//line dcells.w:1738
func (m *MCC) readOption(buf []byte) {
//line dcells.w:1739
	spacer := m.lastNode
//line dcells.w:1740
	hasPrimary := false
//line dcells.w:1741
	for p := skipSpace(buf, 0); buf[p] != 0; {
//line dcells.w:1742

//line dcells.w:1757
		name, next := token(buf, p, true)
//line dcells.w:1758
		if name == "" {
//line dcells.w:1759
			failf("empty item name")
//line dcells.w:1760
		}
//line dcells.w:1761
		num, known := m.nameIndex[name]
//line dcells.w:1762
		if !known {
//line dcells.w:1763
			failf("unknown item name: %s", name)
//line dcells.w:1764
		}
//line dcells.w:1765
		m.createNode(num, spacer, &hasPrimary)
//line dcells.w:1766
		if buf[next] == ':' {
//line dcells.w:1767
			if num < m.second {
//line dcells.w:1768
				failf("primary item must be uncolored: %s", name)
//line dcells.w:1769
			}
//line dcells.w:1770
			color, ce := token(buf, next+1, false)
//line dcells.w:1771
			if color == "" {
//line dcells.w:1772
				failf("missing color after %s:", name)
//line dcells.w:1773
			}
//line dcells.w:1774
			m.nd[m.lastNode].clr = int32(m.internColor(color))
//line dcells.w:1775
			next = ce
//line dcells.w:1776
		} else {
//line dcells.w:1777
			m.nd[m.lastNode].clr = 0
//line dcells.w:1778
		}
//line dcells.w:1779
		p = skipSpace(buf, next)

//line dcells.w:1743
	}

//line dcells.w:1745
	if !hasPrimary {
//line dcells.w:1746

//line dcells.w:1782
		for m.lastNode > spacer {
//line dcells.w:1783
			slot := int(m.nd[m.lastNode].itm) * mccIprop
//line dcells.w:1784
			m.setSize(slot, m.size(slot)-1)
//line dcells.w:1785
			m.setPos(slot, spacer-1)
//line dcells.w:1786
			m.lastNode--
//line dcells.w:1787
		}

//line dcells.w:1747
		return
//line dcells.w:1748
	}
//line dcells.w:1749
	m.nd[spacer].loc = int32(m.lastNode - spacer)
//line dcells.w:1750
	m.lastNode++
//line dcells.w:1751
	m.nd = ensure(m.nd, m.lastNode+1)
//line dcells.w:1752
	m.options++
//line dcells.w:1753
	m.nd[m.lastNode].itm = int32(spacer + 1 - m.lastNode)
//line dcells.w:1754
}

//line dcells.w:1790
func (m *MCC) createNode(num, spacer int, hasPrimary *bool) {
//line dcells.w:1791
	slot := num * mccIprop
//line dcells.w:1792
	m.set = ensure(m.set, slot)
//line dcells.w:1793
	if m.pos(slot) > spacer {
//line dcells.w:1794
		failf("duplicate item name in this option: %s", m.names[num])
//line dcells.w:1795
	}
//line dcells.w:1796
	m.lastNode++
//line dcells.w:1797
	m.nd = ensure(m.nd, m.lastNode+1)
//line dcells.w:1798
	t := m.size(slot)
//line dcells.w:1799
	m.nd[m.lastNode].itm = int32(num)
//line dcells.w:1800
	m.nd[m.lastNode].loc = int32(t)
//line dcells.w:1801
	if num < m.second {
//line dcells.w:1802
		*hasPrimary = true
//line dcells.w:1803
	}
//line dcells.w:1804
	m.setSize(slot, t+1)
//line dcells.w:1805
	m.setPos(slot, m.lastNode)
//line dcells.w:1806
}

//line dcells.w:1811
func (m *MCC) finalize() {
//line dcells.w:1812

//line dcells.w:1819
	m.active, m.itemlen = m.lastItm-1, m.lastItm-1
//line dcells.w:1820
	m.item = ensure(m.item, m.itemlen)
//line dcells.w:1821
	m.set = ensure(m.set, m.itemlen*mccIprop+1) // all input slots readable

//line dcells.w:1823
	j := mccExtra
//line dcells.w:1824
	k := 0
//line dcells.w:1825
	for ; k < m.itemlen; k++ {
//line dcells.w:1826
		m.item[k] = int32(j)
//line dcells.w:1827
		j += mccExtra + m.size((k+1)*mccIprop)
//line dcells.w:1828
	}
//line dcells.w:1829
	m.setlen = j - mccExtra
//line dcells.w:1830
	m.set = ensure(m.set, j+1)
//line dcells.w:1831
	if m.second == secondUnset {
//line dcells.w:1832
		m.osecond, m.second = m.active, j
//line dcells.w:1833
	} else {
//line dcells.w:1834
		m.osecond = m.second - 1
//line dcells.w:1835
	}

//line dcells.w:1813

//line dcells.w:1844
	for ; k != 0; k-- {
//line dcells.w:1845
		base := int(m.item[k-1])
//line dcells.w:1846
		if k == m.second {
//line dcells.w:1847
			m.second = base
//line dcells.w:1848
		}
//line dcells.w:1849
		m.setSize(base, m.size(k*mccIprop))
//line dcells.w:1850
		m.setItemNo(base, k)
//line dcells.w:1851
		m.setSlack(base, m.slack(k*mccIprop))
//line dcells.w:1852
		m.setBound(base, m.bound(k*mccIprop))
//line dcells.w:1853
		m.setPos(base, k-1)
//line dcells.w:1854
		switch {
//line dcells.w:1855
		case k <= m.osecond && m.size(base) < m.bound(base)-m.slack(base):
//line dcells.w:1856
			m.baditem = k
//line dcells.w:1857
		case m.size(base) == 0:
//line dcells.w:1858
			m.force = ensure(m.force, m.forced+1)
//line dcells.w:1859
			m.force[m.forced] = int32(base)
//line dcells.w:1860
			m.forced++
//line dcells.w:1861
		}
//line dcells.w:1862
	}

//line dcells.w:1814

//line dcells.w:1865
	for k = 1; k < m.lastNode; k++ {
//line dcells.w:1866
		if m.nd[k].itm < 0 {
//line dcells.w:1867
			continue
//line dcells.w:1868
		}
//line dcells.w:1869
		base := int(m.item[int(m.nd[k].itm)-1])
//line dcells.w:1870
		loc := base + int(m.nd[k].loc)
//line dcells.w:1871
		m.nd[k].itm = int32(base)
//line dcells.w:1872
		m.nd[k].loc = int32(loc)
//line dcells.w:1873
		m.set[loc] = int32(k)
//line dcells.w:1874
	}

//line dcells.w:1815
	m.deactivateOptionless()
//line dcells.w:1816
}

//line dcells.w:1879
func (m *MCC) deactivateOptionless() {
//line dcells.w:1880
	for m.forced != 0 {
//line dcells.w:1881
		m.forced--
//line dcells.w:1882
		j := int(m.force[m.forced])
//line dcells.w:1883
		m.active--
//line dcells.w:1884
		i := int(m.item[m.active])
//line dcells.w:1885
		pp := m.pos(j)
//line dcells.w:1886
		m.item[m.active], m.item[pp] = int32(j), int32(i)
//line dcells.w:1887
		m.setPos(j, m.active)
//line dcells.w:1888
		m.setPos(i, pp)
//line dcells.w:1889
	}
//line dcells.w:1890
}
