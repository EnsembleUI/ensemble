import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/view/page.dart' as ensemble_page;
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:yaml/yaml.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp';
}

SinglePageModel _pageModelWithHeaderStorageListeners() {
  return PageModel.fromYaml(YamlMap.wrap({
    'View': {
      'header': {
        'titleText': 'Test Page',
        'styles': {
          'listenTitleBarHeightStorage': true,
          'titleBarHeight': r'${ensemble.storage.get("headerHeight")}',
          'collapsibleHeader': {
            'enabled': true,
            'visible': r'${ensemble.storage.get("headerVisible")}',
          },
        },
      },
      'body': {
        'Text': {'text': 'Body'},
      },
    },
  })) as SinglePageModel;
}

Widget _wrapPage(SinglePageModel pageModel) {
  return MaterialApp(
    home: Builder(
      builder: (context) => ensemble_page.Page(
        dataContext: DataContext(buildContext: context),
        pageModel: pageModel,
        onRendered: () {},
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();

  setUpAll(() async {
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().write('headerHeight', 56);
    await GetStorage().write('headerVisible', true);
  });

  tearDown(() async {
    await GetStorage().erase();
  });

  testWidgets(
    'registers one title bar storage listener instead of duplicate subscriptions',
    (tester) async {
      await tester.pumpWidget(_wrapPage(_pageModelWithHeaderStorageListeners()));
      await tester.pump();

      final state =
          tester.state<ensemble_page.PageState>(find.byType(ensemble_page.Page));
      expect(state.hasTitleBarHeightStorageSubscription, isTrue);
      expect(state.hasHeaderVisibilityStorageSubscription, isTrue);
      expect(state.isTitleBarHeightPollTimerActive, isTrue);
      expect(state.isHeaderVisibilityPollTimerActive, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancels header poll timers and subscriptions on dispose',
      (tester) async {
    await tester.pumpWidget(_wrapPage(_pageModelWithHeaderStorageListeners()));
    await tester.pump();

    final state =
        tester.state<ensemble_page.PageState>(find.byType(ensemble_page.Page));
    expect(state.isTitleBarHeightPollTimerActive, isTrue);
    expect(state.isHeaderVisibilityPollTimerActive, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    // Timers were cancelled synchronously in dispose; advancing time must not
    // trigger setState on a disposed PageState.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
