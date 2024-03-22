enum LogType {
  appAnalytics,
  platformAnalytics,
  crashAnalytics,
}

abstract class LogProvider {
  bool shouldAwait = false;
  Map? options;
  String? ensembleAppId;
  Future<void> log(
      String event, Map<String, dynamic> parameters, LogLevel level);

  //init function to be implemented by subclasses
  Future<void> init({Map? options,String? ensembleAppId,bool shouldAwait = false});
}

enum LogLevel {
  info, //info and analytics are the same
  debug,
  fatal,
}
