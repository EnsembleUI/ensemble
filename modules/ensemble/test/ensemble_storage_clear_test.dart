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

  group('scheduleStorageClearDispatches', () {
    test('dispatches only after clear future completes', () async {
      final completer = Completer<void>();
      final dispatched = <String>[];

      scheduleStorageClearDispatches(
        completer.future,
        ['session', 'theme'],
        dispatched.add,
      );

      expect(dispatched, isEmpty);

      completer.complete();
      await Future<void>.delayed(Duration.zero);

      expect(dispatched, ['session', 'theme']);
    });

  });
}
