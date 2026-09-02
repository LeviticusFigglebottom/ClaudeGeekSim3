#!/usr/bin/env bash
# Print the path to a Godot 4.7 binary, downloading it into .bin/ when needed.
# Logs go to stderr so the path is the only thing on stdout:
#   GODOT="$(tools/ensure_godot.sh)"
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.7-stable}"

if [ -n "${GODOT:-}" ] && [ -x "${GODOT}" ]; then echo "${GODOT}"; exit 0; fi
if [ -x "${ROOT}/.bin/godot" ]; then echo "${ROOT}/.bin/godot"; exit 0; fi
if command -v godot >/dev/null 2>&1; then command -v godot; exit 0; fi

ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/${ZIP}"
echo "[godot] downloading ${GODOT_VERSION}" >&2
mkdir -p "${ROOT}/.bin"
curl -sSfL -o "${ROOT}/.bin/${ZIP}" "${URL}" >&2
# build machines do not all ship a working unzip, so fall back to node
if ! { command -v unzip >/dev/null 2>&1 && unzip -o -q "${ROOT}/.bin/${ZIP}" -d "${ROOT}/.bin" >&2; }; then
  echo "[godot] unzip unavailable; extracting with node" >&2
  node "${ROOT}/tools/unzip.mjs" "${ROOT}/.bin/${ZIP}" "${ROOT}/.bin" >&2
fi
BINARY="${ROOT}/.bin/Godot_v${GODOT_VERSION}_linux.x86_64"
if [ ! -f "${BINARY}" ]; then
  echo "[godot] the archive did not contain ${BINARY##*/}" >&2
  exit 1
fi
mv "${BINARY}" "${ROOT}/.bin/godot"
chmod +x "${ROOT}/.bin/godot"
rm -f "${ROOT}/.bin/${ZIP}"
echo "${ROOT}/.bin/godot"
