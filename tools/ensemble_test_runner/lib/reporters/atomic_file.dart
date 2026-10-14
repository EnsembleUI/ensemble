import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:convert';
import 'dart:io';

/// Replaces a file in one rename operation so readers never see a partial file.
class AtomicFile {
  static const _temporaryMarker = '.tmp-';

  /// Removes temporary files left by an interrupted write.
  ///
  /// A writer always flushes its temporary file before renaming it over the
  /// destination.  Therefore a temporary file is never a valid report and
  /// can be removed after it has been left behind for a bounded period.  The
  /// age guard avoids deleting a temporary file belonging to another writer
  /// that is still in progress.
  static int recoverStaleTempsSync(
    File target, {
    Duration olderThan = const Duration(hours: 1),
    DateTime? now,
  }) {
    final directory = target.parent;
    if (!directory.existsSync()) return 0;
    final prefix = '${target.path}$_temporaryMarker';
    final cutoff = (now ?? DateTime.now()).subtract(olderThan);
    var removed = 0;
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is! File || !entity.path.startsWith(prefix)) continue;
      try {
        if (entity.lastModifiedSync().isAfter(cutoff)) continue;
        entity.deleteSync();
        removed++;
      } on FileSystemException {
        // Recovery is best effort.  A concurrent writer or a read-only
        // filesystem must not prevent the new atomic write from proceeding.
      }
    }
    return removed;
  }

  /// Restores a complete interrupted write when [target] is missing.
  ///
  /// A process can terminate after flushing its temporary file and before the
  /// rename.  The previous target is intentionally never replaced here: this
  /// method only promotes a candidate when the target is absent.  Callers may
  /// provide [isValid] to reject a flushed but incomplete payload (for
  /// example, a report can validate its compressed JSON envelope).
  static bool recoverOrphanSync(
    File target, {
    bool Function(List<int> bytes)? isValid,
    Duration olderThan = const Duration(minutes: 1),
    DateTime? now,
  }) {
    if (target.existsSync()) return false;
    final directory = target.parent;
    if (!directory.existsSync()) return false;
    final prefix = '${target.path}$_temporaryMarker';
    final cutoff = (now ?? DateTime.now()).subtract(olderThan);
    final candidates = <File>[];
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is! File || !entity.path.startsWith(prefix)) continue;
      try {
        if (!entity.lastModifiedSync().isAfter(cutoff)) candidates.add(entity);
      } on FileSystemException {
        // A concurrent writer may disappear while the directory is scanned.
      }
    }
    candidates.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } on FileSystemException {
        return 0;
      }
    });
    for (final candidate in candidates) {
      try {
        final bytes = candidate.readAsBytesSync();
        if (bytes.isEmpty || (isValid != null && !isValid(bytes))) continue;
        candidate.renameSync(target.path);
        return true;
      } on FileSystemException {
        // Another writer may have won the recovery race.  Preserve the normal
        // missing-file behavior if no candidate can be promoted.
      } on FormatException {
        // The candidate is incomplete or corrupt; leave it for stale cleanup.
      }
    }
    return false;
  }

  static void writeBytesSync(File target, List<int> bytes) {
    return RunnerBenchmark.sync('artifact', 'writeBytesSync', () {
      target.parent.createSync(recursive: true);
      recoverOrphanSync(target);
      recoverStaleTempsSync(target);
      final temporary = File(
        '${target.path}$_temporaryMarker${pid}-${DateTime.now().microsecondsSinceEpoch}',
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
