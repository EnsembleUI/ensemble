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
```

The tests start on `Hello Home`, verify its greeting, navigate to the
second screen, and verify that screen as well. The app and test definitions
are under `example/ensemble/` so they can be inspected without any generated
code.
