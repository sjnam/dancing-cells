# Dancing Cells is a literate program: the source of truth is dcells.w.
# `make` tangles it to dcells.go and builds everything; `make pdf` typesets it.
#
# GTANGLE/GWEAVE are named to avoid GNU Make's built-in TANGLE/WEAVE variables
# (which point at the CWEB tools).

GO      ?= go
GTANGLE ?= gtangle
GWEAVE  ?= gweave
PDFTEX  ?= pdftex

.PHONY: all build test vet tangle pdf clean

all: build

# Regenerate the Go sources from the literate program when dcells.w changes.
# One gtangle run emits both dcells.go and the test file dcells_test.go.
dcells.go: dcells.w
	$(GTANGLE) $<
	gofmt -w dcells.go dcells_test.go

dcells_test.go: dcells.go

tangle: dcells.go

build: dcells.go
	$(GO) build ./...

test: dcells.go dcells_test.go
	$(GO) test ./...

vet: dcells.go
	$(GO) vet ./...

# Typeset the literate document (two passes resolve the cross-references).
pdf: dcells.pdf
dcells.pdf: dcells.w
	$(GWEAVE) $<
	$(PDFTEX) dcells.tex
	$(PDFTEX) dcells.tex

# clean removes only the typeset-document artifacts; the tangled .go files are
# committed, so `make tangle` (not clean) is what refreshes them.
clean:
	rm -f dcells.tex dcells.pdf dcells.idx dcells.scn dcells.log dcells.toc
