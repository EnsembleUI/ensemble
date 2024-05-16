import 'dart:io';
import 'package:jsparser/src/lexer.dart';

void main(List<String> args) {
  if (args.length != 1) {
    print("Usage: lexer_test.dart FILE.js");
    exit(1);
  }

  String filename = args[0];

  new File(filename).readAsString().then((String text) {
    try {
      Lexer lexer = new Lexer(text);
      for (Token token = lexer.scan();
          token.type != Token.EOF;
          token = lexer.scan()) {
        print(token);
      }
    } on ParseError catch (e) {
      stderr.writeln(e);
      exit(1);
    }
  });
}
