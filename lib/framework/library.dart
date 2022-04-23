

import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

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

class APIResponse with Invokable {
  late final Map<String, dynamic> _body;
  late final Map<String, String> _headers;
  APIResponse(Response response) {
    try {
      _body = json.decode(response.body);
    } on FormatException catch (_, e) {
      log('Supporting only JSON for API response');
    }
    _headers = response.headers;
  }

  @override
  Map<String, Function> getters() {
    return {
      'body': () => _body,
      'headers': () => _headers
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