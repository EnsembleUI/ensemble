import 'dart:io';

import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/widget/text.dart' as widget;
import 'package:ensemble/widget/input/form_textfield.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:mockito/mockito.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> dataMap = {
    'result': {
      'name': 'Peter Parker',
      'age': 25,
      'skills': 'flying',
      'superhero': true,
      'first_name': 'Peter',
      'lastName': 'Parker',
      'has_power_since': 1654841398,
      'power_for_hire': 6400.12,
      'date_1': 'Thu, 16 Jun 2022 17:01:08 GMT-0700',
      'currency_1': 24,
      'currency_2': "25",
      'currency_3': "25.3",
    }
  };

  DataContext getBaseContext() {
    return DataContext(buildContext: MockBuildContext(), initialMap: dataMap);
  }

  DataContext getDataAndWidgetContext() {
    DataContext context = getBaseContext();

    widget.EnsembleText myText = widget.EnsembleText();
    myText.setProperty('text', 'Hello');
    context.addInvokableContext("myText", myText);

    TextInput myTextField = TextInput();
    myTextField.setProperty('value', 'Ronald');
    context.addInvokableContext("myTextField", myTextField);

    return context;
  }

  test('payload map', () {
    Map<String, dynamic> processed = getBaseContext().eval(YamlMap.wrap({
      'payload': {
        'name': '\${result.name}',
        'age': '\${result.age}',
        'skills': ['eating', '\${result.skills}', 'drinking'],
        'superhero': '\${result.superhero}'
      }
    }));
    expect(processed['payload']['name'], 'Peter Parker');
    expect(processed['payload']['age'], 25);
    expect(processed['payload']['skills'], ['eating', 'flying', 'drinking']);
    expect(processed['payload']['superhero'], true);
  });

  /// this is very different than the above. We are testing a variable receiving a map.
  /// This allow us to take in a YamlMap as a value
  test('variable with data map', () {
    Map<String, dynamic> processed = getBaseContext().eval(YamlMap.wrap({
      'variable': {'name': '\${result.name}', 'age': '\${result.age}'}
    }));
    expect(processed['variable'], {'name': 'Peter Parker', 'age': 25});
  });

  test('variable with data list', () {
    Map<String, dynamic> processed = getBaseContext().eval(YamlMap.wrap({
      'variable': ['\${result.name}', 100, '\${result.age}', 'hello']
    }));
    expect(processed['variable'], ['Peter Parker', 100, 25, 'hello']);
  });

  test('url', () {
    expect(getBaseContext().eval("https://site.com/age/\${result.age}/detail"),
        "https://site.com/age/25/detail");
  });

  test('multiple matches', () {
    DataContext context = getBaseContext();
    expect(context.eval("hello \${result.name}"), "hello Peter Parker");
    expect(context.eval("\${result.name}'s age is \${result.age}"),
        "Peter Parker's age is 25");
  });

  test('Parsing expressions', () {
    // empty context returns original
    DataContext context =
        DataContext(buildContext: MockBuildContext(), initialMap: {});
    expect(context.eval(r'${blah}'), '');
    expect(context.eval(r'${result.name}'), '');

    context = getBaseContext();
    expect(context.eval(r'${result.first_name}'), 'Peter');
    expect(context.eval(r'${result.lastName}'), 'Parker');
    expect(context.eval(r'${result.name}'), 'Peter Parker');

    expect(context.eval('hello'), 'hello');
  });

  test('Parsing variables', () {
    DataContext context = getBaseContext();
    expect(context.evalVariable('blah'), null);
    expect(context.evalVariable('blah.blah'), null);

    expect(context.evalVariable('result.name'), 'Peter Parker');
    expect(context.evalVariable('result.age'), 25);
    expect(context.evalVariable('result').toString(),
        dataMap['result'].toString());
  });

  test("Widget getters", () {
    DataContext context = getDataAndWidgetContext();

    expect(context.eval(r'${myText.text} there ${result.name}'),
        'Hello there Peter Parker');
    //expect(context.eval(r'$(myTextField.value)'), 'Ronald');

    // invalid getter
    expect(context.eval(r'${myTextField.what}'), '');
  });

  /*test("Container getters", () {
    Column myColumn = Column();
    myColumn.setProperty("width", 200);

    EnsembleContext context = getBaseContext();
    context.addInvokableContext("myColumn", myColumn);

    expect(context.eval(r'$(myColumn.width)'), 200);
    expect(context.eval(r'My waist is $(myColumn.width)'), 'My waist is 200');


  });*/

  test("Code block", () {
    DataContext context = getDataAndWidgetContext();
    expect(
        context.eval(r'${myText.text} ${myTextField.value}'), 'Hello Ronald');

    // TODO: use AST instead of code
    //context.evalCode('myText.text = "Goodbye"; myTextField.value = "Peter";');
    //expect(context.eval(r'$(myText.text) $(myTextField.value)'), 'Goodbye Peter');
  });

  test("Recursive invokable", () {
    DataContext context = getBaseContext();
    context.addInvokableContext("ensemble", EnsembleMockLibrary());
    expect(context.eval(r'${ensemble.storage.get("username")}'), 'admin');
    expect(context.eval(r"${ensemble.storage.get('username')}"), 'admin');
    expect(
        context.eval(r'Psst ${ensemble.storage.get("password")}'), 'Psst pass');
  });

  // need to re-work date time formatter
  /*test('Date Formatter', () {
    DataContext context = getBaseContext();
    context.addInvokableContext("ensemble", NativeInvokable(MockBuildContext()));

    //expect(context.eval(r'$(ensemble.formatter.prettyDate("2022-06-09"))'), 'Jun 9, 2022');

    //expect(context.eval(r'$(ensemble.formatter.prettyDateTime("2022-06-09T09:05:00"))'), 'Jun 9, 2022 9:05 AM');

    // timestamp 1654841288 is around 6/9/2022 11:09PM PST
    //expect(context.eval(r'$(ensemble.formatter.prettyDateTime(1654841398))'), 'Jun 9, 2022 11:09 PM');
    //expect(context.eval(r'$(ensemble.formatter.prettyDateTime(result.has_power_since))'), 'Jun 9, 2022 11:09 PM');


    expect(context.eval(r'${result.date_1.prettyDateTime()}'), 'Jun 16, 2022 5:01 PM');
    expect(context.eval(r'${result.has_power_since.prettyDateTime()}'), 'Jun 9, 2022 11:09 PM');
  });*/

  test('currency formatter', () {
    DataContext context = getBaseContext();
    context.addInvokableContext(
        "ensemble", NativeInvokable(MockBuildContext()));

    expect(context.eval(r'${result.power_for_hire.prettyCurrency()}'),
        '\$6,400.12');
    expect(context.eval(r'${result.currency_1.prettyCurrency()}'), '\$24.00');
    expect(context.eval(r'${result.currency_2.prettyCurrency()}'), '\$25.00');
    expect(context.eval(r'${result.currency_3.prettyCurrency()}'), '\$25.30');
  });

  test('now', () {
    UserDateTime userDT = MockUserDateTime("2022-09-06T13:05:00");
    expect(InvokableController.getMethods(userDT)['getYear']!.call(), 2022);
    expect(InvokableController.getMethods(userDT)['getMonth']!.call(), 9);
    expect(InvokableController.getMethods(userDT)['getDay']!.call(), 6);
    expect(InvokableController.getMethods(userDT)['getDayOfWeek']!.call(),
        2); // Tuesday = 2
    expect(InvokableController.getMethods(userDT)['getHour']!.call(), 13);
    expect(InvokableController.getMethods(userDT)['getMinute']!.call(), 5);
    expect(InvokableController.getMethods(userDT)['getSecond']!.call(), 0);
  });
}

class EnsembleMockLibrary with Invokable {
  @override
  Map<String, Function> getters() {
    return {'storage': () => MockStorage()};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

class MockStorage with Invokable {
  final Map<String, dynamic> data = {'username': 'admin', 'password': 'pass'};

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'get': (String key) {
        return data[key];
      },
      'set': (String key, dynamic value) => data[key] = value
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

class MockUserDateTime extends UserDateTime {
  String input;
  MockUserDateTime(this.input);

  @override
  DateTime get dateTime => DateTime.parse(input);
}

class MockBuildContext extends Mock implements BuildContext {}
