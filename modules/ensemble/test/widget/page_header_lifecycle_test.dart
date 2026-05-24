import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// Regression coverage for PageState header storage listeners: periodic timers
/// and stream subscriptions must be cancelled on dispose so teardown does not
/// tick after the widget tree is torn down (see fix in page.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    EnsembleThemeManager().reset();
  });

  SinglePageModel modelWithStorageDrivenHeader() {
    final yaml = YamlMap.wrap({
      'View': YamlMap.wrap({
        'header': YamlMap.wrap({
          'titleText': 'T',
          'styles': YamlMap.wrap({
            'listenTitleBarHeightStorage': true,
            'titleBarHeight': 'ensemble.storage.tb_h',
          }),
          'collapsibleHeader': YamlMap.wrap({
            'enabled': true,
            'visible': 'ensemble.storage.coll_vis',
          }),
        }),
        'body': YamlMap.wrap({
          'Text': YamlMap.wrap({'text': 'body'}),
        }),
      }),
    });
    return PageModel.fromYaml(yaml) as SinglePageModel;
  }

  testWidgets(
      'Page with storage-driven header disposes without timer or subscription leaks',
      (tester) async {
    EnsembleThemeManager().reset();

    final pageModel = modelWithStorageDrivenHeader();
    final dataContext = DataContext(buildContext: MockBuildContext());

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Utils.globalAppKey,
        home: Page(
          dataContext: dataContext,
          pageModel: pageModel,
          onRendered: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Utils.globalAppKey,
        home: const SizedBox.shrink(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}
