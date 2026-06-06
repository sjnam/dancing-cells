# ssmcc — exact cover with multiplicities + colors ("dancing cells", Go)

Donald E. Knuth의 CWEB 프로그램
[`SSMCC`](https://www-cs-faculty.stanford.edu/~knuth/programs/ssmcc.w)를
Go로 옮긴 것입니다. 자매 프로그램 [`ssxcc`](../ssxcc/README.md)(색 제약 정확
피복)에 **항목 다중도(multiplicity)**를 더한 버전으로, Filip Stappers가 2023년에
DLX3의 다중도 기법을 결합해 확장했습니다.

`ssxcc`와의 핵심 차이:

- **다중도 `[하한..상한]`**: 1차 항목을 정확히 한 번이 아니라 *u~v번* 덮도록
  요구할 수 있습니다. 입력에서 `하한:상한|이름` 또는 `상한|이름`으로 줍니다.
  `bound`(잔여 용량)와 `slack`(=상한−하한)으로 추적합니다.
- **이진 분기(binary branching)**: `ssxcc`의 d-갈래 분기 대신, 각 노드를
  (항목 i, 옵션 o)로 라벨링해 2-갈래로 분기합니다. *왼쪽* 자식은 o를
  포함(i를 한 번 더 덮음), *오른쪽* 자식은 o를 제거(i는 여전히 미충족).
  `level`은 트리 깊이, `stage`는 왼쪽 분기 수(= 부분해의 옵션 수)입니다.
- 분기 휴리스틱은 분기 차수 `l+s−b+1`(l=옵션 수, b=잔여 bound, s=min(slack,b))를
  최소화하는 항목을 고릅니다. 차수가 1이면 강제(forced) 항목입니다.

원본의 비활성 **weight** 스캐폴딩(탐색에서 실제로 읽히지 않음)과 `-w`/`-W`
플래그는 제외했고, Knuth의 `mems` 계측도 (`ssxcc` 포팅과 마찬가지로) 뺐습니다.

## 빌드 & 실행

모듈 루트에서:

```sh
go run ./cmd/ssmcc -m 1 cmd/ssmcc/examples/multiplicity.dlx
python3 cmd/ssmcc/examples/queens.py 8 | go run ./cmd/ssmcc -m 1
go build -o ssmcc ./cmd/ssmcc        # 바이너리로 빌드하려면
```

## 입력 형식

[`ssxcc`](../ssxcc/README.md)와 동일하되, 1차 항목 이름에 다중도 접두사를 붙일 수
있습니다.

```text
2|a b c        # a는 정확히 2번, b·c는 1번(기본) 덮어야 함
a b
a c
b c
```

`1:3|a` 는 "a를 1~3번", `2|a` 는 "a를 정확히 2번"을 뜻합니다. 2차 항목은
다중도를 가질 수 없고, 옵션 안에서 `이름:색`으로 색을 지정할 수 있습니다.

명령행 플래그는 [`ssxcc`](../ssxcc/README.md)와 같습니다(weight용 `-w`/`-W` 제외).

## 파일 구성

| 파일 | 역할 |
| --- | --- |
| `main.go` | `flag` 파싱, 입출력, 결과 보고 |
| `parse.go` | DLX/DLX3 파서(다중도 접두사 `scanBoundedName` 포함) |
| `dance.go` | 이진 분기 재귀 탐색(`includeOption`/`removeOption`/`chooseBest`) |
| `state.go` | 전역 상태·타입·접근자(`bound`/`slack` 포함)·출력 |
| `gbflip.go` | gb_flip 난수기 |

## 원본과의 동치성

`ctangle ssmcc.w` 레퍼런스와, 실제 계산을 정의하는 모든 출력이 일치합니다:
해와 해 순서, `count`·`updates`·`nodes`·`maxdeg`·profile, shape 파일,
`-v 4`의 항목 스캔 추적, `-s` 무작위 순서까지.

검증 예시:

| 입력 | solutions | updates | nodes |
| --- | --- | --- | --- |
| 8-queens | 92 | 17291 | 1284 |
| 11-queens | 2680 | 1078409 | 72063 |
| 13-queens | 73712 | 24751853 | 1722083 |
| Langford L(2,8) | 300 | 38466 | 3097 |

> **알려진 차이**: `-v 2`(show_choices)의 저수준 "Backtracking to stage N" 줄과
> 몇몇 `-v 4`(show_details) "can't cover"/"deactivating" 메시지는 재현하지
> 않습니다. 이들은 원본의 명시적 `goto` 백트래킹 루프에 결합된 디버그 추적이고
> (일부는 원본에 `item[ii]` 오타까지 있음), 재귀 버전은 백트래킹을 암묵적으로
> 처리하기 때문입니다. 계산 결과 자체에는 영향이 없습니다.
