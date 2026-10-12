// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_test_selection.dart';
import 'package:ensemble_test_runner/execution/device_selector.dart'
    as device_selector;
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Resolves and validates command line values used by the test runner.
///
/// Keeping argument policy separate from process orchestration makes the CLI
/// entry point easier to audit while retaining the existing command contract.
final class CliArgumentOptions {
  const CliArgumentOptions._();

  /// Bounds a command-line run when a host or device stops making progress.
  ///
  /// The value is deliberately applied at the CLI boundary. Callers that
  /// invoke the Flutter test entry directly retain the test framework's
  /// normal timeout policy.
  static const defaultTimeoutSeconds = 10 * 60;

  static String appDirectory(List<String> arguments) {
    for (final arg in arguments) {
      if (arg.startsWith('--app-dir=')) {
        return arg.substring('--app-dir='.length);
      }
    }
    return Directory.current.path;
  }

  static String? reportMode(List<String> arguments) {
    for (final arg in arguments) {
      if (arg == '--report=json') return 'json';
      if (arg == '--report=junit') return 'junit';
    }
    return null;
  }

  static String? reportFile(List<String> arguments) {
    for (final arg in arguments) {
      if (arg.startsWith('--report-file=')) {
        return File(arg.substring('--report-file='.length)).absolute.path;
      }
    }
    return null;
  }

  static int? timeoutSeconds(List<String> arguments) {
    String? value;
    for (final arg in arguments) {
      if (arg.startsWith('--timeout=')) {
        value = arg.substring('--timeout='.length);
      }
    }
    if (value == null) return defaultTimeoutSeconds;

    final match = RegExp(r'^(\d+)(ms|s|m|h)?$').firstMatch(value);
    if (match == null) {
      stderr.writeln(
        'Invalid --timeout value "$value". Use a duration like 30s, 5m, or 1h.',
      );
      exit(2);
    }

    final amount = int.parse(match.group(1)!);
    final unit = match.group(2) ?? 's';
    final seconds = switch (unit) {
      'ms' => (amount / 1000).ceil(),
      's' => amount,
      'm' => amount * 60,
      'h' => amount * 60 * 60,
      _ => amount,
    };
    if (seconds <= 0) {
      stderr.writeln('--timeout must be greater than zero.');
      exit(2);
    }
    return seconds;
  }

  static int? jobsOverride(List<String> arguments) {
    String? value;
    for (final arg in arguments) {
      if (arg.startsWith('--jobs=')) {
        value = arg.substring('--jobs='.length);
      }
    }
    if (value == null || value.isEmpty || value == 'auto') return null;
    final jobs = int.tryParse(value);
    if (jobs == null || jobs <= 0) {
      stderr.writeln(
        'Invalid --jobs value "$value". Use a positive integer, auto, or 1 to disable parallelism.',
      );
      exit(2);
    }
    return jobs;
  }

  static ExecutionMode executionMode(
    List<String> arguments,
    ExecutionMode configured,
  ) {
    final values = CliTestSelection.values(arguments, '--mode');
    if (values.length > 1) {
      throw StateError('--mode may be specified only once.');
    }
    if (values.isEmpty) return configured;
    return switch (values.single) {
      'widget' => ExecutionMode.widget,
      'integration' => ExecutionMode.integration,
      _ => throw StateError(
          'Invalid --mode="${values.single}". Use widget or integration.',
        ),
    };
  }

  static void validateExecutionModeOptions(
    List<String> arguments, {
    required ExecutionMode mode,
    required EnsembleTestConfig config,
    required int? jobs,
  }) {
    final deviceIds = CliTestSelection.values(arguments, '--device-id');
    if (deviceIds.length > 1) {
      throw StateError('--device-id may be specified only once.');
    }
    if (mode == ExecutionMode.widget) {
      if (deviceIds.isNotEmpty) {
        throw StateError('--device-id is only valid with --mode=integration.');
      }
      return;
    }
    final jobsWasSpecified =
        arguments.any((argument) => argument.startsWith('--jobs='));
    if (jobsWasSpecified && jobs != 1) {
      throw StateError(
        'Integration mode is serial. Omit --jobs or use --jobs=1.',
      );
    }
    if (config.devices.isEmpty &&
        CliTestSelection.values(arguments, '--device').isNotEmpty) {
      throw StateError(
        '`--device` was set but tests/config.yaml has no devices.',
      );
    }
  }

  static String selectIntegrationDeviceId(
    String machineJson, {
    String? requestedId,
  }) =>
      device_selector.selectIntegrationDeviceId(
        machineJson: machineJson,
        requestedId: requestedId,
      );
}
