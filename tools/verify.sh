#!/usr/bin/env bash
# Headless verification: imports the project and runs tools/verify.gd.
# tools/ensure_godot.sh downloads Godot 4.7 into .bin/ if no binary is found.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="$(tools/ensure_godot.sh)"
echo "Using $($GODOT --version)"
filter() { grep -vE "ALSA lib|libpulse|audio driver|snd_pcm|audio_driver_alsa|Condition \"status < 0\"|V-Sync|set_use_vsync|^\s*$" || true; }
echo "== import =="
"$GODOT" --headless --path . --import 2>&1 | grep -iE "error|fail" | filter || true
echo "== verify =="
set +e
"$GODOT" --headless --path . res://tools/verify.tscn -- "$@" 2>&1 | filter
STATUS=${PIPESTATUS[0]}
set -e
if [ "$STATUS" -ne 0 ]; then exit "$STATUS"; fi
echo "== playtest (input-driven smoke test) =="
set +e
timeout 180 "$GODOT" --headless --path . -- --area=apartment --spawn=bed --playtest 2>&1 | filter | grep -E "playtest|SCRIPT ERROR|^\s+at:"
STATUS=${PIPESTATUS[0]}
set -e
if [ "$STATUS" -ne 0 ]; then exit "$STATUS"; fi
echo "== brooks (walk every seam of the King's Dream) =="
set +e
timeout 240 "$GODOT" --headless --path . -- --area=kings_dream --spawn=from_king --give=wings,hourglass --flag=maze_walked,dream_king_reached,dream_rush,dream_egg_fell,dream_seated,dream_charge_read --brooks 2>&1 | filter | grep -E "brooks|SCRIPT ERROR|^\s+at:"
STATUS=${PIPESTATUS[0]}
set -e
exit "$STATUS"
