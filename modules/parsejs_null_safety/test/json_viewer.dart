import 'ast_json.dart';
import 'dart:io';
import 'package:parsejs_null_safety/parsejs_null_safety.dart';

Program parseInput(String text) {
  try {
    return parsejs(text, parseAsExpression: true);
  } on ParseError {
    return parsejs(text);
  }
}

main() {
  while (true) {
    stdout.write('> ');
    var input = stdin.readLineSync()!;
    try {
      var program = parseInput(input);
      print(new Ast2Json().visit(program));
    } catch (e) {
      print(e);
    }
  }
}
