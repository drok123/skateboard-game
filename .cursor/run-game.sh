#!/usr/bin/env bash
# Convenience launcher for the skate game on the headless VM.
# Uses the virtual display from .cursor/start.sh and Mesa's software Vulkan
# (lavapipe) so Forward+ rendering works without a physical GPU.
#
# Examples:
#   .cursor/run-game.sh                      # run the main scene
#   .cursor/run-game.sh --headless --import  # (re)import assets, no window
set -euo pipefail

export DISPLAY="${DISPLAY:-:99}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg}"
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"

mkdir -p "${XDG_RUNTIME_DIR}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

if [ "$#" -gt 0 ]; then
  exec godot "$@"
else
  exec godot --rendering-driver vulkan
fi
