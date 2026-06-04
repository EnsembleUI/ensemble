import 'package:ensemble/action/upload_files_action.dart';
import 'package:ensemble/framework/data_context.dart' as ensemble;
import 'package:flutter_test/flutter_test.dart';

ensemble.File _file(String id) => ensemble.File.fromString('/tmp/$id');

void main() {
  group('splitUploadFileBatches', () {
    test('returns single batch when file count is within batchSize', () {
      final files = [_file('a'), _file('b')];
      expect(splitUploadFileBatches(files, 3), [files]);
    });

    test('splits into multiple batches so every file is enqueued', () {
      final files = List.generate(5, (i) => _file('$i'));
      expect(
        splitUploadFileBatches(files, 2),
        [
          files.sublist(0, 2),
          files.sublist(2, 4),
          files.sublist(4, 5),
        ],
      );
    });

    test('uses exact batchSize when length is divisible', () {
      final files = List.generate(4, (i) => _file('$i'));
      expect(
        splitUploadFileBatches(files, 2),
        [files.sublist(0, 2), files.sublist(2, 4)],
      );
    });

    test('rejects non-positive batchSize', () {
      expect(
        () => splitUploadFileBatches([_file('a')], 0),
        throwsArgumentError,
      );
    });
  });
}
