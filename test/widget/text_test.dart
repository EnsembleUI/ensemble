
import 'package:ensemble/widget/text.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> props = {
  'text': 'hello'
};

Map<String, dynamic> styles = {
};




void main() {



  testWidgets('Text widget',  (tester) async {
    ensemble.Text myText = ensemble.Text();
    myText.setProperty('text', 'Hello');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: myText,
      ),
    ));

    Finder finder = find.text('Hello');
    expect(finder, findsOneWidget);



    //EnsembleText text = tester.widget(finder);
  });


}