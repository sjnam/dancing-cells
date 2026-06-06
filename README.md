# dancing-cells

Donald E. Knuth의 "dancing cells"(dancing **links**가 아니라 sparse-set 기반)
정확 피복(exact cover) solver들을 Go로 옮긴 모음입니다. 원본 CWEB 프로그램의
알고리즘과 결과를 충실히 따르되, `goto` 상태기계를 재귀로, 직접 짠 명령행 처리를
`flag` 패키지로 바꾸고 역할별 파일로 나눠 관용적인 Go로 작성했습니다.

| 프로그램 | 설명 |
| --- | --- |
| [`cmd/ssxcc`](cmd/ssxcc/README.md) | XCC — 색 제약 정확 피복 (d-갈래 분기). Knuth의 [`SSXCC`](https://www-cs-faculty.stanford.edu/~knuth/programs/ssxcc.w) |
| [`cmd/ssmcc`](cmd/ssmcc/README.md) | 위에 **항목 다중도**(`u:v\|name`)를 더한 버전 (이진 분기). Knuth의 [`SSMCC`](https://www-cs-faculty.stanford.edu/~knuth/programs/ssmcc.w) |

## 빌드 & 실행

```sh
go run ./cmd/ssxcc -m 1 cmd/ssxcc/examples/exactcover.dlx
go run ./cmd/ssmcc -m 1 cmd/ssmcc/examples/multiplicity.dlx

go build -o ssxcc ./cmd/ssxcc        # 바이너리로 빌드
go build -o ssmcc ./cmd/ssmcc
go build ./...                       # 둘 다 컴파일 검증
```

입력은 Knuth의 다른 solver들과 같은 DLX 형식(파일 인자 또는 표준입력)입니다.
자세한 입력 형식·플래그·동치성 검증은 각 프로그램의 README를 보세요.

## 동치성

각 포팅은 `ctangle`로 만든 원본 C 레퍼런스와, 실제 계산을 정의하는 모든 출력이
일치합니다 — 해와 해 순서, `count`·`updates`·`nodes`·`maxdeg`·profile, shape
파일, `-s` 무작위 순서. (Knuth의 `mems`/`bytes` 계측은 의도적으로 제외했습니다.)
