// Local smoke check for iOS FTL packaging (no FTL submit).
//
// Usage (from repo):
//   cd tools/ensemble_test_runner
//   dart run tool/local_ios_pack_check.dart
//
// Optional: APP_DIR=/path/to/example dart run tool/local_ios_pack_check.dart

import 'dart:io';

import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';
import 'package:ensemble_test_runner/execution/remote/native_build_service.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  if (!Platform.isMacOS) {
    stderr.writeln('iOS pack check requires macOS + Xcode');
    exit(1);
  }

  final packageRoot = Directory.current.path;
  final appDir = Platform.environment['APP_DIR'] ??
      p.normalize(p.join(packageRoot, 'example'));
  if (!Directory(appDir).existsSync()) {
    stderr.writeln('App dir not found: $appDir');
    exit(1);
  }

  stderr.writeln('Local iOS pack check in $appDir');
  final patcher = YamlTestAppPatcher(appDir);
  patcher.enable(
    mode: ExecutionMode.integration,
    targetPlatform: 'ios',
  );

  try {
    if (patcher.pubspecChanged) {
      stderr.writeln('flutter pub get...');
      final pubGet = await Process.run(
        'flutter',
        ['pub', 'get'],
        workingDirectory: appDir,
        runInShell: true,
      );
      if (pubGet.exitCode != 0) {
        stderr.writeln(pubGet.stderr);
        stderr.writeln(pubGet.stdout);
        exit(pubGet.exitCode);
      }
    }

    final identity = NativeBuildService.computeIdentity(
      mode: ExecutionMode.integration,
      target: ExecutionTarget.remote,
      platform: 'ios',
      variant: 'release',
      selectedTestIds: const ['local-pack-check'],
    );

    final artifacts = await IosFtlPackager(
      onProgress: (message) => stderr.writeln('[pack] $message'),
    ).package(
      identity: identity,
      appDir: appDir,
      config: const EnsembleTestConfig(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
      ),
    );

    final stub = artifacts.metadata['stub'] == 'true';
    final zipFile = File(artifacts.appPackagePath);
    final xctestrunFile = File(artifacts.testPackagePath);
    final zipBytes = zipFile.existsSync() ? zipFile.lengthSync() : -1;
    final xctestrunBytes =
        xctestrunFile.existsSync() ? xctestrunFile.lengthSync() : -1;

    stdout.writeln('appPackage=${artifacts.appPackagePath} ($zipBytes bytes)');
    stdout.writeln(
      'testPackage=${artifacts.testPackagePath} ($xctestrunBytes bytes)',
    );
    stdout.writeln('metadata=${artifacts.metadata}');

    if (stub) {
      stderr.writeln('FAILED: stub package — ${artifacts.metadata['detail']}');
      exit(2);
    }

    if (zipBytes < 100 * 1024) {
      stderr.writeln('FAILED: ios_tests.zip too small ($zipBytes bytes)');
      exit(2);
    }
    if (xctestrunBytes < 200) {
      stderr.writeln('FAILED: .xctestrun empty ($xctestrunBytes bytes)');
      exit(2);
    }

    final listed = await Process.run('unzip', ['-l', artifacts.appPackagePath]);
    final listing = listed.stdout.toString();
    final hasRelease = listing.contains('Release-iphoneos/');
    final hasXctestrun = listing.contains('.xctestrun');
    stdout.writeln('zipHasReleaseIphoneos=$hasRelease');
    stdout.writeln('zipHasXctestrun=$hasXctestrun');
    if (!hasRelease || !hasXctestrun) {
      stderr.writeln('FAILED: zip missing Release-iphoneos or .xctestrun');
      exit(2);
    }

    stdout.writeln(
      'OK: iOS FTL packages look submittable '
      '(${(zipBytes / (1024 * 1024)).toStringAsFixed(1)}MiB zip).',
    );
  } finally {
    patcher.restore();
    stderr.writeln('Restored example app patcher mutations.');
  }
}
