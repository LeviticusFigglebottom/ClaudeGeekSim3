#!/usr/bin/env bash
# Preview the browser build locally, with the headers a real host must send.
#   tools/serve_web.sh [port]
set -euo pipefail
cd "$(dirname "$0")/.."
exec node tools/serve_web.mjs --port "${1:-8060}"
