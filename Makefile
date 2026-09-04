# Dancing Cells is a literate program: the .w files are the source of truth.
# `make` tangles them to Go and builds everything; `make pdf` typesets them.
#
#   dcells.w   the common ground: public API, node array, DLX scanner
#   ssxcc.w    the XCC engine (d-way branching)
#   ssmcc.w    the MCC engine (multiplicities, binary branching)
#
# examples/words, examples/transversal and examples/hollow are literate programs
# too (in Korean), typeset with luatex since kotexgweb needs it.
# taocp-7.2.2.1-exercises holds one careful reading of an exercise per
# directory, each with a verify.w that checks Knuth's answer.  They are in
# English but go through luatex, because one of them draws its figure with
# luamplib; to add another, put its number in EXERCISES below.
#
# GTANGLE/GWEAVE are named to avoid GNU Make's built-in TANGLE/WEAVE variables
# (which point at the CWEB tools).

GO      ?= go
GTANGLE ?= gtangle
GWEAVE  ?= gweave
PDFTEX  ?= pdftex
LUATEX  ?= luatex
MPTOPDF ?= mptopdf
MPOST   ?= mpost
RSVG    ?= rsvg-convert
MAGICK  ?= magick

WORDS := examples/words
TRANS   := examples/transversal
HOLLOW  := examples/hollow
EXDIR   := taocp-7.2.2.1-exercises
EXERCISES := 29-30 104 151-152 334
FIGS    := $(EXDIR)/29-30/backtrack.png $(EXDIR)/104/allinterval.png \
           $(EXDIR)/151-152/loop8x12.png
VERIFY  := $(foreach e,$(EXERCISES),$(EXDIR)/$(e)/verify)
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

$(TRANS)/transversal.go: $(TRANS)/transversal.w
	cd $(TRANS) && $(GTANGLE) transversal.w
	gofmt -w $(TRANS)/transversal.go

$(HOLLOW)/hollow.go: $(HOLLOW)/hollow.w
	cd $(HOLLOW) && $(GTANGLE) hollow.w
	gofmt -w $(HOLLOW)/hollow.go

# A static pattern rule, not an implicit one: the generic `%.pdf: %.w` below
# would otherwise win for these targets and leave its output in the wrong
# directory.
$(addsuffix /verify.go,$(VERIFY)): %/verify.go: %/verify.w
	cd $* && $(GTANGLE) verify.w
	gofmt -w $@

tangle: dcells.go ssxcc.go ssmcc.go $(WORDS)/words.go \
        $(TRANS)/transversal.go $(HOLLOW)/hollow.go \
        $(addsuffix /verify.go,$(VERIFY))

build: tangle
	$(GO) build ./...

test: tangle ssxcc_test.go ssmcc_test.go
	$(GO) test ./...

vet: tangle
	$(GO) vet ./...

# Typeset the literate documents (two passes resolve the cross-references).
pdf: $(addsuffix .pdf,$(LIB)) $(WORDS)/words.pdf $(TRANS)/transversal.pdf \
     $(HOLLOW)/hollow.pdf $(addsuffix /verify.pdf,$(VERIFY)) $(FIGS)

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

$(TRANS)/transversal.pdf: $(TRANS)/transversal.w
	cd $(TRANS) && $(GWEAVE) transversal.w
	cd $(TRANS) && $(LUATEX) transversal.tex
	cd $(TRANS) && $(LUATEX) transversal.tex

$(HOLLOW)/hollow.pdf: $(HOLLOW)/hollow.w
	cd $(HOLLOW) && $(GWEAVE) hollow.w
	cd $(HOLLOW) && $(LUATEX) hollow.tex
	cd $(HOLLOW) && $(LUATEX) hollow.tex

# A static pattern rule, not an implicit one: the generic `%.pdf: %.w` above
# would otherwise win for these targets and leave its output in the wrong
# directory.  These go through luatex because one of them draws its figure
# with luamplib.
$(addsuffix /verify.pdf,$(VERIFY)): %/verify.pdf: %/verify.w
	cd $* && $(GWEAVE) verify.w
	cd $* && $(LUATEX) verify.tex
	cd $* && $(LUATEX) verify.tex

# A figure that both verify.w and README.md show is drawn once, in MetaPost:
# luamplib runs the .mp while the document is typeset, and mpost runs it again
# on its own to make the picture the README displays.  Arguments: the exercise
# directory, the figure name, and how wide the raster should be.
define figure
$$(EXDIR)/$(1)/$(2).png: $$(EXDIR)/$(1)/verify/$(2).mp
	cd $$(EXDIR)/$(1)/verify && \
	  $$(MPOST) -s 'outputformat="svg"' '\input $(2); end.' </dev/null
	$$(RSVG) -w $(3) $$(EXDIR)/$(1)/verify/$(2).1 -o $$@
	$$(MAGICK) $$@ -bordercolor white -border 16 $$@
	rm -f $$(EXDIR)/$(1)/verify/$(2).1 $$(EXDIR)/$(1)/verify/$(2).log
$$(EXDIR)/$(1)/verify/verify.pdf: $$(EXDIR)/$(1)/verify/$(2).mp
endef
$(eval $(call figure,29-30,backtrack,900))
$(eval $(call figure,104,allinterval,700))
$(eval $(call figure,151-152,loop8x12,1800))

# clean removes everything the .w files generate, tangled Go included;
# `make` (or `make tangle`) puts the Go sources back.  The one exception is the
# verify.pdf files, which are committed so that they can be read without GWEB
# installed.
clean:
	rm -f ssxcc_test.go ssmcc_test.go
	rm -f $(addsuffix .tex,$(LIB)) $(addsuffix .pdf,$(LIB)) \
	      $(addsuffix .idx,$(LIB)) $(addsuffix .scn,$(LIB)) \
	      $(addsuffix .log,$(LIB)) $(addsuffix .toc,$(LIB)) $(addsuffix .dvi,$(LIB))
	rm -f $(WORDS)/words.go $(TRANS)/transversal.go \
	      $(HOLLOW)/hollow.go $(addsuffix /verify.go,$(VERIFY))
	rm -f $(WORDS)/words.tex $(WORDS)/words.pdf $(WORDS)/words.idx \
	      $(WORDS)/words.scn $(WORDS)/words.log $(WORDS)/words.toc \
	      $(WORDS)/words.1 $(WORDS)/words.mpx $(WORDS)/words-1.pdf
	rm -f $(TRANS)/transversal.tex $(TRANS)/transversal.pdf \
	      $(TRANS)/transversal.idx $(TRANS)/transversal.scn \
	      $(TRANS)/transversal.log $(TRANS)/transversal.toc
	rm -f $(HOLLOW)/hollow.tex $(HOLLOW)/hollow.pdf $(HOLLOW)/hollow.idx \
	      $(HOLLOW)/hollow.scn $(HOLLOW)/hollow.log $(HOLLOW)/hollow.toc
	rm -f $(addsuffix /verify.tex,$(VERIFY)) $(addsuffix /verify.idx,$(VERIFY)) \
	      $(addsuffix /verify.scn,$(VERIFY)) $(addsuffix /verify.log,$(VERIFY)) \
	      $(addsuffix /verify.toc,$(VERIFY))
	rm -f $(EXDIR)/*/verify/*.1 $(EXDIR)/*/verify/*.log
