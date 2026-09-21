#!/usr/bin/env bash
# Cloud Agent install: prepare a headless-renderable Godot 4 environment.
# Idempotent — safe to re-run against a cached/snapshotted machine.
set -euo pipefail

GODOT_VERSION="4.2.2-stable"
GODOT_BIN="${HOME}/bin/godot"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- System packages -------------------------------------------------------
# Godot renders Forward+ (Vulkan) which we drive with Mesa's software rasterizer
# (lavapipe/llvmpipe) plus a virtual X display, so the game runs without a GPU.
if ! dpkg -s mesa-vulkan-drivers >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    mesa-vulkan-drivers libvulkan1 vulkan-tools \
    libgl1-mesa-dri libglx-mesa0 \
    libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 \
    libasound2t64 libpulse0 \
    xvfb x11-utils xdotool ffmpeg unzip curl ca-certificates
fi

# --- Godot editor / runtime binary -----------------------------------------
if [ ! -x "${GODOT_BIN}" ]; then
  mkdir -p "${HOME}/bin"
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -oq "${tmp}/godot.zip" -d "${tmp}"
  mv "${tmp}/Godot_v${GODOT_VERSION}_linux.x86_64" "${GODOT_BIN}"
  chmod +x "${GODOT_BIN}"
  rm -rf "${tmp}"
fi
sudo ln -sf "${GODOT_BIN}" /usr/local/bin/godot

# --- Import project assets / build the .godot cache ------------------------
# Runs against the checked-out source; regenerates import metadata for the
# .glb characters, audio, and scenes so the project is ready to open/run.
cd "${repo_root}"
godot --headless --import

echo "Godot environment ready: $(godot --version 2>/dev/null | tail -1)"
