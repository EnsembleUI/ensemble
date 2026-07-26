import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores public storage and keychain from an isolated copy', () async {
    EnsembleTestHarness.ensureTestPlugins();
    final storage = StorageManager();
    await storage.init();
    await storage.clearPublicStorage();
    for (final key in (await storage.getAllFromKeychain()).keys) {
      await storage.removeSecurely(key);
    }

    await storage.write('apiUrl', 'http://stub');
    await storage.write('nested', {
      'values': [1, 2]
    });
    await storage.writeSecurely(key: 'sahCookie', value: 'original');
    final snapshot = await AppSessionSnapshot.capture();

    await storage.write('apiUrl', 'http://changed');
    final nested = storage.read<Map>('nested')!;
    (nested['values'] as List).add(3);
    await storage.write('extra', true);
    await storage.writeSecurely(key: 'sahCookie', value: 'changed');
    await storage.writeSecurely(key: 'extraSecret', value: 'remove-me');

    await snapshot.restore();

    expect(storage.read('apiUrl'), 'http://stub');
    expect(storage.read('nested'), {
      'values': [1, 2]
    });
    expect(storage.read('extra'), isNull);
    expect(await storage.readSecurely('sahCookie'), 'original');
    expect(await storage.readSecurely('extraSecret'), isNull);
  });
}
