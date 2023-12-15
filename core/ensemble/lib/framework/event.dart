import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class EnsembleEvent extends Object with Invokable {
  final Invokable? source;
  dynamic data;
  dynamic error;
  EnsembleEvent(this.source, {this.data = const {}, this.error});
  @override
  Map<String, Function> getters() {
    return {'data': () => data, 'error': () => error, 'source': () => source};
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

class WebViewNavigationEvent extends EnsembleEvent {
  bool allowNavigation = true;

  WebViewNavigationEvent(super.source, String url) {
    data = {'url': url};
  }
  @override
  Map<String, Function> setters() {
    Map<String, Function> setters = {
      'allowNavigation': (value) =>
          allowNavigation = Utils.getBool(value, fallback: true),
    };
    setters.addAll(super.setters());
    return setters;
  }
}
