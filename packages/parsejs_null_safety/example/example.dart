import 'package:parsejs_null_safety/parsejs_null_safety.dart';
import 'dart:io';

void main() async {
  final file = File('test.js');
  final code = await file.readAsString();
  final ast = parsejs(code, filename: 'test.js');
  print('Parsed JavaScript file successfully');
  print('AST has ${ast.body.length} statements');
}
