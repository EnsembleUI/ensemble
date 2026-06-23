# ensemble_test_runner

Standalone declarative YAML test runner for Ensemble apps. Wraps the **real** Ensemble runtime (`EnsembleApp`), injects mocks via runtime override hooks, and asserts on rendered UI, navigation, APIs, and storage.

This package is **not** a dependency of `modules/ensemble`. It is a **dev-only** dependency — not shipped in release builds.

## Write tests (YAML only)

Add `*.test.yaml` files under the configured local app path's `tests/`
directory, for example `ensemble/apps/helloApp/tests/`:

```yaml
id: hello_home_renders
startScreen: Hello Home
initialState:
  storage:
    helloApp:
      name:
        first: John
        last: Doe
steps:
  - expectVisible:
      id: greeting_text
```

Each `*.test.yaml` file is **one** test — `id`, `steps`, and **either** `startScreen` **or** `prerequisite` are at the root (no `tests:` array). A test with `prerequisite: <other_test_id>` runs after that test on the **same** app session, applying only `initialState`/`mocks` in-place before executing its steps.

Widget YAML must set `testId` (or `id`, which maps to the same `ValueKey`).

### Step vocabulary

The full official catalog (lifecycle, gestures, API mocks, fixtures, debug, etc.) is in **[STEP_VOCABULARY.md](STEP_VOCABULARY.md)**.

Machine-readable registry (single source): `lib/vocabulary/test_step_registry.dart`.

### JSON Schema (editor validation)

A JSON Schema for `*.test.yaml` is hosted at `https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json`. The committed copy lives at [`assets/schema/ensemble_tests_schema.json`](assets/schema/ensemble_tests_schema.json) and is generated from the step registry:

```bash
cd packages/ensemble_test_runner && dart run tool/generate_schema.dart
```

Or per file at the top of a test:

```yaml
# yaml-language-server: $schema=https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json
```

## App setup

1. Add `*.test.yaml` files under `definitions.local.path/tests/`, for example
   `ensemble/apps/helloApp/tests/`.
2. Configure `definitions.local` in `ensemble/ensemble-config.yaml` (`path`, `appHome`, `i18n.path`).
3. Add `ensemble_test_runner` to `dev_dependencies` (same git `url`/`ref` as your `ensemble:` dependency).
4. Run `flutter pub get`.

## Run

From your app directory (e.g. `starter/`):

```bash
dart run ensemble_test_runner:ensemble_test
```

The command must run from the Flutter wrapper app root — the directory with
`pubspec.yaml` and `ensemble/ensemble-config.yaml`. Dart resolves
`ensemble_test_runner:ensemble_test` from the current package's
`dev_dependencies`, so running the command from `ensemble/apps/<app>` will fail
before the runner starts.

The CLI temporarily bundles `definitions.local.path/tests/` as an asset (if needed), writes `test/ensemble_tests.dart`, runs `flutter test`, then restores your `pubspec.yaml` and removes the generated test file.

By default, output is quiet: no `pub get` package list, no Flutter test progress lines — `SCREEN TRACKER` navigation logs plus the boxed suite report. Use `--verbose` for full subprocess output (useful when debugging).

Optional: `--app-dir=<path>` when not running from the app root.

### Validate setup

Run doctor when setting up a new app or debugging discovery issues:

```bash
dart run ensemble_test_runner:ensemble_test --doctor
```

It checks the wrapper app, `ensemble-config.yaml`, `definitions.local`, test
folder, YAML parsing, duplicate IDs, prerequisites, schema comments, and obvious
widget `id`/`testId` references.

### CI output

For machine-readable results:

```bash
dart run ensemble_test_runner:ensemble_test --report=json
dart run ensemble_test_runner:ensemble_test --report-file=build/ensemble_test_results.json
```

`--report=json` prints the final run result as JSON. `--report-file` writes the
same JSON to disk while keeping the normal console report.

On success the console prints one consolidated boxed report for the suite: each test id (with YAML path), timing, **start screen** or **prerequisite**, **navigation flow**, and a numbered **step outline**.

## Examples

### Login flow

```yaml
# yaml-language-server: $schema=https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json
id: login_flow
startScreen: Login
steps:
  - mockApi:
      name: login
      response:
        statusCode: 200
        body:
          token: test-token
  - enterText:
      id: email_field
      value: user@test.com
  - enterText:
      id: password_field
      value: password
  - tap:
      id: login_button
  - expectApiCalled:
      name: login
  - expectVisible:
      id: dashboard_title
```

### Storage/env setup

```yaml
id: logged_in_home
startScreen: Home
initialState:
  env:
    apiURL: https://example.test
  storage:
    auth:
      token: test-token
steps:
  - expectVisible:
      id: welcome_text
```

### Multi-file prerequisite chain

```yaml
id: login_start
startScreen: Login
steps:
  - enterText:
      id: email_field
      value: user@test.com
```

```yaml
id: login_submit
prerequisite: login_start
steps:
  - tap:
      id: login_button
  - expectVisible:
      id: dashboard_title
```

## Package layout

```
lib/
  entry/          Flutter test entry (`runEnsembleYamlTests`)
  cli/            `dart run ensemble_test_runner:ensemble_test` subprocess runner
  runner/         Runtime boot, orchestration, session state
  actions/        Step execution
  assertions/     expect* handlers
  discovery/      Find and plan `*.test.yaml` files
  parser/         YAML → models
  reporters/      Console report formatting
  vocabulary/     Step registry + JSON Schema shapes
  models/         Shared data types
  mocks/          Mock HTTP provider + test logger
bin/ensemble_test.dart   CLI executable
tool/                    Schema/registry generators
```

## Runtime hooks (in `ensemble` core)

The runner uses small, optional hooks in the core module — not a package dependency:

- Test harness applies `EnsembleTestSetup` (storage seeds, env overrides) before `EnsembleApp` mounts
- Test harness installs `MockAPIProvider` on `EnsembleConfig.apiProviders['http']`
- Test mode via `--dart-define=testmode=true` (added automatically by the CLI)
- Navigation flow for `expectVisited` is recorded in the test runner via `ScreenTracker.onScreenChange`

`EnsembleTestHarness` runs storage init inside `tester.runAsync()` so `GetStorage` can finish under the widget test binding.
