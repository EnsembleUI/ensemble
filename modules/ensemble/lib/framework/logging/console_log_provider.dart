import 'package:ensemble/framework/logging/log_provider.dart';

class ConsoleLogProvider extends LogProvider {
  @override
  Future<void> log(Map<String, dynamic> config) async {
    // Construct a log message string
    var logLevel = (config['logLevel'] != null)
        ? config['logLevel'].toString().split('.').last
        : LogLevel.info.name; // Extracts enum value name

    final StringBuffer logMessage = StringBuffer()
      ..write("[$logLevel] ")
      ..write(config['name'])
      ..write(' - ')
      ..write(config['parameters']
          .entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', '));
    // Output log message to console
    print(logMessage.toString());
  }

  @override
  Future<void> init(
      {Map? options, String? ensembleAppId, bool shouldAwait = false}) async {
    this.ensembleAppId = ensembleAppId;
    // Initialization logic for ConsoleLogProvider, if any.
    // Since this is a console logger, we might not need any initialization.
    print('ConsoleLogProvider initialized.');
  }
}
