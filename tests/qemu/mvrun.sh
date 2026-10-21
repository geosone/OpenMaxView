#!/bin/bash
# The multitasking core on real Open 386MAX in QEMU:  MS-DOS 6.22 with
# 386MAX (Open386MAX's linux/test/dosboot.sh and its test images), MVRUN
# runs two TICK tasks (Open386MAX TESTS/SCENARIO/TICK:  a line a second
# into a file) for SECS seconds.  Both must count.
#
#   tests/qemu/mvrun.sh            (MAXROOT=../Open386MAX, SECS=30)
#
# Output:  build/test-qemu/mvrun/ (screen texts, test.img)
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
MAXROOT=${MAXROOT:-$(cd "$ROOT/../Open386MAX" && pwd)}
SECS=${SECS:-30}
OUT=$ROOT/build/test-qemu/mvrun
TICK=$MAXROOT/build/TESTS/TICK.EXE
export MTOOLS_SKIP_CHECK=1
[ -s "$TICK" ] || { echo "no $TICK (make -C $MAXROOT TESTS)"; exit 2; }
# MVDEBUG=1:  the core traces to port E9h ($OUT.e9)
rm -f "$ROOT/build/mvkern.obj" "$ROOT/build/MVRUN.EXE"
make -s -C "$ROOT" MVDEBUG=${MVDEBUG:-0} build/MVRUN.EXE || exit 2
rm -rf "$OUT"; mkdir -p "$OUT"
KEEP=1 ACCEL="-accel tcg" QEMU_EXTRA="-debugcon file:$OUT.e9" XFILES="$ROOT/build/MVRUN.EXE $TICK" \
    AUTO="C:\\MVRUN $SECS C:\\TICK.EXE C:\\T1.TXT ; C:\\TICK.EXE C:\\T2.TXT" \
    STEPS="wait:MVRUN:_done:$((SECS * 3 + 120)) text:end" TESTDIR="$OUT" \
    "$MAXROOT/linux/test/dosboot.sh" msdos622 > "$OUT.log" 2>&1
grep -v '^\s*$' "$OUT/end.txt" "$OUT/fail.txt" 2>/dev/null | tail -8
count() { mtype -i "$OUT/test.img@@32256" ::/$1 2>/dev/null | tr -d '\r' |
          awk '$1 == "tick" {n = $2 + 0} END {print n + 0}'; }
t1=$(count T1.TXT); t2=$(count T2.TXT)
echo "T1 $t1, T2 $t2 (of about $SECS each)"
fail=0
[ "$t1" -ge $((SECS / 3)) ] || fail=1
[ "$t2" -ge $((SECS / 3)) ] || fail=1
grep -q "MVRUN: done" "$OUT/end.txt" 2>/dev/null || fail=1
[ $fail = 0 ] && echo PASS || { echo FAIL; exit 1; }
