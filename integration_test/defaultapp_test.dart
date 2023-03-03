import 'dart:io';

import 'package:ensemble/widget/button.dart';
import 'package:ensemble/widget/form_textfield.dart';
import 'package:ensemble/widget/text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../integration_test/framework/main.dart' as testApp;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();


  group('Default App Tests', () {

    /// test that binding to a TextInput works properly in the same scope
    /// and also in a custom widget's scope
    testWidgets("Bindings to widget's value", (tester) async {
      testApp.initTestApp(definition: 'Widget Bindings');
      await tester.pumpAndSettle();

      // TextInput has initial value of 'first'
      // so first make sure our EnsembleText is correctly bind to that
      Finder text = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('first')
      );
      expect(text, findsOneWidget);

      // Custom Widget's text should also bind to the same value
      Finder customText = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('Custom Widget: first')
      );
      expect(customText, findsOneWidget);

      // nested Custom Widget also bind correctly
      Finder customCustomText = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('Custom Custom Widget: first')
      );
      expect(customCustomText, findsOneWidget);

      // now put the cursor inside TextInput and changes its value
      Finder textInput = find.byType(TextInput);
      await tester.enterText(textInput, 'second');
      // just tap somewhere so TextInput's focus out is fired
      await tester.tap(find.byType(Button));
      await tester.pumpAndSettle();

      // confirm the text now says second
      text = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('second')
      );
      expect(text, findsOneWidget);

      // and custom widget's text also updates
      customText = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('Custom Widget: second')
      );
      expect(customText, findsOneWidget);

      // also nested custom widget
      customCustomText = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('Custom Custom Widget: second')
      );
      expect(customCustomText, findsOneWidget);
    });

    /// test bindings to API is working properly
    testWidgets('API Binding', (tester) async {
      testApp.initTestApp(definition: 'API Bindings');
      await tester.pumpAndSettle();

      // before the API loads
      Finder count = find.descendant(
        of: find.byType(EnsembleText),
        matching: find.text('count ')
      );
      expect(count, findsOneWidget);

      Finder person = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('First person: ')
      );
      expect(person, findsOneWidget);

      // after API loads
      await tester.pump(const Duration(seconds: 2));

      // data should reflected
      count = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('count 2')
      );
      expect(count, findsOneWidget);

      person = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('First person: Rachel')
      );
      expect(person, findsOneWidget);

    });


  });




}