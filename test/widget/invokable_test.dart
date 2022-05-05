
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/widget/Text.dart' as widget;
import 'package:ensemble/widget/form_textfield.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:mockito/mockito.dart';

void main() {

  Map<String, dynamic> dataMap = {
    'result': {
      'name': 'Peter Parker',
      'age': 25,
      'first_name': 'Peter',
      'last-name': 'Parker'
    }
  };

  DataContext getBaseContext() {
    return DataContext(buildContext: MockBuildContext(), initialMap: dataMap);
  }

  DataContext getDataAndWidgetContext() {
    DataContext context = getBaseContext();

    widget.Text myText = widget.Text();
    myText.setProperty('text', 'Hello');
    context.addInvokableContext("myText", myText);

    TextField myTextField = TextField();
    myTextField.setProperty('value', 'Ronald');
    context.addInvokableContext("myTextField", myTextField);

    return context;
  }

  test('url', () {
    expect(getBaseContext().eval("https://site.com/age/\$(result.age)/detail"), "https://site.com/age/25/detail");
  });

  test('multiple matches', () {
    DataContext context = getBaseContext();
    expect(context.eval("hello \$(result.name)"), "hello Peter Parker");
    expect(context.eval("\$(result.name)'s age is \$(result.age)"), "Peter Parker's age is 25");
  });


  test('Parsing expressions', () {
    // empty context returns original
    DataContext context = DataContext(buildContext: MockBuildContext(), initialMap: {});
    expect(context.eval(r'$(blah)'), r'blah');
    expect(context.eval(r'$(result.name)'), r'result.name');

    context = getBaseContext();
    expect(context.eval(r'$(result.first_name)'), 'Peter');
    expect(context.eval(r'$(result.last-name)'), 'Parker');
    expect(context.eval(r'$(result.name)'), 'Peter Parker');

    expect(context.eval('hello'), 'hello');
  });


  test('Parsing variables', () {
    DataContext context = getBaseContext();
    expect(context.evalVariable('blah'), 'blah');
    expect(context.evalVariable('blah.blah'), 'blah.blah');

    expect(context.evalVariable('result.name'), 'Peter Parker');
    expect(context.evalVariable('result.age'), 25);
    expect(context.evalVariable('result').toString(), dataMap['result'].toString());
  });


  
  test("Widget getters", () {
    DataContext context = getDataAndWidgetContext();
    
    //expect(context.eval(r'$(myText.text) there $(result.name)'), 'Hello there Peter Parker');
    //expect(context.eval(r'$(myTextField.value)'), 'Ronald');

    // invalid getter
    expect(context.eval(r'$(myTextField.what)'), 'myTextField.what');
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
    expect(context.eval(r'$(myText.text) $(myTextField.value)'), 'Hello Ronald');

    // TODO: use AST instead of code
    //context.evalCode('myText.text = "Goodbye"; myTextField.value = "Peter";');
    //expect(context.eval(r'$(myText.text) $(myTextField.value)'), 'Goodbye Peter');
  });

  test("Recursive invokable", () {
    DataContext context = getBaseContext();
    context.addInvokableContext("ensemble", EnsembleMockLibrary());
    expect(context.eval(r'$(ensemble.storage.get("username"))'), 'admin');
    expect(context.eval(r"$(ensemble.storage.get('username'))"), 'admin');
    expect(context.eval(r'Psst $(ensemble.storage.get("password"))'), 'Psst pass');
  });

}

class EnsembleMockLibrary with Invokable {
  @override
  Map<String, Function> getters() {
    return {
      'storage': () => MockStorage()
    };
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
  final Map<String, dynamic> data = {
    'username': 'admin',
    'password': 'pass'
  };

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

class MockBuildContext extends Mock implements BuildContext {}