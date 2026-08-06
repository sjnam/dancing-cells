# Dancing Cells is a literate program: the .w files are the source of truth.
# `make` tangles them to Go and builds everything; `make pdf` typesets them.
#
#   dcells.w   the common ground: public API, node array, DLX scanner
#   ssxcc.w    the XCC engine (d-way branching)
#   ssmcc.w    the MCC engine (multiplicities, binary branching)
#
# examples/words is a fourth literate program (in Korean), typeset with luatex
# since kotexgweb needs it.
#
# GTANGLE/GWEAVE are named to avoid GNU Make's built-in TANGLE/WEAVE variables
# (which point at the CWEB tools).

GO      ?= go
GTANGLE ?= gtangle
GWEAVE  ?= gweave
PDFTEX  ?= pdftex
LUATEX  ?= luatex
MPTOPDF ?= mptopdf

WORDS := examples/words
LIB   := dcells ssxcc ssmcc

.PHONY: all build test vet tangle pdf clean

all: build

# Regenerate the Go sources from the literate programs when a .w file changes.
# gtangle on ssxcc.w and ssmcc.w emits the test files alongside the engines.
dcells.go: dcells.w
	$(GTANGLE) $<
	gofmt -w dcells.go

ssxcc.go ssxcc_test.go: ssxcc.w
	$(GTANGLE) $<
	gofmt -w ssxcc.go ssxcc_test.go

ssmcc.go ssmcc_test.go: ssmcc.w
	$(GTANGLE) $<
	gofmt -w ssmcc.go ssmcc_test.go

$(WORDS)/words.go: $(WORDS)/words.w
	cd $(WORDS) && $(GTANGLE) words.w
	gofmt -w $(WORDS)/words.go

tangle: dcells.go ssxcc.go ssmcc.go $(WORDS)/words.go

build: tangle
	$(GO) build ./...

test: tangle ssxcc_test.go ssmcc_test.go
	$(GO) test ./...

vet: tangle
	$(GO) vet ./...

# Typeset the literate documents (two passes resolve the cross-references).
pdf: $(addsuffix .pdf,$(LIB)) $(WORDS)/words.pdf

%.pdf: %.w
	$(GWEAVE) $<
	$(PDFTEX) $*.tex
	$(PDFTEX) $*.tex

# words.mp must be converted first: \pic pulls words-1.pdf into the document.
$(WORDS)/words.pdf: $(WORDS)/words.w $(WORDS)/words.mp
	cd $(WORDS) && $(MPTOPDF) words.mp
	cd $(WORDS) && $(GWEAVE) words.w
	cd $(WORDS) && $(LUATEX) words.tex
	cd $(WORDS) && $(LUATEX) words.tex

# clean removes everything the .w files generate, tangled Go included;
# `make` (or `make tangle`) puts the Go sources back.
clean:
	rm -f dcells.go ssxcc.go ssxcc_test.go ssmcc.go ssmcc_test.go
	rm -f $(addsuffix .tex,$(LIB)) $(addsuffix .pdf,$(LIB)) \
	      $(addsuffix .idx,$(LIB)) $(addsuffix .scn,$(LIB)) \
	      $(addsuffix .log,$(LIB)) $(addsuffix .toc,$(LIB))
	rm -f $(WORDS)/words.go
	rm -f $(WORDS)/words.tex $(WORDS)/words.pdf $(WORDS)/words.idx \
	      $(WORDS)/words.scn $(WORDS)/words.log $(WORDS)/words.toc \
	      $(WORDS)/words.1 $(WORDS)/words.mpx $(WORDS)/words-1.pdf
