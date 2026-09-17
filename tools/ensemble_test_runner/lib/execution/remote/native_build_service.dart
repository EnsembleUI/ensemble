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
  /// On-device export directory for envelope (+ any file artifacts).
  ///
  /// Must match [FirebaseTestLabProvider.androidDirectoriesToPull]. Google’s
  /// Testing API allowlists `/sdcard`, `/storage`, and `/data/local/tmp` for
  /// `directoriesToPull`. Prefer `/data/local/tmp` — it is writable by the app
  /// and not subject to scoped-storage limits that block shared `/sdcard` paths
  /// on API 29+ (see gcloud `firebase test android run --directories-to-pull`).
  static const exportRelativePath = 'ensemble_test_remote';

  /// Absolute on-device path baked into remote APKs via dart-define.
  static const onDeviceArtifactRoot =
      '/data/local/tmp/ensemble_test_remote';

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
    final testTarget = p.join(workspace, 'integration_test/ensemble_tests.dart');
    if (!File(testTarget).existsSync()) {
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail:
            'Missing integration_test/ensemble_tests.dart. Remote packaging '
            'requires the CLI patcher to wire integration_test before build.',
      );
    }

    final hostTest = Directory(
      p.join(workspace, 'android/app/src/androidTest'),
    );
    final hasFlutterTestRunner = hostTest.existsSync() &&
        hostTest.listSync(recursive: true).whereType<File>().any((f) {
          final lower = f.path.toLowerCase();
          if (!lower.endsWith('.java') && !lower.endsWith('.kt')) {
            return false;
          }
          return f.readAsStringSync().contains('FlutterTestRunner');
        });
    if (!hasFlutterTestRunner) {
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail:
            'Missing androidTest host with FlutterTestRunner '
            '(e.g. MainActivityTest). Without it FTL reports SUCCESS with 0 tests.',
      );
    }

    final definePairs = <String>[
      for (final e in identity.dartDefines.entries) '${e.key}=${e.value}',
      'ensembleTestRemoteBuildId=${identity.buildId}',
      'ensembleTestRemotePlanHash=${identity.planHash}',
      'ensembleTestArtifactRoot=${AndroidFtlPackager.onDeviceArtifactRoot}',
    ];
    final flutterDefines = [
      for (final pair in definePairs) '--dart-define=$pair',
    ];
    // Must match flutter_tools encodeDartDefines: each `k=v` is base64'd,
    // then joined with commas. A single base64 of the joined string is wrong
    // and causes assembleDebug to drop defines (screenshots then write to
    // relative build/ → read-only on device / FTL).
    final gradleDartDefines = encodeDartDefinesForGradle(definePairs);

    // Flutter build registers integration_test in the Android project before
    // assembleAndroidTest; without it the instrumentation APK is an empty shell.
    onProgress?.call('Building Android debug APK (integration_test target)...');
    final build = await run('flutter', [
      'build',
      'apk',
      '--debug',
      '--target=$testTarget',
      '--no-tree-shake-icons',
      ...flutterDefines,
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

    final androidDir = p.join(workspace, 'android');
    if (!File(p.join(androidDir, 'gradlew')).existsSync()) {
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail: 'Missing android/gradlew after flutter build',
      );
    }

    // Official Flutter FTL flow: assembleAndroidTest, then assembleDebug -Ptarget.
    onProgress?.call('Assembling Android instrumentation test APK...');
    final assembleTest = await _runCaptured(
      './gradlew',
      [
        'app:assembleAndroidTest',
        '-Pdart-defines=$gradleDartDefines',
      ],
      workingDirectory: androidDir,
    );
    if (assembleTest.exitCode != 0) {
      final detail =
          _formatProcessFailure('gradlew assembleAndroidTest', assembleTest);
      onProgress?.call('ERROR: $detail');
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail: detail,
      );
    }

    onProgress?.call('Assembling Android debug APK with -Ptarget...');
    final assembleDebug = await _runCaptured(
      './gradlew',
      [
        'app:assembleDebug',
        '-Ptarget=$testTarget',
        '-Pdart-defines=$gradleDartDefines',
      ],
      workingDirectory: androidDir,
    );
    if (assembleDebug.exitCode != 0) {
      final detail =
          _formatProcessFailure('gradlew assembleDebug', assembleDebug);
      onProgress?.call('ERROR: $detail');
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail: detail,
      );
    }

    final appCandidates = [
      p.join(workspace, 'build/app/outputs/apk/debug/app-debug.apk'),
      p.join(workspace, 'build/app/outputs/flutter-apk/app-debug.apk'),
    ];
    final testApkPath = p.join(
      workspace,
      'build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk',
    );
    final appApk = appCandidates.firstWhere(
      (path) => File(path).existsSync(),
      orElse: () => '',
    );
    if (appApk.isEmpty || !File(testApkPath).existsSync()) {
      onProgress?.call('ERROR: APKs missing after gradle assemble');
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail:
            'APKs missing after gradle (app=${appApk.isNotEmpty}, '
            'test=${File(testApkPath).existsSync()})',
      );
    }

    final appSize = File(appApk).lengthSync();
    final testSize = File(testApkPath).lengthSync();
    // AGP omits androidx.test / integration_test from the *test* APK when those
    // classes already ship in the app APK (duplicate-class avoidance). A valid
    // Flutter FTL androidTest APK is often ~6KiB and only contains
    // MainActivityTest; AndroidJUnitRunner + FlutterTestRunner live in the app.
    const minAppApkBytes = 500 * 1024;
    const minTestApkBytes = 1500; // MainActivityTest + tiny dex shell
    final hostOk = await _apkDexContainsAny(
      testApkPath,
      const ['MainActivityTest'],
    );
    final runnerOk = await _apkDexContainsAny(
      appApk,
      const ['AndroidJUnitRunner', 'FlutterTestRunner'],
    );
    final entryOk = await _apkKernelContainsAny(
      appApk,
      const [
        'runEnsembleIntegrationYamlTests',
        'integration_test/ensemble_tests.dart',
      ],
    );
    final definesOk = await _apkKernelContainsAny(
      appApk,
      const [
        // Unique value from computeIdentity dart-defines (not a source literal
        // that would false-positive when defines failed to bake).
        NativeBuildService.remoteTestEncryptionKey,
      ],
    );
    if (appSize < minAppApkBytes ||
        testSize < minTestApkBytes ||
        !hostOk ||
        !runnerOk ||
        !entryOk ||
        !definesOk) {
      final detail =
          'Android packages look incomplete for FTL '
          '(app=${_formatBytes(appSize)}, test=${_formatBytes(testSize)}, '
          'mainActivityTestInTestApk=$hostOk, '
          'runnerInAppApk=$runnerOk, '
          'integrationEntryInAppApk=$entryOk, '
          'remoteArtifactRootInAppApk=$definesOk). '
          'Need MainActivityTest in the androidTest APK, '
          'AndroidJUnitRunner/FlutterTestRunner in the app APK, '
          'the integration_test entrypoint, and dart-defines '
          '(especially ensembleTestArtifactRoot) baked via -Ptarget / '
          'correctly encoded -Pdart-defines.';
      onProgress?.call('ERROR: $detail');
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail: detail,
      );
    }

    onProgress?.call(
      'Android packages ready '
      '(app=${_formatBytes(appSize)}, test=${_formatBytes(testSize)}; '
      'MainActivityTest + FlutterTestRunner + integration entry + '
      'remote artifact root OK)',
    );
    return NativeBuildArtifacts(
      identity: identity,
      appPackagePath: appApk,
      testPackagePath: testApkPath,
      metadata: {
        'platform': 'android',
        'exportHypothesis': exportRelativePath,
        'workspace': workspace,
        'appApkBytes': '$appSize',
        'testApkBytes': '$testSize',
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
      Map<String, String>? environment,
    })? runProcess,
  }) async {
    // Always absolute: xcodebuild -derivedDataPath is resolved from ios/, so a
    // relative appDir like "." (CI --app-dir=.) would write products under
    // ios/build/ios_integ while we look in ./build/ios_integ.
    final root = p.normalize(p.absolute(appDir));

    Future<ProcessResult> run(
      String exe,
      List<String> args, {
      String? workingDirectory,
      Map<String, String>? environment,
    }) {
      if (runProcess != null) {
        return runProcess(
          exe,
          args,
          workingDirectory: workingDirectory ?? root,
          environment: environment,
        );
      }
      return _runCaptured(
        exe,
        args,
        workingDirectory: workingDirectory ?? root,
        environment: environment,
      );
    }

    final defines = [
      for (final e in identity.dartDefines.entries)
        '--dart-define=${e.key}=${e.value}',
      '--dart-define=ensembleTestRemoteBuildId=${identity.buildId}',
      '--dart-define=ensembleTestRemotePlanHash=${identity.planHash}',
    ];

    final entry = File(p.join(root, integrationTestEntry));
    if (!entry.existsSync()) {
      return _stub(
        identity,
        appDir: root,
        detail:
            'Missing $integrationTestEntry. Remote packaging requires the '
            'CLI patcher to wire integration_test before build.',
      );
    }

    final runnerTests = File(p.join(root, 'ios/RunnerTests/RunnerTests.m'));
    if (!runnerTests.existsSync()) {
      return _stub(
        identity,
        appDir: root,
        detail:
            'Missing ios/RunnerTests/RunnerTests.m with '
            'INTEGRATION_TEST_IOS_RUNNER. See Flutter integration_test README.',
      );
    }

    onProgress?.call('Building iOS release package for FTL...');
    // Flutter >= 3.32: release-only config can leave integration_test out of
    // the XCTest host so FTL reports 0 cases. Configure once in debug first
    // (flutter/flutter#170119), then build release for the device zip.
    onProgress?.call(
      'Configuring iOS integration_test host (debug --config-only)...',
    );
    final configOnly = await run('flutter', [
      'build',
      'ios',
      integrationTestEntry,
      '--config-only',
      '--debug',
      '--no-codesign',
      ...defines,
    ]);
    if (configOnly.exitCode != 0) {
      return _stub(
        identity,
        appDir: root,
        detail: _formatProcessFailure(
          'flutter build ios --config-only --debug',
          configOnly,
        ),
      );
    }

    final build = await run('flutter', [
      'build',
      'ios',
      integrationTestEntry,
      '--release',
      '--no-codesign',
      '--no-tree-shake-icons',
      ...defines,
    ]);
    if (build.exitCode != 0) {
      return _stub(
        identity,
        appDir: root,
        detail: _formatProcessFailure('flutter build ios', build),
      );
    }

    final derived = p.join(root, 'build/ios_integ');
    final products = p.join(derived, 'Build/Products');
    final iosDir = p.join(root, 'ios');
    // Xcode 26 / macos-26: Metal.xctoolchain is preferred but lacks Swift
    // compatibility libs → RunnerTests link fails with
    // __swift_FORCE_LOAD_$_swiftCompatibility56. Pin the default toolchain.
    // See flutter/flutter#175905 and actions/runner-images#13135.
    const xcodeDefaultToolchain = 'com.apple.dt.toolchain.XcodeDefault';
    onProgress?.call('Running xcodebuild build-for-testing...');
    final xcode = await run(
      'xcodebuild',
      [
        'build-for-testing',
        '-workspace',
        'Runner.xcworkspace',
        '-scheme',
        'Runner',
        '-toolchain',
        xcodeDefaultToolchain,
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
        'TREE_SHAKE_ICONS=NO',
      ],
      workingDirectory: iosDir,
      environment: {
        ...Platform.environment,
        'TOOLCHAINS': xcodeDefaultToolchain,
      },
    );
    if (xcode.exitCode != 0) {
      return _stub(
        identity,
        appDir: root,
        detail: _formatProcessFailure('xcodebuild build-for-testing', xcode),
      );
    }

    final productsDir = Directory(products);
    if (!productsDir.existsSync()) {
      final misplaced = Directory(
        p.join(root, 'ios/build/ios_integ/Build/Products'),
      );
      final hint = misplaced.existsSync()
          ? ' Found products under ios/build/ios_integ (relative '
              'derivedDataPath bug); appDir must be absolute.'
          : '';
      return _stub(
        identity,
        appDir: root,
        detail: 'Missing xcodebuild products at $products.$hint',
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
        appDir: root,
        detail:
            'Expected Release-iphoneos + *.xctestrun under $products '
            '(got release=${releaseDir.existsSync()}, '
            'xctestrun=${xctestrunFiles.length})',
      );
    }

    final out = Directory(
      p.join(root, 'build/ensemble_test_remote', identity.buildId),
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
        appDir: root,
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
        'xctestrun': p.basename(xctestrunFiles.first.path),
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
  Map<String, String>? environment,
}) {
  return Process.run(
    executable,
    args,
    workingDirectory: workingDirectory,
    runInShell: true,
    environment: environment,
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

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KiB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MiB';
}

/// Matches `flutter_tools` [encodeDartDefines] for `-Pdart-defines=`.
String encodeDartDefinesForGradle(List<String> definePairs) {
  return definePairs.map((pair) => base64Encode(utf8.encode(pair))).join(',');
}

/// Scans dex inside an APK for any of [needles] (class name fragments).
Future<bool> _apkDexContainsAny(String apkPath, List<String> needles) async {
  final tmp = Directory.systemTemp.createTempSync('ensemble_apk_scan_');
  try {
    final unzip = await Process.run(
      'unzip',
      ['-o', '-q', apkPath, 'classes*.dex', '-d', tmp.path],
    );
    if (unzip.exitCode != 0) return false;
    for (final entity in tmp.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dex')) continue;
      final listed = await Process.run('strings', [entity.path]);
      if (listed.exitCode != 0) continue;
      final out = listed.stdout.toString();
      for (final needle in needles) {
        if (out.contains(needle)) return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  } finally {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  }
}

/// Scans Flutter kernel / libapp for [needles] (entrypoint / dart-define values).
Future<bool> _apkKernelContainsAny(String apkPath, List<String> needles) async {
  final tmp = Directory.systemTemp.createTempSync('ensemble_apk_kernel_');
  try {
    final unzip = await Process.run(
      'unzip',
      [
        '-o',
        '-q',
        apkPath,
        'assets/flutter_assets/kernel_blob.bin',
        'lib/*/libapp.so',
        '-d',
        tmp.path,
      ],
    );
    if (unzip.exitCode != 0 && !Directory(tmp.path).listSync(recursive: true).any((e) => e is File)) {
      return false;
    }
    Future<bool> scan(File file) async {
      final listed = await Process.run('strings', [file.path]);
      if (listed.exitCode != 0) return false;
      final out = listed.stdout.toString();
      for (final needle in needles) {
        if (out.contains(needle)) return true;
      }
      return false;
    }

    for (final entity in tmp.listSync(recursive: true)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name != 'kernel_blob.bin' && name != 'libapp.so') continue;
      if (await scan(entity)) return true;
    }
    return false;
  } catch (_) {
    return false;
  } finally {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  }
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
