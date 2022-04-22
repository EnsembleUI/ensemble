

import 'package:ensemble/ensemble.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sdui/invokables/invokable.dart';

class EnsembleLibrary with Invokable {
  final BuildContext buildContext;
  EnsembleLibrary(this.buildContext);

  @override
  Map<String, Function> getters() {
    return {
      'storage': () => EnsembleStorage(),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'navigateScreen': navigateToScreen,
      'debug': (value) async {
        if (value is Future) {
          value.then((value) => print('Debug: $value'));
        } else {
          print('Debug: $value');
        }
      },
    };
  }

  @override
  Map<String, Function> setters() {
    // TODO: implement setters
    throw UnimplementedError();
  }

  void navigateToScreen(String screenId) {
    Ensemble().navigateToPage(buildContext, screenId);
  }

}

/// Singleton handling user storage
class EnsembleStorage with Invokable {
  static final EnsembleStorage _instance = EnsembleStorage._internal();
  EnsembleStorage._internal();
  factory EnsembleStorage() {
    return _instance;
  }
  // TODO: use async secure storage - extends FlutterSecureStorage
  final Map<String, dynamic> userStorage = {};

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'get': (String key) => userStorage[key],
      'set': (String key, dynamic value) {
        if (value != null) {
          userStorage[key] = value;
        }
      }
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

}