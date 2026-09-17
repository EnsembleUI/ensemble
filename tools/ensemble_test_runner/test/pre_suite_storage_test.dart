import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    EnsembleTestHarness.ensureTestPlugins();
    EnsembleTestHarness.resetPreSuiteStorageSnapshotForTest();
    final storage = StorageManager();
    await storage.init();
    await EnsembleTestHarness.wipeAllPersistentStorage();
  });

  tearDown(() {
    EnsembleTestHarness.resetPreSuiteStorageSnapshotForTest();
  });

  test('independent clear restores pre-suite keys and drops test-written keys',
      () async {
    final storage = StorageManager();
    await storage.write('production_pref', 'keep-me');
    await storage.writeSecurely(key: 'production_secret', value: 'keep-secret');

    await EnsembleTestHarness.ensurePreSuiteStorageSnapshot();

    await storage.write('session_value', 'from-previous-test');
    await storage.writeSecurely(key: 'test_only', value: 'drop-me');
    await storage.write('production_pref', 'mutated');

    await EnsembleTestHarness.restorePreSuiteStorageForTest();

    expect(storage.read('production_pref'), 'keep-me');
    expect(storage.read('session_value'), isNull);
    expect(await storage.readSecurely('production_secret'), 'keep-secret');
    expect(await storage.readSecurely('test_only'), isNull);
  });

  test('suite-end restore reapplies the pre-suite baseline', () async {
    final storage = StorageManager();
    await storage.write('production_pref', 'keep-me');
    await EnsembleTestHarness.ensurePreSuiteStorageSnapshot();
    await storage.write('production_pref', 'mutated');
    await storage.write('leftover', 'drop');

    await EnsembleTestHarness.restorePreSuiteStorageAtSuiteEnd();

    expect(storage.read('production_pref'), 'keep-me');
    expect(storage.read('leftover'), isNull);
  });

  test('suite-end restore clears the baseline so a second call is a no-op',
      () async {
    final storage = StorageManager();
    await storage.write('production_pref', 'keep-me');
    await EnsembleTestHarness.ensurePreSuiteStorageSnapshot();
    await storage.write('production_pref', 'mutated');

    await EnsembleTestHarness.restorePreSuiteStorageAtSuiteEnd();
    expect(storage.read('production_pref'), 'keep-me');

    await storage.write('production_pref', 'mutated-again');
    // Baseline already consumed — second call must not rewrite storage.
    await EnsembleTestHarness.restorePreSuiteStorageAtSuiteEnd();
    expect(storage.read('production_pref'), 'mutated-again');
  });

  test('restore phases name clear failures', () async {
    await expectLater(
      () => AppSessionSnapshot.runRestorePhases(
        clear: () async {
          throw StateError('simulated clear failure');
        },
        rewrite: () async {},
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('clear phase'),
        ),
      ),
    );
  });

  test('restore phases name rewrite failures', () async {
    await expectLater(
      () => AppSessionSnapshot.runRestorePhases(
        clear: () async {},
        rewrite: () async {
          throw StateError('simulated write failure');
        },
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('rewrite phase'),
        ),
      ),
    );
  });

  test('physical device storage gate rejects without acknowledgment', () {
    expect(
      () => EnsembleTestHarness.assertPhysicalDeviceStorageAcknowledged(
        deviceIsPhysical: true,
        allowMutation: false,
        resetStorage: false,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('--allow-device-storage-mutation'),
        ),
      ),
    );
  });

  test('physical device storage gate accepts acknowledgment flags', () {
    expect(
      () => EnsembleTestHarness.assertPhysicalDeviceStorageAcknowledged(
        deviceIsPhysical: true,
        allowMutation: true,
        resetStorage: false,
      ),
      returnsNormally,
    );
    expect(
      () => EnsembleTestHarness.assertPhysicalDeviceStorageAcknowledged(
        deviceIsPhysical: true,
        allowMutation: false,
        resetStorage: true,
      ),
      returnsNormally,
    );
    expect(
      () => EnsembleTestHarness.assertPhysicalDeviceStorageAcknowledged(
        deviceIsPhysical: false,
        allowMutation: false,
        resetStorage: false,
      ),
      returnsNormally,
    );
  });
}
