//line dcells.w:100
// Package dcells solves exact-cover-with-colors (XCC) and
//line dcells.w:101
// exact-cover-with-multiplicities (MCC) problems using sparse-set "dancing
//line dcells.w:102
// cells" data structures instead of dancing links.
//line dcells.w:103
//
//line dcells.w:104
// It is a library form of Donald E. Knuth's SSXCC and SSMCC programs, exposing
//line dcells.w:105
// an API that mirrors github.com/sjnam/dlx: construct a solver with NewXCC or
//line dcells.w:106
// NewMCC, call Dance with an io.Reader carrying a problem in the DLX text
//line dcells.w:107
// format, and range over Result.Solutions. Each solution is a slice of Option,
//line dcells.w:108
// and each Option lists the item names of one chosen option (a colored
//line dcells.w:109
// secondary item appears as "name:color").
//line dcells.w:110
//
//line dcells.w:111
// Item names and colors are arbitrary (possibly multibyte) strings, as in dlx.

//line dcells.w:79
package dcells

//line dcells.w:81
import (
//line dcells.w:82
	"bufio"
//line dcells.w:83
	"context"
//line dcells.w:84
	"fmt"
//line dcells.w:85
	"io"
//line dcells.w:86
	"os"
//line dcells.w:87
	"strconv"
//line dcells.w:88
	"strings"
//line dcells.w:89
	"time"
//line dcells.w:90
)

//line dcells.w:142
const (
//line dcells.w:143
	primExtra = 4 // set entries reserved below each item's base
//line dcells.w:144
	infSize = 1 << 30 // "no item to branch on" => a solution
//line dcells.w:145
	secondUnset = 1 << 30 // sentinel for "no primary/secondary boundary yet"
//line dcells.w:146
)

//line dcells.w:155
type node struct {
//line dcells.w:156
	itm, loc, clr int32
//line dcells.w:157
}

//line dcells.w:164
type Option []string

//line dcells.w:166
type Result struct {
//line dcells.w:167
	Solutions <-chan []Option
//line dcells.w:168
	Heartbeat <-chan string
//line dcells.w:169
}

// twoints is one savestack entry: an item and the size to restore.
//
//line dcells.w:176
//line dcells.w:177
type twoints struct {
//line dcells.w:178
	l, r int32
//line dcells.w:179
}

// threeints is one MCC savestack entry: an item, its size, and its bound.
//
//line dcells.w:181
//line dcells.w:182
type threeints struct{ l, s, b int32 }

//line dcells.w:189
func ensure[T any](s []T, n int) []T {
//line dcells.w:190
	if n <= len(s) {
//line dcells.w:191
		return s
//line dcells.w:192
	}
//line dcells.w:193
	if n <= cap(s) {
//line dcells.w:194
		return s[:n]
//line dcells.w:195
	}
//line dcells.w:196
	t := make([]T, n, max(cap(s)*2, n, 64))
//line dcells.w:197
	copy(t, s)
//line dcells.w:198
	return t
//line dcells.w:199
}

// XCC holds the state of one dancing-cells computation.
//
//line dcells.w:207
//line dcells.w:208
type XCC struct {
//line dcells.w:209

//line dcells.w:224
	Debug bool
	// PulseInterval controls how often a Heartbeat string is offered.
	//
//line dcells.w:225
//line dcells.w:226
	PulseInterval time.Duration

//line dcells.w:210
	ctx context.Context

//line dcells.w:212

	// matrix, items, and the sparse-set "set" array
	//
//line dcells.w:233
//line dcells.w:234
	nd []node
//line dcells.w:235
	lastNode int
//line dcells.w:236
	item []int32
//line dcells.w:237
	second int
//line dcells.w:238
	lastItm int
//line dcells.w:239
	set []int32
//line dcells.w:240
	itemlen int
//line dcells.w:241
	setlen int
//line dcells.w:242
	active int
//line dcells.w:243
	oactive int
//line dcells.w:244
	baditem int
//line dcells.w:245
	osecond int

//line dcells.w:213

	// interned item names (by item number, 1-based) and colors (by id, 1-based)
	//
//line dcells.w:251
//line dcells.w:252
	names []string
//line dcells.w:253
	nameIndex map[string]int
//line dcells.w:254
	colorNames []string
//line dcells.w:255
	colorIndex map[string]int

//line dcells.w:214

	// force stack of items reduced to a single remaining option
	//
//line dcells.w:262
//line dcells.w:263
	force []int32
//line dcells.w:264
	forced int

	// depth-first search state
	//
//line dcells.w:266
//line dcells.w:267
	choice []int32
//line dcells.w:268
	saved []int32
//line dcells.w:269
	savestack []twoints
//line dcells.w:270
	saveptr int

//line dcells.w:215

	// statistics
	//
//line dcells.w:273
//line dcells.w:274
	updates uint64
//line dcells.w:275
	nodes uint64
//line dcells.w:276
	options uint64
//line dcells.w:277
	count uint64

//line dcells.w:216

	// output, set up per Dance call
	//
//line dcells.w:280
//line dcells.w:281
	solStream chan []Option
//line dcells.w:282
	heartbeat chan string
//line dcells.w:283
	pulse *time.Ticker

//line dcells.w:217
}

//line dcells.w:289
func NewXCC() *XCC {
//line dcells.w:290
	return &XCC{
//line dcells.w:291
		second: secondUnset,
//line dcells.w:292
		names: []string{""}, // item numbers are 1-based
//line dcells.w:293
		nameIndex: make(map[string]int),
//line dcells.w:294
		colorNames: []string{""}, // color 0 means "no color"
//line dcells.w:295
		colorIndex: make(map[string]int),
//line dcells.w:296
		ctx: context.Background(),
//line dcells.w:297
	}
//line dcells.w:298
}

//line dcells.w:305
func (s *XCC) WithContext(ctx context.Context) *XCC {
//line dcells.w:306
	if ctx == nil {
//line dcells.w:307
		panic("dcells: nil context")
//line dcells.w:308
	}
//line dcells.w:309
	c := *s
//line dcells.w:310
	c.ctx = ctx
//line dcells.w:311
	return &c
//line dcells.w:312
}

//line dcells.w:314
func (s *XCC) Updates() uint64 { return s.updates }

//line dcells.w:315
func (s *XCC) Nodes() uint64 { return s.nodes }

//line dcells.w:322
func (s *XCC) size(x int) int { return int(s.set[x-1]) }

//line dcells.w:323
func (s *XCC) pos(x int) int { return int(s.set[x-2]) }

//line dcells.w:324
func (s *XCC) itemNo(x int) int { return int(s.set[x-3]) }

//line dcells.w:326
func (s *XCC) setSize(x, v int) { s.set[x-1] = int32(v) }

//line dcells.w:327
func (s *XCC) setPos(x, v int) { s.set[x-2] = int32(v) }

//line dcells.w:328
func (s *XCC) setItemNo(x, v int) { s.set[x-3] = int32(v) }

//line dcells.w:334
func (s *XCC) internName(name string) (num int, ok bool) {
//line dcells.w:335
	if _, dup := s.nameIndex[name]; dup {
//line dcells.w:336
		return 0, false
//line dcells.w:337
	}
//line dcells.w:338
	num = len(s.names)
//line dcells.w:339
	s.names = append(s.names, name)
//line dcells.w:340
	s.nameIndex[name] = num
//line dcells.w:341
	return num, true
//line dcells.w:342
}

//line dcells.w:344
func (s *XCC) internColor(name string) int {
//line dcells.w:345
	if id, ok := s.colorIndex[name]; ok {
//line dcells.w:346
		return id
//line dcells.w:347
	}
//line dcells.w:348
	id := len(s.colorNames)
//line dcells.w:349
	s.colorNames = append(s.colorNames, name)
//line dcells.w:350
	s.colorIndex[name] = id
//line dcells.w:351
	return id
//line dcells.w:352
}

//line dcells.w:361
func (s *XCC) option(p int) Option {
//line dcells.w:362
	for s.nd[p-1].itm > 0 {
//line dcells.w:363
		p-- // move to the option's first node
//line dcells.w:364
	}
//line dcells.w:365
	var opt Option
//line dcells.w:366
	for q := p; s.nd[q].itm > 0; q++ {
//line dcells.w:367
		name := s.names[s.itemNo(int(s.nd[q].itm))]
//line dcells.w:368
		if c := s.nd[q].clr; c != 0 {
//line dcells.w:369
			name += ":" + s.colorNames[c]
//line dcells.w:370
		}
//line dcells.w:371
		opt = append(opt, name)
//line dcells.w:372
	}
//line dcells.w:373
	return opt
//line dcells.w:374
}

//line dcells.w:383
func (s *XCC) Dance(rd io.Reader) *Result {
//line dcells.w:384
	s.inputMatrix(rd)

//line dcells.w:386
	s.solStream = make(chan []Option)
//line dcells.w:387
	s.heartbeat = make(chan string)

//line dcells.w:389
	go func() {
//line dcells.w:390
		defer close(s.solStream)
//line dcells.w:391
		defer close(s.heartbeat)

//line dcells.w:393
		if s.Debug {
//line dcells.w:394
			fmt.Fprintf(os.Stderr,
//line dcells.w:395
				"(%d options, %d+%d items, %d entries successfully read)\n",
//line dcells.w:396
				s.options, s.osecond, s.itemlen-s.osecond, s.lastNode)
//line dcells.w:397
		}
//line dcells.w:398
		if s.PulseInterval > 0 {
//line dcells.w:399
			s.pulse = time.NewTicker(s.PulseInterval)
//line dcells.w:400
			defer s.pulse.Stop()
//line dcells.w:401
		}

//line dcells.w:403
		if s.baditem == 0 {
//line dcells.w:404
			s.search(0)
//line dcells.w:405
		}

//line dcells.w:407
		if s.Debug {
//line dcells.w:408
			plural := "s"
//line dcells.w:409
			if s.count == 1 {
//line dcells.w:410
				plural = ""
//line dcells.w:411
			}
//line dcells.w:412
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
//line dcells.w:413
				s.count, plural, s.updates, s.nodes)
//line dcells.w:414
		}
//line dcells.w:415
	}()

//line dcells.w:417
	return &Result{Solutions: s.solStream, Heartbeat: s.heartbeat}
//line dcells.w:418
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

//line dcells.w:442
	s.swapOut(best)
//line dcells.w:443
	s.oactive = s.active
//line dcells.w:444
	s.hide(best, 0, 0)
//line dcells.w:445
	s.saveSizes(level)
//line dcells.w:446
	s.choice = ensure(s.choice, level+1)
//line dcells.w:447
	for c := best; c < best+s.size(best); c++ {
//line dcells.w:448
		opt := int(s.set[c])
//line dcells.w:449
		s.choice[level] = int32(opt)
//line dcells.w:450
		if s.commitOption(opt) {
//line dcells.w:451
			if !s.search(level + 1) {
//line dcells.w:452
				return false
//line dcells.w:453
			}
//line dcells.w:454
		}
//line dcells.w:455
		s.restoreSizes(level)
//line dcells.w:456
	}
//line dcells.w:457
	return true
//line dcells.w:458
}

//line dcells.w:465
func (s *XCC) visit(level int) bool {
//line dcells.w:466
	s.count++
//line dcells.w:467
	sol := make([]Option, level)
//line dcells.w:468
	for k := 0; k < level; k++ {
//line dcells.w:469
		sol[k] = s.option(int(s.choice[k]))
//line dcells.w:470
	}
//line dcells.w:471
	select {
//line dcells.w:472
	case <-s.ctx.Done():
//line dcells.w:473
		return false
//line dcells.w:474
	case s.solStream <- sol:
//line dcells.w:475
		return true
//line dcells.w:476
	}
//line dcells.w:477
}

// tick offers a heartbeat string when the pulse fires, without blocking.
//
//line dcells.w:483
//line dcells.w:484
func (s *XCC) tick() {
//line dcells.w:485
	if s.pulse == nil {
//line dcells.w:486
		return
//line dcells.w:487
	}
//line dcells.w:488
	select {
//line dcells.w:489
	case <-s.pulse.C:
//line dcells.w:490
		select {
//line dcells.w:491
		case s.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", s.nodes, s.count):
//line dcells.w:492
		default:
//line dcells.w:493
		}
//line dcells.w:494
	default:
//line dcells.w:495
	}
//line dcells.w:496
}

//line dcells.w:506
func (s *XCC) chooseItem() (best int, solution bool) {
//line dcells.w:507
	for s.forced != 0 {
//line dcells.w:508
		s.forced--
//line dcells.w:509
		if f := int(s.force[s.forced]); s.pos(f) < s.active {
//line dcells.w:510
			return f, false
//line dcells.w:511
		}
//line dcells.w:512
	}

//line dcells.w:514
	score := infSize
//line dcells.w:515
	for k := 0; k < s.active; k++ {
//line dcells.w:516
		x := int(s.item[k])
//line dcells.w:517
		if x >= s.second {
//line dcells.w:518
			continue // secondary items are not branched on
//line dcells.w:519
		}
//line dcells.w:520
		switch sz := s.size(x); {
//line dcells.w:521
		case sz == 0:
//line dcells.w:522
		case sz == 1:
//line dcells.w:523
			s.force = ensure(s.force, s.forced+1)
//line dcells.w:524
			s.force[s.forced] = int32(x)
//line dcells.w:525
			s.forced++
//line dcells.w:526
		case sz < score || (sz == score && x < best): // ties: leftmost
//line dcells.w:527
			best, score = x, sz
//line dcells.w:528
		}
//line dcells.w:529
	}

//line dcells.w:531
	if s.forced != 0 {
//line dcells.w:532
		s.forced--
//line dcells.w:533
		return int(s.force[s.forced]), false
//line dcells.w:534
	}
//line dcells.w:535
	return best, score == infSize
//line dcells.w:536
}

//line dcells.w:548
func (s *XCC) commitOption(opt int) bool {
//line dcells.w:549
	p := s.active
//line dcells.w:550
	s.oactive = s.active
//line dcells.w:551
	for q := opt + 1; q != opt; {
//line dcells.w:552
		c := int(s.nd[q].itm)
//line dcells.w:553
		if c < 0 {
//line dcells.w:554
			q += c
//line dcells.w:555
			continue
//line dcells.w:556
		}
//line dcells.w:557
		if pp := s.pos(c); pp < p {
//line dcells.w:558
			p--
//line dcells.w:559
			cc := int(s.item[p])
//line dcells.w:560
			s.item[p], s.item[pp] = int32(c), int32(cc)
//line dcells.w:561
			s.setPos(cc, pp)
//line dcells.w:562
			s.setPos(c, p)
//line dcells.w:563
			s.updates++
//line dcells.w:564
		}
//line dcells.w:565
		q++
//line dcells.w:566
	}
//line dcells.w:567
	s.active = p

//line dcells.w:569
	for q := opt + 1; q != opt; {
//line dcells.w:570
		c := int(s.nd[q].itm)
//line dcells.w:571
		if c < 0 {
//line dcells.w:572
			q += c
//line dcells.w:573
			continue
//line dcells.w:574
		}
//line dcells.w:575
		switch {
//line dcells.w:576
		case c < s.second:
//line dcells.w:577
			if !s.hide(c, 0, 1) {
//line dcells.w:578
				s.forced = 0
//line dcells.w:579
				return false
//line dcells.w:580
			}
//line dcells.w:581
		case s.pos(c) < s.oactive: // skip if already purified
//line dcells.w:582
			if !s.hide(c, int(s.nd[q].clr), 1) {
//line dcells.w:583
				s.forced = 0
//line dcells.w:584
				return false
//line dcells.w:585
			}
//line dcells.w:586
		}
//line dcells.w:587
		q++
//line dcells.w:588
	}
//line dcells.w:589
	return true
//line dcells.w:590
}

//line dcells.w:601
func (s *XCC) hide(c, color, check int) bool {
//line dcells.w:602
	for rr, end := c, c+s.size(c); rr < end; rr++ {
//line dcells.w:603
		tt := int(s.set[rr])
//line dcells.w:604
		if color != 0 && int(s.nd[tt].clr) == color {
//line dcells.w:605
			continue
//line dcells.w:606
		}
//line dcells.w:607
		for nn := tt + 1; nn != tt; {
//line dcells.w:608
			u, v := int(s.nd[nn].itm), int(s.nd[nn].loc)
//line dcells.w:609
			if u < 0 {
//line dcells.w:610
				nn += u
//line dcells.w:611
				continue
//line dcells.w:612
			}
//line dcells.w:613
			if s.pos(u) < s.oactive {
//line dcells.w:614
				ss := s.size(u) - 1
//line dcells.w:615
				if ss <= 1 && check != 0 && u < s.second && s.pos(u) < s.active {
//line dcells.w:616
					if ss == 0 {
//line dcells.w:617
						return false
//line dcells.w:618
					}
//line dcells.w:619
					s.force = ensure(s.force, s.forced+1)
//line dcells.w:620
					s.force[s.forced] = int32(u)
//line dcells.w:621
					s.forced++
//line dcells.w:622
				}
//line dcells.w:623
				nnp := int(s.set[u+ss])
//line dcells.w:624
				s.setSize(u, ss)
//line dcells.w:625
				s.set[u+ss], s.set[v] = int32(nn), int32(nnp)
//line dcells.w:626
				s.nd[nn].loc, s.nd[nnp].loc = int32(u+ss), int32(v)
//line dcells.w:627
				s.updates++
//line dcells.w:628
			}
//line dcells.w:629
			nn++
//line dcells.w:630
		}
//line dcells.w:631
	}
//line dcells.w:632
	return true
//line dcells.w:633
}

// swapOut removes item x from the active list (covering it).
//
//line dcells.w:637
//line dcells.w:638
func (s *XCC) swapOut(x int) {
//line dcells.w:639
	p := s.active - 1
//line dcells.w:640
	s.active = p
//line dcells.w:641
	pp := s.pos(x)
//line dcells.w:642
	cc := int(s.item[p])
//line dcells.w:643
	s.item[p], s.item[pp] = int32(x), int32(cc)
//line dcells.w:644
	s.setPos(cc, pp)
//line dcells.w:645
	s.setPos(x, p)
//line dcells.w:646
	s.updates++
//line dcells.w:647
}

// saveSizes snapshots the active items' sizes so a branch can be undone.
//
//line dcells.w:656
//line dcells.w:657
func (s *XCC) saveSizes(level int) {
//line dcells.w:658
	s.savestack = ensure(s.savestack, s.saveptr+s.active)
//line dcells.w:659
	for p := 0; p < s.active; p++ {
//line dcells.w:660
		s.savestack[s.saveptr+p] = twoints{s.item[p], int32(s.size(int(s.item[p])))}
//line dcells.w:661
	}
//line dcells.w:662
	s.saveptr += s.active
//line dcells.w:663
	s.saved = ensure(s.saved, level+2)
//line dcells.w:664
	s.saved[level+1] = int32(s.saveptr)
//line dcells.w:665
}

// restoreSizes undoes the deletions since saveSizes at this level.
//
//line dcells.w:667
//line dcells.w:668
func (s *XCC) restoreSizes(level int) {
//line dcells.w:669
	s.saveptr = int(s.saved[level+1])
//line dcells.w:670
	s.active = s.saveptr - int(s.saved[level])
//line dcells.w:671
	for p := -s.active; p < 0; p++ {
//line dcells.w:672
		e := s.savestack[s.saveptr+p]
//line dcells.w:673
		s.setSize(int(e.l), int(e.r))
//line dcells.w:674
	}
//line dcells.w:675
}

//line dcells.w:698
const (
//line dcells.w:699
	mccExtra = 5 // set entries below each item base: size, pos, itemNo, slack, bound
//line dcells.w:700
	mccIprop = 5 // input-phase slot spacing
//line dcells.w:701
)

// MCC holds the state of one multiplicity dancing-cells computation.
//
//line dcells.w:708
//line dcells.w:709
type MCC struct {
//line dcells.w:710
	Debug bool
//line dcells.w:711
	PulseInterval time.Duration

//line dcells.w:713
	ctx context.Context

//line dcells.w:715
	nd []node
//line dcells.w:716
	lastNode int
//line dcells.w:717
	item []int32
//line dcells.w:718
	second int
//line dcells.w:719
	lastItm int
//line dcells.w:720
	set []int32
//line dcells.w:721
	itemlen int
//line dcells.w:722
	setlen int
//line dcells.w:723
	active int
//line dcells.w:724
	baditem int
//line dcells.w:725
	osecond int

//line dcells.w:727
	names []string
//line dcells.w:728
	nameIndex map[string]int
//line dcells.w:729
	colorNames []string
//line dcells.w:730
	colorIndex map[string]int

//line dcells.w:732
	force []int32
//line dcells.w:733
	forced int

//line dcells.w:735
	included []int32 // option included at each stage, for solution output
//line dcells.w:736
	savestack []threeints
//line dcells.w:737
	saveptr int

//line dcells.w:739
	updates uint64
//line dcells.w:740
	nodes uint64
//line dcells.w:741
	options uint64
//line dcells.w:742
	count uint64

//line dcells.w:744
	solStream chan []Option
//line dcells.w:745
	heartbeat chan string
//line dcells.w:746
	pulse *time.Ticker
//line dcells.w:747
}

//line dcells.w:752
func NewMCC() *MCC {
//line dcells.w:753
	return &MCC{
//line dcells.w:754
		second: secondUnset,
//line dcells.w:755
		names: []string{""},
//line dcells.w:756
		nameIndex: make(map[string]int),
//line dcells.w:757
		colorNames: []string{""},
//line dcells.w:758
		colorIndex: make(map[string]int),
//line dcells.w:759
		ctx: context.Background(),
//line dcells.w:760
	}
//line dcells.w:761
}

//line dcells.w:763
func (m *MCC) WithContext(ctx context.Context) *MCC {
//line dcells.w:764
	if ctx == nil {
//line dcells.w:765
		panic("dcells: nil context")
//line dcells.w:766
	}
//line dcells.w:767
	c := *m
//line dcells.w:768
	c.ctx = ctx
//line dcells.w:769
	return &c
//line dcells.w:770
}

//line dcells.w:772
func (m *MCC) Updates() uint64 { return m.updates }

//line dcells.w:773
func (m *MCC) Nodes() uint64 { return m.nodes }

//line dcells.w:778
func (m *MCC) size(x int) int { return int(m.set[x-1]) }

//line dcells.w:779
func (m *MCC) pos(x int) int { return int(m.set[x-2]) }

//line dcells.w:780
func (m *MCC) itemNo(x int) int { return int(m.set[x-3]) }

//line dcells.w:781
func (m *MCC) slack(x int) int { return int(m.set[x-4]) }

//line dcells.w:782
func (m *MCC) bound(x int) int { return int(m.set[x-5]) }

//line dcells.w:784
func (m *MCC) setSize(x, v int) { m.set[x-1] = int32(v) }

//line dcells.w:785
func (m *MCC) setPos(x, v int) { m.set[x-2] = int32(v) }

//line dcells.w:786
func (m *MCC) setItemNo(x, v int) { m.set[x-3] = int32(v) }

//line dcells.w:787
func (m *MCC) setSlack(x, v int) { m.set[x-4] = int32(v) }

//line dcells.w:788
func (m *MCC) setBound(x, v int) { m.set[x-5] = int32(v) }

//line dcells.w:793
func (m *MCC) internName(name string) (num int, ok bool) {
//line dcells.w:794
	if _, dup := m.nameIndex[name]; dup {
//line dcells.w:795
		return 0, false
//line dcells.w:796
	}
//line dcells.w:797
	num = len(m.names)
//line dcells.w:798
	m.names = append(m.names, name)
//line dcells.w:799
	m.nameIndex[name] = num
//line dcells.w:800
	return num, true
//line dcells.w:801
}

//line dcells.w:803
func (m *MCC) internColor(name string) int {
//line dcells.w:804
	if id, ok := m.colorIndex[name]; ok {
//line dcells.w:805
		return id
//line dcells.w:806
	}
//line dcells.w:807
	id := len(m.colorNames)
//line dcells.w:808
	m.colorNames = append(m.colorNames, name)
//line dcells.w:809
	m.colorIndex[name] = id
//line dcells.w:810
	return id
//line dcells.w:811
}

//line dcells.w:813
func (m *MCC) option(p int) Option {
//line dcells.w:814
	for m.nd[p-1].itm > 0 {
//line dcells.w:815
		p--
//line dcells.w:816
	}
//line dcells.w:817
	var opt Option
//line dcells.w:818
	for q := p; m.nd[q].itm > 0; q++ {
//line dcells.w:819
		name := m.names[m.itemNo(int(m.nd[q].itm))]
//line dcells.w:820
		if c := m.nd[q].clr; c != 0 {
//line dcells.w:821
			name += ":" + m.colorNames[c]
//line dcells.w:822
		}
//line dcells.w:823
		opt = append(opt, name)
//line dcells.w:824
	}
//line dcells.w:825
	return opt
//line dcells.w:826
}

//line dcells.w:832
func (m *MCC) Dance(rd io.Reader) *Result {
//line dcells.w:833
	m.inputMatrix(rd)

//line dcells.w:835
	m.solStream = make(chan []Option)
//line dcells.w:836
	m.heartbeat = make(chan string)

//line dcells.w:838
	go func() {
//line dcells.w:839
		defer close(m.solStream)
//line dcells.w:840
		defer close(m.heartbeat)

//line dcells.w:842
		if m.Debug {
//line dcells.w:843
			fmt.Fprintf(os.Stderr,
//line dcells.w:844
				"(%d options, %d+%d items, %d entries successfully read)\n",
//line dcells.w:845
				m.options, m.osecond, m.itemlen-m.osecond, m.lastNode)
//line dcells.w:846
		}
//line dcells.w:847
		if m.PulseInterval > 0 {
//line dcells.w:848
			m.pulse = time.NewTicker(m.PulseInterval)
//line dcells.w:849
			defer m.pulse.Stop()
//line dcells.w:850
		}

//line dcells.w:852
		if m.baditem == 0 {
//line dcells.w:853
			m.search(0)
//line dcells.w:854
		}

//line dcells.w:856
		if m.Debug {
//line dcells.w:857
			plural := "s"
//line dcells.w:858
			if m.count == 1 {
//line dcells.w:859
				plural = ""
//line dcells.w:860
			}
//line dcells.w:861
			fmt.Fprintf(os.Stderr, "Altogether %d solution%s, %d updates, %d nodes.\n",
//line dcells.w:862
				m.count, plural, m.updates, m.nodes)
//line dcells.w:863
		}
//line dcells.w:864
	}()

//line dcells.w:866
	return &Result{Solutions: m.solStream, Heartbeat: m.heartbeat}
//line dcells.w:867
}

//line dcells.w:878
func (m *MCC) search(stage int) bool {
//line dcells.w:879
	m.nodes++
//line dcells.w:880
	select {
//line dcells.w:881
	case <-m.ctx.Done():
//line dcells.w:882
		return false
//line dcells.w:883
	default:
//line dcells.w:884
	}
//line dcells.w:885
	m.tick()

//line dcells.w:887
	// A forced item left over from a covering at a shallower node.
//line dcells.w:888
	for m.forced != 0 {
//line dcells.w:889
		m.forced--
//line dcells.w:890
		if bi := int(m.force[m.forced]); m.pos(bi) < m.active {
//line dcells.w:891
			return m.forcedMove(stage, bi)
//line dcells.w:892
		}
//line dcells.w:893
	}

//line dcells.w:895
	best, score := m.chooseBest()
//line dcells.w:896
	if m.forced != 0 {
//line dcells.w:897
		m.forced--
//line dcells.w:898
		return m.forcedMove(stage, int(m.force[m.forced]))
//line dcells.w:899
	}
//line dcells.w:900
	if score == infSize {
//line dcells.w:901
		return m.visit(stage)
//line dcells.w:902
	}

//line dcells.w:904
	mark := m.saveState()
//line dcells.w:905
	opt := int(m.set[best])
//line dcells.w:906
	m.included = ensure(m.included, stage+1)
//line dcells.w:907
	m.included[stage] = int32(opt)

//line dcells.w:909
	if m.includeOption(opt) {
//line dcells.w:910
		if !m.search(stage + 1) {
//line dcells.w:911
			m.saveptr = mark
//line dcells.w:912
			return false
//line dcells.w:913
		}
//line dcells.w:914
	}
//line dcells.w:915
	if score != 1 {
//line dcells.w:916
		m.restoreState(mark)
//line dcells.w:917
		if m.removeOption(opt) {
//line dcells.w:918
			if !m.search(stage) {
//line dcells.w:919
				m.saveptr = mark
//line dcells.w:920
				return false
//line dcells.w:921
			}
//line dcells.w:922
		}
//line dcells.w:923
	}
//line dcells.w:924
	m.saveptr = mark
//line dcells.w:925
	return true
//line dcells.w:926
}

//line dcells.w:932
func (m *MCC) forcedMove(stage, bi int) bool {
//line dcells.w:933
	opt := int(m.set[bi])
//line dcells.w:934
	m.included = ensure(m.included, stage+1)
//line dcells.w:935
	m.included[stage] = int32(opt)
//line dcells.w:936
	if m.includeOption(opt) {
//line dcells.w:937
		return m.search(stage + 1)
//line dcells.w:938
	}
//line dcells.w:939
	return true
//line dcells.w:940
}

// visit emits the current solution (the options included so far).
//
//line dcells.w:945
//line dcells.w:946
func (m *MCC) visit(stage int) bool {
//line dcells.w:947
	m.count++
//line dcells.w:948
	sol := make([]Option, stage)
//line dcells.w:949
	for k := 0; k < stage; k++ {
//line dcells.w:950
		sol[k] = m.option(int(m.included[k]))
//line dcells.w:951
	}
//line dcells.w:952
	select {
//line dcells.w:953
	case <-m.ctx.Done():
//line dcells.w:954
		return false
//line dcells.w:955
	case m.solStream <- sol:
//line dcells.w:956
		return true
//line dcells.w:957
	}
//line dcells.w:958
}

//line dcells.w:960
func (m *MCC) tick() {
//line dcells.w:961
	if m.pulse == nil {
//line dcells.w:962
		return
//line dcells.w:963
	}
//line dcells.w:964
	select {
//line dcells.w:965
	case <-m.pulse.C:
//line dcells.w:966
		select {
//line dcells.w:967
		case m.heartbeat <- fmt.Sprintf("%d nodes, %d solutions so far", m.nodes, m.count):
//line dcells.w:968
		default:
//line dcells.w:969
		}
//line dcells.w:970
	default:
//line dcells.w:971
	}
//line dcells.w:972
}

//line dcells.w:979
func (m *MCC) chooseBest() (best, score int) {
//line dcells.w:980
	score = infSize
//line dcells.w:981
	bestS, bestL := 0, 0
//line dcells.w:982
	for k := 0; k < m.active; k++ {
//line dcells.w:983
		x := int(m.item[k])
//line dcells.w:984
		if x >= m.second {
//line dcells.w:985
			continue
//line dcells.w:986
		}
//line dcells.w:987
		s := m.slack(x)
//line dcells.w:988
		if b := m.bound(x); s > b {
//line dcells.w:989
			s = b
//line dcells.w:990
		}
//line dcells.w:991
		t := m.size(x) + s - m.bound(x) + 1
//line dcells.w:992
		switch {
//line dcells.w:993
		case t == 1:
//line dcells.w:994
			for i := m.bound(x) - m.slack(x); i > 0; i-- {
//line dcells.w:995
				m.force = ensure(m.force, m.forced+1)
//line dcells.w:996
				m.force[m.forced] = int32(x)
//line dcells.w:997
				m.forced++
//line dcells.w:998
			}
//line dcells.w:999
		case t <= score && (t < score || (s <= bestS && (s < bestS ||
//line dcells.w:1000
			(m.size(x) >= bestL && (m.size(x) > bestL || x < best))))):
//line dcells.w:1001
			score, best, bestS, bestL = t, x, s, m.size(x)
//line dcells.w:1002
		}
//line dcells.w:1003
	}
//line dcells.w:1004
	return best, score
//line dcells.w:1005
}

//line dcells.w:1013
func (m *MCC) includeOption(opt int) bool {
//line dcells.w:1014
	for m.nd[opt-1].itm > 0 {
//line dcells.w:1015
		opt--
//line dcells.w:1016
	}
//line dcells.w:1017
	for ; ; opt++ {
//line dcells.w:1018
		ii := int(m.nd[opt].itm)
//line dcells.w:1019
		if ii <= 0 {
//line dcells.w:1020
			break
//line dcells.w:1021
		}
//line dcells.w:1022
		pp := int(m.nd[opt].loc)
//line dcells.w:1023
		if m.pos(ii) >= m.active {
//line dcells.w:1024
			if ii >= m.second {
//line dcells.w:1025
				continue // secondary item already purified
//line dcells.w:1026
			}
//line dcells.w:1027
			return false // should not happen for a well-formed active option
//line dcells.w:1028
		}
//line dcells.w:1029
		if !m.coverOrCommit(ii, opt, pp) {
//line dcells.w:1030
			return false
//line dcells.w:1031
		}
//line dcells.w:1032
	}
//line dcells.w:1033
	return true
//line dcells.w:1034
}

//line dcells.w:1043
func (m *MCC) coverOrCommit(ii, opt, pp int) bool {
//line dcells.w:1044
	if ii < m.second {
//line dcells.w:1045
		m.setBound(ii, m.bound(ii)-1)
//line dcells.w:1046
	}
//line dcells.w:1047
	if ii >= m.second || m.bound(ii) == 0 {
//line dcells.w:1048
		ss := m.size(ii)
//line dcells.w:1049
		c := 0
//line dcells.w:1050
		if ii >= m.second {
//line dcells.w:1051
			c = int(m.nd[opt].clr)
//line dcells.w:1052
		}
//line dcells.w:1053
		for s := ii + ss - 1; s >= ii; s-- {
//line dcells.w:1054
			if s == pp {
//line dcells.w:1055
				continue
//line dcells.w:1056
			}
//line dcells.w:1057
			optp := int(m.set[s])
//line dcells.w:1058
			if c == 0 || int(m.nd[optp].clr) != c {
//line dcells.w:1059
				if !m.removeFromOtherSets(optp) {
//line dcells.w:1060
					return false
//line dcells.w:1061
				}
//line dcells.w:1062
			}
//line dcells.w:1063
		}
//line dcells.w:1064
		m.deactivate(ii)
//line dcells.w:1065
	} else {
//line dcells.w:1066
		ss := m.size(ii) - 1
//line dcells.w:1067
		if ss < m.bound(ii)-m.slack(ii) {
//line dcells.w:1068
			m.forced = 0
//line dcells.w:1069
			return false // ii would be wiped out
//line dcells.w:1070
		}
//line dcells.w:1071
		if ss == 0 {
//line dcells.w:1072
			m.deactivate(ii)
//line dcells.w:1073
		} else {
//line dcells.w:1074
			nnp := int(m.set[ii+ss])
//line dcells.w:1075
			m.setSize(ii, ss)
//line dcells.w:1076
			m.set[ii+ss], m.set[pp] = int32(opt), int32(nnp)
//line dcells.w:1077
			m.nd[opt].loc, m.nd[nnp].loc = int32(ii+ss), int32(pp)
//line dcells.w:1078
			m.updates++
//line dcells.w:1079
		}
//line dcells.w:1080
	}
//line dcells.w:1081
	return true
//line dcells.w:1082
}

//line dcells.w:1089
func (m *MCC) removeFromOtherSets(optp int) bool {
//line dcells.w:1090
	nn := optp
//line dcells.w:1091
	for m.nd[nn-1].itm > 0 {
//line dcells.w:1092
		nn--
//line dcells.w:1093
	}
//line dcells.w:1094
	for ; ; nn++ {
//line dcells.w:1095
		ii := int(m.nd[nn].itm)
//line dcells.w:1096
		if ii <= 0 {
//line dcells.w:1097
			break
//line dcells.w:1098
		}
//line dcells.w:1099
		p := int(m.nd[nn].loc)
//line dcells.w:1100
		if p >= m.second && m.pos(ii) >= m.active {
//line dcells.w:1101
			continue
//line dcells.w:1102
		}
//line dcells.w:1103
		ss := m.size(ii) - 1
//line dcells.w:1104
		if p < m.second {
//line dcells.w:1105
			if ss < m.bound(ii)-m.slack(ii) {
//line dcells.w:1106
				m.forced = 0
//line dcells.w:1107
				return false
//line dcells.w:1108
			}
//line dcells.w:1109
			if ss == 0 {
//line dcells.w:1110
				m.deactivate(ii)
//line dcells.w:1111
			}
//line dcells.w:1112
		}
//line dcells.w:1113
		if ss > 0 {
//line dcells.w:1114
			nnp := int(m.set[ii+ss])
//line dcells.w:1115
			m.setSize(ii, ss)
//line dcells.w:1116
			m.set[ii+ss], m.set[p] = int32(nn), int32(nnp)
//line dcells.w:1117
			m.nd[nn].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
//line dcells.w:1118
			m.updates++
//line dcells.w:1119
		}
//line dcells.w:1120
	}
//line dcells.w:1121
	return true
//line dcells.w:1122
}

//line dcells.w:1129
func (m *MCC) removeOption(cur int) bool {
//line dcells.w:1130
	for m.nd[cur-1].itm > 0 {
//line dcells.w:1131
		cur--
//line dcells.w:1132
	}
//line dcells.w:1133
	for ; ; cur++ {
//line dcells.w:1134
		ii := int(m.nd[cur].itm)
//line dcells.w:1135
		if ii <= 0 {
//line dcells.w:1136
			break
//line dcells.w:1137
		}
//line dcells.w:1138
		p := int(m.nd[cur].loc)
//line dcells.w:1139
		if p >= m.second && m.pos(ii) >= m.active {
//line dcells.w:1140
			continue
//line dcells.w:1141
		}
//line dcells.w:1142
		ss := m.size(ii) - 1
//line dcells.w:1143
		if p < m.second {
//line dcells.w:1144
			if ss < m.bound(ii)-m.slack(ii) {
//line dcells.w:1145
				return false
//line dcells.w:1146
			}
//line dcells.w:1147
			if ss == 0 {
//line dcells.w:1148
				m.deactivate(ii)
//line dcells.w:1149
			}
//line dcells.w:1150
		}
//line dcells.w:1151
		if ss > 0 {
//line dcells.w:1152
			nnp := int(m.set[ii+ss])
//line dcells.w:1153
			m.setSize(ii, ss)
//line dcells.w:1154
			m.set[ii+ss], m.set[p] = int32(cur), int32(nnp)
//line dcells.w:1155
			m.nd[cur].loc, m.nd[nnp].loc = int32(ii+ss), int32(p)
//line dcells.w:1156
			m.updates++
//line dcells.w:1157
		}
//line dcells.w:1158
	}
//line dcells.w:1159
	return true
//line dcells.w:1160
}

//line dcells.w:1164
func (m *MCC) deactivate(ii int) {
//line dcells.w:1165
	m.active--
//line dcells.w:1166
	p := m.pos(ii)
//line dcells.w:1167
	iii := int(m.item[m.active])
//line dcells.w:1168
	m.item[m.active], m.item[p] = int32(ii), int32(iii)
//line dcells.w:1169
	m.setPos(ii, m.active)
//line dcells.w:1170
	m.setPos(iii, p)
//line dcells.w:1171
}

//line dcells.w:1178
func (m *MCC) saveState() int {
//line dcells.w:1179
	mark := m.saveptr
//line dcells.w:1180
	m.savestack = ensure(m.savestack, m.saveptr+m.active)
//line dcells.w:1181
	for p := 0; p < m.active; p++ {
//line dcells.w:1182
		x := int(m.item[p])
//line dcells.w:1183
		e := threeints{l: int32(x), s: int32(m.size(x))}
//line dcells.w:1184
		if x < m.second {
//line dcells.w:1185
			e.b = int32(m.bound(x))
//line dcells.w:1186
		}
//line dcells.w:1187
		m.savestack[m.saveptr] = e
//line dcells.w:1188
		m.saveptr++
//line dcells.w:1189
	}
//line dcells.w:1190
	return mark
//line dcells.w:1191
}

//line dcells.w:1193
func (m *MCC) restoreState(mark int) {
//line dcells.w:1194
	m.active = m.saveptr - mark
//line dcells.w:1195
	for p := 0; p < m.active; p++ {
//line dcells.w:1196
		e := m.savestack[mark+p]
//line dcells.w:1197
		m.setSize(int(e.l), int(e.s))
//line dcells.w:1198
		if int(e.l) < m.second {
//line dcells.w:1199
			m.setBound(int(e.l), int(e.b))
//line dcells.w:1200
		}
//line dcells.w:1201
	}
//line dcells.w:1202
	m.saveptr = mark
//line dcells.w:1203
}

//line dcells.w:1219
type parseError struct{ msg string }

//line dcells.w:1221
func (e *parseError) Error() string { return e.msg }

//line dcells.w:1223
func failf(format string, a ...any) {
//line dcells.w:1224
	panic(&parseError{fmt.Sprintf(format, a...)})
//line dcells.w:1225
}

//line dcells.w:1233
func isspace(c byte) bool {
//line dcells.w:1234
	return c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r'
//line dcells.w:1235
}

//line dcells.w:1237
func nextLine(br *bufio.Reader) (buf []byte, ok bool) {
//line dcells.w:1238
	str, err := br.ReadString('\n')
//line dcells.w:1239
	if len(str) == 0 && err != nil {
//line dcells.w:1240
		return nil, false
//line dcells.w:1241
	}
//line dcells.w:1242
	buf = make([]byte, len(str)+1)
//line dcells.w:1243
	copy(buf, str)
//line dcells.w:1244
	return buf, true
//line dcells.w:1245
}

//line dcells.w:1247
func skipSpace(buf []byte, p int) int {
//line dcells.w:1248
	for isspace(buf[p]) {
//line dcells.w:1249
		p++
//line dcells.w:1250
	}
//line dcells.w:1251
	return p
//line dcells.w:1252
}

// token reads buf[p:] up to the next whitespace, NUL, or (if stopColon) ':'.
//
//line dcells.w:1254
//line dcells.w:1255
func token(buf []byte, p int, stopColon bool) (string, int) {
//line dcells.w:1256
	start := p
//line dcells.w:1257
	for buf[p] != 0 && !isspace(buf[p]) && !(stopColon && buf[p] == ':') {
//line dcells.w:1258
		p++
//line dcells.w:1259
	}
//line dcells.w:1260
	return string(buf[start:p]), p
//line dcells.w:1261
}

//line dcells.w:1265
func (s *XCC) inputMatrix(rd io.Reader) {
//line dcells.w:1266
	br := bufio.NewReader(rd)
//line dcells.w:1267
	s.readItemNames(br)
//line dcells.w:1268
	s.readOptions(br)
//line dcells.w:1269
}

//line dcells.w:1277
func (s *XCC) readItemNames(br *bufio.Reader) {
//line dcells.w:1278
	var buf []byte
//line dcells.w:1279
	var p int
//line dcells.w:1280
	found := false
//line dcells.w:1281
	for {
//line dcells.w:1282
		var ok bool
//line dcells.w:1283
		if buf, ok = nextLine(br); !ok {
//line dcells.w:1284
			break
//line dcells.w:1285
		}
//line dcells.w:1286
		if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
//line dcells.w:1287
			found = true
//line dcells.w:1288
			break
//line dcells.w:1289
		}
//line dcells.w:1290
	}
//line dcells.w:1291
	if !found {
//line dcells.w:1292
		failf("no items")
//line dcells.w:1293
	}
//line dcells.w:1294
	for buf[p] != 0 {
//line dcells.w:1295
		name, next := token(buf, p, false)
//line dcells.w:1296
		if name == "|" {
//line dcells.w:1297
			if s.second != secondUnset {
//line dcells.w:1298
				failf("item name line contains | twice")
//line dcells.w:1299
			}
//line dcells.w:1300
			s.second = len(s.names) // the next item's number
//line dcells.w:1301
		} else {
//line dcells.w:1302
			if strings.ContainsAny(name, ":|") {
//line dcells.w:1303
				failf("illegal character in item name: %q", name)
//line dcells.w:1304
			}
//line dcells.w:1305
			if _, ok := s.internName(name); !ok {
//line dcells.w:1306
				failf("duplicate item name: %s", name)
//line dcells.w:1307
			}
//line dcells.w:1308
		}
//line dcells.w:1309
		p = skipSpace(buf, next)
//line dcells.w:1310
	}
//line dcells.w:1311
	s.lastItm = len(s.names) // items + 1 (names[0] is unused)
//line dcells.w:1312
}

//line dcells.w:1317
func (s *XCC) readOptions(br *bufio.Reader) {
//line dcells.w:1318
	for {
//line dcells.w:1319
		buf, ok := nextLine(br)
//line dcells.w:1320
		if !ok {
//line dcells.w:1321
			break
//line dcells.w:1322
		}
//line dcells.w:1323
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
//line dcells.w:1324
			continue
//line dcells.w:1325
		}
//line dcells.w:1326
		s.readOption(buf)
//line dcells.w:1327
	}
//line dcells.w:1328
	s.finalize()
//line dcells.w:1329
}

//line dcells.w:1337
func (s *XCC) readOption(buf []byte) {
//line dcells.w:1338
	spacer := s.lastNode
//line dcells.w:1339
	hasPrimary := false
//line dcells.w:1340
	for p := skipSpace(buf, 0); buf[p] != 0; {
//line dcells.w:1341
		name, next := token(buf, p, true)
//line dcells.w:1342
		if name == "" {
//line dcells.w:1343
			failf("empty item name")
//line dcells.w:1344
		}
//line dcells.w:1345
		m, known := s.nameIndex[name]
//line dcells.w:1346
		if !known {
//line dcells.w:1347
			failf("unknown item name: %s", name)
//line dcells.w:1348
		}
//line dcells.w:1349
		s.createNode(m, spacer, &hasPrimary)
//line dcells.w:1350
		if buf[next] == ':' {
//line dcells.w:1351
			if m < s.second {
//line dcells.w:1352
				failf("primary item must be uncolored: %s", name)
//line dcells.w:1353
			}
//line dcells.w:1354
			color, ce := token(buf, next+1, false)
//line dcells.w:1355
			if color == "" {
//line dcells.w:1356
				failf("missing color after %s:", name)
//line dcells.w:1357
			}
//line dcells.w:1358
			s.nd[s.lastNode].clr = int32(s.internColor(color))
//line dcells.w:1359
			next = ce
//line dcells.w:1360
		} else {
//line dcells.w:1361
			s.nd[s.lastNode].clr = 0
//line dcells.w:1362
		}
//line dcells.w:1363
		p = skipSpace(buf, next)
//line dcells.w:1364
	}

//line dcells.w:1366
	if !hasPrimary {
//line dcells.w:1367
		for s.lastNode > spacer {
//line dcells.w:1368
			slot := int(s.nd[s.lastNode].itm) << 2
//line dcells.w:1369
			s.setSize(slot, s.size(slot)-1)
//line dcells.w:1370
			s.setPos(slot, spacer-1)
//line dcells.w:1371
			s.lastNode--
//line dcells.w:1372
		}
//line dcells.w:1373
		return
//line dcells.w:1374
	}
//line dcells.w:1375
	s.nd[spacer].loc = int32(s.lastNode - spacer)
//line dcells.w:1376
	s.lastNode++
//line dcells.w:1377
	s.nd = ensure(s.nd, s.lastNode+1)
//line dcells.w:1378
	s.options++
//line dcells.w:1379
	s.nd[s.lastNode].itm = int32(spacer + 1 - s.lastNode)
//line dcells.w:1380
}

//line dcells.w:1387
func (s *XCC) createNode(m, spacer int, hasPrimary *bool) {
//line dcells.w:1388
	slot := m << 2
//line dcells.w:1389
	s.set = ensure(s.set, slot)
//line dcells.w:1390
	if s.pos(slot) > spacer {
//line dcells.w:1391
		failf("duplicate item name in this option: %s", s.names[m])
//line dcells.w:1392
	}
//line dcells.w:1393
	s.lastNode++
//line dcells.w:1394
	s.nd = ensure(s.nd, s.lastNode+1)
//line dcells.w:1395
	t := s.size(slot)
//line dcells.w:1396
	s.nd[s.lastNode].itm = int32(m)
//line dcells.w:1397
	s.nd[s.lastNode].loc = int32(t)
//line dcells.w:1398
	if m < s.second {
//line dcells.w:1399
		*hasPrimary = true
//line dcells.w:1400
	}
//line dcells.w:1401
	s.setSize(slot, t+1)
//line dcells.w:1402
	s.setPos(slot, s.lastNode)
//line dcells.w:1403
}

//line dcells.w:1412
func (s *XCC) finalize() {
//line dcells.w:1413
	s.active, s.itemlen = s.lastItm-1, s.lastItm-1
//line dcells.w:1414
	s.item = ensure(s.item, s.itemlen)
//line dcells.w:1415
	s.set = ensure(s.set, (s.itemlen<<2)+1) // all input slots readable

//line dcells.w:1417
	j := primExtra
//line dcells.w:1418
	k := 0
//line dcells.w:1419
	for ; k < s.itemlen; k++ {
//line dcells.w:1420
		s.item[k] = int32(j)
//line dcells.w:1421
		j += primExtra + s.size((k+1)<<2)
//line dcells.w:1422
	}
//line dcells.w:1423
	s.setlen = j - primExtra
//line dcells.w:1424
	s.set = ensure(s.set, j+1)
//line dcells.w:1425
	if s.second == secondUnset {
//line dcells.w:1426
		s.osecond, s.second = s.active, j
//line dcells.w:1427
	} else {
//line dcells.w:1428
		s.osecond = s.second - 1
//line dcells.w:1429
	}

//line dcells.w:1431
	for ; k != 0; k-- {
//line dcells.w:1432
		base := int(s.item[k-1])
//line dcells.w:1433
		if k == s.second {
//line dcells.w:1434
			s.second = base
//line dcells.w:1435
		}
//line dcells.w:1436
		s.setSize(base, s.size(k<<2))
//line dcells.w:1437
		if s.size(base) == 0 && k <= s.osecond {
//line dcells.w:1438
			s.baditem = k
//line dcells.w:1439
		}
//line dcells.w:1440
		s.setPos(base, k-1)
//line dcells.w:1441
		s.setItemNo(base, k)
//line dcells.w:1442
	}

//line dcells.w:1444
	for k = 1; k < s.lastNode; k++ {
//line dcells.w:1445
		if s.nd[k].itm < 0 {
//line dcells.w:1446
			continue
//line dcells.w:1447
		}
//line dcells.w:1448
		base := int(s.item[int(s.nd[k].itm)-1])
//line dcells.w:1449
		loc := base + int(s.nd[k].loc)
//line dcells.w:1450
		s.nd[k].itm = int32(base)
//line dcells.w:1451
		s.nd[k].loc = int32(loc)
//line dcells.w:1452
		s.set[loc] = int32(k)
//line dcells.w:1453
	}
//line dcells.w:1454
}

//line dcells.w:1460
func (m *MCC) inputMatrix(rd io.Reader) {
//line dcells.w:1461
	br := bufio.NewReader(rd)
//line dcells.w:1462
	m.readItemNames(br)
//line dcells.w:1463
	m.readOptions(br)
//line dcells.w:1464
}

//line dcells.w:1473
func mustAtoi(s string) int {
//line dcells.w:1474
	n, err := strconv.Atoi(s)
//line dcells.w:1475
	if err != nil || n < 0 {
//line dcells.w:1476
		failf("illegal number in bound spec: %q", s)
//line dcells.w:1477
	}
//line dcells.w:1478
	return n
//line dcells.w:1479
}

//line dcells.w:1481
func parseItemSpec(tok string, inSecondary bool) (name string, lower, upper int) {
//line dcells.w:1482
	if i := strings.IndexByte(tok, '|'); i >= 0 {
//line dcells.w:1483
		if inSecondary {
//line dcells.w:1484
			failf("secondary item cannot have a multiplicity: %q", tok)
//line dcells.w:1485
		}
//line dcells.w:1486
		spec, nm := tok[:i], tok[i+1:]
//line dcells.w:1487
		if j := strings.IndexByte(spec, ':'); j >= 0 {
//line dcells.w:1488
			lower, upper = mustAtoi(spec[:j]), mustAtoi(spec[j+1:])
//line dcells.w:1489
		} else {
//line dcells.w:1490
			upper = mustAtoi(spec)
//line dcells.w:1491
			lower = upper
//line dcells.w:1492
		}
//line dcells.w:1493
		if upper == 0 {
//line dcells.w:1494
			failf("upper bound is zero: %q", tok)
//line dcells.w:1495
		}
//line dcells.w:1496
		if lower > upper {
//line dcells.w:1497
			failf("lower bound exceeds upper bound: %q", tok)
//line dcells.w:1498
		}
//line dcells.w:1499
		name = nm
//line dcells.w:1500
	} else {
//line dcells.w:1501
		name, lower, upper = tok, 1, 1
//line dcells.w:1502
	}
//line dcells.w:1503
	if name == "" {
//line dcells.w:1504
		failf("item name empty: %q", tok)
//line dcells.w:1505
	}
//line dcells.w:1506
	if strings.ContainsAny(name, ":|") {
//line dcells.w:1507
		failf("illegal character in item name: %q", name)
//line dcells.w:1508
	}
//line dcells.w:1509
	return
//line dcells.w:1510
}

//line dcells.w:1516
func (m *MCC) readItemNames(br *bufio.Reader) {
//line dcells.w:1517
	var buf []byte
//line dcells.w:1518
	var p int
//line dcells.w:1519
	found := false
//line dcells.w:1520
	for {
//line dcells.w:1521
		var ok bool
//line dcells.w:1522
		if buf, ok = nextLine(br); !ok {
//line dcells.w:1523
			break
//line dcells.w:1524
		}
//line dcells.w:1525
		if p = skipSpace(buf, 0); buf[p] != '|' && buf[p] != 0 {
//line dcells.w:1526
			found = true
//line dcells.w:1527
			break
//line dcells.w:1528
		}
//line dcells.w:1529
	}
//line dcells.w:1530
	if !found {
//line dcells.w:1531
		failf("no items")
//line dcells.w:1532
	}
//line dcells.w:1533
	for buf[p] != 0 {
//line dcells.w:1534
		tok, next := token(buf, p, false)
//line dcells.w:1535
		if tok == "|" {
//line dcells.w:1536
			if m.second != secondUnset {
//line dcells.w:1537
				failf("item name line contains | twice")
//line dcells.w:1538
			}
//line dcells.w:1539
			m.second = len(m.names) // the next item's number
//line dcells.w:1540
		} else {
//line dcells.w:1541
			name, lower, upper := parseItemSpec(tok, m.second != secondUnset)
//line dcells.w:1542
			num, ok := m.internName(name)
//line dcells.w:1543
			if !ok {
//line dcells.w:1544
				failf("duplicate item name: %s", name)
//line dcells.w:1545
			}
//line dcells.w:1546
			slot := num * mccIprop
//line dcells.w:1547
			m.set = ensure(m.set, slot)
//line dcells.w:1548
			m.setSlack(slot, upper-lower)
//line dcells.w:1549
			m.setBound(slot, upper)
//line dcells.w:1550
		}
//line dcells.w:1551
		p = skipSpace(buf, next)
//line dcells.w:1552
	}
//line dcells.w:1553
	m.lastItm = len(m.names)
//line dcells.w:1554
}

//line dcells.w:1557
func (m *MCC) readOptions(br *bufio.Reader) {
//line dcells.w:1558
	for {
//line dcells.w:1559
		buf, ok := nextLine(br)
//line dcells.w:1560
		if !ok {
//line dcells.w:1561
			break
//line dcells.w:1562
		}
//line dcells.w:1563
		if p := skipSpace(buf, 0); buf[p] == '|' || buf[p] == 0 {
//line dcells.w:1564
			continue
//line dcells.w:1565
		}
//line dcells.w:1566
		m.readOption(buf)
//line dcells.w:1567
	}
//line dcells.w:1568
	m.finalize()
//line dcells.w:1569
}

//line dcells.w:1574
func (m *MCC) readOption(buf []byte) {
//line dcells.w:1575
	spacer := m.lastNode
//line dcells.w:1576
	hasPrimary := false
//line dcells.w:1577
	for p := skipSpace(buf, 0); buf[p] != 0; {
//line dcells.w:1578
		name, next := token(buf, p, true)
//line dcells.w:1579
		if name == "" {
//line dcells.w:1580
			failf("empty item name")
//line dcells.w:1581
		}
//line dcells.w:1582
		num, known := m.nameIndex[name]
//line dcells.w:1583
		if !known {
//line dcells.w:1584
			failf("unknown item name: %s", name)
//line dcells.w:1585
		}
//line dcells.w:1586
		m.createNode(num, spacer, &hasPrimary)
//line dcells.w:1587
		if buf[next] == ':' {
//line dcells.w:1588
			if num < m.second {
//line dcells.w:1589
				failf("primary item must be uncolored: %s", name)
//line dcells.w:1590
			}
//line dcells.w:1591
			color, ce := token(buf, next+1, false)
//line dcells.w:1592
			if color == "" {
//line dcells.w:1593
				failf("missing color after %s:", name)
//line dcells.w:1594
			}
//line dcells.w:1595
			m.nd[m.lastNode].clr = int32(m.internColor(color))
//line dcells.w:1596
			next = ce
//line dcells.w:1597
		} else {
//line dcells.w:1598
			m.nd[m.lastNode].clr = 0
//line dcells.w:1599
		}
//line dcells.w:1600
		p = skipSpace(buf, next)
//line dcells.w:1601
	}

//line dcells.w:1603
	if !hasPrimary {
//line dcells.w:1604
		for m.lastNode > spacer {
//line dcells.w:1605
			slot := int(m.nd[m.lastNode].itm) * mccIprop
//line dcells.w:1606
			m.setSize(slot, m.size(slot)-1)
//line dcells.w:1607
			m.setPos(slot, spacer-1)
//line dcells.w:1608
			m.lastNode--
//line dcells.w:1609
		}
//line dcells.w:1610
		return
//line dcells.w:1611
	}
//line dcells.w:1612
	m.nd[spacer].loc = int32(m.lastNode - spacer)
//line dcells.w:1613
	m.lastNode++
//line dcells.w:1614
	m.nd = ensure(m.nd, m.lastNode+1)
//line dcells.w:1615
	m.options++
//line dcells.w:1616
	m.nd[m.lastNode].itm = int32(spacer + 1 - m.lastNode)
//line dcells.w:1617
}

//line dcells.w:1620
func (m *MCC) createNode(num, spacer int, hasPrimary *bool) {
//line dcells.w:1621
	slot := num * mccIprop
//line dcells.w:1622
	m.set = ensure(m.set, slot)
//line dcells.w:1623
	if m.pos(slot) > spacer {
//line dcells.w:1624
		failf("duplicate item name in this option: %s", m.names[num])
//line dcells.w:1625
	}
//line dcells.w:1626
	m.lastNode++
//line dcells.w:1627
	m.nd = ensure(m.nd, m.lastNode+1)
//line dcells.w:1628
	t := m.size(slot)
//line dcells.w:1629
	m.nd[m.lastNode].itm = int32(num)
//line dcells.w:1630
	m.nd[m.lastNode].loc = int32(t)
//line dcells.w:1631
	if num < m.second {
//line dcells.w:1632
		*hasPrimary = true
//line dcells.w:1633
	}
//line dcells.w:1634
	m.setSize(slot, t+1)
//line dcells.w:1635
	m.setPos(slot, m.lastNode)
//line dcells.w:1636
}

//line dcells.w:1643
func (m *MCC) finalize() {
//line dcells.w:1644
	m.active, m.itemlen = m.lastItm-1, m.lastItm-1
//line dcells.w:1645
	m.item = ensure(m.item, m.itemlen)
//line dcells.w:1646
	m.set = ensure(m.set, m.itemlen*mccIprop+1) // all input slots readable

//line dcells.w:1648
	j := mccExtra
//line dcells.w:1649
	k := 0
//line dcells.w:1650
	for ; k < m.itemlen; k++ {
//line dcells.w:1651
		m.item[k] = int32(j)
//line dcells.w:1652
		j += mccExtra + m.size((k+1)*mccIprop)
//line dcells.w:1653
	}
//line dcells.w:1654
	m.setlen = j - mccExtra
//line dcells.w:1655
	m.set = ensure(m.set, j+1)
//line dcells.w:1656
	if m.second == secondUnset {
//line dcells.w:1657
		m.osecond, m.second = m.active, j
//line dcells.w:1658
	} else {
//line dcells.w:1659
		m.osecond = m.second - 1
//line dcells.w:1660
	}

//line dcells.w:1662
	for ; k != 0; k-- {
//line dcells.w:1663
		base := int(m.item[k-1])
//line dcells.w:1664
		if k == m.second {
//line dcells.w:1665
			m.second = base
//line dcells.w:1666
		}
//line dcells.w:1667
		m.setSize(base, m.size(k*mccIprop))
//line dcells.w:1668
		m.setItemNo(base, k)
//line dcells.w:1669
		m.setSlack(base, m.slack(k*mccIprop))
//line dcells.w:1670
		m.setBound(base, m.bound(k*mccIprop))
//line dcells.w:1671
		m.setPos(base, k-1)
//line dcells.w:1672
		switch {
//line dcells.w:1673
		case k <= m.osecond && m.size(base) < m.bound(base)-m.slack(base):
//line dcells.w:1674
			m.baditem = k
//line dcells.w:1675
		case m.size(base) == 0:
//line dcells.w:1676
			m.force = ensure(m.force, m.forced+1)
//line dcells.w:1677
			m.force[m.forced] = int32(base)
//line dcells.w:1678
			m.forced++
//line dcells.w:1679
		}
//line dcells.w:1680
	}

//line dcells.w:1682
	for k = 1; k < m.lastNode; k++ {
//line dcells.w:1683
		if m.nd[k].itm < 0 {
//line dcells.w:1684
			continue
//line dcells.w:1685
		}
//line dcells.w:1686
		base := int(m.item[int(m.nd[k].itm)-1])
//line dcells.w:1687
		loc := base + int(m.nd[k].loc)
//line dcells.w:1688
		m.nd[k].itm = int32(base)
//line dcells.w:1689
		m.nd[k].loc = int32(loc)
//line dcells.w:1690
		m.set[loc] = int32(k)
//line dcells.w:1691
	}

//line dcells.w:1693
	m.deactivateOptionless()
//line dcells.w:1694
}

//line dcells.w:1701
func (m *MCC) deactivateOptionless() {
//line dcells.w:1702
	for m.forced != 0 {
//line dcells.w:1703
		m.forced--
//line dcells.w:1704
		j := int(m.force[m.forced])
//line dcells.w:1705
		m.active--
//line dcells.w:1706
		i := int(m.item[m.active])
//line dcells.w:1707
		pp := m.pos(j)
//line dcells.w:1708
		m.item[m.active], m.item[pp] = int32(j), int32(i)
//line dcells.w:1709
		m.setPos(j, m.active)
//line dcells.w:1710
		m.setPos(i, pp)
//line dcells.w:1711
	}
//line dcells.w:1712
}
