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
}
