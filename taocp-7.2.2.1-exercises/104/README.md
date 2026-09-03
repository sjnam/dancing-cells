# TAOCP 7.2.2.1, Exercise 104: An Audit

Written 3 September 2026, against Volume 4B, Addison-Wesley, first printing,
2022, and the errata file as of that date.

## Verdict

| Item | Finding |
| --- | --- |
| Exercise 104 (statement) | No error. Amended for clarity, 15 Sept 2025. |
| Answer 104(a) | Correct. One step left implicit. |
| Answer 104(b) | Correct, and stronger than it needs to be. |

Everything the exercise asserts checks out: the printed sequence $x^{(5)}$ is
right index for index, and the "amazing" 12-tone row really is perfect. Both
parts of the answer hold for every row reachable by exhaustive search, which
here means every $n$ up to 12 with $n + 1$ prime — all 39,916,800 rows in the
largest case.

The argument for part (a) proves more than it claims. It shows that a perfect
row *is* a table of discrete logarithms, and since the converse is easy, the
perfect rows are exactly those tables: $\varphi(n)$ of them for each $n$, one
per primitive root modulo $p$. The amazing row is the one belonging to $R = 2$,
the smallest primitive root of 13.

---

## 1. What the exercise asks

An $n$-tone row is a permutation $x = x\_0x\_1\ldots x\_{n-1}$ of
$\{0, 1, \ldots, n-1\}$. Two rows are *equivalent* when they differ by a
transposition, that is, when $x'\_k = (x\_k + d) \bmod n$ for some fixed $d$.
Exercise 103 studies rows whose $n - 1$ adjacent intervals
$(x\_k - x\_{k-1}) \bmod n$ are all different — the *all-interval* rows.

Exercise 104 assumes $n + 1 = p$ is prime and defines "every $r\text{th}$ element":

> Given an $n$-tone row $x = x\_0x\_1\ldots x\_{n-1}$, define
> $y\_k = x\_{(k-1) \bmod p}$, and let $x^{(r)} = y\_r y\_{2r} \ldots y\_{nr}$ be
> the $n$-tone row consisting of "every $r\text{th}$ element of $x$" (where
> $x\_n$ is
> considered to be blank). For example, when $n = 12$, every 5th element of $x$
> is the sequence
> $x^{(5)} = x\_4 x\_9 x\_1 x\_6 x\_{11} x\_3 x\_8 x\_0 x\_5 x\_{10} x\_2 x\_7$.
>
> An $n$-tone row is called *perfect* if it is equivalent to $x^{(r)}$ for
> $1 \le r \le n$. For example, the amazing 12-tone row
> 0 1 4 2 9 5 11 3 8 10 7 6 is perfect.
>
> a) Prove that a perfect $n$-tone row has the all-interval property.
> b) Prove that a perfect $n$-tone row also satisfies $x \equiv x^R$.

Unwinding the two definitions, the $j\text{th}$ element of $x^{(r)}$ is
$x\_{(jr - 1) \bmod p}$ for $1 \le j \le n$.

### 1.1 The errata amendment

The statement above is the amended one. From `err4b.textxt`, dated 15 September
2025:

```tex
\amendpage 4b.135 in exercise 104 (25.09.15)
\ninepoint line 2: whenever $k$ is not a multiple of~$p$ \becomes\nl
line 3: (if $x_n$ is blank) \becomes
(where $x_n$ is considered to be blank)
\endchange
```

The first printing hedged the definition of $y\_k$ with "whenever $k$ is not a
multiple of $p$"; the amendment drops that clause and instead declares $x\_n$
blank. This is an `\amendpage`, not a `\bugonpage` — new material for a future
printing, not a correction. Both readings describe the same object, since
$y\_{jr}$ is never asked for at a multiple of $p$.

---

## 2. Checking what the exercise prints

### 2.1 The sequence $x^{(5)}$

For $n = 12$ and $r = 5$ the definition gives index $(5j - 1) \bmod 13$ at
position $j$:

```text
the exercise says that every 5th element of a 12-tone row is
   x4 x9 x1 x6 x11 x3 x8 x0 x5 x10 x2 x7
the definition gives [4 9 1 6 11 3 8 0 5 10 2 7]
agrees: true
```

### 2.2 The amazing row

```text
the amazing row [0 1 4 2 9 5 11 3 8 10 7 6]
   is perfect:            true
   has all intervals:     true
   is equivalent to x^R:  true
   is the index table of R=2: true
```

The last line is not part of the exercise but explains where the row comes from.
It is the table of discrete logarithms base 2 modulo 13: $x\_{k-1}$ is the
exponent $e$ with $2^e \equiv k$.

### 2.3 Why $p$ has to be prime

The hypothesis is not decoration. If $p$ were composite, say $p = ab$ with
$1 < a, b < p$, then $x^{(b)}$ would ask for $y\_{ab} = y\_p = x\_{p-1} = x\_n$,
which the exercise declares blank — the construction would not even be defined.
Since $a$ and $b$ are both at most $n$, this happens for every composite $p$:

| $n$ | $p$ | the collision |
| --- | --- | --- |
| 3 | 4 = 2·2 | $x^{(2)}$ needs $y\_4 = x\_3$ |
| 5 | 6 = 2·3 | $x^{(3)}$ needs $y\_6 = x\_5$ |
| 8 | 9 = 3·3 | $x^{(3)}$ needs $y\_9 = x\_8$ |

Conversely, when $p$ is prime no product $jr$ with $1 \le j, r \le n$ is a
multiple of $p$, so $x^{(r)}$ is always a genuine $n$-tone row.

---

## 3. Answer (a)

> We may assume that $x\_0 = 0$. There's a constant $c\_r$ such that
> $y\_{kr} \equiv x\_{k-1} + c\_r$ (modulo $n$) for $1 \le k \le n$. Thus
> $y\_r = x\_{r-1} \equiv c\_r$;
> $y\_{r^2} = x\_{(r^2-1) \bmod p} \equiv x\_{r-1} + c\_r \equiv 2c\_r$;
> $y\_{r^3} = x\_{(r^3-1) \bmod p} \equiv x\_{(r^2-1) \bmod p} + c\_r \equiv 3c\_r$;
> etc. Let $r$ be primitive modulo $p$, so that
> $\{r \bmod p, \ldots, r^n \bmod p\} = \{1, \ldots, p-1\}$, and let $R = r^d$
> where $c\_r d \bmod n = 1$. Then we've proved
> $R^{x\_{(r^k-1) \bmod p}} \equiv (r^k \bmod p)$ (modulo $p$) for
> $1 \le k \le n$; that is, $R^{x\_{k-1}} \equiv k$.
>
> Now suppose $x\_k - x\_{k-1} \equiv x\_l - x\_{l-1}$ (modulo $n$). Then
> $R^{x\_k} R^{x\_{l-1}} \equiv R^{x\_{k-1}} R^{x\_l}$ (modulo $p$); consequently
> $(k+1)l \equiv k(l+1)$ (modulo $p$), hence $k = l$.

### 3.1 The argument, checked step by step

Every step holds.

- *The constant* — "there's a constant $c\_r$" is exactly what
  $x \equiv x^{(r)}$ says, written out: $x^{(r)}\_{j-1} = y\_{jr}$, and
  equivalence means $x^{(r)}\_{j-1} = x\_{j-1} + c\_r$.
- *The iteration* — taking $k = 1$ gives $y\_r = x\_{r-1} \equiv c\_r$; taking
  $k = r$ gives $x\_{(r^2-1) \bmod p} \equiv x\_{r-1} + c\_r$; and in general
  $x\_{(r^k - 1) \bmod p} \equiv k c\_r \pmod n$ for $k \ge 1$.
- *The conclusion* — with $R = r^d$ and $c\_r d \equiv 1$, and since $r$ has
  order $n$ modulo $p$ so that exponents may be reduced modulo $n$,
  $R^{x\_{(r^k-1) \bmod p}} = r^{d k c\_r} = r^k$. As $k$ runs from 1 to $n$,
  $r^k \bmod p$ runs through $1, \ldots, n$, so this is $R^{x\_{k-1}} \equiv k$
  after renaming.
- *The finish* — $R^{x\_k} \equiv k+1$ and $R^{x\_{l-1}} \equiv l$, so equal
  intervals give $(k+1)l \equiv k(l+1)$, that is $l \equiv k \pmod p$; and
  $1 \le k, l \le n < p$, so $k = l$. The $n - 1$ intervals are therefore
  distinct, and none is zero because $x$ is a permutation, so they are exactly
  $\{1, \ldots, n-1\}$.

### 3.2 The one step left implicit

"Let $R = r^d$ where $c\_r d \bmod n = 1$" presumes that such a $d$ exists, that
is, that $\gcd(c\_r, n) = 1$. The answer does not say why.

It is true, and the reason is the clause immediately before it. Because $r$ is
primitive, $(r^k - 1) \bmod p$ runs through all of $0, \ldots, n-1$ as $k$ runs
through $1, \ldots, n$; so the left sides of
$x\_{(r^k-1) \bmod p} \equiv k c\_r$ exhaust the permutation $x$, forcing the
values $k c\_r \bmod n$ to exhaust $\{0, \ldots, n-1\}$, which happens only when
$c\_r$ generates the additive group — that is, when $\gcd(c\_r, n) = 1$.

The restriction to primitive $r$ is doing real work here, and dropping it would
break the step. For the amazing row, $c\_r$ turns out to be the index of $r$, so
it is invertible exactly when $r$ is itself primitive:

```text
for the row [0 1 4 2 9 5 11 3 8 10 7 6] (n=12, p=13):
   r ord(r)    c_r    gcd
   1      1      0     12
   2     12      1      1 d exists
   3      3      4      4
   4      6      2      2
   5      4      9      3
   6     12      5      1 d exists
   7     12     11      1 d exists
   8      4      3      3
   9      3      8      4
  10      6     10      2
  11     12      7      1 d exists
  12      2      6      6
```

Four values of $r$ admit a $d$, and they are precisely the four primitive roots
of 13. This is an elision in the exposition, not a gap in the mathematics.

### 3.3 What the argument actually proves

The chain ends at $R^{x\_{k-1}} \equiv k$, which says that $x$ is the table of
indices to base $R$. The converse takes one line: if
$x\_{k-1} = \mathrm{ind}\_R k$ then

$$y_{jr} = \mathrm{ind}_R(jr \bmod p) = x_{j-1} + \mathrm{ind}_R r,$$

so $x \equiv x^{(r)}$ with $c\_r = \mathrm{ind}\_R r$.

So *perfect* and *table of discrete logarithms* are the same condition, and the
perfect rows can be counted: one per primitive root modulo $p$, hence
$\varphi(p-1) = \varphi(n)$ of them up to transposition. The exercise does not
mention this, and neither does the answer, but it falls out of the proof and
gives something sharp to test against.

### 3.4 Exhaustive verification

Every row with $x\_0 = 0$ — one representative per equivalence class — was
visited for each $n \le 12$ with $n+1$ prime, and each was asked whether it is
perfect, whether it has the all-interval property, whether it is equivalent to
its reversal, and whether it is one of the tables of logarithms.

| $n$ | $p$ | rows | perf. | all-int. | $x \equiv x^R$ | $\varphi(n)$ | tables |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2 | 1 | 1 | 1 | 1 | 1 | yes |
| 2 | 3 | 1 | 1 | 1 | 1 | 1 | yes |
| 4 | 5 | 6 | 2 | 2 | 2 | 2 | yes |
| 6 | 7 | 120 | 2 | 2 | 2 | 2 | yes |
| 10 | 11 | 362,880 | 4 | 4 | 4 | 4 | yes |
| 12 | 13 | 39,916,800 | 4 | 4 | 4 | 4 | yes |

The perfect column equals the all-interval column in every line, which is
part (a); it equals the $x \equiv x^R$ column, which is part (b); and it equals
$\varphi(n)$, with the rows themselves matching the tables of logarithms
one for one.

---

## 4. Answer (b)

> $x^{(n)} = x^R$. [See the papers by Lehmer and Gilbert in answer 103.]

This is correct, and worth spelling out because the equation is an identity
rather than an equivalence. Since $n \equiv -1$ modulo $p$, we get
$(jn - 1) \bmod p = (-j-1) \bmod p = n - j$, so the $j\text{th}$ element of $x^{(n)}$
is $x\_{n-j}$ — the reversal exactly, on the nose, with no transposition needed.

It holds for **every** row, perfect or not, which the one-line answer rather
undersells. A perfect row is equivalent to $x^{(r)}$ for every $r$, in
particular for $r = n$, and therefore to $x^R$. Checked against every row with
$x\_0 = 0$:

```text
n= 2: x^(n) = x^R for every row, exceptions so far: 0
n= 4: x^(n) = x^R for every row, exceptions so far: 0
n= 6: x^(n) = x^R for every row, exceptions so far: 0
n=10: x^(n) = x^R for every row, exceptions so far: 0
n=12: x^(n) = x^R for every row, exceptions so far: 0
```

---

## 5. Cross-check: answer 103(b) through our own solver

Exercise 103(b) asks for the all-interval rows by way of Algorithm C, and its
answer supplies an XCC formulation together with the counts. Building that
formulation here serves two purposes: it puts a published number next to a run
of our own `ssxcc`, and it confirms that the perfect rows have somewhere to
live — every one of them must appear among the all-interval solutions if
part (a) is right.

The items are a position $j$ and a pitch $p\_t$ for $0 \le j, t < n$, an
interval value $d\_k$ and an interval slot $q\_t$ for $1 \le k, t < n$, all
primary, plus a secondary item $x\_j$ per position whose color is the pitch
landing there. One
family of options places a pitch in a position; the other says "interval $k$
sits in slot $t$" and carries the arithmetic in its colors,
$x\_{t-1}\!:\!i$ and $x\_t\!:\!(i+k) \bmod n$. Options that disagree about a
position cannot both be chosen, because a secondary item admits one color only,
and that single mechanism makes the row and its intervals permutations at the
same time.

```text
  n    items   options   solutions      nodes   answer 103(b)
  2        8         4           1          4   1 agrees
  4       18        46           2         13   2 agrees
  6       28       176           4         63   4 agrees
  8       38       442          24        755   24 agrees
 10       48       892         288      12419   288 agrees
 12       58      1574        3856     315259   3856 agrees
```

All six counts match the published (1, 2, 4, 24, 288, 3856). Note the line for
$n = 8$: $p = 9$ is not prime, so no perfect rows are defined there, yet
all-interval rows exist in quantity. Perfection is a much stronger demand than
the all-interval property — 4 rows out of 3856 when $n = 12$.

---

## 6. Method

One program did the work, kept in [`verify/`](verify/). It is a GWEB literate
program — [`verify.w`](verify/verify.w) is the source, and `gtangle` produces
the Go from it. The typeset document, [`verify.pdf`](verify/verify.pdf), is
committed beside the source, so it can be read without installing GWEB.

It has four modes.

1. `-mode example` checks what the exercise prints: the index pattern of
   $x^{(5)}$, the perfection of the amazing row, and the identity
   $x^{(n)} = x^R$ over every row.
2. `-mode perfect` exhibits the table of logarithms for each primitive root and
   shows the $\gcd(c\_r, n)$ table behind §3.2.
3. `-mode all` is the exhaustive search of §3.4.
4. `-mode xcc` builds answer 103(b)'s formulation and runs it through `ssxcc`.

To reproduce:

```sh
make tangle                     # gtangle verify.w -> verify.go
cd taocp-7.2.2.1-exercises/104/verify && go build -o v .
./v -mode example
./v -mode perfect
./v -mode all                   # about 4 seconds
./v -mode xcc
```

`make pdf` regenerates `verify.pdf` from `verify.w`.

---

## 7. References

- D. E. Knuth, *The Art of Computer Programming*, Volume 4B (Addison-Wesley,
  2022), §7.2.2.1, exercises 103–104 (p. 135), answers (pp. 439–440).
- D. E. Knuth, *Changes to Volume 4B*,
  <https://cs.stanford.edu/~knuth/err4b.textxt>, entry
  `\amendpage 4b.135 in exercise 104 (25.09.15)`.
- D. H. Lehmer, *Proc. Canadian Math. Congress* **4** (1959), 171–173.
- E. N. Gilbert, *SIAM Review* **7** (1965), 189–198.
