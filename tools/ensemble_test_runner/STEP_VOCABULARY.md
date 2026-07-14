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

### API assert / logs
`resetApiCalls`, `expectApiCalled`, `expectApiNotCalled`, `expectApiCallOrder`, `expectLastApiCall`, `logApiCalls`

### Storage / runtime
`setStorage`, `expectStorage`, `removeStorage`, `clearStorage`, `setEnv`, `setAuth`, `clearAuth`, `setPermission`, `setDevice`, `setLocale`, `setTheme`

### Scripts / debug / quality
`runScript`, `expectScript`, `expectScriptResult`, `expectConsoleLog`, `logStorage`, `logPerformance`, `screenshot`, `dumpTree`, `expectNoConsoleErrors`, `expectNoRenderErrors`, `expectError`, `expectNoErrors`, `expectAccessible`, `expectSemanticsLabel`, `expectNoOverflow`

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

`logPerformance` writes Flutter app frame timing metrics to
`build/ensemble_test_runner/logs/<test>_app_performance.json`. To write this
artifact automatically once after the full suite, set this in
`tests/config.yaml`:

```yaml
performance:
  enabled: true
```

`dumpTree`, `logApiCalls`, and `logStorage` can also be written automatically
once after the full suite from `tests/config.yaml`:

```yaml
dumpTree:
  enabled: true
logApiCalls:
  enabled: true
logStorage:
  enabled: true
```

Before running a new suite, use `dart run ensemble_test_runner:ensemble_test --doctor`
from the Flutter wrapper app root to validate config, test discovery, duplicate
IDs, prerequisites, schema comments, and obvious widget IDs. CI can request JSON
with `--report=json` or `--report-file=build/ensemble_test_results.json`.

Each `*.test.yaml` file is a single test case and must provide **exactly one** of:

- `startScreen` — cold-starts the app on the given screen and runs steps
- `prerequisite` — ID of another test that must run first; the runner reuses the same app session, applies `initialState`/`mocks` in-place, and then runs this test's steps only

When multiple tests declare `prerequisite` chains, the runner discovers all YAML files, builds a dependency graph by `id`/`prerequisite`, and executes tests once each in topological order.

## Adding a step

1. Add one row to [`tool/generate_step_registry.dart`](tool/generate_step_registry.dart) (`desc` + optional `example` override; defaults come from `defaultExampleForArg`) and run `dart run tool/generate_step_registry.dart`.
2. If needed, add a variant to [`TestStepArgKind`](lib/vocabulary/test_step_arg_kind.dart) and its `jsonSchema` switch.
3. Implement in [`TestStepExecutor`](lib/actions/test_step_executor.dart) and/or [`ExtendedStepHandlers`](lib/actions/extended_step_handlers.dart).
4. Run `dart run tool/generate_schema.dart` and document here.
