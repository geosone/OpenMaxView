# Open MaxView DOS build. This uses the same open-source tool chain as Open
# 386MAX: Open Watcom's C compiler plus its embedded JWasm and JWlink.

WATCOM ?= /opt/watcom
MAXROOT ?= /home/mario/mars/386MAX
WCC    := $(WATCOM)/binl64/wcc
JWASM  := $(MAXROOT)/linux/bin/jwasm
JWLINK := $(MAXROOT)/linux/bin/jwlink
CC     ?= cc
BUILD  := build
PACKAGE := $(BUILD)/OpenMaxView

DOS_CFLAGS := -bt=dos -ms -0 -os -s -zq -w4 -i=include -i=$(WATCOM)/h

.PHONY: all package test test-dos clean

all: $(BUILD)/MAXVTSR.COM $(BUILD)/MAXVIEW.EXE $(BUILD)/MAXVAPP.EXE \
	$(BUILD)/MAXVMEM.EXE $(BUILD)/MAXVSET.EXE $(BUILD)/MAXVAUTO.EXE \
	$(BUILD)/MAXVFILE.EXE $(BUILD)/MAXVANSI.COM $(BUILD)/DVPROBE.EXE \
	$(BUILD)/SETUP.EXE $(BUILD)/MAXVIEW.CFG \
	$(BUILD)/MAXVSET.INI $(BUILD)/MAXVAUTO.DAT $(BUILD)/README.TXT \
	$(BUILD)/LICENSE.TXT

$(BUILD):
	mkdir -p $@

$(BUILD)/odqtsr.obj: kernel/odqtsr.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MAXVTSR.COM: $(BUILD)/odqtsr.obj
	cd $(BUILD) && $(JWLINK) format dos com name MAXVTSR.COM option quiet option map=MAXVTSR.MAP file odqtsr.obj

$(BUILD)/opendesq.obj: src/opendesq.c include/catalog.h include/maxbackend.h include/odqapi.h include/settings.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/catalog.obj: src/catalog.c include/catalog.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/settings.obj: src/settings.c include/settings.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/mvui.obj: src/mvui.c include/mvui.h | $(BUILD)
	WATCOM=$(WATCOM) $(WCC) $(DOS_CFLAGS) -fo=$@ $<

$(BUILD)/maxbackend.obj: kernel/maxbackend.asm | $(BUILD)
	$(JWASM) -Zm -c -q -W1 -Fo$@ $<

$(BUILD)/MAXVIEW.EXE: $(BUILD)/opendesq.obj $(BUILD)/catalog.obj $(BUILD)/settings.obj $(BUILD)/maxbackend.obj
	cd $(BUILD) && $(JWLINK) format dos name MAXVIEW.EXE option quiet option map=MAXVIEW.MAP option stack=16384 option nofarcalls file opendesq.obj,catalog.obj,settings.obj,maxbackend.obj libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286

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

package: all
	rm -rf $(PACKAGE)
	mkdir -p $(PACKAGE)
	cp $(BUILD)/SETUP.EXE $(BUILD)/MAXVIEW.EXE $(BUILD)/MAXVTSR.COM \
		$(BUILD)/MAXVAPP.EXE $(BUILD)/MAXVMEM.EXE $(BUILD)/MAXVSET.EXE \
		$(BUILD)/MAXVAUTO.EXE $(BUILD)/MAXVFILE.EXE $(BUILD)/DVPROBE.EXE \
		$(BUILD)/MAXVANSI.COM $(BUILD)/MAXVIEW.CFG \
		$(BUILD)/MAXVSET.INI $(BUILD)/MAXVAUTO.DAT $(BUILD)/README.TXT \
		$(BUILD)/LICENSE.TXT $(PACKAGE)/

$(BUILD)/test_catalog: tests/test_catalog.c src/catalog.c include/catalog.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_catalog.c src/catalog.c

$(BUILD)/test_settings: tests/test_settings.c src/settings.c include/settings.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_settings.c src/settings.c

$(BUILD)/test_autodetect: tests/test_autodetect.c src/autodetect.c src/catalog.c include/autodetect.h include/catalog.h | $(BUILD)
	$(CC) -std=c89 -Wall -Wextra -Werror -pedantic -Iinclude -o $@ tests/test_autodetect.c src/autodetect.c src/catalog.c

test: $(BUILD)/test_catalog $(BUILD)/test_settings $(BUILD)/test_autodetect
	$(BUILD)/test_catalog
	$(BUILD)/test_settings
	$(BUILD)/test_autodetect
	python3 -m unittest discover -s tests -p 'test_*.py'

test-dos: all $(BUILD)/MAXSTUB.COM $(BUILD)/ANSIPRB.COM
	rm -rf $(BUILD)/INSTTEST
	rm -rf $(BUILD)/AUTOTEST
	rm -rf $(BUILD)/FILETEST
	rm -f $(BUILD)/AUTOCFG $(BUILD)/AUTOCFG.BAK $(BUILD)/AUTOCFG.NEW
	mkdir -p $(BUILD)/AUTOTEST
	mkdir -p $(BUILD)/FILETEST
	cp $(BUILD)/MAXVTSR.COM $(BUILD)/AUTOTEST/EDIT.COM
	cp $(BUILD)/MAXVTSR.COM $(BUILD)/FILETEST/INPUT.BIN
	cp $(BUILD)/MAXVIEW.EXE $(BUILD)/FILETEST/OTHER.BIN
	env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -noconsole \
		-c 'mount c $(CURDIR)' -c 'c:' -c 'cd build' \
		-c 'MAXVTSR.COM > MVTSR.TXT' -c 'MAXVTSR.COM > MVTSR2.TXT' \
		-c 'DVPROBE.EXE > MVPROBE.TXT' -c 'MAXSTUB.COM' \
		-c 'DVPROBE.EXE > MVPROBE2.TXT' -c 'exit' >/dev/null 2>&1
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
	rg -q 'resident API 0.2 installed' $(BUILD)/MVTSR.TXT
	rg -q 'already installed' $(BUILD)/MVTSR2.TXT
	rg -q 'API version 2.80 detected' $(BUILD)/MVPROBE.TXT
	rg -q 'PAUSE call returned successfully' $(BUILD)/MVPROBE.TXT
	rg -q 'Nested critical-section state passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Alternate video-buffer API passed' $(BUILD)/MVPROBE.TXT
	rg -q 'Open 386MAX backend not detected' $(BUILD)/MVPROBE.TXT
	rg -q 'Open 386MAX backend ABI 1.0, 2/4 contexts' $(BUILD)/MVPROBE2.TXT
	rg -q 'ANSI console 1.0 installed' $(BUILD)/ANSI1.TXT
	rg -q 'already installed' $(BUILD)/ANSI2.TXT
	rg -q 'MAXVANSI probe passed' $(BUILD)/ANSIPRB.TXT
	rg -q 'Open MaxView installed' $(BUILD)/INSTALL.TXT
	rg -q 'valid program' $(BUILD)/CFGCHK.TXT
	rg -q 'MAXVAPP.EXE' $(BUILD)/CFGLIST.TXT
	rg -q 'MV_API=0.2' $(BUILD)/MEMSTAT.TXT
	rg -q 'MAX_BACKEND=0' $(BUILD)/MEMSTAT.TXT
	rg -q 'MAX_BACKEND=1' $(BUILD)/MEMMAX.TXT
	rg -q 'MAX_ABI=1.0' $(BUILD)/MEMMAX.TXT
	rg -q 'settings valid' $(BUILD)/SETCHK.TXT
	rg -q 'AUTO_TSR=YES' $(BUILD)/SETLIST.TXT
	rg -q 'valid detection rule' $(BUILD)/AUTOCHEC.TXT
	rg -q 'EDIT.COM|DOS text editor|C:\\BUILD\\AUTOTEST' $(BUILD)/AUTOSCAN.TXT
	rg -q 'added 1 program' $(BUILD)/AUTOAPLY.TXT
	rg -q 'added 0 program' $(BUILD)/AUTODUP.TXT
	rg -q '1 valid program' $(BUILD)/AUTOCFG.TXT
	rg -q 'F|INPUT.BIN|' $(BUILD)/FILELIST.TXT
	rg -q 'file copied' $(BUILD)/FILECOPY.TXT
	rg -q 'copy failed' $(BUILD)/FILESAME.TXT
	rg -q 'file copied' $(BUILD)/FILEOVER.TXT
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
	test -f $(BUILD)/INSTTEST/MAXVIEW.CFG
	test -f $(BUILD)/INSTTEST/MAXVSET.INI
	test -f $(BUILD)/INSTTEST/MAXVAUTO.DAT
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

