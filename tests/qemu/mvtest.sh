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
CASES=${*:-two mem serial keys kill crit desk deskmany win dvapi cwd ems gfx objs ipc kbd objq fields selects records mouse wwrite wstream wquery crtc many progs}
PROGS=${PROGS:-XMSFUNC XMSLOCK EMSFUNC EMSMORE VCPIFUNC VDSFUNC V86FUNC INT15 A20 DPMIMISC RMCBNEST PMSTACK}
JOBS=${JOBS:-6}
EXPECT_VDSFUNC='physical = linear FAIL'
[ -s "$TICK" ] || { echo "no $TICK (make -C $MAXROOT TESTS)"; exit 2; }
rm -f "$ROOT/build/mvkern.obj" "$ROOT/build/MVRUN.EXE"
make -s -C "$ROOT" MVDEBUG=${MVDEBUG:-0} build/MVRUN.EXE build/MEMPROBE.COM \
    build/KEYPROBE.COM build/CRITPRB.COM build/MAXVIEW.EXE build/DVTASK.COM \
    build/MAXVTSR.COM build/CWDPROBE.COM build/EMSPROBE.COM build/GFXPROBE.COM build/LEAKPRB.COM build/IPCPRB.COM || exit 2
mkdir -p "$OUT"
fail=0

run() {     # case, seconds, MVRUN task list, more files, steps before the end
    local dir=$OUT/$1
    rm -rf "$dir"; mkdir -p "$dir"
    KEEP=1 ACCEL="-accel tcg" XFILES="$ROOT/build/MVRUN.EXE ${4:-}" \
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
    echo "== desk:  MAXVIEW.EXE runs programs as tasks"
    cfg=$OUT/MAXVIEW.CFG
    printf 'T|Tick counter|C:\\TICK.EXE C:\\T1.TXT||64|640\r\nK|Key probe|C:\\KEYPROBE.COM C:\\K2.TXT D||64|640\r\n' > "$cfg"
    CMD="C:\\MAXVIEW" END="wait:desk_end:30" run desk 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/KEYPROBE.COM $TICK $cfg" \
        "wait:Open_Program:60 text:desk0 key:ret sleep:3 text:tick key:alt wait:Tab_next:20 text:desk1 key:o wait:Open_Program:20 key:down key:ret wait:keyprobe_D_ready:20 key:x,y sleep:1 key:alt wait:Tab_next:20 key:o wait:Open_Program:20 key:t wait:Enter:_switch:10 text:tasks key:down key:ret wait:keyprobe_D_ready:20 key:z key:dot wait:Key_probe_ended:20 text:ended sleep:3 key:esc wait:exit_to_DOS:10 text:confirm key:y gone:Open_Program:20 sleep:2 type:echo_desk_end"
    d=$OUT/desk
    k2=$(file desk K2.TXT); t1=$(last desk T1.TXT tick)
    echo "  K2 '$k2', T1 $t1"
    check "desktop up, multitasking" "grep -q 'Open Program' '$d/desk0.txt' && ! grep -q 'One program at a time' '$d/desk0.txt'"
    check "TICK on its own screen" "[ -f '$d/tick.txt' ] && ! grep -q 'Open Program' '$d/tick.txt'"
    check "Alt back to MaxView (windows)" "grep -q 'Tick counter' '$d/desk1.txt' && grep -q 'Tab next' '$d/desk1.txt'"
    check "task list" "grep -q 'Tick counter' '$d/tasks.txt' && grep -q 'Key probe' '$d/tasks.txt'"
    check "KEYPROBE got its keys" "[ '$k2' = xyz ]"
    check "end reported" "grep -q 'Key probe ended' '$d/ended.txt' && grep -q 'code 0' '$d/ended.txt'"
    check "exit closes TICK" "grep -q 'Close 1 running' '$d/confirm.txt'"
    check "TICK counted meanwhile" "[ $t1 -ge 10 ]"
    check "DOS works afterwards" "grep -q '^desk end' '$d/end.txt'"
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
    for i in $(seq 2 12); do
        # (the menu keeps the last selection:  one down to the next)
        st="$st key:alt wait:Tab_next:20 key:o wait:Open_Program:20 key:down key:ret sleep:3"
    done
    st="$st wait:keyprobe_D_ready:20 key:alt wait:Tab_next:20 key:o wait:Open_Program:20 key:t wait:Enter:_switch:10 text:list1"
    for j in $(seq 1 11); do st="$st key:down"; done
    st="$st sleep:1 text:list2 key:ret sleep:2 key:k key:dot wait:Key_probe_ended:20 text:ended sleep:2 key:esc wait:exit_to_DOS:10 text:confirm key:y gone:Open_Program:30 sleep:2 type:echo_deskmany_end"
    CMD="C:\\MAXVIEW" END="wait:deskmany_end:60" run deskmany 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/KEYPROBE.COM $TICK $cfg" "$st"
    d=$OUT/deskmany
    k=$(file deskmany K12.TXT); n=0
    for i in $(seq 1 11); do [ $(last deskmany T$i.TXT tick) -ge 5 ] && n=$((n + 1)); done
    echo "  K12 '$k', TICKs counting $n of 11"
    check "list:  the first 10 rows" "grep -q ' 1  Tick 1 ' '$d/list1.txt' && grep -q ' A  Tick 10 ' '$d/list1.txt' && ! grep -q 'Key probe' '$d/list1.txt'"
    check "list scrolled:  B, C at the end" "grep -q ' B  Tick 11 ' '$d/list2.txt' && grep -q ' C  Key probe ' '$d/list2.txt' && ! grep -q ' 1  Tick 1 ' '$d/list2.txt'"
    check "Ctrl+Alt only for 1-9" "grep -q 'Tick 9 .*Ctrl+Alt+9' '$d/list1.txt' && ! grep -q 'Tick 10 .*Ctrl+Alt' '$d/list1.txt'"
    check "Enter on C:  KEYPROBE gets the keys" "[ '$k' = k ]"
    check "11 TICKs count" "[ $n -eq 11 ]"
    check "exit closes 11" "grep -q 'Close 11 running' '$d/confirm.txt'"
    check "DOS works afterwards" "grep -q '^deskmany end' '$d/end.txt'"
    ;;
win)
    echo "== win:  windows of several tasks"
    cfg=$OUT/MAXVIEW.CFG
    printf 'A|Probe A|C:\\KEYPROBE.COM C:\\W1.TXT D||64|640\r\nB|Probe B|C:\\KEYPROBE.COM C:\\W2.TXT B||64|640\r\n' > "$cfg"
    CMD="C:\\MAXVIEW" END="wait:win_end:30" run win 0 "" \
        "$ROOT/build/MAXVIEW.EXE $ROOT/build/MAXVTSR.COM $ROOT/build/MAXVANSI.COM $ROOT/build/KEYPROBE.COM $cfg" \
        "wait:Open_Program:60 key:ret wait:keyprobe_D_ready:20 key:alt wait:Tab_next:20 key:o wait:Open_Program:20 key:down key:ret wait:keyprobe_B_ready:20 key:alt wait:Tab_next:20 sleep:1 text:two key:tab sleep:1 key:ret sleep:1 key:a,b sleep:2 text:typed key:alt sleep:1 key:m key:right,right,right,down sleep:1 key:ret sleep:1 text:moved key:z sleep:2 text:full key:alt wait:Tab_next:20 key:c wait:Probe_A_ended:20 text:closed key:q wait:exit_to_DOS:10 key:y gone:Tab_next:20 sleep:2 type:echo_win_end"
    d=$OUT/win
    w1=$(file win W1.TXT)
    c1=$(awk '/1 Probe A/ {print NR*100 + index($0, "1 Probe A"); exit}' "$d/typed.txt" 2>/dev/null)
    c2=$(awk '/1 Probe A/ {print NR*100 + index($0, "1 Probe A"); exit}' "$d/moved.txt" 2>/dev/null)
    echo "  W1 '$w1', title at $c1 -> $c2"
    check "both windows on one screen" "grep -q 'keyprobe D ready' '$d/two.txt' && grep -q 'keyprobe B ready' '$d/two.txt'"
    check "typing into a window" "grep -q 'Typing into Probe A' '$d/typed.txt' && grep -q 'ab' '$d/typed.txt'"
    check "window keys to its task" "[ '$w1' = ab ]"
    check "window moved (3 right, 1 down)" "[ -n '$c1' ] && [ \$(( ${c2:-0} - ${c1:-0} )) -eq 103 ]"
    check "zoom:  full screen" "grep -q 'keyprobe D ready' '$d/full.txt' && ! grep -q 'Tab next' '$d/full.txt'"
    check "close" "grep -q 'Probe A ended' '$d/closed.txt' && ! grep -q 'keyprobe D' '$d/closed.txt'"
    check "DOS works afterwards" "grep -q '^win end' '$d/end.txt'"
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
