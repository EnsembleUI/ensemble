# ensemble_test_runner example

This example is intentionally small: it runs the real Ensemble runtime with
local YAML definitions and includes one declarative test for the app.

## Run the app

```bash
cd example
flutter pub get
flutter run
```

## Run the YAML test

From this directory, after `flutter pub get`:

```bash
dart run ensemble_test_runner:ensemble_test
```

The test starts on `Hello Home`, verifies its greeting, navigates to the
second screen, and verifies that screen as well. The app and test definitions
are under `example/ensemble/` so they can be inspected without any generated
code.
