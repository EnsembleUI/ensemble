import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';

class EnsembleEvent extends Object with Invokable {
  final Invokable? source;
  String? name;
  dynamic data;
  dynamic error;
  EnsembleEvent(this.source, {this.data = const {}, this.error, this.name});
  static EnsembleEvent fromYaml(String name, YamlMap? map) {
    return EnsembleEvent(null, name: name, data: map?['data']);
  }

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

class EnsembleEventHandler {
  EnsembleAction action;
  ScopeManager scopeManager;
  EnsembleEventHandler(this.scopeManager, this.action);
  Future<dynamic> handleEvent(EnsembleEvent event, BuildContext context) {
    return ScreenController()
        .executeActionWithScope(context, scopeManager, action, event: event);
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
