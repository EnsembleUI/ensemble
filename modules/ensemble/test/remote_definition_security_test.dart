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
      expect(isSafeRemoteScreenSelector('foo%00bar'), isFalse);
    });

    test('rejects overly long screen names', () {
      expect(isSafeRemoteScreenSelector('a' * 256), isTrue);
      expect(isSafeRemoteScreenSelector('a' * 257), isFalse);
    });

    test('rejects empty and control characters', () {
      expect(isSafeRemoteScreenSelector(''), isFalse);
      expect(isSafeRemoteScreenSelector('bad\u0000name'), isFalse);
    });
  });
}
