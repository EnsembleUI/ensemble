import 'dart:async';

import 'package:ensemble/framework/data_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ensembleStorageClearDispatchKeys', () {
    test('excludes enc_ prefix and preserves order of remaining keys', () {
      expect(
        ensembleStorageClearDispatchKeys(
            ['session', 'enc_token', 'theme', 'enc_other']),
        ['session', 'theme'],
      );
    });

    test('treats only the enc_ prefix as encrypted storage namespace', () {
      expect(
        ensembleStorageClearDispatchKeys(['enc_legacy', 'enc2', 'normal']),
        ['enc2', 'normal'],
      );
    });

    test('empty input yields empty list', () {
      expect(ensembleStorageClearDispatchKeys([]), isEmpty);
    });
  });

  group('runStorageClearDispatches', () {
    test('dispatches only after clearFuture completes', () async {
      final clearCompleter = Completer<void>();
      final dispatched = <String>[];
      var clearCompleted = false;

      final pending = runStorageClearDispatches(
        clearFuture: clearCompleter.future,
        keys: ['session', 'theme'],
        dispatch: (key) {
          expect(clearCompleted, isTrue);
          dispatched.add(key);
        },
      );

      expect(dispatched, isEmpty);

      clearCompleter.complete();
      clearCompleted = true;
      await pending;

      expect(dispatched, ['session', 'theme']);
    });

    test('still dispatches when clearFuture completes with an error', () async {
      final dispatched = <String>[];

      await runStorageClearDispatches(
        clearFuture: Future<void>.error(StateError('clear failed')),
        keys: ['session'],
        dispatch: dispatched.add,
      ).catchError((_) {});

      expect(dispatched, ['session']);
    });
  });
}
