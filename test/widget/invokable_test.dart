
import 'package:ensemble/framework/context.dart';
import 'package:ensemble/layout/Column.dart';
import 'package:ensemble/widget/Text.dart';
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/widget/form_textfield.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  Map<String, dynamic> dataMap = {
    'result': {
      'name': 'Peter Parker',
      'age': 25,
      'first_name': 'Peter',
      'last-name': 'Parker'
    }
  };

  EnsembleContext getBaseContext() {
    return EnsembleContext(dataMap);
  }

  EnsembleContext getDataAndWidgetContext() {
    EnsembleContext context = getBaseContext();

    Text myText = Text();
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
    EnsembleContext context = getBaseContext();
    expect(context.eval("hello \$(result.name)"), "hello Peter Parker");
    expect(context.eval("\$(result.name)'s age is \$(result.age)"), "Peter Parker's age is 25");
  });


  test('Parsing expressions', () {
    // empty context returns original
    EnsembleContext context = EnsembleContext({});
    expect(context.eval(r'$(result.name)'), r'result.name');

    context = getBaseContext();
    expect(context.eval(r'$(result.first_name)'), 'Peter');
    expect(context.eval(r'$(result.last-name)'), 'Parker');
    expect(context.eval(r'$(result.name)'), 'Peter Parker');

    expect(context.eval('hello'), 'hello');
  });


  test('Parsing variables', () {
    EnsembleContext context = getBaseContext();
    expect(context.evalVariable('blah'), 'blah');
    expect(context.evalVariable('blah.blah'), 'blah.blah');

    expect(context.evalVariable('result.name'), 'Peter Parker');
    expect(context.evalVariable('result.age'), 25);
    expect(context.evalVariable('result').toString(), dataMap['result'].toString());
  });
  
  test("Widget getters", () {
    EnsembleContext context = getDataAndWidgetContext();
    
    expect(context.eval(r'$(myText.text) there $(result.name)'), 'Hello there Peter Parker');
    expect(context.eval(r'$(myTextField.value)'), 'Ronald');

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
    EnsembleContext context = getDataAndWidgetContext();
    expect(context.eval(r'$(myText.text) $(myTextField.value)'), 'Hello Ronald');

    context.evalCode(
    r' myText.text = "Goodbye"; '
    r' myTextField.value = "Peter"; ');
    // will fail until evalCode() implementation
    //expect(context.eval(r'$(myText.text) $(myTextField.value)'), 'Goodbye Peter');
  });

}