import 'dart:async';
import 'dart:io';

import 'package:ensemble/action/invoke_api_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:yaml/yaml.dart';

/// A provider whose `invokeApi` completion is controlled by the test.
class _FakeProvider extends APIProvider {
  final Completer<Response> completer = Completer<Response>();

  @override
  Future<void> init(String appId, Map<String, dynamic> config) async {}

  @override
  Future<Response> invokeApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName) {
    return completer.future;
  }

  @override
  Future<Response> invokeMockAPI(DataContext eContext, dynamic mock) async =>
      _FakeResponse();

  @override
  APIProvider clone() => _FakeProvider();

  @override
  dispose() {}
}

class _FakeResponse extends Response {}

/// A live provider (SSE/Firestore-like) whose subscription keeps a listener
/// that can be invoked repeatedly, independent of the page lifecycle.
class _FakeLiveProvider extends APIProvider with LiveAPIProvider {
  ResponseListener? listener;

  @override
  Future<void> init(String appId, Map<String, dynamic> config) async {}

  @override
  Future<Response> invokeApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName) async {
    throw UnsupportedError('live provider');
  }

  @override
  Future<Response> subscribeToApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName, ResponseListener l) async {
    listener = l;
    return _FakeResponse();
  }

  @override
  Future<Response> invokeMockAPI(DataContext eContext, dynamic mock) async =>
      _FakeResponse();

  @override
  APIProvider clone() => _FakeLiveProvider();

  @override
  dispose() {}
}

/// Counts how many times it is executed, so tests can observe onResponse.
class _CountingAction extends EnsembleAction {
  int count = 0;

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) async {
    count++;
  }
}

/// Builds a widget tree exposing a ScopeManager and an APIProviders map, and
/// returns the scope plus the element context used to execute actions.
Future<(ScopeManager, BuildContext)> _pumpScope(
    WidgetTester tester, _FakeProvider fake) async {
  late ScopeManager scope;
  await tester.pumpWidget(APIProviders(
    providers: {'fake': fake},
    child: MaterialApp(
      home: Builder(builder: (context) {
        scope = ScopeManager(
          DataContext(buildContext: context),
          PageData(apiMap: {
            'myApi': YamlMap.wrap(
                {'type': 'fake', 'url': 'https://example.com/api'}),
          }),
        );
        scope.dataContext.addInvokableContext('myApi', APIResponse());
        return DataScopeWidget(
            scopeManager: scope, child: const SizedBox(width: 1, height: 1));
      }),
    ),
  ));
  final ctx = tester.element(find.byType(SizedBox));
  return (scope, ctx);
}

void main() {
  late Directory storageDir;

  // AppConfig.isMockResponse() reads GetStorage; construct it before the
  // fake-async test zone so GetStorage does not leave a pending timer.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDir = await Directory.systemTemp.createTemp('ensemble-api-guard-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => storageDir.path);
    await GetStorage.init();
  });

  tearDownAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await storageDir.delete(recursive: true);
  });

  testWidgets('child scope dispose does not mark the page disposed',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final pageData = PageData();
    final scope = ScopeManager(DataContext(buildContext: context), pageData);
    final child = scope.createChildScope();

    child.dispose();
    expect(pageData.isDisposed, isFalse,
        reason: 'disposing a child scope must not mark the page disposed');

    scope.dispose();
    expect(pageData.isDisposed, isTrue);
  });

  testWidgets('API onResponse runs while the page is live', (tester) async {
    final fake = _FakeProvider();
    final counting = _CountingAction();
    final (scope, ctx) = await _pumpScope(tester, fake);

    final action = InvokeAPIAction(apiName: 'myApi', onResponse: counting);
    final future = InvokeAPIController()
        .execute(action, ctx, scope, scope.pageData.apiMap);

    fake.completer.complete(_FakeResponse()..apiState = APIState.loading);
    await future;
    await tester.pump();

    expect(counting.count, 1, reason: 'onResponse must run for a live page');
    expect(scope.pageData.isDisposed, isFalse);
    scope.dispose();
  });

  testWidgets('API onError runs while the page is live', (tester) async {
    final fake = _FakeProvider();
    final counting = _CountingAction();
    final (scope, ctx) = await _pumpScope(tester, fake);

    final action = InvokeAPIAction(apiName: 'myApi', onError: counting);
    final future = InvokeAPIController()
        .execute(action, ctx, scope, scope.pageData.apiMap);

    fake.completer.complete(_FakeResponse()..isOkay = false);
    await future;
    await tester.pump();

    expect(counting.count, 1, reason: 'onError must run for a live page');
    expect(scope.pageData.isDisposed, isFalse);
    scope.dispose();
  });

  testWidgets('API onResponse is skipped after the page is disposed',
      (tester) async {
    final fake = _FakeProvider();
    final counting = _CountingAction();
    final (scope, ctx) = await _pumpScope(tester, fake);

    final action = InvokeAPIAction(apiName: 'myApi', onResponse: counting);
    final future = InvokeAPIController()
        .execute(action, ctx, scope, scope.pageData.apiMap);

    // Simulate navigating away before the in-flight API completes.
    scope.dispose();
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(scope.pageData.isDisposed, isTrue);

    fake.completer.complete(_FakeResponse()..apiState = APIState.loading);
    await future;
    await tester.pump();

    expect(counting.count, 0,
        reason: 'onResponse must not run once the page is disposed');
  });

  testWidgets('API onError is skipped after the page is disposed',
      (tester) async {
    final fake = _FakeProvider();
    final counting = _CountingAction();
    final (scope, ctx) = await _pumpScope(tester, fake);

    final action = InvokeAPIAction(apiName: 'myApi', onError: counting);
    final future = InvokeAPIController()
        .execute(action, ctx, scope, scope.pageData.apiMap);

    scope.dispose();
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    final failed = _FakeResponse()..isOkay = false;
    fake.completer.complete(failed);
    await future;
    await tester.pump();

    expect(counting.count, 0,
        reason: 'onError must not run once the page is disposed');
  });

  testWidgets(
      'live provider events after dispose are ignored (subscription stays)',
      (tester) async {
    final live = _FakeLiveProvider();
    final counting = _CountingAction();
    late ScopeManager scope;
    await tester.pumpWidget(APIProviders(
      providers: {'fakeLive': live},
      child: MaterialApp(
        home: Builder(builder: (context) {
          scope = ScopeManager(
            DataContext(buildContext: context),
            PageData(apiMap: {
              'liveApi': YamlMap.wrap({
                'type': 'fakeLive',
                'listenForChanges': true,
                'url': 'https://example.com/sse',
              }),
            }),
          );
          scope.dataContext.addInvokableContext('liveApi', APIResponse());
          return DataScopeWidget(
              scopeManager: scope, child: const SizedBox(width: 1, height: 1));
        }),
      ),
    ));
    final ctx = tester.element(find.byType(SizedBox));
    final action = InvokeAPIAction(apiName: 'liveApi', onResponse: counting);

    await InvokeAPIController()
        .execute(action, ctx, scope, scope.pageData.apiMap);
    await tester.pump();
    expect(counting.count, 1,
        reason: 'initial live response runs while the page is mounted');

    scope.dispose();
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    // Simulate a streamed event arriving after the page is gone. The provider
    // still holds and can invoke the listener (its subscription is app-level
    // and never cancelled), but the framework must ignore the callback.
    live.listener!(_FakeResponse()..apiState = APIState.loading);
    await tester.pump();
    expect(counting.count, 1,
        reason: 'post-dispose live events must be ignored');
  });
}
