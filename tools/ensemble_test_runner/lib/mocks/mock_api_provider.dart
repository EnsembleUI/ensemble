import 'dart:convert';

import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
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

/// Records API calls and returns YAML-configured mock responses by API name.
class MockAPIProvider extends HTTPAPIProvider {
  MockAPIProvider({
    required Map<String, MockAPIResponse> mocks,
    HTTPAPIProvider? delegate,
  })  : _mocks = mocks,
        _delegate = delegate ?? HTTPAPIProvider();

  final Map<String, MockAPIResponse> _mocks;
  final HTTPAPIProvider _delegate;
  final List<APICallRecord> calls = [];

  int callCount(String apiName) =>
      calls.where((c) => c.name == apiName).length;

  List<APICallRecord> callsFor(String apiName) =>
      calls.where((c) => c.name == apiName).toList();

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
      return _delegate.invokeApi(context, api, eContext, apiName);
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

  @override
  Future<HttpResponse> invokeMockAPI(DataContext eContext, dynamic mock) =>
      _delegate.invokeMockAPI(eContext, mock);

  /// Same instance as config — keeps call recording aligned with [EnsembleTestContext].
  @override
  MockAPIProvider clone() => this;

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
