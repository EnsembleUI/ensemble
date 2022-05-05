import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/parser/ast.dart';
import 'package:ensemble_ts_interpreter/parser/js_interpreter.dart';
import 'package:http/http.dart';

/// manages Data and Invokables within the current data scope.
/// This class can evaluate expressions based on the data scope
class DataContext {
  final Map<String, dynamic> _contextMap = {};
  final BuildContext buildContext;

  DataContext({required this.buildContext, Map<String, dynamic>? initialMap}) {
    if (initialMap != null) {
      _contextMap.addAll(initialMap);
    }
    _contextMap['ensemble'] = NativeInvokable(buildContext);
  }

  DataContext clone() {
    return DataContext(buildContext: buildContext, initialMap: _contextMap);
  }


  // raw data (data map, api result), traversable with dot and bracket notations
  void addDataContext(Map<String, dynamic> data) {
    _contextMap.addAll(data);
  }
  void addDataContextById(String id, dynamic value) {
    if (value != null) {
      _contextMap[id] = value;
    }
  }
  // invokable widget, traversable with getters, setters & methods
  void addInvokableContext(String id, Invokable widget) {
    _contextMap[id] = widget;
  }

  bool hasContext(String id) {
    return _contextMap[id] != null;
  }

  /// return the data context value given the ID
  dynamic getContextById(String id) {
    return _contextMap[id];
  }


  /// evaluate single inline binding expression (getters only) e.g $(myVar.text).
  /// Note that this expects the variable to be surrounded by $(...)
  dynamic eval(dynamic expression) {
    if (expression is! String) {
      return expression;
    }

    // if just have single standalone expression, return the actual type (e.g integer)
    RegExpMatch? simpleExpression = Utils.onlyExpression.firstMatch(expression);
    if (simpleExpression != null) {
      return evalVariable(simpleExpression.group(1)!);
    }
    // if we have multiple expressions, or mixing with text, return as String
    // greedy match anything inside a $() with letters, digits, period, square brackets.
    return expression.replaceAllMapped(Utils.containExpression,
            (match) => evalVariable("${match[1]}").toString());

    /*return replaceAllMappedAsync(
        expression,
        RegExp(r'\$\(([a-z_-\d."\(\)\[\]]+)\)', caseSensitive: false),
        (match) async => (await evalVariable("${match[1]}")).toString()
    );*/

  }

  Future<String> replaceAllMappedAsync(String string, Pattern exp, Future<String> Function(Match match) replace) async {
    StringBuffer replaced = StringBuffer();
    int currentIndex = 0;
    for(Match match in exp.allMatches(string)) {
      String prefix = match.input.substring(currentIndex, match.start);
      currentIndex = match.end;
      replaced
        ..write(prefix)
        ..write(await replace(match));
    }
    replaced.write(string.substring(currentIndex));
    return replaced.toString();
  }

  /// evaluate Typescript code block
  void evalCode(String codeBlock) {
    final json = jsonDecode(codeBlock);
    List<ASTNode> arr = ASTBuilder().buildArray(json['body']);
    dynamic rtnValue = Interpreter(_contextMap).evaluate(arr);
    //print(rtnValue);
  }

  dynamic evalToken(List<String> tokens, int index, dynamic data) {
    // can't go further, return data
    if (index == tokens.length) {
      return data;
    }

    if (data is Invokable) {
      String token = tokens[index];
      if (data.getGettableProperties().contains(token)) {
        return evalToken(tokens, index+1, data.getProperty(token));
      } else {
        // only support methods with 1 argument for now
        RegExpMatch? match = RegExp(r'''([a-zA-Z_-\d]+)\s*\(["']([a-zA-Z_-\d]+)["']\)''').firstMatch(token);
        if (match != null) {
          // first group is the method name, second is the argument
          Function? method = data.getMethods()[match.group(1)];
          if (method != null) {
            dynamic nextData = Function.apply(method, [match.group(2)]);
            return evalToken(tokens, index+1, nextData);
          }
        }
        // return null since we can't find any matching methods/getters on this Invokable
        return null;
      }

    } else if (data is Map) {
      return evalToken(tokens, index+1, data[tokens[index]]);
    }
    return data;
  }


  /// evaluate a single variable expression e.g myVariable.value.
  /// Note: use eval() if your variable are surrounded by $(...)
  dynamic evalVariable(String variable) {
    List<String> tokens = variable.split('.');
    dynamic result = evalToken(tokens, 1, _contextMap[tokens[0]]);

    // don't return null. Preferably returning the variable name
    // for debug purpose + we have something to display
    return result ?? variable;
  }

  /// token format: result
  static dynamic _parseToken(List<String> tokens, int index, Map<String, dynamic> map) {
    if (index == tokens.length-1) {
      return map[tokens[index]];
    }
    if (map[tokens[index]] == null) {
      return null;
    }
    return _parseToken(tokens, index+1, map[tokens[index]]);
  }


}


/// built-in helpers/utils accessible to all DataContext
class NativeInvokable with Invokable {
  final BuildContext _buildContext;
  NativeInvokable(this._buildContext);

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
      'debug': (value) => log('Debug: $value'),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  void navigateToScreen(String screenId) {
    Ensemble().navigateToPage(_buildContext, screenId);
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
  Map<String, dynamic>? _body;
  Map<String, String>? _headers;

  APIResponse({Response? response}) {
    if (response != null) {
      setAPIResponse(response);
    }
  }

  setAPIResponse(Response response) {
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