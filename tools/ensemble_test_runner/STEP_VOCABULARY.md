# Ensemble declarative test step vocabulary

Official step catalog for app-local `tests/*.test.yaml` files, for example `ensemble/apps/helloApp/tests/*.test.yaml`. Every step in [`TestStepRegistry.entries`](lib/vocabulary/test_step_registry.dart) is **implemented** (tier `core` or `extended`).

| Tier | Meaning |
|------|---------|
| **core** | Primary step name |
| **extended** | Alias or secondary API (`wait` → `pump`, `expectScreen` → `expectNavigateTo`) |

## Quick reference

### Lifecycle
`openScreen`, `reloadScreen`, `restartApp`, `resetAppState`, `trigger`, `launchApp`

### Interactions
`tap`, `doubleTap`, `longPress`, `enterText`, `clearText`, `replaceText`, `submitText`, `focus`, `unfocus`

### Form controls
`select`, `selectIndex`, `check`, `uncheck`, `toggle`, `setSlider`, `chooseDate`, `chooseTime`

### Gestures
`scroll`, `scrollUntilVisible`, `swipe`, `drag`, `pullToRefresh`

### Wait / sync
`wait` (alias `pump`), `pump`, `settle`, `waitFor`, `waitForText`, `waitForGone`, `waitForApi`, `waitForNavigation`

### UI assertions
`expectVisible`, `expectNotVisible`, `expectExists`, `expectNotExists`, `expectText`, `expectNoText`, `expectTextContains`, `expectEnabled`, `expectDisabled`

### Value / list
`expectValue`, `expectChecked`, `expectSelected`, `expectProperty`, `expectStyle`, `expectCount`, `expectListCount`, `expectListContains`, `expectListItem`, `expectEmpty`, `expectNotEmpty`

### Navigation
`expectScreen` (alias), `expectNavigateTo`, `expectVisited`, `expectNotVisited`, `expectBackStack`, `expectCanGoBack`, `goBack`

### API mocks / assert / logs
`mocks`, `httpRequest`, `resetApiCalls`, `expectApiCalled`, `expectApiNotCalled`, `expectApiCallOrder`, `expectLastApiCall`, `logApiCalls`

### Storage / runtime
`setStorage`, `expectStorage`, `removeStorage`, `clearStorage`, `setEnv`, `setAuth`, `clearAuth`, `setPermission`, `setDevice`, `setLocale`, `setTheme`

### Scripts / debug / quality
`runScript`, `expectScript`, `expectScriptResult`, `expectConsoleLog`, `expectNoConsoleErrors`, `expectNoRenderErrors`, `expectError`, `expectNoErrors`, `expectAccessible`, `expectSemanticsLabel`, `expectNoOverflow`

### Control flow
`group`, `repeat`, `optional`, `ifVisible`

## Example

```yaml
id: login_flow
startScreen: Login
steps:
  - enterText:
      id: email_field
      value: user@test.com
  - tap:
      id: login_button
  - waitForNavigation:
      screen: Home
  - expectVisible:
      id: welcome_text
```

## JSON Schema

Editor validation: `https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json` (committed copy at [`assets/schema/ensemble_tests_schema.json`](assets/schema/ensemble_tests_schema.json), regenerate with `dart run tool/generate_schema.dart`). Arg shapes come from [`TestStepArgKind`](lib/vocabulary/test_step_arg_kind.dart) on each [`TestStepRegistryEntry`](lib/vocabulary/test_step_registry.dart).

Performance logging writes Flutter app frame timing metrics to
`build/ensemble_test_runner/logs/app_performance.json`. Enable it once for the
full suite in `tests/config.yaml`:

```yaml
performance:
  enabled: true
```

Long app timers can be capped during the test run without changing the checked
in screen YAML:

```yaml
timers:
  enabled: true
  maxStartAfterSeconds: 1
  maxRepeatIntervalSeconds: 1
```

`dumpTree` and `performance` are suite-level **config** flags; when enabled
they emit **per-test** payloads (and step-scoped performance) folded into
`results.json.gz`. `logApiCalls` and `logStorage` likewise attach **per-test**
data to each test result / HTML card:

```yaml
dumpTree:
  enabled: true
logApiCalls:
  enabled: true
logStorage:
  enabled: true
```

Example paths: `home_wifi[android_nl]_api_calls.json`,
`home_wifi[android_nl]_storage.json`, plus always-on
`home_wifi[android_nl]_app_console.log` for that run's prints.
Long-running test support processes belong in `tests/config.yaml`. They start
once before the suite, must answer the optional readiness URL, and are stopped
after the suite:

```yaml
services:
  - name: modemStub
    command: .venv/bin/python
    arguments: [modemstub/app.py]
    workingDirectory: ensemble/apps/inhome/autotests
    readyUrl: /ping
```

The runner assigns a free local port. Use `${services.modemStub.url}` in test
steps instead of repeating the endpoint.

Use `httpRequest` for finite setup or state changes during a test:

```yaml
- httpRequest:
    method: POST
    url: ${services.modemStub.url}/api/v1/stub/hard-reset
    body:
      loadDefaults: true
    expectStatus: 200
```

Use `mocks` when the app API response should change during a test. It supports
the same inline and `.mock.json` file shapes as root-level `mocks`, and applies
to later app API calls:

```yaml
- mocks:
    getDevices:
      body:
        count: 4
```

Before running a new suite, use `dart run ensemble_test_runner:ensemble_test --doctor`
from the Flutter wrapper app root to validate config, test discovery, duplicate
IDs, sessions, schema comments, and obvious widget IDs. CI can request JSON
with `--report=json` or `--report-file=build/ensemble_test_results.json`.

Each `*.test.yaml` file is a single test case and must provide:

- `startScreen` — cold-starts the app on the given screen and runs steps
- `session` — optional; runs the referenced test once, restores its captured storage/keychain/locale for this test, runs `setup`, and mounts the requested `startScreen`
- `retry` — number of additional attempts after a failed run, e.g. `retry: 3`

Root-level `setup` supports `httpRequest`, `group`, and `optional`. It runs
before the test screen is mounted; it is intended for external service and stub
configuration, not widget actions.

The runner discovers all YAML files, builds a dependency graph from `session`
references, and executes each test once in topological order.

## Adding a step

1. Add one row to [`tool/generate_step_registry.dart`](tool/generate_step_registry.dart) (`desc` + optional `example` override; defaults come from `defaultExampleForArg`) and run `dart run tool/generate_step_registry.dart`.
2. If needed, add a variant to [`TestStepArgKind`](lib/vocabulary/test_step_arg_kind.dart) and its `jsonSchema` switch.
3. Implement in [`TestStepExecutor`](lib/actions/test_step_executor.dart) and/or [`ExtendedStepHandlers`](lib/actions/extended_step_handlers.dart).
4. Run `dart run tool/generate_schema.dart` and document here.
