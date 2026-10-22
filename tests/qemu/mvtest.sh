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
CASES=${*:-two mem serial keys kill crit desk win dvapi cwd ems gfx many progs}
PROGS=${PROGS:-XMSFUNC XMSLOCK EMSFUNC EMSMORE VCPIFUNC VDSFUNC V86FUNC INT15 A20 DPMIMISC RMCBNEST PMSTACK}
JOBS=${JOBS:-6}
EXPECT_VDSFUNC='physical = linear FAIL'
[ -s "$TICK" ] || { echo "no $TICK (make -C $MAXROOT TESTS)"; exit 2; }
rm -f "$ROOT/build/mvkern.obj" "$ROOT/build/MVRUN.EXE"
make -s -C "$ROOT" MVDEBUG=${MVDEBUG:-0} build/MVRUN.EXE build/MEMPROBE.COM \
    build/KEYPROBE.COM build/CRITPRB.COM build/MAXVIEW.EXE build/DVTASK.COM \
    build/MAXVTSR.COM build/CWDPROBE.COM build/EMSPROBE.COM build/GFXPROBE.COM || exit 2
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
