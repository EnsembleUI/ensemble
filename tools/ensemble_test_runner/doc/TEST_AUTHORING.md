# Test Authoring

`ensemble_test_runner` can act as the execution backend for test authoring. The recommended loop is:

1. Inspect the app:
   ```sh
   dart run ensemble_test_runner:ensemble_test --inspect-app
   ```
2. Generate or scaffold a test under `ensemble/apps/<appName>/tests`.
3. Validate without booting Flutter:
   ```sh
   dart run ensemble_test_runner:ensemble_test --validate-only
   ```
4. Run the selected test and request machine-readable output:
   ```sh
   dart run ensemble_test_runner:ensemble_test --id=login_valid --report=json
   ```

## Test Shape

Each `.test.yaml` file defines one test at the root. Use metadata so generated tests are easy to organize and select.

```yaml
# yaml-language-server: $schema=https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json
id: login_valid
feature: login
tags: [smoke, auth]
description: Valid user can log in and reach Home
priority: high
startScreen: Login
retry: 3
steps:
  - expectVisible:
      id: email_field
```

Use `startScreen` to choose where the test starts. Use `session` when the test
needs captured app state from another test before mounting that screen.
Use `retry` for known flaky external flows; `retry: 3` means one initial attempt
plus up to three additional attempts.

## Suite Config

Put shared runner settings in `tests/config.yaml`, next to the `*.test.yaml`
files:

```yaml
# yaml-language-server: $schema=https://cdn.ensembleui.com/schemas/ensemble_test_config_schema.json
screenshots:
  enabled: true
  platform: ios
  model: iPhone 15 Pro

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

When `screenshots.enabled` is true, the runner captures automatic step
screenshots into one contact sheet per test case under
`build/ensemble_test_runner/screenshots/`.

When `timers.enabled` is true, the CLI temporarily caps numeric
`startAfter` and `repeatInterval` values in local app screen YAML while the test
process runs, then restores the original files.

## App Context

`--inspect-app` emits JSON with screens, widget IDs, APIs, navigation targets, imports, storage/env references, and lifecycle hints.

## Mocks

Use `mocks` for API responses. For small mocks, define them inline:

```yaml
mocks:
  getDevices:
    body:
      count: 2
```

For larger suites, use an ordered list of `.mock.json` files. Later entries
override earlier entries.

```yaml
mocks:
  - mocks/common/base.mock.json
```

You can also mix both forms in one list:

```yaml
mocks:
  - mocks/common/base.mock.json
  - getDevices:
      body:
        count: 3
```

For scenario-based suites, keep reusable API data in mock files. The runner does
not know what your scenario variables mean; it only substitutes `${scenario.*}`
values and merges mock entries in order.

```yaml
id: home_scenarios
session: signin_to_gateway
startScreen: Home

mocks:
  - mocks/common/base.mock.json
  - mocks/devices/${scenario.device}.mock.json
  - mocks/behaviors/${scenario.behavior}.mock.json

scenarios:
  - id: v14_online
    vars:
      device: v14
      behavior: online
      expectedDeviceCount: 2

steps:
  - expectText:
      text: ${scenario.expectedDeviceCount}
```

Each scenario expands to its own test id, for example
`home_scenarios[v14_online]`.

Mock files are JSON files. The root object maps API names to response
overrides:

```json
{
  "getDevices": {
    "statusCode": 200,
    "delayMs": 300,
    "body": {
      "status": []
    }
  }
}
```

Later files override earlier files. Use `delayMs` when a mock should stay
pending briefly before returning, matching the loading behavior of a real API.

## Validation

`--validate-only` checks generated tests without running Flutter. It reports blocking errors for invalid YAML shape, missing tests, duplicate IDs, unknown sessions, and unknown screens. It reports warnings for likely unknown widget IDs/APIs.

Warnings do not fail the command. Errors exit with code `2`.

## Selection

Use selection flags for development, CI shards, and repair loops:

```sh
dart run ensemble_test_runner:ensemble_test --feature=login
dart run ensemble_test_runner:ensemble_test --tag=smoke
dart run ensemble_test_runner:ensemble_test --path=auth/
dart run ensemble_test_runner:ensemble_test --id=login_valid
```

Prerequisites are included automatically when a selected test depends on them.

## CLI Inputs

Use repeatable `--input key=value` flags for values that should come from the
command line:

```sh
dart run ensemble_test_runner:ensemble_test \
  --input adminPassword='s4C>M7U6t~' \
  --input expectedDeviceCount=2
```

Reference them in test YAML with `${inputs.key}`:

```yaml
initialState:
  keychain:
    adminPassword: ${inputs.adminPassword}
steps:
  - expectText:
      text: ${inputs.expectedDeviceCount}
```

## CI Output

Stable exit codes:

- `0`: all selected tests passed
- `1`: test failure
- `2`: setup/config/validation failure
- `3`: internal runner error

Reports:

```sh
dart run ensemble_test_runner:ensemble_test --report=json --report-file=build/ensemble-tests.json
dart run ensemble_test_runner:ensemble_test --report=junit --report-file=build/ensemble-tests.xml
```

JSON failures include a `failure` object with `kind`, `expected`, `actual`, `suggestions`, and screen context so an author can update the test with less guesswork.

## Scaffolding

Create a valid starter test:

```sh
dart run ensemble_test_runner:ensemble_test \
  --scaffold-test=login_valid \
  --feature=login \
  --tag=smoke \
  --screen=Login
```

Then replace `TODO_widget_test_id` with an ID from `--inspect-app`.
