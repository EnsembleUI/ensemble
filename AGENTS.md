# AGENTS.md

## Cursor Cloud specific instructions

### Project overview
Ensemble is a Flutter/Dart monorepo (managed by Melos) that provides a runtime for building native apps from declarative YAML definitions. The starter app (`/starter`) is the primary runnable application.

### Prerequisites
- **Flutter SDK 3.47.2** must be installed at `/opt/flutter` with `/opt/flutter/bin` on `PATH`.
  This is the version every CI workflow pins. `modules/ensemble` declares `flutter: '>=3.35.0'` and is
  verified on both 3.35.4 and 3.47.2 — do not introduce APIs newer than 3.35 without raising that floor
  (see the `TODO(flutter-upgrade)` markers).
- **JDK 17** is required for Android builds (Flutter 3.38 raised the minimum).
- **Melos** must be globally activated (`dart pub global activate melos`).
- `PATH` must include both `/opt/flutter/bin` and `$HOME/.pub-cache/bin`.

### Key commands

| Task | Command | Working directory |
|------|---------|-------------------|
| Bootstrap monorepo | `melos bootstrap` | `/workspace` |
| Lint (core module) | `flutter analyze` | `/workspace/modules/ensemble` |
| Lint (starter) | `flutter analyze` | `/workspace/starter` |
| Unit tests (core) | `flutter test` | `/workspace/modules/ensemble` |
| Unit tests (auth) | `flutter test` | `/workspace/modules/auth` |
| Build web | `flutter build web --no-tree-shake-icons` | `/workspace/starter` |
| Run web dev server | `flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0` | `/workspace/starter` |

### Non-obvious gotchas
- The starter's `pubspec.yaml` points the `ensemble` dependency to a git URL, but `melos bootstrap` overrides this with a local path reference. Always run `melos bootstrap` from the repo root before building.
- The default `ensemble-config.yaml` uses `from: ensemble` which fetches app definitions from Ensemble's cloud (Firestore). This works without any local Firebase setup since it reads from a public Kitchen Sink demo app (`appId: e24402cb-75e2-404c-866c-29e6c3dd7992`).
- To use local YAML definitions instead, change `from: ensemble` to `from: local` in `starter/ensemble/ensemble-config.yaml`.
- `flutter analyze` reports ~237 pre-existing issues in `modules/ensemble` (0 errors; mostly `must_be_immutable`,
  unused imports/locals, and ~22 remaining deprecations). These are not regressions.
- iOS/Android **release** builds need `--no-tree-shake-icons`: Ensemble resolves icons dynamically from YAML,
  so it builds non-const `IconData` (see `modules/ensemble/lib/framework/widget/icon.dart`).
- The starter is **deliberately incomplete in git**: `.gitignore` excludes both the Xcode project
  (`project.pbxproj`) and the Android `MainActivity` (`starter/android/app/src/main/kotlin`). Before
  building either platform, run the generate step from the starter README:
  `cd starter && flutter create --org com.ensembleui --project-name starter --platform=ios,android,web .`
  The project name must yield `com.ensembleui.starter` to match `appId` in `ensemble/ensemble.properties`,
  otherwise the app installs but crashes with `ClassNotFoundException ... MainActivity`.
- Before an **iOS** build on Flutter >= 3.44, disable SwiftPM: `flutter config --no-enable-swift-package-manager`.
  10 plugins have no SwiftPM support, and running it alongside CocoaPods makes Xcode fail with
  "Multiple commands produce ...framework" for the Firebase/gRPC frameworks. Not set in `pubspec.yaml`
  on purpose: the `flutter: config:` key only parses on Flutter >= 3.44 and would break the 3.27 target.
  CI is unaffected (it builds web + android only).
- Web builds produce Wasm compatibility warnings for packages using `dart:html` — these are informational and do not block the JS build.
- The Chrome device (`-d chrome`) opens a browser window; use `-d web-server` for headless/CI environments.
- After changing dependencies in any module's `pubspec.yaml`, re-run `melos bootstrap` from the repo root.
- After switching Flutter SDKs (`fvm use`), run `flutter clean` before testing — a stale per-SDK
  `shaders/ink_sparkle.frag` makes unrelated widget tests fail with "Runtime stages buffer failed verification".
