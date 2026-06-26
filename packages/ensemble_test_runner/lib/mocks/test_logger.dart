/// Simple in-memory logger for test runs.
class TestLogger {
  final List<String> logs = [];

  void log(String message) {
    logs.add(message);
  }

  void clear() => logs.clear();
}
