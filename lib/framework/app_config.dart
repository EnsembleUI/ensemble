import 'package:ensemble/ensemble.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class AppConfig with Invokable {
  @override
  Map<String, Function> getters() {
    return {
      'baseUrl': () => Ensemble().getConfig()?.getUserAppConfig()?.baseUrl
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

}