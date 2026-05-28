import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/view/page.dart' as ensemble;
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:yaml/yaml.dart';

SinglePageModel _pageModelWithStorageHeader({
  bool listenTitleBarHeightStorage = false,
  bool collapsibleHeader = false,
}) {
  final headerStyles = <String, dynamic>{
    if (listenTitleBarHeightStorage) ...{
      'listenTitleBarHeightStorage': true,
      'titleBarHeight': r'${ensemble.storage.headerHeight}',
    },
  };

  final header = <String, dynamic>{
    'title': 'Test Page',
    'styles': headerStyles,
    if (collapsibleHeader)
      'collapsibleHeader': {
        'enabled': true,
        'visible': r'${ensemble.storage.headerVisible}',
      },
  };

  return ScreenDefinition(YamlMap.wrap({
    'View': {
      'header': header,
      'body': {
        'Text': {'text': 'Body'},
      },
    },
  })).getModel(null) as SinglePageModel;
}

Widget _wrapPage(SinglePageModel pageModel) {
  return MaterialApp(
    navigatorKey: Utils.globalAppKey,
    home: Builder(
      builder: (context) {
        return ensemble.Page(
          dataContext: DataContext(buildContext: context),
          pageModel: pageModel,
          onRendered: () {},
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/tmp';
        }
        if (methodCall.method == 'getTemporaryDirectory') {
          return '/tmp';
        }
        return null;
      },
    );
  });

  setUp(() async {
    await GetStorage.init();
    await GetStorage.init('system');
    await StorageManager().init();
    await StorageManager().write('headerHeight', 56);
    await StorageManager().write('headerVisible', true);
  });

  tearDown(() async {
    await StorageManager().clearPublicStorage();
  });

  testWidgets('storage-bound titleBarHeight poll updates AppBar while mounted',
      (tester) async {
    await tester.pumpWidget(
      _wrapPage(_pageModelWithStorageHeader(listenTitleBarHeightStorage: true)),
    );
    await tester.pump();

    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 56);

    await StorageManager().write('headerHeight', 72);
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 72);
  });

  testWidgets('Page dispose cancels titleBarHeight storage poll timers',
      (tester) async {
    await tester.pumpWidget(
      _wrapPage(_pageModelWithStorageHeader(listenTitleBarHeightStorage: true)),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    await StorageManager().write('headerHeight', 96);
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Page dispose cancels collapsibleHeader visibility poll timers',
      (tester) async {
    await tester.pumpWidget(
      _wrapPage(_pageModelWithStorageHeader(collapsibleHeader: true)),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    await StorageManager().write('headerVisible', false);
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsibleHeader poll hides AppBar when storage visibility is false',
      (tester) async {
    await tester.pumpWidget(
      _wrapPage(_pageModelWithStorageHeader(collapsibleHeader: true)),
    );
    await tester.pump();

    expect(find.byType(AppBar), findsOneWidget);

    await StorageManager().write('headerVisible', false);
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 0);
  });
}
