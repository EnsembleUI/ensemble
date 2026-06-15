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
}
