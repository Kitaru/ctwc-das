all: tetris das-limit build/game_palette.pal build/menu_palette.pal build/game_nametable.nam build/level_menu_nametable.nam
test: build/tetris-test
# These are simply aliases
.PHONY: all dis tetris das-limit

dis: build/tetris-PRG.s

das-limit: build/das-limit.nes
build/das-limit.o: build/tetris.inc
build/das-limit.ips.cfg: build/das-limit.o
build/das-limit.ips: build/das-limit.o build/ips.o
build/das-limit.nes: build/tetris.nes

tetris: build/tetris.nes
build/tetris-CHR.o: build/tetris-CHR-00.chr build/tetris-CHR-01.chr
build/tetris.nes: build/tetris.o build/tetris-CHR.o build/tetris-PRG.o build/tetris-ram.o
ifeq "$(PAL)" "1"
build/tetris-test: tetris-pal.nes
else
build/tetris-test: tetris.nes
endif
build/tetris-test: build/tetris.nes
	diff $^
	touch $@

ifeq "$(PAL)" "1"
build/tetris-unreferenced_data4.bin: build/tetris-pal-PRG.bin | build
	tail -c +31222 $< | head -c 1291 > $@
else
build/tetris-unreferenced_data4.bin: build/tetris-PRG.bin | build
	tail -c +31212 $< | head -c 1301 > $@
endif

# There are tools to split apart the iNES file, like
# https://github.com/taotao54321/ines, but they would require an additional
# setup step for the user to download/run.
build/tetris-PRG.bin: tetris.nes | build
	tail -c +17 $< | head -c 32768 > $@
build/tetris-pal-PRG.bin: tetris-pal.nes | build
	tail -c +17 $< | head -c 32768 > $@
build/tetris-CHR-00.chr: tetris.nes | build
	tail -c +32785 $< | head -c 8192 > $@
build/tetris-CHR-01.chr: tetris.nes | build
	tail -c +40977 $< | head -c 8192 > $@

build/tetris-pal-PRG.info: tetris-PRG.info ntsc2pal.awk | build
	awk -f ntsc2pal.awk $< > $@
build/tetris-pal.nes.cfg: tetris.nes.cfg ntsc2pal.awk | build
	awk -f ntsc2pal.awk $< > $@
build/tetris-pal.nes: build/tetris.o build/tetris-CHR.o build/tetris-pal-PRG.o build/tetris-ram.o
build/tetris-pal-PRG.o: build/tetris-pal-PRG.s

ifeq "$(PAL)" "1"
build/tetris-PRG.s: build/tetris-pal-PRG.s
	cp $< $@
build/tetris.nes: build/tetris-pal.nes
	cp $< $@
	cp $(basename $<).dbg $(basename $@).dbg
	cp $(basename $<).lbl $(basename $@).lbl
endif

build/game_palette.pal: build/tetris-PRG.bin
	# +3 for buildCopyToPpu header
	tail -c +$$((0xACF3 - 0x8000 + 3 + 1)) $< | head -c 16 > $@
build/menu_palette.pal: build/tetris-PRG.bin
	# +3 for buildCopyToPpu header
	tail -c +$$((0xAD2B - 0x8000 + 3 + 1)) $< | head -c 16 > $@
build/legal_screen_nametable.nam:
build/legal_screen_nametable.nam.stripe: build/tetris-PRG.bin
	tail -c +$$((0xADB8 - 0x8000 + 1)) $< | head -c $$((1024/32*35)) > $@
build/game_nametable.nam.stripe: build/tetris-PRG.bin
	tail -c +$$((0xBF3C - 0x8000 + 1)) $< | head -c $$((1024/32*35)) > $@
build/level_menu_nametable.nam.stripe: build/tetris-PRG.bin
	tail -c +$$((0xBADB - 0x8000 + 1)) $< | head -c $$((1024/32*35)) > $@

# Converts to/from NES Stripe RLE. Only supports a _very_ limited subset that
# is fully consecutive, only "literal to right", with each sized 0x20
build/%: %.stripe
	LC_ALL=C awk -v BINMODE=3 'BEGIN {RS=".{35}";ORS=""} {print substr(RT, 4)}' $< > $@
build/%.nam.stripe: %.nam
	LC_ALL=C awk -v BINMODE=3 'BEGIN {RS=".{32}";ADDR=0x2000} {printf("%c%c%c%s",ADDR/256,ADDR%256,32,RT);ADDR=ADDR+32}' $< > $@

build/tetris.inc: build/tetris.nes
	sort build/tetris.lbl | sed -E -e 's/al 00(.{4}) .(.*)/\2 := $$\1/' | uniq > $@

build/tetris-ram.s: tetris-PRG.info tetris-ram.awk | build
	awk -f tetris-ram.awk $< > $@

ifeq "$(PAL)" "1"
FCEUXFLAGS = --pal 1
else
FCEUXFLAGS = --pal 0
endif
build/%.test: %.lua
	# Second prerequisite is assumed to be a .nes to run
	fceux --no-config 1 --fullscreen 0 --sound 0 --frameskip 100 $(FCEUXFLAGS) --loadlua $< $(word 2,$^)
	touch $@

.PHONY: test
test:
	# fceux saves some of the configuration, so restore what we can
	fceux --no-config 1 --sound 1 --frameskip 0 --loadlua testing-reset.lua build/tetris.nes

# include last because it enables SECONDEXPANSION
include nes.mk
