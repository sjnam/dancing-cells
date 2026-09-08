# Dancing Cells is a literate program: the .w files are the source of truth.
# This Makefile builds the library and nothing else --- the four documents that
# tangle into the package `dcells`, and the ZDD engine beside it:
#
#   dcells.w   the common ground: public API, node array, DLX scanner
#   ssxcc.w    the XCC engine (d-way branching)
#   ssmcc.w    the MCC engine (multiplicities, binary branching)
#   xccdc.w    the XCC engine again, maintaining domain consistency
#   zdd/zdd.w  the ZDD engine: all solutions as a decision diagram.  It is a
#              package of its own because it depends on github.com/sjnam/bdd
#              while the core package depends on nothing.
#
# The programs that use the library have Makefiles of their own, with the same
# targets, and neither needs this one to have been run first:
#
#   examples/Makefile                  the twelve example programs
#   taocp-7.2.2.1-exercises/Makefile   the careful readings of TAOCP exercises
#
# GTANGLE/GWEAVE are named to avoid GNU Make's built-in TANGLE/WEAVE variables
# (which point at the CWEB tools).

GO      ?= go
GTANGLE ?= gtangle
GWEAVE  ?= gweave
PDFTEX  ?= pdftex

LIB  := dcells ssxcc ssmcc xccdc
PKGS := . ./zdd

.PHONY: all build test vet tangle pdf clean

all: build

# Regenerate the Go sources from the literate programs when a .w file changes.
# gtangle on the three engines emits their test files alongside them.
dcells.go: dcells.w
	$(GTANGLE) $<
	gofmt -w dcells.go

ssxcc.go ssxcc_test.go: ssxcc.w
	$(GTANGLE) $<
	gofmt -w ssxcc.go ssxcc_test.go

ssmcc.go ssmcc_test.go: ssmcc.w
	$(GTANGLE) $<
	gofmt -w ssmcc.go ssmcc_test.go

xccdc.go xccdc_test.go: xccdc.w
	$(GTANGLE) $<
	gofmt -w xccdc.go xccdc_test.go

zdd/zdd.go zdd/zdd_test.go: zdd/zdd.w
	cd zdd && $(GTANGLE) zdd.w
	gofmt -w zdd/zdd.go zdd/zdd_test.go

tangle: dcells.go ssxcc.go ssmcc.go xccdc.go zdd/zdd.go

build: tangle
	$(GO) build $(PKGS)

test: tangle ssxcc_test.go ssmcc_test.go xccdc_test.go zdd/zdd_test.go
	$(GO) test $(PKGS)

vet: tangle
	$(GO) vet $(PKGS)

# Typeset the literate documents (two passes resolve the cross-references).
pdf: $(addsuffix .pdf,$(LIB)) zdd/zdd.pdf

%.pdf: %.w
	$(GWEAVE) $<
	$(PDFTEX) $*.tex
	$(PDFTEX) $*.tex

# A static pattern rule, so that the generic one above does not claim it and
# leave its output in the wrong directory.
zdd/zdd.pdf: zdd/zdd.w
	cd zdd && $(GWEAVE) zdd.w
	cd zdd && $(PDFTEX) zdd.tex
	cd zdd && $(PDFTEX) zdd.tex

# clean removes everything the .w files generate here; `make` puts the Go
# sources back.  The five engine .go files are checked in, so that the package
# can be imported without running GWEB first, and are left alone.
clean:
	rm -f ssxcc_test.go ssmcc_test.go xccdc_test.go zdd/zdd_test.go
	rm -f $(foreach x,tex pdf idx scn log toc,zdd/zdd.$(x))
	rm -f $(foreach x,tex pdf idx scn log toc dvi,\
	        $(addsuffix .$(x),$(LIB)))
