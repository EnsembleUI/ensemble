import 'package:ensemble/util/upload_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uploadPathContainsParentSegment', () {
    test('allows normal paths', () {
      expect(uploadPathContainsParentSegment(null), false);
      expect(uploadPathContainsParentSegment(''), false);
      expect(uploadPathContainsParentSegment('/tmp/photo.jpg'), false);
      expect(uploadPathContainsParentSegment('C:\\Users\\me\\file.txt'), false);
      expect(uploadPathContainsParentSegment('cache/image.png'), false);
    });

    test('rejects parent directory segments', () {
      expect(uploadPathContainsParentSegment('/a/b/../c'), true);
      expect(uploadPathContainsParentSegment(r'C:\a\..\b'), true);
      expect(uploadPathContainsParentSegment('..'), true);
      expect(uploadPathContainsParentSegment('../etc/passwd'), true);
    });
  });
}
