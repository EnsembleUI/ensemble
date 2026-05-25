import 'package:ensemble/framework/data_context.dart' show File;
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

    test('treats only a full path segment ".." as traversal', () {
      expect(uploadPathContainsParentSegment('photo..jpg'), false);
      expect(uploadPathContainsParentSegment('.../x'), false);
      expect(uploadPathContainsParentSegment(r'a\..\b'), true);
    });

    test('normalises backslashes before splitting', () {
      expect(uploadPathContainsParentSegment(r'var\..\evil'), true);
    });
  });

  group('UploadUtils.uploadFiles path guard', () {
    test('throws before any network I/O when path contains ".."', () async {
      final files = <File>[
        File(null, null, null, '/tmp/../outside.jpg', null),
      ];

      await expectLater(
        UploadUtils.uploadFiles(
          taskId: 't1',
          method: 'POST',
          url: 'http://127.0.0.1:9/should-not-connect',
          headers: const {},
          fields: const {},
          files: files,
          fieldName: 'file',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('..'),
          ),
        ),
      );
    });
  });
}
