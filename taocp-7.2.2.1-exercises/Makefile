# One careful reading of an exercise of TAOCP 7.2.2.1 per directory: README.md
# is the report and verify/verify.w is the program behind it.  The readings are
# in English, but they go through luatex, because some of them draw their
# figures with luamplib.  To add one, put its directory name in EXERCISES
# below, plus one $(eval $(call figure,...)) line if it draws a picture.
#
# This Makefile stands alone.  The library these programs import is built by
# the Makefile in the directory above, but nothing needs to have been tangled
# there: the engine .go files are checked in.
#
# GTANGLE/GWEAVE are named to avoid GNU Make's built-in TANGLE/WEAVE variables
# (which point at the CWEB tools).

GO      ?= go
GTANGLE ?= gtangle
GWEAVE  ?= gweave
LUATEX  ?= luatex
MPOST   ?= mpost
RSVG    ?= rsvg-convert
MAGICK  ?= magick

EXERCISES := 029-030 055 104 121 129 147 151-152 262 305-306 320 323 334 \
             337 346 387 432 442
VERIFY := $(foreach e,$(EXERCISES),$(e)/verify)
FIGS   := 029-030/backtrack.png 104/allinterval.png 121/tetrads.png \
          151-152/loop8x12.png 262/tilings.png 320/convex56.png \
          323/tetraskews.png 334/wwall.png 337/dice.png 346/tripods.png \
          387/polycubes.png 432/kakuro.png 442/hitori.png

.PHONY: all build test vet tangle pdf clean

all: build

# A static pattern rule, not an implicit one: a generic `%.go: %.w` would
# otherwise leave its output in the wrong directory.
$(addsuffix /verify.go,$(VERIFY)): %/verify.go: %/verify.w
	cd $* && $(GTANGLE) verify.w
	gofmt -w $@

tangle: $(addsuffix /verify.go,$(VERIFY))

build: tangle
	$(GO) build ./...

test: tangle
	$(GO) test ./...

vet: tangle
	$(GO) vet ./...

# Typeset the readings (two passes resolve the cross-references), and draw the
# pictures their README.md files display.
pdf: $(addsuffix /verify.pdf,$(VERIFY)) $(FIGS)

$(addsuffix /verify.pdf,$(VERIFY)): %/verify.pdf: %/verify.w
	cd $* && $(GWEAVE) verify.w
	cd $* && $(LUATEX) verify.tex
	cd $* && $(LUATEX) verify.tex

# A figure that both verify.w and README.md show is drawn once, in MetaPost:
# luamplib runs the .mp while the document is typeset, and mpost runs it again
# on its own to make the picture the README displays.  Arguments: the exercise
# directory, the figure name, and how wide the raster should be.
define figure
$(1)/$(2).png: $(1)/verify/$(2).mp
	cd $(1)/verify && \
	  $$(MPOST) -s 'outputformat="svg"' '\input $(2); end.' </dev/null
	$$(RSVG) -w $(3) $(1)/verify/$(2).1 -o $$@
	$$(MAGICK) $$@ -trim +repage -bordercolor white -border 16 $$@
	rm -f $(1)/verify/$(2).1 $(1)/verify/$(2).log
$(1)/verify/verify.pdf: $(1)/verify/$(2).mp
endef
$(eval $(call figure,029-030,backtrack,900))
$(eval $(call figure,104,allinterval,700))
$(eval $(call figure,121,tetrads,1500))
$(eval $(call figure,151-152,loop8x12,1800))
$(eval $(call figure,262,tilings,1600))
$(eval $(call figure,320,convex56,1500))
$(eval $(call figure,323,tetraskews,1400))
$(eval $(call figure,334,wwall,1500))
$(eval $(call figure,337,dice,1100))
$(eval $(call figure,346,tripods,1300))
$(eval $(call figure,387,polycubes,1400))
$(eval $(call figure,432,kakuro,1500))
$(eval $(call figure,442,hitori,1200))

# clean removes everything the .w files generate, tangled Go included; `make`
# puts the Go sources back.  The one exception is the verify.pdf files, which
# are committed so that a reading can be read without GWEB installed.
clean:
	rm -f $(addsuffix /verify.go,$(VERIFY))
	rm -f $(foreach x,tex idx scn log toc,\
	        $(addsuffix /verify.$(x),$(VERIFY)))
	rm -f */verify/*.1 */verify/*.log */verify/*.mpx
