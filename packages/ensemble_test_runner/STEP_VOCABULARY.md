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
`wait` (alias `pump`), `pump`, `settle`, `waitFor`, `waitForText`, `waitForGone`, `waitForApi`, `waitForNavigation`, `waitUntil`

### UI assertions
`expectVisible`, `expectNotVisible`, `expectExists`, `expectNotExists`, `expectText`, `expectNoText`, `expectTextContains`, `expectEnabled`, `expectDisabled`

### Value / list
`expectValue`, `expectChecked`, `expectSelected`, `expectProperty`, `expectStyle`, `expectCount`, `expectListCount`, `expectListContains`, `expectListItem`, `expectEmpty`, `expectNotEmpty`

### Navigation
`expectScreen` (alias), `expectNavigateTo`, `expectVisited`, `expectNotVisited`, `expectBackStack`, `expectCanGoBack`, `goBack`

### API mock / assert
`mockApi`, `mockApiError`, `mockApiFromFixture`, `mockApiException`, `mockTimeout`, `mockNetworkOffline`, `mockNetworkOnline`, `resetApiCalls`, `clearApiMocks`, `expectApiCalled`, `expectApiNotCalled`, `expectApiRequest`, `expectApiRequestContains`, `expectApiHeader`, `expectApiCallOrder`, `expectLastApiCall`, `logApiCalls`

### State / storage / runtime
`setState`, `expectState`, `expectStateContains`, `expectStateExists`, `expectStateNotExists`, `resetState`, `setStorage`, `expectStorage`, `removeStorage`, `clearStorage`, `setEnv`, `setAuth`, `clearAuth`, `setPermission`, `setDevice`, `setLocale`, `setTheme`

### Scripts / fixtures / debug / quality
`runScript`, `expectScript`, `expectScriptResult`, `expectConsoleLog`, `loadFixture`, `setStateFromFixture`, `expectMatchesFixture`, `logState`, `logStorage`, `screenshot`, `dumpTree`, `expectNoConsoleErrors`, `expectNoRenderErrors`, `expectError`, `expectNoErrors`, `expectAccessible`, `expectSemanticsLabel`, `expectNoOverflow`

### Control flow
`group`, `repeat`, `optional`, `ifVisible`

## Example

```yaml
id: login_flow
startScreen: Login
steps:
  - mockApi:
      name: login
      response:
        statusCode: 200
        body:
          token: test
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

Each `*.test.yaml` file is a single test case and must provide **exactly one** of:

- `startScreen` — cold-starts the app on the given screen and runs steps
- `prerequisite` — ID of another test that must run first; the runner reuses the same app session, applies `initialState`/`mocks` in-place, and then runs this test's steps only

When multiple tests declare `prerequisite` chains, the runner discovers all YAML files, builds a dependency graph by `id`/`prerequisite`, and executes tests once each in topological order.

## Adding a step

1. Add one row to [`tool/generate_step_registry.dart`](tool/generate_step_registry.dart) (`desc` + optional `example` override; defaults come from `defaultExampleForArg`) and run `dart run tool/generate_step_registry.dart`.
2. If needed, add a variant to [`TestStepArgKind`](lib/vocabulary/test_step_arg_kind.dart) and its `jsonSchema` switch.
3. Implement in [`TestStepExecutor`](lib/actions/test_step_executor.dart) and/or [`ExtendedStepHandlers`](lib/actions/extended_step_handlers.dart).
4. Run `dart run tool/generate_schema.dart` and document here.
