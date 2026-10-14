/// Public widget-test entry point for declarative test suites.
library;

import 'package:ensemble_test_runner/entry/ensemble_test_entry_common.dart'
    as common;
import 'package:ensemble_test_runner/src/integrations/firebase/firebase_test_registration.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/runtime/test_execution_binding.dart';

export 'package:ensemble_test_runner/entry/ensemble_test_entry_common.dart'
    show EnsembleTestOptions, reportSuiteEndWithStorageRestore;

Future<void> runEnsembleTests({
  Future<void> Function()? bootstrap,
  Map<String, Function>? externalMethods,
}) =>
    _runEnsembleTestsWithOptions(
      common.EnsembleTestOptions(
          bootstrap: bootstrap, externalMethods: externalMethods),
    );

Future<void> _runEnsembleTestsWithOptions(
    common.EnsembleTestOptions options) async {
  ensureExecutionBinding(options.mode);
  return _registerEnsembleTests(options);
}

/// Registers the suite with Firebase test support for widget-mode execution.
Future<void> _registerEnsembleTests(common.EnsembleTestOptions options) =>
    common.registerEnsembleTestsInternal(
      options,
      options.mode == ExecutionMode.widget
          ? const [firebaseTestIntegration]
          : const [],
    );
