

import 'package:ensemble/widget/form_textfield.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {



  testWidgets('TextField',  (tester) async {
    TextInput textInput = TextInput();
    textInput.setProperty('value', 'hello');
    textInput.setProperty('validator', {
      'minLength': 5
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: textInput,
      )
    ));

    Finder finder = find.byType(TextInput);
    TextInput result = tester.widget(finder);
    expect(result.textController.text, 'hello');
    

    // update content
    await tester.enterText(finder, 'Jon');
    expect(result.textController.text, 'Jon');

    // validate minLength
    // await tester.pump();
    // result.controller.obscureToggle
    // //expect(find.text('The field must be at least 5 characters long'), findsOneWidget);

  });
}