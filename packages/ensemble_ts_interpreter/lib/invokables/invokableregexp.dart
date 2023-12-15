import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class InvokableRegExp extends Object with Invokable {
  RegExp regExp;
  InvokableRegExp(this.regExp);
  @override
  Map<String, Function> getters() {
    // TODO: implement getters
    throw UnimplementedError();
  }

  @override
  Map<String, Function> methods() {
    return {
      'test': (String input) => regExp.hasMatch(input),
      //'exec': (String input) => regExp.allMatches(input).toList()

    };
  }

  @override
  Map<String, Function> setters() {
    // TODO: implement setters
    throw UnimplementedError();
  }

}