import 'package:ensemble_test_runner/runner/test_artifacts.dart';

/// Simple in-memory logger for test runs.
class TestLogger {
  static const _artifactSuffix = String.fromEnvironment(
    'ensembleTestWorkerSuffix',
  );

  final List<String> logs = [];

  void log(String message) {
    logs.add(message);
  }

  Future<String> writeLogFile({
    required String testId,
    required String name,
    required String content,
    String extension = 'log',
  }) async {
    final directory = ensembleTestArtifactDirectory('logs');
    await directory.create(recursive: true);
    final safeTestId = _safeFileName(testId);
    final safeName = _safeFileName(name);
    final suffix = _safeFileName(_artifactSuffix);
    final suffixPart = suffix.isEmpty ? '' : '_$suffix';
    final fileName = safeTestId.isEmpty
        ? '$safeName$suffixPart.${_safeExtension(extension)}'
        : '${safeTestId}_$safeName$suffixPart.${_safeExtension(extension)}';
    final file = ensembleTestArtifactFile('logs', fileName);
    await file.writeAsString(content);
    return ensembleTestArtifactDisplayPath('logs', fileName);
  }

  void clear() => logs.clear();

  static String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  static String _safeExtension(String value) {
    final extension = value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
    return extension.isEmpty ? 'log' : extension;
  }
}
