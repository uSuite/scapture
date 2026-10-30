#!/bin/sh
# Universal Release build and zip, signed ad hoc as the family's downloads
# are (no Developer ID yet, so no notarisation). Writes
# build/release/sCapture.app and build/release/sCapture-<version>.zip.
set -eu
VERSION=$(cat VERSION)
BUILD_NUMBER=$(git rev-list --count HEAD)
OUT=build/release

# A tag on HEAD must match VERSION, so a release never ships a stale number.
TAG=$(git tag --points-at HEAD | grep '^v' | head -1 || true)
if [ -n "$TAG" ] && [ "$TAG" != "v$VERSION" ]; then
    echo "release: HEAD is tagged $TAG but VERSION says $VERSION" >&2
    exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
APP="$OUT/sCapture.app" CONFIG=release SIGN_IDENTITY=- FLAGS="--arch arm64 --arch x86_64" \
    VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" scripts/bundle.sh
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$OUT/sCapture.app" "$OUT/sCapture-$VERSION.zip"
echo "release: $(lipo -archs "$OUT/sCapture.app/Contents/MacOS/sCapture") $VERSION ($BUILD_NUMBER)"
shasum -a 256 "$OUT/sCapture-$VERSION.zip"
