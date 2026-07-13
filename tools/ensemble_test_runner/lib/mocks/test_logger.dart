import 'dart:io';

/// Simple in-memory logger for test runs.
class TestLogger {
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
    final directory = Directory('build/ensemble_test_runner/logs');
    await directory.create(recursive: true);
    final safeTestId = _safeFileName(testId);
    final safeName = _safeFileName(name);
    final fileName = safeTestId.isEmpty
        ? '$safeName.${_safeExtension(extension)}'
        : '${safeTestId}_$safeName.${_safeExtension(extension)}';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    return file.path;
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
