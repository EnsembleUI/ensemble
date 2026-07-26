import 'dart:convert';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:http/http.dart' as http;

abstract final class HttpRequestAction {
  static Future<void> execute(Map<String, dynamic> args) async {
    final rawUrl = args['url']?.toString();
    if (rawUrl == null || rawUrl.isEmpty) {
      throw EnsembleTestFailure('httpRequest requires "url"');
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw EnsembleTestFailure('httpRequest has an invalid URL: $rawUrl');
    }

    final method = args['method']?.toString().toUpperCase() ?? 'GET';
    final headers = _headers(args['headers']);
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (args.containsKey('body')) {
      final body = args['body'];
      if (body is String) {
        request.body = body;
      } else {
        if (!_hasContentType(request.headers)) {
          request.headers['content-type'] = 'application/json';
        }
        request.body = jsonEncode(body);
      }
    }

    final timeoutMs = _positiveInt(args['timeoutMs'], fallback: 10000);
    final client = http.Client();
    try {
      final response = await LiveAsyncCallSupport.run<http.Response>(() async {
        final streamed = await client
            .send(request)
            .timeout(Duration(milliseconds: timeoutMs));
        return http.Response.fromStream(streamed);
      });
      if (response == null) {
        throw EnsembleTestFailure('httpRequest did not return a response');
      }

      final expectedStatus = args['expectStatus'];
      if (expectedStatus != null) {
        final expected = _positiveInt(expectedStatus);
        if (response.statusCode != expected) {
          throw EnsembleTestFailure(
            'httpRequest $method $rawUrl expected status $expected, got '
            '${response.statusCode}: ${response.body}',
          );
        }
      } else if (response.statusCode < 200 || response.statusCode >= 300) {
        throw EnsembleTestFailure(
          'httpRequest $method $rawUrl failed with status '
          '${response.statusCode}: ${response.body}',
        );
      }

      final expectedBody = args['expectBodyContains']?.toString();
      if (expectedBody != null && !response.body.contains(expectedBody)) {
        throw EnsembleTestFailure(
          'httpRequest $method $rawUrl response did not contain '
          '"$expectedBody": ${response.body}',
        );
      }
    } on EnsembleTestFailure {
      rethrow;
    } catch (error) {
      throw EnsembleTestFailure('httpRequest $method $rawUrl failed: $error');
    } finally {
      client.close();
    }
  }

  static Map<String, String> _headers(dynamic node) {
    if (node == null) return const {};
    if (node is! Map) {
      throw EnsembleTestFailure('httpRequest "headers" must be a map');
    }
    return {
      for (final entry in node.entries)
        entry.key.toString(): entry.value.toString(),
    };
  }

  static int _positiveInt(dynamic value, {int? fallback}) {
    if (value == null && fallback != null) return fallback;
    final parsed = value is int ? value : int.tryParse(value.toString());
    if (parsed == null || parsed <= 0) {
      throw EnsembleTestFailure('Expected a positive integer, got "$value"');
    }
    return parsed;
  }

  static bool _hasContentType(Map<String, String> headers) => headers.keys.any(
        (key) => key.toLowerCase() == 'content-type',
      );
}
