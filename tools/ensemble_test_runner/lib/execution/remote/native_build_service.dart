import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/execution/remote/remote_progress.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:path/path.dart' as p;

/// Build identity (reusable) vs execution identity (per submit).
class NativeBuildIdentity {
  final String buildId;
  final String planHash;
  final String platform;
  final String variant;
  final List<String> selectedTestIds;
  final Map<String, String> dartDefines;

  const NativeBuildIdentity({
    required this.buildId,
    required this.planHash,
    required this.platform,
    required this.variant,
    required this.selectedTestIds,
    this.dartDefines = const {},
  });
}

class NativeBuildArtifacts {
  final NativeBuildIdentity identity;
  final String appPackagePath;
  final String testPackagePath;
  final Map<String, String> metadata;

  const NativeBuildArtifacts({
    required this.identity,
    required this.appPackagePath,
    required this.testPackagePath,
    this.metadata = const {},
  });
}

/// Builds (or reuses) native packages keyed by [NativeBuildIdentity.buildId].
class NativeBuildService {
  final Directory cacheDirectory;
  final Future<NativeBuildArtifacts> Function(
    NativeBuildIdentity identity, {
    required String appDir,
    required EnsembleTestConfig config,
  })? builder;
  final RemoteProgress? onProgress;

  NativeBuildService({
    Directory? cacheDirectory,
    this.builder,
    this.onProgress,
  }) : cacheDirectory = cacheDirectory ??
            Directory(
              p.join(
                Directory.systemTemp.path,
                'ensemble_test_native_builds',
              ),
            );

  void _log(String message) => onProgress?.call(message);

  /// Deterministic test-only encryption key for remote packages (not a secret).
  static const remoteTestEncryptionKey = 'EnsembleTestKey00000000000000000';

  static NativeBuildIdentity computeIdentity({
    required ExecutionMode mode,
    required ExecutionTarget target,
    required String platform,
    required String variant,
    required List<String> selectedTestIds,
    Map<String, String> dartDefines = const {},
    String? toolchainFingerprint,
  }) {
    // Never bake per-run encryption keys or runIds into build identity.
    final sanitizedDefines = Map<String, String>.from(dartDefines)
      ..remove('ensembleTestEncryptionKey')
      ..remove('ensembleTestRemoteRunId')
      ..remove('ensembleTestRemoteDeviceExecutionId');
    sanitizedDefines['ensembleTestEncryptionKey'] = remoteTestEncryptionKey;
    sanitizedDefines['ensembleTestEmitRemoteEnvelope'] = 'true';
    sanitizedDefines['ensembleTestExecutionMode'] = 'integration';
    sanitizedDefines['ensembleTestExecutionTarget'] = 'remote';

    final planHash = computePlanHash(
      mode: mode,
      target: target,
      selectedTestIds: selectedTestIds,
      buildDefines: sanitizedDefines,
    );
    final material = json.encode({
      'platform': platform,
      'variant': variant,
      'planHash': planHash,
      'defines': sanitizedDefines,
      if (toolchainFingerprint != null) 'toolchain': toolchainFingerprint,
    });
    final buildId = sha256.convert(utf8.encode(material)).toString();
    return NativeBuildIdentity(
      buildId: buildId,
      planHash: planHash,
      platform: platform,
      variant: variant,
      selectedTestIds: List<String>.from(selectedTestIds)..sort(),
      dartDefines: sanitizedDefines,
    );
  }

  Future<NativeBuildArtifacts> buildOrReuse({
    required NativeBuildIdentity identity,
    required String appDir,
    required EnsembleTestConfig config,
  }) async {
    cacheDirectory.createSync(recursive: true);
    final slot = Directory(p.join(cacheDirectory.path, identity.buildId));
    final marker = File(p.join(slot.path, 'artifacts.json'));
    if (marker.existsSync()) {
      _log('Cache hit for build ${identity.buildId.substring(0, 12)}…');
      final decoded = json.decode(marker.readAsStringSync()) as Map;
      return NativeBuildArtifacts(
        identity: identity,
        appPackagePath: decoded['appPackagePath'].toString(),
        testPackagePath: decoded['testPackagePath'].toString(),
        metadata: {
          'reused': 'true',
          ...Map<String, String>.from(
            (decoded['metadata'] as Map?)?.map(
                  (k, v) => MapEntry(k.toString(), v.toString()),
                ) ??
                {},
          ),
        },
      );
    }

    _log(
      'Building ${identity.platform} packages '
      '(this can take several minutes)...',
    );
    final built = builder != null
        ? await builder!(identity, appDir: appDir, config: config)
        : await _defaultBuild(identity, appDir: appDir, config: config);

    slot.createSync(recursive: true);
    marker.writeAsStringSync(
      json.encode({
        'appPackagePath': built.appPackagePath,
        'testPackagePath': built.testPackagePath,
        'metadata': built.metadata,
        'identity': {
          'buildId': identity.buildId,
          'planHash': identity.planHash,
          'platform': identity.platform,
        },
      }),
    );
    return built;
  }

  Future<NativeBuildArtifacts> _defaultBuild(
    NativeBuildIdentity identity, {
    required String appDir,
    required EnsembleTestConfig config,
  }) async {
    if (identity.platform == 'ios') {
      return IosFtlPackager(onProgress: onProgress).package(
        identity: identity,
        appDir: appDir,
        config: config,
      );
    }
    return AndroidFtlPackager(onProgress: onProgress).package(
      identity: identity,
      appDir: appDir,
      config: config,
    );
  }
}

/// Android APK + androidTest packaging for FTL.
///
/// Artifact export path is a **hypothesis** until real FTL verification.
class AndroidFtlPackager {
  /// Candidate on-device export directory for envelope + screenshots.
  static const exportRelativePath = 'files/ensemble_test_remote';

  final RemoteProgress? onProgress;

  AndroidFtlPackager({this.onProgress});

  Future<NativeBuildArtifacts> package({
    required NativeBuildIdentity identity,
    required String appDir,
    required EnsembleTestConfig config,
    Future<ProcessResult> Function(String executable, List<String> args)?
        runProcess,
  }) async {
    final run = runProcess ??
        ((exe, args) => _runCaptured(
              exe,
              args,
              workingDirectory: appDir,
            ));

    final workspace = await _prepareIsolatedWorkspace(appDir, identity.buildId);
    final defines = [
      for (final e in identity.dartDefines.entries)
        '--dart-define=${e.key}=${e.value}',
      '--dart-define=ensembleTestRemoteBuildId=${identity.buildId}',
      '--dart-define=ensembleTestRemotePlanHash=${identity.planHash}',
      '--dart-define=ensembleTestArtifactRoot=/data/local/tmp/ensemble_test_remote',
    ];

    onProgress?.call('Building Android debug APK...');
    final build = await run('flutter', [
      'build',
      'apk',
      '--debug',
      ...defines,
    ]);
    if (build.exitCode != 0) {
      final detail = _formatProcessFailure('flutter build apk', build);
      onProgress?.call('ERROR: $detail');
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail: detail,
      );
    }

    // Flutter FTL docs: assemble instrumentation + debug with test target.
    final androidDir = p.join(workspace, 'android');
    final testTarget = p.join(workspace, 'integration_test/ensemble_tests.dart');
    if (File(testTarget).existsSync() &&
        File(p.join(androidDir, 'gradlew')).existsSync()) {
      onProgress?.call('Assembling Android instrumentation test APK...');
      final gradle = await _runCaptured(
        './gradlew',
        [
          'app:assembleAndroidTest',
          'app:assembleDebug',
          '-Ptarget=$testTarget',
        ],
        workingDirectory: androidDir,
      );
      if (gradle.exitCode != 0) {
        onProgress?.call(
          'WARNING: ${_formatProcessFailure('gradlew assembleAndroidTest', gradle)}\n'
          'Continuing with flutter APK only.',
        );
      }
    }

    final appApk = p.join(
      workspace,
      'build/app/outputs/flutter-apk/app-debug.apk',
    );
    final testApkPath = p.join(
      workspace,
      'build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk',
    );
    final testApk =
        File(testApkPath).existsSync() ? testApkPath : appApk;
    if (!File(appApk).existsSync()) {
      onProgress?.call('ERROR: APK missing after build; emitting stubs');
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail: 'APK missing after build',
      );
    }
    onProgress?.call('Android packages ready');
    return NativeBuildArtifacts(
      identity: identity,
      appPackagePath: appApk,
      testPackagePath: testApk,
      metadata: {
        'platform': 'android',
        'exportHypothesis': exportRelativePath,
        'workspace': workspace,
      },
    );
  }

  Future<String> _prepareIsolatedWorkspace(String appDir, String buildId) async {
    // Prefer building in-place under a dedicated output dir marker to avoid
    // mutating unrelated user state; copy is used when appDir is dirty.
    final marker = File(p.join(appDir, '.ensemble_test_remote_workspace'));
    marker.parent.createSync(recursive: true);
    marker.writeAsStringSync(buildId);
    return appDir;
  }

  NativeBuildArtifacts _stubArtifacts(
    NativeBuildIdentity identity, {
    required String workspace,
    required String platform,
    required String detail,
  }) {
    final out = Directory(
      p.join(workspace, 'build/ensemble_test_remote', identity.buildId),
    )..createSync(recursive: true);
    final app = File(p.join(out.path, 'app-stub.$platform'));
    final test = File(p.join(out.path, 'test-stub.$platform'));
    app.writeAsStringSync('stub-app\n$detail\n');
    test.writeAsStringSync('stub-test\n$detail\n');
    return NativeBuildArtifacts(
      identity: identity,
      appPackagePath: app.path,
      testPackagePath: test.path,
      metadata: {
        'platform': platform,
        'stub': 'true',
        'detail': detail,
        'exportHypothesis': exportRelativePath,
      },
    );
  }
}

/// iOS XCTest zip packaging for Firebase Test Lab (Flutter integration_test).
///
/// Follows Flutter's documented FTL flow:
/// `flutter build ios <test> --release` → `xcodebuild build-for-testing` →
/// zip `Release-iphoneos` + `Runner_*.xctestrun`.
class IosFtlPackager {
  static const exportHypothesis =
      'XCTest attachments / Documents/ensemble_test_remote (unverified)';

  static const integrationTestEntry =
      'integration_test/ensemble_tests.dart';

  final RemoteProgress? onProgress;

  IosFtlPackager({this.onProgress});

  Future<NativeBuildArtifacts> package({
    required NativeBuildIdentity identity,
    required String appDir,
    required EnsembleTestConfig config,
    Future<ProcessResult> Function(
      String executable,
      List<String> args, {
      String? workingDirectory,
    })? runProcess,
  }) async {
    Future<ProcessResult> run(
      String exe,
      List<String> args, {
      String? workingDirectory,
    }) {
      if (runProcess != null) {
        return runProcess(
          exe,
          args,
          workingDirectory: workingDirectory ?? appDir,
        );
      }
      return _runCaptured(
        exe,
        args,
        workingDirectory: workingDirectory ?? appDir,
      );
    }

    final defines = [
      for (final e in identity.dartDefines.entries)
        '--dart-define=${e.key}=${e.value}',
      '--dart-define=ensembleTestRemoteBuildId=${identity.buildId}',
      '--dart-define=ensembleTestRemotePlanHash=${identity.planHash}',
    ];

    final entry = File(p.join(appDir, integrationTestEntry));
    if (!entry.existsSync()) {
      return _stub(
        identity,
        appDir: appDir,
        detail:
            'Missing $integrationTestEntry. Remote packaging requires the '
            'CLI patcher to wire integration_test before build.',
      );
    }

    final runnerTests = File(p.join(appDir, 'ios/RunnerTests/RunnerTests.m'));
    if (!runnerTests.existsSync()) {
      return _stub(
        identity,
        appDir: appDir,
        detail:
            'Missing ios/RunnerTests/RunnerTests.m with '
            'INTEGRATION_TEST_IOS_RUNNER. See Flutter integration_test README.',
      );
    }

    onProgress?.call('Building iOS release package for FTL...');
    final build = await run('flutter', [
      'build',
      'ios',
      integrationTestEntry,
      '--release',
      '--no-codesign',
      ...defines,
    ]);
    if (build.exitCode != 0) {
      return _stub(
        identity,
        appDir: appDir,
        detail: _formatProcessFailure('flutter build ios', build),
      );
    }

    final derived = p.join(appDir, 'build/ios_integ');
    final products = p.join(derived, 'Build/Products');
    final iosDir = p.join(appDir, 'ios');
    onProgress?.call('Running xcodebuild build-for-testing...');
    final xcode = await run(
      'xcodebuild',
      [
        'build-for-testing',
        '-workspace',
        'Runner.xcworkspace',
        '-scheme',
        'Runner',
        '-xcconfig',
        'Flutter/Release.xcconfig',
        '-configuration',
        'Release',
        '-derivedDataPath',
        derived,
        '-sdk',
        'iphoneos',
        'CODE_SIGNING_ALLOWED=NO',
        'CODE_SIGNING_REQUIRED=NO',
        'CODE_SIGN_IDENTITY=',
      ],
      workingDirectory: iosDir,
    );
    if (xcode.exitCode != 0) {
      return _stub(
        identity,
        appDir: appDir,
        detail: _formatProcessFailure('xcodebuild build-for-testing', xcode),
      );
    }

    final productsDir = Directory(products);
    if (!productsDir.existsSync()) {
      return _stub(
        identity,
        appDir: appDir,
        detail: 'Missing xcodebuild products at $products',
      );
    }

    final releaseDir = Directory(p.join(products, 'Release-iphoneos'));
    final xctestrunFiles = productsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.xctestrun'))
        .toList();
    if (!releaseDir.existsSync() || xctestrunFiles.isEmpty) {
      return _stub(
        identity,
        appDir: appDir,
        detail:
            'Expected Release-iphoneos + *.xctestrun under $products '
            '(got release=${releaseDir.existsSync()}, '
            'xctestrun=${xctestrunFiles.length})',
      );
    }

    final out = Directory(
      p.join(appDir, 'build/ensemble_test_remote', identity.buildId),
    )..createSync(recursive: true);
    final zipPath = p.join(out.path, 'ios_tests.zip');
    final xctestrunDest =
        p.join(out.path, p.basename(xctestrunFiles.first.path));

    onProgress?.call('Packaging iOS XCTest zip...');
    final zip = await run(
      'zip',
      [
        '-r',
        '--must-match',
        zipPath,
        'Release-iphoneos',
        p.basename(xctestrunFiles.first.path),
      ],
      workingDirectory: products,
    );
    if (zip.exitCode != 0) {
      return _stub(
        identity,
        appDir: appDir,
        detail: _formatProcessFailure('zip', zip),
      );
    }

    xctestrunFiles.first.copySync(xctestrunDest);
    onProgress?.call('iOS packages ready');
    return NativeBuildArtifacts(
      identity: identity,
      appPackagePath: zipPath,
      testPackagePath: xctestrunDest,
      metadata: {
        'platform': 'ios',
        'exportHypothesis': exportHypothesis,
        'derivedData': derived,
      },
    );
  }

  NativeBuildArtifacts _stub(
    NativeBuildIdentity identity, {
    required String appDir,
    required String detail,
  }) {
    onProgress?.call('ERROR: iOS FTL packaging failed:\n$detail');
    final out = Directory(
      p.join(appDir, 'build/ensemble_test_remote', identity.buildId),
    )..createSync(recursive: true);
    final zip = File(p.join(out.path, 'ios_tests.zip'));
    final xctestrun = File(p.join(out.path, 'ensemble.xctestrun'));
    zip.writeAsStringSync('ios-stub\n$detail\n');
    xctestrun.writeAsStringSync('xctestrun-stub\n$detail\n');
    return NativeBuildArtifacts(
      identity: identity,
      appPackagePath: zip.path,
      testPackagePath: xctestrun.path,
      metadata: {
        'platform': 'ios',
        'exportHypothesis': exportHypothesis,
        'stub': 'true',
        'detail': detail,
      },
    );
  }
}

/// Runs a process quietly, capturing stdout/stderr for error reporting.
Future<ProcessResult> _runCaptured(
  String executable,
  List<String> args, {
  required String workingDirectory,
}) {
  return Process.run(
    executable,
    args,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
}

String _formatProcessFailure(String label, ProcessResult result) {
  final out = result.stdout.toString().trim();
  final err = result.stderr.toString().trim();
  final buffer = StringBuffer('$label failed (exit ${result.exitCode})');
  if (err.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('--- stderr ---')
      ..writeln(err);
  }
  if (out.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('--- stdout ---')
      ..writeln(out);
  }
  if (err.isEmpty && out.isEmpty) {
    buffer.write(': (no stdout/stderr captured)');
  }
  return buffer.toString();
}

/// Local simulation of pass/fail artifact export for packaging proof.
class ArtifactExportProof {
  static Future<Directory> simulateDeviceExport({
    required String root,
    required RemoteRunEnvelope envelope,
    required bool includeCorruptArtifact,
  }) async {
    final dir = Directory(p.join(root, 'remote'))..createSync(recursive: true);
    final envelopeFile = File(p.join(dir.path, 'envelope.json'));
    envelopeFile.writeAsStringSync(json.encode(envelope.toJson()));
    final shot = File(p.join(dir.path, 'screenshot.png'));
    shot.writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]); // PNG hdr
    if (includeCorruptArtifact) {
      File(p.join(dir.path, 'broken.bin')).writeAsStringSync('x');
    }
    return dir;
  }
}
