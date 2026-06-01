import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/view/page.dart' as ensemble_page;
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late SinglePageModel pageModel;

  setUp(() {
    pageModel = PageModel.fromYaml(YamlMap.wrap({
      'View': {
        'header': {
          'titleText': 'Header',
          'styles': {
            'collapsibleHeader': {
              'enabled': true,
              'visible': 'ensemble.storage.headerVisible',
            },
          },
        },
        'body': {
          'Text': {'text': 'body'},
        },
      },
    })) as SinglePageModel;
  });

  testWidgets(
      'PageState cancels header storage listeners and poll timers on dispose',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ensemble_page.Page(
              dataContext: DataContext(buildContext: context),
              pageModel: pageModel,
              onRendered: () {},
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
