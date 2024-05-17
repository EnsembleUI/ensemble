//http://160.16.109.33/github.com/mason-lang/esast/
import 'package:yaml/yaml.dart';

abstract class JSASTVisitor {
  void visitExpressionStatement(ExpressionStatement stmt);
  void visitAssignmentExpression(AssignmentExpression stmt);
  dynamic visitThisExpression(ThisExpr stmt);
  dynamic visitArrayExpression(ArrayExpression stmt);
  dynamic visitMemberExpression(MemberExpr stmt);
  void visitIfStatement(IfStatement stmt);
  dynamic visitConditionalExpression(ConditionalExpression stmt);
  dynamic visitBinaryExpression(BinaryExpression stmt);
  bool visitLogicalExpression(LogicalExpression stmt);
  dynamic visitUnaryExpression(UnaryExpression stmt);
  dynamic visitLiteral(Literal stmt);
  String visitIdentifier(Identifier stmt);
  dynamic visitBlockStatement(BlockStatement stmt);
  dynamic visitCallExpression(CallExpression stmt);
  Function visitArrowFunctionExpression(ArrowFunctionExpression stmt);
  void visitVariableDeclaration(VariableDeclaration stmt);
  void visitVariableDeclarator(VariableDeclarator stmt);
  Map visitObjectExpression(ObjectExpr stmt);
  Map visitProperty(Property stmt);
  dynamic visitReturnStatement(ReturnStatement stmt);
  dynamic visitExpression(Expression stmt) {
    if ( stmt is BinaryExpression ) {
      return visitBinaryExpression(stmt);
    } else if ( stmt is LogicalExpression ) {
      return visitLogicalExpression(stmt);
    } else if ( stmt is CallExpression ) {
      return visitCallExpression(stmt);
    } else if ( stmt is MemberExpr ) {
      return visitMemberExpression(stmt);
    } else if ( stmt is AssignmentExpression ) {
      return visitAssignmentExpression(stmt);
    } else if ( stmt is Identifier ) {
      return visitIdentifier(stmt);
    } else if ( stmt is Literal ) {
      return visitLiteral(stmt);
    } else if ( stmt is UnaryExpression ) {
      return visitUnaryExpression(stmt);
    } else if ( stmt is ArrowFunctionExpression ) {
      return visitArrowFunctionExpression(stmt);
    } else if (stmt is ThisExpr) {
      return visitThisExpression(stmt);
    } else if (stmt is ConditionalExpression) {
      return visitConditionalExpression(stmt);
    } else if ( stmt is ArrayExpression ) {
      return visitArrayExpression(stmt);
    } else if ( stmt is ObjectExpr ) {
      return visitObjectExpression(stmt);
    } else {
      throw Exception("This type of expression is not currently supported. Expression="+stmt.toString());
    }
  }

}
enum BinaryOperator {
  equals,lt,gt,ltEquals,gtEquals,notequals,minus,plus,multiply,divide,inop,instaneof
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
abstract class ASTNode {
  dynamic accept(JSASTVisitor visitor);
}
class IfStatement implements ASTNode {
  Expression test;
  ASTNode consequent;
  ASTNode? alternate;
  IfStatement(this.test,this.consequent,this.alternate);
  static IfStatement fromJson(var jsonNode,ASTBuilder builder) {
    return IfStatement(builder.buildNode(jsonNode['test']) as Expression,
        builder.buildNode(jsonNode['consequent']),
        (jsonNode['alternate']!=null)?builder.buildNode(jsonNode['alternate']):null
      );
  }
  @override
  dynamic accept(JSASTVisitor visitor) {
    return visitor.visitIfStatement(this);
  }
}
class ConditionalExpression implements Expression {
  Expression test,consequent,alternate;
  ConditionalExpression(this.test,this.consequent,this.alternate);
  static ConditionalExpression fromJson(var jsonNode,ASTBuilder builder) {
    return ConditionalExpression(builder.buildNode(jsonNode['test']) as Expression,
        builder.buildNode(jsonNode['consequent']) as Expression,
        builder.buildNode(jsonNode['alternate']) as Expression);
  }
  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitConditionalExpression(this);
  }

}
class BlockStatement implements ASTNode {
  List<ASTNode> statements;
  BlockStatement(this.statements);
  static BlockStatement fromJson(var jsonNode,ASTBuilder builder) {
    List<ASTNode> nodes = [];
    List stmts = jsonNode['body'];
    stmts.forEach((node) {
      nodes.add(builder.buildNode(node));
    });
    return BlockStatement(nodes);
  }
  @override
  dynamic accept(JSASTVisitor visitor) {
    return visitor.visitBlockStatement(this);
  }
}
abstract class Expression extends ASTNode {}
abstract class BooleanExpression extends Expression {}
class UnaryExpression implements Expression {
  Expression argument;
  UnaryOperator op;
  UnaryExpression(this.argument,this.op);
  static UnaryExpression fromJson(var jsonNode,ASTBuilder builder) {
    String operator = jsonNode['operator'];
    UnaryOperator? op;
    if ( operator == '-' ) {
      op = UnaryOperator.minus;
    } else if ( operator == '+' ) {
      op = UnaryOperator.plus;
    } else if ( operator == '!' ) {
      op = UnaryOperator.not;
    } else if ( operator == 'typeof' ) {
      op = UnaryOperator.typeof;
    } else if ( operator == 'void' ) {
      op = UnaryOperator.voidop;
    } else {
      Exception(operator+' is not yet supported');
    }
    return UnaryExpression(builder.buildNode(jsonNode['argument']) as Expression, op!);
  }

  @override
  dynamic accept(JSASTVisitor visitor) {
    return visitor.visitUnaryExpression(this);
  }

}

class BinaryExpression implements BooleanExpression {
  Expression left,right;
  BinaryOperator op;
  BinaryExpression(this.left,this.op,this.right);
  static BinaryExpression fromJson(var jsonNode,ASTBuilder builder) {
    String operator = jsonNode['operator'];
    BinaryOperator? op;
    if ( operator == '==' ) {
      op = BinaryOperator.equals;
    } else if ( operator == '<' ) {
      op = BinaryOperator.lt;
    } else if ( operator == '<=' ) {
      op = BinaryOperator.ltEquals;
    } else if ( operator == '>' ) {
      op = BinaryOperator.gt;
    } else if ( operator == '<=' ) {
      op = BinaryOperator.gtEquals;
    } else if ( operator == '!=' ) {
      op = BinaryOperator.notequals;
    } else if ( operator == '-' ) {
      op = BinaryOperator.minus;
    } else if ( operator == '+' ) {
      op = BinaryOperator.plus;
    } else if ( operator == '*' ) {
      op = BinaryOperator.multiply;
    } else if ( operator == '/' ) {
      op = BinaryOperator.divide;
    } else {
      Exception(operator+' is not yet supported');
    }
    return BinaryExpression(builder.buildNode(jsonNode['left']) as Expression,
        op!,
        builder.buildNode(jsonNode['right']) as Expression
    );
  }
  @override
  dynamic accept(JSASTVisitor visitor) {
    return visitor.visitBinaryExpression(this);
  }
}
abstract class Declaration extends ASTNode {}
class VariableDeclaration implements Declaration {
  VariableDeclarationKind kind;
  List<VariableDeclarator> declarators;
  VariableDeclaration(this.kind,this.declarators);
  static VariableDeclaration fromJson(var jsonNode,ASTBuilder builder) {
    String k = jsonNode['kind'] as String;
    VariableDeclarationKind kind;
    if ( k == 'let' ) {
      kind = VariableDeclarationKind.let;
    } else if ( k == 'var' ) {
      kind = VariableDeclarationKind.variable;
    } else {
      kind = VariableDeclarationKind.constant;
    }
    List<dynamic> declarations = jsonNode['declarations'];
    List<VariableDeclarator> declarators = [];
    for ( var node in declarations ) {
      declarators.add(builder.buildNode(node) as VariableDeclarator);
    }
    return VariableDeclaration(kind,declarators);
  }
  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitVariableDeclaration(this);
  }
}
class VariableDeclarator extends ASTNode {
  Identifier id;
  Expression? init;
  VariableDeclarator(this.id,this.init);
  static VariableDeclarator fromJson(var jsonNode,ASTBuilder builder) {
    ASTNode n = builder.buildNode(jsonNode['id']);
    if ( n is! Identifier ) {
      throw Exception('Only Identifiers are supported for variable declarations at this time');
    }
    Identifier id = n;
    Expression? init;
    if ( jsonNode['init'] != null ) {
      init = builder.buildNode(jsonNode['init']) as Expression;
    }
    return VariableDeclarator(id,init);
  }
  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitVariableDeclarator(this);
  }
}
class ArrowFunctionExpression implements Expression {
  BlockStatement? blockStmt;
  Expression? expression;
  List<ASTNode> params;
  ArrowFunctionExpression(this.blockStmt,this.expression,this.params);
  static ArrowFunctionExpression fromJson(var jsonNode,ASTBuilder builder) {
    List<ASTNode> params = builder.buildArray(jsonNode['params']);
    BlockStatement? blockStmt;
    Expression? expression;
    if ( jsonNode['body']['type'] == 'BlockStatement' ) {
      blockStmt = builder.buildNode(jsonNode['body']) as BlockStatement;
    } else {
      expression = builder.buildNode(jsonNode['body']) as Expression;
    }
    return ArrowFunctionExpression(blockStmt,expression,params);
  }
  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitArrowFunctionExpression(this);
  }

}
//http://160.16.109.33/github.com/mason-lang/esast/class/src/ast.js~CallExpression.html
class CallExpression implements Expression {
  Expression callee;
  List<ASTNode> arguments;
  CallExpression(this.callee,this.arguments);
  static CallExpression fromJson(var jsonNode,ASTBuilder builder) {
    Expression callee = builder.buildNode(jsonNode['callee']) as Expression;
    return CallExpression(callee, builder.buildArray(jsonNode['arguments']));
  }
  @override
  dynamic accept(JSASTVisitor visitor) {
    return visitor.visitCallExpression(this);
  }
}
class LogicalExpression implements BooleanExpression {
  Expression left,right;
  LogicalOperator op;
  LogicalExpression(this.left,this.op,this.right);
  static LogicalExpression fromJson(var jsonNode,ASTBuilder builder) {
    String operator = jsonNode['operator'];
    LogicalOperator? op;
    if ( operator == '&&' ) {
      op = LogicalOperator.and;
    } else if ( operator == '||' ) {
      op = LogicalOperator.or;
    } else if ( operator == '|' ) {
      op = LogicalOperator.not;
    } else {
      Exception(operator+' is not yet supported');
    }
    Expression left = builder.buildNode(jsonNode['left']) as Expression;
    return LogicalExpression(builder.buildNode(jsonNode['left']) as Expression,
        op!,
        builder.buildNode(jsonNode['right']) as Expression
    );
  }
  @override
  dynamic accept(JSASTVisitor visitor) {
    return visitor.visitLogicalExpression(this);
  }
}
class Literal implements Expression {
  dynamic value;
  Literal(this.value);
  static Literal fromJson(var jsonNode,ASTBuilder builder) {
    return Literal(jsonNode['value']);
  }
  @override
  dynamic accept(JSASTVisitor visitor) {
    return visitor.visitLiteral(this);
  }
}
class Identifier implements Expression {
  String name;
  Identifier(this.name);
  static Identifier fromJson(var jsonNode,ASTBuilder builder) {
    return Identifier(jsonNode['name']);
  }
  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitIdentifier(this);
  }
}
class ExpressionStatement implements ASTNode {
  ASTNode expression;
  ExpressionStatement(this.expression);
  static ExpressionStatement fromJson(var jsonNode,ASTBuilder builder) {
    var exp = jsonNode['expression'];
    return ExpressionStatement(builder.buildNode(exp));
  }
  @override
  dynamic accept(JSASTVisitor visitor) {
    return visitor.visitExpressionStatement(this);
  }
}

class AssignmentExpression implements Expression {
  Expression left,right;
  AssignmentOperator op;
  AssignmentExpression(this.left,this.op,this.right);
  static AssignmentExpression fromJson(var jsonNode,ASTBuilder builder) {
    AssignmentOperator op;
    if ( jsonNode['operator'] == '=' ) {
      op = AssignmentOperator.equal;
    } else if ( jsonNode['operator'] == '+=' ) {
      op = AssignmentOperator.plusEqual;
    } else if ( jsonNode['operator'] == '-=' ) {
      op = AssignmentOperator.minusEqual;
    } else {
      throw Exception('Operator '+jsonNode['operator']+' is not yet supported');
    }
    return AssignmentExpression(builder.buildNode(jsonNode['left']) as Expression,
        op, builder.buildNode(jsonNode['right']) as Expression);
  }
  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitAssignmentExpression(this);
  }
}

class ThisExpr implements Expression {
  ThisExpr();
  static ThisExpr fromJson(var jsonNode, ASTBuilder builder) {
    return ThisExpr();
  }
  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitThisExpression(this);
  }
}
class ArrayExpression implements Expression {
  List arr;
  ArrayExpression(this.arr);
  static ArrayExpression fromJson(var jsonNode,ASTBuilder builder) {
    return ArrayExpression(builder.buildArray(jsonNode['elements'] as List));
  }
  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitArrayExpression(this);
  }
}
class Property extends ASTNode {
  Expression key;//either Literal | Identifier
  Expression value;
  Property(this.key,this.value);
  static Property fromJson(var jsonNode,ASTBuilder builder) {
    if ( jsonNode['kind'] != 'init' ) {
      throw Exception('currently function calls to initialize properties of an object are unsupported');
    }
    Expression key = builder.buildNode(jsonNode['key']) as Expression;
    if ( !(key is Literal) && !(key is Identifier) ) {
      throw Exception("Property key must be either Literal or Identifier");
    }
    return Property(key,builder.buildNode(jsonNode['value']) as Expression);
  }

  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitProperty(this);
  }
}
class ObjectExpr implements Expression {
  List<Property> properties;
  ObjectExpr(this.properties);
  static ObjectExpr fromJson(var jsonNode,ASTBuilder builder) {
    List props = jsonNode['properties'];
    return ObjectExpr(buildArray(props,builder));
  }

  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitObjectExpression(this);
  }
  static List<Property> buildArray(var jsonArr,ASTBuilder builder) {
    List<Property> nodes = [];
    jsonArr.forEach((node) {
      nodes.add(builder.buildNode(node) as Property);
    });
    return nodes;
  }
}
class MemberExpr implements Expression {
  Expression object,property;
  MemberExpr(this.object,this.property);
  static MemberExpr fromJson(var jsonNode,ASTBuilder builder) {
    return MemberExpr(builder.buildNode(jsonNode['object']) as Expression, builder.buildNode(jsonNode['property']) as Expression);
  }
  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitMemberExpression(this);
  }
}
class ReturnStatement extends ASTNode {
  Expression? argument;
  ReturnStatement(this.argument);
  static ReturnStatement fromJson(var jsonNode,ASTBuilder builder) {
    Expression? argument;
    if ( jsonNode['argument'] != null ) {
      argument = builder.buildNode(jsonNode['argument']) as Expression;
    }
    return ReturnStatement(argument);
  }

  @override
  accept(JSASTVisitor visitor) {
    return visitor.visitReturnStatement(this);
  }
}
class ASTBuilder {
  List<ASTNode> buildArray(var jsonArr) {
    List<ASTNode> nodes = [];
    jsonArr.forEach((node) {
      nodes.add(buildNode(node));
    });
    return nodes;
  }
  /*
  List<String> getBindableExpressionsAsStrings(List<ASTNode> nodes) {
    List<String> expStrs = [];
    List<Expression> expressions = getBindableExpressions(nodes);
    for ( Expression exp : expressions ) {
      expStrs.add(exp.)
    }
  }
  List<Expression> getBindableExpressionsFromNode(ASTNode node) {
    List<Expression> exps = [];
    if ( node is BlockStatement ) {
      exps.addAll(getBindableExpressions(node.statements));
    } else if ( node is AssignmentExpression ) {
      exps.addAll(getBindableExpressionsFromNode(node.right));
    } else if ( node is BinaryExpression) {
      exps.addAll(getBindableExpressionsFromNode(node.left));
      exps.addAll(getBindableExpressionsFromNode(node.right));
    } else if ( node is LogicalExpression ) {
      exps.addAll(getBindableExpressionsFromNode(node.left));
      exps.addAll(getBindableExpressionsFromNode(node.right));
    } else if ( node is Expression ) {
      expToTest = node;
    }
    if ( expToTest is! Literal ) {
      exps.add(expToTest as Expression);
    }
  }

   */

  ASTNode buildNode(var node) {
    String type = (node is Map)?node['type']:node.toString();
    if ( type == 'ExpressionStatement' ) {
      return ExpressionStatement.fromJson(node, this);
    } else if ( type == 'AssignmentExpression' ) {
      return AssignmentExpression.fromJson(node,this);
    } else if ( type == 'MemberExpression' ) {
      return MemberExpr.fromJson(node, this);
    } else if ( type == 'IfStatement' ) {
      return IfStatement.fromJson(node, this);
    }  else if ( type == 'ConditionalExpression' ) {
      return ConditionalExpression.fromJson(node, this);
    }else if ( type == 'Literal' ) {
      return Literal.fromJson(node, this);
    } else if ( type == 'Identifier' ) {
      return Identifier.fromJson(node, this);
    } else if ( type == 'BlockStatement' ) {
      return BlockStatement.fromJson(node, this);
    } else if ( type == 'BinaryExpression' ) {
      return BinaryExpression.fromJson(node, this);
    } else if ( type == 'LogicalExpression' ) {
      return LogicalExpression.fromJson(node, this);
    } else if ( type == 'CallExpression' ) {
      return CallExpression.fromJson(node, this);
    } else if ( type == 'UnaryExpression' ) {
      return UnaryExpression.fromJson(node, this);
    } else if (type == 'ThisExpression') {
      return ThisExpr.fromJson(node, this);
    } else if ( type == 'ArrayExpression' ) {
      return ArrayExpression.fromJson(node, this);
    } else if ( type == 'ArrowFunctionExpression' ) {
      return ArrowFunctionExpression.fromJson(node, this);
    } else if ( type == 'VariableDeclaration' ) {
      return VariableDeclaration.fromJson(node, this);
    } else if ( type == 'VariableDeclarator' ) {
      return VariableDeclarator.fromJson(node, this);
    } else if ( type == 'ObjectExpression' ) {
      return ObjectExpr.fromJson(node, this);
    } else if ( type == 'Property' ) {
      return Property.fromJson(node, this);
    } else if ( type == 'ReturnStatement' ) {
      return ReturnStatement.fromJson(node, this);
    }
    throw Exception(type+" is not yet supported. Full expression is="+node.toString());
  }
}