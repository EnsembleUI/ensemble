import 'package:ensemble_test_runner/actions/test_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveEnsembleThemeName', () {
    test('maps light/dark aliases', () {
      expect(resolveEnsembleThemeName('light'), 'Light');
      expect(resolveEnsembleThemeName('DARK'), 'Dark');
      expect(resolveEnsembleThemeName(' Light '), 'Light');
    });

    test('passes through exact names when no registry', () {
      expect(resolveEnsembleThemeName('Custom'), 'Custom');
    });

    test('matches registered names case-insensitively', () {
      expect(
        resolveEnsembleThemeName(
          'dark',
          registeredNames: const ['Light', 'Dark'],
        ),
        'Dark',
      );
      expect(
        resolveEnsembleThemeName(
          'LIGHT',
          registeredNames: const ['Light', 'Dark'],
        ),
        'Light',
      );
    });

    test('returns null for unknown registered theme', () {
      expect(
        resolveEnsembleThemeName(
          'Sepia',
          registeredNames: const ['Light', 'Dark'],
        ),
        isNull,
      );
    });

    test('returns null for empty', () {
      expect(resolveEnsembleThemeName(null), isNull);
      expect(resolveEnsembleThemeName('  '), isNull);
    });
  });
}
