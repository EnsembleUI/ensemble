import 'dart:async';

import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

  test('records raw non-JSON HTTP response bodies for diagnostics', () async {
    final delegate = _RawBodyAPIProvider('upstream response');
    final provider = TestApiProviderOverlay(mocks: {});

    await provider.invokeApiWithDelegate(
      delegate,
      _FakeBuildContext(),
      YamlMap.wrap({'type': 'http', 'url': 'https://example.test/status'}),
      DataContext(buildContext: _FakeBuildContext()),
      'status',
    );

    final call = provider.calls.single;
    expect(call.statusCode, 200);
    expect(call.responseBody, 'upstream response');
  });

  test('records provider invocation duration', () async {
    LiveAsyncCallSupport.reset();
    addTearDown(LiveAsyncCallSupport.reset);
    final delegate = _ConcurrentRecordingAPIProvider(
      onStart: () {},
      onEnd: () {},
    );
    final provider = TestApiProviderOverlay(mocks: {});
    provider.liveAsyncRunner = <T>(call) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return call();
    };

    await provider.invokeApiWithDelegate(
      delegate,
      _FakeBuildContext(),
      YamlMap.wrap({'type': 'http', 'url': 'https://example.test/status'}),
      DataContext(buildContext: _FakeBuildContext()),
      'status',
    );

    final call = provider.calls.single;
    expect(call.providerDurationMs, greaterThanOrEqualTo(45));
  });

  test('mocked APIs honor delayMs before returning', () async {
    final delegate = _RecordingAPIProvider();
    final provider = TestApiProviderOverlay(
      mocks: {
        'slowProfile': MockAPIResponse(
          statusCode: 200,
          body: {'name': 'Jane'},
          delayMs: 50,
        ),
      },
      delegate: delegate,
    );
    final context = _FakeBuildContext();
    var completed = false;

    final responseFuture = provider
        .invokeApiWithDelegate(
      delegate,
      context,
      YamlMap.wrap({'type': 'http', 'url': 'https://example.test/profile'}),
      DataContext(buildContext: context),
      'slowProfile',
    )
        .then((response) {
      completed = true;
      return response;
    });

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(completed, isFalse);

    final response = await responseFuture;
    expect(completed, isTrue);
    expect(delegate.invoked, isFalse);
    expect(response.body, {'name': 'Jane'});
    final recordedCall = provider.callsFor('slowProfile').single;
    expect(recordedCall.completed, isTrue);
    expect(recordedCall.providerDurationMs, greaterThanOrEqualTo(45));
  });

  test('mocked API sequences return responses in call order', () async {
    final delegate = _RecordingAPIProvider();
    final provider = TestApiProviderOverlay(
      mocks: {
        'profile': MockAPIResponse(
          responses: const [
            MockAPIResponse(body: {'name': 'first'}),
            MockAPIResponse(body: {'name': 'second'}),
          ],
        ),
      },
      delegate: delegate,
    );
    final context = _FakeBuildContext();

    final first = await provider.invokeApiWithDelegate(
      delegate,
      context,
      YamlMap.wrap({'type': 'http', 'url': 'https://example.test/profile'}),
      DataContext(buildContext: context),
      'profile',
    );
    final second = await provider.invokeApiWithDelegate(
      delegate,
      context,
      YamlMap.wrap({'type': 'http', 'url': 'https://example.test/profile'}),
      DataContext(buildContext: context),
      'profile',
    );
    final third = await provider.invokeApiWithDelegate(
      delegate,
      context,
      YamlMap.wrap({'type': 'http', 'url': 'https://example.test/profile'}),
      DataContext(buildContext: context),
      'profile',
    );

    expect(delegate.invoked, isFalse);
    expect(first.body, {'name': 'first'});
    expect(second.body, {'name': 'second'});
    expect(third.body, {'name': 'second'});
  });

  test('mocked non-http APIs return configured responses without delegating',
      () async {
    final delegate = _RecordingGenericAPIProvider();
    final provider = TestApiProviderOverlay(
      mocks: {
        'listenForRecommendations': MockAPIResponse(
          body: {
            'document': {'active': []},
          },
        ),
      },
    );
    final context = _FakeBuildContext();

    final response = await provider.invokeApiWithDelegate(
      delegate,
      context,
      YamlMap.wrap(
          {'type': 'firestore', 'path': 'users/u/recommendations/current'}),
      DataContext(buildContext: context),
      'listenForRecommendations',
    );

    expect(delegate.invoked, isFalse);
    expect(response.body, {
      'document': {'active': []},
    });
  });

  test(
      'successful non-http responses complete API records without status codes',
      () async {
    final delegate = _FirestoreLikeAPIProvider();
    final provider = TestApiProviderOverlay(mocks: {});
    final context = _FakeBuildContext();

    await provider.invokeApiWithDelegate(
      delegate,
      context,
      YamlMap.wrap({'type': 'firestore', 'path': 'teams'}),
      DataContext(buildContext: context),
      'getTeams',
    );

    final record = provider.calls.single;
    expect(record.statusCode, isNull);
    expect(record.error, isNull);
    expect(record.isCompleted, isTrue);
  });

  test('batches live runner calls into one non-reentrant runAsync scope',
      () async {
    var providerInFlight = 0;
    var maxProviderInFlight = 0;
    var runnerInFlight = 0;
    var maxRunnerInFlight = 0;
    var runnerInvocations = 0;
    final delegate = _ConcurrentRecordingAPIProvider(
      onStart: () {
        providerInFlight++;
        if (providerInFlight > maxProviderInFlight) {
          maxProviderInFlight = providerInFlight;
        }
      },
      onEnd: () {
        providerInFlight--;
      },
    );
    final provider = TestApiProviderOverlay(mocks: {}, delegate: delegate);
    provider.liveAsyncRunner = <T>(Future<T> Function() fn) async {
      runnerInvocations++;
      runnerInFlight++;
      if (runnerInFlight > maxRunnerInFlight) {
        maxRunnerInFlight = runnerInFlight;
      }
      try {
        return await fn();
      } finally {
        runnerInFlight--;
      }
    };

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
    expect(runnerInvocations, 1);
    expect(maxRunnerInFlight, 1);
    expect(maxProviderInFlight, 2);
    expect(delegate.invoked, 2);
  });

  test('untracked runAsync work serializes without blocking live waits',
      () async {
    final events = <String>[];
    final gate = Completer<void>();
    LiveAsyncCallSupport.runner = <T>(Future<T> Function() fn) => fn();

    try {
      final artifact = LiveAsyncCallSupport.runUntracked<void>(() async {
        events.add('artifact-start');
        await gate.future;
        events.add('artifact-end');
      });
      await Future<void>.delayed(Duration.zero);

      expect(LiveAsyncCallSupport.hasPendingLiveCalls, isFalse);
      await LiveAsyncCallSupport.waitForLiveCalls();
      expect(events, ['artifact-start']);

      final live = LiveAsyncCallSupport.run<void>(() async {
        events.add('live');
      });

      expect(LiveAsyncCallSupport.hasPendingLiveCalls, isTrue);
      expect(LiveAsyncCallSupport.pendingLiveCallCount, 1);
      gate.complete();
      await Future.wait([artifact, live]);

      expect(events, ['artifact-start', 'artifact-end', 'live']);
      expect(LiveAsyncCallSupport.hasPendingLiveCalls, isFalse);
      expect(LiveAsyncCallSupport.pendingLiveCallCount, 0);
    } finally {
      LiveAsyncCallSupport.reset();
    }
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

class _RawBodyAPIProvider extends HTTPAPIProvider {
  _RawBodyAPIProvider(this.rawBody);

  final String rawBody;

  @override
  Future<HttpResponse> invokeApi(
    BuildContext context,
    YamlMap api,
    DataContext eContext,
    String apiName,
  ) async =>
      HttpResponse(
        http.Response(rawBody, 200, headers: {'content-type': 'text/plain'}),
        APIState.success,
      );
}

class _RecordingGenericAPIProvider implements APIProvider {
  bool invoked = false;

  @override
  Future<void> init(String appId, Map<String, dynamic> config) async {}

  @override
  Future<Response> invokeApi(
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

  @override
  Future<Response> invokeMockAPI(DataContext eContext, dynamic mock) {
    throw UnimplementedError();
  }

  @override
  APIProvider clone() => this;

  @override
  void dispose() {}
}

class _FirestoreLikeAPIProvider extends _RecordingGenericAPIProvider {
  @override
  Future<Response> invokeApi(
    BuildContext context,
    YamlMap api,
    DataContext eContext,
    String apiName,
  ) async {
    invoked = true;
    return _FirestoreLikeResponse();
  }
}

class _FirestoreLikeResponse extends Response {
  _FirestoreLikeResponse() {
    apiState = APIState.success;
    body = {'documents': []};
    apiName = 'getTeams';
  }
}

class _FakeBuildContext extends Fake implements BuildContext {}
