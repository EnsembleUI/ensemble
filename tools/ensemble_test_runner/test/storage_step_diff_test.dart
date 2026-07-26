import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('diffStorage', () {
    test('detects added keys', () {
      final changes = diffStorage(
        {'a': 1},
        {'a': 1, 'b': 'new'},
      );
      expect(changes, hasLength(1));
      expect(changes.single.key, 'b');
      expect(changes.single.change, 'added');
      expect(changes.single.after, 'new');
      expect(changes.single.before, isNull);
    });

    test('detects modified keys', () {
      final changes = diffStorage(
        {
          'token': {'v': 1},
        },
        {
          'token': {'v': 2},
        },
      );
      expect(changes, hasLength(1));
      expect(changes.single.change, 'modified');
      expect(changes.single.before, {'v': 1});
      expect(changes.single.after, {'v': 2});
    });

    test('detects removed keys', () {
      final changes = diffStorage(
        {'gone': true, 'keep': 1},
        {'keep': 1},
      );
      expect(changes, hasLength(1));
      expect(changes.single.key, 'gone');
      expect(changes.single.change, 'removed');
      expect(changes.single.before, true);
    });

    test('returns empty when unchanged', () {
      expect(
        diffStorage(
          {
            'a': [1, 2],
          },
          {
            'a': [1, 2],
          },
        ),
        isEmpty,
      );
    });
  });
}
