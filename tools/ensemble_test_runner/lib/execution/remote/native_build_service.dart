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
  /// `directoriesToPull`. Prefer `/sdcard/Download` — apps can create it on
  /// FTL (API 36), while `/data/local/tmp/<subdir>` returns Permission denied
  /// and turns green UI runs into `testFailure` at screenshot flush.
  static const exportRelativePath = 'ensemble_test_remote';

  /// Absolute on-device path baked into remote APKs via dart-define.
  ///
  /// Remote packages write screenshots + envelope here (not logcat). FTL
  /// `directoriesToPull` must request this exact path.
  static const onDeviceArtifactRoot =
      '/sdcard/Download/ensemble_test_remote';

  /// Secondary pull/write path (legacy tmp — often unwritable to the app).
  static const onDeviceArtifactRootAlt =
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
/// Follows Flutter's documented FTL flow with the #170119 workaround:
/// debug `--config-only` (once) → `flutter build ios <test> --release` →
/// `xcodebuild build-for-testing` → embed XCTest inject dylib → sanitize
/// `.xctestrun` → zip `Release-iphoneos` + `Runner_*.xctestrun`.
/// Do not re-run debug `--config-only` after release — that leaves
/// `Generated.xcconfig` in debug and can omit `RunnerTests.xctest`.
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
    // __swift_FORCE_LOAD_$_swiftCompatibility56. Pin via TOOLCHAINS env only
    // (do not pass -toolchain into xcodebuild — that can bake host toolchain
    // ids into the .xctestrun and yield FTL "0 test cases").
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
        '-xcconfig',
        'Flutter/Release.xcconfig',
        '-configuration',
        'Release',
        '-destination',
        'generic/platform=iOS',
        '-derivedDataPath',
        derived,
        '-sdk',
        'iphoneos',
        'CODE_SIGNING_ALLOWED=NO',
        'CODE_SIGNING_REQUIRED=NO',
        'CODE_SIGN_IDENTITY=',
        'TREE_SHAKE_ICONS=NO',
        // Release defaults to testability off; without this, build-for-testing
        // can succeed for Runner.app yet skip producing RunnerTests.xctest.
        'ENABLE_TESTABILITY=YES',
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
        .toList()
      ..sort((a, b) {
        // Prefer Runner_*.xctestrun over any other name.
        final aRunner = p.basename(a.path).startsWith('Runner_') ? 0 : 1;
        final bRunner = p.basename(b.path).startsWith('Runner_') ? 0 : 1;
        return aRunner.compareTo(bRunner);
      });
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

    final runnerApp = Directory(p.join(releaseDir.path, 'Runner.app'));
    final runnerTestsBundle = findRunnerTestsXctest(releaseDir);
    if (!runnerApp.existsSync() || runnerTestsBundle == null) {
      final listing = _listShallow(releaseDir);
      final productsListing = _listShallow(productsDir);
      final anyXctest = _findAllXctestBundles(productsDir);
      return _stub(
        identity,
        appDir: root,
        detail:
            'Release-iphoneos missing Runner.app or RunnerTests.xctest '
            '(app=${runnerApp.existsSync()}, '
            'tests=${runnerTestsBundle != null}). '
            'FTL would report 0 XCTest cases.\n'
            'Products:\n$productsListing\n'
            'Release-iphoneos contents:\n$listing\n'
            'Any *.xctest under Products: '
            '${anyXctest.isEmpty ? '(none)' : anyXctest.join(', ')}',
      );
    }

    // Xcode 26+ often omits libXCTestBundleInject.dylib from Runner.app while
    // still referencing it from the .xctestrun → FTL "0 test case results".
    final injectPath = await ensureLibXCTestBundleInject(
      runnerApp,
      runProcess: run,
    );
    if (injectPath == null) {
      return _stub(
        identity,
        appDir: root,
        detail:
            'Missing Runner.app/Frameworks/libXCTestBundleInject.dylib and '
            'could not copy it from the iPhoneOS platform. FTL cannot inject '
            'the XCTest host (0 test case results).',
      );
    }
    onProgress?.call('Ensured XCTest inject dylib at $injectPath');

    // FTL matches the .xctestrun SDK token to the device OS version. Xcode
    // 26.2 often emits Runner_iphoneos26.2-*.xctestrun while the device is
    // 26.3 → "0 test cases". Rename to the remote device version.
    final deviceIosVersion = resolveRemoteIosDeviceVersion(config);
    var xctestrunFile = xctestrunFiles.first;
    final alignedName = alignXctestrunFilenameForIosVersion(
      p.basename(xctestrunFile.path),
      deviceIosVersion,
    );
    if (alignedName != null && alignedName != p.basename(xctestrunFile.path)) {
      final aligned = File(p.join(products, alignedName));
      xctestrunFile.copySync(aligned.path);
      onProgress?.call(
        'Aligned .xctestrun for FTL device iOS $deviceIosVersion: '
        '${p.basename(xctestrunFile.path)} → $alignedName',
      );
      xctestrunFile = aligned;
    } else if (deviceIosVersion != null) {
      onProgress?.call(
        'Using .xctestrun ${p.basename(xctestrunFile.path)} '
        '(device iOS $deviceIosVersion)',
      );
    }

    // Strip Xcode 26 host-only DYLD inserts (libRPAC) and force serial tests.
    // Untouched, FTL often finishes FAILURE with "0 test case results".
    final sanitize = sanitizeXctestrunForFtl(xctestrunFile);
    if (sanitize != null) {
      onProgress?.call('Sanitized .xctestrun for FTL: $sanitize');
    }
    if (!xctestrunDeclaresTestTargets(xctestrunFile)) {
      return _stub(
        identity,
        appDir: root,
        detail:
            '.xctestrun declares no XCTest targets '
            '(${p.basename(xctestrunFile.path)}). FTL would report 0 cases.',
      );
    }

    final out = Directory(
      p.join(root, 'build/ensemble_test_remote', identity.buildId),
    )..createSync(recursive: true);
    final zipPath = p.join(out.path, 'ios_tests.zip');
    final xctestrunDest = p.join(out.path, p.basename(xctestrunFile.path));

    onProgress?.call('Packaging iOS XCTest zip...');
    final zip = await run(
      'zip',
      [
        '-r',
        '--must-match',
        zipPath,
        'Release-iphoneos',
        p.basename(xctestrunFile.path),
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

    xctestrunFile.copySync(xctestrunDest);

    // Fail closed if the zip cannot host XCTest (FTL then reports 0 cases).
    final listed = await run('unzip', ['-l', zipPath]);
    final listing = listed.stdout.toString();
    final hasXctestBundle = listing.contains('RunnerTests.xctest');
    final hasXctestrunInZip = listing.contains('.xctestrun');
    final hasRunnerApp = listing.contains('Runner.app/');
    final hasInjectDylib = listing.contains('libXCTestBundleInject.dylib');
    if (listed.exitCode != 0 ||
        !hasXctestBundle ||
        !hasXctestrunInZip ||
        !hasRunnerApp ||
        !hasInjectDylib) {
      return _stub(
        identity,
        appDir: root,
        detail:
            'ios_tests.zip missing Runner.app, RunnerTests.xctest, '
            '.xctestrun, or libXCTestBundleInject.dylib '
            '(FTL would report 0 cases). unzip exit=${listed.exitCode}\n'
            '$listing',
      );
    }

    onProgress?.call('iOS packages ready');
    // testPackagePath is the same zip: FTL wants one archive (Release-iphoneos +
    // .xctestrun), matching `gcloud firebase test ios run --test ios_tests.zip`.
    return NativeBuildArtifacts(
      identity: identity,
      appPackagePath: zipPath,
      testPackagePath: zipPath,
      metadata: {
        'platform': 'ios',
        'exportHypothesis': exportHypothesis,
        'derivedData': derived,
        'xctestrun': p.basename(xctestrunFile.path),
        'xctestrunCopy': xctestrunDest,
        'zipHasRunnerTests': 'true',
        if (deviceIosVersion != null) 'deviceIosVersion': deviceIosVersion,
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
    // Avoid shell joining: build settings like CODE_SIGN_IDENTITY= must stay
    // intact as argv, and paths with spaces must not be re-split.
    runInShell: false,
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

/// Parses `Xcode 26.2\nBuild version ...` → `26.2`.
String? parseXcodebuildVersionOutput(String stdout) {
  final match = RegExp(r'^Xcode\s+(\d+(?:\.\d+)*)', multiLine: true)
      .firstMatch(stdout);
  return match?.group(1);
}

/// First iOS device version from [config.remote.devices], if any.
String? resolveRemoteIosDeviceVersion(EnsembleTestConfig config) {
  final remote = config.remote;
  if (remote == null) return null;
  for (final device in remote.devices) {
    if (!device.matchesPlatform('ios')) continue;
    final version = device.version?.trim();
    if (version != null && version.isNotEmpty) return version;
  }
  return null;
}

/// Finds `RunnerTests.xctest` under [releaseDir] (sibling or PlugIns).
Directory? findRunnerTestsXctest(Directory releaseDir) {
  if (!releaseDir.existsSync()) return null;
  final sibling = Directory(p.join(releaseDir.path, 'RunnerTests.xctest'));
  if (sibling.existsSync()) return sibling;
  try {
    for (final entity in releaseDir.listSync(recursive: true)) {
      if (entity is! Directory) continue;
      if (p.basename(entity.path) == 'RunnerTests.xctest') return entity;
    }
  } catch (_) {
    return null;
  }
  return null;
}

List<String> _findAllXctestBundles(Directory productsDir) {
  if (!productsDir.existsSync()) return const [];
  try {
    return productsDir
        .listSync(recursive: true)
        .whereType<Directory>()
        .where((d) => d.path.endsWith('.xctest'))
        .map((d) => p.relative(d.path, from: productsDir.path))
        .toList()
      ..sort();
  } catch (_) {
    return const [];
  }
}

String _listShallow(Directory dir) {
  try {
    final names = dir
        .listSync()
        .map((e) => p.basename(e.path))
        .toList()
      ..sort();
    if (names.isEmpty) return '(empty)';
    return names.join('\n');
  } catch (error) {
    return '(could not list: $error)';
  }
}

/// Copies `libXCTestBundleInject.dylib` into [runnerApp]/Frameworks if missing.
///
/// Xcode 26+ `build-for-testing` may omit it while the `.xctestrun` still
/// references `__TESTHOST__/Frameworks/libXCTestBundleInject.dylib`.
Future<String?> ensureLibXCTestBundleInject(
  Directory runnerApp, {
  Future<ProcessResult> Function(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  })? runProcess,
}) async {
  final frameworks = Directory(p.join(runnerApp.path, 'Frameworks'))
    ..createSync(recursive: true);
  final dest = File(p.join(frameworks.path, 'libXCTestBundleInject.dylib'));
  if (dest.existsSync()) {
    return p.relative(dest.path, from: runnerApp.parent.path);
  }

  final run = runProcess ??
      ((exe, args, {workingDirectory, environment}) => Process.run(
            exe,
            args,
            workingDirectory: workingDirectory,
            environment: environment,
          ));
  final sdk = await run('xcrun', [
    '--sdk',
    'iphoneos',
    '--show-sdk-platform-path',
  ]);
  if (sdk.exitCode != 0) return null;
  final platformPath = sdk.stdout.toString().trim();
  if (platformPath.isEmpty) return null;
  final src = File(
    p.join(
      platformPath,
      'Developer',
      'usr',
      'lib',
      'libXCTestBundleInject.dylib',
    ),
  );
  if (!src.existsSync()) return null;
  src.copySync(dest.path);
  return p.relative(dest.path, from: runnerApp.parent.path);
}

const _ftlXcTestInject =
    '__TESTHOST__/Frameworks/libXCTestBundleInject.dylib';

/// Host-only dylibs Xcode 26+ injects that break FTL device launch.
final _ftlHostileDyldInsert = RegExp(
  r'(?:^|:)(/usr/lib/libRPAC\.dylib|/Developer/|/System/Developer/|libMainThreadChecker\.dylib)',
);

/// Rewrites an `.xctestrun` so FTL can load XCTest on device.
///
/// Returns a short description of changes, or null when unchanged/unreadable.
String? sanitizeXctestrunForFtl(File xctestrunFile) {
  if (!xctestrunFile.existsSync()) return null;
  Map<String, dynamic> root;
  try {
    final converted = Process.runSync(
      'plutil',
      ['-convert', 'json', '-o', '-', xctestrunFile.path],
    );
    if (converted.exitCode != 0) return null;
    final decoded = jsonDecode(converted.stdout.toString());
    if (decoded is! Map) return null;
    root = Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }

  final changes = <String>[];

  void sanitizeTarget(String name, Map<String, dynamic> target) {
    if (target['ParallelizationEnabled'] == true) {
      target['ParallelizationEnabled'] = false;
      changes.add('$name.ParallelizationEnabled=false');
    }
    if (target.containsKey('ToolchainsSettingValue')) {
      target.remove('ToolchainsSettingValue');
      changes.add('$name.ToolchainsSettingValue removed');
    }

    final testing = Map<String, dynamic>.from(
      (target['TestingEnvironmentVariables'] as Map?) ?? const {},
    );
    final beforeTesting = testing['DYLD_INSERT_LIBRARIES']?.toString();
    testing['DYLD_INSERT_LIBRARIES'] = _ftlXcTestInject;
    testing.removeWhere((key, _) => key.startsWith('PERFC_'));
    if (beforeTesting != _ftlXcTestInject) {
      changes.add('$name.TestingEnvironmentVariables.DYLD_INSERT_LIBRARIES');
    }
    target['TestingEnvironmentVariables'] = testing;

    final env = Map<String, dynamic>.from(
      (target['EnvironmentVariables'] as Map?) ?? const {},
    );
    final insert = env['DYLD_INSERT_LIBRARIES']?.toString();
    if (insert != null && _ftlHostileDyldInsert.hasMatch(insert)) {
      env.remove('DYLD_INSERT_LIBRARIES');
      changes.add('$name.EnvironmentVariables.DYLD_INSERT_LIBRARIES removed');
    }
    final beforePerfc = env.length;
    env.removeWhere((key, _) => key.startsWith('PERFC_'));
    if (env.length != beforePerfc) {
      changes.add('$name.EnvironmentVariables.PERFC_* removed');
    }
    target['EnvironmentVariables'] = env;
  }

  // Format v1: top-level test-target dictionaries.
  for (final entry in root.entries.toList()) {
    if (entry.key.startsWith('__')) continue;
    if (entry.value is! Map) continue;
    final target = Map<String, dynamic>.from(entry.value as Map);
    if (target['TestBundlePath'] == null && target['TestHostPath'] == null) {
      continue;
    }
    sanitizeTarget(entry.key, target);
    root[entry.key] = target;
  }

  // Format v2: TestConfigurations → TestTargets.
  final configs = root['TestConfigurations'];
  if (configs is List) {
    for (var i = 0; i < configs.length; i++) {
      final config = configs[i];
      if (config is! Map) continue;
      final configMap = Map<String, dynamic>.from(config);
      final targets = configMap['TestTargets'];
      if (targets is! List) continue;
      for (var j = 0; j < targets.length; j++) {
        final t = targets[j];
        if (t is! Map) continue;
        final target = Map<String, dynamic>.from(t);
        sanitizeTarget('TestConfigurations[$i].TestTargets[$j]', target);
        targets[j] = target;
      }
      configMap['TestTargets'] = targets;
      configs[i] = configMap;
    }
    root['TestConfigurations'] = configs;
  }

  if (changes.isEmpty) return null;

  final tmpJson = File('${xctestrunFile.path}.ftl.json');
  try {
    tmpJson.writeAsStringSync(jsonEncode(root));
    final converted = Process.runSync(
      'plutil',
      ['-convert', 'binary1', '-o', xctestrunFile.path, tmpJson.path],
    );
    if (converted.exitCode != 0) return null;
  } finally {
    try {
      if (tmpJson.existsSync()) tmpJson.deleteSync();
    } catch (_) {}
  }
  return changes.join('; ');
}

/// True when [xctestrunFile] lists at least one XCTest target.
bool xctestrunDeclaresTestTargets(File xctestrunFile) {
  try {
    final converted = Process.runSync(
      'plutil',
      ['-convert', 'json', '-o', '-', xctestrunFile.path],
    );
    if (converted.exitCode != 0) return false;
    final decoded = jsonDecode(converted.stdout.toString());
    if (decoded is! Map) return false;
    final root = Map<String, dynamic>.from(decoded);
    for (final entry in root.entries) {
      if (entry.key.startsWith('__')) continue;
      if (entry.value is Map &&
          (entry.value as Map)['TestBundlePath'] != null) {
        return true;
      }
    }
    final configs = root['TestConfigurations'];
    if (configs is List) {
      for (final config in configs) {
        if (config is! Map) continue;
        final targets = config['TestTargets'];
        if (targets is List && targets.isNotEmpty) return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

/// Rewrites `Runner_iphoneos26.2-arm64.xctestrun` → `…26.3…` for FTL.
///
/// Returns null when [filename] is not a `*_iphoneos*-arm64.xctestrun` name.
String? alignXctestrunFilenameForIosVersion(
  String filename,
  String? iosVersion,
) {
  if (iosVersion == null || iosVersion.isEmpty) return null;
  final match = RegExp(
    r'^(.*_iphoneos)\d+(?:\.\d+)*(-arm64\.xctestrun)$',
    caseSensitive: false,
  ).firstMatch(filename);
  if (match == null) return null;
  return '${match.group(1)}$iosVersion${match.group(2)}';
}

/// Local Xcode major.minor for FTL `IosXcTest.xcodeVersion` (must match build).
String? detectLocalXcodeVersion() {
  try {
    final result = Process.runSync(
      'xcodebuild',
      ['-version'],
      runInShell: true,
    );
    if (result.exitCode != 0) return null;
    return parseXcodebuildVersionOutput(result.stdout.toString());
  } catch (_) {
    return null;
  }
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
