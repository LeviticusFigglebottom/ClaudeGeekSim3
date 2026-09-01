#!/usr/bin/env bash
# Render one screenshot of an area with software OpenGL (no GPU needed).
#   tools/shot.sh <area_id> <out.png> [spawn] [yaw,pitch] [extra godot user args...]
# Requires Xvfb (xvfb-run) and a Godot 4.7 binary at ./.bin/godot or $GODOT.
set -euo pipefail
AREA="${1:?area id}"; OUT="${2:?output png}"; SPAWN="${3:-default}"; LOOK="${4:-}"
shift $(( $# >= 4 ? 4 : $# ))
GODOT="${GODOT:-$(dirname "$0")/../.bin/godot}"
ARGS=(--path "$(dirname "$0")/.." --rendering-driver opengl3 --resolution 1280x720 --quit-after 400 -- "--area=$AREA" "--spawn=$SPAWN" "--shot=$OUT")
if [ -n "$LOOK" ]; then ARGS+=("--look=$LOOK"); fi
ARGS+=("$@")
export LIBGL_ALWAYS_SOFTWARE=1
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" "${ARGS[@]}" 2>&1 \
  | grep -vE "ALSA lib|libpulse|audio driver|snd_pcm|audio_driver_alsa|Condition \"status < 0\"|V-Sync|set_use_vsync|^\s*$" || true
