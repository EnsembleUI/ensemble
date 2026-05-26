import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Regression coverage for [PageState] dispose: periodic timers and storage
/// subscriptions created for reactive header height / collapsible visibility
/// must be cancelled so callbacks never call [setState] after dispose.
void main() {
  testWidgets(
    'Page cancels title-bar height poll timer and storage listener on dispose',
    (tester) async {
      final doc = loadYaml(
        '''
View:
  body:
    Column:
      children:
        - Text:
            text: body
  header:
    titleText: Title
    styles:
      listenTitleBarHeightStorage: true
      titleBarHeight: ensemble.storage.tbHeight
''',
      ) as YamlMap;

      final model = PageModel.fromYaml(doc) as SinglePageModel;
      expect(model.headerModel, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Page(
              dataContext: DataContext(buildContext: context),
              pageModel: model,
              onRendered: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Page cancels collapsible header visibility poll timer on dispose',
    (tester) async {
      final doc = loadYaml(
        '''
View:
  body:
    Column:
      children:
        - Text:
            text: body
  header:
    titleText: Title
    styles:
      collapsibleHeader:
        enabled: true
        visible: ensemble.storage.hdrVis
''',
      ) as YamlMap;

      final model = PageModel.fromYaml(doc) as SinglePageModel;
      expect(model.headerModel, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Page(
              dataContext: DataContext(buildContext: context),
              pageModel: model,
              onRendered: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
    },
  );
}
