#!/bin/sh
# Wrap the SPM-built sCapture executable into build/sCapture.app. Signed with
# SIGN_IDENTITY when set (an Apple Development certificate keeps the Screen
# Recording and Accessibility grants across rebuilds), ad hoc otherwise.
set -eu

SWIFT=${SWIFT:-swift}
VERSION=${VERSION:-0.0.0}
BUILD_NUMBER=${BUILD_NUMBER:-1}
CONFIG=${CONFIG:-debug}
APP=${APP:-build/sCapture.app}
SIGN_IDENTITY=${SIGN_IDENTITY:--}
# extra build flags, such as the two --arch flags of a universal release
FLAGS=${FLAGS:-}

sh -c "$SWIFT build -c $CONFIG $FLAGS --product sCapture"
BIN_DIR=$(sh -c "$SWIFT build -c $CONFIG $FLAGS --show-bin-path")

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/sCapture" "$APP/Contents/MacOS/sCapture"
sed \
    -e "s/\$(EXECUTABLE_NAME)/sCapture/" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/io.github.usuite.scapture/" \
    -e "s/\$(MARKETING_VERSION)/$VERSION/" \
    -e "s/\$(CURRENT_PROJECT_VERSION)/$BUILD_NUMBER/" \
    Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp brand/scapture-menubar.svg "$APP/Contents/Resources/MenuBarIcon.svg"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign "$SIGN_IDENTITY" "$APP" >/dev/null
echo "built $APP $VERSION ($BUILD_NUMBER), signed ${SIGN_IDENTITY}"
