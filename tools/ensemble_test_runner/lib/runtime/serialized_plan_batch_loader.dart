import 'dart:io';

import 'package:ensemble_test_runner/entry/runner_runtime_configuration.dart';

import '../cli/cli_worker_batch_wire_transport.dart';

/// Loads precompiled plans handed off to a Flutter worker by the scheduler.
///
/// The payload is file based because a compiled batch can exceed a
/// shell-safe command line. The runtime define carries only its absolute path.
/// With no path, the normal planner/compiler path remains in use.
Future<CliWorkerBatch?> workerBatchFromEnvironment() async {
  final path =
      RunnerRuntimeConfiguration.current.string('ensembleTestPlanBatchFile');
  if (path.isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Execution plan batch file not found: $path');
  }
  final payload = await file.readAsString();
  return CliWorkerBatchWireTransport.decode(payload);
}
