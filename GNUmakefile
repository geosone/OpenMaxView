# Open MaxView DOS build. This uses the same open-source tool chain as Open
# 386MAX: Open Watcom's C compiler plus its embedded JWasm and JWlink.

WATCOM ?= /opt/watcom
MAXROOT ?= /home/mario/mars/386MAX
WCC    := $(WATCOM)/binl64/wcc
JWASM  := $(MAXROOT)/linux/bin/jwasm
JWLINK := $(MAXROOT)/linux/bin/jwlink
CC     ?= cc
BUILD  := build

DOS_CFLAGS := -bt=dos -ms -0 -os -s -zq -w4 -i=include -i=$(WATCOM)/h

.PHONY: all test test-dos clean

all: $(BUILD)/MAXVTSR.COM $(BUILD)/MAXVIEW.EXE $(BUILD)/DVPROBE.EXE

$(BUILD):
	mkdir -p $@

$(BUILD)/odqtsr.obj: kernel/odqtsr.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MAXVTSR.COM: $(BUILD)/odqtsr.obj
	cd $(BUILD) && $(JWLINK) format dos com name MAXVTSR.COM option quiet option map=MAXVTSR.MAP file odqtsr.obj

$(BUILD)/opendesq.obj: src/opendesq.c include/catalog.h include/odqapi.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/catalog.obj: src/catalog.c include/catalog.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/MAXVIEW.EXE: $(BUILD)/opendesq.obj $(BUILD)/catalog.obj
	cd $(BUILD) && $(JWLINK) format dos name MAXVIEW.EXE option quiet option map=MAXVIEW.MAP option stack=8192 option nofarcalls file opendesq.obj,catalog.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/dvprobe.obj: examples/dvprobe.c include/odqapi.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/DVPROBE.EXE: $(BUILD)/dvprobe.obj
	cd $(BUILD) && $(JWLINK) format dos name DVPROBE.EXE option quiet option map=DVPROBE.MAP option stack=2048 option nofarcalls file dvprobe.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/test_catalog: tests/test_catalog.c src/catalog.c include/catalog.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_catalog.c src/catalog.c

test: $(BUILD)/test_catalog
	$(BUILD)/test_catalog
	python3 -m unittest discover -s tests -p 'test_*.py'

test-dos: all
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVTSR.COM > MVTSR.TXT' -c 'DVPROBE.EXE > MVPROBE.TXT' \
		-c 'exit' >/dev/null 2>&1
	rg -q 'resident API 0.1 installed' $(BUILD)/MVTSR.TXT
	rg -q 'API version 2.80 detected' $(BUILD)/MVPROBE.TXT
	rg -q 'PAUSE call returned successfully' $(BUILD)/MVPROBE.TXT

clean:
	find $(BUILD) -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null || true

