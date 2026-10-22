#!/bin/bash
# MaxView against DESQview 2.80:  the scenarios of tests/qemu/mvtest.sh in
# two DESQview windows (DESQview on Open 386MAX, as Open386MAX's
# linux/test/desqview.sh runs it) and in MaxView tasks; the measurements
# side by side.  MaxView must do at least what DESQview does.
#
#   tests/qemu/dvcompare.sh [two|dvapi|cwd|ems|gfx] [...]   (default: all)
#
#   two    TICK in the background, TICK in the foreground:  lines each
#          (a line a second while it runs)
#   dvapi  DVTASK B (counts) in window 1, DVTASK A (measures) in window 2:
#          BEGINC..ENDC holds the other task, PAUSE gives it more time
#   cwd    CWDPROBE \A and \B:  each window keeps its current directory
#   ems    EMSPROBE A and B:  each window keeps its EMS pages
#   gfx    GFXPROBE (VGA 13h) in window 1, KEYPROBE in window 2, back to
#          window 1:  the screens, the graphics task in the background
#
# DESQview is not free software:  its image stays local (DVIMG, default
# ~/mars/scratch-386max/dvbbs.img, the one of desqview.sh).  MAXROOT as in
# mvtest.sh.  Output:  build/test-dvcmp/<case>/ (DESQview runs), the
# MaxView runs in build/test-qemu/ (mvtest.sh).
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
MAXROOT=${MAXROOT:-$(cd "$ROOT/../Open386MAX" && pwd)}
OUT=$ROOT/build/test-dvcmp
MVOUT=$ROOT/build/test-qemu
DVIMG=${DVIMG:-$HOME/mars/scratch-386max/dvbbs.img}
TICK=$MAXROOT/build/TESTS/TICK.EXE
export MTOOLS_SKIP_CHECK=1
CASES=${*:-two dvapi cwd ems gfx}

[ -s "$DVIMG" ] || { echo "no DESQview image $DVIMG (DVIMG=)"; exit 2; }
[ -s "$TICK" ] || { echo "no $TICK (make -C $MAXROOT TESTS)"; exit 2; }
make -s -C "$ROOT" build/DVTASK.COM build/CWDPROBE.COM build/EMSPROBE.COM \
    build/GFXPROBE.COM build/KEYPROBE.COM build/MAXVTSR.COM || exit 2
mkdir -p "$OUT"
B=$ROOT/build

# DESQview loaded; open(keys, title):  a window through Open Window
READY='wait:Welcome_to:300 gone:Welcome_to:300 sleep:3'
open() { echo "key:alt wait:Open_Window:60 key:o wait:Big_DOS:60 key:$1 wait:$2:120 sleep:3"; }

dvrun() {   # case, steps, files:  boot DESQview, drive it
    local dir=$OUT/$1
    rm -rf "$dir"; mkdir -p "$dir"
    cp --sparse=always "$DVIMG" "$dir/dv.img"
    KEEP=1 KEEPCFG=1 AUTO='' ACCEL="-accel tcg" XFILES="$3" \
        QEMU_EXTRA="-serial file:$dir/com1.out" STEPS="$2" \
        TESTDIR="$dir/boot" "$MAXROOT/linux/test/dosboot.sh" "$dir/dv.img" \
        > "$dir/dosboot.log" 2>&1
    rm -f "$dir/dv.img"
}
dvfile() {  # case, file
    mtype -i "$OUT/$1/boot/test.img@@32256" ::/$2 2>/dev/null | tr -d '\r'
}
mvfile() {  # mvtest case, file
    mtype -i "$MVOUT/$1/test.img@@32256" ::/$2 2>/dev/null | tr -d '\r'
}
lastn() {   # word:  the number after its last line (stdin)
    awk -v w="$1" '$1 == w {n = $2 + 0} END {print n + 0}'
}
row() { printf '  %-34s %-22s %s\n' "$1" "$2" "$3"; }

# the DESQview runs, all at once
for c in $CASES; do
case $c in
two)
    dvrun two "$READY $(open d,1 _1__DOS) type:C:\\TICK_C:\\T1.TXT sleep:3 $(open d,1 _2__DOS) type:C:\\TICK_C:\\T2.TXT sleep:30 text:run" "$TICK" & ;;
dvapi)
    dvrun dvapi "$READY $(open d,1 _1__DOS) type:C:\\DVTASK_B_C:\\D2.TXT sleep:3 $(open d,1 _2__DOS) type:C:\\DVTASK_A_C:\\D1.TXT sleep:40 text:run" "$B/DVTASK.COM" & ;;
cwd)
    dvrun cwd "$READY $(open d,1 _1__DOS) type:MD_C:\\A type:MD_C:\\B type:C:\\CWDPROBE_\\A_C:\\W1.TXT sleep:2 $(open d,1 _2__DOS) type:C:\\CWDPROBE_\\B_C:\\W2.TXT sleep:30 text:run" "$B/CWDPROBE.COM" & ;;
ems)
    # (Big DOS windows:  the DOS window's DVP has no EMS)
    dvrun ems "$READY $(open b,d Version_6.22) type:C:\\EMSPROBE_C:\\E1.TXT_A sleep:2 $(open b,d Version_6.22) type:C:\\EMSPROBE_C:\\E2.TXT_B sleep:30 text:run" "$B/EMSPROBE.COM" & ;;
gfx)
    dvrun gfx "$READY $(open d,1 _1__DOS) type:C:\\GFXPROBE_C:\\G1.TXT sleep:6 shot:gfx1 $(open d,1 _2__DOS) type:C:\\KEYPROBE_C:\\K2.TXT_D wait:keyprobe_D_ready:30 text:fg2 sleep:6 key:alt sleep:2 key:s sleep:2 key:1 sleep:4 shot:gfx3 key:dot sleep:4 text:run" "$B/GFXPROBE.COM $B/KEYPROBE.COM" & ;;
*)  echo "unknown case $c"; exit 2 ;;
esac
done
wait
# the MaxView runs
"$ROOT/tests/qemu/mvtest.sh" $CASES > "$OUT/mvtest.log" 2>&1
mvres=$(tail -1 "$OUT/mvtest.log")

green() {   # share of colour 2 (0,170,0) in a screendump, percent
    python3 -c "
import sys
from PIL import Image
im=Image.open(sys.argv[1]).convert('RGB'); w,h=im.size
n=sum(c for c,(r,g,b) in im.getcolors(w*h) if r<40 and g>150 and b<40)
print(n*100//(w*h))" "$1" 2>/dev/null || echo 0
}

echo "== MaxView against DESQview 2.80 (both on Open 386MAX)"
row "" "DESQview" "MaxView"
for c in $CASES; do
case $c in
two)
    d1=$(dvfile two T1.TXT | lastn tick); d2=$(dvfile two T2.TXT | lastn tick)
    m1=$(mvfile two T1.TXT | lastn tick); m2=$(mvfile two T2.TXT | lastn tick)
    row "two:  lines bg / fg" "$d1 / $d2 (30 s)" "$m1 / $m2 (30 s)" ;;
dvapi)
    for s in dv mv; do
        if [ $s = dv ]; then a=$(dvfile dvapi D1.TXT); b=$(dvfile dvapi D2.TXT)
        else a=$(mvfile dvapi D1.TXT); b=$(mvfile dvapi D2.TXT); fi
        aa=$(echo "$a" | awk '$1 == "app" {print $2}'); ab=$(echo "$b" | awk '$1 == "app" {print $2}')
        # in start order:  DV opens B (window 1) before A, MVRUN starts A first
        if [ $s = dv ]; then app="$ab/$aa"; else app="$aa/$ab"; fi
        crit=$(echo "$a" | awk '$1 == "crit" {print ($2 == $3 ? "held" : "NOT held") ($4 > $3 ? ", runs after" : ", NOT after")}')
        pause=$(echo "$a" | awk '$1 == "pause" && $2 > 0 {printf "x%.1f", $3 / $2}')
        eval "app_$s=\$app crit_$s=\"\$crit\" pause_$s=\$pause"
    done
    row "dvapi:  APPNUM 1st/2nd started" "$app_dv" "$app_mv"
    row "dvapi:  BEGINC..ENDC" "${crit_dv:-?}" "${crit_mv:-?}"
    row "dvapi:  PAUSE (other task's share)" "${pause_dv:-?}" "${pause_mv:-?}"
    row "dvapi:  DV version (2B01h)" "$(dvfile dvapi D1.TXT | awk '$1 == "app" {print $4}')" "$(mvfile dvapi D1.TXT | awk '$1 == "app" {print $4}')"
    row "dvapi:  40:F0h" "$(dvfile dvapi D1.TXT | awk '$1 == "ica" {print $2}')" "$(mvfile dvapi D1.TXT | awk '$1 == "ica" {print $2}')"
    row "dvapi:  error policy (DE15h)" "$(dvfile dvapi D1.TXT | awk '$1 == "err" {print $2}')" "$(mvfile dvapi D1.TXT | awk '$1 == "err" {print $2}')" ;;
cwd)
    row "cwd:  window 1, 2" "$(dvfile cwd W1.TXT), $(dvfile cwd W2.TXT)" \
        "$(mvfile cwd W1.TXT), $(mvfile cwd W2.TXT)" ;;
ems)
    row "ems:  window 1, 2" "$(dvfile ems E1.TXT | tr -s ' '), $(dvfile ems E2.TXT | tr -s ' ')" \
        "$(mvfile ems E1.TXT | tr -s ' '), $(mvfile ems E2.TXT | tr -s ' ')" ;;
gfx)
    dk=no; grep -q 'keyprobe D ready' "$OUT/gfx/boot/fg2.txt" 2>/dev/null && dk=yes
    mk=no; grep -q 'keyprobe D ready' "$MVOUT/gfx/fg2.txt" 2>/dev/null && mk=yes
    row "gfx:  graphics shown (green %)" "$(green $OUT/gfx/boot/gfx1.png)" "$(green $MVOUT/gfx/gfx1.png)"
    row "gfx:  text window after it" "$dk" "$mk"
    row "gfx:  graphics back (green %)" "$(green $OUT/gfx/boot/gfx3.png)" "$(green $MVOUT/gfx/gfx3.png)"
    row "gfx:  GFXPROBE" "$(dvfile gfx G1.TXT)" "$(mvfile gfx G1.TXT)" ;;
esac
done
echo "  MaxView checks (mvtest.sh):  $mvres"
