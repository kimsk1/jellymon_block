# JellyMon Hive iOS bridge

The iOS export is prepared in two phases:

1. Export the Godot iOS project to `build/ios/JellyMon.xcodeproj`.
2. Run `tools/prepare_ios_hive.sh`, then open `build/ios/JellyMon.xcworkspace`.

The preparation script copies the pinned Podfile, installs Hive 26.4.0 and
Adiz 3.0.0, and verifies that the generated Xcode workspace contains the
required frameworks. Always open the `.xcworkspace`, not the `.xcodeproj`,
after CocoaPods is installed.

If Xcode reports `Framework 'AppAuth' not found`, close the window opened from
`build/ios/JellyMon.xcodeproj` and open `build/ios/JellyMon.xcworkspace` instead.
Both files are in the same directory, but the workspace also builds
`Pods/Pods.xcodeproj`. The navigator should contain both JellyMon and Pods.
Building the project alone reads CocoaPods linker flags without building the
required frameworks. Adding a path to another DerivedData folder is not a fix.

Current pinned versions are Hive SDK 26.4.0, Hive Adiz 3.0.0, and iOS 14.0.
The export preset uses Apple team `XZNDHJ52PQ` and bundle/Hive App ID
`com.jellymontest.game` for the sandbox build.

From the project root, the repeatable export flow is:

```sh
/Users/kimsk/Documents/dev/tool/Godot.app/Contents/MacOS/Godot \
  --headless --path . --export-debug iOS build/ios/JellyMon.xcodeproj
tools/prepare_ios_hive.sh
open build/ios/JellyMon.xcworkspace
```

`tools/build_ios_hive_plugin.sh` is only needed when the Objective-C++ bridge
source changes. It requires Godot 4.7 source and the Pods frameworks. The bridge
must be compiled with `DEBUG_ENABLED` to match Godot's iOS debug template ABI.

The current Podfile does not include the optional Hercules module. The bridge
therefore calls `HIVEConfiguration.setUseHercules(false)` before `AuthV4.setup`.
Without this setting, the SDK aborts at setup completion with
`useHercules is true. Hercules framework should exist.` If Hercules is added
later, enable it only after adding the matching SDK dependency.

Google login in the installed Hive 26.4.0 provider requires all three XML
attributes: `clientId` (iOS OAuth client), `serverClientId` (Web OAuth client),
and `reversedClientId` (reversed iOS client). The same reversed iOS client must
appear under `CFBundleURLTypes` in Info.plist; this is maintained in the iOS
export preset. Omitting `clientId` causes `AuthV4ProviderMissingKey` (-1200105),
even if the other two attributes are present. Device login results are written
to Documents/hive_login_status.json with result code and missing-key details,
without player identifiers or authentication tokens.

Adiz must receive the active UIWindowScene's root view controller. Godot 4.7's
SwiftUI app has no window on its app delegate, so using only
`UIApplication.sharedApplication.delegate.window` prevents Adiz initialization.
The bridge selects the foreground scene's key window and resolves its presented
controller. Native `[JellyMonAdiz]` logs report initialization and load/show state.

The Godot native singleton source and binary are maintained under
`ios/plugins/HiveBridge`. Re-exporting the project must not remove that source
folder; rerun the preparation script after every clean export.
