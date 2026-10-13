#!/bin/bash
# Fetch the OFL Japanese fonts used by make_store_screenshots.py.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)/fonts"
mkdir -p "$DIR"
for file in zenkakugothicnew/ZenKakuGothicNew-Bold.ttf zenkakugothicnew/ZenKakuGothicNew-Medium.ttf \
            zenoldmincho/ZenOldMincho-Bold.ttf zenoldmincho/ZenOldMincho-Regular.ttf; do
  [ -f "$DIR/$(basename "$file")" ] || curl -sSfL -o "$DIR/$(basename "$file")" "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/$file"
done
ls "$DIR"
