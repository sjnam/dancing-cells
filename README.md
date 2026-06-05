# ssxcc — XCC solver with "dancing cells" (Go port)

Donald E. Knuth의 CWEB 프로그램
[`SSXCC`](https://www-cs-faculty.stanford.edu/~knuth/programs/ssxcc.w)를
Go로 옮긴 것입니다. dancing **links**가 아니라 **sparse-set**("dancing cells")
자료구조로 색 제약이 있는 정확 피복(exact cover with colors, XCC) 문제를 풉니다.

원본과 같은 DLX 입력 형식을 받고, 같은 통계(solutions, mems, updates, nodes,
bytes, ccost)를 **바이트 단위로 동일하게** 출력하도록 포팅했습니다. 즉
`mems++`/`mems += n` 계측은 Knuth의 `o`/`oo`/`ooo` 주석을 그대로 따라갑니다.

## 빌드 & 실행

```sh
go build -o ssxcc .
./ssxcc < examples/exactcover.dlx          # 풀고 통계만 출력
./ssxcc m1 < examples/exactcover.dlx       # 모든 해를 출력
python3 examples/queens.py 8 | ./ssxcc m1  # 8-queens
```

## 입력 형식 (DLX)

- 첫 비주석 줄: 항목 이름들. `|` 왼쪽은 1차(primary, 반드시 덮어야 함),
  오른쪽은 2차(secondary, 최대 한 번, 색 지정 가능) 항목입니다.
- 이후 각 줄은 옵션 하나: 포함하는 항목 이름들을 나열합니다.
  2차 항목엔 `name:c` 처럼 한 글자 색을 붙일 수 있습니다.
- `|` 로 시작하거나 빈 줄은 주석/무시됩니다.

```
a b c d e f g          # 1차 항목 7개
c e
a d g
...
```

## 명령행 옵션 (원본과 동일)

| 옵션 | 뜻 |
|------|----|
| `v<n>` | verbose 비트마스크 (1 basics, 2 choices, 4 details, 128 profile, 256 full state, 512 totals, 1024 warnings, 2048 max degree) |
| `m<n>` | n번째 해마다 출력 (`m0` = 개수만 셈, 기본값) |
| `s<n>` | 항목 리스트를 시드 n으로 무작위화 (gb_flip 사용) |
| `d<n>` | 약 n mems마다 진행 상황 보고 |
| `c<n>`/`C<n>`/`l<n>` | 추적 출력 레벨 제한 |
| `t<n>` | 해를 n개 찾으면 정지 |
| `T<n>` | mems가 n을 넘으면 중단 |
| `S<file>` | 탐색 트리 모양(shape) 파일 출력 |

## 구현 메모

- `ssxcc.go` — 자료구조, 입력 파서, 탐색(`solve`), 통계.
  탐색 루프는 원본의 `goto` 구조(`forward`/`advance`/`backup`/`abort` 등)를
  그대로 Go의 `goto`로 옮겨 동작이 1:1로 대응됩니다.
- `gbflip.go` — Knuth의 이식성 난수 생성기 gb_flip 포팅. `s<seed>` 옵션의
  셔플이 C 원본과 정확히 같은 순서를 내도록 합니다.
- 거대한 배열(`nd`, `set`, `savestack`)은 C와 같은 폭(`int32`)으로 잡아
  보고되는 byte 수와 메모리 사용이 원본과 맞습니다.

## 원본과의 동치성 검증

`ctangle ssxcc.w && cc -std=gnu89 ssxcc.c -o ssxcc_ref` 로 만든 레퍼런스와
다음이 모두 일치합니다(해, 해 순서, mems, updates, nodes, bytes, shape 파일,
verbose/progress/state 출력까지):

- 7항목 정확 피복 예제, 색 XCC 예제
- 8·13-queens (기본/`v2176`/`s42`/`d2000`/`v256` 모드)

예) 13-queens: `73712 solutions, 46649+412211638 mems, 29080172 updates,
1278828 nodes` — C와 Go가 동일.
