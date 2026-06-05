# ssxcc — XCC solver with "dancing cells" (Go)

Donald E. Knuth의 CWEB 프로그램
[`SSXCC`](https://www-cs-faculty.stanford.edu/~knuth/programs/ssxcc.w)를
Go로 옮긴 것입니다. dancing **links**가 아니라 **sparse-set**("dancing cells")
자료구조로 색 제약이 있는 정확 피복(exact cover with colors, XCC) 문제를 풉니다.

원본과 같은 DLX 입력 형식을 받습니다. 원본의 `goto` 기반 상태기계를 재귀로,
직접 짠 명령행 파서를 `flag` 패키지로, 한 덩어리 코드를 역할별 파일로 나눠
관용적인 Go로 작성했습니다. Knuth 특유의 `mems` 계측은 제거했습니다.

## 빌드 & 실행

```sh
go build -o ssxcc .
./ssxcc examples/exactcover.dlx          # 파일을 인자로
./ssxcc -m 1 examples/exactcover.dlx     # 모든 해를 출력
./ssxcc < examples/exactcover.dlx        # 표준입력으로도 가능
python3 examples/queens.py 8 | ./ssxcc -m 1
```

## 입력 형식 (DLX)

- 첫 비주석 줄: 항목 이름들. `|` 왼쪽은 1차(primary, 반드시 덮어야 함),
  오른쪽은 2차(secondary, 최대 한 번, 색 지정 가능) 항목입니다.
- 이후 각 줄은 옵션 하나로, 포함하는 항목 이름을 나열합니다.
  2차 항목엔 `name:c` 처럼 한 글자 색을 붙일 수 있습니다.
- `|` 로 시작하거나 빈 줄은 주석/무시됩니다.

```text
a b c d e f g          # 1차 항목 7개
c e
a d g
...
```

## 명령행 플래그

`flag` 패키지를 쓰므로 `-v 6` 처럼 공백 또는 `-v=6` 형태로 줍니다.

| 플래그 | 뜻 |
| --- | --- |
| `-v <n>` | verbose 비트마스크 (1 basics, 2 choices, 4 details, 128 profile, 256 full state, 512 totals, 1024 warnings, 2048 max degree) |
| `-m <n>` | n번째 해마다 출력 (`-m 0` = 개수만 셈, 기본값) |
| `-s <n>` | 항목 리스트를 시드 n으로 무작위화 (gb_flip 사용) |
| `-d <n>` | n개의 탐색 노드마다 진행 상황 보고 (0 = 안 함) |
| `-c`/`-C`/`-l <n>` | 추적 출력 레벨 제한 |
| `-t <n>` | 해를 n개 찾으면 정지 (0 = 무제한) |
| `-T <n>` | 탐색 노드가 n을 넘으면 중단 (0 = 무제한) |
| `-S <file>` | 탐색 트리 모양(shape) 파일 출력 |

> 원본의 `-d`/`-T`는 mems 기준이었으나, mems 계측을 없앴으므로 여기서는 탐색
> **노드 수** 기준으로 동작합니다.

## 파일 구성

| 파일 | 역할 |
| --- | --- |
| `main.go` | `flag` 파싱, 입출력 준비, 결과 보고 |
| `parse.go` | DLX 입력 파서 (`readItemNames`, `readOptions`, `createNode`, `finalize`) |
| `dance.go` | 재귀 탐색(`search`/`chooseItem`/`commitOption`/`hide`)과 sparse-set 연산 |
| `state.go` | 전역 상태, 타입, 필드 접근자, 이름 인코딩, 출력/`sanity` 보조 |
| `gbflip.go` | Knuth의 이식성 난수기 gb_flip 포팅 (`-s` 셔플용) |

### 재귀 구조에 대해

원본은 forced move일 때 도메인 크기를 저장하지 않는 최적화를 위해 `goto`로
backtracking 위치를 직접 관리합니다. 이 포팅은 모든 레벨에서 대칭적으로
save/restore 하는 평범한 재귀로 바꿨습니다. save/restore는 **탐색 경로에
영향을 주지 않는 순수 부기**라서, 해·해 순서·노드 수·updates가 원본과 그대로
일치합니다(단지 forced 레벨에서 불필요한 크기 저장이 조금 더 일어날 뿐입니다).

## 원본과의 동치성 검증

`ctangle ssxcc.w && cc -std=gnu89 ssxcc.c -o ssxcc_ref` 로 만든 레퍼런스와,
mems/bytes/ccost(이 포팅에서 제거한 항목)를 제외한 모든 출력이 일치합니다:
해와 해 순서, `count`·`updates`·`nodes`·`maxdeg`·profile, shape 파일,
`-v 2`/`-v 4` 추적까지.

예) 13-queens: `73712 solutions, 29080172 updates, 1278828 nodes` — C·Go 동일.
