import 'dart:async';

import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:flutter/widgets.dart';
import 'package:yaml/yaml.dart';

class APICallRecord {
  final String name;
  final YamlMap apiDefinition;
  final DateTime timestamp;

  APICallRecord({
    required this.name,
    required this.apiDefinition,
    required this.timestamp,
  });
}

class ApiCallRecorder {
  final List<APICallRecord> calls = [];

  int callCount(String apiName) => calls.where((c) => c.name == apiName).length;

  List<APICallRecord> callsFor(String apiName) =>
      calls.where((c) => c.name == apiName).toList();

  void record(APICallRecord call) => calls.add(call);

  void reset() => calls.clear();
}

/// Test provider overlay: observes API calls, applies test overrides, otherwise delegates.
class TestApiProviderOverlay extends HTTPAPIProvider {
  TestApiProviderOverlay({
    required Map<String, MockAPIResponse> mocks,
    HTTPAPIProvider? delegate,
    ApiCallRecorder? recorder,
  })  : _mocks = mocks,
        _delegate = delegate ?? HTTPAPIProvider(),
        recorder = recorder ?? ApiCallRecorder();

  final Map<String, MockAPIResponse> _mocks;
  HTTPAPIProvider _delegate;
  HTTPAPIProvider get delegate => _delegate;
  final ApiCallRecorder recorder;
  Future<T?> Function<T>(Future<T> Function())? liveAsyncRunner;
  final Map<String, int> _mockCallIndexes = {};

  List<APICallRecord> get calls => recorder.calls;

  int callCount(String apiName) => recorder.callCount(apiName);

  List<APICallRecord> callsFor(String apiName) => recorder.callsFor(apiName);

  bool hasMock(String apiName) => _mocks.containsKey(apiName);

  void bindHttpDelegate(HTTPAPIProvider delegate) {
    _delegate = delegate;
  }

  void setMock(String apiName, MockAPIResponse response) {
    _mocks[apiName] = response;
    _mockCallIndexes.remove(apiName);
  }

  void resetCalls() => recorder.reset();

  void clearMocks() {
    _mocks.clear();
    _mockCallIndexes.clear();
  }

  final Map<String, Exception> _forcedExceptions = {};

  void setApiException(String apiName, Exception error) {
    _forcedExceptions[apiName] = error;
  }

  void clearApiExceptions() => _forcedExceptions.clear();

  bool get hasPendingLiveCalls => LiveAsyncCallSupport.hasPendingLiveCalls;

  Future<void> waitForLiveCalls() => LiveAsyncCallSupport.waitForLiveCalls();

  @override
  Future<void> init(String appId, Map<String, dynamic> config) =>
      _delegate.init(appId, config);

  @override
  Future<HttpResponse> invokeApi(
    BuildContext context,
    YamlMap api,
    DataContext eContext,
    String apiName,
  ) async {
    final response = await invokeApiWithDelegate(
      _delegate,
      context,
      api,
      eContext,
      apiName,
    );
    if (response is HttpResponse) {
      return response;
    }
    return HttpResponse.fromBody(
      response.body,
      response.headers?.map((k, v) => MapEntry(k, v.toString())),
      response.statusCode,
      response.reasonPhrase,
      response.apiState,
    );
  }

  Future<Response> invokeApiWithDelegate(
    APIProvider delegate,
    BuildContext context,
    YamlMap api,
    DataContext eContext,
    String apiName,
  ) async {
    final forced = _forcedExceptions[apiName];
    if (forced != null) {
      recorder.record(APICallRecord(
        name: apiName,
        apiDefinition: api,
        timestamp: DateTime.now(),
      ));
      throw forced;
    }

    recorder.record(APICallRecord(
      name: apiName,
      apiDefinition: api,
      timestamp: DateTime.now(),
    ));

    final mock = _mocks[apiName];
    if (mock == null) {
      return _invokeLiveDelegate(
        delegate,
        context,
        api,
        eContext,
        apiName,
      );
    }

    final response = _nextMockResponse(apiName, mock);
    if (response.delayMs != null && response.delayMs! > 0) {
      await Future<void>.delayed(Duration(milliseconds: response.delayMs!));
    }

    if (delegate is HTTPAPIProvider) {
      return delegate.invokeMockAPI(eContext, _toRuntimeMockResponse(response));
    }
    return HttpResponse.fromBody(
      response.body,
      response.headers,
      response.statusCode,
      null,
      APIState.success,
    );
  }

  MockAPIResponse _nextMockResponse(String apiName, MockAPIResponse mock) {
    final responses = mock.responses;
    if (responses.isEmpty) return mock;

    final index = _mockCallIndexes[apiName] ?? 0;
    _mockCallIndexes[apiName] = index + 1;
    return responses[index < responses.length ? index : responses.length - 1];
  }

  Future<Response> _invokeLiveDelegate(
    APIProvider delegate,
    BuildContext context,
    YamlMap api,
    DataContext eContext,
    String apiName,
  ) async {
    final runner = liveAsyncRunner;
    Future<Response> call() =>
        delegate.invokeApi(context, api, eContext, apiName);

    if (runner != null) {
      try {
        final response = await _runLiveApiCall<Response>(call);
        if (response != null) {
          return response;
        }
        return HttpResponse.fromBody(
          'Live API call did not return a response.',
          {'Content-Type': 'text/plain'},
          500,
          'Internal Server Error',
          APIState.error,
        );
      } catch (error) {
        return HttpResponse.fromBody(
          'Unexpected error: $error.',
          {'Content-Type': 'text/plain'},
          500,
          'Internal Server Error',
          APIState.error,
        );
      }
    }

    return call();
  }

  Future<T?> _runLiveApiCall<T>(Future<T> Function() call) {
    LiveAsyncCallSupport.runner ??= liveAsyncRunner;
    return LiveAsyncCallSupport.run(call);
  }

  @override
  Future<HttpResponse> invokeMockAPI(DataContext eContext, dynamic mock) =>
      _delegate.invokeMockAPI(eContext, mock);

  /// Same instance as config — keeps call recording aligned with [EnsembleTestContext].
  @override
  TestApiProviderOverlay clone() => this;

  @override
  void dispose() => _delegate.dispose();
}

/// Delegates to a real provider unless [host] has a test override for the API name.
class TestApiOverlay implements APIProvider {
  TestApiOverlay(this._host, this._delegate);

  final TestApiProviderOverlay _host;
  final APIProvider _delegate;
  APIProvider get delegate => _delegate;

  @override
  Future<void> init(String appId, Map<String, dynamic> config) =>
      _delegate.init(appId, config);

  @override
  Future<Response> invokeApi(
    BuildContext context,
    YamlMap api,
    DataContext eContext,
    String apiName,
  ) {
    return _host.invokeApiWithDelegate(
      _delegate,
      context,
      api,
      eContext,
      apiName,
    );
  }

  @override
  Future<Response> invokeMockAPI(DataContext eContext, dynamic mock) =>
      _delegate.invokeMockAPI(eContext, mock);

  @override
  TestApiOverlay clone() => TestApiOverlay(_host, _delegate.clone());

  @override
  void dispose() => _delegate.dispose();
}

Map<String, dynamic> _toRuntimeMockResponse(MockAPIResponse mock) {
  return <String, dynamic>{
    'body': mock.body,
    if (mock.headers != null) 'headers': mock.headers,
    'statusCode': mock.statusCode,
  };
}
