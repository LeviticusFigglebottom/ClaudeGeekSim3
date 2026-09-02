#!/usr/bin/env bash
# What Vercel runs. The build machine has no Godot and no export templates, so
# fetch them (about 60 MB, a few seconds) and export the browser build.
#
# Environment:
#   SKIP_VERIFY=1        skip the world-graph check before exporting
#   GODOT_WEB_THREADS=0  single-threaded build (works without the isolation
#                        headers, at a cost in speed)
#   GODOT_VERSION        default 4.7-stable
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== ANTEROOM web build on ${VERCEL:+Vercel }${VERCEL_ENV:-local}"
node --version
if [ -s build/web/index.html ] && [ "${USE_PREBUILT_WEB:-0}" = "1" ]; then
  echo "== using the prebuilt build/web committed to the repository"
  exit 0
fi
exec tools/export_web.sh
