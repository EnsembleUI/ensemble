import 'package:ensemble/framework/logging/log_provider.dart';

class LogManager {
  final Map<LogType, Map<LogLevel, List<LogProvider>>> _providers = {};
  static final LogManager _instance = LogManager._internal();
  LogManager._internal();
  factory LogManager() => _instance;

  void addProvider(LogType type, LogLevel level, LogProvider provider) {
    _providers.putIfAbsent(type, () => {});
    var levelProviders = _providers[type]!;
    levelProviders.putIfAbsent(level, () => []).add(provider);
  }

  void addProviderForAllLevels(LogType type, LogProvider provider) {
    for (var level in LogLevel.values) {
      addProvider(type, level, provider);
    }
  }

  Future<void> log(LogType type, Map<String, dynamic> config) async {
    if (type == LogType.appAnalytics) {
      type = LogType.appAnalytics;
    }

    final levelProviders = _providers[type]?[config['logLevel']];
    if (levelProviders == null) return;

    List<Future<void>> tasks = [];
    for (final provider in levelProviders) {
      final task = provider.handleAnalytics(config);
      if (provider.shouldAwait) {
        tasks.add(task);
      } else {
        // Fire-and-forget
        task.catchError((error) {
          // Optionally handle or log errors
          print('Error logging event: $error');
        });
        // No need to add to tasks as it's fire-and-forget
      }
    }

    // If any tasks are meant to be awaited, wait for them here
    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
  }
}
