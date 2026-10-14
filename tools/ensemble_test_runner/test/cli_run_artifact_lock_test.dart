import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_run_artifact_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows one owner and blocks a second owner until release', () {
    final directory = Directory.systemTemp.createTempSync('ensemble-lock-');
    addTearDown(() => directory.deleteSync(recursive: true));

    final first = CliRunArtifactLock(directory.path);
    final second = CliRunArtifactLock(directory.path);

    expect(first.acquire(), isTrue);
    expect(second.acquire(), isFalse);

    first.release();
    expect(second.acquire(), isTrue);
    second.release();
  });

  test('release is idempotent when the lock was never acquired', () {
    final directory = Directory.systemTemp.createTempSync('ensemble-lock-');
    addTearDown(() => directory.deleteSync(recursive: true));

    expect(() => CliRunArtifactLock(directory.path).release(), returnsNormally);
  });
}
