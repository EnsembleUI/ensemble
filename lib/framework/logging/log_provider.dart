enum LogType {
  appAnalytics,
  platformAnalytics,
  crashAnalytics,
}
abstract class LogProvider {
  final bool shouldAwait;

  LogProvider({this.shouldAwait = false});

  Future<void> log(String event, Map<String, dynamic> parameters, LogLevel level);

  //init function to be implemented by subclasses
  Future<void> init();
}

enum LogLevel {
  info,//info and analytics are the same
  debug,
  fatal,
}

