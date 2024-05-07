import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/widget/conditional.dart';
import 'package:ensemble/widget/input/dropdown.dart';
import 'package:ensemble/widget/input/form_textfield.dart';
import 'package:ensemble/widget/text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/widget/test_utils.dart';
import '../framework/test_helper.dart';

void main() {
  late EnsembleConfig config;
  setUpAll(() async {
    config = await TestHelper.setupApp(appName: 'defaultApp');
  });

  group('Default App Tests', () {
    /// test that binding to a TextInput works properly in the same scope
    /// and also in a custom widget's scope
    testWidgets("Bindings to widget's value", (tester) async {
      await TestHelper.loadScreen(tester, 'Custom Widget', config);

      // TextInput has initial value of 'first'
      // so first make sure our EnsembleText is correctly bind to that
      Finder text = find.descendant(
          of: find.byType(EnsembleText), matching: find.text('first'));
      expect(text, findsOneWidget);

      // Custom Widget's onLoad can access inputs
      // search for toast message
      await tester.pumpAndSettle();
      expect(find.text('Hello first'), findsOneWidget);

      // ensure Nested widget's onLoad can access inputs via JS too
      expect(find.text('Hi first'), findsOneWidget);

      // Custom Widget's text should also bind to the same value
      Finder customText = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('Custom Widget: first'));
      expect(customText, findsOneWidget);

      // nested Custom Widget also bind correctly
      Finder customCustomText = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('Custom Custom Widget: first'));
      expect(customCustomText, findsOneWidget);

      // now put the cursor inside TextInput and changes its value
      Finder textInput = find.byType(TextInput);
      await tester.enterText(textInput, 'second');
      // just tap somewhere so TextInput's focus out is fired
      await tester.tap(find.byType(Button));
      await tester.pumpAndSettle();

      // confirm the text now says second
      text = find.descendant(
          of: find.byType(EnsembleText), matching: find.text('second'));
      expect(text, findsOneWidget);

      // and custom widget's text also updates
      customText = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('Custom Widget: second'));
      expect(customText, findsOneWidget);

      // also nested custom widget
      customCustomText = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('Custom Custom Widget: second'));
      expect(customCustomText, findsOneWidget);

      // ensure onLoad never run again and still retain original value
      expect(find.text('Hi first'), findsOneWidget);
    });

    /// test bindings to API is working properly
    testWidgets('API Binding', (tester) async {
      await TestHelper.loadScreen(tester, 'API Bindings', config);
      await tester.pumpAndSettle();

      // before the API loads
      Finder count = find.descendant(
          of: find.byType(EnsembleText), matching: find.text('count '));
      expect(count, findsOneWidget);

      Finder person = find.descendant(
          of: find.byType(EnsembleText), matching: find.text('First person: '));
      expect(person, findsOneWidget);

      // fetch
      await tester.tap(find.byType(Button));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // data should reflected
      count = find.descendant(
          of: find.byType(EnsembleText), matching: find.text('count 2'));
      expect(count, findsOneWidget);

      person = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('First person: Rachel'));
      expect(person, findsOneWidget);
    });

    /// test invokeApi
    /**testWidgets("invokeApi Test", (tester) async {
      await TestHelper.loadScreen(tester, "Invoke Api", config);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Button, "Call API"));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      Finder myHeader = find.textContaining('application/json');
      Finder status = find.text('200-OK');
      Finder error = find.text("Error");
      Finder body = find.text("Body: ");
      expect(body, findsNothing);
      expect(error, findsNothing);
      expect(myHeader, findsNWidgets(3));
      expect(status, findsOneWidget);

      await tester
          .tap(find.widgetWithText(Button, 'Call API with invalid URI'));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      Finder badapiOnerror = find.text("Bad Api onResponse called");
      Finder badApiStatus =
          find.text("Invalid argument(s): No host specified in URI blah");
      expect(badapiOnerror, findsNothing);
      expect(badApiStatus, findsOneWidget);

      await tester
          .tap(find.widgetWithText(Button, 'Call API that returns error'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      Finder errorText = find.text("Internal Server Error");
      Finder errorStatus = find.text("500");
      expect(errorText, findsNWidgets(2));
      expect(errorStatus, findsOneWidget);
    });*/

    // test nested textSTyle
    testWidgets('Nested TextStyle update via Bindings/JS', (tester) async {
      await TestHelper.loadScreen(tester, 'Nested TextStyle', config);
      await tester.pumpAndSettle();

      Finder textFinder = find.descendant(
          of: find.byType(EnsembleText),
          matching: find.text('This textStyle can change'));
      expect(textFinder, findsOneWidget);
      Text textWidget = tester.widget(textFinder);
      expect(textWidget.style?.color, null);
      expect(textWidget.style?.fontFamily, null);

      // Binding Test: change the font to Google font Abel
      Finder inputFinder = find.byType(TextInput);
      await tester.enterText(inputFinder, 'Abel');
      await TestHelper.removeFocus(tester);
      textWidget = tester.widget(textFinder);
      expect(textWidget.style?.fontFamily, 'Abel_regular');

      // Binding Test: change to non-Google 'RandomFont' and confirm
      await tester.tap(inputFinder);
      await tester.enterText(inputFinder, 'RandomFont');
      await TestHelper.removeFocus(tester);
      textWidget = tester.widget(textFinder);
      expect(textWidget.style?.fontFamily, 'RandomFont');

      // JS Test: click on button to change color
      Finder buttonFinder = find.descendant(
          of: find.byType(Button),
          matching: find.text('Change text color to red'));
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // confirm text color is now red
      textWidget = tester.widget(textFinder);
      expect(textWidget.style?.color, Colors.red);

      // JS Test: click on button to change size
      buttonFinder = find.descendant(
          of: find.byType(Button),
          matching: find.text('Change font size to 40'));
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      textWidget = tester.widget(textFinder);
      expect(textWidget.style?.fontSize, 40);
    });

    /// We have 2 dropdowns inside 2 Forms, one with label on top and another
    /// with side-by-side labels. The structure for both is different hence
    /// the demonstration on how to do for each
    testWidgets('Test finding Ensemble widgets in Forms', (tester) async {
      await TestHelper.loadScreen(tester, 'Dropdown and Form', config);
      await tester.pumpAndSettle();

      // two TextInputs on the screen
      Finder textInputFinders = find.byType(TextInput);
      expect(textInputFinders, findsNWidgets(2));

      /// test TextInput with label on top
      Finder? textInput1 =
          TestHelper.findFormWidgetByLabel<TextInput>(tester, 'My TextInput');
      expect(textInput1, findsOneWidget);
      await tester.enterText(textInput1!, 'hello');
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);

      // test TextInput with side-by-side label
      Finder? textInput2 =
          TestHelper.findFormWidgetByLabel<TextInput>(tester, 'My TextInput 2');
      expect(textInput2, findsOneWidget);
      await tester.enterText(textInput2!, 'world');
      await tester.pumpAndSettle();
      expect(find.text('world'), findsOneWidget);

      // two Dropdowns on the screen
      Finder dropdownFinders = find.byType(Dropdown);
      expect(dropdownFinders, findsNWidgets(2));

      /// Dropdown inside Form with label on top
      Finder? dropdown1 =
          TestHelper.findFormWidgetByLabel<Dropdown>(tester, 'My Dropdown');
      expect(dropdown1, findsOneWidget);
      // open the dropdown
      await tester.tap(dropdown1!);
      await tester.pumpAndSettle();
      // select value 'one'
      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      // verified value 'six' is selected
      expect(find.text('one'), findsOneWidget);

      /// Dropdown inside Form with side-by-side label
      Finder? dropdown2 =
          TestHelper.findFormWidgetByLabel<Dropdown>(tester, "My Dropdown 2");
      expect(dropdown2, findsOneWidget);
      // open the dropdown
      await tester.tap(dropdown2!);
      await tester.pumpAndSettle();
      // select value 'six'
      await tester.tap(find.text('six'));
      await tester.pumpAndSettle();
      // verified value 'six' is selected
      expect(find.text('six'), findsOneWidget);
    });

    testWidgets('Conditional', (tester) async {
      await TestHelper.loadScreen(tester, 'Conditional', config);
      await tester.pumpAndSettle();

      Finder textInputFinder = find.byType(TextInput);
      expect(textInputFinder, findsOneWidget);

      // one Conditional widget on the screen
      Finder conditionalFinder = find.byType(Conditional);
      expect(conditionalFinder, findsOneWidget);

      Finder textFinder = find.byType(EnsembleText);
      expect(textFinder, findsOneWidget);

      // Initial Statement when textfield is empty
      EnsembleText textWidget = tester.firstWidget(textFinder);
      expect(textWidget.controller.text, 'Else Statement');

      // If Statement
      await tester.enterText(textInputFinder, 'If');
      await tester.pumpAndSettle();
      textWidget = tester.widget(textFinder);
      expect(textWidget.controller.text, 'If Statement');

      // Else If First Statement
      await tester.enterText(textInputFinder, 'ElseIf1');
      await tester.pumpAndSettle();
      textWidget = tester.widget(textFinder);
      expect(textWidget.controller.text, 'Else If Statement - 1');

      // Else If Second Statement
      await tester.enterText(textInputFinder, 'ElseIf2');
      await tester.pumpAndSettle();
      textWidget = tester.widget(textFinder);
      expect(textWidget.controller.text, 'Else If Statement - 2');

      // Else If Third Statement
      await tester.enterText(textInputFinder, 'ElseIf3');
      await tester.pumpAndSettle();
      textWidget = tester.widget(textFinder);
      expect(textWidget.controller.text, 'Else If Statement - 3');

      // Else Statement
      await tester.enterText(textInputFinder, 'Other');
      await tester.pumpAndSettle();
      textWidget = tester.widget(textFinder);
      expect(textWidget.controller.text, 'Else Statement');
    });
  });
}
