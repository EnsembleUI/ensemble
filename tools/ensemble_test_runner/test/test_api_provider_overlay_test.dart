import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  testWidgets('unmocked firebase functions delegate to the real provider',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    final delegate = _RecordingAPIProvider();
    final provider = TestApiProviderOverlay(mocks: {});
    final context = tester.element(find.byType(SizedBox));
    final api =
        YamlMap.wrap({'type': 'firebaseFunction', 'name': 'exampleCallable'});

    await provider.invokeApiWithDelegate(
      delegate,
      context,
      api,
      DataContext(buildContext: context),
      'exampleCallable',
    );

    expect(delegate.invoked, isTrue);
    expect(provider.callCount('exampleCallable'), 1);
  });

  testWidgets('mocked APIs return configured responses without delegating',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    final delegate = _RecordingAPIProvider();
    final provider = TestApiProviderOverlay(
      mocks: {
        'login': MockAPIResponse(statusCode: 200, body: {'token': 'abc'}),
      },
      delegate: delegate,
    );
    final context = tester.element(find.byType(SizedBox));
    final response = await provider.invokeApi(
      context,
      YamlMap.wrap({'type': 'http', 'url': 'https://example.test/login'}),
      DataContext(buildContext: context),
      'login',
    );

    expect(delegate.invoked, isFalse);
    expect(response.body, {'token': 'abc'});
  });

  test('serializes live runner calls to avoid reentrant runAsync', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final delegate = _ConcurrentRecordingAPIProvider(
      onStart: () {
        inFlight++;
        if (inFlight > maxInFlight) {
          maxInFlight = inFlight;
        }
      },
      onEnd: () {
        inFlight--;
      },
    );
    final provider = TestApiProviderOverlay(mocks: {}, delegate: delegate);
    provider.liveAsyncRunner = <T>(Future<T> Function() fn) => fn();

    final buildContext = _FakeBuildContext();
    final first = provider.invokeApiWithDelegate(
      delegate,
      buildContext,
      YamlMap.wrap({'type': 'http', 'url': 'https://example.test/a'}),
      DataContext(buildContext: buildContext),
      'first',
    );
    final second = provider.invokeApiWithDelegate(
      delegate,
      buildContext,
      YamlMap.wrap({'type': 'http', 'url': 'https://example.test/b'}),
      DataContext(buildContext: buildContext),
      'second',
    );

    await Future.wait([first, second]);
    expect(maxInFlight, 1);
    expect(delegate.invoked, 2);
  });
}

class _ConcurrentRecordingAPIProvider extends HTTPAPIProvider {
  _ConcurrentRecordingAPIProvider({
    required this.onStart,
    required this.onEnd,
  });

  final void Function() onStart;
  final void Function() onEnd;
  int invoked = 0;

  @override
  Future<HttpResponse> invokeApi(
    BuildContext context,
    YamlMap api,
    DataContext eContext,
    String apiName,
  ) async {
    onStart();
    invoked++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    onEnd();
    return HttpResponse.fromBody(
      {'ok': true},
      {'Content-Type': 'application/json'},
      200,
      null,
      APIState.success,
    );
  }
}

class _RecordingAPIProvider extends HTTPAPIProvider {
  bool invoked = false;

  @override
  Future<HttpResponse> invokeApi(
    BuildContext context,
    YamlMap api,
    DataContext eContext,
    String apiName,
  ) async {
    invoked = true;
    return HttpResponse.fromBody(
      {'ok': true},
      {'Content-Type': 'application/json'},
      200,
      null,
      APIState.success,
    );
  }
}

class _FakeBuildContext extends Fake implements BuildContext {}
