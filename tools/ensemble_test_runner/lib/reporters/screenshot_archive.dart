import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:path/path.dart' as p;

/// Packs report screenshots into a stored ZIP and removes loose files.
/// Images are already compressed, so this writer streams them without another
/// compression pass or whole-archive buffering.
class ScreenshotArchive {
  static const fileName = 'screenshots.zip';
  static const _zip32Limit = 0xffffffff;
  static const _utf8AndDescriptorFlags = 0x0808;
  static final _crcTable = List<int>.generate(256, (index) {
    var value = index;
    for (var bit = 0; bit < 8; bit++) {
      value = value.isOdd ? (value >>> 1) ^ 0xedb88320 : value >>> 1;
    }
    return value;
  }, growable: false);

  static bool create(String artifactRoot) => RunnerBenchmark.sync(
      'artifact', 'createScreenshotArchive', () => _create(artifactRoot));

  static bool _create(String artifactRoot) {
    final report = Directory(p.join(artifactRoot, 'report'));
    final images = Directory(p.join(report.path, 'screenshots'));
    if (!images.existsSync()) {
      final stale = File(p.join(report.path, fileName));
      if (stale.existsSync()) stale.deleteSync();
      return false;
    }

    final files = images.listSync(recursive: true).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      images.deleteSync(recursive: true);
      final stale = File(p.join(report.path, fileName));
      if (stale.existsSync()) stale.deleteSync();
      return false;
    }
    if (files.any((file) => !file.path.toLowerCase().endsWith('.webp'))) {
      throw StateError('Screenshot archive only accepts WebP images.');
    }

    final target = File(p.join(report.path, fileName));
    AtomicFile.recoverStaleTempsSync(target);
    final temporary = File(
      '${target.path}.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
    RandomAccessFile? output;
    var completed = false;
    var totalBytes = 0;
    try {
      output = temporary.openSync(mode: FileMode.write);
      final entries = <_ZipEntry>[];
      for (final file in files) {
        final name = p
            .join('screenshots', p.relative(file.path, from: images.path))
            .replaceAll('\\', '/');
        final entry = _writeEntry(output, file, name);
        entries.add(entry);
        totalBytes += entry.size;
      }
      _writeCentralDirectory(output, entries);
      _checkZip32(output.positionSync(), 'archive size');
      output.flushSync();
      output.closeSync();
      output = null;
      temporary.renameSync(target.path);
      completed = true;
      RunnerBenchmark.count('screenshotFiles', files.length);
      RunnerBenchmark.count('screenshotBytes', totalBytes);
    } finally {
      if (output != null) {
        try {
          output.closeSync();
        } on Object {
          // Preserve the original archive-write failure.
        }
      }
      if (!completed && temporary.existsSync()) temporary.deleteSync();
    }
    images.deleteSync(recursive: true);
    return true;
  }

  static _ZipEntry _writeEntry(
    RandomAccessFile output,
    File file,
    String name,
  ) {
    final encodedName = utf8.encode(name);
    final stat = file.statSync();
    if (encodedName.length > 0xffff ||
        stat.size < 0 ||
        stat.size > _zip32Limit) {
      throw StateError('Screenshot cannot be represented in a ZIP32 archive.');
    }
    final modified = file.lastModifiedSync();
    final time = _dosTime(modified);
    final date = _dosDate(modified);
    final offset = output.positionSync();
    _checkZip32(offset, 'entry offset');

    // A data descriptor lets the writer calculate CRC while streaming bytes.
    _writeHeader(output, 30, (header) {
      header.setUint32(0, 0x04034b50, Endian.little);
      header.setUint16(4, 20, Endian.little);
      header.setUint16(6, _utf8AndDescriptorFlags, Endian.little);
      header.setUint16(8, 0, Endian.little);
      header.setUint16(10, time, Endian.little);
      header.setUint16(12, date, Endian.little);
      header.setUint16(26, encodedName.length, Endian.little);
    });
    output.writeFromSync(encodedName);

    var crc = 0xffffffff;
    var size = 0;
    final input = file.openSync(mode: FileMode.read);
    try {
      while (true) {
        final chunk = input.readSync(64 * 1024);
        if (chunk.isEmpty) break;
        size += chunk.length;
        _checkZip32(size, 'entry size');
        crc = _updateCrc32(crc, chunk);
        output.writeFromSync(chunk);
      }
    } finally {
      input.closeSync();
    }
    crc = (crc ^ 0xffffffff) & _zip32Limit;
    _writeU32(output, 0x08074b50);
    _writeU32(output, crc);
    _writeU32(output, size);
    _writeU32(output, size);
    return _ZipEntry(
      name: encodedName,
      crc: crc,
      size: size,
      offset: offset,
      time: time,
      date: date,
      mode: stat.mode,
    );
  }

  static void _writeCentralDirectory(
    RandomAccessFile output,
    List<_ZipEntry> entries,
  ) {
    if (entries.length > 0xffff) {
      throw StateError('Screenshot count exceeds the ZIP32 limit.');
    }
    final start = output.positionSync();
    for (final entry in entries) {
      _writeHeader(output, 46, (header) {
        header.setUint32(0, 0x02014b50, Endian.little);
        header.setUint16(4, 0x0314, Endian.little);
        header.setUint16(6, 20, Endian.little);
        header.setUint16(8, _utf8AndDescriptorFlags, Endian.little);
        header.setUint16(10, 0, Endian.little);
        header.setUint16(12, entry.time, Endian.little);
        header.setUint16(14, entry.date, Endian.little);
        header.setUint32(16, entry.crc, Endian.little);
        header.setUint32(20, entry.size, Endian.little);
        header.setUint32(24, entry.size, Endian.little);
        header.setUint16(28, entry.name.length, Endian.little);
        header.setUint32(38, (entry.mode & 0xffff) << 16, Endian.little);
        header.setUint32(42, entry.offset, Endian.little);
      });
      output.writeFromSync(entry.name);
    }
    final size = output.positionSync() - start;
    _checkZip32(start, 'central directory offset');
    _checkZip32(size, 'central directory size');
    _writeHeader(output, 22, (header) {
      header.setUint32(0, 0x06054b50, Endian.little);
      header.setUint16(8, entries.length, Endian.little);
      header.setUint16(10, entries.length, Endian.little);
      header.setUint32(12, size, Endian.little);
      header.setUint32(16, start, Endian.little);
    });
  }

  static int _updateCrc32(int crc, List<int> bytes) {
    var index = 0;
    var remaining = bytes.length;
    while (remaining >= 8) {
      crc = _crcTable[(crc ^ bytes[index++]) & 255] ^ (crc >>> 8);
      crc = _crcTable[(crc ^ bytes[index++]) & 255] ^ (crc >>> 8);
      crc = _crcTable[(crc ^ bytes[index++]) & 255] ^ (crc >>> 8);
      crc = _crcTable[(crc ^ bytes[index++]) & 255] ^ (crc >>> 8);
      crc = _crcTable[(crc ^ bytes[index++]) & 255] ^ (crc >>> 8);
      crc = _crcTable[(crc ^ bytes[index++]) & 255] ^ (crc >>> 8);
      crc = _crcTable[(crc ^ bytes[index++]) & 255] ^ (crc >>> 8);
      crc = _crcTable[(crc ^ bytes[index++]) & 255] ^ (crc >>> 8);
      remaining -= 8;
    }
    while (remaining-- > 0) {
      crc = _crcTable[(crc ^ bytes[index++]) & 255] ^ (crc >>> 8);
    }
    return crc;
  }

  static void _writeHeader(
    RandomAccessFile output,
    int size,
    void Function(ByteData header) encode,
  ) {
    final header = ByteData(size);
    encode(header);
    output.writeFromSync(
      Uint8List.view(header.buffer, header.offsetInBytes, header.lengthInBytes),
    );
  }

  static void _writeU32(RandomAccessFile output, int value) => _writeHeader(
      output, 4, (header) => header.setUint32(0, value, Endian.little));

  static void _checkZip32(int value, String field) {
    if (value < 0 || value > _zip32Limit) {
      throw StateError('ZIP32 $field limit exceeded.');
    }
  }

  static int _dosTime(DateTime value) =>
      (value.hour << 11) | (value.minute << 5) | (value.second ~/ 2);

  static int _dosDate(DateTime value) {
    final year = value.year.clamp(1980, 2107);
    return ((year - 1980) << 9) | (value.month << 5) | value.day;
  }

  /// Clears pending images but retains the last completed report archive.
  static void clearPendingImages(String artifactRoot) {
    final images = Directory(p.join(artifactRoot, 'report', 'screenshots'));
    if (images.existsSync()) images.deleteSync(recursive: true);
  }
}

final class _ZipEntry {
  const _ZipEntry({
    required this.name,
    required this.crc,
    required this.size,
    required this.offset,
    required this.time,
    required this.date,
    required this.mode,
  });

  final List<int> name;
  final int crc;
  final int size;
  final int offset;
  final int time;
  final int date;
  final int mode;
}
