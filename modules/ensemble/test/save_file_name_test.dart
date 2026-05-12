import 'package:ensemble/action/saveFile/save_mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizedSaveFileName', () {
    test('returns basename and strips traversal segments', () {
      expect(sanitizedSaveFileName('report.pdf'), 'report.pdf');
      expect(sanitizedSaveFileName('subdir/report.pdf'), 'report.pdf');
      expect(sanitizedSaveFileName(r'..\Downloads\evil.txt'), 'evil.txt');
    });

    test('throws on invalid names', () {
      expect(() => sanitizedSaveFileName(''), throwsFormatException);
      expect(() => sanitizedSaveFileName('..'), throwsFormatException);
      expect(() => sanitizedSaveFileName('foo..bar'), throwsFormatException);
    });
  });
}
