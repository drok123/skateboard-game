#!/usr/bin/env bash
# Cloud Agent start: bring up a virtual X display for running the game GUI.
# Idempotent — detects an already-running server and returns without duplicates.
set -euo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

# Headless display :99 sized to the game's 1280x720 window.
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
  Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset \
    >/tmp/xvfb-99.log 2>&1 &
  # Wait briefly for the server to accept connections.
  for _ in $(seq 1 25); do
    xdpyinfo -display :99 >/dev/null 2>&1 && break
    sleep 0.2
  done
fi

echo "Virtual display :99 ready for 'godot' (see .cursor/run-game.sh)."
