#!/bin/sh
set -e
# Pin an older SDK: on Command Line Tools only (no Xcode), the newest SDK ships
# @State as a macro that needs a plugin only Xcode provides — this SDK still has
# the plain (pre-macro) SwiftUI property wrappers.
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX14.5.sdk
swift build -c release
APP=FileStack.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/FileStack "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
# ad-hoc sign: without a stable signature macOS re-asks for file-access TCC permissions on every rebuild
codesign --force --deep --sign - "$APP"
echo "built $APP"
