import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:convert';
import 'dart:io';

/// Replaces a file in one rename operation so readers never see a partial file.
class AtomicFile {
  static void writeBytesSync(File target, List<int> bytes) {
    return RunnerBenchmark.sync('artifact', 'writeBytesSync', () {
      target.parent.createSync(recursive: true);
      final temporary = File(
        '${target.path}.tmp-${pid}-${DateTime.now().microsecondsSinceEpoch}',
      );
      try {
        temporary.writeAsBytesSync(bytes, flush: true);
        temporary.renameSync(target.path);
        RunnerBenchmark.count('bytesWritten', bytes.length);
        RunnerBenchmark.count('filesWritten', 1);
      } finally {
        if (temporary.existsSync()) temporary.deleteSync();
      }
    });
  }

  static void writeStringSync(
    File target,
    String contents, {
    Encoding encoding = utf8,
  }) {
    return RunnerBenchmark.sync('artifact', 'writeStringSync', () {
      writeBytesSync(target, encoding.encode(contents));
    });
  }
}
