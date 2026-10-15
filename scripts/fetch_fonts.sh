#!/bin/bash
# Prepare the bundled OFL Japanese fonts used by the release media scripts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/verify_store_fonts.py"
# Keep the old local directory available for existing preview commands.
mkdir -p "$ROOT/scripts/fonts"
cp "$ROOT"/assets/store-fonts/*.ttf "$ROOT/scripts/fonts/"
