import 'dart:io';

import 'package:ensemble_test_runner/cli/file_mutation_journal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late FileMutationJournal journal;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('file_mutation_journal_');
    journal = FileMutationJournal();
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('captures a file once and restores its original content', () {
    final file = File('${directory.path}/config.yaml')
      ..writeAsStringSync('old');

    journal.capture(file.path);
    file.writeAsStringSync('temporary');
    journal.capture(file.path);
    file.writeAsStringSync('changed again');
    journal.restoreAll([file.path]);

    expect(file.readAsStringSync(), 'old');
  });

  test('continues restoring remaining files after one restore fails', () {
    final blockedPath = '${directory.path}/blocked.dart';
    final blockedFile = File(blockedPath)..writeAsStringSync('original');
    final survivor = File('${directory.path}/survivor.yaml')
      ..writeAsStringSync('original survivor');
    journal
      ..capture(blockedPath)
      ..capture(survivor.path);

    blockedFile.deleteSync();
    Directory(blockedPath).createSync();
    survivor.writeAsStringSync('temporary survivor');

    expect(
      () => journal.restoreAll([blockedPath, survivor.path]),
      throwsA(isA<FileSystemException>()),
    );
    expect(survivor.readAsStringSync(), 'original survivor');
    expect(journal.paths, [blockedPath]);

    Directory(blockedPath).deleteSync();
    journal.restoreAll([blockedPath]);
    expect(File(blockedPath).readAsStringSync(), 'original');
    expect(journal.paths, isEmpty);
  });

  test('write captures an existing file before replacement', () {
    final file = File('${directory.path}/config.yaml')
      ..writeAsStringSync('old');

    journal.write(file.path, 'temporary');
    journal.restoreAll([file.path]);

    expect(file.readAsStringSync(), 'old');
  });

  test('removes paths that did not exist before the patch', () {
    final file = File('${directory.path}/generated.dart');

    journal.write(file.path, 'generated', optional: true);
    journal.restoreAll([file.path]);

    expect(file.existsSync(), isFalse);
  });

  test('captures validated source without reopening the file', () {
    final file = File('${directory.path}/entry.dart')
      ..writeAsStringSync('validated source');

    journal.writeValidated(
      file.path,
      'changed after validation',
      originalContents: 'validated source',
    );
    journal.restoreAll([file.path]);

    expect(file.readAsStringSync(), 'validated source');
  });

  test('can preserve an intentional generated upgrade', () {
    final file = File('${directory.path}/entry.dart')
      ..writeAsStringSync('legacy');

    journal.capture(file.path);
    file.writeAsStringSync('upgraded');
    journal.preserve(file.path, 'upgraded');
    file.writeAsStringSync('temporary');
    journal.restoreAll([file.path]);

    expect(file.readAsStringSync(), 'upgraded');
  });

  test('removes the full empty directory chain created for generated files',
      () {
    final generatedDirectory = Directory('${directory.path}/test/generated');
    final generatedFile = File('${generatedDirectory.path}/entry.dart');

    journal.createDirectory(generatedDirectory.path);
    journal.capture(generatedFile.path, optional: true);
    generatedFile.writeAsStringSync('temporary entry');
    journal.restoreAll([generatedFile.path]);

    expect(generatedFile.existsSync(), isFalse);
    expect(generatedDirectory.existsSync(), isFalse);
    expect(Directory('${directory.path}/test').existsSync(), isFalse);
  });

  test('keeps a created directory if another file is placed in it', () {
    final generatedDirectory = Directory('${directory.path}/test');
    journal.createDirectory(generatedDirectory.path);
    File('${generatedDirectory.path}/application-output.txt')
        .writeAsStringSync('keep');

    journal.restoreAll(const []);

    expect(generatedDirectory.existsSync(), isTrue);
    expect(
      File('${generatedDirectory.path}/application-output.txt')
          .readAsStringSync(),
      'keep',
    );
  });
}
