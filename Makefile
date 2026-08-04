# Dancing Cells is a literate program: the source of truth is dcells.w.
# `make` tangles it to dcells.go and builds everything; `make pdf` typesets it.
#
# examples/words is a second literate program (in Korean), tangled the same way
# and typeset with luatex, since kotexgweb needs it.
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

.PHONY: all build test vet tangle pdf clean

all: build

# Regenerate the Go sources from the literate programs when the .w files change.
# One gtangle run on dcells.w emits both dcells.go and the test file.
dcells.go: dcells.w
	$(GTANGLE) $<
	gofmt -w dcells.go dcells_test.go

dcells_test.go: dcells.go

$(WORDS)/words.go: $(WORDS)/words.w
	cd $(WORDS) && $(GTANGLE) words.w
	gofmt -w $(WORDS)/words.go

tangle: dcells.go $(WORDS)/words.go

build: tangle
	$(GO) build ./...

test: tangle dcells_test.go
	$(GO) test ./...

vet: tangle
	$(GO) vet ./...

# Typeset the literate documents (two passes resolve the cross-references).
pdf: dcells.pdf $(WORDS)/words.pdf

dcells.pdf: dcells.w
	$(GWEAVE) $<
	$(PDFTEX) dcells.tex
	$(PDFTEX) dcells.tex

# words.mp must be converted first: \pic pulls words-1.pdf into the document.
$(WORDS)/words.pdf: $(WORDS)/words.w $(WORDS)/words.mp
	cd $(WORDS) && $(MPTOPDF) words.mp
	cd $(WORDS) && $(GWEAVE) words.w
	cd $(WORDS) && $(LUATEX) words.tex
	cd $(WORDS) && $(LUATEX) words.tex

# clean removes everything the two GWEB documents generate, tangled Go included;
# `make` (or `make tangle`) puts the Go sources back.
clean:
	rm -f dcells.go dcells_test.go
	rm -f dcells.tex dcells.pdf dcells.idx dcells.scn dcells.log dcells.toc
	rm -f $(WORDS)/words.go
	rm -f $(WORDS)/words.tex $(WORDS)/words.pdf $(WORDS)/words.idx \
	      $(WORDS)/words.scn $(WORDS)/words.log $(WORDS)/words.toc \
	      $(WORDS)/words.1 $(WORDS)/words.mpx $(WORDS)/words-1.pdf
