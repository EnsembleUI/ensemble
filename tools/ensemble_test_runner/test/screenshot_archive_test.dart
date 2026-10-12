import 'dart:io';

import 'package:archive/archive.dart';
import 'package:ensemble_test_runner/reporters/screenshot_archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('packs screenshot files into one ZIP and removes loose copies', () {
    final root = Directory.systemTemp.createTempSync('screenshot_archive_');
    addTearDown(() => root.deleteSync(recursive: true));
    final images = Directory(p.join(root.path, 'report', 'screenshots'))
      ..createSync(recursive: true);
    final expected = <int>[0, 1, 2, 3, 255];
    File(p.join(images.path, 'frame.webp')).writeAsBytesSync(expected);

    expect(ScreenshotArchive.create(root.path), isTrue);

    final zip = File(p.join(root.path, 'report', 'screenshots.zip'));
    expect(zip.existsSync(), isTrue);
    expect(images.existsSync(), isFalse);
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    expect(archive.files, hasLength(1));
    expect(archive.files.single.name, 'screenshots/frame.webp');
    expect(archive.files.single.content as List<int>, expected);
  });

  test('archives a multi-megabyte screenshot set byte-for-byte', () {
    final root = Directory.systemTemp.createTempSync('screenshot_archive_');
    addTearDown(() => root.deleteSync(recursive: true));
    final images = Directory(p.join(root.path, 'report', 'screenshots'))
      ..createSync(recursive: true);
    final payload = List<int>.generate(256 * 1024, (index) => index & 0xff);
    for (var index = 0; index < 16; index++) {
      File(p.join(images.path, 'frame_$index.webp')).writeAsBytesSync(payload);
    }

    expect(ScreenshotArchive.create(root.path), isTrue);

    final zip = File(p.join(root.path, 'report', ScreenshotArchive.fileName));
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    expect(archive.files, hasLength(16));
    expect(
      archive.files.fold<int>(0, (size, file) => size + file.size),
      16 * payload.length,
    );
    expect(archive.files.first.content as List<int>, payload);
    // Stored image bytes should not go through a second compression pass.
    expect(zip.lengthSync(), greaterThanOrEqualTo(16 * payload.length));
  });

  test('closes each screenshot input while building large archives', () {
    final root = Directory.systemTemp.createTempSync('screenshot_archive_');
    addTearDown(() => root.deleteSync(recursive: true));
    final images = Directory(p.join(root.path, 'report', 'screenshots'))
      ..createSync(recursive: true);
    for (var index = 0; index < 300; index++) {
      File(p.join(images.path, 'frame_$index.webp'))
          .writeAsBytesSync([index & 0xff]);
    }

    expect(ScreenshotArchive.create(root.path), isTrue);

    final zip = File(p.join(root.path, 'report', ScreenshotArchive.fileName));
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    expect(archive.files, hasLength(300));
  });

  test('clears working screenshots but preserves the last report archive', () {
    final root = Directory.systemTemp.createTempSync('screenshot_archive_');
    addTearDown(() => root.deleteSync(recursive: true));
    final report = Directory(p.join(root.path, 'report'))..createSync();
    final zip = File(p.join(report.path, ScreenshotArchive.fileName))
      ..writeAsBytesSync([1]);

    File(p.join(report.path, 'screenshots', 'pending.webp'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([2]);

    ScreenshotArchive.clearPendingImages(root.path);

    expect(zip.existsSync(), isTrue);
    expect(Directory(p.join(report.path, 'screenshots')).existsSync(), isFalse);
  });

  test('rejects non-WebP screenshot files', () {
    final root = Directory.systemTemp.createTempSync('screenshot_archive_');
    addTearDown(() => root.deleteSync(recursive: true));
    final images = Directory(p.join(root.path, 'report', 'screenshots'))
      ..createSync(recursive: true);
    File(p.join(images.path, 'unexpected.jpg')).writeAsBytesSync([1]);

    expect(() => ScreenshotArchive.create(root.path), throwsStateError);
  });

  test('archive write failure keeps the old report and pending images', () {
    final root = Directory.systemTemp.createTempSync('screenshot_archive_');
    addTearDown(() => root.deleteSync(recursive: true));
    final report = Directory(p.join(root.path, 'report'))..createSync();
    final images = Directory(p.join(report.path, 'screenshots'))..createSync();
    File(p.join(images.path, 'frame.webp')).writeAsBytesSync([1, 2, 3]);
    final target = Directory(p.join(report.path, ScreenshotArchive.fileName))
      ..createSync();
    final previousReport = File(p.join(target.path, 'preserve.txt'))
      ..writeAsStringSync('previous report');

    expect(
      () => ScreenshotArchive.create(root.path),
      throwsA(isA<FileSystemException>()),
    );

    expect(previousReport.readAsStringSync(), 'previous report');
    expect(File(p.join(images.path, 'frame.webp')).existsSync(), isTrue);
    expect(
      report.listSync().whereType<File>().where(
            (file) => p.basename(file.path).startsWith('screenshots.zip.tmp-'),
          ),
      isEmpty,
    );
  });
}
