import 'package:ensemble_test_runner/application/application_test_types.dart';

/// One resolved suite source shared by CLI patching, validation and runtime.
class TestSuiteSource {
  final String appDirectory;
  final String testsDirectory;
  final String testsAssetPrefix;
  final String testEntryPath;
  final TestApplicationLaunchKind launchKind;

  const TestSuiteSource({
    required this.appDirectory,
    required this.testsDirectory,
    required this.testsAssetPrefix,
    required this.testEntryPath,
    required this.launchKind,
  });
}
