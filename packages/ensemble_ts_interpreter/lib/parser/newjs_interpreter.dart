// ignore_for_file: unnecessary_null_comparison, unused_catch_clause, unnecessary_non_null_assertion, unused_local_variable
import 'dart:async';
import 'dart:convert';
import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/context.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecommons.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablepromises.dart';
import 'package:parsejs_null_safety/jsparser.dart';
import 'package:ensemble_ts_interpreter/parser/regex_ext.dart';

class Bindings extends RecursiveVisitor<dynamic> {
  List<String> bindings = [];
  List<String> resolve(Program program) {
    visit(program);
    return bindings;
  }

  String convertToString(List<String> list) {
    String rtn = '';
    list.forEach((element) {
      rtn += '.' + element;
    });
    return rtn;
  }

  @override
  visitVariableDeclarator(VariableDeclarator node) {
    final names = _bindingNames(node.name).map(visitName).toList();
    bindings.addAll(names);
    return names.join(',');
  }

  List<Name> _bindingNames(Node binding) {
    if (binding is Name) return [binding];
    if (binding is ObjectPattern) {
      return binding.properties.expand((property) {
        final value = property.value;
        if (value is Name) return [value];
        return _bindingNames(value);
      }).toList();
    }
    if (binding is ArrayPattern) {
      return binding.elements
          .whereType<Node>()
          .expand((element) => element is RestParameter
              ? _bindingNames(element.name)
              : _bindingNames(element))
          .toList();
    }
    if (binding is DefaultParameter) return _bindingNames(binding.name);
    if (binding is RestParameter) return _bindingNames(binding.name);
    return <Name>[];
  }

  @override
  visitBinary(BinaryExpression node) {
    dynamic left = node.left.visitBy(this);
    dynamic right = node.right.visitBy(this);
    if (left is String) {
      bindings.add(left);
    }
    if (right is String) {
      bindings.add(right);
    }
    return bindings;
  }

  @override
  visitMember(MemberExpression node) {
    dynamic obj = node.object.visitBy(this);
    if (obj != null) {
      return obj + '.' + node.property.visitBy(this);
    }
    return null;
  }

  @override
  String visitName(Name node) {
    return node.value;
  }

  @override
  String visitNameExpression(NameExpression node) {
    return node.name.visitBy(this) as String;
  }

  @override
  visitCall(CallExpression node) {
    if (node.arguments != null) {
      for (Expression exp in node.arguments) {
        dynamic rtn = exp.visitBy(this);
        if (rtn is String) {
          bindings.add(rtn);
        }
      }
    }
  }

  @override
  visitAssignment(AssignmentExpression node) {
    if (node.right != null) {
      dynamic rtn = node.right.visitBy(this);
      if (rtn is String) {
        bindings.add(rtn);
      }
    }
  }

  @override
  visitExpressionStatement(ExpressionStatement node) {
    dynamic rtn = node.expression.visitBy(this);
    if (rtn is String) {
      bindings.add(rtn);
    }
  }

  @override
  visitIndex(IndexExpression node, {bool computeAsPattern = false}) {
    dynamic obj = node.object.visitBy(this);
    dynamic prop;
    if (node.property is LiteralExpression) {
      prop = (node.property as LiteralExpression).value;
    }
    if (node.property is NameExpression) {
      if (obj is String) {
        bindings.add(obj);
        bindings.add(node.property.visitBy(this)
            as String); //we add the name to the bindings as well
      }
    } else if (obj is String) {
      if (prop is num) {
        return obj + '[' + prop.toString() + ']';
      } else if (prop is String) {
        return obj + "['" + prop + "']";
      }
    }
  }

  @override
  visitConditional(ConditionalExpression node) {
    return node.condition.visitBy(this);
  }

  defaultNode(Node node) {
    dynamic rtn;
    node.forEach((node) {
      rtn = visit(node);
    });
    return rtn;
  }
}

class _LexicalBinding {
  dynamic value;
  final bool mutable;
  bool initialized;

  _LexicalBinding.uninitialized({required this.mutable})
      : initialized = false,
        value = null;

  _LexicalBinding.initialized(this.value, {required this.mutable})
      : initialized = true;
}

class _LexicalContext {
  final Map<String, _LexicalBinding> bindings = {};

  bool has(String name) => bindings.containsKey(name);

  dynamic get(String name, int line) {
    final binding = bindings[name]!;
    if (!binding.initialized) {
      throw JSException(line,
          "Cannot access lexical variable '$name' before initialization.");
    }
    return binding.value;
  }

  void declare(String name, {required bool mutable}) {
    bindings.putIfAbsent(
        name, () => _LexicalBinding.uninitialized(mutable: mutable));
  }

  void initialize(String name, dynamic value, {required bool mutable}) {
    bindings[name] = _LexicalBinding.initialized(value, mutable: mutable);
  }

  void set(String name, dynamic value, int line) {
    final binding = bindings[name]!;
    if (!binding.mutable && binding.initialized) {
      throw JSException(line, "Assignment to constant variable '$name'.");
    }
    binding.value = value;
    binding.initialized = true;
  }

  _LexicalContext snapshot() {
    final next = _LexicalContext();
    bindings.forEach((key, binding) {
      next.bindings[key] =
          _LexicalBinding.uninitialized(mutable: binding.mutable)
            ..value = binding.value
            ..initialized = binding.initialized;
    });
    return next;
  }
}

class _ForLoopBinding {
  final Node binding;
  final String kind;
  final VariableDeclaration? declaration;

  _ForLoopBinding(this.binding, this.kind, this.declaration);
}

class JSInterpreter extends RecursiveVisitor<dynamic> {
  late String code;
  late Program program;
  Map<Scope, Context> contexts = {};
  final List<Context> _dynamicContexts = [];
  final List<_LexicalContext> _lexicalContexts = [];
  String? _nextStatementLabel;
  String _currentDeclarationKind = 'var';
  @override
  defaultNode(Node node) {
    dynamic rtn;
    node.forEach((node) => rtn = visit(node));
    return rtn;
  }

  String getCode(Node node) {
    String rtn = '';
    if (node.start != null && node.end != null) {
      rtn = code.substring(node.start!, node.end!);
    }
    return rtn;
  }

  JSInterpreter(this.code, this.program, Context programContext) {
    contexts[program] = programContext;
    InvokableController.addGlobals(programContext.getContextMap());
    InvokableController.updateLocale(programContext.getContextMap());
  }
  static const String parsingErrorAppendage =
      "ES5 is the compatibility baseline. "
      "Selected ES6+ conveniences such as arrow functions, let/const, template literals, tagged templates, destructuring declarations, object shorthand/methods, computed property names, default/rest parameters, spread in arrays/calls, for...of, optional chaining, nullish coalescing, Symbol keys, Promises, and practical async/await are supported. "
      "Classes, modules, generators, and full ES6+ conformance are not supported yet.";
  JSInterpreter.fromCode(String code, Context programContext)
      : this(code, parseCode(code), programContext);
  static Program parseCode(String code) {
    if (code.isEmpty) {
      throw JSException(1,
          "Empty string is being passed as javascript code to parse. Please check your javascript code and fix it");
    }
    try {
      return parsejs(code);
    } on ParseError catch (e) {
      final line = e.line ?? 1;
      final column = _columnForOffset(code, e.startOffset);
      throw JSException(
        line,
        "JavaScript parse error: ${e.message}.",
        column: column,
        recovery: parsingErrorAppendage,
        detailedError: _formatParseDetails(code, line, column),
        originalError: e,
      );
    } catch (error) {
      throw JSException(
        1,
        "JavaScript parse error: ${error.toString()}.",
        recovery: parsingErrorAppendage,
        detailedError: _formatParseDetails(code, 1, 1),
        originalError: error,
      );
    }
  }

  static int _columnForOffset(String code, int? offset) {
    if (offset == null || offset < 0 || offset > code.length) return 1;
    final lineStart = code.lastIndexOf('\n', offset - 1) + 1;
    return offset - lineStart + 1;
  }

  static String _formatParseDetails(String code, int line, int column) {
    final lines = code.split('\n');
    if (lines.isEmpty) return parsingErrorAppendage;
    final index = (line - 1).clamp(0, lines.length - 1);
    final start = (index - 1).clamp(0, lines.length - 1);
    final end = (index + 1).clamp(0, lines.length - 1);
    final buffer = StringBuffer('Near line $line, column $column:\n');
    for (var i = start; i <= end; i++) {
      final lineNumber = i + 1;
      buffer.writeln('${lineNumber.toString().padLeft(4)} | ${lines[i]}');
      if (i == index) {
        buffer.writeln('     | ${' ' * (column - 1)}^');
      }
    }
    return buffer.toString();
  }

  static String toJSString(Map map) {
    int i = 0;
    Map placeHolders = {};
    String keyPrefix = '__ensemble_placeholder__';
    var encoded = jsonEncode(map, toEncodable: (value) {
      if (value is JavascriptFunction) {
        String key = keyPrefix + i.toString();
        placeHolders[key] = value.functionCode;
        i++;
        return key;
      }
      throw JSException(1, 'Cannot convert to JSON: $value');
    });
    placeHolders.forEach((key, value) {
      encoded = encoded.replaceFirst('\"$key\"', value);
    });
    return encoded;
  }

  Scope enclosingScope(Node node) {
    while (node is! Scope) {
      node = node.parent!;
    }
    return node;
  }

  Context findProgramContext(Node node) {
    Scope scope = enclosingScope(node);
    while (scope is! Program) {
      scope = enclosingScope(scope.parent!);
    }
    return getContextForScope(scope);
  }

  JSInterpreter cloneForContext(
      Scope scope, Context ctx, bool inheritContexts) {
    JSInterpreter i = JSInterpreter(
        this.code, this.program, getContextForScope(this.program));
    i._dynamicContexts.addAll(_dynamicContexts);
    i._lexicalContexts.addAll(_lexicalContexts);
    if (inheritContexts) {
      contexts.keys.forEach((key) {
        i.contexts[key] = contexts[key]!;
      });
    }
    i.contexts[scope] = ctx;
    return i;
  }

  Scope findScope(Name nameNode) {
    String name = nameNode.value;
    Node parent = nameNode.parent!;
    Node node = nameNode;
    if (parent is FunctionNode && parent.name == node && !parent.isExpression) {
      node = parent.parent!;
    }
    Scope scope = enclosingScope(node);
    while (scope is! Program) {
      if (scope.environment == null)
        throw JSException(scope.line ?? 1,
            'Scope does not have an environment. Scope:${getCode(scope)}');
      if (scope.environment!.contains(name)) return scope;
      scope = enclosingScope(scope.parent!);
    }
    return scope;
  }

  Context getContextForScope(Scope scope) {
    // Some transient scopes may not have been registered; fall back to program.
    return contexts[scope] ?? contexts[program]!;
  }

  void addToThisContext(Name node, dynamic value) {
    Context ctx = getContextForScope(node.scope!);
    ctx.addToThisContext(node.value, value);
  }

  void addToContext(Name node, dynamic value) {
    for (final _LexicalContext lexical in _lexicalContexts.reversed) {
      if (lexical.has(node.value)) {
        lexical.set(node.value, value, node.line ?? 1);
        return;
      }
    }
    for (final Context candidate in _dynamicContexts.reversed) {
      if (candidate.hasContext(node.value)) {
        candidate.addDataContextById(node.value, value);
        return;
      }
    }
    for (final Scope s in contexts.keys.toList().reversed) {
      final Context candidate = contexts[s]!;
      if (candidate.hasContext(node.value)) {
        candidate.addDataContextById(node.value, value);
        return;
      }
    }
    Context ctx = getContextForScope(node.scope!);
    ctx.addDataContextById(node.value, value);
  }

  List<Name> _bindingNames(Node binding) {
    if (binding is Name) return [binding];
    if (binding is ObjectPattern) {
      return binding.properties.expand((property) {
        final value = property.value;
        if (value is Name) return [value];
        return _bindingNames(value);
      }).toList();
    }
    if (binding is ArrayPattern) {
      return binding.elements
          .whereType<Node>()
          .expand((element) => element is RestParameter
              ? _bindingNames(element.name)
              : _bindingNames(element))
          .toList();
    }
    if (binding is DefaultParameter) return _bindingNames(binding.name);
    if (binding is RestParameter) return _bindingNames(binding.name);
    throw JSException(binding.line ?? 1, 'Unsupported binding pattern.');
  }

  void _bindPattern(Node binding, dynamic value,
      {required bool lexical, required bool mutable, required int line}) {
    if (binding is Name) {
      if (lexical) {
        for (final lexicalContext in _lexicalContexts.reversed) {
          if (lexicalContext.has(binding.value)) {
            lexicalContext.set(binding.value, value, line);
            return;
          }
        }
        final lexicalContext = _LexicalContext();
        lexicalContext.initialize(binding.value, value, mutable: mutable);
        _lexicalContexts.add(lexicalContext);
      } else {
        addToThisContext(binding, value);
      }
      return;
    }
    if (binding is ObjectPattern) {
      final excludedKeys = <dynamic>{};
      for (final property in binding.properties) {
        if (property.isSpread) {
          final rest = <dynamic, dynamic>{};
          if (value is Map) {
            for (final key in InvokableController.ownEnumerableKeys(value)) {
              if (!excludedKeys.contains(key)) {
                rest[key] = InvokableController.getProperty(value, key);
              }
            }
          }
          _bindPattern(property.value, rest,
              lexical: lexical, mutable: mutable, line: line);
          continue;
        }
        final key = _propertyKey(property);
        excludedKeys.add(key);
        final propertyValue =
            value == null || !InvokableController.hasProperty(value, key)
                ? jsUndefined
                : InvokableController.getProperty(value, key);
        _bindPattern(property.value, propertyValue,
            lexical: lexical, mutable: mutable, line: line);
      }
      return;
    }
    if (binding is ArrayPattern) {
      final values = value is List ? value : <dynamic>[];
      for (int i = 0; i < binding.elements.length; i++) {
        final element = binding.elements[i];
        if (element == null) continue;
        if (element is RestParameter) {
          _bindPattern(element.name, values.skip(i).toList(),
              lexical: lexical, mutable: mutable, line: line);
          break;
        }
        final elementValue = i < values.length ? values[i] : jsUndefined;
        _bindPattern(element, elementValue,
            lexical: lexical, mutable: mutable, line: line);
      }
      return;
    }
    if (binding is RestParameter) {
      _bindPattern(binding.name, value,
          lexical: lexical, mutable: mutable, line: line);
      return;
    }
    if (binding is DefaultParameter) {
      final actualValue = isJSUndefined(value)
          ? getValueFromExpression(binding.defaultValue)
          : value;
      _bindPattern(binding.name, actualValue,
          lexical: lexical, mutable: mutable, line: line);
      return;
    }
    throw JSException(binding.line ?? line, 'Unsupported binding pattern.');
  }

  void _bindParameter(Map<String, dynamic> ctx, Node binding, dynamic value,
      {required int line}) {
    if (binding is Name) {
      ctx[binding.value] = value;
      return;
    }
    if (binding is ObjectPattern) {
      final excludedKeys = <dynamic>{};
      for (final property in binding.properties) {
        if (property.isSpread) {
          final rest = <dynamic, dynamic>{};
          if (value is Map) {
            for (final key in InvokableController.ownEnumerableKeys(value)) {
              if (!excludedKeys.contains(key)) {
                rest[key] = InvokableController.getProperty(value, key);
              }
            }
          }
          _bindParameter(ctx, property.value, rest, line: line);
          continue;
        }
        final key = _propertyKey(property);
        excludedKeys.add(key);
        final propertyValue =
            value == null || !InvokableController.hasProperty(value, key)
                ? jsUndefined
                : InvokableController.getProperty(value, key);
        _bindParameter(ctx, property.value, propertyValue, line: line);
      }
      return;
    }
    if (binding is ArrayPattern) {
      final values = value is List ? value : <dynamic>[];
      for (int i = 0; i < binding.elements.length; i++) {
        final element = binding.elements[i];
        if (element == null) continue;
        if (element is RestParameter) {
          _bindParameter(ctx, element.name, values.skip(i).toList(),
              line: line);
          break;
        }
        _bindParameter(
            ctx, element, i < values.length ? values[i] : jsUndefined,
            line: line);
      }
      return;
    }
    if (binding is RestParameter) {
      _bindParameter(ctx, binding.name, value, line: line);
      return;
    }
    if (binding is DefaultParameter) {
      final actualValue = isJSUndefined(value) || value == null
          ? getValueFromExpression(binding.defaultValue)
          : value;
      _bindParameter(ctx, binding.name, actualValue, line: line);
      return;
    }
    throw JSException(binding.line ?? line, 'Unsupported function parameter.');
  }

  void _assignPattern(Expression pattern, dynamic value, int line) {
    if (pattern is NameExpression) {
      addToContext(pattern.name, value);
      return;
    }
    if (pattern is ArrayExpression) {
      final values = value is List ? value : <dynamic>[];
      for (int i = 0; i < pattern.expressions.length; i++) {
        final element = pattern.expressions[i];
        if (element == null) continue;
        if (element is SpreadExpression) {
          _assignPattern(element.argument, values.skip(i).toList(), line);
          break;
        }
        _assignPattern(
            element, i < values.length ? values[i] : jsUndefined, line);
      }
      return;
    }
    if (pattern is ObjectExpression) {
      for (final property in pattern.properties) {
        if (property.isSpread) {
          throw JSException(line,
              'Rest properties in destructuring assignment are not supported yet.');
        }
        final key = _propertyKey(property);
        final propertyValue = value == null
            ? jsUndefined
            : InvokableController.getProperty(value, key);
        if (property.value is NameExpression) {
          _assignPattern(property.value as NameExpression, propertyValue, line);
        } else {
          throw JSException(line,
              'Nested object destructuring assignment is not supported yet.');
        }
      }
      return;
    }
    throw JSException(line, 'Unsupported destructuring assignment target.');
  }

  void _hoistBinding(Node binding, dynamic value) {
    for (final name in _bindingNames(binding)) {
      final ctx = getContextForScope(name.scope!);
      if (!ctx.hasContext(name.value)) {
        addToThisContext(name, value);
      }
    }
  }

  // dynamic removeFromContext(Name node) {
  //   Map m = getContextForScope(node.scope!);
  //   return m.remove(node.value);
  // }
  dynamic getValueFromNode(Node node) {
    dynamic value = node.visitBy(this);
    if (value is List) {
      List<dynamic> arr = [];
      value.forEach((element) {
        if (element is Node) {
          arr.add(getValueFromNode(element));
        } else {
          arr.add(element);
        }
      });
      //we must not assign the array to a new array as it will be disconnected from the original.
      //Take the nested array case when you are changing value within the nested array.
      //see 2darrayissue in unit tests
      //value = arr;
      for (int i = 0; i < value.length; i++) {
        value[i] = arr[i];
      }
    } else if (value is Name) {
      value = getValue(value);
    } else if (node is ThisExpression) {
      value = getValueFromString(value);
    }
    return value;
  }

  dynamic getValueFromString(String name) {
    for (final _LexicalContext lexical in _lexicalContexts.reversed) {
      if (lexical.has(name)) return lexical.get(name, 1);
    }
    for (final Context ctx in _dynamicContexts.reversed) {
      if (ctx.hasContext(name)) return ctx.getContextById(name);
    }
    for (final Scope s in contexts.keys.toList().reversed) {
      if (contexts[s]!.hasContext(name))
        return contexts[s]!.getContextById(name);
    }
    Context ctx = getContextForScope(program);
    return ctx.getContextById(name);
  }

  bool _hasName(String name) {
    for (final _LexicalContext lexical in _lexicalContexts.reversed) {
      if (lexical.has(name)) return true;
    }
    for (final Context ctx in _dynamicContexts.reversed) {
      if (ctx.hasContext(name)) return true;
    }
    for (final Scope s in contexts.keys.toList().reversed) {
      if (contexts[s]!.hasContext(name)) return true;
    }
    return getContextForScope(program).hasContext(name);
  }

  dynamic getValue(Name node) {
    for (final _LexicalContext lexical in _lexicalContexts.reversed) {
      if (lexical.has(node.value)) {
        return lexical.get(node.value, node.line ?? 1);
      }
    }

    // 1) Dynamic object scopes from `with` shadow lexical scopes.
    for (final Context ctx in _dynamicContexts.reversed) {
      if (ctx.hasContext(node.value)) {
        return ctx.getContextById(node.value);
      }
    }

    // 2) Try the node's own scope next (captures nested function declarations).
    if (node.scope != null) {
      final Context scopedCtx = getContextForScope(node.scope!);
      if (scopedCtx.hasContext(node.value)) {
        return scopedCtx.getContextById(node.value);
      }
    }

    // 3) Scan all known contexts (newest first) as a safety net.
    for (final Scope s in contexts.keys.toList().reversed) {
      if (contexts[s]!.hasContext(node.value)) {
        return contexts[s]!.getContextById(node.value);
      }
    }

    // 4) Fallback to the resolved scope via environment tracking.
    Scope scope = findScope(node);
    Context ctx = getContextForScope(scope);
    return ctx.getContextById(node.value);
  }

  evaluate({Node? node}) {
    dynamic rtn;
    try {
      if (node != null) {
        rtn = visit(node);
      } else {
        //first visit all the function declarations
        for (int i = program.body.length - 1; i >= 0; i--) {
          Statement stmt = program.body[i];
          if (stmt is FunctionDeclaration) {
            stmt.visitBy(this);
          }
        }
        rtn = visit(program);
        if (rtn is Name) {
          rtn = getValue(rtn);
        }
      }
    } on ControlFlowReturnException catch (e) {
      rtn = e.returnValue;
    } on JSException catch (e) {
      rethrow;
    } catch (e) {
      throw JSException(1, e.toString(),
          detailedError: 'Code: $code', originalError: e);
    }
    return rtn;
  }

  dynamic executeConditional(
      Expression testExp, Node consequent, Node? alternate) {
    dynamic condition = getValueFromExpression(testExp);
    bool test = toBoolean(condition);
    dynamic rtn;
    if (test) {
      rtn = consequent.visitBy(this);
    } else {
      if (alternate != null) {
        rtn = alternate.visitBy(this);
      }
    }
    return rtn;
  }

  @override
  visitThis(ThisExpression node) {
    return 'this';
  }

  @override
  visitSequence(SequenceExpression node) {
    dynamic rtn;
    for (final Expression expression in node.expressions) {
      rtn = getValueFromExpression(expression);
    }
    return rtn;
  }

  @override
  visitDebugger(DebuggerStatement node) {
    return null;
  }

  @override
  visitLabeledStatement(LabeledStatement node) {
    final oldLabel = _nextStatementLabel;
    _nextStatementLabel = node.label.value;
    try {
      return node.body.visitBy(this);
    } on ControlFlowBreakException catch (e) {
      if (e.label == node.label.value) return null;
      rethrow;
    } finally {
      _nextStatementLabel = oldLabel;
    }
  }

  @override
  visitConditional(ConditionalExpression node) {
    return executeConditional(node.condition, node.then, node.otherwise);
  }

  @override
  visitIf(IfStatement node) {
    return executeConditional(node.condition, node.then, node.otherwise);
  }

  @override
  visitProperty(Property node) {
    final key = _propertyKey(node);
    if (node.isGetter) {
      return {
        'key': key,
        'descriptor': JSPropertyDescriptor(
          get: _wrapJavascriptFunction(
              visitFunctionNode(node.function, inheritContext: true)),
          enumerable: true,
          configurable: true,
        )
      };
    }
    if (node.isSetter) {
      return {
        'key': key,
        'descriptor': JSPropertyDescriptor(
          set: _wrapJavascriptFunction(
              visitFunctionNode(node.function, inheritContext: true)),
          enumerable: true,
          configurable: true,
        )
      };
    }
    return {
      'key': key,
      'descriptor': JSPropertyDescriptor(
        value: node.value is FunctionNode
            ? visitFunctionNode(node.value as FunctionNode,
                inheritContext: true)
            : getValueFromNode(node.value),
        writable: true,
        enumerable: true,
        configurable: true,
      )
    };
  }

  dynamic _propertyKey(Property node) {
    if (node.computed) {
      return getValueFromNode(node.key);
    }
    if (node.key is Name) {
      return (node.key as Name).value;
    }
    if (node.key is LiteralExpression) {
      return (node.key as LiteralExpression).value;
    }
    throw JSException(node.line ?? -1,
        'Property of object ${node.toString()} is not supported.');
  }

  @override
  visitObject(ObjectExpression node) {
    Map obj = {};
    for (Property property in node.properties) {
      if (property.isSpread) {
        final source = getValueFromNode(property.value);
        if (source is Map) {
          for (final key in InvokableController.ownEnumerableKeys(source)) {
            InvokableController.setProperty(
                obj, key, InvokableController.getProperty(source, key));
          }
        }
        continue;
      }
      Map prop = visitProperty(property);
      InvokableController.defineProperty(
          obj, prop['key'], prop['descriptor'] as JSPropertyDescriptor);
    }
    return obj;
  }

  Function _wrapJavascriptFunction(dynamic fn) {
    if (fn is JavascriptFunction) {
      return (List<dynamic> args, [dynamic thisArg]) =>
          fn.callWithThis(args, thisArg);
    }
    return fn as Function;
  }

  @override
  visitReturn(ReturnStatement node) {
    dynamic returnValue;
    if (node.argument != null) {
      returnValue = getValueFromExpression(node.argument!);
    }
    throw ControlFlowReturnException(node.line ?? -1, '', returnValue);
  }

  @override
  visitUnary(UnaryExpression node) {
    // Handle 'delete' operator specially - it needs to work on property expressions
    if (node.operator == 'delete') {
      PropertyPattern? pattern;
      if (node.argument is MemberExpression) {
        pattern = visitMember(node.argument as MemberExpression,
            computeAsPattern: true);
      } else if (node.argument is IndexExpression) {
        pattern = visitIndex(node.argument as IndexExpression,
            computeAsPattern: true);
      } else if (node.argument is Name || node.argument is NameExpression) {
        return true;
      }

      if (pattern != null) {
        return InvokableController.deleteProperty(
            pattern.obj, pattern.property);
      }
      return false;
    }

    dynamic val = getValueFromNode(node.argument);
    switch (node.operator) {
      case 'void':
        val = null;
        break;
      case '-':
        val = (val is num) ? -val : -toNumber(val);
        break;
      case '+':
        val = toNumber(val);
        break;
      case '++':
        val = (val is num) ? val + 1 : toNumber(val) + 1;
        break;
      case '--':
        val = (val is num) ? val - 1 : toNumber(val) - 1;
        break;
      case '~':
        val = (val is int) ? ~val : ~toNumber(val).toInt();
        break;
      case 'typeof':
        if (node.argument is NameExpression) {
          final name = (node.argument as NameExpression).name.value;
          val = _hasName(name) ? _jsTypeOf(val) : 'undefined';
        } else {
          val = _jsTypeOf(val);
        }
        break;
      case '!':
        val = !toBoolean(val);
        break;
      default:
        throw JSException(
            node.line ?? -1, "${node.operator} not yet implemented.",
            detailedError: "Code: " + getCode(node));
    }
    return val;
  }

  String _jsTypeOf(dynamic val) {
    if (isJSUndefined(val)) return 'undefined';
    if (val == null) return 'object'; // In JavaScript, typeof null is 'object'
    if (val is num) return 'number';
    if (val is String) return 'string';
    if (val is bool) return 'boolean';
    if (val is JavascriptFunction) return 'function';
    // Add other types as necessary, like 'function' for callable objects
    return 'object';
  }

  bool toBoolean(dynamic val) {
    if (_isNullish(val) ||
        val == 0 ||
        val == false ||
        val == '' ||
        val == 'false') {
      return false;
    }
    if (val is num && val.isNaN) {
      return false;
    }
    return true;
  }

  num toNumber(dynamic val) {
    if (isJSUndefined(val)) {
      return double.nan;
    } else if (val == null) {
      return 0;
    } else if (val is num) {
      return val;
    } else if (val is String) {
      if (val.trim().isEmpty) return 0;
      return num.tryParse(val) ?? double.nan;
    } else if (val is bool) {
      return val ? 1 : 0;
    }
    // Add additional type conversions as necessary
    return 0;
  }

  int _toInt32(dynamic val) => toNumber(val).toInt() & 0xffffffff;

  bool _strictEquals(dynamic left, dynamic right) {
    if (isJSUndefined(left) || isJSUndefined(right)) {
      return isJSUndefined(left) && isJSUndefined(right);
    }
    if (left == null || right == null) return left == null && right == null;
    if (left.runtimeType != right.runtimeType) return false;
    if (left is num && right is num && (left.isNaN || right.isNaN)) {
      return false;
    }
    return identical(left, right) || left == right;
  }

  bool _looseEquals(dynamic left, dynamic right) {
    if (_isNullish(left) && _isNullish(right)) return true;
    if (left == null && right == null) return true;
    if (left is num && right is num && (left.isNaN || right.isNaN)) {
      return false;
    }
    if (left.runtimeType == right.runtimeType) return left == right;
    if (left is bool) return _looseEquals(toNumber(left ? 1 : 0), right);
    if (right is bool) return _looseEquals(left, toNumber(right ? 1 : 0));
    if (left is num && right is String) return left == toNumber(right);
    if (left is String && right is num) return toNumber(left) == right;
    return false;
  }

  bool _isNullish(dynamic value) => value == null || isJSUndefined(value);

  bool _hasProperty(dynamic obj, dynamic property) =>
      InvokableController.hasProperty(obj, property);

  bool _isInstanceOf(dynamic obj, dynamic constructor) {
    if (constructor is Invokable) {
      if (constructor is StaticArray) return obj is List;
      return obj is Invokable;
    }
    if (constructor is JavascriptFunction) {
      return InvokableController.isPrototypeInChain(obj, constructor.prototype);
    }
    return false;
  }

  @override
  visitUpdateExpression(UpdateExpression node) {
    dynamic val = getValueFromExpression(node.argument!);
    PropertyPattern? pattern;
    num number;
    num originalNumber;
    if (val is num) {
      number = val;
      originalNumber = number;
    } else {
      throw JSException(
          node.line ?? -1,
          'The operator ' +
              node.operator! +
              ' is only valid for numbers and ' +
              node.argument.toString() +
              ' is not a number.',
          detailedError: 'Code: ${getCode(node)}');
    }
    if (node.argument is MemberExpression) {
      pattern = visitMember(node.argument as MemberExpression,
          computeAsPattern: true);
    } else if (node.argument is IndexExpression) {
      pattern =
          visitIndex(node.argument as IndexExpression, computeAsPattern: true);
    }

    if (pattern != null) {
      var obj = pattern.obj;
      switch (node.operator) {
        case '++':
          number++;
          InvokableController.setProperty(obj, pattern.property, number);
          break;
        case '--':
          number--;
          InvokableController.setProperty(obj, pattern.property, number);
          break;
        default:
          throw JSException(node.line ?? -1,
              "${node.operator!} in Code: ${getCode(node)} is not yet supported");
      }
    } else if (node.argument is Name || node.argument is NameExpression) {
      Name n;
      if (node.argument is NameExpression) {
        n = (node.argument as NameExpression).name;
      } else {
        n = node.argument as Name;
      }
      switch (node.operator) {
        case '++':
          number++;
          break;
        case '--':
          number--;
          break;
      }
      addToContext(n, number);
    }
    if (node.isPrefix) {
      return number;
    }
    return originalNumber;
  }

  @override
  visitFunctionDeclaration(FunctionDeclaration node) {
    // Always evaluate and add the function to current context
    // This allows Global code to overwrite Import functions, which is the correct
    // JavaScript behavior (shadowing parent scope functions).
    JavascriptFunction newFunc = visitFunctionNode(node.function);
    addToThisContext(node.function.name!, newFunc);
    return newFunc;
  }

  @override
  visitFunctionNode(FunctionNode node, {bool? inheritContext}) {
    final List<dynamic> args = computeArguments(node.params);
    final capturedLexicalContexts =
        List<_LexicalContext>.from(_lexicalContexts);
    late JavascriptFunction fn;
    fn = JavascriptFunction((List<dynamic>? _params, [dynamic thisArg]) {
      /*
        1. create a map, parmValueMap
        2. go through params and create a args[i]: parm[i] entry in the map
        3. push the map to the context stack
        4. execute the blockstatement or expression
       */
      List<dynamic> params = _params ?? [];
      Map<String, dynamic> ctx = {};

      if (node.params != null) {
        for (int i = 0; i < node.params.length; i++) {
          final param = node.params[i];
          if (param is RestParameter) {
            _bindParameter(ctx, param.name, params.skip(i).toList(),
                line: param.line ?? node.line ?? 1);
            break;
          }
          dynamic value = i < params.length ? params[i] : null;
          if (param is DefaultParameter && value == null) {
            value = getValueFromExpression(param.defaultValue);
          }
          _bindParameter(
              ctx, param is DefaultParameter ? param.name : param, value,
              line: param.line ?? node.line ?? 1);
        }
      }
      ctx['arguments'] = _buildArgumentsObject(params, fn);
      ctx['this'] = thisArg ?? getContextForScope(program).getContextMap();
      Context context = SimpleContext(ctx);
      // Inherit parent contexts so nested functions can see outer declarations.
      JSInterpreter i = cloneForContext(node, context, inheritContext ?? true);
      i._lexicalContexts
        ..clear()
        ..addAll(capturedLexicalContexts);
      if (node.isAsync) {
        return JSPromise.fromFuture(i._executeAsyncBody(node.body));
      }
      dynamic rtn;
      try {
        if (node.body != null) {
          rtn = node.body.visitBy(i);
        }
      } on ControlFlowReturnException catch (e) {
        rtn = e.returnValue;
      }
      if (rtn is Node) {
        rtn = i.getValueFromNode(rtn);
      }
      return rtn;
    }, code.substring(node.start!, node.end));
    return fn;
  }

  Map<dynamic, dynamic> _buildArgumentsObject(
      List<dynamic> params, JavascriptFunction callee) {
    final Map<dynamic, dynamic> args = {};
    for (int i = 0; i < params.length; i++) {
      args[i.toString()] = params[i];
      args[i] = params[i];
    }
    args['length'] = params.length;
    args['callee'] = callee;
    return args;
  }

  @override
  visitFunctionExpression(FunctionExpression node) {
    return visitFunctionNode(node.function, inheritContext: true);
  }

  Future<dynamic> _executeAsyncBody(Statement body) async {
    try {
      if (body is BlockStatement) {
        dynamic rtn;
        final lexicalContext = _LexicalContext();
        for (Statement stmt in body.body) {
          if (stmt is VariableDeclaration && stmt.kind != 'var') {
            for (final declarator in stmt.declarations) {
              for (final name in _bindingNames(declarator.name)) {
                lexicalContext.declare(name.value,
                    mutable: stmt.kind != 'const');
              }
            }
          }
        }
        _lexicalContexts.add(lexicalContext);
        try {
          for (final stmt in body.body) {
            rtn = await _executeAsyncStatement(stmt);
          }
          return rtn;
        } finally {
          _lexicalContexts.removeLast();
        }
      }
      return await _executeAsyncStatement(body);
    } on ControlFlowReturnException catch (e) {
      return e.returnValue;
    }
  }

  Future<dynamic> _executeAsyncStatement(Statement stmt) async {
    if (!_containsAwait(stmt)) {
      return stmt.visitBy(this);
    }
    if (stmt is ReturnStatement) {
      final value = stmt.argument == null
          ? null
          : await _getValueFromExpressionAsync(stmt.argument!);
      throw ControlFlowReturnException(stmt.line ?? -1, '', value);
    }
    if (stmt is ExpressionStatement) {
      return _getValueFromExpressionAsync(stmt.expression);
    }
    if (stmt is VariableDeclaration) {
      final previousKind = _currentDeclarationKind;
      _currentDeclarationKind = stmt.kind;
      try {
        for (final declarator in stmt.declarations) {
          final value = declarator.init == null
              ? null
              : await _getValueFromExpressionAsync(declarator.init!);
          _bindPattern(declarator.name, value,
              lexical: stmt.kind != 'var',
              mutable: stmt.kind != 'const',
              line: declarator.line ?? stmt.line ?? 1);
        }
      } finally {
        _currentDeclarationKind = previousKind;
      }
      return null;
    }
    if (stmt is IfStatement) {
      final condition = await _getValueFromExpressionAsync(stmt.condition);
      if (toBoolean(condition)) {
        return _executeAsyncStatement(stmt.then);
      }
      if (stmt.otherwise != null) {
        return _executeAsyncStatement(stmt.otherwise!);
      }
      return null;
    }
    if (stmt is ThrowStatement) {
      final value = await _getValueFromExpressionAsync(stmt.argument);
      if (value is JSCustomException) throw value;
      throw JSCustomException(value);
    }
    throw JSException(
        stmt.line ?? 1, 'await is not supported in this statement form yet.',
        detailedError: 'Code: ${getCode(stmt)}');
  }

  Future<dynamic> _getValueFromExpressionAsync(Expression expression) async {
    if (expression is AwaitExpression) {
      final value = await _getValueFromExpressionAsync(expression.argument);
      return _awaitJsValue(value);
    }
    if (!_containsAwait(expression)) {
      return getValueFromExpression(expression);
    }
    if (expression is BinaryExpression) {
      final left = await _getValueFromExpressionAsync(expression.left);
      if (expression.operator == '&&' && !toBoolean(left)) return left;
      if (expression.operator == '||' && toBoolean(left)) return left;
      if (expression.operator == '??' && !_isNullish(left)) return left;
      final right = await _getValueFromExpressionAsync(expression.right);
      return BinaryExpression(LiteralExpression(left), expression.operator,
              LiteralExpression(right))
          .visitBy(this);
    }
    if (expression is TemplateLiteral) {
      final buffer = StringBuffer();
      for (int i = 0; i < expression.strings.length; i++) {
        buffer.write(expression.strings[i]);
        if (i < expression.expressions.length) {
          final value =
              await _getValueFromExpressionAsync(expression.expressions[i]);
          buffer.write(value?.toString() ?? 'null');
        }
      }
      return buffer.toString();
    }
    if (expression is ConditionalExpression) {
      final condition =
          await _getValueFromExpressionAsync(expression.condition);
      return toBoolean(condition)
          ? _getValueFromExpressionAsync(expression.then)
          : _getValueFromExpressionAsync(expression.otherwise);
    }
    throw JSException(expression.line ?? 1,
        'await is not supported in this expression form yet.',
        detailedError: 'Code: ${getCode(expression)}');
  }

  Future<dynamic> _awaitJsValue(dynamic value) {
    if (value is JSPromise) return value.toFuture();
    if (value is Future) return value;
    return Future<dynamic>.value(value);
  }

  bool _containsAwait(Node node) {
    var found = false;
    void walk(Node child) {
      if (found) return;
      if (child is AwaitExpression) {
        found = true;
        return;
      }
      child.forEach(walk);
    }

    walk(node);
    return found;
  }

  @override
  visitAwait(AwaitExpression node) {
    throw JSException(
        node.line ?? 1, 'await can only be used inside async functions.');
  }

  @override
  visitArrowFunctionNode(ArrowFunctionNode node) {
    final List<dynamic> args = computeArguments(node.params);
    final capturedLexicalContexts =
        List<_LexicalContext>.from(_lexicalContexts);
    return JavascriptFunction((List<dynamic>? _params, [dynamic thisArg]) {
      List<dynamic> params = _params ?? [];
      Map<String, dynamic> ctx = {};
      if (node.params != null) {
        for (int i = 0; i < node.params.length; i++) {
          final param = node.params[i];
          if (param is RestParameter) {
            _bindParameter(ctx, param.name, params.skip(i).toList(),
                line: param.line ?? node.line ?? 1);
            break;
          }
          dynamic value = i < params.length ? params[i] : null;
          if (param is DefaultParameter && value == null) {
            value = getValueFromExpression(param.defaultValue);
          }
          _bindParameter(
              ctx, param is DefaultParameter ? param.name : param, value,
              line: param.line ?? node.line ?? 1);
        }
      }
      Context context = SimpleContext(ctx);
      JSInterpreter i = cloneForContext(node, context, true);
      i._lexicalContexts
        ..clear()
        ..addAll(capturedLexicalContexts);
      dynamic rtn;
      try {
        if (node.body != null) {
          rtn = node.body.visitBy(i);
        }
      } on ControlFlowReturnException catch (e) {
        rtn = e.returnValue;
      }
      if (rtn is Node) {
        rtn = i.getValueFromNode(rtn);
      }
      return rtn;
    }, code.substring(node.start!, node.end));
  }

  @override
  visitBlock(BlockStatement node) {
    dynamic rtn;
    final lexicalContext = _LexicalContext();
    for (Statement stmt in node.body) {
      if (stmt is VariableDeclaration && stmt.kind != 'var') {
        for (final declarator in stmt.declarations) {
          for (final name in _bindingNames(declarator.name)) {
            lexicalContext.declare(name.value, mutable: stmt.kind != 'const');
          }
        }
      }
    }
    _lexicalContexts.add(lexicalContext);
    // Hoist function declarations in this block before executing statements.
    try {
      for (Statement stmt in node.body) {
        if (stmt is FunctionDeclaration && stmt.function.name != null) {
          addToThisContext(
              stmt.function.name!, visitFunctionNode(stmt.function));
        }
      }
      for (Node stmt in node.body) {
        rtn = stmt.visitBy(this);
      }
      return rtn;
    } finally {
      _lexicalContexts.removeLast();
    }
  }

  @override
  visitVariableDeclaration(VariableDeclaration node) {
    final previousKind = _currentDeclarationKind;
    _currentDeclarationKind = node.kind;
    dynamic rtn;
    try {
      for (final declarator in node.declarations) {
        rtn = declarator.visitBy(this);
      }
    } finally {
      _currentDeclarationKind = previousKind;
    }
    return rtn;
  }

  @override
  visitVariableDeclarator(VariableDeclarator node) {
    Node binding = node.name;
    dynamic value;
    if (_currentDeclarationKind != 'var') {
      value = node.init != null ? getValueFromExpression(node.init!) : null;
      _bindPattern(binding, value,
          lexical: true,
          mutable: _currentDeclarationKind != 'const',
          line: node.line ?? 1);
      return binding;
    }
    if (node.init != null) {
      value = getValueFromExpression(node.init!);
      _bindPattern(binding, value,
          lexical: false, mutable: true, line: node.line ?? 1);
    } else {
      //hoisting
      _hoistBinding(binding, value);
    }
    return binding;
  }

  @override
  visitObjectPattern(ObjectPattern node) => node;

  @override
  visitArrayPattern(ArrayPattern node) => node;

  @override
  visitBinary(BinaryExpression node) {
    try {
      dynamic left = getValueFromExpression(node.left);
      //special check in case of || to avoid evaluating the right expression
      //https://github.com/EnsembleUI/ensemble/issues/574
      if (node.operator == '||') {
        if (left != false &&
            !_isNullish(left) &&
            left != 0 &&
            left != '' &&
            !(left is num && left.isNaN)) {
          return left;
        } else {
          return getValueFromExpression(node.right);
        }
      } else if (node.operator == '&&') {
        if (left == false ||
            _isNullish(left) ||
            left == 0 ||
            left == '' ||
            (left is num && left.isNaN)) {
          return left;
        } else {
          return getValueFromExpression(node.right);
        }
      } else if (node.operator == '??') {
        return _isNullish(left) ? getValueFromExpression(node.right) : left;
      }
      dynamic right = getValueFromExpression(node.right);
      dynamic rtn = false;
      if (left is SupportsPrimitiveOperations) {
        return left.runOperation(node.operator!, right);
      }
      if (node.operator == '+') {
        if (left == null && right == null) {
          left = 0;
          right = 0;
        } else if (left is String || right is String) {
          left = left?.toString() ?? "null";
          right = right?.toString() ?? "null";
        } else {
          left = left ?? 0;
          right = right ?? 0;
        }
      } else {
        // For other operators, treat null as 0 where applicable
        if ([
          '-',
          '/',
          '*',
          '%',
          '|',
          '&',
          '^',
          '<<',
          '>>',
          '>>>',
          '<',
          '<=',
          '>',
          '>='
        ].contains(node.operator)) {
          left = left ?? 0;
          right = right ?? 0;
        }
      }
      bool done = true;
      switch (node.operator) {
        case '==':
          rtn = _looseEquals(left, right);
          break;
        case '===':
          rtn = _strictEquals(left, right);
          break;
        case '!=':
          rtn = !_looseEquals(left, right);
          break;
        case '!==':
          rtn = !_strictEquals(left, right);
          break;
        case '<':
          rtn = left < right;
          break;
        case '<=':
          rtn = left <= right;
          break;
        case '>':
          rtn = left > right;
          break;
        case '>=':
          rtn = left >= right;
          break;
        case '-':
          rtn = left - right;
          break;
        case '+':
          rtn = left + right;
          break;
        case '/':
          rtn = left / right;
          break;
        case '*':
          rtn = left * right;
          break;
        case '%':
          rtn = left % right;
          break;
        case '|':
          rtn = left | right;
          break;
        case '^':
          rtn = left ^ right;
          break;
        case '<<':
          rtn = left << right;
          break;
        case '>>':
          rtn = left >> right;
          break;
        case '>>>':
          rtn = (_toInt32(left) & 0xffffffff) >> (toNumber(right).toInt() & 31);
          break;
        case '&':
          rtn = left & right;
          break;
        case 'in':
          rtn = _hasProperty(right, left);
          break;
        case 'instanceof':
          rtn = _isInstanceOf(left, right);
          break;
        default:
          done = false;
          break;
      }
      if (!done) {
        throw JSException(
            node.line ?? -1, node.operator! + ' is not yet supported',
            detailedError: 'Code: ${getCode(node)}');
      }
      return rtn;
    } on JSException catch (e) {
      rethrow;
    } on InvalidPropertyException catch (e) {
      throw JSException(node.line ?? 1, '${e.message}. Code: ${getCode(node)}');
    }
  }

  @override
  visitBreak(BreakStatement node) {
    throw ControlFlowBreakException(node.line ?? 1, '', node.label?.value);
  }

  @override
  visitContinue(ContinueStatement node) {
    throw ControlFlowContinueException(node.line ?? 1, '', node.label?.value);
  }

  @override
  visitFor(ForStatement node) {
    final String? loopLabel = _nextStatementLabel;
    _nextStatementLabel = null;
    final List<String> loopLetNames = node.init is VariableDeclaration &&
            (node.init as VariableDeclaration).kind == 'let'
        ? (node.init as VariableDeclaration)
            .declarations
            .expand((declaration) => _bindingNames(declaration.name))
            .map((name) => name.value)
            .toList()
        : <String>[];
    if (node.init != null) {
      node.init!.visitBy(this);
    }
    while (node.condition == null ||
        toBoolean(getValueFromNode(node.condition!))) {
      _LexicalContext? iterationContext;
      if (loopLetNames.isNotEmpty) {
        iterationContext = _snapshotLoopBindings(loopLetNames);
        _lexicalContexts.add(iterationContext);
      }
      try {
        node.body.visitBy(this);
      } on ControlFlowBreakException catch (e) {
        if (iterationContext != null) {
          _copyLoopBindings(iterationContext, loopLetNames);
          _lexicalContexts.removeLast();
        }
        if (e.label == loopLabel) break;
        if (e.label != null) rethrow;
        break;
      } on ControlFlowContinueException catch (e) {
        if (e.label == loopLabel) {
          // continue to update
        } else if (e.label != null) {
          rethrow;
        }
        //skip as we are executing the update anyway
      } finally {
        if (iterationContext != null &&
            identical(_lexicalContexts.last, iterationContext)) {
          _copyLoopBindings(iterationContext, loopLetNames);
          _lexicalContexts.removeLast();
        }
      }
      // Execute the update expression after each loop iteration
      // see https://github.com/EnsembleUI/ensemble/issues/1704
      if (node.update != null) {
        node.update!.visitBy(this);
      }
    }
  }

  _LexicalContext _snapshotLoopBindings(List<String> names) {
    final iteration = _LexicalContext();
    for (final name in names) {
      for (final lexical in _lexicalContexts.reversed) {
        if (lexical.has(name)) {
          final binding = lexical.bindings[name]!;
          iteration.bindings[name] =
              _LexicalBinding.uninitialized(mutable: binding.mutable)
                ..value = binding.value
                ..initialized = binding.initialized;
          break;
        }
      }
    }
    return iteration;
  }

  void _copyLoopBindings(_LexicalContext iteration, List<String> names) {
    for (final name in names) {
      if (!iteration.has(name)) continue;
      for (final lexical in _lexicalContexts.reversed.skip(1)) {
        if (lexical.has(name)) {
          final binding = iteration.bindings[name]!;
          lexical.bindings[name] =
              _LexicalBinding.uninitialized(mutable: binding.mutable)
                ..value = binding.value
                ..initialized = binding.initialized;
          break;
        }
      }
    }
  }

  @override
  visitWhile(WhileStatement node) {
    final String? loopLabel = _nextStatementLabel;
    _nextStatementLabel = null;
    while (toBoolean(getValueFromNode(node.condition))) {
      try {
        node.body.visitBy(this);
      } on ControlFlowBreakException catch (e) {
        if (e.label == loopLabel) break;
        if (e.label != null) rethrow;
        break;
      } on ControlFlowContinueException catch (e) {
        if (e.label == loopLabel) continue;
        if (e.label != null) rethrow;
        continue;
      }
    }
  }

  @override
  visitDoWhile(DoWhileStatement node) {
    final String? loopLabel = _nextStatementLabel;
    _nextStatementLabel = null;
    do {
      try {
        node.body.visitBy(this);
      } on ControlFlowBreakException catch (e) {
        if (e.label == loopLabel) break;
        if (e.label != null) rethrow;
        break;
      } on ControlFlowContinueException catch (e) {
        if (e.label == loopLabel) continue;
        if (e.label != null) rethrow;
        continue;
      }
    } while (toBoolean(getValueFromNode(node.condition)));
  }

  @override
  visitForIn(ForInStatement node) {
    dynamic right = getValueFromNode(node.right);
    dynamic left = node.left.visitBy(this);
    if (right is! Map) {
      throw JSException(node.line ?? 1,
          'for...in is only allowed for js objects or maps. $right is not a map',
          detailedError: 'Code: ${getCode(node)}');
    }
    if (left is! Name) {
      throw JSException(node.line ?? 1,
          'left side in the for...in expression must be a name node. $node.left is not name',
          detailedError: 'Code: ${getCode(node)}');
    }
    final Map map = right;
    for (dynamic key in InvokableController.enumerableKeys(map)) {
      addToContext(left, key);
      try {
        node.body.visitBy(this);
      } on ControlFlowBreakException catch (e) {
        if (e.label != null) rethrow;
        break;
      } on ControlFlowContinueException catch (e) {
        if (e.label != null) rethrow;
        continue;
      }
    }
    //removeFromContext(left);
  }

  @override
  visitForOf(ForOfStatement node) {
    final String? loopLabel = _nextStatementLabel;
    _nextStatementLabel = null;
    final dynamic right = getValueFromNode(node.right);
    final List<dynamic> values = _toForOfValues(right, node);
    final _ForLoopBinding binding = _forLoopBinding(node.left, node);

    if (binding.kind == 'var') {
      binding.declaration?.visitBy(this);
    }

    for (final value in values) {
      _LexicalContext? iterationContext;
      if (binding.kind == 'assignment' && binding.binding is Expression) {
        _assignPattern(binding.binding as Expression, value, node.line ?? 1);
      } else if (binding.kind != 'var') {
        iterationContext = _LexicalContext();
        for (final name in _bindingNames(binding.binding)) {
          iterationContext.declare(name.value,
              mutable: binding.kind != 'const');
        }
        _lexicalContexts.add(iterationContext);
        _bindPattern(binding.binding, value,
            lexical: true,
            mutable: binding.kind != 'const',
            line: node.line ?? 1);
      } else {
        _bindPattern(binding.binding, value,
            lexical: false, mutable: true, line: node.line ?? 1);
      }

      try {
        node.body.visitBy(this);
      } on ControlFlowBreakException catch (e) {
        if (iterationContext != null) {
          _lexicalContexts.removeLast();
        }
        if (e.label == loopLabel) break;
        if (e.label != null) rethrow;
        break;
      } on ControlFlowContinueException catch (e) {
        if (e.label == loopLabel) {
          // Continue with the next iterable value.
        } else if (e.label != null) {
          rethrow;
        }
      } finally {
        if (iterationContext != null &&
            _lexicalContexts.isNotEmpty &&
            identical(_lexicalContexts.last, iterationContext)) {
          _lexicalContexts.removeLast();
        }
      }
    }
  }

  List<dynamic> _toForOfValues(dynamic value, Node node) {
    if (value is List) return List<dynamic>.from(value);
    if (value is String) return value.split('');
    if (value is Invokable) {
      final methods = InvokableController.methods(value);
      final isMapLike =
          methods.containsKey('get') && methods.containsKey('set');
      final values = methods['values'];
      final entries = methods['entries'];
      if (isMapLike && entries != null) {
        final result = Function.apply(entries, const []);
        if (result is List) return List<dynamic>.from(result);
      }
      if (!isMapLike && values != null) {
        final result = Function.apply(values, const []);
        if (result is List) return List<dynamic>.from(result);
      }
      if (entries != null) {
        final result = Function.apply(entries, const []);
        if (result is List) return List<dynamic>.from(result);
      }
    }
    throw JSException(node.line ?? 1,
        'for...of requires a practical iterable value such as an array, string, Map, or Set.',
        detailedError: 'Code: ${getCode(node)}');
  }

  _ForLoopBinding _forLoopBinding(Node left, Node node) {
    if (left is VariableDeclaration) {
      if (left.declarations.length != 1) {
        throw JSException(
            node.line ?? 1, 'for...of supports one loop variable.');
      }
      return _ForLoopBinding(left.declarations.first.name, left.kind, left);
    }
    if (left is NameExpression) {
      return _ForLoopBinding(left.name, 'var', null);
    }
    if (left is ArrayExpression || left is ObjectExpression) {
      return _ForLoopBinding(left, 'assignment', null);
    }
    if (left is Name) {
      return _ForLoopBinding(left, 'var', null);
    }
    throw JSException(
        node.line ?? 1, 'left side in for...of must be a variable name.');
  }

  @override
  visitSwitch(SwitchStatement node) {
    final dynamic argument = getValueFromExpression(node.argument);
    var matched = false;
    var defaultIndex = -1;
    for (var i = 0; i < node.cases.length; i++) {
      if (node.cases[i].isDefault) {
        defaultIndex = i;
        continue;
      }
      if (_strictEquals(
          argument, getValueFromExpression(node.cases[i].expression!))) {
        matched = true;
        defaultIndex = i;
        break;
      }
    }
    if (defaultIndex == -1) return null;
    dynamic rtn;
    for (var i = defaultIndex; i < node.cases.length; i++) {
      if (!matched && !node.cases[i].isDefault) continue;
      matched = true;
      try {
        for (final Statement stmt in node.cases[i].body) {
          rtn = stmt.visitBy(this);
        }
      } on ControlFlowBreakException catch (e) {
        if (e.label != null) rethrow;
        return rtn;
      }
    }
    return rtn;
  }

  @override
  visitWith(WithStatement node) {
    final dynamic obj = getValueFromExpression(node.object);
    if (obj is! Map) {
      throw JSException(node.line ?? 1, 'with statement requires an object');
    }
    final dynamicContext = <String, dynamic>{};
    obj.forEach((key, value) {
      dynamicContext[key.toString()] = value;
    });
    final context = SimpleContext(dynamicContext);
    _dynamicContexts.add(context);
    try {
      final rtn = node.body.visitBy(this);
      context.getContextMap().forEach((key, value) {
        obj[key] = value;
      });
      return rtn;
    } finally {
      _dynamicContexts.removeLast();
    }
  }

  @override
  visitLiteral(LiteralExpression node) {
    Context programContext = findProgramContext(node);
    if (node.value is String) {
      Function? getStringFunc = programContext.getContextById('getStringValue');
      if (getStringFunc != null) {
        //this takes care of translating strings into different languages
        return Function.apply(getStringFunc, [node.value]);
      }
    }
    return node.value;
  }

  @override
  visitTemplateLiteral(TemplateLiteral node) {
    final buffer = StringBuffer();
    for (int i = 0; i < node.strings.length; i++) {
      buffer.write(node.strings[i]);
      if (i < node.expressions.length) {
        final value = getValueFromExpression(node.expressions[i]);
        buffer.write(value?.toString() ?? 'null');
      }
    }
    return buffer.toString();
  }

  @override
  visitTaggedTemplate(TaggedTemplateExpression node) {
    dynamic tag;
    dynamic thisArg = getContextForScope(program).getContextMap();

    if (node.tag is MemberExpression) {
      final pattern =
          visitMember(node.tag as MemberExpression, computeAsPattern: true);
      if (pattern == null) return jsUndefined;
      thisArg = pattern.obj;
      tag = InvokableController.methods(pattern.obj)[pattern.property];
      tag ??= InvokableController.getProperty(pattern.obj, pattern.property);
    } else if (node.tag is IndexExpression) {
      final pattern =
          visitIndex(node.tag as IndexExpression, computeAsPattern: true);
      if (pattern == null) return jsUndefined;
      thisArg = pattern.obj;
      tag = InvokableController.getProperty(pattern.obj, pattern.property);
    } else {
      tag = getValueFromExpression(node.tag);
    }

    if (tag == null || identical(tag, jsUndefined)) {
      throw JSException(
          node.line ?? -1, 'Tagged template tag is not callable.');
    }

    final strings = List<dynamic>.from(node.template.strings);
    final values = node.template.expressions
        .map((expression) => getValueFromExpression(expression))
        .toList();
    return _callAnyFunction(tag, [strings, ...values], thisArg);
  }

  @override
  visitSpread(SpreadExpression node) {
    return getValueFromExpression(node.argument);
  }

  @override
  visitArray(ArrayExpression node) {
    List arr = [];
    node.forEach((node) {
      if (node is SpreadExpression) {
        final spreadValue = getValueFromExpression(node.argument);
        if (spreadValue is List) {
          arr.addAll(spreadValue);
        } else {
          throw JSException(node.line ?? 1,
              'Spread in array literals requires a list value.');
        }
      } else {
        arr.add(node.visitBy(this));
      }
    });
    return arr;
  }

  @override
  visitNameExpression(NameExpression node) {
    return node.name.visitBy(this);
  }

  List computeArguments(List<Node> args, {bool resolveNames = false}) {
    List l = [];
    for (Node node in args) {
      if (resolveNames) {
        if (node is Expression) {
          if (node is SpreadExpression) {
            dynamic spreadValue = getValueFromExpression(node.argument);
            if (spreadValue is List) {
              l.addAll(spreadValue);
              continue;
            }
            throw JSException(node.line ?? 1,
                'Spread in function calls requires a list value.');
          }
          dynamic v = getValueFromExpression(node);
          if (v is JavascriptFunction) {
            l.add(v._onCall);
          } else {
            l.add(v);
          }
        } else if (node is Name) {
          l.add(getValue(node));
        }
      } else {
        l.add(node.visitBy(this));
      }
    }
    return l;
  }

  executeMethod(dynamic method, List<Expression> declaredArguments,
      {String? methodName, MethodExecutor? executor, dynamic thisArg}) {
    List<dynamic> arguments =
        computeArguments(declaredArguments, resolveNames: true);
    if (method is JavascriptFunction) {
      return method.callWithThis(arguments, thisArg);
    }
    if (methodName != null && executor != null) {
      return executor.callMethod(methodName, arguments);
    }
    if (method is Function) {
      //functions being called from js to dart
      try {
        if (arguments.length == 0) {
          return Function.apply(method, null);
        } else {
          return Function.apply(method, arguments);
        }
      } catch (_) {
        return Function.apply(method, [arguments, thisArg]);
      }
    } else {
      if (arguments.length == 0) {
        return method();
      } else {
        return method(arguments);
      }
    }
  }

  dynamic _callAnyFunction(dynamic fn, List<dynamic> args, [dynamic thisArg]) {
    if (fn is JavascriptFunction) {
      return fn.callWithThis(args, thisArg);
    }
    if (fn is Function) {
      return Function.apply(fn, args);
    }
    return Function.apply(fn, args);
  }

  JavascriptFunction _functionMethod(dynamic fn, dynamic property) {
    switch (property) {
      case 'call':
        return JavascriptFunction((List<dynamic>? args, [dynamic thisArg]) {
          final params = args ?? [];
          final callThis = params.isNotEmpty ? params.first : null;
          return _callAnyFunction(fn, params.skip(1).toList(), callThis);
        }, 'function call() { [native code] }');
      case 'apply':
        return JavascriptFunction((List<dynamic>? args, [dynamic thisArg]) {
          final params = args ?? [];
          final callThis = params.isNotEmpty ? params.first : null;
          final appliedArgs = params.length > 1 && params[1] is List
              ? List<dynamic>.from(params[1] as List)
              : <dynamic>[];
          return _callAnyFunction(fn, appliedArgs, callThis);
        }, 'function apply() { [native code] }');
      case 'bind':
        return JavascriptFunction((List<dynamic>? args, [dynamic thisArg]) {
          final params = args ?? [];
          final boundThis = params.isNotEmpty ? params.first : null;
          final boundArgs = params.skip(1).toList();
          return JavascriptFunction((List<dynamic>? callArgs, [dynamic _]) {
            return _callAnyFunction(
                fn, [...boundArgs, ...(callArgs ?? [])], boundThis);
          }, 'function bound() { [native code] }');
        }, 'function bind() { [native code] }');
      default:
        throw InvalidPropertyException(
            'Function does not have a gettable property named $property');
    }
  }

  @override
  visitCall(CallExpression node) {
    dynamic val;
    try {
      dynamic method;
      if (node.callee is NameExpression) {
        if (node.isNew) {
          //a new object is being instantiated
          final dynamic _class = getValue((node.callee as NameExpression).name);
          if (_class == null) {
            throw JSException(node.line ?? -1,
                'Cannot instantiate object of class ${(node.callee as NameExpression).name} No definition found for class in code ${getCode(node)}.',
                recovery: 'Check your syntax and try again.');
          }
          if (_class is JavascriptFunction) {
            final Map<String, dynamic> instance = {};
            InvokableController.setPrototype(instance, _class.prototype);
            final dynamic constructed = _class.callWithThis(
                computeArguments(node.arguments, resolveNames: true), instance);
            val = constructed is Map ||
                    constructed is Invokable ||
                    constructed is List
                ? constructed
                : instance;
            return val;
          }
          if (!(_class is Invokable)) {
            throw JSException(node.line ?? -1,
                'Cannot instantiate object of class ${(node.callee as NameExpression).name} Class is not invokable in code ${getCode(node)}.',
                recovery: 'Check your syntax and try again.');
          }
          if (_class.methods()['init'] == null) {
            throw JSException(node.line ?? -1,
                'Cannot instantiate object of class ${(node.callee as NameExpression).name} No init method found for class in code ${getCode(node)}. init method is called to construct an instance. It must take List<parms> as argument.',
                recovery: 'Check your syntax and try again.');
          }
          method = _class.methods()['init'];
        } else {
          method = getValue((node.callee as NameExpression).name);
          if (method == null) {
            if (node.optional) return jsUndefined;
            throw JSException(
                node.line ?? -1, 'No definition found for ${getCode(node)}.',
                recovery: 'Check your syntax and try again.');
          }
        }
        val = executeMethod(method, node.arguments,
            thisArg: getContextForScope(program).getContextMap());
      } else if (node.callee is FunctionExpression) {
        method = visitFunctionExpression(node.callee as FunctionExpression);
        val = executeMethod(method, node.arguments,
            thisArg: getContextForScope(program).getContextMap());
      } else if (node.callee is MemberExpression ||
          node.callee is IndexExpression) {
        PropertyPattern? pattern;
        dynamic method;
        MethodExecutor? methodExecutor;
        String? methodName;
        if (node.callee is MemberExpression) {
          pattern = visitMember(node.callee as MemberExpression,
              computeAsPattern: true);
          if (pattern == null) return jsUndefined;
          if (pattern!.obj is MethodExecutor) {
            methodExecutor = pattern!.obj as MethodExecutor;
            methodName = pattern.property;
          } else if ((pattern.obj is JavascriptFunction ||
                  pattern.obj is Function) &&
              (pattern.property == 'call' ||
                  pattern.property == 'apply' ||
                  pattern.property == 'bind')) {
            method = _functionMethod(pattern.obj, pattern.property);
          } else {
            method = InvokableController.methods(pattern.obj)[pattern.property];
          }
          method ??=
              InvokableController.methods(pattern!.obj)[pattern.property];
          method ??=
              InvokableController.getProperty(pattern.obj, pattern.property);
        } else if (node.callee is IndexExpression) {
          pattern = visitIndex(node.callee as IndexExpression,
              computeAsPattern: true);
          if (pattern == null) return jsUndefined;
          if ((pattern!.obj is JavascriptFunction || pattern.obj is Function) &&
              (pattern.property == 'call' ||
                  pattern.property == 'apply' ||
                  pattern.property == 'bind')) {
            method = _functionMethod(pattern.obj, pattern.property);
          } else {
            method =
                InvokableController.getProperty(pattern.obj, pattern.property);
          }
          //old: method = pattern!.obj.getProperty(pattern.property);
        }
        if (method == null) {
          if (node.optional) return jsUndefined;
          throw JSException(
              node.line ?? -1,
              "cannot compute statement=" +
                  node.toString() +
                  " "
                      "as no method found for property=" +
                  ((pattern != null) ? pattern.property.toString() : ''),
              detailedError: 'Code: ${getCode(node)}');
        }
        try {
          val = executeMethod(method, node.arguments,
              methodName: methodName,
              executor: methodExecutor,
              thisArg: pattern?.obj);
        } on JSException catch (e) {
          rethrow;
        } catch (e) {
          throw JSException(node.line ?? -1,
              'Error while executing method: ${getCode(node)}. Underlying error:${e.toString()}',
              originalError: e);
        }
      }
    } on JSException catch (e) {
      rethrow;
    } on InvalidPropertyException catch (e) {
      throw JSException(node.line ?? 1, '${e.message}. Code: ${getCode(node)}');
    }
    return val;
  }

  dynamic performOperation(
      dynamic left, dynamic right, String operator, int line, String code) {
    // Handle concatenation with strings
    if (operator == '+=' && (left is String || right is String)) {
      return left.toString() + right.toString();
    }

    // For arithmetic and bitwise operations, ensure both operands are numbers
    num leftNum, rightNum;
    try {
      leftNum = num.parse(left.toString());
      rightNum = num.parse(right.toString());
    } catch (e) {
      throw JSException(line,
          "Either '$left' or '$right' cannot be parsed ino a number and number if required for the $operator operation. Relevant Code: $code");
    }
    switch (operator) {
      case '+=':
        return leftNum + rightNum;
      case '-=':
        return leftNum - rightNum;
      case '*=':
        return leftNum * rightNum;
      case '/=':
        return leftNum / rightNum;
      case '%=':
        return leftNum % rightNum;
      case '<<=':
        // Ensure operands are integers for bitwise operations
        return leftNum.toInt() << rightNum.toInt();
      case '>>=':
        return leftNum.toInt() >> rightNum.toInt();
      case '|=':
        return leftNum.toInt() | rightNum.toInt();
      case '^=':
        return leftNum.toInt() ^ rightNum.toInt();
      case '&=':
        return leftNum.toInt() & rightNum.toInt();
      default:
        throw JSException(
            line, "$operator in Code: $code is not yet supported");
    }
  }

  @override
  visitAssignment(AssignmentExpression node) {
    try {
      dynamic val = getValueFromExpression(node.right);
      PropertyPattern? pattern;
      if (node.left is MemberExpression) {
        pattern =
            visitMember(node.left as MemberExpression, computeAsPattern: true);
      } else if (node.left is IndexExpression) {
        pattern =
            visitIndex(node.left as IndexExpression, computeAsPattern: true);
      }
      if (pattern != null) {
        var obj = pattern.obj;
        if (node.operator == '=') {
          InvokableController.setProperty(obj, pattern.property, val);
        } else {
          dynamic left = InvokableController.getProperty(obj, pattern.property);
          dynamic right = val;
          val = performOperation(
              left, right, node.operator!, node.line ?? -1, getCode(node));
          InvokableController.setProperty(obj, pattern.property, val);
        }
      } else if (node.left is Name || node.left is NameExpression) {
        Name n;
        if (node.left is NameExpression) {
          n = (node.left as NameExpression).name;
        } else {
          n = node.left as Name;
        }
        dynamic value = getValue(n);
        if (value == null || node.operator == '=') {
          value = val;
        } else {
          value = performOperation(
              value, val, node.operator!, node.line ?? -1, getCode(node));
        }
        addToContext(n, value);
      } else if (node.operator == '=' &&
          (node.left is ArrayExpression || node.left is ObjectExpression)) {
        _assignPattern(node.left, val, node.line ?? 1);
      }
      return val;
    } on JSException catch (e) {
      rethrow;
    } on InvalidPropertyException catch (e) {
      throw JSException(node.line ?? 1, '${e.message}. Code: ${getCode(node)}');
    }
  }

  @override
  RegExp visitRegexp(RegexpExpression node) {
    if (node.regexp == null) {
      throw ArgumentError("The regex pattern cannot be null.");
    }

    String pattern = node.regexp!;
    int lastIndex = -1;

    // Find the last unescaped slash
    for (int i = pattern.length - 1; i >= 0; i--) {
      if (pattern[i] == '/' && (i == 0 || pattern[i - 1] != '\\')) {
        lastIndex = i;
        break;
      }
    }

    if (lastIndex == -1) {
      throw ArgumentError("Invalid regex pattern: missing ending slash.");
    }

    // Extract the pattern and options
    String regexPattern = (lastIndex > 0)
        ? pattern.substring(1, lastIndex)
        : ''; // Extract pattern without slashes
    String options = (lastIndex < pattern.length - 1)
        ? pattern.substring(lastIndex + 1)
        : ''; // Extract options after the last slash

    bool allMatches = false;
    bool dotAll = false;
    bool multiline = false;
    bool ignoreCase = false;
    bool unicode = false;

    // Set the options
    if (options.contains('i')) {
      ignoreCase = true;
    }
    if (options.contains('g')) {
      allMatches = true;
    }
    if (options.contains('m')) {
      multiline = true;
    }
    if (options.contains('s')) {
      dotAll = true;
    }
    if (options.contains('u')) {
      unicode = true;
    }

    // Create and return the Dart RegExp
    RegExp regex = RegExp(
      regexPattern,
      multiLine: multiline,
      caseSensitive: !ignoreCase,
      dotAll: dotAll,
      unicode: unicode,
    );
    if (allMatches) {
      //see regex_ext.dart for more details
      regex.global = true;
    }
    return regex;
  }

  @override
  visitIndex(IndexExpression node, {bool computeAsPattern = false}) {
    dynamic val;
    try {
      if (node.optional) {
        final obj = getValueFromExpression(node.object);
        if (_isNullish(obj)) return computeAsPattern ? null : jsUndefined;
        final property = getValueFromExpression(node.property);
        return _getObjectPropertyValue(obj, property,
            computeAsPattern: computeAsPattern);
      }
      val = visitObjectPropertyExpression(
          node.object, getValueFromExpression(node.property),
          computeAsPattern: computeAsPattern);
    } on InvalidPropertyException {
      //ignore since obj['prop'] is fine even when prop does not exist. We just return null in that case
    }
    return val;
  }

  visitObjectPropertyExpression(Expression object, dynamic property,
      {bool computeAsPattern = false}) {
    dynamic obj = getValueFromExpression(object);
    if (_isNullish(obj)) {
      throw InvalidPropertyException(
          '${getCode(object)} is undefined. Check your syntax.');
    }
    return _getObjectPropertyValue(obj, property,
        computeAsPattern: computeAsPattern);
  }

  dynamic _getObjectPropertyValue(dynamic obj, dynamic property,
      {bool computeAsPattern = false}) {
    if (obj is JavascriptFunction && property == 'prototype') {
      return computeAsPattern ? PropertyPattern(obj, property) : obj.prototype;
    }
    if ((obj is JavascriptFunction || obj is Function) &&
        (property == 'call' || property == 'apply' || property == 'bind')) {
      return computeAsPattern
          ? PropertyPattern(obj, property)
          : _functionMethod(obj, property);
    }
    return computeAsPattern
        ? PropertyPattern(obj, property)
        : InvokableController.getProperty(obj, property);
  }

  @override
  visitMember(MemberExpression node, {bool computeAsPattern = false}) {
    if (node.optional) {
      final obj = getValueFromExpression(node.object);
      if (_isNullish(obj)) return computeAsPattern ? null : jsUndefined;
      return _getObjectPropertyValue(obj, node.property.value,
          computeAsPattern: computeAsPattern);
    }
    return visitObjectPropertyExpression(node.object, node.property.value,
        computeAsPattern: computeAsPattern);
  }

  @override
  visitName(Name node) {
    return node;
  }

  @override
  visitThrow(ThrowStatement node) {
    dynamic argumentValue = getValueFromExpression(node.argument);
    if (argumentValue is JSCustomException) {
      throw argumentValue;
    } else {
      throw JSCustomException(argumentValue);
    }
  }

  @override
  visitTry(TryStatement node) {
    if (node.handler == null && node.finalizer == null) {
      throw JSException(node.line ?? 0,
          "Syntax Error: a try block must have a corresponding catch or finally");
    }
    try {
      node.block.visitBy(this);
    } on ControlFlowReturnException {
      rethrow; // Re-throw control flow exceptions
    } on ControlFlowBreakException {
      rethrow;
    } on ControlFlowContinueException {
      rethrow;
    } catch (e) {
      if (node.handler != null) {
        dynamic exceptionValue = getExceptionValue(e);
        Map<String, dynamic> ctxMap = {};
        // If it's an Error object (created via new Error()), keep it as JSCustomException
        // If it's a wrapped primitive throw, unwrap it to the raw value
        if (e is JSCustomException && e.isErrorObject) {
          ctxMap[node.handler!.param.value] = e;
        } else {
          dynamic exceptionValue = getExceptionValue(e);
          ctxMap[node.handler!.param.value] = exceptionValue;
        }
        Context context = SimpleContext(ctxMap);
        // Clone the interpreter with this new context
        JSInterpreter interpreter =
            cloneForContext(node.handler!, context, true);
        interpreter.visitCatchClause(node.handler!);
      }
    } finally {
      if (node.finalizer != null) {
        node.finalizer!.visitBy(this);
      }
    }
  }

  @override
  visitCatchClause(CatchClause node) {
    node.body.visitBy(this);
  }

// Helper method to extract exception value
  dynamic getExceptionValue(dynamic exception) {
    if (exception is JSCustomException) {
      return exception.value;
    } else if (exception is JSException) {
      return exception.message;
    } else {
      return exception.toString();
    }
  }

  dynamic getValueFromExpression(Expression exp) {
    return getValueFromNode(exp);
  }

  noSuchMethod(Invocation invocation) {
    if (!invocation.isMethod || invocation.namedArguments.isNotEmpty)
      super.noSuchMethod(invocation);
    invocation.positionalArguments;
    return null;
  }
}

enum BinaryOperator {
  equals,
  strictEquals,
  lt,
  gt,
  ltEquals,
  gtEquals,
  notequals,
  minus,
  plus,
  multiply,
  divide,
  inop,
  instaneof
}

enum AssignmentOperator { equal, plusEqual, minusEqual }

enum LogicalOperator { or, and, not }

enum UnaryOperator { minus, plus, not, typeof, voidop }

enum VariableDeclarationKind { constant, let, variable }

class ControlFlowReturnException extends JSException {
  dynamic returnValue;
  ControlFlowReturnException(int line, String message, this.returnValue)
      : super(line, message);
}

class ControlFlowBreakException extends JSException {
  final String? label;
  ControlFlowBreakException(int line, String message, [this.label])
      : super(line, message);
}

class ControlFlowContinueException extends JSException {
  final String? label;
  ControlFlowContinueException(int line, String message, [this.label])
      : super(line, message);
}

/// Represents a key-value pattern resolved from a property access.
class PropertyPattern {
  /// The target object of the property.
  Object obj;
  /// The key/property name.
  dynamic property;
  /// Creates a property pattern with the given object and property.
  PropertyPattern(this.obj, this.property);
}

typedef OnCall = dynamic Function(List arguments, [dynamic thisArg]);

class JavascriptFunction {
  JavascriptFunction(this._onCall, this.functionCode)
      : prototype = <String, dynamic>{};

  final OnCall _onCall;
  final String functionCode;
  final Map<String, dynamic> prototype;

  dynamic callWithThis(List arguments, [dynamic thisArg]) =>
      _onCall(arguments, thisArg);

  noSuchMethod(Invocation invocation) {
    if (!invocation.isMethod || invocation.namedArguments.isNotEmpty)
      super.noSuchMethod(invocation);
    final arguments = invocation.positionalArguments;
    if (arguments.length > 0) {
      return _onCall(arguments[0] is List ? arguments[0] : arguments);
    } else {
      return _onCall(arguments);
    }
  }
}
