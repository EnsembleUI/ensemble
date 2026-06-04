import 'package:ensemble/framework/data_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runEnsembleStorageClearDispatches', () {
    test('dispatches only after clear future completes', () async {
      final dispatched = <String>[];
      var storageCleared = false;

      final clearFuture = Future<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        storageCleared = true;
      });

      final done = runEnsembleStorageClearDispatches(
        clearFuture,
        ['session', 'theme'],
        dispatched.add,
      );

      expect(dispatched, isEmpty);
      await done;
      expect(storageCleared, isTrue);
      expect(dispatched, ['session', 'theme']);
    });

    test('still dispatches when clear future completes with error', () async {
      final dispatched = <String>[];

      final done = runEnsembleStorageClearDispatches(
        Future<void>.error(StateError('clear failed')),
        ['a'],
        dispatched.add,
      );

      await expectLater(done, throwsStateError);
      expect(dispatched, ['a']);
    });
  });
}
