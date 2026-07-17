# ensemble_test_runner

Dev-only declarative YAML test runner for Ensemble apps. Wraps the **real** Ensemble runtime (`EnsembleApp`), injects mocks via runtime override hooks, and asserts on rendered UI, navigation, APIs, and storage.

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

Each `*.test.yaml` file is **one** test (no `tests:` array). It either
cold-starts with `startScreen`, continues a mounted flow with `prerequisite`, or
restores reusable app state with `session` and starts on its own `startScreen`.

Use root-level `setup` for commands and HTTP requests that must complete before
the screen is mounted. This is useful for resetting or configuring a stub server:

```yaml
id: authenticated_home
session: signin
startScreen: Home
setup:
  - httpRequest:
      method: POST
      url: ${services.modemStub.url}/api/v1/stub/scenario
      body: {testcase: home, responsename: offline}
steps:
  - expectVisible: {id: offline_message}
```

Widget YAML must set `testId` (or `id`, which maps to the same `ValueKey`).

### Step vocabulary

The full official catalog (lifecycle, gestures, API assertions, debug, etc.) is in **[STEP_VOCABULARY.md](STEP_VOCABULARY.md)**.

Machine-readable registry (single source): `lib/vocabulary/test_step_registry.dart`.

### JSON Schema (editor validation)

A JSON Schema for `*.test.yaml` is hosted at `https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json`. The committed copy lives at [`assets/schema/ensemble_tests_schema.json`](assets/schema/ensemble_tests_schema.json) and is generated from the step registry:

```bash
cd tools/ensemble_test_runner && dart run tool/generate_schema.dart
```

Or per file at the top of a test:

```yaml
# yaml-language-server: $schema=https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json
```

Suite-wide runner config lives in `tests/config.yaml`. The schema is hosted at
`https://cdn.ensembleui.com/schemas/ensemble_test_config_schema.json`:

```yaml
# yaml-language-server: $schema=https://cdn.ensembleui.com/schemas/ensemble_test_config_schema.json
services:
  - name: modemStub
    command: .venv/bin/python
    arguments: [modemstub/app.py]
    workingDirectory: ensemble/apps/inhome/autotests
    readyUrl: /ping

The runner assigns a free local port. Tests can reference that resolved endpoint
as `${services.modemStub.url}`.

screenshots:
  enabled: true
  platform: ios
  model: iPhone 15 Pro
  includeSteps: []
  excludeSteps: []

performance:
  enabled: true
timers:
  enabled: true
  maxStartAfterSeconds: 1
  maxRepeatIntervalSeconds: 1
dumpTree:
  enabled: true
logApiCalls:
  enabled: true
logStorage:
  enabled: true
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

Pass test-runner inputs with repeatable `--input key=value` flags. Tests can
reference them as `${inputs.key}` in `initialState`, mocks, and steps:

```bash
dart run ensemble_test_runner:ensemble_test \
  --input adminPassword='s4C>M7U6t~' \
  --input expectedDeviceCount=2
```

```yaml
initialState:
  keychain:
    adminPassword: ${inputs.adminPassword}
steps:
  - expectText:
      text: ${inputs.expectedDeviceCount}
```

There is no implicit whole-suite timeout; individual steps and services keep
their own bounded timeouts. Add one when CI should enforce a suite deadline:

```bash
dart run ensemble_test_runner:ensemble_test --timeout=30s
dart run ensemble_test_runner:ensemble_test --timeout=15m
dart run ensemble_test_runner:ensemble_test --timeout=1h
```

### Validate setup

Run doctor when setting up a new app or debugging discovery issues:

```bash
dart run ensemble_test_runner:ensemble_test --doctor
```

It checks the wrapper app, `ensemble-config.yaml`, `definitions.local`, test
folder, YAML parsing, duplicate IDs, prerequisites, schema comments, and obvious
widget `id`/`testId` references.

For generated tests, use fast validation without booting Flutter:

```bash
dart run ensemble_test_runner:ensemble_test --validate-only
dart run ensemble_test_runner:ensemble_test --validate-only --report=json
```

### App inspection and scaffolding

Emit app metadata for test authors:

```bash
dart run ensemble_test_runner:ensemble_test --inspect-app
```

Create a starter test under `definitions.local.path/tests/`:

```bash
dart run ensemble_test_runner:ensemble_test --scaffold-test=login_valid --feature=login --tag=smoke --screen=Login
```

See [`docs/TEST_AUTHORING.md`](docs/TEST_AUTHORING.md) for the test authoring workflow, mock file conventions, validation rules, and repair-loop output.

### CI output

For machine-readable results:

```bash
dart run ensemble_test_runner:ensemble_test --report=json
dart run ensemble_test_runner:ensemble_test --report-file=build/ensemble_test_results.json
dart run ensemble_test_runner:ensemble_test --report=junit --report-file=build/ensemble_test_results.xml
```

`--report=json` prints the final run result as JSON. `--report=junit` prints
JUnit XML. `--report-file` writes the selected machine report to disk while
keeping the normal console report.

Stable exit codes: `0` pass, `1` test failures, `2` setup/config/validation
failures, `3` internal runner errors.

Run a subset:

```bash
dart run ensemble_test_runner:ensemble_test --id=login_valid
dart run ensemble_test_runner:ensemble_test --feature=login
dart run ensemble_test_runner:ensemble_test --tag=smoke
dart run ensemble_test_runner:ensemble_test --path=auth/
```

Prerequisite tests are included automatically for selected continuation tests.

On success the console prints one consolidated boxed report for the suite: each test id (with YAML path), timing, **start screen** or **prerequisite**, **navigation flow**, and a numbered **step outline**. Raw app console output is written to `build/ensemble_test_runner/logs/app_console*.log` and listed as an `appLogs` suite artifact.

## Examples

### Login flow

```yaml
# yaml-language-server: $schema=https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json
id: login_flow
startScreen: Login
retry: 3
mocks:
  - mocks/login_success.mock.json
steps:
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

### Reusable authenticated session

The session producer runs once. After it passes, the runner captures public
storage, keychain values, and locale in memory. Each consumer restores that
snapshot, runs its `setup`, and mounts a fresh requested screen.

```yaml
id: signin
startScreen: Login
steps:
  - tap: {id: login_button}
  - waitForNavigation: {screen: Home}
```

```yaml
id: devices
session: signin
startScreen: Home
setup:
  - httpRequest:
      method: POST
      url: ${services.modemStub.url}/api/v1/stub/reset
steps:
  - tap: {id: devices_button}
```

Use `prerequisite` when the second test must continue the exact mounted UI
state. Use `session` when tests need the same signed-in data but should otherwise
start independently. Session snapshots are not written to disk.

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
- Navigation flow for `expectVisited` is recorded in the test runner via `ScreenTracker.onScreenChange`

`EnsembleTestHarness` runs storage init inside `tester.runAsync()` so `GetStorage` can finish under the widget test binding.
