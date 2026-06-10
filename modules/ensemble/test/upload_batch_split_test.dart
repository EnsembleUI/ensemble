import 'package:ensemble/util/upload_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitUploadFileBatches', () {
    test('returns a single batch when batchSize is null', () {
      expect(splitUploadFileBatches([1, 2, 3], null), [
        [1, 2, 3],
      ]);
    });

    test('splits files into fixed-size batches', () {
      expect(splitUploadFileBatches([1, 2, 3, 4, 5], 2), [
        [1, 2],
        [3, 4],
        [5],
      ]);
    });

    test('returns one batch when batchSize covers all files', () {
      expect(splitUploadFileBatches(['a', 'b'], 10), [
        ['a', 'b'],
      ]);
    });

    test('returns empty outer list when batchSize set but input is empty', () {
      expect(splitUploadFileBatches<int>([], 2), isEmpty);
    });

    test('returns one empty batch when batchSize is null and input is empty', () {
      expect(splitUploadFileBatches<int>([], null), [
        <int>[],
      ]);
    });
  });

  group('backgroundUploadWorkUniqueName', () {
    test('uses task id so each batch gets a distinct Workmanager name', () {
      expect(backgroundUploadWorkUniqueName('abc123'), 'abc123');
      expect(
        backgroundUploadWorkUniqueName('batch-a'),
        isNot(backgroundUploadWorkUniqueName('batch-b')),
      );
      expect(backgroundUploadWorkUniqueName('task-1'), isNot('uploadTask'));
    });

    test('batch count matches registrations needed for multi-batch uploads', () {
      final batches = splitUploadFileBatches([1, 2, 3, 4, 5], 2);
      expect(batches.length, 3);
      final uniqueNames =
          batches.map((_) => backgroundUploadWorkUniqueName('id-${_.hashCode}')).toSet();
      expect(uniqueNames.length, batches.length);
    });
  });
}
