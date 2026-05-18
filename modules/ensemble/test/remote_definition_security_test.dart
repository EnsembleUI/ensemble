import 'package:ensemble/framework/definition_providers/screen_selector_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSafeRemoteScreenSelector', () {
    test('allows typical screen names', () {
      expect(isSafeRemoteScreenSelector('Hello Home'), isTrue);
      expect(isSafeRemoteScreenSelector('screen_1'), isTrue);
      expect(isSafeRemoteScreenSelector('a-b'), isTrue);
    });

    test('rejects path traversal and separators', () {
      expect(isSafeRemoteScreenSelector('../admin'), isFalse);
      expect(isSafeRemoteScreenSelector('foo/bar'), isFalse);
      expect(isSafeRemoteScreenSelector(r'foo\bar'), isFalse);
      expect(isSafeRemoteScreenSelector('foo%2fbar'), isFalse);
    });

    test('rejects empty and control characters', () {
      expect(isSafeRemoteScreenSelector(''), isFalse);
      expect(isSafeRemoteScreenSelector('bad\u0000name'), isFalse);
    });

    test('rejects percent-encoding used to smuggle separators', () {
      expect(isSafeRemoteScreenSelector(r'home%2f..%2fsecrets'), isFalse);
      expect(isSafeRemoteScreenSelector(r'..%2fetc'), isFalse);
    });

    test('enforces maximum selector length', () {
      final ok = List.filled(256, 'a').join();
      final tooLong = List.filled(257, 'a').join();
      expect(isSafeRemoteScreenSelector(ok), isTrue);
      expect(isSafeRemoteScreenSelector(tooLong), isFalse);
    });
  });
}
