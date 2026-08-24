#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -m)" != "arm64" ]]; then
  printf 'ERROR: This compatibility entry point requires Apple Silicon arm64.\n' >&2
  printf 'Run %s/build_drm_receiver_macos.sh on this Mac instead.\n' "$SCRIPT_DIR" >&2
  exit 1
fi

exec "$SCRIPT_DIR/build_drm_receiver_macos.sh" "$@"
