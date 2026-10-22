#!/bin/bash
# The multitasking core on real Open 386MAX in QEMU:  MS-DOS 6.22 with
# 386MAX (Open386MAX's linux/test/dosboot.sh and its test images); MVRUN
# runs the tasks of a case.  The cases follow Open386MAX's
# linux/test/desqview.sh (DESQview 2.80 on 386MAX is the bar).
#
#   tests/qemu/mvtest.sh [two|mem|serial|keys|kill|crit] [...]       (default: all)
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
CASES=${*:-two mem serial keys kill crit}
[ -s "$TICK" ] || { echo "no $TICK (make -C $MAXROOT TESTS)"; exit 2; }
rm -f "$ROOT/build/mvkern.obj" "$ROOT/build/MVRUN.EXE"
make -s -C "$ROOT" MVDEBUG=${MVDEBUG:-0} build/MVRUN.EXE build/MEMPROBE.COM \
    build/KEYPROBE.COM build/CRITPRB.COM || exit 2
mkdir -p "$OUT"
fail=0

run() {     # case, seconds, MVRUN task list, more files, steps before the end
    local dir=$OUT/$1
    rm -rf "$dir"; mkdir -p "$dir"
    KEEP=1 ACCEL="-accel tcg" XFILES="$ROOT/build/MVRUN.EXE ${4:-}" \
        QEMU_EXTRA="-debugcon file:$OUT/$1.e9 ${SERIAL:--serial file:$OUT/$1.com1}" \
        AUTO="C:\\MVRUN ${FG:-}$2 $3" \
        STEPS="${5:-} wait:MVRUN:_done:$(($2 * 3 + 120)) text:end" TESTDIR="$dir" \
        "$MAXROOT/linux/test/dosboot.sh" msdos622 > "$OUT/$1.log" 2>&1
    grep -q "MVRUN: done" "$dir/end.txt" 2>/dev/null ||
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
    check "same PSP segment (private memory)" "[ -n \"\$m1\" ] && [ \"\$(echo \$m1 | awk '{print \$2}')\" = \"\$(echo \$m2 | awk '{print \$2}')\" ]"
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
*)  echo "unknown case $c"; exit 2 ;;
esac
done
if [ $fail = 0 ]; then echo PASS; else echo FAIL; exit 1; fi
