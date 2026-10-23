# Open MaxView DOS build. This uses the same open-source tool chain as Open
# 386MAX: Open Watcom's C compiler plus its embedded JWasm and JWlink.

WATCOM ?= /opt/watcom
MAXROOT ?= $(abspath ../Open386MAX)
WCC    := $(WATCOM)/binl64/wcc
JWASM  := $(MAXROOT)/linux/bin/jwasm
JWLINK := $(MAXROOT)/linux/bin/jwlink
CC     ?= cc
BUILD  := build
PACKAGE := $(BUILD)/OpenMaxView
VERSION := $(strip $(shell sed -n '1p' VERSION))
RELEASE_DIR := $(BUILD)/releases/$(VERSION)
DOCFILES := DOCS.TXT USERGUID.TXT TOOLS.TXT CONFIG.TXT BUILDING.TXT \
	TESTING.TXT API.TXT COMPAT.TXT DEVELOP.TXT ROADMAP.TXT REMOTE2.TXT \
	TROUBLE.TXT ARCHITEC.TXT HELP.TXT BBSGUIDE.TXT PROGDEV.TXT QUICK.TXT \
	CONFORM.TXT

DOS_CFLAGS := -bt=dos -ms -0 -os -s -zq -w4 -i=include -i=$(WATCOM)/h

.PHONY: all package setup-package release-check test test-dos books book-html book-pdf book-epub clean

all: $(BUILD)/MAXVTSR.COM $(BUILD)/MAXVIEW.EXE $(BUILD)/MVRUN.EXE $(BUILD)/MAXVAPP.EXE \
	$(BUILD)/MAXVMEM.EXE $(BUILD)/MAXVSET.EXE $(BUILD)/MAXVAUTO.EXE \
	$(BUILD)/MAXVFILE.EXE $(BUILD)/MAXVANSI.COM $(BUILD)/DVPROBE.EXE \
	$(BUILD)/MAXVDVP.EXE $(BUILD)/MENU.COM $(BUILD)/HELLO.COM $(BUILD)/MOUSE.COM $(BUILD)/COUNTDN.COM $(BUILD)/SERVE.COM $(BUILD)/ASK.COM \
	$(BUILD)/SETUP.EXE $(BUILD)/MAXVIEW.CFG \
	$(BUILD)/MAXVSET.INI $(BUILD)/MAXVAUTO.DAT $(BUILD)/README.TXT \
	$(BUILD)/LICENSE.TXT $(addprefix $(BUILD)/,$(DOCFILES))

$(BUILD):
	mkdir -p $@

$(BUILD)/odqtsr.obj: kernel/odqtsr.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MAXVTSR.COM: $(BUILD)/odqtsr.obj
	cd $(BUILD) && $(JWLINK) format dos com name MAXVTSR.COM option quiet option map=MAXVTSR.MAP file odqtsr.obj

$(BUILD)/opendesq.obj: src/opendesq.c include/mvkern.h include/mvhost.h include/catalog.h include/maxbackend.h include/odqapi.h include/scheduler.h include/settings.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/catalog.obj: src/catalog.c include/catalog.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/settings.obj: src/settings.c include/settings.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/scheduler.obj: src/scheduler.c include/scheduler.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/mvprocess.obj: src/mvprocess.c include/mvprocess.h include/catalog.h include/scheduler.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/vmtask.obj: src/vmtask.c include/vmtask.h include/maxbackend.h include/scheduler.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/vmbackend.obj: src/vmbackend.c include/vmtask.h include/maxbackend.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/mvui.obj: src/mvui.c include/mvui.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/maxbackend.obj: kernel/maxbackend.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MAXVIEW.EXE: $(BUILD)/opendesq.obj $(BUILD)/catalog.obj $(BUILD)/settings.obj $(BUILD)/scheduler.obj $(BUILD)/mvprocess.obj $(BUILD)/vmtask.obj $(BUILD)/vmbackend.obj $(BUILD)/maxbackend.obj $(BUILD)/mvhost.obj $(BUILD)/mvkern.obj
	cd $(BUILD) && $(JWLINK) format dos name MAXVIEW.EXE option quiet option map=MAXVIEW.MAP option stack=16384 option nofarcalls file opendesq.obj,catalog.obj,settings.obj,scheduler.obj,mvprocess.obj,vmtask.obj,vmbackend.obj,maxbackend.obj,mvhost.obj,mvkern.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

MVDEBUG ?= 0
$(BUILD)/mvkern.obj: kernel/mvkern.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -DMVDEBUG=$(MVDEBUG) -Fo$@ $<

$(BUILD)/mvhost.obj: src/mvhost.c include/mvhost.h include/mvkern.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/mvrun.obj: src/mvrun.c include/mvkern.h include/mvhost.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/MVRUN.EXE: $(BUILD)/mvrun.obj $(BUILD)/mvhost.obj $(BUILD)/mvkern.obj
	cd $(BUILD) && $(JWLINK) format dos name MVRUN.EXE option quiet option map=MVRUN.MAP option stack=4096 option nofarcalls file mvrun.obj,mvhost.obj,mvkern.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/memprobe.obj: tests/memprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MEMPROBE.COM: $(BUILD)/memprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name MEMPROBE.COM option quiet option map=MEMPROBE.MAP file memprobe.obj

$(BUILD)/keyprobe.obj: tests/keyprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/KEYPROBE.COM: $(BUILD)/keyprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name KEYPROBE.COM option quiet option map=KEYPROBE.MAP file keyprobe.obj

$(BUILD)/critprobe.obj: tests/critprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/CRITPRB.COM: $(BUILD)/critprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name CRITPRB.COM option quiet option map=CRITPRB.MAP file critprobe.obj

$(BUILD)/dvtask.obj: tests/dvtask.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/DVTASK.COM: $(BUILD)/dvtask.obj
	cd $(BUILD) && $(JWLINK) format dos com name DVTASK.COM option quiet option map=DVTASK.MAP file dvtask.obj

$(BUILD)/numprb.obj: tests/numprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/NUMPRB.COM: $(BUILD)/numprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name NUMPRB.COM option quiet option map=NUMPRB.MAP file numprb.obj

$(BUILD)/menu.obj: demos/menu.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MENU.COM: $(BUILD)/menu.obj
	cd $(BUILD) && $(JWLINK) format dos com name MENU.COM option quiet option map=MENU.MAP file menu.obj

$(BUILD)/hello.obj: demos/hello.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/HELLO.COM: $(BUILD)/hello.obj
	cd $(BUILD) && $(JWLINK) format dos com name HELLO.COM option quiet option map=HELLO.MAP file hello.obj

$(BUILD)/mouse.obj: demos/mouse.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MOUSE.COM: $(BUILD)/mouse.obj
	cd $(BUILD) && $(JWLINK) format dos com name MOUSE.COM option quiet option map=MOUSE.MAP file mouse.obj

$(BUILD)/countdn.obj: demos/countdn.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/COUNTDN.COM: $(BUILD)/countdn.obj
	cd $(BUILD) && $(JWLINK) format dos com name COUNTDN.COM option quiet option map=COUNTDN.MAP file countdn.obj

$(BUILD)/serve.obj: demos/serve.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/SERVE.COM: $(BUILD)/serve.obj
	cd $(BUILD) && $(JWLINK) format dos com name SERVE.COM option quiet option map=SERVE.MAP file serve.obj

$(BUILD)/ask.obj: demos/ask.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/ASK.COM: $(BUILD)/ask.obj
	cd $(BUILD) && $(JWLINK) format dos com name ASK.COM option quiet option map=ASK.MAP file ask.obj

$(BUILD)/wobprb.obj: tests/wobprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/WOBPRB.COM: $(BUILD)/wobprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name WOBPRB.COM option quiet option map=WOBPRB.MAP file wobprb.obj

$(BUILD)/ptrprb.obj: tests/ptrprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/PTRPRB.COM: $(BUILD)/ptrprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name PTRPRB.COM option quiet option map=PTRPRB.MAP file ptrprb.obj

$(BUILD)/bcsprb.obj: tests/bcsprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/BCSPRB.COM: $(BUILD)/bcsprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name BCSPRB.COM option quiet option map=BCSPRB.MAP file bcsprb.obj

$(BUILD)/mseprb.obj: tests/mseprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MSEPRB.COM: $(BUILD)/mseprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name MSEPRB.COM option quiet option map=MSEPRB.MAP file mseprb.obj

$(BUILD)/selprb.obj: tests/selprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/SELPRB.COM: $(BUILD)/selprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name SELPRB.COM option quiet option map=SELPRB.MAP file selprb.obj

$(BUILD)/fldprb.obj: tests/fldprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/FLDPRB.COM: $(BUILD)/fldprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name FLDPRB.COM option quiet option map=FLDPRB.MAP file fldprb.obj

$(BUILD)/obqprb.obj: tests/obqprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/OBQPRB.COM: $(BUILD)/obqprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name OBQPRB.COM option quiet option map=OBQPRB.MAP file obqprb.obj

$(BUILD)/crtprb.obj: tests/crtprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/CRTPRB.COM: $(BUILD)/crtprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name CRTPRB.COM option quiet option map=CRTPRB.MAP file crtprb.obj

$(BUILD)/qryprb.obj: tests/qryprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/QRYPRB.COM: $(BUILD)/qryprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name QRYPRB.COM option quiet option map=QRYPRB.MAP file qryprb.obj

$(BUILD)/strprb.obj: tests/strprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/STRPRB.COM: $(BUILD)/strprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name STRPRB.COM option quiet option map=STRPRB.MAP file strprb.obj

$(BUILD)/winprb.obj: tests/winprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/WINPRB.COM: $(BUILD)/winprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name WINPRB.COM option quiet option map=WINPRB.MAP file winprb.obj

$(BUILD)/kbdprb.obj: tests/kbdprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/KBDPRB.COM: $(BUILD)/kbdprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name KBDPRB.COM option quiet option map=KBDPRB.MAP file kbdprb.obj

$(BUILD)/ipcprb.obj: tests/ipcprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/IPCPRB.COM: $(BUILD)/ipcprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name IPCPRB.COM option quiet option map=IPCPRB.MAP file ipcprb.obj

$(BUILD)/leakprb.obj: tests/leakprb.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/LEAKPRB.COM: $(BUILD)/leakprb.obj
	cd $(BUILD) && $(JWLINK) format dos com name LEAKPRB.COM option quiet option map=LEAKPRB.MAP file leakprb.obj

$(BUILD)/cwdprobe.obj: tests/cwdprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/CWDPROBE.COM: $(BUILD)/cwdprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name CWDPROBE.COM option quiet option map=CWDPROBE.MAP file cwdprobe.obj

$(BUILD)/emsprobe.obj: tests/emsprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/EMSPROBE.COM: $(BUILD)/emsprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name EMSPROBE.COM option quiet option map=EMSPROBE.MAP file emsprobe.obj

$(BUILD)/gfxprobe.obj: tests/gfxprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/GFXPROBE.COM: $(BUILD)/gfxprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name GFXPROBE.COM option quiet option map=GFXPROBE.MAP file gfxprobe.obj

$(BUILD)/maxcfg.obj: src/maxcfg.c include/catalog.h include/mvui.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/MAXVAPP.EXE: $(BUILD)/maxcfg.obj $(BUILD)/catalog.obj $(BUILD)/mvui.obj
	cd $(BUILD) && $(JWLINK) format dos name MAXVAPP.EXE option quiet option map=MAXVAPP.MAP option stack=16384 option nofarcalls file maxcfg.obj,catalog.obj,mvui.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/maxmem.obj: src/maxmem.c include/maxbackend.h include/memquery.h include/mvui.h include/odqapi.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/memquery.obj: kernel/memquery.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MAXVMEM.EXE: $(BUILD)/maxmem.obj $(BUILD)/maxbackend.obj $(BUILD)/memquery.obj $(BUILD)/mvui.obj
	cd $(BUILD) && $(JWLINK) format dos name MAXVMEM.EXE option quiet option map=MAXVMEM.MAP option stack=4096 option nofarcalls file maxmem.obj,maxbackend.obj,memquery.obj,mvui.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/maxvset.obj: src/maxvset.c include/mvui.h include/settings.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/MAXVSET.EXE: $(BUILD)/maxvset.obj $(BUILD)/settings.obj $(BUILD)/mvui.obj
	cd $(BUILD) && $(JWLINK) format dos name MAXVSET.EXE option quiet option map=MAXVSET.MAP option stack=4096 option nofarcalls file maxvset.obj,settings.obj,mvui.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/autodetect.obj: src/autodetect.c include/autodetect.h include/catalog.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/maxvauto.obj: src/maxvauto.c include/autodetect.h include/catalog.h include/mvui.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/MAXVAUTO.EXE: $(BUILD)/maxvauto.obj $(BUILD)/autodetect.obj $(BUILD)/catalog.obj $(BUILD)/mvui.obj
	cd $(BUILD) && $(JWLINK) format dos name MAXVAUTO.EXE option quiet option map=MAXVAUTO.MAP option stack=8192 option nofarcalls file maxvauto.obj,autodetect.obj,catalog.obj,mvui.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/maxvfile.obj: src/maxvfile.c include/mvui.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/MAXVFILE.EXE: $(BUILD)/maxvfile.obj $(BUILD)/mvui.obj
	cd $(BUILD) && $(JWLINK) format dos name MAXVFILE.EXE option quiet option map=MAXVFILE.MAP option stack=8192 option nofarcalls file maxvfile.obj,mvui.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/dvp.obj: src/dvp.c include/dvp.h include/catalog.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/maxvdvp.obj: src/maxvdvp.c include/dvp.h include/catalog.h include/mvui.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/MAXVDVP.EXE: $(BUILD)/maxvdvp.obj $(BUILD)/dvp.obj $(BUILD)/catalog.obj $(BUILD)/mvui.obj
	cd $(BUILD) && $(JWLINK) format dos name MAXVDVP.EXE option quiet option map=MAXVDVP.MAP option stack=8192 option nofarcalls file maxvdvp.obj,dvp.obj,catalog.obj,mvui.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/maxvansi.obj: kernel/maxvansi.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MAXVANSI.COM: $(BUILD)/maxvansi.obj
	cd $(BUILD) && $(JWLINK) format dos com name MAXVANSI.COM option quiet option map=MAXVANSI.MAP file maxvansi.obj

$(BUILD)/dvprobe.obj: examples/dvprobe.c include/maxbackend.h include/odqapi.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/DVPROBE.EXE: $(BUILD)/dvprobe.obj $(BUILD)/maxbackend.obj
	cd $(BUILD) && $(JWLINK) format dos name DVPROBE.EXE option quiet option map=DVPROBE.MAP option stack=2048 option nofarcalls file dvprobe.obj,maxbackend.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/maxstub.obj: tests/maxstub.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MAXSTUB.COM: $(BUILD)/maxstub.obj
	cd $(BUILD) && $(JWLINK) format dos com name MAXSTUB.COM option quiet option map=MAXSTUB.MAP file maxstub.obj

$(BUILD)/ansiprobe.obj: tests/ansiprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/ANSIPRB.COM: $(BUILD)/ansiprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name ANSIPRB.COM option quiet option map=ANSIPRB.MAP file ansiprobe.obj

$(BUILD)/handleprobe.obj: tests/handleprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/HANDLEPR.COM: $(BUILD)/handleprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name HANDLEPR.COM option quiet option map=HANDLEPR.MAP file handleprobe.obj

$(BUILD)/objectprobe.obj: tests/objectprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/OBJPROBE.COM: $(BUILD)/objectprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name OBJPROBE.COM option quiet option map=OBJPROBE.MAP file objectprobe.obj

$(BUILD)/mailprobe.obj: tests/mailprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MAILPROB.COM: $(BUILD)/mailprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name MAILPROB.COM option quiet option map=MAILPROB.MAP file mailprobe.obj

$(BUILD)/printprobe.obj: tests/printprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/PRINTPR.COM: $(BUILD)/printprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name PRINTPR.COM option quiet option map=PRINTPR.MAP file printprobe.obj

$(BUILD)/bitprobe.obj: tests/bitprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/BITPROBE.COM: $(BUILD)/bitprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name BITPROBE.COM option quiet option map=BITPROBE.MAP file bitprobe.obj

$(BUILD)/soundprobe.obj: tests/soundprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/SOUNDPR.COM: $(BUILD)/soundprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name SOUNDPR.COM option quiet option map=SOUNDPR.MAP file soundprobe.obj

$(BUILD)/stackprobe.obj: tests/stackprobe.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/STACKPR.COM: $(BUILD)/stackprobe.obj
	cd $(BUILD) && $(JWLINK) format dos com name STACKPR.COM option quiet option map=STACKPR.MAP file stackprobe.obj

$(BUILD)/setup.obj: src/setup.c | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/SETUP.EXE: $(BUILD)/setup.obj
	cd $(BUILD) && $(JWLINK) format dos name SETUP.EXE option quiet option map=SETUP.MAP option stack=4096 option nofarcalls file setup.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

$(BUILD)/MAXVIEW.CFG: MAXVIEW.CFG | $(BUILD)
	cp $< $@

$(BUILD)/MAXVSET.INI: MAXVSET.INI | $(BUILD)
	cp $< $@

$(BUILD)/MAXVAUTO.DAT: MAXVAUTO.DAT | $(BUILD)
	cp $< $@

$(BUILD)/README.TXT: README.md | $(BUILD)
	cp $< $@

$(BUILD)/LICENSE.TXT: LICENSE | $(BUILD)
	cp $< $@

$(BUILD)/DOCS.TXT: docs/README.md | $(BUILD)
	cp $< $@

$(BUILD)/USERGUID.TXT: docs/USER_GUIDE.md | $(BUILD)
	cp $< $@

$(BUILD)/TOOLS.TXT: docs/TOOLS.md | $(BUILD)
	cp $< $@

$(BUILD)/CONFIG.TXT: docs/CONFIGURATION.md | $(BUILD)
	cp $< $@

$(BUILD)/BUILDING.TXT: docs/BUILDING.md | $(BUILD)
	cp $< $@

$(BUILD)/TESTING.TXT: docs/TESTING.md | $(BUILD)
	cp $< $@

$(BUILD)/API.TXT: docs/API.md | $(BUILD)
	cp $< $@

$(BUILD)/COMPAT.TXT: docs/COMPATIBILITY.md | $(BUILD)
	cp $< $@

$(BUILD)/CONFORM.TXT: docs/CONFORMANCE.md | $(BUILD)
	cp $< $@

$(BUILD)/DEVELOP.TXT: docs/DEVELOPMENT.md | $(BUILD)
	cp $< $@

$(BUILD)/ROADMAP.TXT: docs/ROADMAP.md | $(BUILD)
	cp $< $@

$(BUILD)/REMOTE2.TXT: docs/REMOTE_VIEW_2X.md | $(BUILD)
	cp $< $@

$(BUILD)/TROUBLE.TXT: docs/TROUBLESHOOTING.md | $(BUILD)
	cp $< $@

$(BUILD)/ARCHITEC.TXT: docs/ARCHITECTURE.md | $(BUILD)
	cp $< $@

$(BUILD)/HELP.TXT: docs/HELP.md | $(BUILD)
	cp $< $@

$(BUILD)/BBSGUIDE.TXT: docs/SERIAL_BBS.md | $(BUILD)
	cp $< $@

$(BUILD)/PROGDEV.TXT: docs/PROGRAMMING.md | $(BUILD)
	cp $< $@

$(BUILD)/QUICK.TXT: docs/QUICKSTART.md | $(BUILD)
	cp $< $@

books: book-html book-pdf book-epub

book-html:
	python3 tools/build_books.py --format developer-html

book-pdf:
	python3 tools/build_books.py --format user-pdf

book-epub:
	python3 tools/build_books.py --format user-epub

package: all
	rm -rf $(PACKAGE)
	mkdir -p $(PACKAGE)
	cp $(BUILD)/SETUP.EXE $(BUILD)/MAXVIEW.EXE $(BUILD)/MAXVTSR.COM \
		$(BUILD)/MAXVAPP.EXE $(BUILD)/MAXVMEM.EXE $(BUILD)/MAXVSET.EXE \
		$(BUILD)/MAXVAUTO.EXE $(BUILD)/MAXVFILE.EXE $(BUILD)/DVPROBE.EXE \
		$(BUILD)/MAXVDVP.EXE \
		$(BUILD)/MAXVANSI.COM $(BUILD)/MAXVIEW.CFG \
		$(BUILD)/MAXVSET.INI $(BUILD)/MAXVAUTO.DAT $(BUILD)/README.TXT \
		$(BUILD)/LICENSE.TXT $(addprefix $(BUILD)/,$(DOCFILES)) $(PACKAGE)/

setup-package: package books
	python3 tools/build_release.py --package $(PACKAGE) \
		--books $(BUILD)/books --output $(RELEASE_DIR) --version $(VERSION)

release-check:
	$(MAKE) clean
	$(MAKE) test
	$(MAKE) test-dos
	$(MAKE) setup-package

$(BUILD)/test_catalog: tests/test_catalog.c src/catalog.c include/catalog.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_catalog.c src/catalog.c

$(BUILD)/test_settings: tests/test_settings.c src/settings.c include/settings.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_settings.c src/settings.c

$(BUILD)/test_autodetect: tests/test_autodetect.c src/autodetect.c src/catalog.c include/autodetect.h include/catalog.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_autodetect.c src/autodetect.c src/catalog.c

$(BUILD)/test_dvp: tests/test_dvp.c src/dvp.c src/catalog.c include/dvp.h include/catalog.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_dvp.c src/dvp.c src/catalog.c

$(BUILD)/test_scheduler: tests/test_scheduler.c src/scheduler.c include/scheduler.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_scheduler.c src/scheduler.c

$(BUILD)/test_vmtask: tests/test_vmtask.c src/vmtask.c src/scheduler.c include/vmtask.h include/maxbackend.h include/scheduler.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_vmtask.c src/vmtask.c src/scheduler.c

$(BUILD)/test_mvprocess: tests/test_mvprocess.c src/mvprocess.c src/catalog.c src/scheduler.c include/mvprocess.h include/catalog.h include/scheduler.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_mvprocess.c src/mvprocess.c src/catalog.c src/scheduler.c

test: $(BUILD)/test_catalog $(BUILD)/test_settings $(BUILD)/test_autodetect $(BUILD)/test_dvp $(BUILD)/test_scheduler $(BUILD)/test_vmtask $(BUILD)/test_mvprocess
	$(BUILD)/test_catalog
	$(BUILD)/test_settings
	$(BUILD)/test_autodetect
	$(BUILD)/test_dvp
	$(BUILD)/test_scheduler
	$(BUILD)/test_vmtask
	$(BUILD)/test_mvprocess
	python3 -m unittest discover -s tests -p 'test_*.py'
	python3 tools/build_books.py --check

test-dos: all $(BUILD)/MAXSTUB.COM $(BUILD)/ANSIPRB.COM $(BUILD)/HANDLEPR.COM $(BUILD)/OBJPROBE.COM $(BUILD)/MAILPROB.COM $(BUILD)/PRINTPR.COM $(BUILD)/BITPROBE.COM $(BUILD)/SOUNDPR.COM $(BUILD)/STACKPR.COM $(BUILD)/test_dvp
	rm -rf $(BUILD)/INSTTEST
	rm -rf $(BUILD)/AUTOTEST
	rm -rf $(BUILD)/FILETEST
	rm -f $(BUILD)/AUTOCFG $(BUILD)/AUTOCFG.BAK $(BUILD)/AUTOCFG.NEW
	rm -f $(BUILD)/DVPCFG $(BUILD)/DVPCFG.BAK $(BUILD)/DVPCFG.NEW $(BUILD)/test.dvp
	$(BUILD)/test_dvp --keep
	mkdir -p $(BUILD)/AUTOTEST
	mkdir -p $(BUILD)/FILETEST
	cp $(BUILD)/MAXVTSR.COM $(BUILD)/AUTOTEST/EDIT.COM
	cp $(BUILD)/MAXVTSR.COM $(BUILD)/FILETEST/INPUT.BIN
	cp $(BUILD)/MAXVIEW.EXE $(BUILD)/FILETEST/OTHER.BIN
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVTSR.COM > MVTSR.TXT' -c 'MAXVTSR.COM > MVTSR2.TXT' \
		-c 'DVPROBE.EXE > MVPROBE.TXT' -c 'MAXSTUB.COM' \
		-c 'DVPROBE.EXE > MVPROBE2.TXT' \
		-c 'HANDLEPR.COM > HANDLEPR.TXT' \
		-c 'OBJPROBE.COM > OBJPROBE.TXT' -c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVTSR.COM > NUL' \
		-c 'MAILPROB.COM > MAILPROB.TXT' -c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVTSR.COM > NUL' \
		-c 'PRINTPR.COM > PRINTPR.TXT' \
		-c 'STACKPR.COM > STACKPR.TXT' -c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVTSR.COM > NUL' \
		-c 'BITPROBE.COM > BITPROBE.TXT' -c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVTSR.COM > NUL' \
		-c 'SOUNDPR.COM > SOUNDPR.TXT' -c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVANSI.COM > ANSI1.TXT' -c 'MAXVANSI.COM > ANSI2.TXT' \
		-c 'ANSIPRB.COM > ANSIPRB.TXT' -c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'SETUP.EXE /S /D:C:\BUILD\INSTTEST > INSTALL.TXT' \
		-c 'echo PRESERVED> C:\BUILD\INSTTEST\MAXVIEW.CFG' \
		-c 'echo INIKEEP> C:\BUILD\INSTTEST\MAXVSET.INI' \
		-c 'echo DATKEEP> C:\BUILD\INSTTEST\MAXVAUTO.DAT' \
		-c 'SETUP.EXE /S /D:C:\BUILD\INSTTEST > INSTALL2.TXT' \
		-c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVDVP.EXE /CHECK TEST.DVP > DVPCHK.TXT' \
		-c 'MAXVDVP.EXE /LIST TEST.DVP > DVPLIST.TXT' \
		-c 'COPY MAXVIEW.CFG DVPCFG > NUL' \
		-c 'MAXVDVP.EXE /IMPORT TEST.DVP /F:DVPCFG /K:Q > DVPIMP.TXT' \
		-c 'MAXVAPP.EXE /CHECK /F:DVPCFG > DVPCAT.TXT' \
		-c 'MAXVAPP.EXE /LIST /F:DVPCFG > DVPREC.TXT' \
		-c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVTSR.COM > NUL' -c 'MAXVAPP.EXE /CHECK > CFGCHK.TXT' \
		-c 'MAXVAPP.EXE /LIST > CFGLIST.TXT' \
		-c 'MAXVMEM.EXE /T > MEMSTAT.TXT' -c 'MAXSTUB.COM' \
		-c 'MAXVMEM.EXE /T > MEMMAX.TXT' -c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVSET.EXE /CHECK > SETCHK.TXT' \
		-c 'MAXVSET.EXE /LIST > SETLIST.TXT' \
		-c 'MAXVAUTO.EXE /CHECK > AUTOCHECK.TXT' \
		-c 'MAXVAUTO.EXE /SCAN /R:C:\BUILD\AUTOTEST > AUTOSCAN.TXT' \
		-c 'MAXVAUTO.EXE /APPLY /F:AUTOCFG /R:C:\BUILD\AUTOTEST > AUTOAPLY.TXT' \
		-c 'MAXVAUTO.EXE /APPLY /F:AUTOCFG /R:C:\BUILD\AUTOTEST > AUTODUP.TXT' \
		-c 'MAXVAPP.EXE /CHECK /F:AUTOCFG > AUTOCFG.TXT' \
		-c 'exit' >/dev/null 2>&1
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVFILE.EXE /LIST /P:C:\BUILD\FILETEST > FILELIST.TXT' \
		-c 'MAXVFILE.EXE /COPY C:\BUILD\FILETEST\INPUT.BIN C:\BUILD\FILETEST\COPY.BIN > FILECOPY.TXT' \
		-c 'MAXVFILE.EXE /COPY C:\BUILD\FILETEST\INPUT.BIN C:\BUILD\FILETEST\INPUT.BIN /Y > FILESAME.TXT' \
		-c 'MAXVFILE.EXE /COPY C:\BUILD\FILETEST\OTHER.BIN C:\BUILD\FILETEST\COPY.BIN /Y > FILEOVER.TXT' \
		-c 'exit' >/dev/null 2>&1
	rg -q 'resident API 0.36 installed' $(BUILD)/MVTSR.TXT
	rg -q 'already installed' $(BUILD)/MVTSR2.TXT
	rg -q 'API version 2.80 detected' $(BUILD)/MVPROBE.TXT
	rg -q 'Resident installation-path API passed' $(BUILD)/MVPROBE.TXT
	rg -q 'TopView-compatible GETVER identity passed' $(BUILD)/MVPROBE.TXT
	rg -q 'PAUSE call returned successfully' $(BUILD)/MVPROBE.TXT
	rg -q 'Foreground APPNUM and task defaults passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Foreground keyboard-mouse state API passed' $(BUILD)/MVPROBE.TXT
	rg -q 'APILEVEL, JUSTIFY and CSTYLE APIs passed' $(BUILD)/MVPROBE.TXT
	rg -q 'SET/GET ERROR APIs passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Resident system-memory APIs passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Extended system-memory allocation API passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Resident common-memory APIs passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Conventional and expanded memory status APIs passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Foreground task object APIs passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Foreground LOCATE and GETBUF APIs passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Foreground PROCESSMEM API passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Foreground DOSUSER, OBJNEXT and WININFO APIs passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Nested critical-section state passed' $(BUILD)/MVPROBE.TXT
	rg -q 'SCRNINFO and video identity APIs passed' $(BUILD)/MVPROBE.TXT
	rg -q 'DBGPOKE physical status-line API passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Alternate video-buffer API passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Foreground PUSHKEY API passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Foreground targeted PUTKEY API passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Open 386MAX backend not detected' $(BUILD)/MVPROBE.TXT
	rg -q 'Open 386MAX backend ABI 1.0, 2/4 contexts, QPI 7.3, table 00001234' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI master IRQ calldown lifecycle passed' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI active context release rejected' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI empty context token rejected' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI cloned page table 00005678 without activating it' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI second owned context clone rejected' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI allocated 4 private data pages, 00006789 through 0000678C' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI private data-page pool limit enforced' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI owned context activation verified' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI active owned context release rejected' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI active-clone private page release rejected' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI four-entry mapping table installed and verified' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI mapping-table duplicate and capacity guards passed' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI root restore blocked by uncommitted mapping' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI partial mapping-table commit blocks root restore' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI complete owned-clone mapping table committed' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI committed mapping table survived verified root restore' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI committed mapping blocks page and clone release' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI committed mapping table persisted across context switch' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI owned-clone mapping table restored and verified' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI root context restoration verified' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI private-page ownership blocks clone release' $(BUILD)/MVPROBE2.TXT
	rg -q 'QPI private data-page pool released after root restoration' $(BUILD)/MVPROBE2.TXT
	rg -q 'Open 386MAX QPI context lifecycle passed' $(BUILD)/MVPROBE2.TXT
	rg -q 'MAXVTSR HANDLE message passed' $(BUILD)/HANDLEPR.TXT
	rg -q 'MAXVTSR timer object lifecycle passed' $(BUILD)/OBJPROBE.TXT
	rg -q 'MAXVTSR mailbox queue lifecycle passed' $(BUILD)/MAILPROB.TXT
	rg -q 'MAXVTSR PRINTC foreground output passed' $(BUILD)/PRINTPR.TXT
	rg -q 'MAXVTSR task stack switching passed' $(BUILD)/STACKPR.TXT
	rg -q 'MAXVTSR second-level callback services passed' $(BUILD)/BITPROBE.TXT
	rg -q 'MAXVTSR bounded SOUND queue passed' $(BUILD)/SOUNDPR.TXT
	rg -q 'ANSI console 1.0 installed' $(BUILD)/ANSI1.TXT
	rg -q 'already installed' $(BUILD)/ANSI2.TXT
	rg -q 'MAXVANSI probe passed' $(BUILD)/ANSIPRB.TXT
	rg -q 'Open MaxView installed' $(BUILD)/INSTALL.TXT
	rg -q 'valid program' $(BUILD)/CFGCHK.TXT
	rg -q 'MAXVAPP.EXE' $(BUILD)/CFGLIST.TXT
	rg -q 'MV_API=0.36' $(BUILD)/MEMSTAT.TXT
	rg -q 'MV_COMMON_TOTAL_BYTES=2048' $(BUILD)/MEMSTAT.TXT
	rg -q 'MV_COMMON_AVAILABLE_BYTES=2048' $(BUILD)/MEMSTAT.TXT
	rg -q 'MV_COMMON_LARGEST_BYTES=256' $(BUILD)/MEMSTAT.TXT
	rg -q 'MV_PROCESS_TOTAL_PARAS=[1-9][0-9]*' $(BUILD)/MEMSTAT.TXT
	rg -q 'MV_PROCESS_SYSTEM_PARAS=0' $(BUILD)/MEMSTAT.TXT
	rg -q 'MV_PROCESS_LARGEST_SYSTEM_PARAS=16' $(BUILD)/MEMSTAT.TXT
	rg -q 'MAX_BACKEND=0' $(BUILD)/MEMSTAT.TXT
	rg -q 'MAX_BACKEND=1' $(BUILD)/MEMMAX.TXT
	rg -q 'MAX_ABI=1.0' $(BUILD)/MEMMAX.TXT
	rg -q 'MAX_QPI=7.3' $(BUILD)/MEMMAX.TXT
	rg -q 'MAX_QPI_CONTEXT=00001234' $(BUILD)/MEMMAX.TXT
	rg -q 'settings valid' $(BUILD)/SETCHK.TXT
	rg -q 'AUTO_TSR=YES' $(BUILD)/SETLIST.TXT
	rg -q 'AUTO_ANSI=YES' $(BUILD)/SETLIST.TXT
	rg -q 'valid detection rule' $(BUILD)/AUTOCHEC.TXT
	rg -q 'EDIT.COM|DOS text editor|C:\\BUILD\\AUTOTEST' $(BUILD)/AUTOSCAN.TXT
	rg -q 'added 1 program' $(BUILD)/AUTOAPLY.TXT
	rg -q 'added 0 program' $(BUILD)/AUTODUP.TXT
	rg -q '1 valid program' $(BUILD)/AUTOCFG.TXT
	rg -q 'F|INPUT.BIN|' $(BUILD)/FILELIST.TXT
	rg -q 'file copied' $(BUILD)/FILECOPY.TXT
	rg -q 'copy failed' $(BUILD)/FILESAME.TXT
	rg -q 'file copied' $(BUILD)/FILEOVER.TXT
	rg -q 'valid DVP for Sample editor' $(BUILD)/DVPCHK.TXT
	rg -q 'PATH=C:\\DOS\\EDIT.COM' $(BUILD)/DVPLIST.TXT
	rg -q 'imported Sample editor as hotkey Q' $(BUILD)/DVPIMP.TXT
	rg -q 'valid program' $(BUILD)/DVPCAT.TXT
	rg -q 'Q|Sample editor|C:\\DOS\\EDIT.COM NOTES.TXT|C:\\WORK|192|640' $(BUILD)/DVPREC.TXT
	rg -q '192|640|1|2|4|1000|7|2048|8|25|80|2|1|3|154|18|52|86|120' $(BUILD)/DVPREC.TXT
	cmp $(BUILD)/FILETEST/OTHER.BIN $(BUILD)/FILETEST/COPY.BIN
	test ! -f '$(BUILD)/FILETEST/COPY.$$MV'
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVFILE.EXE /DELETE C:\BUILD\FILETEST\COPY.BIN /Y > FILEDEL.TXT' \
		-c 'exit' >/dev/null 2>&1
	rg -q 'file deleted' $(BUILD)/FILEDEL.TXT
	test ! -f $(BUILD)/FILETEST/COPY.BIN
	test -f $(BUILD)/INSTTEST/MAXVIEW.EXE
	test -f $(BUILD)/INSTTEST/MAXVTSR.COM
	test -f $(BUILD)/INSTTEST/MAXVAPP.EXE
	test -f $(BUILD)/INSTTEST/MAXVMEM.EXE
	test -f $(BUILD)/INSTTEST/MAXVSET.EXE
	test -f $(BUILD)/INSTTEST/MAXVAUTO.EXE
	test -f $(BUILD)/INSTTEST/MAXVFILE.EXE
	test -f $(BUILD)/INSTTEST/MAXVANSI.COM
	test -f $(BUILD)/INSTTEST/MAXVDVP.EXE
	test -f $(BUILD)/INSTTEST/MAXVIEW.CFG
	test -f $(BUILD)/INSTTEST/MAXVSET.INI
	test -f $(BUILD)/INSTTEST/MAXVAUTO.DAT
	test -f $(BUILD)/INSTTEST/DOCS.TXT
	test -f $(BUILD)/INSTTEST/USERGUID.TXT
	test -f $(BUILD)/INSTTEST/TOOLS.TXT
	test -f $(BUILD)/INSTTEST/CONFIG.TXT
	test -f $(BUILD)/INSTTEST/BUILDING.TXT
	test -f $(BUILD)/INSTTEST/TESTING.TXT
	test -f $(BUILD)/INSTTEST/API.TXT
	test -f $(BUILD)/INSTTEST/COMPAT.TXT
	test -f $(BUILD)/INSTTEST/CONFORM.TXT
	test -f $(BUILD)/INSTTEST/DEVELOP.TXT
	test -f $(BUILD)/INSTTEST/ROADMAP.TXT
	test -f $(BUILD)/INSTTEST/REMOTE2.TXT
	test -f $(BUILD)/INSTTEST/TROUBLE.TXT
	test -f $(BUILD)/INSTTEST/ARCHITEC.TXT
	test -f $(BUILD)/INSTTEST/HELP.TXT
	test -f $(BUILD)/INSTTEST/BBSGUIDE.TXT
	test -f $(BUILD)/INSTTEST/PROGDEV.TXT
	test -f $(BUILD)/INSTTEST/QUICK.TXT
	test -f $(BUILD)/INSTTEST/MAXVIEW.LOG
	rg -q '^PRESERVED' $(BUILD)/INSTTEST/MAXVIEW.CFG
	rg -q '^INIKEEP' $(BUILD)/INSTTEST/MAXVSET.INI
	rg -q '^DATKEEP' $(BUILD)/INSTTEST/MAXVAUTO.DAT

clean:
	find $(BUILD) -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null || true
	rm -rf $(BUILD)/INSTTEST
	rm -rf $(BUILD)/AUTOTEST
	rm -rf $(BUILD)/FILETEST
	rm -rf $(PACKAGE)

