#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN_ROOT="$PROJECT_ROOT/native/hive_ios"
GODOT_SOURCE=${GODOT_SOURCE:-/private/tmp/godot-4.7}
SCONS=${SCONS:-/private/tmp/jellymon-scons/bin/scons}
OUTPUT="$PROJECT_ROOT/ios/plugins/HiveBridge/hive_bridge.xcframework"

if [ ! -f "$GODOT_SOURCE/core/version.h" ]; then
	echo "Godot 4.7 source is required at $GODOT_SOURCE" >&2
	exit 1
fi
if [ ! -x "$SCONS" ]; then
	echo "SCons is required at $SCONS" >&2
	exit 1
fi

cd "$PLUGIN_ROOT"
mkdir -p bin
CLANG_MODULE_CACHE_PATH=/private/tmp/jellymon-clang-cache "$SCONS" arch=arm64 simulator=no godot_path="$GODOT_SOURCE" project_root="$PROJECT_ROOT" target_path=bin -j8
CLANG_MODULE_CACHE_PATH=/private/tmp/jellymon-clang-cache "$SCONS" arch=arm64 simulator=yes godot_path="$GODOT_SOURCE" project_root="$PROJECT_ROOT" target_path=bin -j8

rm -rf "$OUTPUT"
xcodebuild -create-xcframework \
	-library "$PLUGIN_ROOT/bin/libhive_bridge_arm64_ios.a" \
	-library "$PLUGIN_ROOT/bin/libhive_bridge_arm64_simulator.a" \
	-output "$OUTPUT"

echo "HiveBridge iOS plugin built: $OUTPUT"
