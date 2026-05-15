# Contributing to Ensemble

Thank you for your interest in contributing to Ensemble! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## Getting Started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (>= 3.24.0)
- [Melos](https://melos.invertase.dev/) (>= 3.4.0) — install with `dart pub global activate melos`

### Setting Up the Development Environment

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/<your-username>/ensemble.git
   cd ensemble
   ```

2. Bootstrap the monorepo (installs dependencies and links local packages):
   ```bash
   melos bootstrap
   ```

3. Run the starter app to verify your setup:
   ```bash
   cd starter
   flutter run
   ```

This will launch the Kitchen Sink demo app showcasing the available widgets and features.

## Repository Structure

This is a Dart/Flutter monorepo managed by Melos:

- **`modules/ensemble/`** — Core Ensemble runtime
- **`modules/`** — Optional feature modules (auth, camera, chat, location, etc.)
- **`packages/`** — Standalone packages published to pub.dev
- **`starter/`** — Reference app for running Ensemble-powered apps

## How to Contribute

### Reporting Bugs

- Search [existing issues](https://github.com/EnsembleUI/ensemble/issues) to avoid duplicates.
- If no existing issue matches, open a new one with:
  - A clear, descriptive title
  - Steps to reproduce the issue
  - Expected vs. actual behavior
  - Flutter version, platform, and any relevant configuration

### Suggesting Features

Open an issue describing the feature, its use case, and any proposed implementation approach. This lets the team discuss the idea before significant effort is invested.

### Contributing Code

#### Widget Development

1. Browse existing widgets in [`modules/ensemble/lib/widget/`](https://github.com/EnsembleUI/ensemble/tree/main/modules/ensemble/lib/widget) to understand patterns.
2. Run the [Kitchen Sink app](https://studio.ensembleui.com/app/e24402cb-75e2-404c-866c-29e6c3dd7992/screens) to see how YAML definitions map to Flutter widgets.
3. Create your own app and screens in [Ensemble Studio](https://studio.ensembleui.com/) to prototype and test your widget.

#### Creating a Pull Request

1. Create a branch from `main`:
   ```bash
   git checkout -b feature/my-change
   ```

2. Make your changes, following the conventions in the existing codebase.

3. Run analysis to check for issues:
   ```bash
   cd modules/ensemble
   flutter analyze
   ```

4. Run tests to ensure nothing is broken:
   ```bash
   cd modules/ensemble
   flutter test
   ```

5. If you modified the auth module, run its tests as well:
   ```bash
   cd modules/auth
   flutter test
   ```

6. Commit your changes with a clear, descriptive message.

7. Push your branch and open a pull request against `main`.

8. Verify that all CI status checks are passing.

### Adding or Enabling Modules

The starter app has optional modules disabled by default to keep the app lightweight. To enable a module:

1. Uncomment the corresponding dependency in `starter/pubspec.yaml`.
2. Run `flutter pub upgrade`.
3. Enable the service in `starter/lib/generated/ensemble_modules.dart` by uncommenting the relevant imports and registration lines.
4. Run `flutter run` to verify.

See the [Starter README](https://github.com/EnsembleUI/ensemble/tree/main/starter#readme) for details.

## Style Guidelines

- Follow existing code conventions in the repository.
- Use `flutter analyze` to catch lint issues before submitting.
- Keep pull requests focused — one logical change per PR.

## Releasing

See the [Releasing a New Version](README.md#releasing-a-new-version) section in the README.

## License

By contributing to Ensemble, you agree that your contributions will be licensed under the [BSD 3-Clause License](LICENSE).
