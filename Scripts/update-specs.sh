#!/bin/sh
# Downloads the CommonMark and GFM specifications and stores their examples
# as test data in Tests/SetzerSpecTests/Resources. Run from the repository
# root or any other directory. Sources are pinned and checked before either
# fixture is replaced. The specifications are licensed CC-BY-SA 4.0.
set -eu
cd "$(dirname "$0")/.."
COMMONMARK_VERSION=0.31.2
# This Swift fork revision reproduces the existing upstream GFM corpus,
# including its two task list examples marked "disabled".
GFM_REF=08ddb528923cc1a6527e02b7a1aee9e516ca749a
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fsSL "https://spec.commonmark.org/$COMMONMARK_VERSION/spec.json" -o "$work/commonmark.json"
curl -fsSL "https://raw.githubusercontent.com/swiftlang/swift-cmark/$GFM_REF/test/spec.txt" -o "$work/gfm.txt"
python3 -I - "$work" <<'PY'
import hashlib
import pathlib
import sys

directory = pathlib.Path(sys.argv[1])
expected = {
    "commonmark.json": "d431b29d97b6f73e69d547109cf5081578fac931e72afe95639ebe766c1b2a20",
    "gfm.txt": "7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c",
}
for name, digest in expected.items():
    if hashlib.sha256((directory / name).read_bytes()).hexdigest() != digest:
        raise SystemExit(f"Unexpected contents for {name}; fixtures were not updated")
PY
python3 -I Scripts/convert-gfm-spec.py "$work/gfm.txt" > "$work/gfm.json"
cp "$work/commonmark.json" "Tests/SetzerSpecTests/Resources/commonmark-$COMMONMARK_VERSION.json"
cp "$work/gfm.json" "Tests/SetzerSpecTests/Resources/gfm-0.29.json"
echo "Updated specification examples."
