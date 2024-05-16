library ast_json;

import 'package:jsparser/src/ast.dart';

/// Converts an AST to a JSON object matching the AST structure emitted by the Esprima parser.
/// This is for testing purposes, so the output can be compared against another well-tested parser.
class Ast2Json extends Visitor<Object?> {
  bool ranges;
  bool lines;

  Ast2Json({this.ranges: false, this.lines: false});

  // NOTE: The order in which properties are mentioned is significant, since properties
  //       must be mentioned in the same order for our JSON comparator to work.

  List<Object?> list(List<Node?> nodes) => nodes.map(visit).toList();

  visit(Node? node) {
    if (node == null) return null;
    Map? json = node.visitBy(this) as Map?;
    if (ranges) {
      json!['range'] = [node.start, node.end];
    }
    if (lines) {
      json!['line'] = node.line;
    }
    return json;
  }

  visitPrograms(Programs node) => throw 'Can only JSONify one program';

  visitFunctionNode(FunctionNode node) => {
        'type': 'FunctionExpression',
        'id': visit(node.name),
        'params': list(node.params),
        'defaults': <Object>[],
        'body': visit(node.body),
        'rest': null,
        'generator': false,
        'expression': false
      };

  visitProgram(Program node) => {'type': 'Program', 'body': list(node.body)};

  visitName(Name node) => {'type': 'Identifier', 'name': node.value};

  visitEmptyStatement(EmptyStatement node) => {
        'type': 'EmptyStatement',
      };

  visitBlock(BlockStatement node) =>
      {'type': 'BlockStatement', 'body': list(node.body)};

  visitExpressionStatement(ExpressionStatement node) =>
      {'type': 'ExpressionStatement', 'expression': visit(node.expression)};

  visitIf(IfStatement node) => {
        'type': 'IfStatement',
        'test': visit(node.condition),
        'consequent': visit(node.then),
        'alternate': visit(node.otherwise)
      };

  visitLabeledStatement(LabeledStatement node) => {
        'type': 'LabeledStatement',
        'label': visit(node.label),
        'body': visit(node.body)
      };

  visitBreak(BreakStatement node) =>
      {'type': 'BreakStatement', 'label': visit(node.label)};

  visitContinue(ContinueStatement node) =>
      {'type': 'ContinueStatement', 'label': visit(node.label)};

  visitWith(WithStatement node) => {
        'type': 'WithStatement',
        'object': visit(node.object),
        'body': visit(node.body)
      };

  visitSwitch(SwitchStatement node) => {
        'type': 'SwitchStatement',
        'discriminant': visit(node.argument),
        'cases': list(node.cases)
      };

  visitSwitchCase(SwitchCase node) => {
        'type': 'SwitchCase',
        'test': visit(node.expression),
        'consequent': list(node.body)
      };

  visitReturn(ReturnStatement node) =>
      {'type': 'ReturnStatement', 'argument': visit(node.argument)};

  visitThrow(ThrowStatement node) =>
      {'type': 'ThrowStatement', 'argument': visit(node.argument)};

  visitTry(TryStatement node) => {
        'type': 'TryStatement',
        'block': visit(node.block),
        'guardedHandlers': <Object>[],
        'handlers': node.handler == null ? <Object>[] : [visit(node.handler)],
        'finalizer': visit(node.finalizer)
      };

  visitCatchClause(CatchClause node) => {
        'type': 'CatchClause',
        'param': visit(node.param),
        'body': visit(node.body)
      };

  visitWhile(WhileStatement node) => {
        'type': 'WhileStatement',
        'test': visit(node.condition),
        'body': visit(node.body)
      };

  visitDoWhile(DoWhileStatement node) => {
        'type': 'DoWhileStatement',
        'body': visit(node.body),
        'test': visit(node.condition)
      };

  visitFor(ForStatement node) => {
        'type': 'ForStatement',
        'init': visit(node.init),
        'test': visit(node.condition),
        'update': visit(node.update),
        'body': visit(node.body)
      };

  visitForIn(ForInStatement node) => {
        'type': 'ForInStatement',
        'left': visit(node.left),
        'right': visit(node.right),
        'body': visit(node.body),
        'each': false
      };

  visitFunctionDeclaration(FunctionDeclaration node) => {
        'type': 'FunctionDeclaration',
        'id': visit(node.function.name),
        'params': list(node.function.params),
        'defaults': <Object>[],
        'body': visit(node.function.body),
        'rest': null,
        'generator': false,
        'expression': false
      };

  visitVariableDeclaration(VariableDeclaration node) => {
        'type': 'VariableDeclaration',
        'declarations': list(node.declarations),
        'kind': 'var'
      };

  visitVariableDeclarator(VariableDeclarator node) => {
        'type': 'VariableDeclarator',
        'id': visit(node.name),
        'init': visit(node.init)
      };

  visitDebugger(DebuggerStatement node) => {'type': 'DebuggerStatement'};

  visitThis(ThisExpression node) => {'type': 'ThisExpression'};

  visitArray(ArrayExpression node) =>
      {'type': 'ArrayExpression', 'elements': list(node.expressions)};

  visitObject(ObjectExpression node) =>
      {'type': 'ObjectExpression', 'properties': list(node.properties)};

  visitProperty(Property node) => {
        'type': 'Property',
        'key': visit(node.key),
        'value': visit(node.value),
        'kind': node.kind
      };

  visitFunctionExpression(FunctionExpression node) => visit(node.function);

  visitSequence(SequenceExpression node) =>
      {'type': 'SequenceExpression', 'expressions': list(node.expressions)};

  visitUnary(UnaryExpression node) => {
        'type': 'UnaryExpression',
        'operator': node.operator,
        'argument': visit(node.argument),
        'prefix': true
      };

  visitBinary(BinaryExpression node) => {
        'type': (node.operator == '&&' || node.operator == '||')
            ? 'LogicalExpression'
            : 'BinaryExpression',
        'operator': node.operator,
        'left': visit(node.left),
        'right': visit(node.right)
      };

  visitAssignment(AssignmentExpression node) => {
        'type': 'AssignmentExpression',
        'operator': node.operator,
        'left': visit(node.left),
        'right': visit(node.right)
      };

  visitUpdateExpression(UpdateExpression node) => {
        'type': 'UpdateExpression',
        'operator': node.operator,
        'argument': visit(node.argument),
        'prefix': node.isPrefix
      };

  visitConditional(ConditionalExpression node) => {
        'type': 'ConditionalExpression',
        'test': visit(node.condition),
        'consequent': visit(node.then),
        'alternate': visit(node.otherwise)
      };

  visitCall(CallExpression node) => {
        'type': node.isNew ? 'NewExpression' : 'CallExpression',
        'callee': visit(node.callee),
        'arguments': list(node.arguments)
      };

  visitMember(MemberExpression node) => {
        'type': 'MemberExpression',
        'computed': false,
        'object': visit(node.object),
        'property': visit(node.property),
      };

  visitIndex(IndexExpression node) => {
        'type': 'MemberExpression',
        'computed': true,
        'object': visit(node.object),
        'property': visit(node.property),
      };

  visitNameExpression(NameExpression node) => visit(node.name);

  // Some values cannot be encoded in JSON. We simply represent these as null.
  bool isUnencodable(Object? x) =>
      x == double.infinity || x == double.negativeInfinity || x == double.nan;

  visitLiteral(LiteralExpression node) => <String, Object?>{
        'type': 'Literal',
        'value': isUnencodable(node.value) ? null : node.value,
        'raw': node.raw
      };

  visitRegexp(RegexpExpression node) =>
      {'type': 'Literal', 'value': <String, Object>{}, 'raw': node.regexp};
}
