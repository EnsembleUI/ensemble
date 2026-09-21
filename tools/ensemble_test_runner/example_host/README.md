# Flutter host + Ensemble child example

This app is a Flutter host with Ensemble embedded as a child, the same shape as
KPN `flutter_pca`: a Flutter login screen, then a Flutter shell that owns the
bottom navigation. Ensemble is initialized when that shell appears — not on the
login screen.

Two ways to open the Ensemble shop:

1. **Shop tab** in the bottom navbar
2. **Open Shop** card on the Flutter Home tab, which pushes the same Ensemble
   screen onto the host navigator

The other two tabs (Home and Account) stay Flutter.

`example/` remains the standalone Ensemble widget suite. Use this directory
for mixed Flutter-host / Ensemble-child tests.

This package depends on the local `modules/ensemble` via `dependency_overrides`
so the runner and runtime stay in lockstep in this monorepo.

## Run the app

```bash
cd example_host
flutter pub get
flutter run
```

iOS must target 15.0+ (Firebase 12). `flutter create` still generates 13.0;
this example already sets `platform :ios, '15.0'` in `ios/Podfile` and
`IPHONEOS_DEPLOYMENT_TARGET = 15.0` in the Xcode project. If you recreate the
native projects, run `dart run ensemble_test_runner:ensemble_test --doctor --fix`
or raise those values yourself.

On Flutter 3.44+, disable SwiftPM before an iOS build:

```bash
flutter config --no-enable-swift-package-manager
```

Xcode 27 / the iOS 27 SDK requires the UIScene lifecycle. This example’s
`ios/Runner/Info.plist` includes `UIApplicationSceneManifest` pointing at
`FlutterSceneDelegate`. Recreating the iOS project without that key will crash
on launch with “UIScene life cycle is required for apps built with this SDK”.

## Run the YAML tests

Host suites omit `startScreen`. The entry file owns launch through
`ApplicationTestDriver` and is never overwritten by the CLI.

```bash
cd example_host
flutter pub get

# Host-side widget tests (no simulator required).
dart run ensemble_test_runner:ensemble_test \
  --tests-dir=tests \
  --test-entry=test/application_yaml_tests.dart \
  --mode=widget
```

The HTML report is `build/ensemble_test_runner/report/index.html`. Suite
`tests/config.yaml` enables per-step screenshots; the host runner also writes
app console, API, and storage logs into that report. The example fires dummy
host (`hostLogin`, `hostSession`) and Ensemble shop (`getCatalog`,
`getFeaturedItem`) APIs plus `debugPrint` / `console.log` lines so those
report tabs are populated.

Integration mode uses the same YAML and `--test-entry`. The CLI passes
`--dart-define=ensembleTestExecutionMode=integration`; `runApplicationYamlTests`
selects the integration binding from that define. On device, native plugins
(`device_info_plus`, sqflite, path_provider) stay real — widget-test
MethodChannel mocks are not installed.

```bash
dart run ensemble_test_runner:ensemble_test \
  --tests-dir=tests \
  --test-entry=test/application_yaml_tests.dart \
  --mode=integration
```

Login any email/password (pre-filled) and use **Continue**. After login the
shell initializes Ensemble, then the navbar and Home card both open `Shop.yaml`.
