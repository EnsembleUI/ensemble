import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mockito/mockito.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockBuildContext mockContext;

  setUp(() async {
    await GetStorage.init();
    await GetStorage().erase();
    final sm = StorageManager();
    if (!sm.initialized) {
      await sm.init();
    }
    mockContext = MockBuildContext();
  });

  tearDown(() async {
    await GetStorage().erase();
  });

  group('EnsembleStorage.clear', () {
    test('removes public keys and retains enc_ prefixed entries', () async {
      await StorageManager().write('session', 'keep-until-clear');
      await StorageManager().write('enc_token', 'secret');

      final storage = EnsembleStorage(mockContext);
      storage.clear();

      expect(StorageManager().read<String>('session'), isNull);
      expect(StorageManager().read<String>('enc_token'), 'secret');
    });

    test('exposes clear through invokable methods for script bindings', () async {
      await StorageManager().write('flag', true);

      final storage = EnsembleStorage(mockContext);
      final clearMethod = storage.methods()['clear'];
      expect(clearMethod, isNotNull);
      (clearMethod! as void Function([dynamic]))();

      expect(StorageManager().read('flag'), isNull);
    });

    test('clear with only enc_ keys leaves storage unchanged', () async {
      await StorageManager().write('enc_only', 'x');

      EnsembleStorage(mockContext).clear();

      expect(StorageManager().read<String>('enc_only'), 'x');
    });
  });
}

class MockBuildContext extends Mock implements BuildContext {}
