import 'dart:convert';

import 'package:ensemble/framework/library.dart';
import 'package:flutter/cupertino.dart';
import 'package:sdui/invokables/invokable.dart';
import 'package:sdui/parser/ast.dart';
import 'package:sdui/parser/js_interpreter.dart';

class EnsembleContext {
  Map<String, dynamic> _contextMap = {};

  BuildContext? _buildContext;
  EnsembleContext({
    BuildContext? buildContext,
    Map<String, dynamic>? initialMap
  }) {
    if (buildContext != null) {
      setBuildContext(buildContext);
    }

    if (initialMap != null) {
      _contextMap.addAll(initialMap);
    }
  }

  /// Ensemble library requires buildContext to work
  void setBuildContext(BuildContext buildContext) {
    _buildContext = buildContext;
    _contextMap['ensemble'] = EnsembleLibrary(buildContext);
  }

  EnsembleContext clone() {
    return EnsembleContext(initialMap: _contextMap);
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


  /// evaluate single inline binding expression (getters only) e.g $(myVar.text).
  /// Note that this expects the variable to be surrounded by $(...)
  dynamic eval(dynamic expression) {
    if (expression is! String) {
      return expression;
    }

    // if just have single standalone expression, return the actual type (e.g integer)
    RegExpMatch? simpleExpression = RegExp(r'^\$\(([a-z_-\d."\(\)\[\]]+)\)$', caseSensitive: false)
        .firstMatch(expression);
    if (simpleExpression != null) {
      return evalVariable(simpleExpression.group(1)!);
    }
    // if we have multiple expressions, or mixing with text, return as String
    // greedy match anything inside a $() with letters, digits, period, square brackets.
    return expression.replaceAllMapped(RegExp(r'\$\(([a-z_-\d."\(\)\[\]]+)\)', caseSensitive: false),
            (match) => evalVariable("${match[1]}").toString());

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
        RegExpMatch? match = RegExp(r'([a-zA-Z_-\d]+)\s*\("([a-zA-Z_-\d]+)"\)').firstMatch(token);
        if (match != null) {
          // first group is the method name, second is the argument
          Function? method = data.getMethods()[match.group(1)];
          if (method != null) {
            return evalToken(tokens, index+1, Function.apply(method, [match.group(2)]));
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

/*
    // is invokable
    if (data is Invokable) {
      if (data.getGettableProperties().contains(tokens[1])) {
        return data.getProperty(tokens[1]);
      } else {
        // support methods with 1 key e.g getMyValue(key)
        RegExpMatch? match = RegExp(r'([a-zA-Z_-\d]+)\s*\("([a-zA-Z_-\d]+)"\)').firstMatch(tokens[1]);
        if (match != null) {
          // first group is the method name
          Function? method = data.getMethods()[match.group(1)];
          if (method != null) {
            dynamic result = Function.apply(method, [match.group(2)]);
            return result;
          }
        }
      }
    }
    // simple data
    else if (data != null) {
      return _parseToken(tokens, 0, _contextMap) ?? variable;
    }
    // can't resolve, return the original input
    return variable;
    */
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