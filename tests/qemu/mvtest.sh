#!/bin/bash
# The multitasking core on real Open 386MAX in QEMU:  MS-DOS 6.22 with
# 386MAX (Open386MAX's linux/test/dosboot.sh and its test images); MVRUN
# runs the tasks of a case.  The cases follow Open386MAX's
# linux/test/desqview.sh (DESQview 2.80 on 386MAX is the bar).
#
#   tests/qemu/mvtest.sh [two|mem|serial|keys|kill|crit|desk|win|dvapi|progs|cwd|ems|gfx] [...]       (default: all)
#
#   two   two TICK tasks (Open386MAX TESTS/SCENARIO/TICK:  a line a second
#         into a file, the first also a byte to COM1) for 30 s:  both
#         count, COM1 gets a byte per line of the first
#   mem   two MEMPROBE tasks (tests/memprobe.asm) with different patterns:
#         the same PSP segment (each its own conventional memory), neither
#         pattern overwritten
#   serial a BBS node:  task 1 SERECHO (Open386MAX TESTS/SCENARIO/SERECHO:
#         receives on COM1 by IRQ4, echoes each byte), task 2 TICK; the IRQ
#         goes to task 1 also while task 2 runs.  Open386MAX's
#         linux/test/serfeed.py sends 3000 bytes at 50 bytes/s and checks
#         the echo
#   keys  foreground and background:  KEYPROBE (tests/keyprobe.asm) task 1
#         reads by INT 16h, task 2 by DOS, task 3 TICK; task 1 starts in
#         the foreground (MVRUN /F1), Ctrl+Alt+2 and Ctrl+Alt+1 switch.
#         Each screen shows only its own task, each task gets only the keys
#         typed while it is the foreground, and the waiting tasks leave
#         the CPU to TICK
#   kill  MVRUN /K8:  after 8 s the tasks are killed:  KEYPROBE by DOS
#         (task 1, the foreground:  in DOS, by Ctrl-C), KEYPROBE by INT 16h
#         and TICK (outside DOS); then a TICK starts in a freed slot.  All
#         end with exit FF, the first TICK stops, the new one counts, DOS
#         works afterwards
#   crit  a critical error in the background:  task 2 CRITPRB opens A:\X
#         (no disk) while TICK (task 1) is the foreground; the critical
#         error prompt comes to the foreground and keeps it (Ctrl+Alt+1
#         ignored; meanwhile all tasks wait, as under DOS), Ignore ("u"
#         German, "i" English) answers it, CRITPRB ends, TICK counts on
#   desk  MAXVIEW.EXE itself (with its resident services):  TICK and
#         KEYPROBE started from the menu, Alt back to the menu, the task
#         list switches to KEYPROBE, which ends; exit closes TICK, DOS
#         works afterwards
#   win   MAXVIEW windows:  two KEYPROBEs side by side on one screen, keys
#         typed into a window, a window moved, zoomed to full screen and
#         closed
#   dvapi the DESQview scheduling calls (MAXVTSR loaded):  DVTASK
#         (tests/dvtask.asm) A measures, B counts in the BIOS area 40:F0h;
#         APPNUM is the task #, nothing else runs inside BEGINC..ENDC, PAUSE
#         leaves the CPU to B
#   progs the regression tests of Open386MAX's TESTS/ (PROGS, as in its
#         desqview.sh), each in a task of its own (COMMAND.COM /C R.BAT
#         test, errorlevel -> PROGS.TXT), JOBS runs at a time; each also
#         runs without MaxView:  a test fails only when it passes there.
#         The task is the foreground (as DESQview's Big DOS window).
#         Expected in a task (EXPECT):  VDSFUNC "physical = linear" (the
#         task's conventional memory is private pages; VDS gives their
#         real addresses, which is its purpose)
#   cwd   the current directory per task:  two CWDPROBEs (tests/
#         cwdprobe.asm) change to C:\A and C:\B and keep finding their
#         own; MVRUN's stays C:\
#   ems   EMS per task:  two EMSPROBEs (tests/emsprobe.asm) map 4 pages of
#         their own each into the page frame and keep seeing their own
#         pattern
#   gfx   video modes per task:  GFXPROBE (tests/gfxprobe.asm) in VGA mode
#         13h, KEYPROBE in text; switching between them sets each one's
#         mode, the graphics task is held in the background and draws
#         again when it is back
#   deskmany  MAXVIEW.EXE with 12 programs (11 TICKs, KEYPROBE):  the task
#         list scrolls (10 rows), IDs 1-9 then A, B, C; Enter on the last
#         one (C) gives it screen and keys
#   ipc   task mailboxes (tests/ipcprb.asm):  a server names its own
#         mailbox and waits in READ, a client finds it and writes to it
#   wwrite WRITE to the task's window (tests/winprb.asm)
#   wstream a window stream in WRITE (tests/strprb.asm)
#   wquery a query stream in WRITE (tests/qryprb.asm)
#   crtc  a background task's CRTC/DAC OUTs trapped (tests/crtprb.asm)
#   wobj   a window object (tests/wobprb.asm)
#   menu   demos/menu.asm:  a menu window with a keyboard object
#   pointer a pointer object (tests/ptrprb.asm; needs CuteMouse)
#   fieldops broadcast and scrolling of fields (tests/bcsprb.asm)
#   mouse  a click on a select field (tests/mseprb.asm; needs CuteMouse)
#   records numbered field records (tests/numprb.asm)
#   selects select fields by key (tests/selprb.asm)
#   fields input fields in field mode (tests/fldprb.asm)
#   objq  the task's OBJECTQ (tests/obqprb.asm)
#   kbd   the task's keyboard object (tests/kbdprb.asm):  READ waits for a
#         key, gives its character (F1:  00)
#   objs  DESQview objects of a task that ends (tests/leakprb.asm):  the
#         stack effect of NEW/HANDLE/FREE as DESQview 2.80; a task takes a
#         GETMEM and a GETCOMMON block, a mailbox and a timer and ends:  the
#         next task finds the GETMEM blocks and mailboxes all back, one
#         common block and one timer gone (DESQview frees the same when a
#         window is closed)
#   many  16 task slots (MVRUN /N16, its list from a file):  15 TICKs all
#         count side by side, a 16th program finds the table full
#
# MAXROOT (default ../Open386MAX) needs build/bin (386MAX) and
# build/TESTS.  MVDEBUG=1:  the core traces to port E9h (<case>.e9).
# Output:  build/test-qemu/<case>/ (screens, test.img), <case>.log
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
MAXROOT=${MAXROOT:-$(cd "$ROOT/../Open386MAX" && pwd)}
OUT=$ROOT/build/test-qemu
TICK=$MAXROOT/build/TESTS/TICK.EXE
export MTOOLS_SKIP_CHECK=1
CASES=${*:-two mem serial nodes samecom keys kill crit desk deskmany win rearr mrs tune dvpopt dvpwin setup blank lefthand ipx netbios mvlaunch memstat dossvc video mark help catalog learn lpause dial scis paste ntf alw vntf swap noswap dvapi cwd ems gfx objs ipc kbd objq fields selects records mouse fieldops pointer pntf revive wobj panel menu demos countdn serve subtask worms launch ownwin subown wwrite wstream wquery crtc many progs}
PROGS=${PROGS:-XMSFUNC XMSLOCK EMSFUNC EMSMORE VCPIFUNC VDSFUNC V86FUNC INT15 A20 DPMIMISC RMCBNEST PMSTACK}
JOBS=${JOBS:-6}
EXPECT_VDSFUNC='physical = linear FAIL'
[ -s "$TICK" ] || { echo "no $TICK (make -C $MAXROOT TESTS)"; exit 2; }
rm -f "$ROOT/build/mvkern.obj" "$ROOT/build/MVRUN.EXE"
make -s -C "$ROOT" MVDEBUG=${MVDEBUG:-0} build/MVRUN.EXE build/MEMPROBE.COM \
    build/KEYPROBE.COM build/CRITPRB.COM build/MAXVIEW.EXE build/DVTASK.COM \
    build/MAXVTSR.COM build/CWDPROBE.COM build/EMSPROBE.COM build/GFXPROBE.COM build/LEAKPRB.COM build/IPCPRB.COM \
    build/MAXVANSI.COM build/KBDPRB.COM build/WINPRB.COM build/STRPRB.COM build/QRYPRB.COM build/CRTPRB.COM \
    build/OBQPRB.COM build/NTFPRB.COM build/FLDPRB.COM build/SELPRB.COM build/NUMPRB.COM build/MSEPRB.COM build/BCSPRB.COM build/PTRPRB.COM build/WOBPRB.COM build/MENU.COM build/HELLO.COM build/MOUSE.COM build/COUNTDN.COM build/SERVE.COM build/ASK.COM build/SUBPRB.COM build/WORMS.COM build/LAUNCH.COM build/OWNPRB.COM build/SOWPRB.COM build/SERPRB.COM build/PANPRB.COM build/ALWPRB.COM build/IPXPRB.COM build/NBPRB.COM build/MVTEST.PLB || exit 2
mkdir -p "$OUT"
fail=0

run() {     # case, seconds, MVRUN task list, more files, steps before the end
    local dir=$OUT/$1
    rm -rf "$dir"; mkdir -p "$dir"
    KEEP=1 CONFIG="${CONFIG:-}" ACCEL="-accel tcg" XFILES="$ROOT/build/MVRUN.EXE ${4:-}" \
        QEMU_EXTRA="-debugcon file:$OUT/$1.e9 ${SERIAL:--serial file:$OUT/$1.com1}" \
        AUTO="${CMD:-C:\\MVRUN ${FG:-}$2 $3}" \
        STEPS="${5:-} ${END:-wait:MVRUN:_done:$(($2 * 3 + 120))} text:end" TESTDIR="$dir" \
        "$MAXROOT/linux/test/dosboot.sh" msdos622 > "$OUT/$1.log" 2>&1
    [ -n "${END:-}" ] || grep -q "MVRUN: done" "$dir/end.txt" 2>/dev/null ||
        { echo "  MVRUN did not end:"; grep -v '^\s*$' "$dir/fail.txt" 2>/dev/null | tail -4; }
}

file() {    # case, file:  a file of the run's C:
    mtype -i "$OUT/$1/test.img@@32256" ::/$2 2>/dev/null | tr -d '\r'
}

last() {    # case, file, word:  the number after the last "word"
    file "$1" "$2" | awk -v w="$3" '$1 == w {n = $2 + 0} END {print n + 0}'
}

oldwin() {  # MAXVSET.INI:  windows 1 and 2 smaller (room to move them right)
    printf 'WINDOW1=2,2,10,50\r\nWINDOW2=5,8,10,50\r\n' > "$OUT/MAXVSET.INI"
    echo "$OUT/MAXVSET.INI"
}

check() {   # description, condition
    if eval "$2"; then echo "  OK    $1"
    else echo "  FAIL  $1"; fail=1; fi
}

for c in $CASES; do
case $c in
two)
    echo "== two:  two TICK tasks, the first with COM1"
    run two 30 "C:\\TICK.EXE C:\\T1.TXT C ; C:\\TICK.EXE C:\\T2.TXT" "$TICK"
    t1=$(last two T1.TXT tick); t2=$(last two T2.TXT tick)
    com=$(wc -c < "$OUT/two.com1" 2>/dev/null || echo 0)
    echo "  T1 $t1, T2 $t2, COM1 $com bytes"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/two/end.txt'"
    check "task 1 counts" "[ $t1 -ge 25 ]"
    check "task 2 counts" "[ $t2 -ge 25 ]"
    check "COM1 byte per line of T1" "[ $com -ge $((t1 - 1)) ] && [ $com -le $((t1 + 1)) ]"
    ;;
mem)
    echo "== mem:  two tasks, each with conventional memory of its own"
    run mem 15 "C:\\MEMPROBE.COM C:\\M1.TXT A ; C:\\MEMPROBE.COM C:\\M2.TXT B" "$ROOT/build/MEMPROBE.COM"
    m1=$(file mem M1.TXT); m2=$(file mem M2.TXT)
    echo "  M1: ${m1:-none}"; echo "  M2: ${m2:-none}"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/mem/end.txt'"
    check "task 1 pattern kept" "[ \"\$(echo \$m1 | awk '{print \$3 \$4}')\" = Aok ]"
    check "task 2 pattern kept" "[ \"\$(echo \$m2 | awk '{print \$3 \$4}')\" = Bok ]"
    check "same PSP segment (private memory)" "[ -n \"\$m1\" ] && ! echo \$m1 | grep -q 'psp 0000' && [ \"\$(echo \$m1 | awk '{print \$2}')\" = \"\$(echo \$m2 | awk '{print \$2}')\" ]"
    echo "== mem:  text pages 1-7 per task"
    run memv 15 "C:\\MEMPROBE.COM C:\\M1.TXT A V ; C:\\MEMPROBE.COM C:\\M2.TXT B V" "$ROOT/build/MEMPROBE.COM"
    m1=$(file memv M1.TXT); m2=$(file memv M2.TXT)
    echo "  M1: ${m1:-none}"; echo "  M2: ${m2:-none}"
    check "task 1 text pages kept" "[ \"\$(echo \$m1 | awk '{print \$3 \$4}')\" = Aok ]"
    check "task 2 text pages kept" "[ \"\$(echo \$m2 | awk '{print \$3 \$4}')\" = Bok ]"
    ;;
serial)
    echo "== serial:  IRQ4 to the task that hooked it"
    sock=$OUT/serial.sock; rm -f "$sock" "$OUT/serial.feed"
    ( sleep 5; python3 "$MAXROOT/linux/test/serfeed.py" "$sock" --count 3000 \
          --rate 50 --wait 400 --out "$OUT/serial.feed" > /dev/null ) &
    SERIAL="-serial unix:$sock,server,nowait" run serial 120 \
        "C:\\SERECHO.EXE C:\\S.TXT ; C:\\TICK.EXE C:\\T2.TXT" \
        "$MAXROOT/build/TESTS/SERECHO.EXE $TICK"
    wait
    feed=$(cat "$OUT/serial.feed" 2>/dev/null)
    rx=$(last serial S.TXT rx); t2=$(last serial T2.TXT tick)
    echo "  ${feed:-no feed result}, SERECHO counted $rx, TICK $t2"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/serial/end.txt'"
    check "every byte echoed unchanged" "[ \"\${feed% ok}\" != \"\$feed\" ]"
    check "SERECHO counted 3000 bytes" "[ $rx -eq 3000 ]"
    check "task 2 counts" "[ $t2 -ge 100 ]"
    ;;
nodes)
    echo "== nodes:  two BBS nodes (COM1 IRQ4, COM2 IRQ3) at once, the foreground switched"
    s1=$OUT/nodes1.sock s2=$OUT/nodes2.sock; rm -f "$s1" "$s2" "$OUT"/nodes?.feed
    for n in 1 2; do
        ( sleep 5; python3 "$MAXROOT/linux/test/serfeed.py" "$OUT/nodes$n.sock" --count ${NCOUNT:-3000} \
              --rate ${NRATE:-100} --wait 400 --out "$OUT/nodes$n.feed" > /dev/null ) &
    done
    SERIAL="-serial unix:$s1,server,nowait -serial unix:$s2,server,nowait" FG="/F3 " run nodes 120 \
        "C:\\SERPRB.COM 1 C:\\S1.TXT ; C:\\SERPRB.COM 2 C:\\S2.TXT ; C:\\TICK.EXE C:\\T3.TXT" \
        "$ROOT/build/SERPRB.COM $TICK" \
        "sleep:20 key:ctrl-alt-1 sleep:8 key:ctrl-alt-2 sleep:8 key:ctrl-alt-3 sleep:8 key:ctrl-alt-1"
    wait
    f1=$(cat "$OUT/nodes1.feed" 2>/dev/null); f2=$(cat "$OUT/nodes2.feed" 2>/dev/null)
    r1=$(last nodes S1.TXT rx); r2=$(last nodes S2.TXT rx); t3=$(last nodes T3.TXT tick)
    echo "  COM1 ${f1:-no feed result}, COM2 ${f2:-no feed result}; counted $r1 $r2, TICK $t3"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/nodes/end.txt'"
    check "COM1:  every byte echoed unchanged" "[ \"\${f1% ok}\" != \"\$f1\" ]"
    check "COM2:  every byte echoed unchanged" "[ \"\${f2% ok}\" != \"\$f2\" ]"
    check "both nodes counted ${NCOUNT:-3000} bytes" "[ $r1 -eq ${NCOUNT:-3000} ] && [ $r2 -eq ${NCOUNT:-3000} ]"
    check "task 3 counts" "[ $t3 -ge 100 ]"
    ;;
samecom)
    echo "== samecom:  two tasks hook COM1's IRQ4:  the last one gets it, in front or not (as DV)"
    sock=$OUT/samecom.sock; rm -f "$sock" "$OUT/samecom.feed"
    ( sleep 5; python3 "$MAXROOT/linux/test/serfeed.py" "$sock" --count 3000 \
          --rate 100 --wait 400 --out "$OUT/samecom.feed" > /dev/null ) &
    SERIAL="-serial unix:$sock,server,nowait" FG="/F1 " run samecom 90 \
        "C:\\SERPRB.COM 1 C:\\S1.TXT ; C:\\TICK.EXE C:\\T2.TXT ; C:\\SERPRB.COM 1 C:\\S3.TXT" \
        "$ROOT/build/SERPRB.COM $TICK"
    wait
    r1=$(last samecom S1.TXT rx); r3=$(last samecom S3.TXT rx)
    echo "  $(cat "$OUT/samecom.feed" 2>/dev/null); task 1 counted $r1, task 3 $r3"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/samecom/end.txt'"
    check "task 3 (hooked IRQ4 last, in the background) got all 3000 bytes" "[ $r3 -eq 3000 ]"
    check "task 1 (in front, hooked it first) none" "[ $r1 -eq 0 ]"
    ;;
keys)
    echo "== keys:  foreground task gets screen and keys"
    kp="$ROOT/build/KEYPROBE.COM"
    FG="/F1 " run keys 60 \
        "C:\\KEYPROBE.COM C:\\K1.TXT B ; C:\\KEYPROBE.COM C:\\K2.TXT D ; C:\\TICK.EXE C:\\T3.TXT" \
        "$kp $TICK" \
        "wait:keyprobe_B_ready:60 sleep:3 text:fg1 key:a,b,c sleep:2 key:ctrl-alt-2 wait:keyprobe_D_ready:20 sleep:2 text:fg2 key:x,y,z sleep:2 key:dot sleep:2 key:ctrl-alt-1 wait:abc:20 text:fg3 key:dot"
    k1=$(file keys K1.TXT); k2=$(file keys K2.TXT); t3=$(last keys T3.TXT tick)
    d=$OUT/keys
    echo "  K1 '$k1', K2 '$k2', TICK $t3"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$d/end.txt'"
    check "task 1 screen alone" "grep -q 'keyprobe B ready' '$d/fg1.txt' && ! grep -q 'keyprobe D' '$d/fg1.txt'"
    check "task 2 screen after Ctrl+Alt+2" "grep -q 'keyprobe D ready' '$d/fg2.txt' && ! grep -q 'keyprobe B' '$d/fg2.txt'"
    check "task 1 screen back, with its echo" "grep -q 'abc' '$d/fg3.txt' && ! grep -q 'xyz' '$d/fg3.txt'"
    check "task 1 got its keys (INT 16h)" "[ '$k1' = abc ]"
    check "task 2 got its keys (DOS)" "[ '$k2' = xyz ]"
    check "TICK counts meanwhile" "[ $t3 -ge 45 ]"
    ;;
kill)
    echo "== kill:  ending tasks, a new one in a freed slot"
    FG="/F1 /K8 " run kill 30 \
        "C:\\KEYPROBE.COM C:\\K1.TXT D ; C:\\KEYPROBE.COM C:\\K2.TXT B ; C:\\TICK.EXE C:\\T3.TXT ; C:\\TICK.EXE C:\\T4.TXT" \
        "$ROOT/build/KEYPROBE.COM $TICK" "wait:MVRUN:_done:120 type:dir_c:\\k*.txt"
    d=$OUT/kill
    t3=$(last kill T3.TXT tick); t4=$(last kill T4.TXT tick)
    grep -a "killed in\|^task" "$d/end.txt" | sed 's/  *$//;s/^/  /'
    echo "  T3 $t3, T4 $t4"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$d/end.txt'"
    check "all killed (exit FF)" "grep -q 'killed in .* 1 done 00FF 2 done 00FF 3 done 00FF' '$d/end.txt'"
    check "new task in a freed slot" "grep -q '^task 1: C:.TICK.EXE C:.T4.TXT' '$d/end.txt'"
    check "killed TICK stopped" "[ $t3 -ge 5 ] && [ $t3 -le 10 ]"
    check "new TICK counts" "[ $t4 -ge 15 ]"
    check "DOS works afterwards" "grep -q 'K2 *TXT' '$d/end.txt'"
    ;;
crit)
    echo "== crit:  critical error of a background task"
    FG="/F1 " run crit 30 "C:\\TICK.EXE C:\\T1.TXT ; C:\\CRITPRB.COM A:\\X C:\\C2.TXT" \
        "$ROOT/build/CRITPRB.COM $TICK" \
        "wait:critprobe_start:40 sleep:2 text:crit key:ctrl-alt-1 sleep:3 text:crit2 key:u sleep:1 key:i sleep:2 text:after"
    d=$OUT/crit
    c2=$(file crit C2.TXT); t1=$(last crit T1.TXT tick)
    echo "  C2 '$c2', T1 $t1"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$d/end.txt'"
    check "prompt in the foreground" "grep -q 'critprobe start' '$d/crit.txt' && grep -qi 'A:\\|Laufwerk A\\|drive A' '$d/crit.txt'"
    check "Ctrl+Alt+1 ignored meanwhile" "grep -q 'critprobe start' '$d/crit2.txt' && ! grep -q 'MVRUN' '$d/crit2.txt'"
    check "answered:  CRITPRB went on" "[ \"\${c2#open }\" != \"\$c2\" ]"
    check "TICK counts on" "[ $t1 -ge 20 ]"
    ;;
desk)
    echo "== desk:  MAXVIEW.EXE runs programs as tasks, its menu covers DESQview's"
    cfg=$OUT/MAXVIEW.CFG
    printf 'T|Tick counter|C:\\TICK.EXE C:\\T1.TXT||64|640\r\nK|Key probe|C:\\KEYPROBE.COM C:\\K2.TXT D||64|640\r\n' > "$cfg"
    CMD="C:\\MAXVIEW" END="wait:desk_end:30" run desk 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/KEYPROBE.COM $TICK $cfg" \
        "wait:Open_Program:60 text:desk0 key:ret sleep:3 text:tick key:alt wait:Switch_Windows:20 text:desk1 mon:xp+/4000xb+0xb8000>menu shot:menu key:o wait:Change_a_Program:20 text:open key:k wait:keyprobe_D_ready:20 key:x,y sleep:1 key:alt wait:Switch_Windows:20 key:s wait:Key_probe__________2:10 sleep:1 text:tasks key:2 sleep:2 key:z key:dot wait:Key_probe_ended:20 text:ended sleep:3 key:q wait:Are_you_sure:10 text:confirm key:y gone:Switch_Windows:20 sleep:2 type:echo_desk_end"
    d=$OUT/desk
    k2=$(file desk K2.TXT); t1=$(last desk T1.TXT tick)
    echo "  K2 '$k2', T1 $t1"
    check "desktop up, multitasking" "grep -q 'Open Program' '$d/desk0.txt' && ! grep -q 'One program at a time' '$d/desk0.txt'"
    check "TICK on its own screen" "[ -f '$d/tick.txt' ] && ! grep -q 'Open Program' '$d/tick.txt'"
    check "Alt:  the windows and the menu (Open Window O ... Quit MaxView Q)" "grep -q 'Open Window *O' '$d/desk1.txt' && grep -q 'Rearrange *R' '$d/desk1.txt' && grep -q 'Quit MaxView *Q' '$d/desk1.txt' && grep -q 'Tick' '$d/desk1.txt'"
    # cell (row, column) of the menu's dump:  character and attribute
    cell() { awk '/^[0-9a-f]+:/' "$d/menu.txt" | grep -o "0x[0-9a-f][0-9a-f]" | sed -n "$((($1 * 80 + $2) * 2 + 1)),+1p" | tr '\n' ' ' | sed 's/ $//'; }
    check "the menu at the top right in Open 386MAX's look:  single frame 70h, the bar 0Fh with its red trigger 0Ch, triggers 74h, keys at the right, a line, Mark's trigger 74h, Scissors not available (78h), a shadow" "[ '$(cell 0 54)' = '0xda 0x70' ] && [ '$(cell 0 77)' = '0xbf 0x70' ] && [ '$(cell 14 54)' = '0xc0 0x70' ] && [ '$(cell 1 55)' = '0x20 0x0f' ] && [ '$(cell 1 56)' = '0x4f 0x0c' ] && [ '$(cell 2 56)' = '0x53 0x74' ] && [ '$(cell 2 75)' = '0x53 0x70' ] && [ '$(cell 4 56)' = '0xc4 0x70' ] && [ '$(cell 8 56)' = '0x4d 0x74' ] && [ '$(cell 10 56)' = '0x53 0x78' ] && [ '$(cell 1 78 | cut -c6-9)' = '0x08' ]"
    check "Open Window:  the programs by key, Add / Delete / Change a Program" "grep -q 'Tick counter *T' '$d/open.txt' && grep -q 'Key probe *K' '$d/open.txt' && grep -q 'Change a Program' '$d/open.txt'"
    check "Switch Windows:  the windows by number" "grep -q 'Tick counter *1' '$d/tasks.txt' && grep -q 'Key probe *2' '$d/tasks.txt'"
    check "KEYPROBE got its keys (also in its window)" "[ '$k2' = xyz ]"
    check "end reported" "grep -q 'Key probe ended' '$d/ended.txt' && grep -q 'code 0' '$d/ended.txt'"
    check "Quit MaxView:  Are you sure? Yes / No" "grep -q 'Are you sure' '$d/confirm.txt' && grep -q 'Yes *Y' '$d/confirm.txt'"
    check "TICK counted meanwhile" "[ $t1 -ge 10 ]"
    check "DOS works afterwards (TICK closed)" "grep -q '^desk end' '$d/end.txt'"
    ;;
deskmany)
    echo "== deskmany:  MAXVIEW.EXE with 12 programs"
    cfg=$OUT/MAXVIEW.CFG
    : > "$cfg"
    for i in $(seq 1 11); do   # (hotkeys must differ)
        printf '%s|Tick %d|C:\\TICK.EXE C:\\T%d.TXT||64|640\r\n' $(echo 1234567890X | cut -c$i) $i $i >> "$cfg"
    done
    printf 'Z|Key probe|C:\\KEYPROBE.COM C:\\K12.TXT D||64|640\r\n' >> "$cfg"
    st="wait:Open_Program:60 key:ret sleep:3"
    for i in $(seq 2 12); do   # Open Window, the program's key
        st="$st key:alt wait:Switch_Windows:20 key:o wait:Change_a_Program:20 key:$(echo 234567890xz | cut -c$((i - 1))) sleep:3"
    done
    st="$st wait:keyprobe_D_ready:20 key:alt wait:Switch_Windows:20 key:s wait:Key_probe__________C:10 sleep:1 text:list1"
    st="$st key:c sleep:2 key:k key:dot wait:Key_probe_ended:20 text:ended sleep:2 key:q wait:Are_you_sure:10 text:confirm key:y gone:Switch_Windows:30 sleep:2 type:echo_deskmany_end"
    CMD="C:\\MAXVIEW" END="wait:deskmany_end:60" run deskmany 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/KEYPROBE.COM $TICK $cfg" "$st"
    d=$OUT/deskmany
    k=$(file deskmany K12.TXT); n=0
    for i in $(seq 1 11); do [ $(last deskmany T$i.TXT tick) -ge 5 ] && n=$((n + 1)); done
    echo "  K12 '$k', TICKs counting $n of 11"
    check "Switch Windows:  all 12 numbered as DESQview's (1-9, A, B, C)" "grep -q 'Tick 1  *1 ' '$d/list1.txt' && grep -q 'Tick 9  *9 ' '$d/list1.txt' && grep -q 'Tick 10  *A ' '$d/list1.txt' && grep -q 'Tick 11  *B ' '$d/list1.txt' && grep -q 'Key probe  *C ' '$d/list1.txt'"
    check "C:  KEYPROBE gets the keys" "[ '$k' = k ]"
    check "11 TICKs count" "[ $n -eq 11 ]"
    check "Quit MaxView asks" "grep -q 'Are you sure' '$d/confirm.txt'"
    check "DOS works afterwards (11 closed)" "grep -q '^deskmany end' '$d/end.txt'"
    ;;
win)
    echo "== win:  windows of several tasks, rearranged through the menu"
    cfg=$OUT/MAXVIEW.CFG
    printf 'A|Probe A|C:\\KEYPROBE.COM C:\\W1.TXT D||64|640\r\nB|Probe B|C:\\KEYPROBE.COM C:\\W2.TXT B||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:win_end:30" run win 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/KEYPROBE.COM $cfg $(oldwin)" \
        "wait:Open_Program:60 key:ret wait:keyprobe_D_ready:20 $M key:o wait:Change_a_Program:20 key:b wait:keyprobe_B_ready:20 $M sleep:1 text:two key:s wait:Probe_B:10 key:1 sleep:1 key:a,b sleep:2 text:typed $M key:r wait:Tune_Performance:10 text:rearr key:m key:right,right,right,down sleep:1 key:ret sleep:1 text:moved mon:xp+/4000xb+0xb8000>mvram $M key:z sleep:2 text:full $M key:c wait:Are_you_sure:10 key:y wait:Probe_A_ended:20 text:closed key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_win_end"
    d=$OUT/win
    w1=$(file win W1.TXT)
    # the frame's title as DESQview's "1==Probe A"
    c1=$(awk '/Probe A/ {print NR*100 + index($0, "Probe A"); exit}' "$d/typed.txt" 2>/dev/null)
    c2=$(awk '/Probe A/ {print NR*100 + index($0, "Probe A"); exit}' "$d/moved.txt" 2>/dev/null)
    # its blank a double line, as DV's "1==DOS=(128K)"
    t=$(awk '/^[0-9a-f]+:/' "$d/mvram.txt" 2>/dev/null | grep -o "0x[0-9a-f][0-9a-f]" | awk 'NR % 2' | tr '\n' ' ')
    echo "  W1 '$w1', title at $c1 -> $c2"
    check "both windows on one screen" "grep -q 'keyprobe D ready' '$d/two.txt' && grep -q 'keyprobe B ready' '$d/two.txt'"
    check "Switch Windows 1:  typing into its window" "grep -q 'ab' '$d/typed.txt' && ! grep -q 'Switch Windows' '$d/typed.txt'"
    check "window keys to its task" "[ '$w1' = ab ]"
    check "Rearrange with DESQview's items (Move M ... Tune Performance)" "grep -q 'Move *M' '$d/rearr.txt' && grep -q 'Resize *R' '$d/rearr.txt' && grep -q 'Tune Performance' '$d/rearr.txt'"
    check "Move:  the window moved (3 right, 1 down)" "[ -n '$c1' ] && [ \$(( ${c2:-0} - ${c1:-0} )) -eq 103 ]"
    check "title blank as the frame (Probe=A)" "echo '$t' | grep -q '0x50 0x72 0x6f 0x62 0x65 0xcd 0x41'"
    check "Zoom:  full screen" "grep -q 'keyprobe D ready' '$d/full.txt' && ! grep -q 'Switch Windows' '$d/full.txt'"
    check "Close Window, Yes" "grep -q 'Probe A ended' '$d/closed.txt' && ! grep -q 'keyprobe D' '$d/closed.txt'"
    check "DOS works afterwards" "grep -q '^win end' '$d/end.txt'"
    ;;
rearr)
    echo "== rearr:  Rearrange's Position, Scroll, Freeze, Hide, Put Aside"
    cfg=$OUT/MAXVIEW.CFG
    printf 'A|TickA|C:\\TICK.EXE C:\\TA.TXT||64|640\r\nB|TickB|C:\\TICK.EXE C:\\TB.TXT||64|640\r\nC|TickC|C:\\TICK.EXE C:\\TC.TXT||64|640\r\nD|TickD|C:\\TICK.EXE C:\\TD.TXT||64|640\r\nK|Probe|C:\\KEYPROBE.COM C:\\K.TXT D||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    R="$M key:r wait:Tune_Performance:10"
    O() { echo "$M key:o wait:Change_a_Program:20 key:$1 sleep:3"; }
    CMD="C:\\MAXVIEW" END="wait:rearr_end:30" run rearr 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/KEYPROBE.COM $TICK $cfg" \
        "wait:Open_Program:60 key:ret sleep:3 $R text:menu key:f sleep:1 $(O b) $R key:h sleep:1 $(O c) $(O d) $R key:p sleep:1 $(O k) wait:keyprobe_D_ready:20 $R key:9 sleep:2 text:placed mon:xp+/4000xb+0xb8000>pos $R key:s key:right,right,right sleep:1 key:ret sleep:1 text:scrolled $M key:s wait:TickD:10 text:list key:esc sleep:20 key:alt wait:Switch_Windows:20 key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_rearr_end"
    d=$OUT/rearr
    a=$(last rearr TA.TXT tick); b=$(last rearr TB.TXT tick); c=$(last rearr TC.TXT tick); e=$(last rearr TD.TXT tick)
    pc() { awk '/^[0-9a-f]+:/' "$d/pos.txt" | grep -o "0x[0-9a-f][0-9a-f]" | sed -n "$((($1 * 80 + $2) * 2 + 1))p"; }
    echo "  ticks:  frozen $a, hidden $b, front $c, put aside $e"
    check "Rearrange:  Scroll S, Position 1-9, Freeze F, Hide H, Put Aside P" "grep -q 'Scroll *S' '$d/menu.txt' && grep -q 'Position *1-9' '$d/menu.txt' && grep -q 'Freeze *F' '$d/menu.txt' && grep -q 'Hide *H' '$d/menu.txt' && grep -q 'Put Aside *P' '$d/menu.txt'"
    check "Position 9:  the window in the bottom right quarter (13,41 / 24,79)" "[ '$(pc 13 41) $(pc 13 79) $(pc 24 41) $(pc 24 79)' = '0xc9 0xbb 0xc8 0xbc' ]"
    check "hidden and put aside:  not on the screen, the others are" "grep -q 'TickA' '$d/placed.txt' && grep -q 'TickC' '$d/placed.txt' && ! grep -q 'TickB' '$d/placed.txt' && ! grep -q 'TickD' '$d/placed.txt'"
    check "Scroll 3 right:  the view moved" "grep -q 'probe D ready' '$d/scrolled.txt' && ! grep -q 'keyprobe D ready' '$d/scrolled.txt'"
    check "Switch Windows lists the hidden and put aside ones" "grep -q 'TickB' '$d/list.txt' && grep -q 'TickD' '$d/list.txt'"
    check "Freeze:  the frozen window stopped, Put Aside too, Hide runs on" "[ -n '$c' ] && [ $((${a:-99} * 3)) -lt ${c:-0} ] && [ $((${e:-99} * 3)) -lt ${c:-0} ] && [ $((${b:-0} * 3)) -gt $((${c:-0} * 2)) ]"
    check "DOS works afterwards" "grep -q '^rearr end' '$d/end.txt'"
    ;;
tune)
    echo "== tune:  Tune Performance (Share CPU, ticks) and Change Colors"
    cfg=$OUT/MAXVIEW.CFG
    printf 'A|TickA|C:\\TICK.EXE C:\\TA.TXT||64|640\r\nB|TickB|C:\\TICK.EXE C:\\TB.TXT||64|640\r\nK|Probe|C:\\KEYPROBE.COM C:\\K.TXT D||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    R="$M key:r wait:Tune_Performance:10"
    CMD="C:\\MAXVIEW" END="wait:tune_end:30" run tune 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/KEYPROBE.COM $TICK $cfg" \
        "wait:Open_Program:60 key:ret sleep:3 $M key:o wait:Change_a_Program:20 key:b sleep:2 $R key:t wait:This_Window:10 text:tune0 key:s,f,a,w sleep:1 text:tune1 key:m sleep:1 text:tune2 key:esc,esc sleep:20 $M sleep:3 key:o wait:Change_a_Program:20 key:k wait:keyprobe_D_ready:20 $R key:c sleep:1 key:down,right sleep:1 key:ret sleep:2 mon:xp+/4000xb+0xb8000>col $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_tune_end"
    d=$OUT/tune
    a=$(last tune TA.TXT tick); b=$(last tune TB.TXT tick)
    hb=$(awk '/^[0-9a-f]+:/' "$d/col.txt" | grep -o "0x[0-9a-f][0-9a-f]" | tr '\n' ' ')
    echo "  ticks:  A $a (started first), B $b (in front, not sharing ~20 s)"
    check "Tune Performance:  this window and the system's values" "grep -q 'Run in background *\[Y\] *B' '$d/tune0.txt' && grep -q 'Share CPU in front *\[Y\] *S' '$d/tune0.txt' && grep -q 'Foreground ticks *\[ 6\]' '$d/tune0.txt' && grep -q 'Background ticks *\[ 2\]' '$d/tune0.txt'"
    check "Revive Mouse, Share EGA (the program's, shown), Allow swapping out (this window, the system)" "grep -q 'Revive Mouse *M' '$d/tune0.txt' && grep -q 'Share EGA in front *Y' '$d/tune0.txt' && [ \"\$(grep -c 'Allow swapping out *\[Y\]' '$d/tune0.txt')\" = 2 ]"
    check "S, F, A, W:  Share CPU N, foreground ticks 7, swapping N twice" "grep -q 'Share CPU in front *\[N\]' '$d/tune1.txt' && grep -q 'Foreground ticks *\[ 7\]' '$d/tune1.txt' && [ \"\$(grep -c 'Allow swapping out *\[N\]' '$d/tune1.txt')\" = 2 ]"
    check "M:  Revive Mouse (no driver here:  said so)" "grep -q 'No mouse driver' '$d/tune2.txt'"
    check "not sharing:  the window behind waited (A + 10 < B)" "[ -n '$a' ] && [ -n '$b' ] && [ $((a + 10)) -lt $b ]"
    check "Change Colors:  the program's 07h shown 18h (Down:  blue, Right:  dark grey)" "echo '$hb' | grep -q '0x6b 0x18 0x65 0x18 0x79 0x18 0x70 0x18'"
    check "DOS works afterwards" "grep -q '^tune end' '$d/end.txt'"
    ;;
dvpopt)
    echo "== dvpopt:  a DVP's Runs in background N, Share CPU N, Allow Close Window N (as DESQview 2.80 writes them)"
    cfg=$OUT/MAXVIEW.CFG
    printf 'A|TickA|C:\\TICK.EXE C:\\TA.TXT||64|640\r\nN|TickN|C:\\TICK.EXE C:\\TN.TXT||64|640|1|2|0|0|0|0|0|0|0|0|0|0|0|225|0|48|205\r\nE|EchoN|ECHO closeexit_N||64|640|1|2|0|0|0|0|0|25|80|0|0|0|0|0|0|0|77|0|0|0|0|2\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    R="$M key:r wait:Tune_Performance:10"
    CMD="C:\\MAXVIEW" END="wait:dvpopt_end:30" run dvpopt 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $TICK $cfg" \
        "wait:Open_Program:60 key:ret sleep:3 $M key:o wait:Change_a_Program:20 key:n sleep:3 $M text:menu $R key:t wait:This_Window:10 text:tune key:esc sleep:1 key:esc sleep:1 key:esc sleep:1 $M key:o wait:Change_a_Program:20 key:e sleep:5 text:echon $M key:s sleep:2 text:echosw key:esc sleep:1 key:esc sleep:1 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_dvpopt_end"
    d=$OUT/dvpopt
    check "Allow Close Window N:  Close Window without a key" "grep -q 'Close Window' '$d/menu.txt' && ! grep -q 'Close Window *C' '$d/menu.txt'"
    check "Runs in background N, Share CPU N:  Tune shows them" "grep -q 'Run in background *\[N\]' '$d/tune.txt' && grep -q 'Share CPU in front *\[N\]' '$d/tune.txt'"
    check "Close on exit N (18Bh bit 7 clear, 17Ch 0):  after ECHO its window stays, a DOS prompt in it" "grep -q 'closeexit_N' '$d/echon.txt' && grep -q '^C:.*>' '$d/echon.txt' && grep -q 'EchoN' '$d/echosw.txt'"
    check "DOS works afterwards" "grep -q '^dvpopt end' '$d/end.txt'"
    ;;
dvpwin)
    echo "== dvpwin:  a DVP's starting window (row 4, column 2, 9 x 40) and its maximum (9 x 40) for Resize"
    cfg=$OUT/MAXVIEW.CFG
    printf 'W|Probe W|C:\\KEYPROBE.COM C:\\W1.TXT D||64|640|1|2|0|0|0|0|0|9|40|0|0|0|0|0|0|0|2|4|2|9|40\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:dvpwin_end:30" run dvpwin 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/KEYPROBE.COM $cfg" \
        "wait:Open_Program:60 key:ret wait:keyprobe_D_ready:20 $M sleep:1 mon:xp+/4000xb+0xb8000>v1 key:r wait:Tune_Performance:10 key:r wait:Resize:__arrows:10 key:right,right,down,down sleep:1 key:ret sleep:1 mon:xp+/4000xb+0xb8000>v2 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_dvpwin_end"
    d=$OUT/dvpwin
    vc() { awk '/^[0-9a-f]+:/' "$d/$1.txt" 2>/dev/null | grep -o "0x[0-9a-f][0-9a-f]" | sed -n "$((($2 * 80 + $3) * 2 + 1))p"; }
    corners() { echo "$(vc $1 3 1) $(vc $1 13 1) $(vc $1 3 42) $(vc $1 13 42)"; }
    echo "  frame corners (3,1) (13,1) (3,42) (13,42):  $(corners v1), after Resize:  $(corners v2)"
    check "the window's contents at row 4, column 2, 9 x 40 (its frame around them)" "[ '$(corners v1)' = '0xc9 0xc8 0xbb 0xbc' ]"
    check "Resize:  not past its Maximum Height and Width" "[ '$(corners v2)' = '0xc9 0xc8 0xbb 0xbc' ]"
    check "DOS works afterwards" "grep -q '^dvpwin end' '$d/end.txt'"
    ;;
setup)
    echo "== setup:  MAXVSET's pages (DESQview's Advanced Setup):  Performance, Swapping, Keyboard, Window Positions, Auto Dialer; MAXVIEW with them"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    E="key:ret key:backspace,backspace"
    CMD="C:\\MAXVSET" END="wait:setup_end:30" run setup 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/MAXVSET.EXE $cfg" \
        "wait:Load_resident:60 key:p wait:Foreground_ticks:10 $E type:9 sleep:1 text:perf key:s wait:Swapping_directory:10 key:spc key:down key:ret type:C:\\SW sleep:1 text:swap key:k wait:Use_Learn:10 key:spc key:w wait:Window_Positions:10 $E type:3 key:right $E type:10 key:right $E type:8 key:right $E type:40 sleep:1 text:wpos key:a wait:Dialer_baud:10 key:down $E type:4 sleep:1 text:dial key:m wait:Left-handed:10 key:down key:spc key:v wait:Blank_the_screen:10 key:down $E type:5 sleep:1 text:video key:f2 wait:Settings_saved:10 key:esc sleep:3 type:MAXVSET_/LIST_>C:\\SL.TXT sleep:3 type:MAXVIEW wait:Open_Program:60 key:ret sleep:5 key:shift-alt sleep:3 text:sa $M sleep:1 mon:xp+/4000xb+0xb8000>v1 key:r wait:Tune_Performance:10 key:t wait:This_Window:10 sleep:1 text:tune key:esc,esc sleep:2 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_setup_end"
    d=$OUT/setup
    sl=$(file setup SL.TXT | tr '\n' ' ')
    echo "  /LIST:  $sl"
    vc() { awk '/^[0-9a-f]+:/' "$d/$1.txt" 2>/dev/null | grep -o "0x[0-9a-f][0-9a-f]" | sed -n "$((($2 * 80 + $3) * 2 + 1))p"; }
    corners="$(vc v1 2 9) $(vc v1 11 9) $(vc v1 2 50) $(vc v1 11 50)"
    echo "  frame corners (2,9) (11,9) (2,50) (11,50):  $corners"
    check "the pages:  Performance, Swapping, Window Positions, Auto Dialer (2400 shown)" "grep -q 'Foreground ticks *9' '$d/perf.txt' && grep -q 'C:.SW' '$d/swap.txt' && grep -q 'Height' '$d/wpos.txt' && grep -q '2400' '$d/dial.txt'"
    check "saved:  FOREGROUND 9, SWAPPING NO, SWAP_DIR, LEARN NO, WINDOW1 3,10,8,40, DIAL_BAUD 4, LEFT_HANDED, BLANK 5" "echo '$sl' | grep -q 'FOREGROUND=9 ' && echo '$sl' | grep -q 'SWAPPING=NO ' && echo '$sl' | grep -q 'SWAP_DIR=C:.SW ' && echo '$sl' | grep -q 'LEARN=NO ' && echo '$sl' | grep -q 'WINDOW1=3,10,8,40 ' && echo '$sl' | grep -q 'WINDOW2=14,1,10,78 ' && echo '$sl' | grep -q 'DIAL_BAUD=4 ' && echo '$sl' | grep -q 'LEFT_HANDED=YES ' && echo '$sl' | grep -q 'BLANK=5 ' && echo '$sl' | grep -q 'MOUSE=YES '"
    check "MAXVIEW:  window 1 (no starting window of its own) at Setup's position (row 3, column 10, 8 x 40)" "[ '$corners' = '0xc9 0xc8 0xbb 0xbc' ]"
    check "MAXVIEW:  Learn N (Shift+Alt opens nothing)" "! grep -q 'Display Scripts' '$d/sa.txt'"
    check "MAXVIEW:  Tune Performance with Setup's 9 foreground ticks, swapping N" "grep -q 'Foreground ticks *\[ 9\]' '$d/tune.txt' && grep -q 'Background ticks *\[ 2\]' '$d/tune.txt' && grep -q 'Allow swapping out *\[N\]' '$d/tune.txt'"
    check "DOS works afterwards" "grep -q '^setup end' '$d/end.txt'"
    ;;
blank)
    echo "== blank:  Setup's screen blanker (BLANK=1):  the display off after a minute, a key on again and to the program (as DESQview 2.80, measured)"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    printf 'BLANK=1\r\n' > "$OUT/MAXVSET.INI"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:blank_end:30" run blank 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $cfg $OUT/MAXVSET.INI" \
        "wait:Open_Program:60 key:ret sleep:5 shot:b0 sleep:30 shot:b1 sleep:45 shot:b2 key:x sleep:3 shot:b3 text:b3 key:backspace $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_blank_end"
    d=$OUT/blank
    lit() { python3 -c "from PIL import Image; import sys; print(max(max(p[:3]) for p in Image.open(sys.argv[1]).convert('RGB').getdata()))" "$1" 2>/dev/null; }
    echo "  brightest pixel:  at 5 s $(lit $d/b0.png), 35 s $(lit $d/b1.png), 80 s $(lit $d/b2.png), after the key $(lit $d/b3.png)"
    check "shown before the minute, blank after it" "[ \"\$(lit $d/b0.png)\" -gt 0 ] && [ \"\$(lit $d/b1.png)\" -gt 0 ] && [ \"\$(lit $d/b2.png)\" = 0 ]"
    check "a key:  shown again, the key to the program" "[ \"\$(lit $d/b3.png)\" -gt 0 ] && grep -q 'C:.>x' '$d/b3.txt'"
    check "DOS works afterwards" "grep -q '^blank end' '$d/end.txt'"
    ;;
lefthand)
    echo "== lefthand:  Setup's Mouse left-handed:  a DESQview pointer's right button is its left one (NTFPRB P in MAXVIEW)"
    CTM=${CTMOUSE:-$HOME/mars/scratch-386max/ctm/bin/ctmouse.exe}
    if [ ! -f "$CTM" ]; then echo "  SKIP  no CuteMouse (CTMOUSE=path of ctmouse.exe)"; continue; fi
    cp "$CTM" "$OUT/CTMOUSE.EXE"
    cfg=$OUT/MAXVIEW.CFG
    printf 'N|Pointer|C:\\NTFPRB.COM C:\\N1.TXT P||64|640\r\n' > "$cfg"
    printf 'LEFT_HANDED=YES\r\n' > "$OUT/MAXVSET.INI"
    printf 'C:\\CTMOUSE.EXE\r\nC:\\MAXVIEW\r\n' > "$OUT/L.BAT"
    mv() { local s="" i; for ((i = 0; i < $3; i++)); do s="$s mon:mouse_move+$1+$2 sleep:0.2"; done; echo "$s"; }
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\L.BAT" END="wait:lefthand_end:30" run lefthand 0 "" \
        "$OUT/L.BAT $OUT/CTMOUSE.EXE $ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/NTFPRB.COM $cfg $OUT/MAXVSET.INI" \
        "wait:Open_Program:60 key:ret wait:ntfprb_ready:60 sleep:3 $(mv -100 -100 10) $(mv 4 0 23) $(mv 0 8 4) $(mv 0 4 1) sleep:1 mon:mouse_button+2 sleep:0.5 mon:mouse_button+0 sleep:2 $(mv 4 0 8) sleep:1 mon:mouse_button+1 sleep:0.5 mon:mouse_button+0 sleep:2 key:x sleep:3 key:esc wait:Leave_Open_MaxView:10 key:y sleep:3 type:echo_lefthand_end"
    n1=$(file lefthand N1.TXT)
    st=$(echo "$n1" | grep '^  a 0[0-9A-F] 00 [0-9A-F][0-9A-F] 00 0[1-3] 00' | awk '{print $6}' | tr '\n' ' ')
    echo "  the pointer messages' buttons:  $st"
    check "right button pressed:  left (01h); left pressed:  right (02h)" "[ '$st' = '01 02 ' ]"
    check "DOS works afterwards" "grep -q '^lefthand end' '$OUT/lefthand/end.txt'"
    ;;
ipx|netbios)
    if [ "$c" = ipx ]; then
        echo "== ipx:  IPX in a window behind a busy one (Novell ODI, NE2000, a second VM sending; DESQview's Multitask IPX)"
        prb=IPXPRB; ready=ipxprb_ready; nb=""; ftxt=I.TXT
    else
        echo "== netbios:  NETBIOS (Novell's, over IPX) in a window behind a busy one:  no-wait receives with a POST routine (DESQview's Multitask NETBIOS)"
        prb=NBPRB; ready=nbprb_ready; nb='C:\NETBIOS|'; ftxt=N.TXT
    fi
    NET=${NETDRV:-$ROOT/build/net/bin}
    if [ ! -f "$NET/IPXODI.COM" ] || [ ! -f "$NET/NETBIOS.EXE" ]; then echo "  SKIP  no LSL, NE2000, IPXODI, NETBIOS (NETDRV=directory of them)"; continue; fi
    d=$OUT/$c; rm -rf "$d" "$d-b"; mkdir -p "$d" "$d-b"
    printf 'Link Driver NE2000\r\n    INT 3\r\n    PORT 300\r\n    FRAME Ethernet_802.3\r\n' > "$OUT/NET.CFG"
    printf 'R|Receiver|C:\\%s.COM C:\\%s R 30||64|640\r\nT|Busy|C:\\TICK.EXE C:\\T.TXT||64|640\r\n' $prb $ftxt > "$OUT/MAXVIEW.CFG"
    NF="$NET/LSL.COM $NET/NE2000.COM $NET/IPXODI.COM $NET/NETBIOS.EXE $OUT/NET.CFG $ROOT/build/$prb.COM"
    nic() { echo "-device ne2k_isa,netdev=n0,iobase=0x300,irq=3,mac=52:54:00:12:34:$1 -netdev socket,id=n0,$2"; }
    port=$((20000 + RANDOM % 20000))
    M="key:alt wait:Switch_Windows:20"
    KEEP=1 ACCEL="-accel tcg" XFILES="$NF $ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $OUT/MAXVIEW.CFG $TICK" \
        AUTO="@ECHO OFF|C:\\LSL|C:\\NE2000|C:\\IPXODI|${nb}C:\\MAXVIEW" QEMU_EXTRA="$(nic 0a listen=127.0.0.1:$port)" \
        STEPS="wait:Open_Program:120 key:ret wait:$ready:30 sleep:2 $M key:o wait:Change_a_Program:20 key:t sleep:140 $M sleep:2 text:menu key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_${c}_end wait:${c}_end:30 text:end" \
        TESTDIR="$d" "$MAXROOT/linux/test/dosboot.sh" msdos622 > "$OUT/$c.log" 2>&1 &
    pa=$!
    sleep 2
    KEEP=1 ACCEL="-accel tcg" XFILES="$NF" \
        AUTO="@ECHO OFF|C:\\LSL|C:\\NE2000|C:\\IPXODI|${nb}CHOICE /T:N,60 /N /C:NY|C:\\$prb C:\\$ftxt S 30|ECHO b done" \
        QEMU_EXTRA="$(nic 0b connect=127.0.0.1:$port)" STEPS="wait:b_done:300 text:b" \
        TESTDIR="$d-b" "$MAXROOT/linux/test/dosboot.sh" msdos622 > "$OUT/$c-b.log" 2>&1
    wait $pa
    i=$(file $c $ftxt); s=$(file $c-b $ftxt)
    echo "  receiver:  $(echo "$i" | head -1); $(echo "$i" | tail -1)"
    check "the sender:  30 sent" "echo '$s' | grep -q '^s 30 00'"
    if [ "$c" = ipx ]; then
        check "IPX entry MAXVTSR's (the driver's kept)" "echo '$i' | grep -q '^ipx ' && echo '$i' | grep -q '^open 00'"
        check "behind the busy window:  all 30 received, each ESR in the program's own task (none wrong)" "echo '$i' | grep -q '^end 30 esr 30 bad 0'"
    else
        check "NETBIOS there, the name added" "echo '$i' | grep -q '^nb 03' && echo '$i' | grep -q '^name 00 '"
        check "behind the busy window:  all 30 received, each POST in the program's own task (the 31st:  the cancelled receive's), none wrong" "echo '$i' | grep -q '^r 30 00 post 30' && echo '$i' | grep -q '^end 30 post 31 bad 0'"
    fi
    check "the busy window ran on, the menu answers" "[ \"\$(last $c T.TXT tick)\" -gt 20 ] && grep -q 'Switch Windows' '$d/menu.txt'"
    check "DOS works afterwards" "grep -q '^${c} end' '$d/end.txt'"
    ;;
mvlaunch)
    echo "== mvlaunch:  APP_START in MAXVIEW (demos/LAUNCH starts WORMS), its window with its DVP's settings"
    cfg=$OUT/MAXVIEW.CFG
    printf 'L|Launcher|C:\\LAUNCH.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:mvlaunch_end:30" run mvlaunch 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/LAUNCH.COM $ROOT/build/WORMS.COM $cfg" \
        "wait:Open_Program:60 key:ret wait:choose_a_demo:30 sleep:1 key:w sleep:5 $M key:s sleep:2 text:sw key:esc sleep:1 key:esc sleep:1 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_mvlaunch_end"
    d=$OUT/mvlaunch
    check "WORMS a window of its own, from LAUNCH (APP_START)" "grep -q 'Worms' '$d/sw.txt' && grep -q 'Launcher' '$d/sw.txt'"
    check "DOS works afterwards" "grep -q '^mvlaunch end' '$d/end.txt'"
    ;;
dossvc)
    echo "== dossvc:  DOS Services (MAXVFILE):  Mark by Name, Only Marked, Copy, Append, Type, Move, Erase, Sort, Make Directory"
    printf 'MD C:\\FT\r\nMD C:\\FT\\SUB\r\nECHO hello alpha> C:\\FT\\A.TXT\r\nECHO hello beta> C:\\FT\\B.TXT\r\nECHO data> C:\\FT\\C.DAT\r\nC:\\MAXVFILE /P:C:\\FT\r\nC:\r\nCD \\\r\nDIR /B C:\\FT > C:\\R1.TXT\r\nDIR /B C:\\FT\\SUB > C:\\R2.TXT\r\nECHO dossvc end\r\n' > "$OUT/DS.BAT"
    CMD="C:\\DS.BAT" END="wait:dossvc_end:60" run dossvc 0 "" "$OUT/DS.BAT $ROOT/build/MAXVFILE.EXE" \
        "wait:Commands:60 sleep:1 text:s0 key:n wait:Mark_by_Name:10 key:shift-8,dot,t,x,t,ret sleep:1 text:s1 key:o sleep:1 text:s2 key:o sleep:1 key:c wait:To_directory:10 key:s,u,b,ret sleep:2 text:s3 key:a wait:Append_to:10 key:a,l,l,dot,t,x,t,ret sleep:2 text:s4 key:u wait:Unmark_by_Name:10 key:shift-8,dot,shift-8,ret sleep:1 key:home,down,down sleep:1 key:t sleep:2 text:type key:esc sleep:1 key:end,up sleep:1 text:s5 key:m wait:To_directory:10 key:s,u,b,ret wait:Overwrite:10 text:ovr key:y sleep:2 text:s6 key:end sleep:1 key:e wait:Press_Y:10 key:y sleep:2 text:s7 key:s sleep:1 text:s8 key:shift-8 sleep:1 text:more key:m wait:Make_Directory:10 key:n,e,w,ret sleep:2 key:shift-8 sleep:1 key:esc sleep:3"
    d=$OUT/dossvc
    r1=$(file dossvc R1.TXT | tr '\n' ' '); r2=$(file dossvc R2.TXT | tr '\n' ' ')
    echo "  C:\\FT:  $r1  SUB:  $r2"
    check "the list:  name, size, date and time; the commands" "grep -q 'A.TXT .* [0-9]*-[0-9][0-9]-[0-9][0-9] *[0-9]*:[0-9][0-9][ap]' '$d/s0.txt' && grep -q 'Append *A' '$d/s0.txt' && grep -q 'More *\*' '$d/s0.txt'"
    check "Mark by Name *.TXT:  2 marked; Only Marked:  C.DAT not shown" "grep -q '2 marked' '$d/s1.txt' && grep -q 'A.TXT' '$d/s2.txt' && ! grep -q 'C.DAT' '$d/s2.txt'"
    check "Copy, Append of the marked files:  2 done each" "grep -q '2 done, 0 not' '$d/s3.txt' && grep -q '2 done, 0 not' '$d/s4.txt'"
    check "Type:  the file's text" "grep -q 'hello alpha' '$d/type.txt'"
    check "Move:  B.TXT there already, Overwrite asked" "grep -q 'Overwrite.*B.TXT' '$d/ovr.txt' && grep -q '1 done, 0 not' '$d/s6.txt'"
    check "Move B.TXT to SUB, Erase C.DAT, Make Directory NEW" "grep -q 'B.TXT' '$d/s5.txt' && echo '$r1' | grep -q NEW && ! echo '$r1' | grep -q 'B.TXT' && ! echo '$r1' | grep -q C.DAT && echo '$r2' | grep -q B.TXT && echo '$r2' | grep -q A.TXT"
    check "ALL.TXT:  A.TXT and B.TXT appended" "[ \"\$(file dossvc FT/ALL.TXT | tr '\n' ' ')\" = 'hello alpha hello beta ' ]"
    check "Sort:  by extension; More:  Change, Make, Remove Directory, the diskette programs" "grep -q 'by extension' '$d/s8.txt' && grep -q 'Change Dir' '$d/more.txt' && grep -q 'Format Disk' '$d/more.txt' && grep -q 'Restore' '$d/more.txt'"
    check "DOS works afterwards" "grep -q '^dossvc end' '$d/end.txt'"
    ;;
memstat)
    echo "== memstat:  Memory Status (MAXVMEM) in a window, DESQview's rows; less for new windows with another open"
    cfg=$OUT/MAXVIEW.CFG
    printf 'M|Memory Status|C:\\MAXVMEM.EXE||64|640\r\nD|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:memstat_end:30" run memstat 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/MAXVMEM.EXE $cfg" \
        "wait:Open_Program:60 key:ret wait:For_new_windows:30 sleep:2 text:ms1 key:esc wait:Open_Program:30 sleep:2 key:down key:ret sleep:5 $M key:o wait:Change_a_Program:20 key:m wait:For_new_windows:30 sleep:2 text:ms2 key:esc sleep:3 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_memstat_end"
    d=$OUT/memstat
    nw() { sed -n 's/.*For new windows: *\([0-9]*\) K.*/\1/p' "$d/$1.txt" | head -1; }
    grep -v '^ *$' "$d/ms1.txt" | sed -n '3,12p' | sed 's/^/  /'
    echo "  for new windows:  $(nw ms1) K, with a DOS window open:  $(nw ms2) K"
    check "DESQview's rows:  Common, Conventional, Expanded Memory, each total, available, largest" "grep -q 'Common Memory' '$d/ms1.txt' && grep -q 'Conventional Memory' '$d/ms1.txt' && grep -q 'Expanded Memory' '$d/ms1.txt' && grep -q 'Largest' '$d/ms1.txt'"
    check "for new windows:  less with another window open" "[ -n '$(nw ms1)' ] && [ -n '$(nw ms2)' ] && [ $(nw ms2 || echo 0) -lt $(nw ms1 || echo 0) ]"
    check "DOS works afterwards" "grep -q '^memstat end' '$d/end.txt'"
    ;;
video)
    echo "== video:  with MAXTEXT (Open 386MAX) the windows in its higher mode; Video Options"
    cfg=$OUT/MAXVIEW.CFG
    printf 'A|TickA|C:\\TICK.EXE C:\\TA.TXT||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    R="$M key:r wait:Tune_Performance:10"
    rows() { echo "mon:xp+/1xb+0x484>$1"; }
    CONFIG="DOS=HIGH,UMB|DEVICE=C:\\MAX\\386MAX.SYS|DEVICE=C:\\MAXTEXT.SYS|FILES=40|BUFFERS=20|SHELL=C:\\COMMAND.COM C:\\ /E:1024 /P" \
    CMD="C:\\MAXVIEW" END="wait:video_end:30" run video 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $TICK $cfg $MAXROOT/build/bin/MAXTEXT.SYS" \
        "wait:Open_Program:60 key:ret sleep:3 $R key:v wait:Text_modes:10 text:vid $(rows r0) key:1 sleep:3 $(rows r1) $R key:v wait:Text_modes:10 key:3 sleep:3 $(rows r1b) $R key:2 sleep:2 mon:xp+/8000xb+0xb8000>half $M key:z sleep:3 $(rows rz) key:alt wait:Switch_Windows:20 sleep:2 $(rows r2) key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:3 $(rows r3) type:echo_video_end"
    d=$OUT/video
    rv() { awk -F': ' '/^[0-9a-f]+:/ {print $2; exit}' "$d/$1.txt" 2>/dev/null | tr -dc '0-9a-fx'; }
    hc() { awk '/^[0-9a-f]+:/' "$d/half.txt" | grep -o "0x[0-9a-f][0-9a-f]" | sed -n "$((($1 * 80 + $2) * 2 + 1))p"; }
    echo "  rows (40:84):  $(rv r0) $(rv r1) $(rv r1b) zoomed $(rv rz) $(rv r2) launcher $(rv r3)"
    check "Video Options:  MAXTEXT's modes, its higher one (80 x 50 in QEMU) in use from the start" "grep -q 'Text modes (MAXTEXT)' '$d/vid.txt' && grep -q '80 x 50  \*' '$d/vid.txt' && grep -q '80 x 25 *1' '$d/vid.txt'"
    check "1:  the windows in 25 rows, 3:  in 50 again" "[ '$(rv r0) $(rv r1) $(rv r1b)' = '0x31 0x18 0x31' ]"
    check "Position 2 on 50 rows:  the bottom half (frame rows 26 / 49)" "[ '$(hc 26 0) $(hc 49 0) $(hc 49 79)' = '0xc9 0xc8 0xbc' ]"
    check "Zoom:  the program in its 25 rows, back:  50 again" "[ '$(rv rz) $(rv r2)' = '0x18 0x31' ]"
    check "the launcher in 25 rows again" "[ '$(rv r3)' = '0x18' ]"
    check "DOS works afterwards" "grep -q '^video end' '$d/end.txt'"
    ;;
mark)
    echo "== mark:  Mark in one DOS window, Transfer into another (every line + Enter, the first number)"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\nE|DosTwo|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    printf 'echo XFER-OK 4711> C:\\XF.TXT\r\necho LINE-TWO> C:\\X2.TXT\r\n' > "$OUT/SRC.TXT"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:mark_end:30" run mark 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $cfg $OUT/SRC.TXT" \
        "wait:Open_Program:60 key:ret sleep:4 type:cls sleep:1 type:type_C:\\SRC.TXT wait:LINE-TWO:20 $M text:main key:m wait:Mark_Begin:10 text:markmenu key:up,up,up,up,up,down,down,left,left,left,left key:b key:down,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right sleep:1 mon:xp+/4000xb+0xb8000>hl key:e sleep:1 text:ended key:ret sleep:1 $M key:o wait:Change_a_Program:20 key:e sleep:4 $M key:t wait:first_number:10 text:xmenu key:ret sleep:20 key:e,c,h,o,spc $M key:t wait:first_number:10 key:n sleep:3 type:_>_C:\\N.TXT sleep:3 text:after $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_mark_end"
    d=$OUT/mark
    hl=$(awk '/^[0-9a-f]+:/' "$d/hl.txt" | grep -o "0x[0-9a-f][0-9a-f]" | awk 'NR % 2 == 0 && $1 == "0x70"' | wc -l)
    echo "  cells shown marked (70h):  $hl; XF.TXT:  $(file mark XF.TXT); X2.TXT:  $(file mark X2.TXT); N.TXT:  $(file mark N.TXT)"
    check "the menu:  Mark M, Transfer T" "grep -q 'Mark *M' '$d/main.txt' && grep -q 'Transfer *T' '$d/main.txt'"
    check "Mark:  Begin B, More M, End after B, the Auto Dialer below" "grep -q 'Mark Begin *B' '$d/markmenu.txt' && grep -q 'Mark More *M' '$d/markmenu.txt' && ! grep -q 'Mark End *E' '$d/markmenu.txt' && grep -q 'Auto Dialer' '$d/markmenu.txt'"
    check "the marked text shown reversed (07h -> 70h, 30 cells and more)" "[ $hl -ge 30 ]"
    check "Mark End:  2 lines marked" "grep -q '2 line(s) marked' '$d/ended.txt'"
    check "Transfer:  T, N, any other key" "grep -q 'first line only *T' '$d/xmenu.txt' && grep -q 'first number only *N' '$d/xmenu.txt'"
    check "Transfer + Enter:  both lines typed and run in the other window, none lost" "[ '$(file mark XF.TXT)' = 'XFER-OK 4711' ] && [ '$(file mark X2.TXT)' = 'LINE-TWO' ]"
    check "Transfer N:  the first number typed" "file mark N.TXT | grep -q '^4711 *$'"
    check "DOS works afterwards" "grep -q '^mark end' '$d/end.txt'"
    ;;
help)
    echo "== help:  MaxView's own help (F1):  the topics, a page, back"
    cfg=$OUT/MAXVIEW.CFG
    printf 'A|TickA|C:\\TICK.EXE C:\\TA.TXT||64|640\r\n' > "$cfg"
    CMD="C:\\MAXVIEW" END="wait:help_end:30" run help 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $TICK $cfg" \
        "wait:Open_Program:60 key:ret sleep:3 key:alt wait:Switch_Windows:20 text:main key:f1 wait:About_MaxView:10 text:index key:r wait:Position_1-9:10 text:page key:down,down,down,down,down,down,down,down,down,down sleep:1 text:scrolled key:esc wait:About_MaxView:10 text:back key:esc wait:Switch_Windows:10 text:main2 key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_help_end"
    d=$OUT/help
    check "the menu:  Help F1" "grep -q 'Help *F1' '$d/main.txt'"
    check "F1:  the topics, each with its key" "grep -q 'Keys and Menus *K' '$d/index.txt' && grep -q 'Mark and Transfer *M' '$d/index.txt' && grep -q 'About MaxView *A' '$d/index.txt'"
    check "R:  the Rearrange page in a box with its hint" "grep -q 'Rearrange (R) changes the window in front' '$d/page.txt' && grep -q 'Help:  Up/Down' '$d/page.txt'"
    check "the page fits in 25 rows:  all of it shown, Down moves nothing" "grep -q 'while in front, the time slices' '$d/scrolled.txt' && grep -q 'Rearrange (R) changes the window' '$d/scrolled.txt'"
    check "Esc:  back to the topics, Esc:  the main menu" "! grep -q 'Position 1-9' '$d/back.txt' && grep -q 'Open Window *O' '$d/main2.txt'"
    check "DOS works afterwards" "grep -q '^help end' '$d/end.txt'"
    ;;
catalog)
    echo "== catalog:  Open Window's Add, Change, Delete a Program (MAXVIEW.CFG)"
    cfg=$OUT/MAXVIEW.CFG
    printf 'A|TickA|C:\\TICK.EXE C:\\TA.TXT||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:catalog_end:30" run catalog 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $TICK $cfg" \
        "wait:Open_Program:60 key:ret sleep:3 $M key:o wait:Add_a_Program:10 text:open key:f2 wait:Memory_(KB):10 key:ret sleep:1 text:formerr key:b,tab,t,i,c,k,b,tab key:shift-c,shift-semicolon,backslash,t,i,c,k,dot,e,x,e,spc,shift-c,shift-semicolon,backslash,t,b,dot,t,x,t key:tab,tab,1,2,8,tab,9,tab,4,0,tab,4,tab,2,tab,9,tab,4,0,tab,n,tab,n,tab,n,tab,y,tab,y sleep:1 text:form key:ret sleep:2 text:saved $M key:o wait:Add_a_Program:10 text:open2 key:b sleep:4 $M key:o wait:Add_a_Program:10 key:f3 wait:Change_which:10 key:b wait:Memory_(KB):10 text:change key:backspace,backspace,backspace,backspace,backspace,t,i,c,k,e,r,ret sleep:2 $M key:o wait:Add_a_Program:10 key:f4 wait:Delete_which:10 key:a wait:Are_you_sure:10 text:delconf key:y sleep:2 text:deleted $M key:o wait:Add_a_Program:10 text:open3 key:esc sleep:1 key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_catalog_end"
    d=$OUT/catalog
    echo "  MAXVIEW.CFG:  $(file catalog MAXVIEW.CFG | tr '\n' ' ')"
    check "Open Window:  Add F2, Change F3, Delete F4" "grep -q 'Add a Program *F2' '$d/open.txt' && grep -q 'Change a Program *F3' '$d/open.txt' && grep -q 'Delete a Program *F4' '$d/open.txt'"
    check "Add:  an empty form is refused with its reason" "grep -q 'Key, Title and Program are needed' '$d/formerr.txt'"
    check "Add:  the form filled in, kept" "grep -q 'tickb' '$d/form.txt' && grep -q 'tickb kept in MAXVIEW.CFG' '$d/saved.txt'"
    check "the new program in Open Window, started from it (TB.TXT counts)" "grep -q 'tickb *B' '$d/open2.txt' && [ $(last catalog TB.TXT tick) -gt 0 ]"
    check "Change:  the form with its values" "grep -q 'tickb' '$d/change.txt' && grep -q '128' '$d/change.txt' && grep -q 'tb.txt' '$d/change.txt'"
    check "Delete:  asked first, then gone from Open Window" "grep -q 'TickA' '$d/delconf.txt' && grep -q 'TickA deleted' '$d/deleted.txt' && ! grep -q 'TickA *A' '$d/open3.txt' && grep -q 'ticker *B' '$d/open3.txt'"
    check "Swap out N, Close on exit N, Allow Close Window N, Runs in background Y, Share CPU Y:  in the form, shown again by Change" "for f in form change; do grep -q 'Swap out *N' \$d/\$f.txt && grep -q 'Close on exit *N' \$d/\$f.txt && grep -q 'Close Window *N' \$d/\$f.txt && grep -q 'In background *Y' \$d/\$f.txt && grep -q 'Share CPU *Y' \$d/\$f.txt || exit 1; done"
    check "the window's numbers in the form (start 9 x 40 at 4,2, maximum 9 x 40), shown again by Change" "for f in form change; do grep -q 'Start window *Height  *9  *Width  *40  *Row  *4  *Column  *2' \$d/\$f.txt && grep -q 'Maximum *Height  *9  *Width  *40' \$d/\$f.txt || exit 1; done"
    check "MAXVIEW.CFG:  only the changed program, its profile as DESQview 2.80 writes these (16Fh A0h, 184h 30h, 18Bh 0Fh, 17Ch 0)" "[ \"$(file catalog MAXVIEW.CFG | grep -v '^#')\" = 'B|ticker|C:\\tick.exe C:\\tb.txt||64|128|1|2|0|0|0|0|0|9|40|0|0|0|0|160|0|48|15|4|2|9|40|2' ]"
    check "DOS works afterwards" "grep -q '^catalog end' '$d/end.txt'"
    ;;
mrs)
    echo "== mrs:  Rearrange's Move / Resize / Scroll box, switching between them"
    cfg=$OUT/MAXVIEW.CFG
    printf 'A|TickA|C:\\TICK.EXE C:\\TA.TXT||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:mrs_end:30" run mrs 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $TICK $cfg" \
        "wait:Open_Program:60 key:ret sleep:3 $M text:before key:r wait:Tune_Performance:10 key:m wait:Move:__arrows:10 text:move key:right,right,right,down,down sleep:1 text:moved key:r wait:Resize:__arrows:10 text:resize key:right,right sleep:1 text:resized key:s wait:Scroll:__arrows:10 key:ret sleep:1 text:done $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_mrs_end"
    d=$OUT/mrs
    fr() { grep -n 'TickA' "$d/$1.txt" | head -1 | awk -F: '{print $1 ":" index($0, "TickA")}'; }
    echo "  title before $(fr before), moved $(fr moved)"
    check "Move:  the box (Move, Resize, Scroll, Done) with the hint" "grep -q 'Resize *R' '$d/move.txt' && grep -q 'Scroll *S' '$d/move.txt' && grep -q 'Done *Enter' '$d/move.txt' && grep -q 'R resize, S scroll' '$d/move.txt'"
    check "Move:  the window 2 down, 3 right" "[ '$(fr moved)' != '$(fr before)' ]"
    check "R:  resizing from there, S:  scrolling" "grep -q 'M move, S scroll' '$d/resize.txt'"
    check "Enter:  done, back in the window (no box, no hint)" "! grep -q 'Done *Enter' '$d/done.txt' && ! grep -q 'arrows;' '$d/done.txt' && grep -q 'TickA' '$d/done.txt'"
    check "DOS works afterwards" "grep -q '^mrs end' '$d/end.txt'"
    ;;
learn)
    echo "== learn:  Learn (Shift+Alt):  a script learned on F6, played twice, listed, saved"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    L="key:shift-alt wait:Display_Scripts:10"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:learn_end:30" run learn 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $cfg" \
        "wait:Open_Program:60 key:ret sleep:4 $L text:l0 key:equal wait:press_the_key:10 key:f6 wait:its_name:10 key:h,i sleep:1 text:l1 key:ret sleep:2 type:echo_learned>>C:\\L.TXT sleep:2 $L text:l2 key:minus sleep:2 text:l3 key:f6 sleep:4 key:f6 sleep:4 text:l4 $L key:d wait:Scripts:10 text:list key:esc sleep:1 $L key:s sleep:2 text:saved key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_learn_end"
    d=$OUT/learn
    echo "  L.TXT:  $(file learn L.TXT | tr '\n' ' ')"
    check "Shift+Alt:  Learn, not learning; Start Script =, Display D, Load L" "grep -q 'Not learning' '$d/l0.txt' && grep -q 'Start Script *=' '$d/l0.txt' && grep -q 'Display Scripts *D' '$d/l0.txt' && ! grep -q 'Finish Script *-' '$d/l0.txt'"
    check "Start Script:  its key, its name" "grep -q 'Script on F6, its name:  hi' '$d/l1.txt'"
    check "while learning:  Learning F6, Finish -, Cancel C" "grep -q 'Learning:  F6' '$d/l2.txt' && grep -q 'Finish Script *-' '$d/l2.txt' && grep -q 'Cancel Script *C' '$d/l2.txt'"
    check "Finish:  23 keys on F6" "grep -q 'Script hi:  23 keys on F6' '$d/l3.txt'"
    check "F6 twice:  the script typed and run twice, F6 itself not given to the program" "[ \"$(file learn L.TXT | grep -c '^learned')\" = 3 ] && ! grep -q '\\^Z' '$d/l4.txt'"
    check "Display Scripts:  hi on F6" "grep -q 'hi *F6' '$d/list.txt'"
    check "Save Scripts:  MAXVIEW.SCR" "grep -q '1 script(s) saved in MAXVIEW.SCR' '$d/saved.txt' && mtype -i '$d/test.img@@32256' ::/MAXVIEW.SCR | grep -q MVSCR1"
    check "DOS works afterwards" "grep -q '^learn end' '$d/end.txt'"
    ;;
lpause)
    echo "== lpause:  Learn's Fixed-Size Pause, Variable Pause and Time Delay"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    L="key:shift-alt wait:Display_Scripts:10"
    M="key:alt wait:Switch_Windows:20"
    S="$L key:equal wait:press_the_key:10"
    CMD="C:\\MAXVIEW" END="wait:lpause_end:30" run lpause 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $cfg" \
        "wait:Open_Program:60 key:ret sleep:4 type:cls sleep:1 $S key:f7 wait:its_name:10 key:ret sleep:2 key:e,c,h,o,spc sleep:1 $L key:f sleep:2 key:a,b sleep:1 $L text:fixed key:f sleep:2 type:_>>C:\\P.TXT sleep:2 $L key:minus sleep:2 $S key:f8 wait:its_name:10 key:ret sleep:2 key:e,c,h,o,spc sleep:1 $L key:v sleep:2 key:q sleep:1 $L text:var key:v sleep:2 $L key:t wait:Time_Delay:10 key:backspace,3 sleep:1 text:delay key:ret sleep:2 type:_>>C:\\P.TXT sleep:2 $L key:minus sleep:2 type:cls sleep:2 key:f7 sleep:3 text:f1 key:z,y sleep:3 text:f2 type:cls sleep:2 key:f8 sleep:3 key:u,v sleep:1 key:ret sleep:1 text:v1 sleep:6 text:v2 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_lpause_end"
    d=$OUT/lpause
    echo "  P.TXT:  $(file lpause P.TXT | tr '\r\n' '| ')"
    check "Fixed-Size Pause:  in fixed pause, F ends it, Finish not offered" "grep -q 'In fixed pause' '$d/fixed.txt' && grep -q 'Fixed-Size Pause *F' '$d/fixed.txt' && ! grep -q 'Finish Script *-' '$d/fixed.txt' && ! grep -q 'Variable Pause *V' '$d/fixed.txt'"
    check "Variable Pause:  in variable pause, V ends it" "grep -q 'In variable pause' '$d/var.txt' && grep -q 'Variable Pause *V' '$d/var.txt' && ! grep -q 'Fixed-Size Pause *F' '$d/var.txt'"
    check "Time Delay:  the seconds asked for" "grep -q 'Time Delay, in seconds (1-255):  3_' '$d/delay.txt'"
    check "F7:  the script stops at the fixed pause" "grep -q '^ *C:.>echo *$' '$d/f1.txt'"
    check "F7:  two keys of the user's, then on" "grep -q '^ *C:.>echo zy >>C:.P.TXT' '$d/f2.txt'"
    check "F8:  the user's keys until Enter, Enter taken, then the delay" "grep -q '^ *C:.>echo uv *$' '$d/v1.txt'"
    check "F8:  after the delay on" "grep -q '^ *C:.>echo uv >>C:.P.TXT' '$d/v2.txt'"
    check "P.TXT:  ab, q (learning), zy, uv (playing)" "[ \"$(file lpause P.TXT | tr -d '\r ' | tr '\n' ,)\" = 'ab,q,zy,uv,' ]"
    check "DOS works afterwards" "grep -q '^lpause end' '$d/end.txt'"
    ;;
dial)
    echo "== dial:  Mark's Auto Dialer:  Mark Phone #, Dial (local, access code), Talk on COM1"
    cfg=$OUT/MAXVIEW.CFG; set=$OUT/MAXVSET.INI
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    { cat "$ROOT/MAXVSET.INI"; printf 'MODEM_PORT=1\nACCESS1=9,\n'; } | sed 's/$/\r/' > "$set"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:dial_end:30" run dial 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $cfg $set" \
        "wait:Open_Program:60 key:ret sleep:4 type:cls sleep:1 type:echo_555-1234 sleep:2 $M key:m wait:Mark_Begin:10 text:menu key:p sleep:1 text:none key:up,up key:p sleep:1 text:marked key:d wait:Access_Code_1:10 text:dialmenu key:1 sleep:2 text:dialed key:d wait:Access_Code_1:10 key:l sleep:2 key:t sleep:2 text:talk key:esc sleep:1 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_dial_end"
    d=$OUT/dial
    com=$(tr '\r' '|' < "$OUT/dial.com1" 2>/dev/null | tr -d '\0')
    echo "  COM1:  $com"
    check "Mark:  Auto Dialer with Mark Phone # P, Talk T; Dial not before a number" "grep -q 'Mark Phone # *P' '$d/menu.txt' && grep -q 'Talk *T' '$d/menu.txt' && ! grep -q 'Dial *D' '$d/menu.txt'"
    check "P on a blank:  no phone number" "grep -q 'No phone # under the cursor' '$d/none.txt'"
    check "P on the number:  555-1234 marked, Dial D" "grep -q 'Phone # 555-1234 marked' '$d/marked.txt' && grep -q 'Dial *D' '$d/marked.txt'"
    check "Dial:  Local L, Access Code 1 with its key, 2 and 3 without" "grep -q 'Local *L' '$d/dialmenu.txt' && grep -q 'Access Code 1 *1' '$d/dialmenu.txt' && ! grep -q 'Access Code 2 *2' '$d/dialmenu.txt'"
    check "Dialing shown" "grep -q 'Dialing 555-1234 on COM1' '$d/dialed.txt'"
    check "COM1:  ATDT9,5551234; then ATDT5551234; then ATZ" "[ '$com' = 'ATDT9,5551234;|ATDT5551234;|ATZ|' ]"
    check "Talk shown" "grep -q 'the modem has hung up' '$d/talk.txt'"
    check "DOS works afterwards" "grep -q '^dial end' '$d/end.txt'"
    ;;
scis)
    echo "== scis:  window notifications and Scissors (NTFPRB asks for 40h-51h)"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:scis_end:30" run scis 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/NTFPRB.COM $cfg" \
        "wait:Open_Program:60 key:ret sleep:4 type:C:\\NTFPRB_C:\\N1.TXT_R wait:ntfprb_ready:30 sleep:1 $M text:menu key:x wait:Paste:10 text:scis key:c wait:Mark_Begin:10 key:down,down,right,right key:b key:right,right,down sleep:1 text:marking key:e sleep:2 text:copied $M text:menu2 key:x wait:Paste:10 key:u wait:Mark_Begin:10 key:b,right key:e sleep:2 key:x sleep:3 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:20 sleep:2 type:echo_scis_end"
    d=$OUT/scis
    n1=$(file scis N1.TXT)
    echo "$n1" | sed 's/^/  /'
    win=$(echo "$n1" | sed -n 's/^win \(....\):\(....\)$/\2 \1/p')
    h=$(echo "$win" | awk '{print substr($1,3,2)" "substr($1,1,2)" "substr($2,3,2)" "substr($2,1,2)}')
    check "a window asking for Cut, Copy, Paste:  Scissors X in the menu" "grep -q 'Scissors *X' '$d/menu.txt'"
    check "Scissors:  Copy C, Cut U, Paste without a key" "grep -q 'Copy *C' '$d/scis.txt' && grep -q 'Cut *U' '$d/scis.txt' && ! grep -q 'Paste *P' '$d/scis.txt'"
    check "Copy:  Mark Begin B, Mark End E after it, the hint" "grep -q 'Mark End *E' '$d/marking.txt' && grep -q 'B begin, E end (to the program)' '$d/marking.txt'"
    check "Copy told:  2 x 3" "grep -q 'Copy:  2 x 3 to the program' '$d/copied.txt'"
    check "the DESQ key (50h) and its end (51h), as 1-byte messages in the own mailbox" "echo \"\$n1\" | grep -q '^  a 50' && echo \"\$n1\" | grep -q '^  a 51'"
    check "Copy:  4Eh, the window's handle ($h), row 2, column 2, 2 rows, 3 columns (14 bytes)" "echo \"\$n1\" | grep -A1 '0000:000E' | grep -q '^  a 4E $h 02 02 00 00 00 .. .. 02 03'"
    check "its DWORD a window of 2 x 3 holding the area:  READ gives its first row, cro (3 bytes, as DESQview 2.80)" "echo \"\$n1\" | grep -A2 '^  a 4E' | grep -q '^  r 8 0000:0003 ' && echo \"\$n1\" | grep -q '^  t 63 72 6F '"
    check "Cut:  4Dh, row 0, column 0, 1 row, 2 columns" "echo \"\$n1\" | grep -q '^  a 4D $h 00 00 00 .. .. .. .. 01 02' && echo \"\$n1\" | grep -A2 '^  a 4D' | grep -q '^  r 8 0000:0002 '"
    check "the messages come from the own mailbox (HANDLE 03h)" "m=\$(echo \"\$n1\" | sed -n 's/^mbx //p'); [ -n \"\$m\" ] && echo \"\$n1\" | grep -q \"^q \$m\""
    check "the program read its x and ended, DOS works afterwards" "grep -q '^scis end' '$d/end.txt'"
    ;;
paste)
    echo "== paste:  Mark, then Scissors Paste into a program asking for 4Fh (NTFPRB C)"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:paste_end:30" run paste 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/NTFPRB.COM $cfg" \
        "wait:Open_Program:60 key:ret sleep:4 type:cls sleep:1 type:echo_HELLOWORLD sleep:2 $M key:m wait:Mark_Begin:10 key:up,up,left,left,left,left key:b key:right,right,right,right key:e sleep:1 key:ret sleep:1 $M key:x sleep:1 text:nopaste key:o wait:Change_a_Program:20 key:d sleep:5 type:C:\\NTFPRB_C:\\N2.TXT_C wait:ntfprb_ready:30 sleep:1 $M key:x wait:Paste:10 text:scis key:p sleep:2 text:paste key:down,right sleep:1 text:moved key:ret sleep:3 text:done key:x sleep:3 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_paste_end"
    d=$OUT/paste
    n2=$(file paste N2.TXT)
    echo "$n2" | grep '^  [art]' | sed 's/^/  /'
    check "a DOS window:  Scissors without a key; a program asking for 4Fh after a Mark:  Paste P" "grep -q 'Scissors' '$d/nopaste.txt' && ! grep -q 'Scissors *X' '$d/nopaste.txt' && grep -q 'Paste *P' '$d/scis.txt'"
    check "the block placed from the top left, the arrows move it" "grep -q 'HELLO' '$d/paste.txt' && grep -q 'Paste:  arrows' '$d/moved.txt'"
    check "Enter:  4Fh (14 bytes), row 1, column 1, a window, 1 x 5" "echo \"\$n2\" | grep -B1 '^  a 4F' | grep -q '0000:000E' && echo \"\$n2\" | grep -q '^  a 4F 00 00 .. .. 01 01 00 00 00 .. .. 01 05'"
    check "READ of that window:  its 5 characters (as DESQview 2.80)" "echo \"\$n2\" | grep -q '^  r 8 0000:0005 ' && echo \"\$n2\" | grep -q '^  t 48 45 4C 4C 4F'"
    check "DOS works afterwards" "grep -q '^paste end' '$d/end.txt'"
    ;;
ntf)
    echo "== ntf:  notifications of move, resize, help, front and back, hide, close (NTFPRB)"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    R="$M key:r wait:Tune_Performance:10"
    CMD="C:\\MAXVIEW" END="wait:ntf_end:30" run ntf 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/NTFPRB.COM $cfg $(oldwin)" \
        "wait:Open_Program:60 key:ret sleep:4 type:C:\\NTFPRB_C:\\N1.TXT wait:ntfprb_ready:30 sleep:1 $M text:menu $R key:m key:right,down sleep:1 key:ret sleep:2 $R key:r key:left,up sleep:1 key:ret sleep:2 $R key:s key:right,right,left,down,up sleep:1 key:ret sleep:2 text:scroll $M key:f1 sleep:2 text:phelp $M key:o wait:Change_a_Program:20 key:d sleep:5 $M key:s sleep:1 key:1 sleep:2 $R key:h sleep:2 $M key:s sleep:1 key:1 sleep:2 $M text:menuq key:q sleep:1 key:c wait:Are_you_sure:10 key:y sleep:2 text:closed key:x sleep:3 $M text:menuq2 key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_ntf_end"
    d=$OUT/ntf
    n1=$(file ntf N1.TXT)
    msgs=$(echo "$n1" | grep '^  a ' | cut -c5-)
    echo "$msgs" | sed 's/^/  /'
    win=$(echo "$n1" | sed -n 's/^win \(....\):\(....\)$/\2 \1/p')
    h=$(echo "$win" | awk '{print substr($1,3,2)" "substr($1,1,2)" "substr($2,3,2)" "substr($2,1,2)}')
    ev() { echo "$msgs" | grep "^$1 $h" | head -1 | cut -d' ' -f6-7; }
    l() { echo "$n1" | grep -B1 "^  a $1" | head -1 | awk '{print $2}'; }
    check "Help for Program F1 in the menu of a program asking for Help; Quit without its key (Close asked)" "grep -q 'Help for Program *F1' '$d/menu.txt' && ! grep -q 'Quit MaxView *Q' '$d/menu.txt'"
    check "Move right:  40h (7 bytes), its row and column" "[ \"\$(l 40)\" = 0000:0007 ] && [ -n \"\$(ev 40)\" ]"
    check "Move down:  41h, the row one more than 40h's, the same column" "(set -- \$(ev 40) \$(ev 41); [ \$((0x\$3)) = \$((0x\$1 + 1)) ] && [ \$2 = \$4 ])"
    check "Resize narrower:  42h (7 bytes), then lower:  43h with a row less" "[ \"\$(l 42)\" = 0000:0007 ] && (set -- \$(ev 42) \$(ev 43); [ \$((0x\$3)) = \$((0x\$1 - 1)) ] && [ \$2 = \$4 ])"
    check "Scroll:  per arrow 44h (right, left) / 45h (down, up), 9 bytes, 00 00 00 and the step 01h / FFh; the view stays" "[ \"\$(l 44)\" = 0000:0009 ] && [ \"\$(echo \"\$msgs\" | grep '^4[45] $h' | cut -d' ' -f1,6-9 | tr '\\n' '|')\" = '44 00 00 00 01|44 00 00 00 01|44 00 00 00 FF|45 00 00 00 01|45 00 00 00 FF|' ] && grep -q 'ntfprb ready' '$d/scroll.txt'"
    check "F1:  48h (8 bytes) to the program, MaxView's help not shown" "[ \"\$(l 48)\" = 0000:0008 ] && echo \"\$msgs\" | grep -q '^48 $h 00 00 00' && ! grep -q 'Keys and Menus' '$d/phelp.txt'"
    check "another window in front:  4Bh, back in front:  4Ah, Hide:  47h (1 byte each)" "echo \"\$msgs\" | grep -q '^4B' && echo \"\$msgs\" | grep -q '^4A' && echo \"\$msgs\" | grep -q '^47' && [ \"\$(l 47)\" = 0000:0001 ]"
    check "Close Yes:  46h (8 bytes), the program told, its window kept" "[ \"\$(l 46)\" = 0000:0008 ] && echo \"\$msgs\" | grep -q '^46 $h 00 00 00' && grep -q 'is told to close' '$d/closed.txt' && grep -q 'ntfprb ready' '$d/closed.txt'"
    check "the program ended itself (x):  its notifications gone, Quit Q again" "grep -q 'Quit MaxView *Q' '$d/menuq2.txt' && ! grep -q 'Help for Program' '$d/menuq2.txt'"
    check "DOS works afterwards" "grep -q '^ntf end' '$d/end.txt'"
    ;;
vntf)
    echo "== vntf:  Video Options sends 4Ch (NTFPRB, MAXTEXT)"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    R="$M key:r wait:Tune_Performance:10"
    CONFIG="DOS=HIGH,UMB|DEVICE=C:\\MAX\\386MAX.SYS|DEVICE=C:\\MAXTEXT.SYS|FILES=40|BUFFERS=20|SHELL=C:\\COMMAND.COM C:\\ /E:1024 /P" \
    CMD="C:\\MAXVIEW" END="wait:vntf_end:30" run vntf 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/NTFPRB.COM $cfg $MAXROOT/build/bin/MAXTEXT.SYS" \
        "wait:Open_Program:60 key:ret sleep:4 type:C:\\NTFPRB_C:\\N1.TXT wait:ntfprb_ready:30 sleep:1 $R key:v wait:Text_modes:10 key:1 sleep:3 $R key:v wait:Text_modes:10 key:3 sleep:3 key:esc sleep:1 key:x sleep:3 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:3 type:echo_vntf_end"
    d=$OUT/vntf
    n1=$(file vntf N1.TXT)
    msgs=$(echo "$n1" | grep '^  a ' | cut -c5-)
    echo "$msgs" | sed 's/^/  /'
    check "two text mode changes:  4Ch 03h (2 bytes) three times each" "[ \"\$(echo \"\$msgs\" | grep -c '^4C 03')\" = 6 ] && [ \"\$(echo \"\$n1\" | grep -B1 '^  a 4C' | awk '\$2 == \"0000:0002\"' | wc -l)\" = 6 ]"
    check "DOS works afterwards" "grep -q '^vntf end' '$d/end.txt'"
    ;;
alw)
    echo "== alw:  a program disallows menu functions (ALWPRB, manager stream 20h-33h)"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    CMD="C:\\MAXVIEW" END="wait:alw_end:30" run alw 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/ALWPRB.COM $cfg" \
        "wait:Open_Program:60 key:ret sleep:4 type:C:\\ALWPRB_20_21_22_23_24_25_26_27_28_2E_31_32_33 wait:alwprb_ready:30 sleep:1 $M text:menu key:o sleep:1 key:c sleep:1 text:menuo key:r wait:Tune_Performance:10 text:rear key:m sleep:1 key:1 sleep:1 text:rearm key:esc sleep:1 key:esc sleep:1 key:x sleep:2 $M text:menu2 key:esc sleep:1 type:C:\\ALWPRB_30 wait:alwprb_ready:30 sleep:1 key:alt sleep:2 text:nomenu key:x sleep:2 $M text:menu3 key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:2 type:echo_alw_end"
    d=$OUT/alw
    check "disallowed (20h-28h, 2Eh, 31h-33h):  Open, Switch, Close, Zoom, Mark, Quit without their keys; Rearrange and Scissors stay" "! grep -q 'Open Window *O' '$d/menu.txt' && ! grep -q 'Switch Windows *S' '$d/menu.txt' && ! grep -q 'Close Window *C' '$d/menu.txt' && ! grep -q 'Zoom *Z' '$d/menu.txt' && ! grep -q 'Mark *M' '$d/menu.txt' && ! grep -q 'Quit MaxView *Q' '$d/menu.txt' && grep -q 'Rearrange *R' '$d/menu.txt'"
    check "O and C do nothing (the main menu stays)" "grep -q 'Rearrange *R' '$d/menuo.txt' && ! grep -q 'Are you sure' '$d/menuo.txt' && ! grep -q 'Add a Program' '$d/menuo.txt'"
    check "Rearrange:  Move, Resize, Scroll, Position, Freeze, Hide, Put Aside without keys, Change Colors stays" "! grep -q 'Move *M' '$d/rear.txt' && ! grep -q 'Resize *R' '$d/rear.txt' && ! grep -q 'Scroll *S' '$d/rear.txt' && ! grep -q 'Position *1-9' '$d/rear.txt' && ! grep -q 'Freeze *F' '$d/rear.txt' && ! grep -q 'Hide *H' '$d/rear.txt' && ! grep -q 'Put Aside *P' '$d/rear.txt' && grep -q 'Change Colors *C' '$d/rear.txt' && grep -q 'Tune Performance' '$d/rearm.txt'"
    check "the program ended:  its functions allowed again" "grep -q 'Open Window *O' '$d/menu2.txt' && grep -q 'Quit MaxView *Q' '$d/menu2.txt' && grep -q 'Zoom *Z' '$d/menu2.txt'"
    check "30h:  the DESQ key opens no menu, the program keeps the keyboard" "! grep -q 'Switch Windows' '$d/nomenu.txt' && grep -q 'Switch Windows *S' '$d/menu3.txt'"
    check "DOS works afterwards" "grep -q '^alw end' '$d/end.txt'"
    ;;
swap)
    echo "== swap:  a window put aside swapped out when memory runs out, back when switched to"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    R="$M key:r wait:Tune_Performance:10"
    OPN="$M key:o wait:Change_a_Program:20 key:d sleep:6"
    MEMSIZE=${SWAPMEM:-4} CMD="C:\\MAXVIEW" END="wait:swap_end:60" run swap 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $cfg" \
        "wait:Open_Program:60 key:ret sleep:4 type:cd_DOS sleep:1 $R key:p sleep:2 $OPN $OPN $OPN $OPN $OPN $OPN text:w7 type:cls sleep:1 type:dir_C:\\MVSWAP*.TMP sleep:3 text:dir7 $R key:p sleep:2 $M key:s sleep:1 key:1 sleep:8 text:back1 type:cls sleep:1 type:cd>C:\\S.TXT sleep:2 type:dir_C:\\MVSWAP*.TMP sleep:3 text:dir1 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:90 sleep:2 type:echo_swap_end"
    d=$OUT/swap
    echo "  S.TXT:  $(file swap S.TXT | tr -d '\r' | tr '\n' ' ')"
    check "7 windows in 4 MB:  window 1 (put aside) swapped out for them" "grep -q 'MVSWAP01 TMP' '$d/dir7.txt' && ! grep -q 'QPI\\|memory' '$d/w7.txt'"
    check "window 7 put aside, window 1 switched to:  7 out, 1 back" "grep -q 'MVSWAP07 TMP' '$d/dir1.txt' && ! grep -q 'MVSWAP01 TMP' '$d/dir1.txt' && ! grep -q 'Not enough memory' '$d/back1.txt'"
    check "window 1's memory came back:  its directory (C:\\DOS)" "file swap S.TXT | grep -q '^C:.DOS'"
    check "Quit:  all closed, the swapped out one too, no swap file left" "grep -q '^swap end' '$d/end.txt' && ! mdir -b -i '$d/test.img@@32256' '::/MVSWAP*.TMP' >/dev/null 2>&1"
    ;;
noswap)
    echo "== noswap:  a program whose DVP says Can be swapped out N is not swapped out"
    cfg=$OUT/MAXVIEW.CFG
    printf 'N|NoSwap|C:\\COMMAND.COM||64|640|1|2|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0\r\nD|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    M="key:alt wait:Switch_Windows:20"
    R="$M key:r wait:Tune_Performance:10"
    OPN="$M key:o wait:Change_a_Program:20 key:d sleep:6"
    MEMSIZE=${SWAPMEM:-4} CMD="C:\\MAXVIEW" END="wait:noswap_end:60" run noswap 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $cfg" \
        "wait:Open_Program:60 key:ret sleep:4 $R key:p sleep:2 $OPN $OPN $OPN $OPN $OPN $OPN text:w7 key:esc sleep:2 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:90 sleep:2 type:echo_noswap_end"
    d=$OUT/noswap
    check "window 1 (NoSwap) put aside stays in memory:  the 7th window refused for want of memory (swap:  the same steps open it)" "grep -q 'QPI memory' '$d/w7.txt'"
    check "Quit:  all closed" "grep -q '^noswap end' '$d/end.txt'"
    ;;
dvapi)
    echo "== dvapi:  DESQview scheduling calls per task"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 40 C:\\DVTASK.COM A C:\\D1.TXT ; C:\\DVTASK.COM B C:\\D2.TXT\r\n' > "$OUT/D.BAT"
    CMD="C:\\D.BAT" run dvapi 40 "" \
        "$OUT/D.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/DVTASK.COM"
    d1=$(file dvapi D1.TXT); d2=$(file dvapi D2.TXT)
    echo "$d1" | sed 's/^/  D1: /'; echo "$d2" | sed 's/^/  D2: /'
    set -- $(echo "$d1" | awk '$1 == "crit" {print $2, $3, $4}') x x x
    c0=$1 c1=$2 c2=$3
    set -- $(echo "$d1" | awk '$1 == "pause" {print $2, $3}') x x
    p1=$1 p2=$2
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/dvapi/end.txt'"
    check "DESQview API present" "echo '$d1' | grep -q 'dv 0250'"
    check "APPNUM:  task 1 and 2" "echo '$d1' | grep -q '^app 1 ' && echo '$d2' | grep -q '^app 2 '"
    check "BEGINC..ENDC:  no other task" "[ '$c0' = '$c1' ] && [ '$c0' != x ]"
    check "after ENDC the other task runs" "[ '$c2' != x ] && [ $c2 -gt $c1 ]"
    check "40:F0h per task (as DESQview)" "echo '$d1' | grep -q '^ica own'"
    check "MAXVTSR state per task (error policy)" "echo '$d1' | grep -q '^err own'"
    check "PAUSE leaves the CPU (\$p2 > 3/2 \$p1)" "[ '$p2' != x ] && [ $p1 -gt 0 ] && [ $((p2 * 2)) -gt $((p1 * 3)) ]"
    ;;
cwd)
    echo "== cwd:  current directory per task"
    printf 'MD C:\\A\r\nMD C:\\B\r\nC:\\MVRUN 25 C:\\CWDPROBE.COM \\A C:\\W1.TXT ; C:\\CWDPROBE.COM \\B C:\\W2.TXT\r\n' > "$OUT/C.BAT"
    CMD="C:\\C.BAT" run cwd 25 "" "$OUT/C.BAT $ROOT/build/CWDPROBE.COM"
    w1=$(file cwd W1.TXT); w2=$(file cwd W2.TXT)
    echo "  W1 '$w1', W2 '$w2'"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/cwd/end.txt'"
    check "task 1 keeps C:\\A" "[ '$w1' = 'cwd A ok' ]"
    check "task 2 keeps C:\\B" "[ '$w2' = 'cwd B ok' ]"
    check "MVRUN's directory unchanged" "grep -q '^cwd C:\\\\ *$' '$OUT/cwd/end.txt'"
    ;;
ems)
    echo "== ems:  EMS page frame per task"
    run ems 25 "C:\\EMSPROBE.COM C:\\E1.TXT A ; C:\\EMSPROBE.COM C:\\E2.TXT B" "$ROOT/build/EMSPROBE.COM"
    e1=$(file ems E1.TXT); e2=$(file ems E2.TXT)
    echo "  E1 '$e1', E2 '$e2'"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/ems/end.txt'"
    check "task 1 keeps its EMS pages" "[ \"\$(echo \$e1)\" = 'ems A ok' ]"
    check "task 2 keeps its EMS pages" "[ \"\$(echo \$e2)\" = 'ems B ok' ]"
    ;;
gfx)
    echo "== gfx:  video modes per task"
    FG="/F1 " run gfx 45 "C:\\GFXPROBE.COM C:\\G1.TXT ; C:\\KEYPROBE.COM C:\\K2.TXT D" \
        "$ROOT/build/GFXPROBE.COM $ROOT/build/KEYPROBE.COM" \
        "sleep:6 shot:gfx1 key:ctrl-alt-2 wait:keyprobe_D_ready:20 text:fg2 sleep:6 key:ctrl-alt-1 sleep:4 shot:gfx3 key:dot sleep:4 key:ctrl-alt-2 sleep:2 key:dot"
    g1=$(file gfx G1.TXT); d=$OUT/gfx
    echo "  G1 '$g1'"
    green() {   # share of colour 2 (0,170,0) in a screendump, percent
        python3 -c "
import sys
from PIL import Image
im=Image.open(sys.argv[1]).convert('RGB'); w,h=im.size
n=sum(c for c,(r,g,b) in im.getcolors(w*h) if r<40 and g>150 and b<40)
print(n*100//(w*h))" "$1" 2>/dev/null || echo 0
    }
    echo "  green: $(green $d/gfx1.png)% before, $(green $d/gfx3.png)% back"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$d/end.txt'"
    check "graphics task draws in mode 13h" "[ \$(green $d/gfx1.png) -ge 90 ]"
    check "text task's screen in text mode" "grep -q 'keyprobe D ready' '$d/fg2.txt'"
    check "graphics task back, drawn again" "[ \$(green $d/gfx3.png) -ge 90 ]"
    check "graphics task held in the background" "[ \$(echo $g1 | awk '{print \$5+0}') -ge 90 ]"
    check "it drew again once" "[ \$(echo $g1 | awk '{print \$3+0}') -eq 1 ]"
    ;;
objs)
    echo "== objs:  DESQview objects of a task that ends"
    printf '@ECHO OFF\r\nC:\\MAXVTSR.COM\r\nC:\\LEAKPRB.COM S C:\\S1.TXT\r\nC:\\LEAKPRB.COM C C:\\C1.TXT\r\nC:\\MVRUN /K6 15 C:\\LEAKPRB.COM L C:\\L1.TXT ; C:\\LEAKPRB.COM C C:\\C2.TXT\r\nC:\\LEAKPRB.COM C C:\\C3.TXT\r\nC:\\MVRUN 10 C:\\LEAKPRB.COM H C:\\H1.TXT ; C:\\LEAKPRB.COM D C:\\D2.TXT\r\nC:\\MVRUN 15 C:\\LEAKPRB.COM L C:\\L2.TXT ; C:\\LEAKPRB.COM V C:\\V2.TXT\r\nECHO OBJSEND\r\n' > "$OUT/O.BAT"
    CMD="C:\\O.BAT" END="wait:OBJSEND:400 sleep:2" run objs 15 "" "$OUT/O.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/LEAKPRB.COM"
    s1=$(file objs S1.TXT | tr '\n' ' '); c1=$(file objs C1.TXT | tr '\n' ' ')
    l1=$(file objs L1.TXT | tr '\n' ' '); c2=$(file objs C2.TXT | tr '\n' ' ')
    c3=$(file objs C3.TXT | tr '\n' ' ')
    h1=$(file objs H1.TXT | tr '\n' ' '); d2=$(file objs D2.TXT | tr '\n' ' ')
    v2=$(file objs V2.TXT | tr '\n' ' ')
    echo "  H1: $h1"; echo "  D2: $d2"; echo "  V2: $v2"
    echo "  S1: $s1"; echo "  C1: $c1"; echo "  L1: $l1"; echo "  C2: $c2"; echo "  C3: $c3"
    get() { echo "$1" | awk -v w="$2" '{for (i = 1; i < NF; i++) if ($i == w) print $(i + 1)}'; }
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/objs/end.txt'"
    check "stack:  NEW +4, HANDLE 01h +4, 00h 0, FREE -4 (as DV)" "[ '$s1' = 'new 4 handle 4 handle0 0 free -4 ' ]"
    check "the task got one of each" "[ '$l1' = 'leak sys 1 com 1 mbx 1 tmr 1 ' ]"
    check "its GETMEM blocks back" "[ -n '$(get "$c1" sys)' ] && [ '$(get "$c2" sys)' = '$(get "$c1" sys)' ]"
    check "its mailbox back" "[ -n '$(get "$c1" mbx)' ] && [ '$(get "$c2" mbx)' = '$(get "$c1" mbx)' ]"
    check "common block and timer kept (as DV)" "[ '$(get "$c2" com)' = \$(( $(get "$c1" com) - 1 )) ] && [ '$(get "$c2" tmr)' = \$(( $(get "$c1" tmr) - 1 )) ]"
    check "the same after MVRUN" "[ '$c3' = '$c2' ]"
    check "the handle of a task that ended is no object any more" "[ '$v2' = 'live 0 2 ' ]"
    check "GETMEM per task:  all for one, all for the other at once" "[ '$h1' = 'hold 8 ' ] && [ '$(get "$d2" sys)' = 8 ]"
    ;;
ipc)
    echo "== ipc:  task mailboxes, a server and a client (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN 15 C:\\IPCPRB.COM S C:\\S1.TXT ; C:\\IPCPRB.COM C C:\\C2.TXT\r\n' > "$OUT/I.BAT"
    CMD="C:\\I.BAT" END="wait:MVRUN:_done:120 sleep:3" run ipc 15 "" "$OUT/I.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/IPCPRB.COM"
    s1=$(file ipc S1.TXT | tr '\n' '|'); c2=$(file ipc C2.TXT | tr '\n' '|')
    echo "  S1: $s1"; echo "  C2: $c2"
    m1=$(echo "$s1" | sed -n 's/^mine \([0-9A-F:]*\)|.*/\1/p')
    m2=$(echo "$c2" | sed -n 's/^mine \([0-9A-F:]*\)|.*/\1/p')
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/ipc/end.txt'"
    check "a mailbox per task (HANDLE 03h)" "[ -n '$m1' ] && [ -n '$m2' ] && [ '$m1' != '$m2' ] && [ '${m1%%:*}' != 0000 ]"
    check "AT:  the column on top (as DV)" "echo '$s1' | grep -q '|at 10 5|'"
    check "SETNAME 03h:  the length on top (as DV)" "echo '$s1' | grep -q '|named.* 2|'"
    check "FINDMAIL finds the server's mailbox" "echo '$c2' | grep -q '|find 1 $m1|sent|'"
    check "READ 03h waits, gets length on top, then the text" "echo '$s1' | grep -q '|got 00000005 [0-9A-F]* hello|'"
    me=$(echo "$c2" | sed -n 's/.*|me \([0-9A-F:]*\)|.*/\1/p')
    check "a task handle per task, ADDR gives the sender's" "[ -n '$me' ] && [ '${me%%:*}' != 0000 ] && echo '$s1' | grep -q '|from $me|replied|'"
    check "WRITE 02h to the sender's mailbox, its READ 03h gets it" "echo '$c2' | grep -q '|reply 00000002 ok|'"
    ;;
wwrite)
    echo "== wwrite:  WRITE to the task's window (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 15 C:\\WINPRB.COM C:\\W1.TXT\r\n' > "$OUT/W.BAT"
    CMD="C:\\W.BAT" END="wait:MVRUN:_done:120 sleep:3" run wwrite 15 "" "$OUT/W.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/WINPRB.COM" \
        "wait:winprb_done:60 sleep:1 text:shot"
    w1=$(file wwrite W1.TXT | tr '\n' '|')
    echo "  W1: $w1"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/wwrite/end.txt'"
    check "stack and cursor as DV (8, handle form 12; CR LF, BS)" "[ '$w1' = 'w1 -8 5 5|w2 -12 5 7|w3 -8 6 1|w4 -8 6 4|' ]"
    check "the text on the screen as DV" "grep -q '^HelloABX' '$OUT/wwrite/shot.txt' && grep -q '^Y2.3' '$OUT/wwrite/shot.txt'"
    ;;
wstream)
    echo "== wstream:  a window stream in WRITE (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 15 C:\\STRPRB.COM C:\\S1.TXT\r\n' > "$OUT/S.BAT"
    CMD="C:\\S.BAT" END="wait:MVRUN:_done:120 sleep:3" run wstream 15 "" "$OUT/S.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/STRPRB.COM" \
        "wait:strprb_done:60 sleep:1 text:shot"
    s1=$(file wstream S1.TXT | tr '\n' '|')
    echo "  S1: $s1"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/wstream/end.txt'"
    check "cursor, characters and colours as DV" "[ '$s1' = 'cur 3 20|cells A/1E B/1E C/1E */1E */1E */1E  /70  /70 x/1E y/1E|' ]"
    ;;
wquery)
    echo "== wquery:  a query stream in WRITE (as DV, the window the screen)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 15 C:\\QRYPRB.COM C:\\Q1.TXT\r\n' > "$OUT/Q.BAT"
    CMD="C:\\Q.BAT" END="wait:MVRUN:_done:120 sleep:3" run wquery 15 "" "$OUT/Q.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/QRYPRB.COM"
    q1=$(file wquery Q1.TXT | tr '\n' '|')
    echo "  Q1: $q1"
    # DV 2.80 in its 10 x 78 framed window:  C3 0A 4E .. A6 0A A7 4E .. D6
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/wquery/end.txt'"
    check "cursor, size, colour, mode, flags" "[ '$q1' = 'q A0 04 A1 07 C0 04 07 C3 19 50 C5 19 50 A6 19 A7 50 AB 50 AF 44 E2 1E D4 D7 DC DE|cur 4 7|' ]"
    ;;
crtc)
    echo "== crtc:  a background task's CRTC and DAC OUTs (QPI 0Dh/0Eh)"
    run crtc 15 "C:\\CRTPRB.COM F C:\\F1.TXT ; C:\\CRTPRB.COM B C:\\B2.TXT" "$ROOT/build/CRTPRB.COM"
    f1=$(file crtc F1.TXT | tr '\n' '|'); b2=$(file crtc B2.TXT | tr '\n' '|')
    echo "  F1: $f1  B2: $b2"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/crtc/end.txt'"
    check "the foreground's cursor stays on the CRTC" "echo '$f1' | grep -q '^cur 0668|'"
    check "the foreground's DAC stays" "echo '$f1' | grep -q '|dac same|'"
    check "the background task reads its own cursor back" "[ '$b2' = 'rb 0005|bios 0 5|' ]"
    ;;
wobj)
    echo "== wobj:  a window object (stream E6h), as under DV"
    xp() { echo "mon:xp+/28xb+$((0xb8000 + $1 * 160 + $2 * 2))>$3"; }
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 25 C:\\WOBPRB.COM C:\\W1.TXT\r\n' > "$OUT/WB.BAT"
    CMD="C:\\WB.BAT" END="wait:MVRUN:_done:120 sleep:3" run wobj 25 "" "$OUT/WB.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/WOBPRB.COM" \
        "wait:wobprb_ready:60 sleep:1 $(xp 13 29 top) $(xp 14 29 hello) $(xp 17 29 colours) $(xp 18 29 bottom) sleep:4 $(xp 16 49 moved) $(xp 13 29 old) sleep:5 text:freed"
    hx() { grep -o "0x[0-9a-f][0-9a-f]" "$OUT/wobj/$1.txt" | tr '\n' ' ' | sed 's/ $//'; }
    w1=$(file wobj W1.TXT | tr '\n' '|')
    echo "  W1: $w1"
    # the screen bytes:  the frame in Open 386MAX's 1Fh (DV:  the window's
    # colours), blanks 17h
    l=$(printf '0xc4 0x1f %.0s' 1 2 3 4 5 6 7); b=$(printf '0x20 0x17 %.0s' 1 2 3 4 5 6 7 8)
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/wobj/end.txt'"
    check "E6h:  a handle as the WRITE's result" "echo '$w1' | grep -q '|new [0-9A-F]*:0000 4|'"
    check "frame (1Fh), title, contents:  top" "[ \"$(hx top)\" = '0xda 0x1f 0x70 0x1f 0x72 0x1f 0x6f 0x1f 0x62 0x1f 0x65 0x1f ${l}0xbf 0x1f' ]"
    check "  hello in 1Fh, blanks 17h (physical colours)" "[ \"$(hx hello)\" = '0xb3 0x1f 0x68 0x1f 0x65 0x1f 0x6c 0x1f 0x6c 0x1f 0x6f 0x1f $(printf '0x20 0x17 %.0s' 1 2 3 4 5 6 7)0xb3 0x1f' ]"
    check "  00h 1Fh 70h 7Fh as they are" "[ \"$(hx colours)\" = '0xb3 0x1f 0x41 0x00 0x42 0x1f 0x43 0x70 0x44 0x7f ${b}0xb3 0x1f' ]"
    check "  bottom" "[ \"$(hx bottom)\" = '0xc0 0x1f $(printf '0xc4 0x1f %.0s' 1 2 3 4 5 6 7 8 9 10 11 12)0xd9 0x1f' ]"
    check "C2h 17,50 + E4h:  moved, the old place restored" "hx moved | grep -q '^0xda 0x1f 0x70 0x1f' && ! hx old | grep -q '^0xda'"
    check "FREE:  the screen restored" "! grep -q probe '$OUT/wobj/freed.txt'"
    ;;
panel)
    echo "== panel:  panel objects (NEW 10h):  a library opened, panels applied (PANPRB, as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 25 C:\\PANPRB.COM C:\\P1.TXT C:\\MVTEST.PLB x TEXT WIN FORM WRAP NOPE\r\n' > "$OUT/PN.BAT"
    CMD="C:\\PN.BAT" END="wait:MVRUN:_done:120 sleep:3" run panel 25 "" "$OUT/PN.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/PANPRB.COM $ROOT/build/MVTEST.PLB" \
        "wait:panprb_ready:60 sleep:1 text:t1 key:ret sleep:3 text:t2 key:ret sleep:3 text:t3 key:ret sleep:3 text:t4 key:ret sleep:3 key:ret sleep:3"
    p1=$(file panel P1.TXT)
    echo "$p1" | sed 's/^/  /'
    own=$(echo "$p1" | sed -n 's/^own 4 //p')
    rd() { echo "$p1" | grep '^read' | sed -n "$1p"; }
    check "NEW 10h:  a handle; OPEN (its length with the 0):  status 0; SIZEOF:  5 panels" "echo \"\$p1\" | grep -q '^new 4 [0-9A-F]*:0000' && echo \"\$p1\" | grep -A1 '^open 0' | grep -q '^status 4 0000:0000' && echo \"\$p1\" | grep -q '^sizeof 4 0000:0005'"
    check "READ TEXT (window 0):  the own window and keyboard 0, status 0, its text in the own window" "[ \"\$(rd 1)\" = \"read 8 \$own 0000:0000\" ] && [ \"\$(echo \"\$p1\" | grep -A1 '^read' | sed -n 2p)\" = 'status 4 0000:0000' ] && grep -q 'Panel text in the own window' '$OUT/panel/t1.txt' && grep -q '^second row' '$OUT/panel/t1.txt'"
    check "READ WIN (E6h):  0, 0 and the new window's handle below them, status 0, the window shown" "rd 2 | grep -q '^read 12 0000:0000 0000:0000 [0-9A-F]*:0000$' && grep -q 'in a new window' '$OUT/panel/t2.txt'"
    check "READ FORM:  a window with fields" "rd 3 | grep -q '^read 12 0000:0000 0000:0000 [0-9A-F]*:0000$' && grep -q 'Two fields:' '$OUT/panel/t3.txt'"
    check "READ WRAP (C5h:  the own window a window object):  colours only (90h) keep the characters past a row's end" "[ \"\$(rd 4)\" = \"read 8 \$own 0000:0000\" ] && grep -q '^ 0123456789' '$OUT/panel/t4.txt' && grep -q '^ ABCDE ' '$OUT/panel/t4.txt'"
    check "READ NOPE:  status 14h, the own window and 0" "[ \"\$(rd 5)\" = \"read 8 \$own 0000:0000\" ] && echo \"\$p1\" | grep -A1 '^read' | tail -1 | grep -q '^status 4 0000:0014'"
    check "CLOSE:  status 0; FREE; MVRUN ended" "echo \"\$p1\" | grep -A1 '^close 0' | grep -q '^status 4 0000:0000' && echo \"\$p1\" | grep -q '^free 0' && grep -q 'MVRUN: done' '$OUT/panel/end.txt'"
    ;;
menu)
    echo "== menu:  demos/MENU, a window and keyboard of its own, as under DV"
    xr() { local s=""; for r in 8 9 10 11 12 13; do s="$s mon:xp+/28xb+$((0xb8000 + r * 160 + 64))>$1$r"; done; echo $s; }
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 25 C:\\MENU.COM C:\\M.TXT\r\n' > "$OUT/MN.BAT"
    CMD="C:\\MN.BAT" END="wait:MVRUN:_done:120 sleep:3" run menu 25 "" "$OUT/MN.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/MENU.COM" \
        "wait:green:60 sleep:2 $(xr a) key:down sleep:1 $(xr b) key:ret sleep:2 $(xr c) text:items key:b sleep:2 key:q sleep:3"
    rows() { for r in 8 9 10 11 12 13; do grep -o "0x[0-9a-f][0-9a-f]" "$OUT/menu/$1$r.txt"; done | tr '\n' ' '; }
    m=$(file menu M.TXT | tr '\n' '|')
    echo "  M: $m"
    # the screen bytes (rows 8-13, columns 32-45), placed as under DV 2.80:
    # a double frame (on top) in Open 386MAX's 1Fh, "colours", the pointed
    # at field 70h, the others 07h (logical colours as they are; DV shows
    # them through its window colours)
    fr() { printf '0xc9 0x1f 0x63 0x1f 0x6f 0x1f 0x6c 0x1f 0x6f 0x1f 0x75 0x1f 0x72 0x1f 0x73 0x1f %s0xbb 0x1f ' "$(printf '0xcd 0x1f %.0s' 1 2 3 4 5)"; }
    ln() { local t="$1" i; printf '0xba 0x1f '; for ((i = 0; i < ${#t}; i++)); do printf '0x%02x 0x%s ' "'${t:i:1}" "$2"; done; printf '0xba 0x1f '; }
    bot() { printf '0xc8 0x1f %s0xbc 0x1f ' "$(printf '0xcd 0x1f %.0s' 1 2 3 4 5 6 7 8 9 10 11 12)"; }
    want() { echo "$(fr)$(ln ' red      R ' $1)$(ln ' green    G ' $2)$(ln ' blue     B ' 07)$(ln ' quit     Q ' 07)$(bot)" | sed 's/ $//'; }
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/menu/end.txt'"
    check "red pointed at (70h), a double frame (1Fh), the others 07h" "[ \"$(rows a | sed 's/ $//')\" = \"$(want 70 07)\" ]"
    check "Down:  green pointed at" "[ \"$(rows b | sed 's/ $//')\" = \"$(want 07 70)\" ]"
    check "Enter:  green stays pointed at" "[ \"$(rows c | sed 's/ $//')\" = \"$(want 07 70)\" ]"
    check "the records as DV's:  02/03/04, 'Y'" "[ '$m' = '02 04 02010059|03 04 03010059|04 04 04010059|' ]"
    check "Enter:  item 2 chosen in the own window, at its start" "grep -q '^item 2 chosen' '$OUT/menu/items.txt'"
    ;;
subtask)
    echo "== subtask:  NEW 08h with an entry point, a DESQview subtask (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 40 C:\\SUBPRB.COM C:\\S.TXT\r\n' > "$OUT/SB.BAT"
    CMD="C:\\SB.BAT" END="wait:MVRUN:_done:120 sleep:3" run subtask 40 "" "$OUT/SB.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/SUBPRB.COM" \
        "wait:sub_in_the_window:60 text:w"
    s1=$(file subtask S.TXT | tr '\n' '|')
    echo "  S: $s1"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/subtask/end.txt'"
    check "NEW:  a handle, 4 bytes (as DV)" "echo '$s1' | grep -q '^new [0-9A-F]* 4|' && ! echo '$s1' | grep -q '^new 0000 '"
    check "the subtask writes to its task's window (its handle)" "grep -q '^sub in the window' '$OUT/subtask/w.txt'"
    check "its mail (BL=02h) read with BL=03h:  2 bytes, status 7, hi" "echo '$s1' | grep -q '|mail 02 07 hi|'"
    check "it runs alongside; FREE ends it (as DV)" "echo '$s1' | grep -q '|runs Y|free|stops Y|'"
    ;;
worms)
    echo "== worms:  demos/WORMS, subtasks with timers writing to the task's window (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 60 C:\\WORMS.COM\r\n' > "$OUT/WM.BAT"
    xs() { echo "mon:xp+/4000xb+0xb8000>$1"; }
    CMD="C:\\WM.BAT" END="wait:MVRUN:_done:120 sleep:3" run worms 60 "" "$OUT/WM.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/WORMS.COM" \
        "wait:WORMS:60 sleep:2 key:n sleep:1 key:n sleep:1 key:n sleep:3 $(xs a) sleep:2 $(xs b) key:k sleep:2 key:s sleep:2 $(xs c) sleep:2 $(xs d) key:s key:c sleep:1 key:q"
    cells() { grep -o "0x[0-9a-f][0-9a-f]" "$OUT/worms/$1.txt" | paste - - | grep -c "^0xdb	$2"; }
    sc() { grep -o "0x[0-9a-f][0-9a-f]" "$OUT/worms/$1.txt" | tr -d '\n'; }
    echo "  worm cells:  $(cells a 0x0a) $(cells a 0x0c) $(cells a 0x0e)"
    check "MVRUN ended, WORMS exit 0" "grep -q 'MVRUN: done' '$OUT/worms/end.txt' && grep -q 'task 1: done exit 0000' '$OUT/worms/end.txt'"
    check "N:  three worms (green, red, yellow)" "[ $(cells a 0x0a) -gt 0 ] && [ $(cells a 0x0c) -gt 0 ] && [ $(cells a 0x0e) -gt 0 ]"
    check "they crawl" "[ '$(sc a)' != '$(sc b)' ]"
    check "S:  all stand still" "[ '$(sc c)' = '$(sc d)' ]"
    ;;
launch)
    echo "== launch:  demos/LAUNCH, APP_START of a DVP made in memory (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 60 C:\\LAUNCH.COM\r\n' > "$OUT/LA.BAT"
    xs() { echo "mon:xp+/4000xb+0xb8000>$1"; }
    CMD="C:\\LA.BAT" END="wait:MVRUN:_done:120 sleep:3" run launch 60 "" "$OUT/LA.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/LAUNCH.COM $ROOT/build/HELLO.COM $ROOT/build/WORMS.COM" \
        "wait:choose_a_demo:60 sleep:1 key:h sleep:6 text:l1 key:w wait:WORMS:30 sleep:1 key:n sleep:3 $(xs w) key:q sleep:4 text:l2 key:q"
    cells() { grep -o "0x[0-9a-f][0-9a-f]" "$OUT/launch/$1.txt" | paste - - | grep -c "^0xdb	$2"; }
    check "MVRUN ended, LAUNCH exit 0" "grep -q 'MVRUN: done' '$OUT/launch/end.txt' && grep -q 'task 1: done exit 0000' '$OUT/launch/end.txt'"
    check "H:  HELLO started as a task of its own, from task 1" "grep -q 'started by 1 Hello' '$OUT/launch/end.txt'"
    check "it ended (COMMAND /C:  DVP close on exit):  LAUNCH in front again, the handle in its window" "grep -q '^Hello:  task [0-9A-F][0-9A-F][0-9A-F][0-9A-F]' '$OUT/launch/l1.txt'"
    check "W:  WORMS started and in front (N:  a worm)" "grep -q 'started by 1 Worms' '$OUT/launch/end.txt' && [ $(cells w 0x0a) -gt 0 ]"
    check "Q in WORMS:  LAUNCH in front again" "grep -q '^Worms:  task [0-9A-F][0-9A-F][0-9A-F][0-9A-F]' '$OUT/launch/l2.txt'"
    ;;
ownwin)
    echo "== ownwin:  the task's own window sized and moved (C3h/C5h/C2h), as under DV"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 20 C:\\OWNPRB.COM\r\n' > "$OUT/OW.BAT"
    CMD="C:\\OW.BAT" END="wait:MVRUN:_done:120 sleep:3" run ownwin 20 "" "$OUT/OW.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/OWNPRB.COM" \
        "wait:own_window:60 sleep:1 mon:xp+/4000xb+0xb8000>o key:ret wait:second:30 sleep:1 mon:xp+/4000xb+0xb8000>o2 key:ret"
    # cell (row, column):  character and attribute, as two hex bytes (o2:  sized again)
    cell() { awk '/^[0-9a-f]+:/' "$OUT/ownwin/${O:-o}.txt" | grep -o "0x[0-9a-f][0-9a-f]" | sed -n "$((($1 * 80 + $2) * 2 + 1)),+1p" | tr '\n' ' ' | sed 's/ $//'; }
    text() { local c s=""; for ((c = $2; c < $3; c++)); do s="$s$(printf "\\x$(cell $1 $c | cut -c3-4)")"; done; printf "$s"; }
    echo "  row 6:  '$(text 6 30 40)'"
    check "MVRUN ended, OWNPRB exit 0" "grep -q 'MVRUN: done' '$OUT/ownwin/end.txt' && grep -q 'task 1: done exit 0000' '$OUT/ownwin/end.txt'"
    check "the text at row 6, column 30 (the window's contents, as DV)" "[ \"$(text 6 30 40)\" = 'own window' ]"
    check "a double frame around 5x20:  corners at 5,29 / 5,50 / 11,29 / 11,50" "[ '$(cell 5 29 | cut -c1-4) $(cell 5 50 | cut -c1-4) $(cell 11 29 | cut -c1-4) $(cell 11 50 | cut -c1-4)' = '0xc9 0xbb 0xc8 0xbc' ]"
    check "the frame's sides at 6,29 and 6,50" "[ '$(cell 6 29 | cut -c1-4)' = '0xba' ] && [ '$(cell 6 50 | cut -c1-4)' = '0xba' ]"
    check "the title as DV's:  its number, two double lines, the program (1==OWNPRB)" "[ '$(cell 5 30 | cut -c1-4) $(cell 5 31 | cut -c1-4) $(cell 5 32 | cut -c1-4)' = '0x31 0xcd 0xcd' ] && [ \"$(text 5 33 39)\" = 'OWNPRB' ] && [ '$(cell 5 39 | cut -c1-4)' = '0xcd' ]"
    check "its blanks in the window's colour (the screen's, 07h; DV:  its DOS window's)" "[ '$(cell 7 30)' = '0x20 0x07' ] && [ '$(cell 6 30 | cut -c6-9)' = '0x1e' ]"
    O=o2
    echo "  sized again, row 3:  '$(text 3 10 20)'"
    check "sized again (8x40, C2h 3,10), as DV:  the text at 3,10, the cursor at 0,0" "[ \"$(text 3 10 16)\" = 'second' ]"
    check "  the double frame around 8x40:  corners at 2,9 / 2,50 / 11,9 / 11,50" "[ '$(cell 2 9 | cut -c1-4) $(cell 2 50 | cut -c1-4) $(cell 11 9 | cut -c1-4) $(cell 11 50 | cut -c1-4)' = '0xc9 0xbb 0xc8 0xbc' ]"
    check "  its title (1==OWNPRB), the old frame gone (5,29 / 11,29 inside)" "[ '$(cell 2 10 | cut -c1-4) $(cell 2 11 | cut -c1-4)' = '0x31 0xcd' ] && [ \"$(text 2 13 19)\" = 'OWNPRB' ] && [ '$(cell 5 29 | cut -c1-4)' != '0xc9' ] && [ '$(cell 11 29 | cut -c1-4)' != '0xc8' ]"
    check "  the old contents at the top left (own window -> secondndow), the new part blank" "[ \"$(text 3 16 20)\" = 'ndow' ] && [ '$(cell 4 10 | cut -c1-4) $(cell 10 49 | cut -c1-4)' = '0x20 0x20' ]"
    unset O
    ;;
subown)
    echo "== subown:  a subtask's own window sized and moved (C3h/C5h/C2h), as under DV"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 20 C:\\SOWPRB.COM\r\n' > "$OUT/SO.BAT"
    CMD="C:\\SO.BAT" END="wait:MVRUN:_done:120 sleep:3" run subown 20 "" "$OUT/SO.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/SOWPRB.COM" \
        "wait:made:60 sleep:2 mon:xp+/4000xb+0xb8000>o key:ret"
    # cell (row, column):  character and attribute, as two hex bytes
    cell() { awk '/^[0-9a-f]+:/' "$OUT/subown/o.txt" | grep -o "0x[0-9a-f][0-9a-f]" | sed -n "$((($1 * 80 + $2) * 2 + 1)),+1p" | tr '\n' ' ' | sed 's/ $//'; }
    text() { local c s=""; for ((c = $2; c < $3; c++)); do s="$s$(printf "\\x$(cell $1 $c | cut -c3-4)")"; done; printf "$s"; }
    echo "  row 15:  '$(text 15 40 50)'"
    check "MVRUN ended, SOWPRB exit 0" "grep -q 'MVRUN: done' '$OUT/subown/end.txt' && grep -q 'task 1: done exit 0000' '$OUT/subown/end.txt'"
    check "the subtask's text at row 15, column 40 (its window's contents, as DV)" "[ \"$(text 15 40 47)\" = 'sub own' ]"
    check "a single frame around 4x20:  corners at 14,39 / 14,60 / 19,39 / 19,60" "[ '$(cell 14 39 | cut -c1-4) $(cell 14 60 | cut -c1-4) $(cell 19 39 | cut -c1-4) $(cell 19 60 | cut -c1-4)' = '0xda 0xbf 0xc0 0xd9' ]"
    check "untitled (a line at 14,40), the frame 1Fh (Open 386MAX's)" "[ '$(cell 14 40)' = '0xc4 0x1f' ] && [ '$(cell 15 39)' = '0xb3 0x1f' ]"
    check "its contents 17h, as DV shows them" "[ '$(cell 15 40 | cut -c6-9)' = '0x17' ] && [ '$(cell 16 40)' = '0x20 0x17' ]"
    check "the task's text in its window (main made)" "awk '/^[0-9a-f]+:/' '$OUT/subown/o.txt' | grep -o '0x[0-9a-f][0-9a-f]' | awk 'NR % 2' | tr -d '\\n' | grep -q '0x6d0x610x690x6e0x200x6d0x610x640x65'"
    ;;
serve)
    echo "== serve:  demos/SERVE and ASK, two tasks over a named mailbox (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F2 40 C:\\SERVE.COM ; C:\\ASK.COM\r\n' > "$OUT/SA.BAT"
    CMD="C:\\SA.BAT" END="wait:MVRUN:_done:120 sleep:3" run serve 40 "" "$OUT/SA.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/SERVE.COM $ROOT/build/ASK.COM" \
        "wait:SERVE_found:60 sleep:2 type:hello_there sleep:3 type:one_more sleep:3 text:a1 key:ctrl-alt-1 sleep:3 text:a3 sleep:2 text:a4 key:ctrl-alt-2 sleep:1 key:ret"
    t3=$(head -1 "$OUT/serve/a3.txt" | sed -n 's/^SERVE  time  \([0-9:]*\)  requests  \([0-9]*\).*/\1 \2/p')
    t4=$(head -1 "$OUT/serve/a4.txt" | sed -n 's/^SERVE  time  \([0-9:]*\)  requests  \([0-9]*\).*/\1 \2/p')
    echo "  SERVE:  $t3 / $t4"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/serve/end.txt'"
    check "ASK:  FINDMAIL found SERVE's mailbox" "grep -q '^SERVE found' '$OUT/serve/a1.txt'"
    check "  the answers in capitals (ADDR, ADDTO with BL=02h)" "grep -q '^HELLO THERE' '$OUT/serve/a1.txt' && grep -q '^ONE MORE' '$OUT/serve/a1.txt'"
    check "SERVE:  2 requests, its clock from the timer READ runs" "[ '${t3#* }' = 00002 ] && [ -n '${t3%% *}' ] && [ '${t3%% *}' != '${t4%% *}' ]"
    ;;
countdn)
    echo "== countdn:  demos/COUNTDN, fields + timer + OBJECTQ (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 60 C:\\COUNTDN.COM\r\n' > "$OUT/CD.BAT"
    CMD="C:\\CD.BAT" END="wait:MVRUN:_done:120 sleep:3" run countdn 60 "" "$OUT/CD.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/COUNTDN.COM" \
        "wait:countdown:60 sleep:3 text:c0 type:3 sleep:1 key:ret sleep:1.5 text:c1 sleep:5 text:c2 key:esc"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/countdn/end.txt'"
    check "the window, the seconds' field empty" "grep -q 'Seconds:  \\[  \\]' '$OUT/countdn/c0.txt' && grep -q 'Left:  000' '$OUT/countdn/c0.txt'"
    check "3 from the right, Enter:  002 after 1.5 s" "grep -q 'Seconds:  \\[ 3\\]' '$OUT/countdn/c1.txt' && grep -q 'Left:  002' '$OUT/countdn/c1.txt'"
    check "000 and 'time is up' in the own window" "grep -q 'Left:  000' '$OUT/countdn/c2.txt' && grep -q '^time is up' '$OUT/countdn/c2.txt'"
    ;;
demos)
    echo "== demos:  demos/MOUSE then demos/HELLO in one task (as under DV)"
    CTM=${CTMOUSE:-$HOME/mars/scratch-386max/ctm/bin/ctmouse.exe}
    if [ ! -f "$CTM" ]; then echo "  SKIP  no CuteMouse (CTMOUSE=path of ctmouse.exe)"; continue; fi
    cp "$CTM" "$OUT/CTMOUSE.EXE"
    printf 'C:\\MOUSE.COM\r\nC:\\HELLO.COM\r\nPAUSE\r\n' > "$OUT/D.BAT"
    printf 'C:\\CTMOUSE.EXE\r\nC:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 60 C:\\COMMAND.COM /C C:\\D.BAT\r\n' > "$OUT/DM.BAT"
    mv() { local s="" i; for ((i = 0; i < $3; i++)); do s="$s mon:mouse_move+$1+$2 sleep:0.2"; done; echo "$s"; }
    CMD="C:\\DM.BAT" END="wait:MVRUN:_done:120 sleep:3" run demos 60 "" "$OUT/DM.BAT $OUT/D.BAT $OUT/CTMOUSE.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MOUSE.COM $ROOT/build/HELLO.COM" \
        "wait:right_button:60 sleep:3 text:m0 $(mv -100 -100 10) $(mv 4 0 23) $(mv 0 8 4) $(mv 0 4 1) sleep:1 mon:mouse_button+1 sleep:0.5 mon:mouse_button+0 sleep:2 text:m1 mon:mouse_button+2 sleep:0.5 mon:mouse_button+0 wait:Hello_from:60 sleep:1 text:h key:ret"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/demos/end.txt'"
    check "MOUSE:  the window erased, its text on top" "head -1 '$OUT/demos/m0.txt' | grep -q '^Move the mouse'"
    check "  WRITE of the pointer:  a move to row 5, column 30" "[ \"\$(sed -n 6p '$OUT/demos/m0.txt' | cut -c31)\" = . ]"
    check "  the left button marked where it was" "sed -n 5p '$OUT/demos/m1.txt' | grep -q L"
    check "HELLO:  its line through the API" "grep -q '^Hello from a DESQview API program.' '$OUT/demos/h.txt'"
    ;;
pntf)
    echo "== pntf:  a pointer message sends 49h (NTFPRB P, MVRUN)"
    CTM=${CTMOUSE:-$HOME/mars/scratch-386max/ctm/bin/ctmouse.exe}
    if [ ! -f "$CTM" ]; then echo "  SKIP  no CuteMouse (CTMOUSE=path of ctmouse.exe)"; continue; fi
    cp "$CTM" "$OUT/CTMOUSE.EXE"
    printf 'C:\\CTMOUSE.EXE\r\nC:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 60 C:\\NTFPRB.COM C:\\N1.TXT P ; C:\\TICK.EXE C:\\T2.TXT\r\n' > "$OUT/P.BAT"
    mv() { local s="" i; for ((i = 0; i < $3; i++)); do s="$s mon:mouse_move+$1+$2 sleep:0.2"; done; echo "$s"; }
    CMD="C:\\P.BAT" END="wait:MVRUN:_done:120 sleep:3" run pntf 60 "" "$OUT/P.BAT $OUT/CTMOUSE.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/NTFPRB.COM $TICK" \
        "wait:ntfprb_ready:60 sleep:3 $(mv -100 -100 10) $(mv 4 0 23) $(mv 0 8 4) $(mv 0 4 1) sleep:1 mon:mouse_button+1 sleep:0.5 mon:mouse_button+0 sleep:2 $(mv 4 0 8) $(mv 0 8 1) sleep:1 mon:mouse_button+2 sleep:0.5 mon:mouse_button+0 sleep:2 key:x"
    n1=$(file pntf N1.TXT)
    echo "$n1" | grep '^  [0-9]\|^  a' | sed 's/^/  /'
    seq=$(echo "$n1" | grep '^  [0-9]' | awk '{print $2}' | tr '\n' ' ')
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/pntf/end.txt'"
    check "each click:  its pointer message (6 bytes), then 49h and the pointer's handle (5 bytes)" "[ \"\$(echo '$seq' | cut -d' ' -f1-4)\" = '0000:0006 0000:0005 0000:0006 0000:0005' ] && [ \"\$(echo \"\$n1\" | grep -c '^  a 49 00 00 ')\" = 2 ]"
    ;;
revive)
    echo "== revive:  Tune's Revive Mouse with a driver, pointer messages afterwards (NTFPRB P)"
    CTM=${CTMOUSE:-$HOME/mars/scratch-386max/ctm/bin/ctmouse.exe}
    if [ ! -f "$CTM" ]; then echo "  SKIP  no CuteMouse (CTMOUSE=path of ctmouse.exe)"; continue; fi
    cp "$CTM" "$OUT/CTMOUSE.EXE"
    cfg=$OUT/MAXVIEW.CFG
    printf 'D|DosOne|C:\\COMMAND.COM||64|640\r\n' > "$cfg"
    printf 'C:\\CTMOUSE.EXE\r\nC:\\MAXVIEW\r\n' > "$OUT/R.BAT"
    M="key:alt wait:Switch_Windows:20"
    R="$M key:r wait:Tune_Performance:10"
    mv() { local s="" i; for ((i = 0; i < $3; i++)); do s="$s mon:mouse_move+$1+$2 sleep:0.2"; done; echo "$s"; }
    click="$(mv -100 -100 10) $(mv 4 0 20) $(mv 0 8 6) sleep:1 mon:mouse_button+1 sleep:0.5 mon:mouse_button+0 sleep:2"
    CMD="C:\\R.BAT" END="wait:revive_end:30" run revive 0 "" \
        "$OUT/R.BAT $OUT/CTMOUSE.EXE $ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/NTFPRB.COM $cfg $(oldwin)" \
        "wait:Open_Program:60 key:ret sleep:4 type:C:\\NTFPRB_C:\\N1.TXT_P wait:ntfprb_ready:30 sleep:1 $click $R key:t wait:This_Window:10 key:m sleep:2 text:tune key:esc sleep:1 key:esc sleep:1 key:esc sleep:1 $click key:x sleep:3 $M key:q wait:Are_you_sure:10 key:y gone:Switch_Windows:30 sleep:3 type:echo_revive_end"
    d=$OUT/revive
    n1=$(file revive N1.TXT)
    echo "$n1" | grep '^  [0-9]\|^  a' | sed 's/^/  /'
    check "M:  Mouse revived (the driver's reset)" "grep -q 'Mouse revived' '$d/tune.txt'"
    check "a click before and after:  a pointer message each (6 bytes), relative to the window's contents (screen 6, 10 in DosOne's from 2, 2:  4, 8)" "[ \"\$(echo \"\$n1\" | grep -c '^  [0-9]* 0000:0006 ')\" = 2 ] && [ \"\$(echo \"\$n1\" | grep -c '^  a 04 00 08 00 01 00')\" = 2 ]"
    check "DOS works afterwards" "grep -q '^revive end' '$d/end.txt'"
    ;;
pointer)
    echo "== pointer:  a pointer object (as under DV)"
    CTM=${CTMOUSE:-$HOME/mars/scratch-386max/ctm/bin/ctmouse.exe}
    if [ ! -f "$CTM" ]; then echo "  SKIP  no CuteMouse (CTMOUSE=path of ctmouse.exe)"; continue; fi
    cp "$CTM" "$OUT/CTMOUSE.EXE"
    printf 'C:\\CTMOUSE.EXE\r\nC:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 60 C:\\PTRPRB.COM C:\\P1.TXT ; C:\\TICK.EXE C:\\T2.TXT\r\n' > "$OUT/P.BAT"
    mv() { local s="" i; for ((i = 0; i < $3; i++)); do s="$s mon:mouse_move+$1+$2 sleep:0.2"; done; echo "$s"; }
    CMD="C:\\P.BAT" END="wait:MVRUN:_done:120 sleep:3" run pointer 60 "" "$OUT/P.BAT $OUT/CTMOUSE.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/PTRPRB.COM $TICK" \
        "wait:pptrprb_ready:60 sleep:3 $(mv -100 -100 10) $(mv 4 0 23) $(mv 0 8 4) $(mv 0 4 1) sleep:1 mon:mouse_button+1 sleep:0.5 mon:mouse_button+0 sleep:2 $(mv 4 0 8) $(mv 0 8 1) sleep:1 mon:mouse_button+2 sleep:0.5 mon:mouse_button+0"
    p1=$(file pointer P1.TXT | tr '\n' '|')
    echo "  P1: $p1"
    ph=$(echo "$p1" | sed -n 's/^ptr \([0-9A-F:]*\)|.*/\1/p')
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/pointer/end.txt'"
    check "left at 4,11 then right at 5,15, through the OBJECTQ (as DV)" "echo '$p1' | grep -q '|q1 $ph|p1 5 4 11 01|q2 $ph|p2 5 5 15 02|'"
    ;;
fieldops)
    echo "== fieldops:  broadcast F7h, scrolling F8h-FBh (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 20 C:\\BCSPRB.COM C:\\B1.TXT ; C:\\TICK.EXE C:\\T2.TXT\r\n' > "$OUT/B.BAT"
    CMD="C:\\B.BAT" END="wait:MVRUN:_done:120 sleep:3" run fieldops 20 "" "$OUT/B.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/BCSPRB.COM $TICK" \
        "wait:bcsprb_ready:60 sleep:3 key:z sleep:1 key:ret"
    b1=$(file fieldops B1.TXT | tr '\n' '|')
    echo "  B1: $b1"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/fieldops/end.txt'"
    check "zLLO_ / field 2 / _abc / 456___ (as DV)" "echo '$b1' | grep -q '^r 00000012 7A 4C 4C 4F 20 .. .. .. 20 61 62 63 34 35 36 20 20 20|st 00000000|hdr 04 01 01 00 70 70 A1 80|'"
    ;;
mouse)
    echo "== mouse:  a click on a select field (as under DV)"
    CTM=${CTMOUSE:-$HOME/mars/scratch-386max/ctm/bin/ctmouse.exe}
    if [ ! -f "$CTM" ]; then echo "  SKIP  no CuteMouse (CTMOUSE=path of ctmouse.exe)"; continue; fi
    cp "$CTM" "$OUT/CTMOUSE.EXE"
    printf 'C:\\CTMOUSE.EXE\r\nC:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 60 C:\\MSEPRB.COM C:\\M1.TXT ; C:\\TICK.EXE C:\\T2.TXT\r\n' > "$OUT/M.BAT"
    # CuteMouse's small moves are linear here:  8 counts a column or row
    mv() { local s="" i; for ((i = 0; i < $3; i++)); do s="$s mon:mouse_move+$1+$2 sleep:0.2"; done; echo "$s"; }
    CMD="C:\\M.BAT" END="wait:MVRUN:_done:120 sleep:3" run mouse 60 "" "$OUT/M.BAT $OUT/CTMOUSE.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MSEPRB.COM $TICK" \
        "wait:mseprb_ready:60 sleep:3 $(mv -100 -100 10) $(mv 4 0 25) $(mv 0 8 4) $(mv 0 4 1) sleep:1 mon:mouse_button+1 sleep:0.5 mon:mouse_button+0"
    m1=$(file mouse M1.TXT | tr '\n' '|')
    echo "  M1: $m1"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/mouse/end.txt'"
    check "click on field 2:  N Y N, status 1, 1Fh, C3h (as DV)" "[ '$m1' = 'r 00000003 4E 59 4E|st 00000001|at 07 1F 07|hdr 03 01 00 00 70 1F C0 C3 C0|' ]"
    ;;
records)
    echo "== records:  numbered field records, modes 10b/11b (as under DV)"
    for m in 2 3; do
        printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 20 C:\\NUMPRB.COM %s C:\\N%s.TXT ; C:\\TICK.EXE C:\\T2.TXT\r\n' $m $m > "$OUT/N$m.BAT"
        k=b; [ $m = 3 ] && k=c
        CMD="C:\\N$m.BAT" END="wait:MVRUN:_done:120 sleep:3" run records$m 20 "" "$OUT/N$m.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/NUMPRB.COM $TICK" \
            "wait:numprb_ready:60 sleep:3 key:a sleep:1 key:$k sleep:1 key:ret"
    done
    n2=$(file records2 N2.TXT | tr '\n' '|'); n3=$(file records3 N3.TXT | tr '\n' '|')
    echo "  N2: $n2"; echo "  N3: $n3"
    check "mode 10b:  all three, 'b' typed into field 1 (as DV)" "echo '$n2' | grep -q '^r 00000012 01 05 00 61 62 .. .. .. 02 01 00 4E 03 03 00 .. .. ..|st 00000000|hdr 03 42 01 00 70 1F 81 C0 80|'"
    check "mode 11b:  only the modified field 1 (as DV)" "echo '$n3' | grep -q '^r 00000008 01 05 00 61 63 .. .. ..|st 00000000|hdr 03 43 01 00 70 1F 81 C0 80|'"
    ;;
selects)
    echo "== selects:  select fields by key (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 20 C:\\SELPRB.COM C:\\S1.TXT ; C:\\TICK.EXE C:\\T2.TXT\r\n' > "$OUT/S.BAT"
    CMD="C:\\S.BAT" END="wait:MVRUN:_done:120 sleep:3" run selects 20 "" "$OUT/S.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/SELPRB.COM $TICK" \
        "wait:selprb_ready:60 sleep:3 key:x sleep:1 key:b"
    s1=$(file selects S1.TXT | tr '\n' '|')
    echo "  S1: $s1"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/selects/end.txt'"
    check "x ignored, b:  N Y N, status 1, field 2 in 1Fh and C3h (as DV)" "[ '$s1' = 'r 00000003 4E 59 4E|st 00000001|at 07 1F 07|hdr 03 41 00 00 70 1F C0 C3 C0|' ]"
    ;;
fields)
    echo "== fields:  input fields in field mode (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 20 C:\\FLDPRB.COM C:\\F1.TXT ; C:\\TICK.EXE C:\\T2.TXT\r\n' > "$OUT/F.BAT"
    CMD="C:\\F.BAT" END="wait:MVRUN:_done:120 sleep:3" run fields 20 "" "$OUT/F.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/FLDPRB.COM $TICK" \
        "wait:fldprb_ready:60 sleep:3 key:a sleep:1 key:b sleep:1 key:tab sleep:1 key:x sleep:1 key:ret"
    f1=$(file fields F1.TXT | tr '\n' '|')
    echo "  F1: $f1"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/fields/end.txt'"
    check "READ 05h:  8 bytes, field 1 'ab..', field 2 'x..' (as DV)" "echo '$f1' | grep -q '^r 00000008 61 62 .. .. .. 78 '"
    check "STATUS 0 (Enter), current field 2, both modified" "echo '$f1' | grep -q '|st 00000000|hdr 02 01 02 00 70 70 81 81|'"
    ;;
objq)
    echo "== objq:  the task's OBJECTQ (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 20 C:\\OBQPRB.COM C:\\Q1.TXT ; C:\\TICK.EXE C:\\T2.TXT\r\n' > "$OUT/Q.BAT"
    CMD="C:\\Q.BAT" END="wait:MVRUN:_done:120 sleep:3" run objq 20 "" "$OUT/Q.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/OBQPRB.COM $TICK" \
        "wait:obqprb_ready:60 sleep:3 key:x"
    q1=$(file objq Q1.TXT | tr '\n' '|')
    echo "  Q1: $q1"
    h() { echo "$q1" | sed -n "s/.*$1 \([0-9A-F:]*\)|.*/\1/p" | head -1; }
    kbd=$(h kbd); mbx=$(h mbx); tmr=$(h tmr)
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/objq/end.txt'"
    check "HANDLE 07h:  an OBJECTQ beside the keyboard" "echo '$q1' | grep -q '^obq [0-9A-F]*:0000|' && [ -n '$kbd' ]"
    check "READ 07h:  timer, mailbox, keyboard, timer again (as DV)" "echo '$q1' | grep -q '|r1 4 $tmr|r2 4 $mbx|r3 4 $kbd|r4 4 $tmr|'"
    ;;
kbd)
    echo "== kbd:  the task's keyboard object (as under DV)"
    printf 'C:\\MAXVTSR.COM\r\nC:\\MVRUN /F1 20 C:\\KBDPRB.COM C:\\K1.TXT ; C:\\TICK.EXE C:\\T2.TXT\r\n' > "$OUT/K.BAT"
    CMD="C:\\K.BAT" END="wait:MVRUN:_done:120 sleep:3" run kbd 20 "" "$OUT/K.BAT $ROOT/build/MAXVTSR.COM $ROOT/build/KBDPRB.COM $TICK" \
        "wait:kbdprb_ready:60 sleep:3 key:x sleep:3 key:f1 sleep:3 key:y"
    k1=$(file kbd K1.TXT | tr '\n' '|'); t2=$(last kbd T2.TXT tick)
    echo "  K1: $k1  TICK $t2"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/kbd/end.txt'"
    check "HANDLE 05h:  a keyboard" "echo '$k1' | grep -q '^kbd [0-9A-F]*:0000|' && ! echo '$k1' | grep -q '^kbd 0000'"
    check "READ 05h:  x, F1 as 00 with STATUS 3Bh, y (as DV)" "echo '$k1' | grep -q '|key 00000001 78 st 00000000|key 00000001 00 st 0000003B|key 00000001 79 st 00000000|'"
    check "TICK counts while READ waits" "[ $t2 -ge 20 ]"
    ;;
many)
    echo "== many:  16 task slots, 15 TICK tasks"
    : > "$OUT/L.TXT"
    for i in $(seq 1 16); do printf 'C:\\TICK.EXE C:\\T%d.TXT\r\n' $i >> "$OUT/L.TXT"; done
    FG="/N16 " run many 40 "@C:\\L.TXT" "$TICK $OUT/L.TXT"
    n=0 low=
    for i in $(seq 1 15); do
        t=$(last many T$i.TXT tick); [ $t -ge 10 ] && n=$((n + 1)) || low="$low $i:$t"
    done
    echo "  counting:  $n of 15${low:+ (low:$low)}"
    check "MVRUN ended" "grep -q 'MVRUN: done' '$OUT/many/end.txt'"
    check "15 tasks count (10 lines or more in 40 s)" "[ $n -eq 15 ]"
    check "the 16th did not start (table full)" "! mtype -i '$OUT/many/test.img@@32256' ::/T16.TXT >/dev/null 2>&1"
    ;;
progs)
    echo "== progs:  regression tests, each in a task of its own"
    printf '@ECHO OFF\r\nC:\\%%1 > C:\\%%1.OUT\r\nIF ERRORLEVEL 1 ECHO %%1 FAIL >> C:\\PROGS.TXT\r\nIF NOT ERRORLEVEL 1 ECHO %%1 PASS >> C:\\PROGS.TXT\r\n' > "$OUT/R.BAT"
    n=0
    for t in $PROGS; do
        [ -s "$MAXROOT/build/TESTS/$t.EXE" ] || { echo "  no $MAXROOT/build/TESTS/$t.EXE"; fail=1; continue; }
        ( FG="/F1 " run progs-$t 300 "C:\\COMMAND.COM /C C:\\R.BAT $t" "$OUT/R.BAT $MAXROOT/build/TESTS/$t.EXE" > /dev/null ) &
        ( CMD="C:\\R.BAT $t" END="sleep:1" run progs-ref-$t 0 "" "$OUT/R.BAT $MAXROOT/build/TESTS/$t.EXE" \
              "wait:$t:_[PF]A:200" > /dev/null ) &
        n=$((n + 2))
        [ $((n % JOBS)) = 0 ] && wait
    done
    wait
    for t in $PROGS; do
        r=$(file progs-$t PROGS.TXT | awk -v t=$t '$1 == t {print $2}')
        q=$(file progs-ref-$t PROGS.TXT | awk -v t=$t '$1 == t {print $2}')
        line=$(printf '%-9s MaxView %-5s alone %s' $t "${r:-hang}" "${q:-hang}")
        exp=$(eval echo "\${EXPECT_$t:-}")
        if [ "$r" = FAIL ] && [ -n "$exp" ] && [ -z "$(file progs-$t $t.OUT |
                grep -a FAIL | grep -v '^OK: ' | grep -v -F "$exp")" ]; then
            r=PASS line="$line  (expected:  $exp)"
        fi
        if [ "$r" = PASS ]; then echo "  OK    $line"
        elif [ "$q" != PASS ]; then echo "  OK    $line  (not alone either)"
        else echo "  FAIL  $line"; fail=1
        fi
    done
    ;;
*)  echo "unknown case $c"; exit 2 ;;
esac
done
if [ $fail = 0 ]; then echo PASS; else echo FAIL; exit 1; fi
