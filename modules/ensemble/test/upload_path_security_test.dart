import 'package:ensemble/framework/data_context.dart';
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

  group('UploadUtils.uploadFiles path validation', () {
    test('rejects file paths with parent segments before any network I/O',
        () async {
      await expectLater(
        UploadUtils.uploadFiles(
          taskId: 'upload-task',
          method: 'POST',
          url: 'http://127.0.0.1:1/should-not-be-called',
          headers: const {},
          fields: const {},
          files: [
            File(null, null, null, r'C:\tmp\..\..\etc\hosts', null),
          ],
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
