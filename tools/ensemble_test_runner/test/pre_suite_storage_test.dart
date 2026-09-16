import 'package:ensemble/framework/storage_manager.dart';
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
}
