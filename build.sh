#!/bin/sh
set -e

# Pin an older SDK: on Command Line Tools only (no Xcode), the newest SDK ships
# @State as a macro that needs a plugin only Xcode provides — an SDK around
# macOS 14 still has the plain (pre-macro) SwiftUI property wrappers.
SDK_DIR=/Library/Developer/CommandLineTools/SDKs
if [ -d "$SDK_DIR/MacOSX14.5.sdk" ]; then
    SDKROOT="$SDK_DIR/MacOSX14.5.sdk"
else
    SDKROOT=$(ls -d "$SDK_DIR"/MacOSX14*.sdk 2>/dev/null | sort -V | tail -1)
fi
if [ -z "$SDKROOT" ]; then
    echo "error: no macOS 14.x SDK found under $SDK_DIR" >&2
    echo "This build needs one because the newest SDK's @State macro plugin only ships with full Xcode." >&2
    echo "Fix: install Xcode from the App Store, then build with: xcode-select -s /Applications/Xcode.app && swift build -c release" >&2
    exit 1
fi
export SDKROOT

swift build -c release
APP=FileStack.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/FileStack "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
# ad-hoc sign: without a stable signature macOS re-asks for file-access TCC permissions on every rebuild
codesign --force --deep --sign - "$APP"
echo "built $APP"
