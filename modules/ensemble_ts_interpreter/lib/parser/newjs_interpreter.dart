import 'dart:convert';
import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/context.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:jsparser/jsparser.dart';

class Bindings extends RecursiveVisitor<dynamic> {
  List<String> bindings = [];
  List<String> resolve(Program program) {
    visit(program);
    return bindings;
  }
  String convertToString(List<String> list) {
    String rtn = '';
    list.forEach((element) {rtn += '.'+element;});
    return rtn;
  }
  @override
  visitVariableDeclarator(VariableDeclarator node) {
    String name = visitName(node.name);
    bindings.add(name);
    return name;
  }
  @override
  visitBinary(BinaryExpression node) {
    dynamic left = node.left.visitBy(this);
    dynamic right = node.right.visitBy(this);
    if ( left is String ) {
      bindings.add(left);
    }
    if ( right is String ) {
      bindings.add(right);
    }
    return bindings;
  }
  @override
  visitMember(MemberExpression node) {
    dynamic obj = node.object.visitBy(this);
    if ( obj != null ) {
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
    if ( node.arguments != null ) {
      for ( Expression exp in node.arguments ) {
        dynamic rtn = exp.visitBy(this);
        if ( rtn is String ) {
          bindings.add(rtn);
        }
      }
    }
  }
  @override
  visitAssignment(AssignmentExpression node) {
    if ( node.right != null ) {
      dynamic rtn = node.right.visitBy(this);
      if ( rtn is String ) {
        bindings.add(rtn);
      }
    }
  }
  @override
  visitExpressionStatement(ExpressionStatement node) {
    dynamic rtn = node.expression.visitBy(this);
    if ( rtn is String ) {
      bindings.add(rtn);
    }
  }
  @override
  visitIndex(IndexExpression node, {bool computeAsPattern=false}) {
    dynamic obj = node.object.visitBy(this);
    dynamic prop;
    if ( node.property is LiteralExpression ) {
      prop = (node.property as LiteralExpression).value;
    }
    if ( node.property is NameExpression ) {
      if ( obj is String ) {
        bindings.add(obj);
        bindings.add(node.property.visitBy(this) as String); //we add the name to the bindings as well
      }
    } else if ( obj is String ) {
      if ( prop is num ) {
        return obj + '['+prop.toString()+']';
      } else if ( prop is String ) {
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
class JSInterpreter extends RecursiveVisitor<dynamic> {

  late String code;
  late Program program;
  Map<Scope,Context> contexts= {};
  @override
  defaultNode(Node node) {
    dynamic rtn;
    node.forEach((node)=> rtn = visit(node));
    return rtn;
  }

  String getCode(Node node) {
    String rtn = '';
    if ( node.start != null && node.end != null ) {
      rtn = code.substring(node.start!,node.end!);
    }
    return rtn;
  }
  JSInterpreter(this.code, this.program, Context programContext) {
    contexts[program] = programContext;
    InvokableController.addGlobals(programContext.getContextMap());
  }
  static const String parsingErrorAppendage = "Only ES5 is supported. "
      "Key words such as let, const, operators such as -> and templated strings are not yet supported. "
      "Here's a full list of features that are only available in ES6 and are therefore NOT supported in Ensemble at this time. https://www.w3schools.com/js/js_es6.asp";
  JSInterpreter.fromCode(String code, Context programContext): this(code,parseCode(code),programContext);
  static Program parseCode(String code) {
    if ( code.isEmpty ) {
      throw JSException(1,"Empty string is being passed as javascript code to parse. Please check your javascript code and fix it");
    }
    try {
      return parsejs(code);
    } on ParseError catch(e) {
      throw JSException(e.line??1, "Parsing error Occurred while parsing javascript code block. "
          "Error Message: ${e.message}",detailedError: 'Code: $code . FYI: $parsingErrorAppendage');
    } catch (error) {
      throw JSException(1, "Parsing error Occurred while parsing javascript code block. "
          "Error Message: ${error.toString()}",detailedError: 'Code: $code . FYI: $parsingErrorAppendage');
    }
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
      throw JSException(1,'Cannot convert to JSON: $value');
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
  JSInterpreter cloneForContext(Scope scope,Context ctx,bool inheritContexts) {
    JSInterpreter i = JSInterpreter(this.code, this.program,getContextForScope(this.program));
    if ( inheritContexts ) {
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
        throw JSException(scope.line??1, 'Scope does not have an environment. Scope:${getCode(scope)}');
      if (scope.environment!.contains(name)) return scope;
      scope = enclosingScope(scope.parent!);
    }
    return scope;
  }
  Context getContextForScope(Scope scope) {
    return contexts[scope]!;
  }
  void addToThisContext(Name node, dynamic value) {
    Context ctx = getContextForScope(node.scope!);
    ctx.addToThisContext(node.value,value);
  }
  void addToContext(Name node, dynamic value) {
    Context ctx = getContextForScope(node.scope!);
    ctx.addDataContextById(node.value,value);
  }
  // dynamic removeFromContext(Name node) {
  //   Map m = getContextForScope(node.scope!);
  //   return m.remove(node.value);
  // }
  dynamic getValueFromNode(Node node) {
    dynamic value = node.visitBy(this);
    if ( value is List ) {
      List<dynamic> arr = [];
      value.forEach((element) {
        if ( element is Node ) {
          arr.add(getValueFromNode(element));
        } else {
          arr.add(element);
        }
      });
      //we must not assign the array to a new array as it will be disconnected from the original.
      //Take the nested array case when you are changing value within the nested array.
      //see 2darrayissue in unit tests
      //value = arr;
      for ( int i=0;i<value.length;i++ ) {
        value[i] = arr[i];
      }
    } else if ( value is Name ) {
      value = getValue(value);
    } else if ( node is ThisExpression ) {
      value = getValueFromString(value);
    }
    return value;
  }
  dynamic getValueFromString(String name) {
    Context ctx = getContextForScope(program);
    return ctx.getContextById(name);
  }
  dynamic getValue(Name node) {
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
        for ( int i=program.body.length-1;i>=0;i-- ) {
          Statement stmt = program.body[i];
          if ( stmt is FunctionDeclaration ) {
            stmt.visitBy(this);
          }
        }
        rtn = visit(program);
        if (rtn is Name) {
          rtn = getValue(rtn);
        }
      }
    } on ControlFlowReturnException catch(e) {
      rtn = e.returnValue;
    } on JSException catch(e) {
      rethrow;
    } catch (e) {
      throw JSException(1, e.toString(), detailedError: 'Code: $code', originalError: e);
    }
    return rtn;
  }
  dynamic executeConditional(Expression testExp,Node consequent,Node? alternate) {
    dynamic condition = getValueFromExpression(testExp);
    bool test = toBoolean(condition);
    dynamic rtn;
    if ( test ) {
      rtn = consequent.visitBy(this);
    } else {
      if ( alternate != null ) {
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
  visitConditional(ConditionalExpression node) {
    return executeConditional(node.condition,node.then,node.otherwise);
  }
  @override
  visitIf(IfStatement node) {
    return executeConditional(node.condition,node.then,node.otherwise);
  }
  @override
  visitProperty(Property node) {
    String key;
    if ( node.key is Name ) {
      key = (node.key as Name).value;
    } else if ( node.key is LiteralExpression ) {
      key = (node.key as LiteralExpression).value;
    } else {
      throw JSException(node.line ?? -1,
          'Property of object ${node.toString()} is not supported. Only Name or LiteralExpression are supported.');
    }
    return {'key':key,'value':getValueFromNode(node.value)};
  }
  @override
  visitObject(ObjectExpression node) {
    Map obj = {};
    for ( Property property in node.properties ) {
      Map prop = visitProperty(property);
      obj[prop['key']] = prop['value'];
    }
    return obj;
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
    dynamic val = getValueFromNode(node.argument);
    switch(node.operator) {
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
        val = _jsTypeOf(val);
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
    if (val == null) return 'object'; // In JavaScript, typeof null is 'object'
    if (val is num) return 'number';
    if (val is String) return 'string';
    if (val is bool) return 'boolean';
    // Add other types as necessary, like 'function' for callable objects
    return 'object';
  }

  bool toBoolean(dynamic val) {
    if (val == null || val == 0 || val == false || val == '' || val == 'false') {
      return false;
    }
    if (val is num && val.isNaN) {
      return false;
    }
    return true;
  }

  num toNumber(dynamic val) {
    if (val == null) {
      return 0;
    } else if (val is num) {
      return val;
    } else if (val is String) {
      return num.tryParse(val) ?? double.nan;
    }
    // Add additional type conversions as necessary
    return 0;
  }

  @override
  visitUpdateExpression(UpdateExpression node) {
    dynamic val = getValueFromExpression(node.argument!);
    ObjectPattern? pattern;
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
      pattern =
          visitMember(node.argument as MemberExpression, computeAsPattern: true);
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
    if ( node.isPrefix ) {
      return number;
    }
    return originalNumber;
  }
  @override
  visitFunctionDeclaration(FunctionDeclaration node) {
    JavascriptFunction? func = getValue(node.function.name!);
    if ( func == null ) {
      addToThisContext(node.function.name!, visitFunctionNode(node.function));
    }
    return func;
  }
  @override
  visitFunctionNode(FunctionNode node, {bool? inheritContext}) {
    final List<dynamic> args = computeArguments(node.params);
    return JavascriptFunction((List<dynamic>? _params) {
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
          // Use the value from params if available, otherwise use null
          ctx[node.params[i].value] = i < params.length ? params[i] : null;
        }
      }
      Context context = SimpleContext(ctx);
      JSInterpreter i = cloneForContext(node,context,inheritContext??false);
      dynamic rtn;
      try {
        if (node.body != null) {
          rtn = node.body.visitBy(i);
        }
      } on ControlFlowReturnException catch(e) {
        rtn = e.returnValue;
      }
      if ( rtn is Node ) {
        rtn = i.getValueFromNode(rtn);
      }
      return rtn;
    },code.substring(node.start!,node.end));
  }
  @override
  visitFunctionExpression(FunctionExpression node) {
    return visitFunctionNode(node.function,inheritContext:true);
  }
  @override
  visitArrowFunctionNode(ArrowFunctionNode node) {
    final List<dynamic> args = computeArguments(node.params);
    return JavascriptFunction((List<dynamic>? _params) {
      List<dynamic> params = _params ?? [];
      Map<String, dynamic> ctx = {};
      if (node.params != null) {
        for (int i = 0; i < node.params.length; i++) {
          // Use the value from params if available, otherwise use null
          ctx[node.params[i].value] = i < params.length ? params[i] : null;
        }
      }
      Context context = SimpleContext(ctx);
      JSInterpreter i = cloneForContext(node,context,true);
      dynamic rtn;
      try {
        if (node.body != null) {
          rtn = node.body.visitBy(i);
        }
      } on ControlFlowReturnException catch(e) {
        rtn = e.returnValue;
      }
      if ( rtn is Node ) {
        rtn = i.getValueFromNode(rtn);
      }
      return rtn;
    },code.substring(node.start!,node.end));
  }
  @override
  visitBlock(BlockStatement node) {
    dynamic rtn;
    for ( Node stmt in node.body ) {
      rtn = stmt.visitBy(this);
    }
    return rtn;
  }
  @override
  visitVariableDeclarator(VariableDeclarator node) {
    Name name = node.name;
    dynamic value;
    if ( node.init != null ) {
      value = getValueFromExpression(node.init!);
    }
    addToThisContext(name,value);
    return name;
  }
  @override
  visitBinary(BinaryExpression node) {
    try {
      dynamic left = getValueFromExpression(node.left);
      //special check in case of || to avoid evaluating the right expression
      //https://github.com/EnsembleUI/ensemble/issues/574
      if (node.operator == '||') {
        if (left != false && left != null && left != 0 && left != '' &&
            !(left is num && left.isNaN)) {
          return left;
        } else {
          return getValueFromExpression(node.right);
        }
      } else if (node.operator == '&&') {
        if (left == false || left == null || left == 0 || left == '' ||
            (left is num && left.isNaN)) {
          return left;
        } else {
          return getValueFromExpression(node.right);
        }
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
          rtn = left == right;
          break;
        case '===':
          rtn = left == right;
          break;
        case '!=':
          rtn = left != right;
          break;
        case '!==':
          rtn = left != right;
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
        case '&':
          rtn = left & right;
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
    } on InvalidPropertyException catch(e) {
      throw JSException(node.line??1, '${e.message}. Code: ${getCode(node)}');
    }
  }
  @override
  visitBreak(BreakStatement node) {
    throw ControlFlowBreakException(node.line??1,'');
  }
  @override
  visitContinue(ContinueStatement node) {
    throw ControlFlowContinueException(node.line??1,'');
  }
  @override
  visitFor(ForStatement node) {
    if ( node.init != null ) {
      node.init!.visitBy(this);
    }
    while ( node.condition != null && getValueFromNode(node.condition!) ) {
      try {
        node.body.visitBy(this);
        if ( node.update != null ) {
          node.update!.visitBy(this);
        }
      } on ControlFlowBreakException catch(e) {
        break;
      } on ControlFlowContinueException catch(e) {
        continue;
      }
    }
  }
  @override
  visitWhile(WhileStatement node) {
    while ( getValueFromNode(node.condition) ) {
      try {
        node.body.visitBy(this);
      } on ControlFlowBreakException catch(e) {
        break;
      } on ControlFlowContinueException catch(e) {
        continue;
      }
    }
  }
  @override
  visitDoWhile(DoWhileStatement node) {
    do {
      try {
        node.body.visitBy(this);
      } on ControlFlowBreakException catch(e) {
        break;
      } on ControlFlowContinueException catch(e) {
        continue;
      }
    } while ( getValueFromNode(node.condition) ) ;
  }
  @override
  visitForIn(ForInStatement node) {
    dynamic right = getValueFromNode(node.right);
    dynamic left = node.left.visitBy(this);
    if ( right is! Map ) {
      throw JSException(node.line??1,'for...in is only allowed for js objects or maps. $right is not a map', detailedError:'Code: ${getCode(node)}');
    }
    if ( left is! Name ) {
      throw JSException(node.line??1,'left side in the for...in expression must be a name node. $node.left is not name', detailedError:'Code: ${getCode(node)}');
    }
    Map map = right;
    for ( dynamic key in map.keys ) {
      addToContext(left, key);
      try {
        node.body.visitBy(this);
      } on ControlFlowBreakException catch(e) {
        break;
      } on ControlFlowContinueException catch(e) {
        continue;
      }
    }
    //removeFromContext(left);
  }
  @override
  visitLiteral(LiteralExpression node) {
    Context programContext = findProgramContext(node);
    if ( node.value is String ) {
      Function? getStringFunc = programContext.getContextById('getStringValue');
      if (getStringFunc != null) {
        //this takes care of translating strings into different languages
        return Function.apply(getStringFunc, [node.value]);
      }
    }
    return node.value;
  }
  @override
  visitArray(ArrayExpression node) {
    List arr = [];
    node.forEach((node) {
      arr.add(node.visitBy(this));
    });
    return arr;
  }

  @override
  visitNameExpression(NameExpression node) {
    return node.name.visitBy(this);
  }
  List computeArguments(List<Node> args,{bool resolveNames=false}) {
    List l = [];
    for ( Node node in args ) {
      if ( resolveNames ) {
        if ( node is Expression ) {
          dynamic v = getValueFromExpression(node);
          if ( v is JavascriptFunction ) {
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
      {String? methodName, MethodExecutor? executor}) {
    List<dynamic> arguments =
        computeArguments(declaredArguments, resolveNames: true);
    if (methodName != null && executor != null) {
      return executor.callMethod(methodName, arguments);
    }
    if (method is Function) {
      //functions being called from js to dart
      if (arguments.length == 0) {
        return Function.apply(method, null);
      } else {
        return Function.apply(method, arguments);
      }
    } else {
      if (arguments.length == 0) {
        return method();
      } else {
        return method(arguments);
      }
    }
  }
  @override
  visitCall(CallExpression node) {
    dynamic val;
    try {
      dynamic method;
      if (node.callee is NameExpression) {
        if ( node.isNew ) {
          //a new object is being instantiated
          final dynamic _class = getValue((node.callee as NameExpression).name);
          if ( _class == null ) {
            throw JSException(node.line ?? -1,
                'Cannot instantiate object of class ${(node.callee as NameExpression).name} No definition found for class in code ${getCode(node)}.',
                recovery: 'Check your syntax and try again.');
          }
          if ( !( _class is Invokable) ) {
            throw JSException(node.line ?? -1,
                'Cannot instantiate object of class ${(node.callee as NameExpression).name} Class is not invokable in code ${getCode(node)}.',
                recovery: 'Check your syntax and try again.');
          }
          if ( _class.methods()['init'] == null ) {
            throw JSException(node.line ?? -1,
                'Cannot instantiate object of class ${(node.callee as NameExpression).name} No init method found for class in code ${getCode(node)}. init method is called to construct an instance. It must take List<parms> as argument.',
                recovery: 'Check your syntax and try again.');
          }
          method = _class.methods()['init'];
        } else {
          method = getValue((node.callee as NameExpression).name);
          if (method == null) {
            throw JSException(
                node.line ?? -1, 'No definition found for ${getCode(node)}.',
                recovery: 'Check your syntax and try again.');
          }
        }
        val = executeMethod(method, node.arguments);
      } else
      if (node.callee is MemberExpression || node.callee is IndexExpression) {
        ObjectPattern? pattern;
        dynamic method;
        MethodExecutor? methodExecutor;
        String? methodName;
        if (node.callee is MemberExpression) {
          pattern = visitMember(node.callee as MemberExpression,
              computeAsPattern: true);
          if (pattern!.obj is MethodExecutor) {
            methodExecutor = pattern!.obj as MethodExecutor;
            methodName = pattern.property;
          } else {
            method = InvokableController.methods(pattern.obj)[pattern.property];
          }
          method = InvokableController.methods(pattern!.obj)[pattern.property];
        } else if (node.callee is IndexExpression) {
          pattern = visitIndex(
              node.callee as IndexExpression, computeAsPattern: true);
          method =
              InvokableController.getProperty(pattern!.obj, pattern.property);
          //old: method = pattern!.obj.getProperty(pattern.property);
        }
        if (method == null) {
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
              methodName: methodName, executor: methodExecutor);
        } on JSException catch (e) {
          rethrow;
        } catch (e) {
          throw JSException(
              node.line ?? -1,
              'Error while executing method: ${getCode(node)}. Underlying error:${e.toString()}',
              originalError: e);
        }
      }
    } on JSException catch (e) {
      rethrow;
    } on InvalidPropertyException catch(e) {
      throw JSException(node.line??1, '${e.message}. Code: ${getCode(node)}');
    }
    return val;
  }
  dynamic performOperation(dynamic left, dynamic right, String operator, int line, String code) {
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
      throw JSException(line,"Either '$left' or '$right' cannot be parsed ino a number and number if required for the $operator operation. Relevant Code: $code");
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
        throw JSException(line,
            "$operator in Code: $code is not yet supported");
    }
  }
  @override
  visitAssignment(AssignmentExpression node) {
    try {
      dynamic val = getValueFromExpression(node.right);
      ObjectPattern? pattern;
      if (node.left is MemberExpression) {
        pattern =
            visitMember(node.left as MemberExpression, computeAsPattern: true);
      } else if (node.left is IndexExpression) {
        pattern =
            visitIndex(node.left as IndexExpression, computeAsPattern: true);
      }
      if (pattern != null) {
        var obj = pattern.obj;
        if ( node.operator == '=' ) {
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
        if ( value == null || node.operator == '=') {
          value = val;
        } else {
          value = performOperation(
              value, val, node.operator!, node.line ?? -1, getCode(node));
        }
        addToContext(n, value);
      }
    } on JSException catch (e) {
      rethrow;
    } on InvalidPropertyException catch(e) {
      throw JSException(node.line??1, '${e.message}. Code: ${getCode(node)}');
    }
  }
  @override
  visitRegexp(RegexpExpression node) {
    bool allMatches = false, dotAll = false, multiline = false, ignoreCase = false,unicode = false;

    int index = node.regexp!.lastIndexOf('/');
    if ( index != -1 ) {
      String options = node.regexp!.substring(index);
      if ( options.contains('i') ) {
        ignoreCase = true;
      }
      if ( options.contains('g') ) {
        allMatches = true;
      }
      if ( options.contains('m') ) {
        multiline = true;
      }
      if ( options.contains('s') ) {
        dotAll = true;
      }
      if ( options.contains('u') ) {
        unicode = true;
      }
    }
    return RegExp(node.regexp!.substring(0,index).replaceAll('/', ''),
        multiLine: multiline,
        caseSensitive: !ignoreCase,
        dotAll: dotAll,
        unicode: unicode
    );
  }



  @override
  visitIndex(IndexExpression node, {bool computeAsPattern=false}) {
    dynamic val;
    try {
      val = visitObjectPropertyExpression(
          node.object, getValueFromExpression(node.property),
          computeAsPattern: computeAsPattern);
    } on InvalidPropertyException catch(e) {
      //ignore since obj['prop'] is fine even when prop does not exist. We just return null in that case
    }
    return val;
  }

  visitObjectPropertyExpression(Expression object, dynamic property, {bool computeAsPattern=false}) {
    dynamic obj = getValueFromExpression(object);
    dynamic val;
    if ( obj == null ) {
      throw InvalidPropertyException('${getCode(object)} is undefined. Check your syntax.');
    }
    if ( computeAsPattern ) {
      val = ObjectPattern(obj, property);
    } else {
      val = InvokableController.getProperty(obj, property);
    }
    return val;
  }
  @override
  visitMember(MemberExpression node, {bool computeAsPattern=false}) {
    return visitObjectPropertyExpression(node.object,node.property.value,computeAsPattern: computeAsPattern);
  }
  @override
  visitName(Name node) {
    return node;
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
  equals,strictEquals,lt,gt,ltEquals,gtEquals,notequals,minus,plus,multiply,divide,inop,instaneof
}
enum AssignmentOperator {
  equal,plusEqual,minusEqual
}
enum LogicalOperator {
  or,and,not
}
enum UnaryOperator {
  minus,plus,not,typeof,voidop
}
enum VariableDeclarationKind {
  constant,let,variable
}
class ControlFlowReturnException extends JSException {
  dynamic returnValue;
  ControlFlowReturnException(int line, String message,this.returnValue): super(line,message);
}
class ControlFlowBreakException extends JSException {
  ControlFlowBreakException(int line, String message):super(line,message);
}
class ControlFlowContinueException extends JSException {
  ControlFlowContinueException(int line, String message):super(line,message);
}
class ObjectPattern {
  Object obj;
  dynamic property;
  ObjectPattern(this.obj,this.property);
}
typedef OnCall = dynamic Function(List arguments);
class JavascriptFunction {
  JavascriptFunction(this._onCall,this.functionCode);

  final OnCall _onCall;
  final String functionCode;

  noSuchMethod(Invocation invocation) {
    if (!invocation.isMethod || invocation.namedArguments.isNotEmpty)
      super.noSuchMethod(invocation);
    final arguments = invocation.positionalArguments;
    if ( arguments.length > 0 ) {
      return _onCall(arguments[0]);
    } else {
      return _onCall(arguments);
    }
  }
}
