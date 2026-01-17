#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v nvim >/dev/null 2>&1; then
  echo "nvim not found on PATH" >&2
  exit 1
fi

PLENARY_PATH="${PLENARY_PATH:-$HOME/.local/share/nvim/lazy/plenary.nvim}"

if [ -z "$PLENARY_PATH" ] || [ ! -d "$PLENARY_PATH" ]; then
  echo "Plenary not found. Set PLENARY_PATH to your plenary.nvim directory." >&2
  exit 1
fi

export PLENARY_PATH

nvim --headless -u "$ROOT/tests/minimal_init.lua" \
  -c "PlenaryBustedDirectory $ROOT/tests { minimal_init = '$ROOT/tests/minimal_init.lua' }" \
  -c "qa"
