#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
IOS_BUILD_DIR="$PROJECT_ROOT/build/ios"

if [ ! -f "$IOS_BUILD_DIR/JellyMon.xcodeproj/project.pbxproj" ]; then
  echo "Godot iOS export not found: $IOS_BUILD_DIR/JellyMon.xcodeproj" >&2
  exit 1
fi

cp "$PROJECT_ROOT/native/hive_ios/Podfile" "$IOS_BUILD_DIR/Podfile"
if [ -f "$PROJECT_ROOT/native/hive_ios/Podfile.lock" ]; then
  cp "$PROJECT_ROOT/native/hive_ios/Podfile.lock" "$IOS_BUILD_DIR/Podfile.lock"
fi
cd "$IOS_BUILD_DIR"
pod install
cp "$IOS_BUILD_DIR/Podfile.lock" "$PROJECT_ROOT/native/hive_ios/Podfile.lock"

if [ ! -f "$IOS_BUILD_DIR/JellyMon.xcworkspace/contents.xcworkspacedata" ]; then
  echo "CocoaPods workspace was not generated." >&2
  exit 1
fi

echo "Hive iOS dependencies are ready. Open build/ios/JellyMon.xcworkspace."
