// Local smoke check for Android FTL packaging (no FTL submit).
//
// Usage (from repo):
//   cd tools/ensemble_test_runner
//   dart run tool/local_android_pack_check.dart
//
// Optional: APP_DIR=/path/to/example dart run tool/local_android_pack_check.dart

import 'dart:io';

import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';
import 'package:ensemble_test_runner/execution/remote/native_build_service.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  final packageRoot = Directory.current.path;
  final appDir = Platform.environment['APP_DIR'] ??
      p.normalize(p.join(packageRoot, 'example'));
  if (!Directory(appDir).existsSync()) {
    stderr.writeln('App dir not found: $appDir');
    exit(1);
  }

  stderr.writeln('Local Android pack check in $appDir');
  final patcher = YamlTestAppPatcher(appDir);
  patcher.enable(
    mode: ExecutionMode.integration,
    targetPlatform: 'android',
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
      platform: 'android',
      variant: 'debug',
      selectedTestIds: const ['local-pack-check'],
    );

    final artifacts = await AndroidFtlPackager(
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
    final appFile = File(artifacts.appPackagePath);
    final testFile = File(artifacts.testPackagePath);
    final appBytes = appFile.existsSync() ? appFile.lengthSync() : -1;
    final testBytes = testFile.existsSync() ? testFile.lengthSync() : -1;

    stdout.writeln('appPackage=${artifacts.appPackagePath} ($appBytes bytes)');
    stdout.writeln('testPackage=${artifacts.testPackagePath} ($testBytes bytes)');
    stdout.writeln('metadata=${artifacts.metadata}');

    if (stub) {
      stderr.writeln('FAILED: stub package — ${artifacts.metadata['detail']}');
      exit(2);
    }

    if (testBytes < 1500) {
      stderr.writeln('FAILED: test APK empty ($testBytes bytes)');
      exit(2);
    }

    Future<bool> dexHas(String apk, List<String> needles) async {
      final tmp = Directory.systemTemp.createTempSync('pack_check_');
      try {
        final unzip = await Process.run(
          'unzip',
          ['-o', '-q', apk, 'classes*.dex', '-d', tmp.path],
        );
        if (unzip.exitCode != 0) return false;
        for (final entity in tmp.listSync()) {
          if (entity is! File || !entity.path.endsWith('.dex')) continue;
          final listed = await Process.run('strings', [entity.path]);
          final out = listed.stdout.toString();
          for (final n in needles) {
            if (out.contains(n)) return true;
          }
        }
        return false;
      } finally {
        tmp.deleteSync(recursive: true);
      }
    }

    final hostOk = await dexHas(
      artifacts.testPackagePath,
      const ['MainActivityTest'],
    );
    final runnerOk = await dexHas(
      artifacts.appPackagePath,
      const ['AndroidJUnitRunner', 'FlutterTestRunner'],
    );
    Future<bool> kernelHas(String apk, List<String> needles) async {
      final tmp = Directory.systemTemp.createTempSync('pack_check_kernel_');
      try {
        final unzip = await Process.run(
          'unzip',
          [
            '-o',
            '-q',
            apk,
            'assets/flutter_assets/kernel_blob.bin',
            'lib/*/libapp.so',
            '-d',
            tmp.path,
          ],
        );
        if (unzip.exitCode != 0) return false;
        for (final entity in tmp.listSync(recursive: true)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (name != 'kernel_blob.bin' && name != 'libapp.so') continue;
          final listed = await Process.run('strings', [entity.path]);
          final out = listed.stdout.toString();
          for (final n in needles) {
            if (out.contains(n)) return true;
          }
        }
        return false;
      } finally {
        tmp.deleteSync(recursive: true);
      }
    }

    final entryOk = await kernelHas(
      artifacts.appPackagePath,
      const [
        'runEnsembleIntegrationYamlTests',
        'integration_test/ensemble_tests.dart',
      ],
    );
    final definesOk = await kernelHas(
      artifacts.appPackagePath,
      const [NativeBuildService.remoteTestEncryptionKey],
    );
    stdout.writeln('mainActivityTestInTestApk=$hostOk');
    stdout.writeln('runnerInAppApk=$runnerOk');
    stdout.writeln('integrationEntryInAppApk=$entryOk');
    stdout.writeln('remoteArtifactRootInAppApk=$definesOk');
    if (!hostOk || !runnerOk || !entryOk || !definesOk) {
      stderr.writeln(
        'FAILED: host=$hostOk runner=$runnerOk entry=$entryOk defines=$definesOk',
      );
      exit(2);
    }

    stdout.writeln(
      'OK: Android FTL packages look instrumentable '
      '(~${(testBytes / 1024).toStringAsFixed(1)}KiB test APK is normal when '
      'runner classes ship in the app APK).',
    );
  } finally {
    patcher.restore();
    stderr.writeln('Restored example app patcher mutations.');
  }
}
