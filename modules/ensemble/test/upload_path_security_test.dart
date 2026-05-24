import 'package:ensemble/framework/data_context.dart' as edc;
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

  group('UploadUtils.uploadFiles path guard', () {
    test('throws before sending when a file path contains parent segments', () async {
      final badFile =
          edc.File(null, null, null, '/var/tmp/../../etc/passwd', null);
      await expectLater(
        UploadUtils.uploadFiles(
          taskId: 'upload_test_task',
          method: 'POST',
          url: 'https://example.invalid/upload',
          headers: const {},
          fields: const {},
          files: [badFile],
          fieldName: 'file',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
