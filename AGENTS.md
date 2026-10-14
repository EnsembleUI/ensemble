# AGENTS.md

## Cursor Cloud specific instructions

### Project overview
Ensemble is a Flutter/Dart monorepo (managed by Melos) that provides a runtime for building native apps from declarative YAML definitions. The starter app (`/starter`) is the primary runnable application.

### Prerequisites
- **Flutter SDK 3.38.7** must be installed at `/opt/flutter` with `/opt/flutter/bin` on `PATH`.
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
- `flutter analyze` will report ~520 pre-existing warnings in `modules/ensemble` (mostly unused imports and `must_be_immutable`). These are not regressions.
- Web builds produce Wasm compatibility warnings for packages using `dart:html` — these are informational and do not block the JS build.
- The Chrome device (`-d chrome`) opens a browser window; use `-d web-server` for headless/CI environments.
- After changing dependencies in any module's `pubspec.yaml`, re-run `melos bootstrap` from the repo root.
