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
steps:
  - expectVisible:
      id: email_field
```

Use `startScreen` for a cold start. Use `prerequisite` when a test should continue from another test in the same app session.

## App Context

`--inspect-app` emits JSON with screens, widget IDs, APIs, navigation targets, imports, storage/env references, and lifecycle hints.

## Fixtures And Mocks

Put JSON fixtures under:

```text
ensemble/apps/<appName>/tests/fixtures/<name>.json
```

Reference fixtures by filename:

```yaml
steps:
  - mockApiFromFixture:
      name: profile
      fixture: profile_success.json
```

Use root `mocks.apis` for APIs that may run during `onLoad` or startup. Use step-level `mockApi` or `mockApiFromFixture` for APIs triggered after user actions.

```yaml
mocks:
  apis:
    profile:
      response:
        body: {name: Jane}
steps:
  - mockApi:
      name: login
      response:
        body: {token: test-token}
```

## Validation

`--validate-only` checks generated tests without running Flutter. It reports blocking errors for invalid YAML shape, missing tests, duplicate IDs, unknown prerequisites, unknown screens, and missing fixtures. It reports warnings for likely unknown widget IDs/APIs and mock placement issues.

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
