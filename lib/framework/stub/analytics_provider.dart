import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/logging/log_provider.dart';


class LogProviderStub extends LogProvider{
  @override
  Future<void> log(String event, Map<String, dynamic> parameters, LogLevel level) async {
    throw ConfigError(
        "Firebase Analytics Service is not enabled. "
            "Firebase analytics module has to be included and then enabled. Just enabling in config is not sufficient. "
            "Please review the Ensemble documentation.");
  }

  @override
  Future<void> init({Map? options, String? ensembleAppId, bool shouldAwait = false}) async {
    throw ConfigError(
        "Firebase Analytics Service is not enabled. "
            "Firebase analytics module has to be included and then enabled. Just enabling in config is not sufficient. "
            "Please review the Ensemble documentation.");
  }
}