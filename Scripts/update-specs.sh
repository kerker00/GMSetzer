#!/bin/sh
# Downloads the CommonMark and GFM specifications and stores their examples
# as test data in Tests/SetzerSpecTests/Resources. Run from the repository
# root. The specifications are licensed CC-BY-SA 4.0 (see the README there).
set -eu
COMMONMARK_VERSION=0.31.2
GFM_REF=master
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fsSL "https://spec.commonmark.org/$COMMONMARK_VERSION/spec.json" -o "$work/commonmark.json"
curl -fsSL "https://raw.githubusercontent.com/github/cmark-gfm/$GFM_REF/test/spec.txt" -o "$work/gfm.txt"
python3 -I Scripts/convert-gfm-spec.py "$work/gfm.txt" > "$work/gfm.json"
cp "$work/commonmark.json" "Tests/SetzerSpecTests/Resources/commonmark-$COMMONMARK_VERSION.json"
cp "$work/gfm.json" "Tests/SetzerSpecTests/Resources/gfm-0.29.json"
echo "Updated specification examples."
