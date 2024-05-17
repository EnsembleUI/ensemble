import 'package:ensemble_ts_interpreter/parser/ast.dart';

class BindableExpressionFinder extends JSASTVisitor {
  List<String> bindableExpressions = [];
  List<ASTNode> nodes;
  Map context;
  BindableExpressionFinder(this.nodes,this.context);
  List<String> findBindables() {
    for (ASTNode node in nodes) {
      node.accept(this);
    }
    return bindableExpressions;
  }
  @override
  visitArrayExpression(ArrayExpression stmt) {
  }

  @override
  Function visitArrowFunctionExpression(ArrowFunctionExpression stmt) {
    return ()=>'';
  }

  @override
  void visitAssignmentExpression(AssignmentExpression stmt) {
    stmt.right.accept(this);
  }

  @override
  visitBinaryExpression(BinaryExpression stmt) {
    stmt.left.accept(this);
    stmt.right.accept(this);
  }

  @override
  visitBlockStatement(BlockStatement stmt) {
    stmt.statements.forEach((element) => element.accept(this));
  }

  @override
  visitCallExpression(CallExpression stmt) {
  }

  @override
  visitConditionalExpression(ConditionalExpression stmt) {
    stmt.test.accept(this);
  }

  @override
  void visitExpressionStatement(ExpressionStatement stmt) {
    stmt.expression.accept(this);
  }

  @override
  String visitIdentifier(Identifier stmt) {
    if ( context.containsKey(stmt.name) ) {
      bindableExpressions.add(stmt.name);
    }
    return '';
  }

  @override
  void visitIfStatement(IfStatement stmt) {
    stmt.test.accept(this);
  }

  @override
  visitLiteral(Literal stmt) {
  }

  @override
  bool visitLogicalExpression(LogicalExpression stmt) {
    stmt.left.accept(this);
    stmt.right.accept(this);
    return true;
  }

  @override
  visitMemberExpression(MemberExpr stmt) {
    stmt.object.accept(this);
  }

  @override
  Map visitObjectExpression(ObjectExpr stmt) {
    return {};
  }

  @override
  Map visitProperty(Property stmt) {
    return {};
  }

  @override
  visitReturnStatement(ReturnStatement stmt) {
    if ( stmt.argument != null ) {
      stmt.argument!.accept(this);
    }
  }

  @override
  visitThisExpression(ThisExpr stmt) {
  }

  @override
  visitUnaryExpression(UnaryExpression stmt) {
    stmt.argument.accept(this);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration stmt) {
    stmt.declarators.forEach((element) => element.accept(this));
  }

  @override
  void visitVariableDeclarator(VariableDeclarator stmt) {
    if (stmt.init != null) {
      stmt.init!.accept(this);
    }
  }

}