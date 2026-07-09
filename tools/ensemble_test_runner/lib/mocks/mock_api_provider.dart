import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final dynamic body;
  final Map<String, String>? query;
  final Map<String, String>? headers;

  APICallRecord({
    required this.name,
    required this.apiDefinition,
    required this.timestamp,
    this.body,
    this.query,
    this.headers,
  });
}

/// Records API calls, returns YAML mocks when configured, otherwise delegates.
class MockAPIProvider extends HTTPAPIProvider {
  MockAPIProvider({
    required Map<String, MockAPIResponse> mocks,
    HTTPAPIProvider? delegate,
  })  : _mocks = mocks,
        _delegate = delegate ?? HTTPAPIProvider();

  final Map<String, MockAPIResponse> _mocks;
  HTTPAPIProvider _delegate;
  final List<APICallRecord> calls = [];
  Future<T?> Function<T>(Future<T> Function())? liveAsyncRunner;

  int callCount(String apiName) => calls.where((c) => c.name == apiName).length;

  List<APICallRecord> callsFor(String apiName) =>
      calls.where((c) => c.name == apiName).toList();

  void bindHttpDelegate(HTTPAPIProvider delegate) {
    _delegate = delegate;
  }

  void setMock(String apiName, MockAPIResponse response) {
    _mocks[apiName] = response;
  }

  void resetCalls() => calls.clear();

  void clearMocks() => _mocks.clear();

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

  /// When true, [invokeApi] returns an offline error without calling the delegate.
  bool simulateNetworkOffline = false;

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
    if (simulateNetworkOffline) {
      calls.add(APICallRecord(
        name: apiName,
        apiDefinition: api,
        timestamp: DateTime.now(),
      ));
      return HttpResponse.fromBody(
        {'message': 'Network offline (test)'},
        null,
        503,
        null,
        APIState.error,
      );
    }

    final forced = _forcedExceptions[apiName];
    if (forced != null) {
      calls.add(APICallRecord(
        name: apiName,
        apiDefinition: api,
        timestamp: DateTime.now(),
      ));
      throw forced;
    }

    final captured = _captureRequest(api, eContext);
    calls.add(APICallRecord(
      name: apiName,
      apiDefinition: api,
      timestamp: DateTime.now(),
      body: captured.body,
      query: captured.query,
      headers: captured.headers,
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

    if (mock.delayMs != null && mock.delayMs! > 0) {
      await Future<void>.delayed(Duration(milliseconds: mock.delayMs!));
    }

    return HttpResponse.fromBody(
      mock.body,
      mock.headers?.map((k, v) => MapEntry(k, v.toString())),
      mock.statusCode,
      null,
      APIState.success,
    );
  }

  Future<Response> _invokeLiveDelegate(
    APIProvider delegate,
    BuildContext context,
    YamlMap api,
    DataContext eContext,
    String apiName,
  ) async {
    final runner = liveAsyncRunner;
    Future<Response> call() async {
      final savedOverrides = _clearHttpOverridesForLiveHttps(api, eContext);
      try {
        return await delegate.invokeApi(context, api, eContext, apiName);
      } finally {
        _restoreHttpOverrides(savedOverrides);
      }
    }

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

  /// Remote HTTPS endpoints (e.g. api.acc.kpn.com) fail TLS under the test
  /// harness [HttpOverrides]. Local HTTP gateways still need those overrides.
  HttpOverrides? _clearHttpOverridesForLiveHttps(
    YamlMap api,
    DataContext eContext,
  ) {
    final rawUrl = (api['url'] ?? api['uri'] ?? '').toString().trim();
    if (rawUrl.isEmpty) {
      return null;
    }
    final url = HTTPAPIProvider.resolveUrl(eContext, rawUrl);
    final uri = Uri.tryParse(url);
    if (uri?.scheme != 'https') {
      return null;
    }
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    return saved;
  }

  void _restoreHttpOverrides(HttpOverrides? saved) {
    if (saved != null) {
      HttpOverrides.global = saved;
    }
  }

  @override
  Future<HttpResponse> invokeMockAPI(DataContext eContext, dynamic mock) =>
      _delegate.invokeMockAPI(eContext, mock);

  /// Same instance as config — keeps call recording aligned with [EnsembleTestContext].
  @override
  MockAPIProvider clone() => this;

  @override
  void dispose() => _delegate.dispose();
}

/// Delegates to a real provider unless [host] has a mock for the API name.
class ApiMockOverlay implements APIProvider {
  ApiMockOverlay(this._host, this._delegate);

  final MockAPIProvider _host;
  final APIProvider _delegate;

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
  ApiMockOverlay clone() => ApiMockOverlay(_host, _delegate.clone());

  @override
  void dispose() => _delegate.dispose();
}

class _CapturedRequest {
  final dynamic body;
  final Map<String, String>? query;
  final Map<String, String>? headers;

  const _CapturedRequest({this.body, this.query, this.headers});
}

_CapturedRequest _captureRequest(YamlMap api, DataContext eContext) {
  Map<String, String>? headers;
  if (api['headers'] is YamlMap) {
    headers = {};
    (api['headers'] as YamlMap).forEach((key, value) {
      if (value != null) {
        headers![key.toString().toLowerCase()] =
            eContext.eval(value)?.toString() ?? '';
      }
    });
  }

  dynamic body;
  if (api['body'] != null) {
    final evaluated = eContext.eval(api['body']);
    if (evaluated is Map || evaluated is List) {
      body = evaluated;
    } else if (evaluated is String) {
      try {
        body = json.decode(evaluated);
      } catch (_) {
        body = evaluated;
      }
    } else {
      body = evaluated;
    }
  }

  Map<String, String>? query;
  if (api['parameters'] is YamlMap) {
    query = {};
    (api['parameters'] as YamlMap).forEach((key, value) {
      query![key.toString()] = eContext.eval(value)?.toString() ?? '';
    });
  }

  return _CapturedRequest(body: body, query: query, headers: headers);
}
