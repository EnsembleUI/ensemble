import 'package:ensemble/widget/Text.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  testWidgets('set the Text', (tester) async {
    var data = 'Hello World';
    EnsembleText widget = EnsembleText();
    widget.setProperty('text', data);
    await tester.pumpWidget(TestUtils.wrapTestWidget(widget));

    expect(find.text(data), findsOneWidget);
  });


  testWidgets('set the TextALign', (tester) async {
    var data = 'start';
    EnsembleText widget = EnsembleText();
    widget.setProperty('textAlign', data);
    await tester.pumpWidget(TestUtils.wrapTestWidget(widget));

    expect(find.text(data), findsOneWidget);
  });

}
