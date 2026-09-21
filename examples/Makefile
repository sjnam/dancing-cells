# Every program here is a literate program: <name>/<name>.w is the source and
# the .go beside it is generated.  They are written in Korean and typeset with
# luatex, since kotexgweb needs it.  To add one, put its directory name in
# EXAMPLES below.
#
# This Makefile stands alone.  The library these programs import is built by
# the Makefile in the directory above, but `go build` will tangle nothing and
# needs nothing tangled there: the engine .go files are checked in.
#
# GTANGLE/GWEAVE are named to avoid GNU Make's built-in TANGLE/WEAVE variables
# (which point at the CWEB tools).

GO      ?= go
GTANGLE ?= gtangle
GWEAVE  ?= gweave
LUATEX  ?= luatex

EXAMPLES := domino filomino hollow langford partridge pentominoes queen \
            sudoku transversal words wordsearch zebra
GOFILES  := $(foreach e,$(EXAMPLES),$(e)/$(e).go)
PDFFILES := $(foreach e,$(EXAMPLES),$(e)/$(e).pdf)

.PHONY: all build test vet tangle pdf clean

all: build

# One macro serves them all: <name>/<name>.w makes <name>.go and <name>.pdf in
# place.
define example
$(1)/$(1).go: $(1)/$(1).w
	cd $(1) && $$(GTANGLE) $(1).w
	gofmt -w $(1)/$(1).go
$(1)/$(1).pdf: $(1)/$(1).w
	cd $(1) && $$(GWEAVE) $(1).w
	cd $(1) && $$(LUATEX) $(1).tex
	cd $(1) && $$(LUATEX) $(1).tex
endef
$(foreach e,$(EXAMPLES),$(eval $(call example,$(e))))

tangle: $(GOFILES)

build: tangle
	$(GO) build ./...

test: tangle
	$(GO) test ./...

vet: tangle
	$(GO) vet ./...

# Typeset the literate documents (two passes resolve the cross-references).
pdf: $(PDFFILES)

# clean removes everything the .w files generate; `make` puts the Go sources
# back.
clean:
	rm -f $(GOFILES)
	rm -f $(foreach x,tex pdf idx scn log toc,\
	        $(foreach e,$(EXAMPLES),$(e)/$(e).$(x)))
