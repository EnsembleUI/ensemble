import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/stub/token_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/io_client.dart';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// Server-Sent Events (SSE) API Provider
/// Handles streaming HTTP connections
class SSEAPIProvider extends APIProvider with LiveAPIProvider {
  final List<StreamSubscription> _subscriptions = [];
  final Map<String, http.Client> _activeClients = {};

  @override
  Future<void> init(String appId, Map<String, dynamic> config) async {
    // SSE provider doesn't require initialization
  }

  @override
  Future<Response> invokeApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName) async {
    // For SSE, we should use subscribeToApi
    throw RuntimeError('SSE APIs should use subscribeToApi');
  }

  @override
  Future<Response> subscribeToApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName, ResponseListener listener) async {
    // Prepare headers
    Map<String, String> headers = {};
    DataContext clonedContext = eContext;

    // Check if we need to update clone context for secure storage
    if (_containsSecureStorageReference(api)) {
      final Map<String, dynamic> secureStorageData =
          await StorageManager().getAllFromKeychain();

      final Map<String, dynamic> contextWrapper = {
        'apiSecureStorage': secureStorageData,
      };

      clonedContext = eContext.clone(initialMap: contextWrapper);
    }

    // Handle OAuth authorization
    if (api['authorization'] != null && api['authorization'] != "none") {
      OAuthService? oAuthService = OAuthService.values
          .from(Utils.optionalString(api['authorization']?['oauthId']));
      String? scope = Utils.optionalString(api['authorization']?['scope']);
      bool forceNewTokens = Utils.getBool(
          api['authorization']?['forceNewTokens'],
          fallback: false);
      if (oAuthService != null && scope != null) {
        OAuthServiceToken? token = await GetIt.instance<OAuthController>()
            .authorize(context, oAuthService,
                scope: scope, forceNewTokens: forceNewTokens);
        if (token != null) {
          headers['authorization'] = 'Bearer ${token.accessToken}';
        }
      }

      // Bearer token support
      OAuthService? serviceName = OAuthService.values
          .from(Utils.optionalString(api['authorization']?['serviceId']));
      if (serviceName != null) {
        OAuthServiceToken? token =
            await GetIt.instance<TokenManager>().getServiceTokens(serviceName);
        if (token != null) {
          headers['authorization'] = 'Bearer ${token.accessToken}';
        }
      }
    }

    // Process custom headers
    if (api['headers'] is YamlMap) {
      (api['headers'] as YamlMap).forEach((key, value) {
        if (key.toString().toLowerCase() == 'cookie' && kIsWeb) return;
        if (value != null) {
          headers[key.toString().toLowerCase()] =
              clonedContext.eval(value).toString();
        }
      });
    }

    // Ensure Accept header is set for SSE
    headers['Accept'] = 'text/event-stream';

    // Get URL
    String url = HTTPAPIProvider.resolveUrl(clonedContext, _getUrl(api));
    if (url.isEmpty) {
      throw RuntimeError('URL cannot be empty');
    }

    // Process query parameters
    Map<String, String> params = {};
    if (api['parameters'] is YamlMap) {
      api['parameters'].forEach((key, value) {
        params[key] = eContext.eval(value)?.toString() ?? '';
      });
    }

    // Append query parameters to URL
    if (params.isNotEmpty) {
      StringBuffer urlParams = StringBuffer(url.contains('?') ? '' : '?');
      params.forEach((key, value) {
        urlParams.write('&$key=$value');
      });
      url += urlParams.toString();
    }

    log("SSE GET $url");

    // Get SSE options
    final sseOptions = _getSSEOptions(api, eContext);

    // Get HTTP client with SSL configuration
    final env =
        Ensemble().getConfig()?.definitionProvider.getAppConfig()?.envVariables;
    final secrets = Ensemble().getConfig()?.definitionProvider.getSecrets();

    bool sslPinningEnabled =
        env?['ssl_pinning_enabled']?.toString().toLowerCase() == 'true';
    bool bypassSslCertificate =
        env?['bypass_ssl_pinning']?.toString().toLowerCase() == 'true';
    bool bypassSslPinningWithValidation =
        env?['bypass_ssl_pinning_with_validation']?.toString().toLowerCase() ==
            'true';
    String? sslPinningCertificate = secrets?['ssl_pinning_certificate'];
    String? fingerprintKey = 'bypass_ssl_fingerprint';

    if (api['sslConfig'] != null && api['sslConfig'] is YamlMap) {
      YamlMap sslConfig = api['sslConfig'];
      if (sslConfig['pinningEnabled'] != null) {
        sslPinningEnabled = Utils.getBool(
            eContext.eval(sslConfig['pinningEnabled']),
            fallback: sslPinningEnabled);
      }
      if (sslConfig['bypassPinning'] != null) {
        bypassSslCertificate = Utils.getBool(
            eContext.eval(sslConfig['bypassPinning']),
            fallback: bypassSslCertificate);
      }
      if (sslConfig['bypassPinningWithFingerprint'] != null) {
        bypassSslPinningWithValidation = Utils.getBool(
            eContext.eval(sslConfig['bypassPinningWithFingerprint']),
            fallback: bypassSslPinningWithValidation);
      }
      if (sslConfig['fingerprintKey'] != null) {
        fingerprintKey =
            Utils.optionalString(eContext.eval(sslConfig['fingerprintKey'])) ??
                fingerprintKey;
      }
    }

    http.Client client = await _getHttpClient(
        sslPinningEnabled: sslPinningEnabled,
        bypassSslCertificate: bypassSslCertificate,
        sslPinningCertificate: sslPinningCertificate,
        bypassSslPinningWithValidation: bypassSslPinningWithValidation,
        fingerprintKey: fingerprintKey);

    _activeClients[apiName] = client;

    // Create the SSE connection
    return _connectSSE(
        client, url, headers, apiName, listener, sseOptions, clonedContext);
  }

  Future<Response> _connectSSE(
      http.Client client,
      String url,
      Map<String, String> headers,
      String apiName,
      ResponseListener listener,
      SSEOptions options,
      DataContext eContext) async {
    int reconnectAttempts = 0;
    String? lastEventId;

    Future<void> connect() async {
      try {
        // Add Last-Event-ID header if we have it (for reconnection)
        if (lastEventId != null) {
          headers['Last-Event-ID'] = lastEventId!;
        }

        final request = http.Request('GET', Uri.parse(url));
        request.headers.addAll(headers);

        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode < 200 ||
            streamedResponse.statusCode >= 300) {
          final errorResponse = HttpResponse.fromBody(
            'SSE connection failed with status ${streamedResponse.statusCode}',
            streamedResponse.headers,
            streamedResponse.statusCode,
            streamedResponse.reasonPhrase,
            APIState.error,
          );
          errorResponse.apiName = apiName;
          listener(errorResponse);
          return;
        }

        // Reset reconnect attempts on successful connection
        reconnectAttempts = 0;

        // Parse SSE stream
        String? currentEventType;
        String? currentEventId;
        String currentData = '';

        final subscription = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            if (line.isEmpty) {
              // Empty line indicates end of event
              if (currentData.isNotEmpty) {
                _processSSEEvent(currentEventType ?? 'message', currentData,
                    currentEventId, apiName, listener);
                currentData = '';
                currentEventType = null;
              }
            } else if (line.startsWith(':')) {
              // Comment line, ignore
            } else if (line.contains(':')) {
              final colonIndex = line.indexOf(':');
              final field = line.substring(0, colonIndex);
              final value = line.substring(colonIndex + 1).trim();

              switch (field) {
                case 'event':
                  currentEventType = value;
                  break;
                case 'data':
                  if (currentData.isNotEmpty) {
                    currentData += '\n';
                  }
                  currentData += value;
                  break;
                case 'id':
                  currentEventId = value;
                  lastEventId = value;
                  break;
                case 'retry':
                  // Update retry interval if provided
                  final retryMs = int.tryParse(value);
                  if (retryMs != null && retryMs > 0) {
                    // Could update options here if needed
                  }
                  break;
              }
            } else {
              // Line without colon, treat as data
              if (currentData.isNotEmpty) {
                currentData += '\n';
              }
              currentData += line;
            }
          },
          onError: (error) {
            log('SSE stream error: $error');
            _handleSSEError(error, apiName, listener, options,
                reconnectAttempts, () => connect(), url, headers, eContext);
          },
          onDone: () {
            log('SSE stream closed');
            // Attempt reconnection if enabled
            if (options.autoReconnect &&
                reconnectAttempts < options.maxReconnectAttempts) {
              reconnectAttempts++;
              final delay = Duration(
                  milliseconds: options.reconnectDelay * reconnectAttempts);
              Future.delayed(delay, () {
                log('Reconnecting SSE (attempt $reconnectAttempts)...');
                connect();
              });
            } else {
              // Connection closed permanently
              final closedResponse = HttpResponse.fromBody(
                'SSE connection closed',
                {},
                200,
                'OK',
                APIState.success,
              );
              closedResponse.apiName = apiName;
              listener(closedResponse);
            }
          },
        );

        _subscriptions.add(subscription);
      } catch (error) {
        _handleSSEError(error, apiName, listener, options, reconnectAttempts,
            () => connect(), url, headers, eContext);
      }
    }

    // Start initial connection
    await connect();

    // Return initial response indicating subscription started
    return HttpResponse.fromBody(
      {'message': 'SSE subscription started', 'events': []},
      {'Content-Type': 'application/json'},
      200,
      'OK',
      APIState.success,
    );
  }

  void _processSSEEvent(String eventType, String data, String? eventId,
      String apiName, ResponseListener listener) {
    try {
      // Try to parse as JSON, fallback to plain text
      dynamic body;
      try {
        body = json.decode(data);
      } catch (e) {
        body = data;
      }

      final response = HttpResponse.fromBody(
        {
          'event': eventType,
          'data': body,
          'id': eventId,
        },
        {'Content-Type': 'application/json'},
        200,
        'OK',
        APIState.success,
      );
      response.apiName = apiName;
      listener(response);
    } catch (e) {
      log('Error processing SSE event: $e');
    }
  }

  void _handleSSEError(
      dynamic error,
      String apiName,
      ResponseListener listener,
      SSEOptions options,
      int reconnectAttempts,
      VoidCallback reconnect,
      String url,
      Map<String, String> headers,
      DataContext eContext) {
    String errorMessage;
    if (error is HandshakeException || error is TlsException) {
      errorMessage =
          'SSL error: ${error.toString()}. Please check your certificate.';
    } else if (error is SocketException) {
      errorMessage =
          'Network error: ${error.message}. Please check your network connection.';
    } else {
      errorMessage = 'SSE connection error: ${error.toString()}';
    }

    log(errorMessage);

    final errorResponse = HttpResponse.fromBody(
      errorMessage,
      {'Content-Type': 'text/plain'},
      500,
      'Internal Server Error',
      APIState.error,
    );
    errorResponse.apiName = apiName;
    listener(errorResponse);

    // Attempt reconnection if enabled
    if (options.autoReconnect &&
        reconnectAttempts < options.maxReconnectAttempts) {
      reconnectAttempts++;
      final delay =
          Duration(milliseconds: options.reconnectDelay * reconnectAttempts);
      Future.delayed(delay, () {
        log('Reconnecting SSE after error (attempt $reconnectAttempts)...');
        reconnect();
      });
    }
  }

  SSEOptions _getSSEOptions(YamlMap api, DataContext eContext) {
    if (api['sseOptions'] is YamlMap) {
      return SSEOptions.fromYaml(api['sseOptions'] as YamlMap, eContext);
    }
    return SSEOptions(); // Default options
  }

  Future<http.Client> _getHttpClient({
    required bool sslPinningEnabled,
    required bool bypassSslCertificate,
    String? sslPinningCertificate,
    bool bypassSslPinningWithValidation = false,
    String? fingerprintKey,
  }) async {
    if (kIsWeb) {
      return http.Client();
    }

    if (sslPinningEnabled && sslPinningCertificate != null) {
      Uint8List bytes = base64.decode(sslPinningCertificate);
      SecurityContext context = SecurityContext.defaultContext;
      context.setTrustedCertificatesBytes(bytes);
      return IOClient(HttpClient(context: context));
    }

    if (bypassSslCertificate == true) {
      return IOClient(
          HttpClient()..badCertificateCallback = (cert, host, port) => true);
    }

    if (bypassSslPinningWithValidation == true) {
      String? storedFingerprint;
      try {
        storedFingerprint =
            await StorageManager().readSecurely(fingerprintKey!);
      } catch (e) {
        print('Error reading stored fingerprint: $e');
      }

      HttpClient client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        if (storedFingerprint == null) {
          print('No stored fingerprint found for key: ${fingerprintKey}');
          return false;
        }

        String currentFingerprint = sha256.convert(cert.der).toString();
        bool fingerprintMatches = currentFingerprint == storedFingerprint;
        return fingerprintMatches;
      };
      return IOClient(client);
    }

    return http.Client();
  }

  bool _containsSecureStorageReference(YamlMap api) {
    const String storageIdentifier = 'apiSecureStorage.';

    final headers = api['headers'];
    final body = api['body'];

    return (headers?.toString().contains(storageIdentifier) ?? false) ||
        (body?.toString().contains(storageIdentifier) ?? false);
  }

  static String _getUrl(YamlMap apiDef) =>
      (apiDef['url'] ?? apiDef['uri'] ?? '').toString().trim();

  @override
  Future<Response> invokeMockAPI(DataContext eContext, dynamic mock) async {
    if (mock is Map) {
      mock = YamlMap.wrap(mock);
    }
    dynamic mockResponse = eContext.eval(mock);
    return HttpResponse.fromBody(
        mockResponse['body'],
        mockResponse['headers'],
        mockResponse['statusCode'] ?? 200,
        mockResponse['reasonPhrase'],
        APIState.success);
  }

  @override
  SSEAPIProvider clone() {
    return SSEAPIProvider();
  }

  @override
  dispose() {
    // Cancel all subscriptions
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Close all active clients
    for (var client in _activeClients.values) {
      client.close();
    }
    _activeClients.clear();
  }
}

/// Configuration options for SSE connections
class SSEOptions {
  final bool autoReconnect;
  final int reconnectDelay;
  final int maxReconnectAttempts;

  SSEOptions({
    this.autoReconnect = true,
    this.reconnectDelay = 1000,
    this.maxReconnectAttempts = 5,
  });

  factory SSEOptions.fromYaml(YamlMap yaml, DataContext eContext) {
    return SSEOptions(
      autoReconnect:
          Utils.getBool(eContext.eval(yaml['autoReconnect']), fallback: true),
      reconnectDelay:
          Utils.getInt(eContext.eval(yaml['reconnectDelay']), fallback: 1000),
      maxReconnectAttempts: Utils.getInt(
          eContext.eval(yaml['maxReconnectAttempts']),
          fallback: 5),
    );
  }
}
