package main

// A faithful port of Knuth's gb_flip (the portable random number generator
// from the Stanford GraphBase), so that the `s<seed>` randomizing option
// reproduces exactly the same item shuffles as the original C program.

var (
	gbA    [56]int64
	gbFptr int // index into gbA; gb_next_rand reads gbA[gbFptr]
)

func modDiff(x, y int64) int64 { return (x - y) & 0x7fffffff }

func gbFlipCycle() int64 {
	ii, jj := 1, 32
	for ; jj <= 55; ii, jj = ii+1, jj+1 {
		gbA[ii] = modDiff(gbA[ii], gbA[jj])
	}
	for jj = 1; ii <= 55; ii, jj = ii+1, jj+1 {
		gbA[ii] = modDiff(gbA[ii], gbA[jj])
	}
	gbFptr = 54
	return gbA[55]
}

func gbNextRand() int64 {
	// gbA[0] is the sentinel -1, which triggers a refill cycle.
	if gbA[gbFptr] >= 0 {
		v := gbA[gbFptr]
		gbFptr--
		return v
	}
	return gbFlipCycle()
}

func gbInitRand(seed int64) {
	gbA[0] = -1 // sentinel
	prev, next := seed, int64(1)
	seed = modDiff(prev, 0)
	prev = seed
	gbA[55] = prev
	for i := 21; i != 0; i = (i + 21) % 55 {
		gbA[i] = next
		next = modDiff(prev, next)
		if seed&1 != 0 {
			seed = 0x40000000 + (seed >> 1)
		} else {
			seed >>= 1
		}
		next = modDiff(next, seed)
		prev = gbA[i]
	}
	gbFlipCycle()
	gbFlipCycle()
	gbFlipCycle()
	gbFlipCycle()
	gbFlipCycle()
}

func gbUnifRand(m int64) int64 {
	t := uint64(0x80000000) - uint64(0x80000000)%uint64(m)
	var r int64
	for {
		r = gbNextRand()
		if t > uint64(r) {
			break
		}
	}
	return r % m
}
