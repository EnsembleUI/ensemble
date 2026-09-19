// Rebuild a local-style HTML report from an existing FTL collect directory.
//
// Usage:
//   dart run tool/rebuild_remote_report.dart /path/to/run-xxx
//   dart run tool/rebuild_remote_report.dart /path/to/run-xxx --app-dir=example

import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/execution/remote/remote_host_report.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/execution/remote/remote_report_reconciler.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    stderr.writeln(
      'Usage: dart run tool/rebuild_remote_report.dart <collectDir> '
      '[--app-dir=<path>]',
    );
    exit(args.isEmpty ? 1 : 0);
  }

  var collectPath = args.first;
  var appDir = Directory.current.path;
  for (final arg in args.skip(1)) {
    if (arg.startsWith('--app-dir=')) {
      appDir = arg.substring('--app-dir='.length);
    }
  }

  final collect = Directory(p.normalize(p.absolute(collectPath)));
  if (!collect.existsSync()) {
    stderr.writeln('Collect dir not found: ${collect.path}');
    exit(1);
  }

  final hostRoot = Directory(
    p.join(appDir, 'build', 'ensemble_test_runner'),
  )..createSync(recursive: true);

  final builder = RemoteHostReportBuilder(
    onProgress: (m) => stderr.writeln('[rebuild] $m'),
  );
  await builder.materializeDeviceArtifactsIntoHost(
    collectDirectory: collect,
    hostArtifactRoot: hostRoot.path,
  );

  final envelope = RemoteReportReconciler.loadEnvelope(collect) ??
      RemoteReportReconciler.loadEnvelope(hostRoot);
  if (envelope == null) {
    stderr.writeln('No RemoteRunEnvelope found under ${collect.path}');
    exit(2);
  }

  final device = RemoteReportReconciler.reconcile(
    deviceKey: 'primary',
    nativeOutcome: 'SUCCESS',
    envelope: envelope,
    artifactDirectory: hostRoot,
  );

  final html = await builder.writeReports(
    appDir: appDir,
    hostArtifactRoot: hostRoot.path,
    collectDirectory: collect,
    devices: [device],
  );
  if (html == null) {
    stderr.writeln('Failed to write HTML report');
    exit(3);
  }

  final index = File(p.join(collect.path, 'report', 'index.html'));
  stdout.writeln(json.encode({
    'ok': true,
    'htmlReport': index.path,
    'hostReport': p.join(hostRoot.path, 'report', 'index.html'),
    'failureClass': device.failureClass.name,
  }));
}
