#!/usr/bin/env bash
# Build the browser version of the game into build/web/.
#
#   tools/export_web.sh                 # verify, then export
#   SKIP_VERIFY=1 tools/export_web.sh   # export only
#   GODOT_WEB_THREADS=0 tools/export_web.sh   # single-threaded build (no
#                                             # cross-origin isolation needed)
#
# Fetches a Godot 4.7 binary and just the web export templates if they are
# missing. Nothing about the game changes: this is the same project the
# desktop build and tools/verify.sh use.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${OUT:-build/web}"
GODOT="$(tools/ensure_godot.sh)"
echo "== using $("$GODOT" --version)"

THREADS="${GODOT_WEB_THREADS:-1}"
TEMPLATES="web_release.zip"
if [ "$THREADS" = "0" ]; then
  # A single-threaded build runs on any static host, with no cross-origin
  # isolation headers; it is slower, so it is not the default.
  echo "== single-threaded variant (no SharedArrayBuffer needed)"
  TEMPLATES="web_nothreads_release.zip"
  cp export_presets.cfg export_presets.cfg.orig
  trap 'mv -f export_presets.cfg.orig export_presets.cfg' EXIT
  sed -i 's|^variant/thread_support=true|variant/thread_support=false|' export_presets.cfg
fi
GODOT_WEB_TEMPLATES="$TEMPLATES" node tools/fetch_web_templates.mjs

echo "== importing assets (first run takes a couple of minutes)"
"$GODOT" --headless --path . --import 2>&1 | grep -iE "^error|failed to load" || true

if [ "${SKIP_VERIFY:-0}" != "1" ]; then
  echo "== verifying the game before shipping it"
  LOG="$(mktemp)"
  set +e
  "$GODOT" --headless --path . res://tools/verify.tscn > "$LOG" 2>&1
  STATUS=$?
  set -e
  grep -E "^FAIL|^== |SCRIPT ERROR|route solver" "$LOG" || true
  rm -f "$LOG"
  if [ "$STATUS" -ne 0 ]; then
    echo "!! verification failed - refusing to build a broken deploy" >&2
    exit 1
  fi
fi

echo "== exporting"
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html" 2>&1 \
  | grep -viE "ALSA|pulse|snd_|status < 0|savepack|Storing File|^\s*$" | tail -5
test -s "$OUT/index.html" && test -s "$OUT/index.wasm" && test -s "$OUT/index.pck"
if grep -q '\$GODOT_' "$OUT/index.html"; then
  echo "!! unsubstituted placeholders in the HTML shell:" >&2
  grep -o '\$GODOT_[A-Z_]*' "$OUT/index.html" | sort -u >&2
  exit 1
fi
# a page served without the isolation headers cannot start a threaded build
cp -f web/_headers "$OUT/_headers" 2>/dev/null || true
echo "== built $OUT ($(du -sh "$OUT" | cut -f1))"
ls -la "$OUT" | awk 'NR>1 {printf "   %-34s %8.1f KB\n", $9, $5/1024}'
