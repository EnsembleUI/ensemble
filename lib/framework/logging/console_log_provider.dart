import 'package:ensemble/framework/logging/log_provider.dart';

class ConsoleLogProvider extends LogProvider {

  @override
  Future<void> log(
      String event, Map<String, dynamic> parameters, LogLevel level) async {
    // Construct a log message string
    final StringBuffer logMessage = StringBuffer()
      ..write(
          "[${level.toString().split('.').last}] ") // Extracts enum value name
      ..write(event)
      ..write(' - ')
      ..write(parameters.entries.map((e) => '${e.key}: ${e.value}').join(', '));

    // Output log message to console
    print(logMessage.toString());
  }

  @override
  Future<void> init({Map? options,String? ensembleAppId,bool shouldAwait = false}) async {
    this.ensembleAppId = ensembleAppId;
    // Initialization logic for ConsoleLogProvider, if any.
    // Since this is a console logger, we might not need any initialization.
    print('ConsoleLogProvider initialized.');
  }
}
