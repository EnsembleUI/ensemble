
## 1.0.4

### Changes

* Moved to Ensemble monorepo

## 1.0.3

### Changes

* Fix dependency conflict with web_socket_channel by changing constraint from ^3.0.3 to >=2.0.0 <4.0.0
* Resolves compatibility issue with packages that require web_socket_channel 2.x (like ensemble_chat)
* Maintains compatibility with both Flutter 3.27 and Flutter 3.32

## 1.0.2

### Changes

* Fix dependency conflict with Flutter SDK by changing stack_trace constraint from ^1.12.1 to ^1.12.0
* Resolves compatibility issue with integration_test package in Flutter 3.27

## 1.0.1

### Changes

* Revert version to 1.0.0 in pubspec.yaml and clean up CHANGELOG.md
* chore: bump version to 1.0.1
* Refactor release workflow and update CHANGELOG
* chore: bump version to 1.0.1
* Update workflows and CHANGELOG for pub.dev publishing
* chore: bump version to 1.0.1
* Update CHANGELOG.md to reflect package renaming and versioning changes
* Add publishing step to release workflow for pub.dev
* Add GitHub Actions workflow for publishing to pub.dev
* Refactor release workflow for improved readability


## 1.0.0

### Changes

* **BREAKING**: Package renamed from `walletconnect_dart` to `ensemble_walletconnect`
* Forked from RootSoft/walletconnect-dart-sdk to maintain updates
* Updated repository URLs and package metadata
* Maintained by Ensemble team
* All previous functionality remains the same
* Updated SDK constraints to support Dart 3.x
