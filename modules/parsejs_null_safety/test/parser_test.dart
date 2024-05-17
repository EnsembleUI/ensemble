// Parses the given FILE and prints it as JSON so it can be compared against Esprima's output.

import 'package:jsparser/jsparser.dart';
import 'ast_json.dart';

import 'dart:io';
import 'dart:convert' as JSON;

class Args {
  List<String> args = <String>[];
  Set<String> flags = new Set<String>();

  bool operator [](String flag) => flags.contains(flag);
}

Args parseArgs(List<String> args) {
  Args result = new Args();
  for (String arg in args) {
    if (arg.startsWith('--')) {
      result.flags.add(arg.substring(2));
    } else {
      result.args.add(arg);
    }
  }
  return result;
}

void main(List<String> cmdargs) {
  Args cmd = parseArgs(cmdargs);

  if (cmd.args.length != 1) {
    print(
        "Usage: parser_test.dart [--json [--range] [--line]] [--time] FILE.js");
    exit(1);
  }

  File file = new File(cmd.args[0]);
  file.readAsString().then((String text) {
    try {
      Stopwatch watch = new Stopwatch()..start();
      Program ast = parsejs(text, filename: file.path);
      int time = watch.elapsedMilliseconds;

      if (cmd['time']) {
        print(time);
      }

      if (cmd['json']) {
        var json =
            new Ast2Json(ranges: cmd['range'], lines: cmd['line']).visit(ast);
        print(JSON.jsonEncode(json));
      }
    } on ParseError catch (e) {
      stderr.writeln(e);
      exit(1);
    }
  });
}
