import 'dart:io';

import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('atomically replaces a file and removes its temporary file', () {
    final directory = Directory.systemTemp.createTempSync('atomic-file-test-');
    addTearDown(() => directory.deleteSync(recursive: true));

    final target = File('${directory.path}/results.json.gz');
    AtomicFile.writeStringSync(target, 'first');
    AtomicFile.writeStringSync(target, 'second');

    expect(target.readAsStringSync(), 'second');
    expect(
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('.tmp-')),
      isEmpty,
    );
  });

  test('recovers an interrupted stale write without touching the target', () {
    final directory =
        Directory.systemTemp.createTempSync('atomic-file-recovery-');
    addTearDown(() => directory.deleteSync(recursive: true));

    final target = File('${directory.path}/results.json.gz');
    AtomicFile.writeStringSync(target, 'complete-before-interruption');
    final stale = File('${target.path}.tmp-$pid-interrupted')
      ..writeAsStringSync('partial-payload');
    final old = DateTime(2020, 1, 1);
    stale.setLastModifiedSync(old);

    expect(
      AtomicFile.recoverStaleTempsSync(
        target,
        olderThan: const Duration(minutes: 1),
        now: old.add(const Duration(hours: 1)),
      ),
      1,
    );
    expect(target.readAsStringSync(), 'complete-before-interruption');
    expect(stale.existsSync(), isFalse);
  });

  test('keeps a recent temporary write for its owner', () {
    final directory = Directory.systemTemp.createTempSync('atomic-file-live-');
    addTearDown(() => directory.deleteSync(recursive: true));

    final target = File('${directory.path}/results.json.gz');
    final live = File('${target.path}.tmp-$pid-live')
      ..writeAsStringSync('still-being-written');
    final now = DateTime.now();

    expect(
      AtomicFile.recoverStaleTempsSync(
        target,
        olderThan: const Duration(hours: 1),
        now: now,
      ),
      0,
    );
    expect(live.existsSync(), isTrue);
  });

  test('recovers the newest valid orphan when the target is missing', () {
    final directory =
        Directory.systemTemp.createTempSync('atomic-file-orphan-');
    addTearDown(() => directory.deleteSync(recursive: true));

    final target = File('${directory.path}/results.json');
    final old = File('${target.path}.tmp-$pid-old')..writeAsStringSync('old');
    final newest = File('${target.path}.tmp-$pid-new')
      ..writeAsStringSync('complete');
    final timestamp = DateTime(2020, 1, 1);
    old.setLastModifiedSync(timestamp);
    newest.setLastModifiedSync(timestamp.add(const Duration(minutes: 1)));

    expect(
      AtomicFile.recoverOrphanSync(
        target,
        now: timestamp.add(const Duration(hours: 1)),
        olderThan: const Duration(minutes: 1),
        isValid: (bytes) => String.fromCharCodes(bytes) == 'complete',
      ),
      isTrue,
    );
    expect(target.readAsStringSync(), 'complete');
    expect(newest.existsSync(), isFalse);
    expect(old.existsSync(), isTrue);
  });

  test('does not replace an existing target during orphan recovery', () {
    final directory = Directory.systemTemp.createTempSync('atomic-file-safe-');
    addTearDown(() => directory.deleteSync(recursive: true));

    final target = File('${directory.path}/results.json')
      ..writeAsStringSync('current');
    final orphan = File('${target.path}.tmp-$pid-orphan')
      ..writeAsStringSync('stale');

    expect(
      AtomicFile.recoverOrphanSync(
        target,
        isValid: (bytes) => bytes.isNotEmpty,
      ),
      isFalse,
    );
    expect(target.readAsStringSync(), 'current');
    expect(orphan.existsSync(), isTrue);
  });
}
