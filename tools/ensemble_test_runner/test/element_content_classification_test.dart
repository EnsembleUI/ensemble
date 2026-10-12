import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('classifies standalone and control-owned text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Text('standalone copy'),
            ElevatedButton(
              onPressed: () {},
              child: const Text('save action'),
            ),
          ],
        ),
      ),
    );

    final standalone = tester.element(find.text('standalone copy'));
    expect(isStandaloneTextElement(standalone), isTrue);
    expect(isObservableTextElement(standalone), isTrue);

    final button = tester.element(find.byType(ElevatedButton));
    expect(isActionableControl(button), isTrue);
    expect(isPrimaryControlElement(button), isTrue);

    final buttonText = tester.element(find.text('save action'));
    expect(isStandaloneTextElement(buttonText), isFalse);
    expect(isObservableTextElement(buttonText), isTrue);
  });

  testWidgets('keeps text field internals out of observable text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextField(
            decoration: InputDecoration(labelText: 'Name'),
          ),
        ),
      ),
    );

    final field = tester.element(find.byType(TextField));
    expect(isActionableControl(field), isTrue);
    expect(isPrimaryControlElement(field), isTrue);

    final editable = tester.element(find.byType(EditableText));
    expect(isObservableTextElement(editable), isFalse);
  });

  testWidgets('recognizes rich text as standalone visible content',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Text.rich(
          TextSpan(text: 'rich copy'),
        ),
      ),
    );

    final richText = tester.element(find.byType(Text));
    expect(isStandaloneTextElement(richText), isTrue);
    expect(isObservableTextElement(richText), isTrue);
  });
}
