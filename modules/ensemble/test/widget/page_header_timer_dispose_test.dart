import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  testWidgets(
    'Page with storage-driven header disposes without timer callbacks after unmount',
    (tester) async {
      final doc = loadYaml(
        '''
View:
  header:
    titleText: Test
    collapsibleHeader:
      enabled: true
      visible: ensemble.storage.visFlag
    styles:
      listenTitleBarHeightStorage: true
      titleBarHeight: ensemble.storage.tbhKey
  body:
    Column:
      children:
        - Text:
            text: body
''',
      );

      final pageModel = PageModel.fromYaml(doc as YamlMap) as SinglePageModel;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Page(
              dataContext: DataContext(buildContext: context),
              pageModel: pageModel,
              onRendered: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.shrink()),
      );
      await tester.pump();

      // Undisposed Timer.periodic callbacks would still fire and call setState
      // on the disposed PageState, surfacing as a FlutterError.
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    },
  );
}
