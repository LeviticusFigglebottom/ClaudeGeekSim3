#!/usr/bin/env bash
# Headless verification: imports the project and runs tools/verify.gd.
# Downloads Godot 4.7 into .bin/ if no binary is found (Linux x86_64).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_VERSION="${GODOT_VERSION:-4.7-stable}"
GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
  if [ -x .bin/godot ]; then GODOT=.bin/godot
  elif command -v godot >/dev/null 2>&1; then GODOT=godot
  else
    mkdir -p .bin
    ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    echo "Downloading Godot ${GODOT_VERSION}..."
    curl -sSL -o ".bin/${ZIP}" "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/${ZIP}"
    (cd .bin && unzip -o -q "${ZIP}" && mv "Godot_v${GODOT_VERSION}_linux.x86_64" godot && chmod +x godot && rm "${ZIP}")
    GODOT=.bin/godot
  fi
fi
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
exit "$STATUS"
