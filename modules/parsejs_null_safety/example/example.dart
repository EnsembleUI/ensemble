import 'package:parsejs_null_safety/parsejs_null_safety.dart';
import 'dart:io';

void main() {
  new File('test.js').readAsString().then((String code) {
    Program ast = parsejs(code, filename: 'test.js');
    // Use the AST for something
  });
}
