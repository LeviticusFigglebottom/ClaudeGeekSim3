#!/usr/bin/env bash
# Visual QA tour: renders every registered area from its default spawn (and a
# few extra views) into screenshots/tour/. Needs Xvfb + a Godot binary.
#   tools/screenshots.sh            # all areas
#   tools/screenshots.sh forest sea # subset
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=screenshots/tour
mkdir -p "$OUT"
AREAS=("$@")
if [ ${#AREAS[@]} -eq 0 ]; then
  AREAS=(apartment corridor hallway nexus forest city tavern house castle sea catacombs furnace cistern offices clocktower static mirror_nexus workshop)
fi
for a in "${AREAS[@]}"; do
  tools/shot.sh "$a" "$OUT/${a}_default.png" default "0,-6" | grep -E "shot\]|SCRIPT ERROR" || true
  tools/shot.sh "$a" "$OUT/${a}_turn.png" default "150,-4" | grep -E "shot\]|SCRIPT ERROR" || true
done
python3 - "$OUT" <<'PY'
import sys, glob
from pathlib import Path
sys.path.insert(0, "tools/gen_assets")
import texgen as T
out = Path(sys.argv[1])
paths = sorted(out.glob("*.png"))
if paths:
    T.contact_sheet(paths, out / "contact_sheet.png", cell=320, cols=4)
    print("contact sheet:", out / "contact_sheet.png")
PY
