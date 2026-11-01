#!/bin/bash
# shot.sh <worktree> <outdir>; env CB_SCENARIOS CB_HOVER CB_LAYOUT CB_APPEARANCES. Pops real menus on that branch's sources.
WT=$1; OUT=$2; R=/tmp/cb-ship-render
mkdir -p "$OUT"; rm -f "$OUT/.request" "$OUT/.done"
rsync -a --delete "$WT/Sources/" $R/Sources/
git -C $R checkout -q -- Package.swift
python3 /tmp/cb-mb-kit/patch_package.py $R
mkdir -p $R/RedesignProof; rm -f $R/RedesignProof/*.swift; cp /tmp/ship-menu5/kit/*.swift $R/RedesignProof/
( while [ ! -f "$OUT/.done" ]; do
    if [ -f "$OUT/.request" ]; then read -r ID DEST < "$OUT/.request"; [ "$ID" != 0 ] && screencapture -x -l"$ID" "$DEST"; rm -f "$OUT/.request"; fi
    perl -e 'select(undef,undef,undef,0.1)'
  done ) &
W=$!
cd $R && CB_CMD=test CB_OUT="$OUT" /tmp/cb-mb-kit/build.sh --filter "ShipProof" > "$OUT/.log" 2>&1
touch "$OUT/.done"; wait $W 2>/dev/null
grep -E 'error:|Test run with' "$OUT/.log" | grep -v '`-' | sort -u | cut -c1-200 | head; cat "$OUT/live-sizes.txt" 2>/dev/null | grep -v " items \| rows " ; ls "$OUT" | grep png
