import 'package:ensemble/framework/data_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cancelNonCompletedUploadTasks', () {
    test('cancels pending and running tasks but leaves completed', () {
      final completed = UploadTask(id: 'done', status: UploadStatus.completed);
      final pending = UploadTask(id: 'wait');
      final running =
          UploadTask(id: 'run', status: UploadStatus.running);
      final failed = UploadTask(id: 'fail', status: UploadStatus.failed);

      cancelNonCompletedUploadTasks([completed, pending, running, failed]);

      expect(completed.status, UploadStatus.completed);
      expect(pending.status, UploadStatus.cancelled);
      expect(running.status, UploadStatus.cancelled);
      expect(failed.status, UploadStatus.cancelled);
    });

    test('continues past completed tasks instead of stopping early', () {
      final first = UploadTask(id: '1', status: UploadStatus.completed);
      final second = UploadTask(id: '2', status: UploadStatus.running);
      final third = UploadTask(id: '3');

      cancelNonCompletedUploadTasks([first, second, third]);

      expect(first.status, UploadStatus.completed);
      expect(second.status, UploadStatus.cancelled);
      expect(third.status, UploadStatus.cancelled);
    });
  });
}
