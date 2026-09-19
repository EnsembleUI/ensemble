import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_cli.dart';
import 'package:ensemble_test_runner/execution/remote/acceptance_ledger.dart';
import 'package:ensemble_test_runner/execution/remote/fake_ftl_client.dart';
import 'package:ensemble_test_runner/execution/remote/file_remote_run_store.dart';
import 'package:ensemble_test_runner/execution/remote/firebase_test_lab_provider.dart';
import 'package:ensemble_test_runner/execution/remote/ftl_client.dart';
import 'package:ensemble_test_runner/execution/remote/native_build_service.dart';
import 'package:ensemble_test_runner/execution/remote/remote_host_report.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/execution/remote/remote_orchestrator.dart';
import 'package:ensemble_test_runner/execution/remote/remote_progress.dart';
import 'package:ensemble_test_runner/execution/remote/remote_provider.dart';
import 'package:ensemble_test_runner/execution/remote/remote_report_reconciler.dart';
import 'package:ensemble_test_runner/execution/remote/remote_run_store.dart';
import 'package:ensemble_test_runner/execution/remote/remote_suite_validator.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ExecutionTarget + config', () {
    test('parses target and remote block', () {
      final config = EnsembleTestParser.parseConfigString('''
mode: integration
target: remote
remote:
  provider: firebaseTestLab
  projectId: demo-proj
  devices:
    - model: Pixel2
      version: "30"
      locale: en
      orientation: portrait
  endpoints:
    - name: fixture
      url: https://example.com/mock
''');
      expect(config.mode, ExecutionMode.integration);
      expect(config.target, ExecutionTarget.remote);
      expect(config.remote?.provider, 'firebaseTestLab');
      expect(config.remote?.projectId, 'demo-proj');
      expect(config.remote?.devices.single.model, 'Pixel2');
      expect(config.remote?.endpoints.single.url, 'https://example.com/mock');
    });

    test('CLI --target overrides config', () {
      expect(
        resolveExecutionTargetForTest(
          ['--target=remote'],
          ExecutionTarget.local,
        ),
        ExecutionTarget.remote,
      );
      expect(
        resolveExecutionTargetForTest(const [], ExecutionTarget.remote),
        ExecutionTarget.remote,
      );
    });

    test('plan hash is stable and ignores run ids', () {
      final a = computePlanHash(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
        selectedTestIds: ['b', 'a'],
        buildDefines: {'ensembleTestExecutionMode': 'integration'},
      );
      final b = computePlanHash(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
        selectedTestIds: ['a', 'b'],
        buildDefines: {'ensembleTestExecutionMode': 'integration'},
      );
      expect(a, b);
      expect(a, hasLength(64));
    });
  });

  group('RemoteSuiteValidator', () {
    test('rejects widget + remote', () {
      expect(
        () => RemoteSuiteValidator.validate(
          config: const EnsembleTestConfig(
            mode: ExecutionMode.widget,
            target: ExecutionTarget.remote,
            remote: RemoteExecutionConfig(
              devices: [RemoteDeviceSpec(model: 'Pixel2')],
            ),
          ),
          target: ExecutionTarget.remote,
        ),
        throwsA(isA<EnsembleTestFailure>()),
      );
    });

    test('rejects host-local service commands', () {
      expect(
        () => RemoteSuiteValidator.validate(
          config: EnsembleTestConfig(
            mode: ExecutionMode.integration,
            target: ExecutionTarget.remote,
            remote: const RemoteExecutionConfig(
              devices: [RemoteDeviceSpec(model: 'Pixel2')],
            ),
            services: const [
              TestServiceConfig(name: 'api', command: 'node server.js'),
            ],
          ),
          target: ExecutionTarget.remote,
        ),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (e) => e.message,
            'message',
            contains('host-local'),
          ),
        ),
      );
    });

    test('rejects private LAN URLs', () {
      expect(
        () => RemoteSuiteValidator.validate(
          config: const EnsembleTestConfig(
            mode: ExecutionMode.integration,
            remote: RemoteExecutionConfig(
              devices: [RemoteDeviceSpec(model: 'Pixel2')],
              endpoints: [
                RemoteEndpointConfig(
                  name: 'api',
                  url: 'http://192.168.1.10:8080',
                ),
              ],
            ),
          ),
          target: ExecutionTarget.remote,
        ),
        throwsA(isA<EnsembleTestFailure>()),
      );
    });

    test('allows reachable HTTPS endpoints without command', () {
      expect(
        () => RemoteSuiteValidator.validate(
          config: const EnsembleTestConfig(
            mode: ExecutionMode.integration,
            remote: RemoteExecutionConfig(
              devices: [RemoteDeviceSpec(model: 'Pixel2')],
              endpoints: [
                RemoteEndpointConfig(
                  name: 'api',
                  url: 'https://fixtures.example.com',
                ),
              ],
            ),
            services: [
              TestServiceConfig(
                name: 'api',
                command: '',
                url: 'https://fixtures.example.com',
              ),
            ],
          ),
          target: ExecutionTarget.remote,
        ),
        returnsNormally,
      );
    });
  });

  group('RemoteRunEnvelope', () {
    test('serde round-trip and protocol parse', () {
      final envelope = RemoteRunEnvelope(
        runId: 'run-1',
        planHash: 'abc',
        buildId: 'build-1',
        complete: true,
        cleanupErrors: const ['restore failed'],
        results: const EnsembleTestRunResult(results: []),
      );
      final decoded = RemoteRunEnvelope.fromJson(envelope.toJson());
      expect(decoded.runId, 'run-1');
      expect(decoded.cleanupErrors, ['restore failed']);
      expect(decoded.complete, isTrue);

      // Legacy single-line still parses.
      final output =
          'noise\n$ensembleTestRemoteEnvelopePrefix${json.encode(envelope.toJson())}\n';
      final parsed = parseRemoteRunEnvelopeFromOutput(output);
      expect(parsed?.runId, 'run-1');
    });

    test('chunked envelope protocol round-trips large payloads', () {
      final bigNote = 'x' * 6000;
      final envelope = RemoteRunEnvelope(
        runId: 'chunked-run',
        complete: true,
        results: EnsembleTestRunResult(
          results: const [],
          suiteLogs: [bigNote],
        ),
      );
      final payload = utf8.encode(json.encode(envelope.toJson()));
      final digest = sha256.convert(payload).toString();
      final lines = <String>[
        '$ensembleTestRemoteEnvelopePrefix${json.encode({
          'event': 'start',
          'size': payload.length,
          'sha256': digest,
        })}',
      ];
      for (var offset = 0;
          offset < payload.length;
          offset += ensembleTestRemoteEnvelopeRawChunkSize) {
        final end =
            offset + ensembleTestRemoteEnvelopeRawChunkSize < payload.length
                ? offset + ensembleTestRemoteEnvelopeRawChunkSize
                : payload.length;
        lines.add(
          '$ensembleTestRemoteEnvelopePrefix${json.encode({
            'event': 'chunk',
            'data': base64Encode(payload.sublist(offset, end)),
          })}',
        );
      }
      lines.add(
        '$ensembleTestRemoteEnvelopePrefix${json.encode({'event': 'end'})}',
      );

      final parsed = parseRemoteRunEnvelopeFromOutput(lines.join('\n'));
      expect(parsed?.runId, 'chunked-run');
      expect(parsed?.results?.suiteLogs.single, bigNote);
    });
  });

  group('FileRemoteRunStore CAS', () {
    test('putIntent then putProviderRef increments version', () async {
      final dir = Directory.systemTemp.createTempSync('remote_store_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileRemoteRunStore(dir);
      final manifest = RemoteRunManifest(
        runId: 'r1',
        buildId: 'b1',
        planHash: 'p1',
        intentFingerprint: 'f1',
        clientToken: 'c1',
        platform: 'android',
        devices: const [RemoteDeviceSpec(model: 'Pixel2')],
        status: 'intent',
        updatedAt: DateTime.now().toUtc(),
      );
      await store.putIntent(
        RemoteRunIntent(
          manifest: manifest,
          appPackagePath: '/tmp/app.apk',
          testPackagePath: '/tmp/test.apk',
        ),
      );
      await store.putProviderRef(
        runId: 'r1',
        ref: const RemoteProviderJobRef(jobId: 'm1', matrixId: 'm1'),
        expectedVersion: 1,
      );
      final got = await store.get('r1');
      expect(got?.version, 2);
      expect(got?.providerRef?.jobId, 'm1');
      expect(got?.status, 'submitted');
    });

    test('compareAndSwap rejects stale version', () async {
      final dir = Directory.systemTemp.createTempSync('remote_store_cas_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileRemoteRunStore(dir);
      final manifest = RemoteRunManifest(
        runId: 'r2',
        buildId: 'b1',
        planHash: 'p1',
        intentFingerprint: 'f1',
        clientToken: 'c1',
        platform: 'android',
        devices: const [RemoteDeviceSpec(model: 'Pixel2')],
        status: 'intent',
        updatedAt: DateTime.now().toUtc(),
      );
      await store.putIntent(
        RemoteRunIntent(
          manifest: manifest,
          appPackagePath: '/a',
          testPackagePath: '/t',
        ),
      );
      final ok = await store.compareAndSwap(
        next: manifest.copyWith(status: 'x', version: 99),
        expectedVersion: 5,
      );
      expect(ok, isFalse);
    });
  });

  group('Fake FTL provider contract', () {
    test('submit, uncertain accept, resume, cancel, collect', () async {
      final client = FakeFtlClient();
      final provider = FirebaseTestLabProvider(
        client: client,
        projectId: 'demo',
        limits: const RemoteProviderLimits(
          pollInterval: Duration(milliseconds: 1),
          maxPollDuration: Duration(seconds: 2),
        ),
      );
      final intent = RemoteSubmitIntent(
        runId: 'run',
        buildId: 'build',
        planHash: 'plan',
        intentFingerprint: 'fp',
        clientToken: 'token-1',
        devices: const [RemoteDeviceSpec(model: 'Pixel2')],
        appPackagePath: '/tmp/app.apk',
        testPackagePath: '/tmp/test.apk',
        platform: 'android',
      );
      File(intent.appPackagePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('apk');
      File(intent.testPackagePath).writeAsStringSync('test');

      final ref = await provider.submit(intent);
      expect(ref.jobId, isNotEmpty);
      expect(ref.metadata['resultsUrl'], contains('histories/hist-demo/matrices/'));
      expect(ref.metadata['resultsUrl'], contains('5114929840549376702'));
      expect(ref.metadata['historyId'], 'hist-demo');
      expect(ref.metadata['consoleUrl'], ref.metadata['resultsUrl']);
      expect(ref.metadata['resultsUrl'], isNot(contains('matrix-')));

      client.uncertainNextSubmit = true;
      final adopted = await provider.submit(intent);
      expect(adopted.jobId, ref.jobId);

      client.finish(ref.jobId, outcome: 'SUCCESS');
      final status = await provider.getStatus(ref);
      expect(status.state, RemoteJobState.finished);

      final dest = Directory.systemTemp.createTempSync('ftl_collect_');
      addTearDown(() => dest.deleteSync(recursive: true));
      final collected = await provider.collectArtifacts(
        ref,
        destinationDirectory: dest.path,
      );
      expect(collected.localDirectory, dest.path);
      expect(
        File(p.join(dest.path, 'remote', 'envelope.json')).existsSync(),
        isTrue,
      );

      await provider.requestCancel(ref);
      final cancelled = await provider.getStatus(ref);
      expect(cancelled.state, RemoteJobState.cancelled);
    });

    test('iOS submit is zip-only (no bare xctestrun override)', () async {
      final client = FakeFtlClient();
      final provider = FirebaseTestLabProvider(
        client: client,
        projectId: 'demo',
      );
      final zip = File('${Directory.systemTemp.path}/ios_tests_contract.zip')
        ..writeAsBytesSync(List<int>.filled(64, 7));
      addTearDown(() {
        if (zip.existsSync()) zip.deleteSync();
      });
      final intent = RemoteSubmitIntent(
        runId: 'run-ios',
        buildId: 'build-ios',
        planHash: 'plan',
        intentFingerprint: 'fp-ios',
        clientToken: 'token-ios',
        devices: const [
          RemoteDeviceSpec(platform: 'ios', model: 'iphonese3', version: '26.3'),
        ],
        appPackagePath: zip.path,
        testPackagePath: zip.path,
        platform: 'ios',
      );

      final ref = await provider.submit(intent);
      expect(ref.jobId, isNotEmpty);
      expect(client.submitLog, hasLength(1));
      final payload = client.submitLog.single;
      expect(payload['kind'], 'ios');
      expect(payload.containsKey('xctestrunGcs'), isFalse);
      expect(payload['testsZipGcs'], startsWith('gs://fake-bucket/'));
    });

    test('refuses oversized device matrix', () async {
      final provider = FirebaseTestLabProvider(
        client: FakeFtlClient(),
        projectId: 'demo',
        limits: const RemoteProviderLimits(maxDevicesPerRun: 1),
      );
      expect(
        () => provider.submit(
          RemoteSubmitIntent(
            runId: 'r',
            buildId: 'b',
            planHash: 'p',
            intentFingerprint: 'f',
            clientToken: 'c',
            devices: const [
              RemoteDeviceSpec(model: 'a'),
              RemoteDeviceSpec(model: 'b'),
            ],
            appPackagePath: '/a',
            testPackagePath: '/t',
            platform: 'android',
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('RemoteReportReconciler', () {
    test('classifies pass / test failure / incomplete / artifact', () {
      final dir = Directory.systemTemp.createTempSync('reconcile_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'remote')).createSync(recursive: true);
      File(p.join(dir.path, 'remote', 'envelope.json')).writeAsStringSync(
        json.encode(
          const RemoteRunEnvelope(
            runId: 'r',
            complete: true,
            results: EnsembleTestRunResult(results: []),
          ).toJson(),
        ),
      );

      final pass = RemoteReportReconciler.reconcile(
        deviceKey: 'primary',
        nativeOutcome: 'SUCCESS',
        envelope: RemoteReportReconciler.loadEnvelope(dir),
        artifactDirectory: dir,
      );
      expect(pass.failureClass, RemoteExecutionFailureClass.pass);
      expect(pass.exitCode, 0);

      final failEnv = RemoteRunEnvelope(
        runId: 'r',
        complete: true,
        results: EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.failed(
              testId: 't',
              durationMs: 1,
              error: 'boom',
            ),
          ],
        ),
      );
      final testFail = RemoteReportReconciler.reconcile(
        deviceKey: 'primary',
        nativeOutcome: 'FAILURE',
        envelope: failEnv,
        artifactDirectory: dir,
      );
      expect(testFail.failureClass, RemoteExecutionFailureClass.testFailure);
      expect(testFail.exitCode, 1);

      final incomplete = RemoteReportReconciler.reconcile(
        deviceKey: 'primary',
        nativeOutcome: 'SUCCESS',
        envelope: null,
        artifactDirectory: dir,
      );
      expect(
        incomplete.failureClass,
        RemoteExecutionFailureClass.incomplete,
      );

      final badDir = Directory.systemTemp.createTempSync('reconcile_bad_');
      addTearDown(() => badDir.deleteSync(recursive: true));
      final artifactFail = RemoteReportReconciler.reconcile(
        deviceKey: 'primary',
        nativeOutcome: 'SUCCESS',
        envelope: const RemoteRunEnvelope(
          runId: 'r',
          complete: true,
          artifacts: [
            RemoteArtifactEntry(path: 'screenshots/missing.png'),
          ],
        ),
        artifactDirectory: badDir,
      );
      expect(
        artifactFail.failureClass,
        RemoteExecutionFailureClass.artifactFailure,
      );
    });

    test('loadEnvelope finds Download and data/local/tmp trees + logcat', () {
      final dir = Directory.systemTemp.createTempSync('envelope_load_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final nested = File(
        p.join(
          dir.path,
          'sdcard',
          'Download',
          'ensemble_test_remote',
          'remote',
          'envelope.json',
        ),
      )..parent.createSync(recursive: true);
      nested.writeAsStringSync(
        json.encode(
          const RemoteRunEnvelope(
            runId: 'from-download',
            complete: true,
            results: EnsembleTestRunResult(results: []),
          ).toJson(),
        ),
      );
      expect(
        RemoteReportReconciler.loadEnvelope(dir)?.runId,
        'from-download',
      );

      final tmpOnly = Directory.systemTemp.createTempSync('envelope_tmp_');
      addTearDown(() => tmpOnly.deleteSync(recursive: true));
      File(
        p.join(
          tmpOnly.path,
          'data',
          'local',
          'tmp',
          'ensemble_test_remote',
          'remote',
          'envelope.json',
        ),
      )
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          json.encode(
            const RemoteRunEnvelope(
              runId: 'from-tmp',
              complete: true,
              results: EnsembleTestRunResult(results: []),
            ).toJson(),
          ),
        );
      expect(
        RemoteReportReconciler.loadEnvelope(tmpOnly)?.runId,
        'from-tmp',
      );

      final logOnly = Directory.systemTemp.createTempSync('envelope_log_');
      addTearDown(() => logOnly.deleteSync(recursive: true));
      final envelope = const RemoteRunEnvelope(
        runId: 'from-logcat',
        complete: true,
        results: EnsembleTestRunResult(results: []),
      );
      File(p.join(logOnly.path, 'logcat'))
        ..writeAsStringSync(
          'noise\n$ensembleTestRemoteEnvelopePrefix${json.encode(envelope.toJson())}\n',
        );
      expect(
        RemoteReportReconciler.loadEnvelope(logOnly)?.runId,
        'from-logcat',
      );
    });
  });

  group('Native build identity', () {
    test('excludes run id and uses deterministic encryption key', () {
      final a = NativeBuildService.computeIdentity(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
        platform: 'android',
        variant: 'debug',
        selectedTestIds: const ['t1'],
        dartDefines: const {
          'ensembleTestRemoteRunId': 'should-not-matter',
          'ensembleTestEncryptionKey': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        },
      );
      final b = NativeBuildService.computeIdentity(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
        platform: 'android',
        variant: 'debug',
        selectedTestIds: const ['t1'],
        dartDefines: const {
          'ensembleTestRemoteRunId': 'different',
          'ensembleTestEncryptionKey': 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
        },
      );
      expect(a.buildId, b.buildId);
      expect(
        a.dartDefines['ensembleTestEncryptionKey'],
        NativeBuildService.remoteTestEncryptionKey,
      );
      expect(a.dartDefines.containsKey('ensembleTestRemoteRunId'), isFalse);
    });
  });

  group('Artifact export proof (local)', () {
    test('pass and fail envelopes write collectable files', () async {
      final root = Directory.systemTemp.createTempSync('export_proof_');
      addTearDown(() => root.deleteSync(recursive: true));

      final passEnv = const RemoteRunEnvelope(
        runId: 'pass',
        complete: true,
        results: EnsembleTestRunResult(results: []),
      );
      final passDir = await ArtifactExportProof.simulateDeviceExport(
        root: p.join(root.path, 'pass'),
        envelope: passEnv,
        includeCorruptArtifact: false,
      );
      expect(File(p.join(passDir.path, 'envelope.json')).existsSync(), isTrue);

      final failEnv = RemoteRunEnvelope(
        runId: 'fail',
        complete: true,
        results: EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.failed(
              testId: 'x',
              durationMs: 1,
              error: 'assert',
            ),
          ],
        ),
      );
      final failDir = await ArtifactExportProof.simulateDeviceExport(
        root: p.join(root.path, 'fail'),
        envelope: failEnv,
        includeCorruptArtifact: true,
      );
      final loaded = RemoteReportReconciler.loadEnvelope(
        Directory(p.dirname(failDir.path)),
      );
      expect(loaded?.results?.failedCount, 1);
    });
  });

  group('RemoteOrchestrator with fake provider', () {
    test('intent → submit → collect → reconcile', () async {
      final client = FakeFtlClient();
      final storeDir = Directory.systemTemp.createTempSync('orch_store_');
      final appDir = Directory.systemTemp.createTempSync('orch_app_');
      addTearDown(() {
        storeDir.deleteSync(recursive: true);
        appDir.deleteSync(recursive: true);
      });

      final provider = FirebaseTestLabProvider(
        client: client,
        projectId: 'demo',
        limits: const RemoteProviderLimits(
          pollInterval: Duration(milliseconds: 1),
          maxPollDuration: Duration(seconds: 3),
        ),
      );
      final orch = RemoteOrchestrator(
        provider: provider,
        store: FileRemoteRunStore(storeDir),
        buildService: NativeBuildService(
          cacheDirectory: Directory(p.join(appDir.path, 'cache')),
          builder: (identity, {required appDir, required config}) async {
            final out = Directory(p.join(appDir, 'pkgs'))..createSync();
            final app = File(p.join(out.path, 'app.apk'))..writeAsStringSync('a');
            final test = File(p.join(out.path, 'test.apk'))
              ..writeAsStringSync('t');
            return NativeBuildArtifacts(
              identity: identity,
              appPackagePath: app.path,
              testPackagePath: test.path,
            );
          },
        ),
      );

      // Finish job shortly after submit.
      Future<void>.delayed(const Duration(milliseconds: 20), () {
        for (final snap in client.matrices.values) {
          client.finish(snap.matrixId);
        }
      });

      final report = await orch.runSuite(
        appDir: appDir.path,
        config: const EnsembleTestConfig(
          mode: ExecutionMode.integration,
          target: ExecutionTarget.remote,
          remote: RemoteExecutionConfig(
            devices: [RemoteDeviceSpec(model: 'Pixel2')],
          ),
        ),
        platform: 'android',
        selectedTestIds: const ['t1'],
      );
      expect(report.runId, isNotEmpty);
      expect(report.devices, isNotEmpty);
      // Fake collect writes a complete empty-results envelope → pass.
      expect(report.overall, RemoteExecutionFailureClass.pass);
    });
  });

  group('Acceptance ledger', () {
    test('is not production-ready without verified cloud rows', () {
      expect(RemoteAcceptanceLedger.isProductionReady, isFalse);
      expect(
        RemoteAcceptanceLedger.renderMarkdown(),
        contains('Production-ready:** NO'),
      );
    });
  });

  group('Envelope lifecycle source contract', () {
    test('entry emits envelope only after storage restore', () {
      final source = File('lib/entry/ensemble_test_entry.dart').readAsStringSync();
      final restoreIdx = source.indexOf('restorePreSuiteStorageAtSuiteEnd()');
      final envelopeIdx = source.indexOf('_emitRemoteRunEnvelopeIfRequested');
      expect(restoreIdx, greaterThan(0));
      expect(envelopeIdx, greaterThan(restoreIdx));
      expect(source, contains('cleanupErrors'));
    });
  });

  group('FTL console links + progress', () {
    test('prefers official resultsUrl over invented matrix-* paths', () {
      final historyId = historyIdFromTestMatrixJson({
        'testMatrixId': 'matrix-abc',
        'resultStorage': {
          'toolResultsHistory': {'historyId': 'bh.c9c1e6677f16de48'},
          'resultsUrl':
              'https://console.firebase.google.com/project/build-system-test/'
              'testlab/histories/bh.c9c1e6677f16de48/matrices/5114929840549376702',
        },
      });
      expect(historyId, 'bh.c9c1e6677f16de48');
      final resultsUrl = resultsUrlFromTestMatrixJson({
        'resultStorage': {
          'resultsUrl':
              'https://console.firebase.google.com/project/build-system-test/'
              'testlab/histories/bh.c9c1e6677f16de48/matrices/5114929840549376702',
        },
      });
      final links = FtlConsoleLinks(
        projectId: 'build-system-test',
        matrixId: 'matrix-abc',
        historyId: historyId,
        resultsUrl: resultsUrl,
      );
      expect(links.bestUrl, resultsUrl);
      expect(links.logLine, contains('5114929840549376702'));
      expect(links.logLine, isNot(contains('matrix-abc')));
      expect(links.toMetadata()['resultsUrl'], resultsUrl);
    });

    test('without resultsUrl does not invent a console link', () {
      final links = FtlConsoleLinks(
        projectId: 'my-proj',
        matrixId: 'matrix-abc',
        historyId: 'hist-123',
      );
      expect(links.hasOfficialResultsUrl, isFalse);
      expect(links.bestUrl, isNull);
      expect(links.logLine, contains('matrix-abc'));
      expect(links.logLine, contains('results URL pending'));
      expect(links.logLine, isNot(contains('https://')));
      expect(links.toMetadata().containsKey('resultsUrl'), isFalse);
    });

    test('orchestrator refuses stub packages before FTL submit', () async {
      final storeDir = Directory.systemTemp.createTempSync('stub_store_');
      final appDir = Directory.systemTemp.createTempSync('stub_app_');
      addTearDown(() {
        storeDir.deleteSync(recursive: true);
        appDir.deleteSync(recursive: true);
      });
      final logs = <String>[];
      final orch = RemoteOrchestrator(
        provider: FirebaseTestLabProvider(
          client: FakeFtlClient(),
          projectId: 'demo',
        ),
        store: FileRemoteRunStore(storeDir),
        onProgress: logs.add,
        buildService: NativeBuildService(
          cacheDirectory: Directory(p.join(appDir.path, 'cache')),
          builder: (identity, {required appDir, required config}) async {
            final out = Directory(p.join(appDir, 'pkgs'))..createSync();
            final app = File(p.join(out.path, 'app-stub.android'))
              ..writeAsStringSync('stub');
            final test = File(p.join(out.path, 'test-stub.android'))
              ..writeAsStringSync('stub');
            return NativeBuildArtifacts(
              identity: identity,
              appPackagePath: app.path,
              testPackagePath: test.path,
              metadata: const {
                'stub': 'true',
                'detail': 'flutter build apk failed: boom',
              },
            );
          },
        ),
      );

      await expectLater(
        orch.runSuite(
          appDir: appDir.path,
          config: const EnsembleTestConfig(
            mode: ExecutionMode.integration,
            target: ExecutionTarget.remote,
            remote: RemoteExecutionConfig(
              devices: [RemoteDeviceSpec(model: 'Pixel2')],
            ),
          ),
          platform: 'android',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('stub'),
          ),
        ),
      );
      expect(logs, isNotEmpty);
      expect(logs.first, contains('Build identity'));
    });
  });

  test('IosFtlPackager passes absolute -derivedDataPath when appDir is "."',
      () async {
    final appDir = Directory.systemTemp.createTempSync('ios_rel_app_');
    addTearDown(() {
      if (appDir.existsSync()) appDir.deleteSync(recursive: true);
    });
    File(p.join(appDir.path, 'integration_test/ensemble_tests.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('void main() {}');
    File(p.join(appDir.path, 'ios/RunnerTests/RunnerTests.m'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('INTEGRATION_TEST_IOS_RUNNER(RunnerTests)\n');
    Directory(p.join(appDir.path, 'ios')).createSync(recursive: true);

    String? derivedDataPath;
    final flutterCalls = <List<String>>[];
    final previous = Directory.current;
    Directory.current = appDir;
    try {
      final identity = NativeBuildService.computeIdentity(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
        platform: 'ios',
        variant: 'release',
        selectedTestIds: const ['t1'],
      );
      final artifacts = await IosFtlPackager().package(
        identity: identity,
        appDir: '.',
        config: const EnsembleTestConfig(
          mode: ExecutionMode.integration,
          target: ExecutionTarget.remote,
          remote: RemoteExecutionConfig(
            devices: [
              RemoteDeviceSpec(
                platform: 'ios',
                model: 'iphonese3',
                version: '26.3',
              ),
            ],
          ),
        ),
        runProcess: (
          exe,
          args, {
          workingDirectory,
          environment,
        }) async {
          if (exe == 'flutter') {
            flutterCalls.add(List<String>.from(args));
            expect(args, contains('build'));
            expect(args, contains('ios'));
          }
          if (exe == 'xcodebuild') {
            final i = args.indexOf('-derivedDataPath');
            expect(i, greaterThanOrEqualTo(0));
            derivedDataPath = args[i + 1];
            expect(args, isNot(contains('-toolchain')));
            expect(args, contains('CODE_SIGNING_ALLOWED=NO'));
            expect(args, contains('CODE_SIGNING_REQUIRED=NO'));
            expect(args, contains('ENABLE_TESTABILITY=YES'));
            expect(args, contains('generic/platform=iOS'));
            expect(args, contains('TREE_SHAKE_ICONS=NO'));
            final products = Directory(
              p.join(derivedDataPath!, 'Build/Products'),
            )..createSync(recursive: true);
            final release = Directory(
              p.join(products.path, 'Release-iphoneos'),
            )..createSync(recursive: true);
            Directory(p.join(release.path, 'Runner.app', 'Frameworks'))
                .createSync(recursive: true);
            Directory(
              p.join(
                release.path,
                'Runner.app',
                'PlugIns',
                'RunnerTests.xctest',
              ),
            ).createSync(recursive: true);
            File(
              p.join(
                release.path,
                'Runner.app',
                'Frameworks',
                'libXCTestBundleInject.dylib',
              ),
            ).writeAsBytesSync(const [1, 2, 3]);
            File(p.join(products.path, 'Runner_iphoneos26.3-arm64.xctestrun'))
                .writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>RunnerTests</key>
  <dict>
    <key>TestBundlePath</key>
    <string>__TESTHOST__/PlugIns/RunnerTests.xctest</string>
    <key>TestHostPath</key>
    <string>__TESTROOT__/Release-iphoneos/Runner.app</string>
  </dict>
</dict>
</plist>
''');
            await Process.run('plutil', [
              '-convert',
              'binary1',
              p.join(products.path, 'Runner_iphoneos26.3-arm64.xctestrun'),
            ]);
          }
          if (exe == 'zip') {
            final zipPath = args.firstWhere((a) => a.endsWith('ios_tests.zip'));
            // Generated name as-is — no rename to device version.
            expect(args, contains('Runner_iphoneos26.3-arm64.xctestrun'));
            File(zipPath)
              ..parent.createSync(recursive: true)
              ..writeAsBytesSync([1, 2, 3, 4]);
          }
          if (exe == 'unzip') {
            return ProcessResult(
              0,
              0,
              'Release-iphoneos/\n'
              'Release-iphoneos/Runner.app/\n'
              'Release-iphoneos/Runner.app/Frameworks/libXCTestBundleInject.dylib\n'
              'Release-iphoneos/Runner.app/PlugIns/RunnerTests.xctest/\n'
              'Runner_iphoneos26.3-arm64.xctestrun\n',
              '',
            );
          }
          return ProcessResult(0, 0, '', '');
        },
      );
      expect(artifacts.appPackagePath, artifacts.testPackagePath);
      expect(artifacts.metadata['stub'], isNot('true'));
      expect(artifacts.metadata['zipHasRunnerTests'], 'true');
      expect(artifacts.metadata['xctestrunSdk'], '26.3');
      expect(flutterCalls, hasLength(2));
      expect(flutterCalls[0], contains('--config-only'));
      expect(flutterCalls[0], contains('--debug'));
      expect(flutterCalls[1], contains('--release'));
      expect(flutterCalls[1], isNot(contains('--config-only')));
    } finally {
      Directory.current = previous;
    }

    expect(derivedDataPath, isNotNull);
    expect(p.isAbsolute(derivedDataPath!), isTrue);
    expect(
      derivedDataPath,
      isNot(contains('${p.separator}ios${p.separator}build${p.separator}')),
    );
    expect(derivedDataPath, endsWith(p.join('build', 'ios_integ')));
  });

  test('IosFtlPackager allows same-major device OS vs xctestrun SDK', () async {
    final appDir = Directory.systemTemp.createTempSync('ios_sdk_same_major_');
    addTearDown(() {
      if (appDir.existsSync()) appDir.deleteSync(recursive: true);
    });
    File(p.join(appDir.path, 'integration_test/ensemble_tests.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('void main() {}');
    File(p.join(appDir.path, 'ios/RunnerTests/RunnerTests.m'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('INTEGRATION_TEST_IOS_RUNNER(RunnerTests)\n');

    final artifacts = await IosFtlPackager().package(
      identity: NativeBuildService.computeIdentity(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
        platform: 'ios',
        variant: 'release',
        selectedTestIds: const ['t1'],
      ),
      appDir: appDir.path,
      config: const EnsembleTestConfig(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
        remote: RemoteExecutionConfig(
          devices: [
            RemoteDeviceSpec(
              platform: 'ios',
              model: 'iphonese3',
              version: '26.3',
            ),
          ],
        ),
      ),
      runProcess: (exe, args, {workingDirectory, environment}) async {
        if (exe == 'xcodebuild') {
          final i = args.indexOf('-derivedDataPath');
          final products = Directory(
            p.join(args[i + 1], 'Build/Products'),
          )..createSync(recursive: true);
          Directory(
            p.join(
              products.path,
              'Release-iphoneos',
              'Runner.app',
              'PlugIns',
              'RunnerTests.xctest',
            ),
          ).createSync(recursive: true);
          File(
            p.join(
              products.path,
              'Release-iphoneos',
              'Runner.app',
              'Frameworks',
              'libXCTestBundleInject.dylib',
            ),
          )
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(const [1, 2, 3]);
          File(p.join(products.path, 'Runner_iphoneos26.2-arm64.xctestrun'))
              .writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>RunnerTests</key>
  <dict>
    <key>TestBundlePath</key>
    <string>__TESTHOST__/PlugIns/RunnerTests.xctest</string>
  </dict>
</dict>
</plist>
''');
          await Process.run('plutil', [
            '-convert',
            'binary1',
            p.join(products.path, 'Runner_iphoneos26.2-arm64.xctestrun'),
          ]);
        }
        if (exe == 'zip') {
          final zipPath = args.firstWhere((a) => a.endsWith('ios_tests.zip'));
          // Catalog-aligned filename (contents still from generated 26.2 file).
          expect(args, contains('Runner_iphoneos26.3-arm64.xctestrun'));
          File(zipPath)
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync([1, 2, 3, 4]);
        }
        if (exe == 'unzip') {
          return ProcessResult(
            0,
            0,
            'Release-iphoneos/\n'
            'Release-iphoneos/Runner.app/\n'
            'Release-iphoneos/Runner.app/Frameworks/libXCTestBundleInject.dylib\n'
            'Release-iphoneos/Runner.app/PlugIns/RunnerTests.xctest/\n'
            'Runner_iphoneos26.3-arm64.xctestrun\n',
            '',
          );
        }
        return ProcessResult(0, 0, '', '');
      },
    );
    expect(artifacts.metadata['stub'], isNot('true'));
    expect(artifacts.metadata['xctestrunSdk'], '26.2');
    expect(artifacts.metadata['xctestrun'], 'Runner_iphoneos26.3-arm64.xctestrun');
    expect(artifacts.metadata['deviceIosVersion'], '26.3');
  });

  test('IosFtlPackager stubs when device iOS major mismatches xctestrun SDK',
      () async {
    final appDir = Directory.systemTemp.createTempSync('ios_sdk_mismatch_');
    addTearDown(() {
      if (appDir.existsSync()) appDir.deleteSync(recursive: true);
    });
    File(p.join(appDir.path, 'integration_test/ensemble_tests.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('void main() {}');
    File(p.join(appDir.path, 'ios/RunnerTests/RunnerTests.m'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('INTEGRATION_TEST_IOS_RUNNER(RunnerTests)\n');

    final artifacts = await IosFtlPackager().package(
      identity: NativeBuildService.computeIdentity(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
        platform: 'ios',
        variant: 'release',
        selectedTestIds: const ['t1'],
      ),
      appDir: appDir.path,
      config: const EnsembleTestConfig(
        mode: ExecutionMode.integration,
        target: ExecutionTarget.remote,
        remote: RemoteExecutionConfig(
          devices: [
            RemoteDeviceSpec(
              platform: 'ios',
              model: 'iphonese3',
              version: '27.0',
            ),
          ],
        ),
      ),
      runProcess: (exe, args, {workingDirectory, environment}) async {
        if (exe == 'xcodebuild') {
          final i = args.indexOf('-derivedDataPath');
          final products = Directory(
            p.join(args[i + 1], 'Build/Products'),
          )..createSync(recursive: true);
          Directory(
            p.join(
              products.path,
              'Release-iphoneos',
              'Runner.app',
              'PlugIns',
              'RunnerTests.xctest',
            ),
          ).createSync(recursive: true);
          File(
            p.join(
              products.path,
              'Release-iphoneos',
              'Runner.app',
              'Frameworks',
              'libXCTestBundleInject.dylib',
            ),
          )
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(const [1, 2, 3]);
          File(p.join(products.path, 'Runner_iphoneos26.2-arm64.xctestrun'))
              .writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>RunnerTests</key>
  <dict>
    <key>TestBundlePath</key>
    <string>__TESTHOST__/PlugIns/RunnerTests.xctest</string>
  </dict>
</dict>
</plist>
''');
          await Process.run('plutil', [
            '-convert',
            'binary1',
            p.join(products.path, 'Runner_iphoneos26.2-arm64.xctestrun'),
          ]);
        }
        return ProcessResult(0, 0, '', '');
      },
    );
    expect(artifacts.metadata['stub'], 'true');
    expect(
      artifacts.metadata['detail'],
      contains('major does not match'),
    );
  });

  test('parseXctestrunIosSdkVersion reads SDK token from filename', () {
    expect(
      parseXctestrunIosSdkVersion('Runner_iphoneos26.2-arm64.xctestrun'),
      '26.2',
    );
    expect(
      parseXctestrunIosSdkVersion('Runner_iphoneos26.3-arm64.xctestrun'),
      '26.3',
    );
    expect(parseXctestrunIosSdkVersion('not-an-xctestrun'), isNull);
    expect(iosVersionsShareMajor('26.2', '26.3'), isTrue);
    expect(iosVersionsShareMajor('26.2', '27.0'), isFalse);
    expect(
      alignXctestrunFilenameForIosVersion(
        'Runner_iphoneos26.2-arm64.xctestrun',
        '26.3',
      ),
      'Runner_iphoneos26.3-arm64.xctestrun',
    );
  });

  test('summarizeFtlMatrixEvidence includes progress message text', () {
    expect(
      summarizeFtlMatrixEvidence({
        'state': 'FINISHED',
        'outcomeSummary': 'FAILURE',
        'testExecutions': [
          {
            'state': 'FINISHED',
            'testDetails': {
              'errorMessage': 'Infrastructure error occurred.',
              'progressMessages': [
                'Starting',
                'Installing',
              ],
            },
          },
        ],
      }),
      contains('progress=[Starting | Installing]'),
    );
  });

  test('summarizeFtlMatrixEvidence surfaces invalidMatrix and executions', () {
    expect(
      summarizeFtlMatrixEvidence({
        'state': 'FINISHED',
        'outcomeSummary': 'FAILURE',
        'invalidMatrixDetails': 'INVALID_INPUT_APK',
        'testExecutions': [
          {
            'state': 'FINISHED',
            'testDetails': {
              'errorMessage': '0 test cases',
              'progressMessages': ['a', 'b'],
            },
          },
        ],
      }),
      contains('invalidMatrixDetails=INVALID_INPUT_APK'),
    );
  });

  test('findRunnerTestsXctest finds sibling or PlugIns bundle', () {
    final root = Directory.systemTemp.createTempSync('xctest_find_');
    addTearDown(() => root.deleteSync(recursive: true));

    final release = Directory(p.join(root.path, 'Release-iphoneos'))
      ..createSync();
    expect(findRunnerTestsXctest(release), isNull);

    final sibling = Directory(p.join(release.path, 'RunnerTests.xctest'))
      ..createSync();
    expect(findRunnerTestsXctest(release)?.path, sibling.path);

    sibling.deleteSync(recursive: true);
    final nested = Directory(
      p.join(release.path, 'Runner.app', 'PlugIns', 'RunnerTests.xctest'),
    )..createSync(recursive: true);
    expect(findRunnerTestsXctest(release)?.path, nested.path);
  });

  test('RemoteHostReportBuilder writes local-style HTML + embeds FTL video',
      () async {
    final collect = Directory.systemTemp.createTempSync('remote_report_');
    final appDir = Directory.systemTemp.createTempSync('remote_app_');
    addTearDown(() {
      collect.deleteSync(recursive: true);
      appDir.deleteSync(recursive: true);
    });

    final deviceTree = Directory(
      p.join(
        collect.path,
        'matrix',
        'MediumPhone.arm-36-en-portrait',
        'devices',
        'sdcard',
        'Download',
        'ensemble_test_remote',
      ),
    )..createSync(recursive: true);
    File(p.join(deviceTree.path, 'screenshots', 'hello_frames.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"frames":[]}');
    File(
      p.join(
        deviceTree.path,
        'report',
        'screenshots',
        'shot_1.png',
      ),
    )
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3, 4]);
    File(p.join(deviceTree.path, 'logs', 'hello_app_console.log'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('ok\n');

    final envelope = RemoteRunEnvelope(
      runId: 'run-report',
      complete: true,
      results: EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 'hello (tests/hello.test.yaml)',
            durationMs: 42,
            logs: const [
              'screenshots: build/ensemble_test_runner/screenshots/hello_frames.json',
              'appLogs: build/ensemble_test_runner/logs/hello_app_console.log',
            ],
          ),
        ],
      ),
    );
    File(p.join(deviceTree.path, 'remote', 'envelope.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(json.encode(envelope.toJson()));
    File(
      p.join(
        collect.path,
        'matrix',
        'MediumPhone.arm-36-en-portrait',
        'video.mp4',
      ),
    ).writeAsBytesSync(List<int>.filled(32, 9));

    final hostRoot = p.join(appDir.path, 'build', 'ensemble_test_runner');
    final builder = RemoteHostReportBuilder();
    await builder.materializeDeviceArtifactsIntoHost(
      collectDirectory: collect,
      hostArtifactRoot: hostRoot,
    );
    expect(
      File(p.join(hostRoot, 'screenshots', 'hello_frames.json')).existsSync(),
      isTrue,
    );

    final device = RemoteReportReconciler.reconcile(
      deviceKey: 'primary',
      nativeOutcome: 'SUCCESS',
      envelope: envelope,
      artifactDirectory: Directory(hostRoot),
    );
    final htmlPath = await builder.writeReports(
      appDir: appDir.path,
      hostArtifactRoot: hostRoot,
      collectDirectory: collect,
      devices: [device],
    );
    expect(htmlPath, isNotNull);
    expect(File(p.join(hostRoot, 'report', 'index.html')).existsSync(), isTrue);
    expect(
      File(p.join(hostRoot, 'report', 'results.json.gz')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(collect.path, 'report', 'index.html')).existsSync(),
      isTrue,
    );
    final videoName = Directory(p.join(hostRoot, 'report'))
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((n) => n.startsWith('video') && n.endsWith('.mp4'));
    expect(videoName, isNotEmpty);
    expect(
      File(p.join(collect.path, 'report', videoName.first)).existsSync(),
      isTrue,
    );
    final shell = File(p.join(collect.path, 'report', 'index.html'))
        .readAsStringSync();
    expect(shell, contains('ftl-video'));
  });
}
