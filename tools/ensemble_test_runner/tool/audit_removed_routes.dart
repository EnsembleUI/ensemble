// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:io';

/// Guards against restoring the removed routing facade and its source files.
void main() {
  const removedFiles = <String>{
    'lib/session/session_compatibility.dart',
    'lib/session/session_operation_adapter.dart',
    'lib/session/step_dispatcher.dart',
    'lib/session/step_migration_matrix.dart',
    'lib/session/step_routing.dart',
    'lib/session/step_path.dart',
    'lib/session/step_route_policy.dart',
    'lib/actions/test_step_control_flow.dart',
  };
  const removedSymbols = <String>{
    'StepDispatcher',
    'StepMigrationMatrix',
    'StepRouting',
    'SessionStepRouting',
    '_legacyPayloadBytes',
    'TestStepControlFlow',
  };

  final violations = <String>[];
  for (final path in removedFiles) {
    if (File(path).existsSync()) violations.add('obsolete file: $path');
  }

  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('lib directory not found');
    exitCode = 2;
    return;
  }
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll('\\', '/');
    final source = entity.readAsStringSync();
    for (final symbol in removedSymbols) {
      if (RegExp(r'\b' + RegExp.escape(symbol) + r'\b').hasMatch(source)) {
        violations.add('$path: removed symbol $symbol');
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Removed routing artifacts found:');
    stderr.writeAll(violations, '\n');
    exitCode = 1;
    return;
  }
  stdout.writeln('Removed routing and raw-step control-flow routes are absent.');
}
