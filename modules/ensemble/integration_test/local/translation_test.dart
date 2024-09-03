import 'package:ensemble/ensemble.dart';
import 'package:flutter_test/flutter_test.dart';

import '../framework/test_helper.dart';

void main() {
  group('Default English locale', () {
    testWidgets("default locale should work properly", (tester) async {
      EnsembleConfig config = await TestHelper.setupApp(appName: 'translation');
      await TestHelper.loadScreen(tester, 'Basic', config);

      // test date time currency
      expect(find.text("Jun 20, 2024"), findsOneWidget);
      expect(find.text("2:02 PM"), findsOneWidget);
      expect(find.text("\$100.12"), findsOneWidget);
      expect(find.text("Jun 20 at 2:02PM"), findsOneWidget);

      // test using Date objects
      expect(find.text("3/14/2022"), findsOneWidget);
      expect(find.text("4:07:20 PM"), findsOneWidget);
      expect(find.text("3/14/2022, 4:07:20 PM"), findsOneWidget);

      // test translation
      expect(find.text("Hello Peter"), findsOneWidget);

      await tester.tap(find.text("Show Toast"));
      await tester.pumpAndSettle();
      expect(find.text("Hello Hello Peter"), findsOneWidget);
    });
  });
}
