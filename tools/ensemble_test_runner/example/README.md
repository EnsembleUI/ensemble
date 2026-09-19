# ensemble_test_runner example

This example is intentionally small: it runs the real Ensemble runtime with
local YAML definitions and includes declarative tests for the app.

`tests/config.yaml` currently sets `mode: integration`, so the default command
builds and launches on a connected Android emulator or iOS simulator. Widget
mode is still available with `--mode=widget`.

## Prerequisites

Create the native projects once (they are not fully committed):

```bash
cd example
flutter create --org com.ensembleui --project-name ensemble_test_runner_example --platforms=ios,android .
```

On Flutter 3.44+, disable SwiftPM before an iOS build:

```bash
flutter config --no-enable-swift-package-manager
```

`ios/RunnerTests/RunnerTests.m` must use `INTEGRATION_TEST_IOS_RUNNER` (Flutter
integration_test host) for Firebase Test Lab XCTest packaging.
`RunnerTests.swift` (empty) is required on Xcode 26 so the ObjC test target
links Swift compatibility libraries used by Firebase pods.

Android FTL needs `androidTest/.../MainActivityTest` with `@RunWith(FlutterTestRunner.class)`;
without it Test Lab reports SUCCESS with 0 test cases. Remote packaging also
passes `--no-tree-shake-icons` (Ensemble builds non-const `IconData`).
On Xcode 26 CI, set `TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault` (the remote
workflow does this) so Metal.xctoolchain does not break Swift linking.

Remote iOS CI pins Xcode **26.2** (`maxim-lobanov/setup-xcode`) for FTL
`xcodeVersion`. Device OS in config is FTL catalog **26.3**. The packager zips
the generated `Runner_iphoneos26.2-*.xctestrun` contents under a catalog-aligned
filename (`…26.3…`) — FTL matches the filename token to device OS (without that
copy, submit yields Infrastructure error / empty GCS). No plist sanitize or
dylib inject.

iOS must target 15.0+ (Firebase 12). `flutter create` still generates 13.0;
set `platform :ios, '15.0'` in `ios/Podfile` and `IPHONEOS_DEPLOYMENT_TARGET = 15.0`
in the Xcode project (CI does this for the example), or run
`dart run ensemble_test_runner:ensemble_test --doctor --fix`.

Start an Android emulator or iOS simulator. If more than one is connected,
pass `--device-id`.

## Run the app

```bash
cd example
flutter pub get
flutter run
```

## Run the YAML tests

From this directory, after `flutter pub get`:

```bash
# Integration mode (config.yaml default): install and run on a simulator.
dart run ensemble_test_runner:ensemble_test

# Host-side widget tests, no native project required.
dart run ensemble_test_runner:ensemble_test --mode=widget

# Firebase Test Lab (requires remote: in config.yaml + GCP setup).
dart run ensemble_test_runner:ensemble_test --target=remote --remote-platform=android
dart run ensemble_test_runner:ensemble_test --target=remote --remote-platform=ios
```

The tests start on `Hello Home`, verify its greeting, navigate to the
second screen, and verify that screen as well. The app and test definitions
are under `example/ensemble/` so they can be inspected without any generated
code.
