import 'dart:async';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';

abstract final class RunCommandAction {
  static Future<void> execute(Map<String, dynamic> args) async {
    final command = args['command']?.toString();
    if (command == null || command.isEmpty) {
      throw EnsembleTestFailure('runCommand requires "command"');
    }
    final argumentsNode = args['arguments'];
    if (argumentsNode != null && argumentsNode is! List) {
      throw EnsembleTestFailure('runCommand "arguments" must be a list');
    }
    final environmentNode = args['environment'];
    if (environmentNode != null && environmentNode is! Map) {
      throw EnsembleTestFailure('runCommand "environment" must be a map');
    }

    final arguments = argumentsNode == null
        ? const <String>[]
        : List<String>.from(
            argumentsNode.map((value) => value.toString()),
          );
    final environment = environmentNode == null
        ? null
        : {
            for (final entry in environmentNode.entries)
              entry.key.toString(): entry.value.toString(),
          };
    final timeoutMs = _positiveInt(args['timeoutMs'], fallback: 30000);
    final expectedExitCode = _nonNegativeInt(
      args['expectExitCode'],
      fallback: 0,
    );

    try {
      final result = await LiveAsyncCallSupport.run<_CommandResult>(() async {
        final process = await Process.start(
          command,
          arguments,
          workingDirectory: args['workingDirectory']?.toString(),
          environment: environment,
          includeParentEnvironment: true,
        );
        final stdout = process.stdout.transform(systemEncoding.decoder).join();
        final stderr = process.stderr.transform(systemEncoding.decoder).join();
        try {
          final exitCode = await process.exitCode.timeout(
            Duration(milliseconds: timeoutMs),
          );
          return _CommandResult(
            exitCode: exitCode,
            stdout: await stdout,
            stderr: await stderr,
          );
        } on TimeoutException {
          process.kill();
          try {
            await process.exitCode.timeout(const Duration(seconds: 1));
          } on TimeoutException {
            if (!Platform.isWindows) process.kill(ProcessSignal.sigkill);
            await process.exitCode;
          }
          await Future.wait([stdout, stderr]);
          rethrow;
        }
      });
      if (result == null) {
        throw EnsembleTestFailure('runCommand did not return a result');
      }
      if (result.exitCode != expectedExitCode) {
        throw EnsembleTestFailure(
          'runCommand "$command" expected exit code $expectedExitCode, got '
          '${result.exitCode}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
      }
    } on EnsembleTestFailure {
      rethrow;
    } catch (error) {
      throw EnsembleTestFailure('runCommand "$command" failed: $error');
    }
  }

  static int _positiveInt(dynamic value, {required int fallback}) {
    final parsed = value == null
        ? fallback
        : value is int
            ? value
            : int.tryParse(value.toString());
    if (parsed == null || parsed <= 0) {
      throw EnsembleTestFailure('Expected a positive integer, got "$value"');
    }
    return parsed;
  }

  static int _nonNegativeInt(dynamic value, {required int fallback}) {
    final parsed = value == null
        ? fallback
        : value is int
            ? value
            : int.tryParse(value.toString());
    if (parsed == null || parsed < 0) {
      throw EnsembleTestFailure(
        'Expected a non-negative integer, got "$value"',
      );
    }
    return parsed;
  }
}

class _CommandResult {
  const _CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
