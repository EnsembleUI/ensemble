import 'dart:io';

/// Records original file contents so a temporary runner patch can be restored.
///
/// A `null` value represents a path that did not exist before the patch.
final class FileMutationJournal {
  final Map<String, String?> _originals = {};
  final Set<String> _createdDirectories = {};

  bool contains(String path) => _originals.containsKey(path);

  String? original(String path) => _originals[path];

  Iterable<String> get paths => _originals.keys;

  String? capture(String path, {bool optional = false}) {
    if (contains(path)) return _originals[path];
    final file = File(path);
    if (!file.existsSync()) {
      if (!optional) throw StateError('Expected file not found: $path');
      _originals[path] = null;
      return null;
    }
    final contents = file.readAsStringSync();
    _originals[path] = contents;
    return contents;
  }

  /// Records contents already read by validation without opening the file
  /// again. `null` records that the optional path did not exist.
  void captureValidatedContents(String path, String? contents) {
    if (contains(path)) return;
    _originals[path] = contents;
  }

  /// Captures [path] before replacing it, or records it as new when absent.
  void write(String path, String contents, {bool optional = false}) {
    if (!contains(path)) capture(path, optional: optional);
    File(path).writeAsStringSync(contents);
  }

  /// Replaces a file using content already read by validation or generation.
  /// This avoids reopening the file solely to populate the rollback journal.
  void writeValidated(
    String path,
    String contents, {
    required String? originalContents,
  }) {
    captureValidatedContents(path, originalContents);
    File(path).writeAsStringSync(contents);
  }

  /// Preserves an intentional generated upgrade after the temporary run.
  void preserve(String path, String contents) => _originals[path] = contents;

  /// Creates [path] and records every directory this call had to create.
  ///
  /// Empty created directories are removed after file restoration. Directories
  /// that acquire user or application files while the patch is active remain.
  void createDirectory(String path) {
    final requested = Directory(path).absolute;
    if (requested.existsSync()) return;

    final missing = <String>[];
    var ancestor = requested;
    while (!ancestor.existsSync()) {
      missing.add(ancestor.path);
      final parent = ancestor.parent;
      if (parent.path == ancestor.path) break;
      ancestor = parent;
    }
    requested.createSync(recursive: true);
    _createdDirectories.addAll(missing);
  }

  void restore(String path) {
    if (!contains(path)) return;
    final contents = original(path);
    if (contents == null) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
      return;
    }
    File(path).writeAsStringSync(contents);
  }

  /// Restores [priorityPaths] first, then any remaining captured paths.
  void restoreAll(Iterable<String> priorityPaths) {
    final restored = <String>{};
    final restoredPaths = <String>{};
    Object? firstFailure;
    StackTrace? firstFailureStack;

    void attemptRestore(String path) {
      try {
        restore(path);
        restoredPaths.add(path);
      } catch (error, stackTrace) {
        firstFailure ??= error;
        firstFailureStack ??= stackTrace;
      }
    }

    for (final path in priorityPaths) {
      if (!restored.add(path)) continue;
      attemptRestore(path);
    }
    for (final path in _originals.keys.toList()) {
      if (!restored.add(path)) continue;
      attemptRestore(path);
    }
    for (final path in restoredPaths) {
      _originals.remove(path);
    }
    final directories = _createdDirectories.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final completedDirectories = <String>{};
    for (final path in directories) {
      final directory = Directory(path);
      try {
        if (directory.existsSync() && directory.listSync().isEmpty) {
          directory.deleteSync();
        }
        completedDirectories.add(path);
      } catch (error, stackTrace) {
        firstFailure ??= error;
        firstFailureStack ??= stackTrace;
      }
    }
    for (final path in completedDirectories) {
      _createdDirectories.remove(path);
    }
    final failure = firstFailure;
    final stackTrace = firstFailureStack;
    if (failure != null && stackTrace != null) {
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }

  void rewriteIfChanged(
    File file,
    String Function(String content) rewrite,
  ) {
    final originalContents = file.readAsStringSync();
    final updated = rewrite(originalContents);
    if (updated == originalContents) return;
    capture(file.path);
    file.writeAsStringSync(updated);
  }
}
