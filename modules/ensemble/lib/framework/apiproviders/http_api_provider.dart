import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
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
import 'package:flutter/foundation.dart' as foundation;
import 'package:cookie_jar/cookie_jar.dart';

class HTTPAPIProvider extends APIProvider {
  final CookieJar _cookieJar = CookieJar();
  @override
  Future<HttpResponse> invokeApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName) async {
    // headers
    Map<String, String> headers = {};

    // this is the OAuth flow, where the authorization triggers before
    // calling the API. Leave it alone for now
    if (api['authorization'] != "none") {
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

      // this is the Bearer token. TODO: consolidate with the above
      OAuthService? serviceName =
          OAuthService.values.from(api['authorization']?['serviceId']);
      if (serviceName != null) {
        OAuthServiceToken? token =
            await GetIt.instance<TokenManager>().getServiceTokens(serviceName);
        if (token != null) {
          headers['authorization'] = 'Bearer ${token.accessToken}';
        }
      }
    }

    if (api['headers'] is YamlMap) {
      (api['headers'] as YamlMap).forEach((key, value) {
        // in Web we shouldn't pass the Cookie since that is automatic
        if (key.toString().toLowerCase() == 'cookie' && kIsWeb) return;

        if (value != null) {
          headers[key.toString().toLowerCase()] = eContext.eval(value).toString();
        }
      });
    }
    // Support JSON (or Yaml) body only.
    // Here it's converted to YAML already
    String? bodyPayload;
    Uint8List? bodyBytes;
    if (api['body'] != null) {
      final contentType = headers['content-type']?.toLowerCase() ?? '';

      if (contentType == 'application/x-www-form-urlencoded') {
        // For form-urlencoded, convert body to query string format
        if (api['body'] is Map) {
          Map<String, dynamic> formData = {};
          (api['body'] as Map).forEach((key, value) {
            formData[key.toString()] = eContext.eval(value)?.toString() ?? '';
          });
          // Convert map to x-www-form-urlencoded format
          bodyPayload = formData.entries
              .map((e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
              .join('&');
        }
      } else {
        // For JSON and other content types
        try {
          bodyPayload = json.encode(eContext.eval(api['body']));
          //this is just to make sure we don't create regressions, we will set
          //the bodyBytes only when Content-Type header is explicitly specified.
          //see https://github.com/EnsembleUI/ensemble/issues/1823
          // set Content-Type as json but don't override user's value if exists
          if (headers['content-type'] == null) {
            headers['content-type'] = 'application/json';
          } else {
            bodyBytes = utf8.encode(bodyPayload);
          }
        } on FormatException catch (_, e) {
          log("Only JSON data supported: " + e.toString());
        }
      }
    }

    if (_getUrl(api).isEmpty) {
      throw RuntimeError('URL cannot be empty');
    }

    // query parameter
    Map<String, String> params = {};
    if (api['parameters'] is YamlMap) {
      api['parameters'].forEach((key, value) {
        params[key] = eContext.eval(value)?.toString() ?? '';
      });
    }

    String url = resolveUrl(eContext, _getUrl(api));
    String method = api['method']?.toString().toUpperCase() ?? 'GET';

    // params should be appended to the URL for GET and DELETE
    if (method == 'GET' || method == 'DELETE') {
      if (params.isNotEmpty) {
        StringBuffer urlParams = StringBuffer(url.contains('?') ? '' : '?');
        params.forEach((key, value) {
          urlParams.write('&$key=$value');
        });
        url += urlParams.toString();
      }
      log("$method $url");
    } else {
      log("$method $url");
      //log("$method $url\nBody: $bodyPayload\nParams: "+params.toString());
    }

    dynamic body = bodyPayload ?? params;
    if (foundation.kDebugMode) {
      log("Body(debug only): $body");
    }

    final env =
        Ensemble().getConfig()?.definitionProvider.getAppConfig()?.envVariables;
    final secrets = Ensemble().getConfig()?.definitionProvider.getSecrets();

    // Global SSL configuration (existing environment variables - unchanged)
    bool sslPinningEnabled =
        env?['ssl_pinning_enabled']?.toString().toLowerCase() == 'true';
    bool bypassSslCertificate =
        env?['bypass_ssl_pinning']?.toString().toLowerCase() == 'true';
    bool bypassSslPinningWithValidation =
        env?['bypass_ssl_pinning_with_validation']?.toString().toLowerCase() ==
            'true';

    String? sslPinningCertificate = secrets?['ssl_pinning_certificate'];

    // Extract API-specific SSL configuration and override global settings
    String? fingerprintKey = 'bypass_ssl_fingerprint'; // default key
    
    if (api['sslConfig'] != null && api['sslConfig'] is YamlMap) {
      YamlMap sslConfig = api['sslConfig'];
      
      if (sslConfig['pinningEnabled'] != null) {
        sslPinningEnabled = Utils.getBool(eContext.eval(sslConfig['pinningEnabled']), fallback: sslPinningEnabled);
      }
      
      if (sslConfig['bypassPinning'] != null) {
        bypassSslCertificate = Utils.getBool(eContext.eval(sslConfig['bypassPinning']), fallback: bypassSslCertificate);
      }
      
      if (sslConfig['bypassPinningWithFingerprint'] != null) {
        bypassSslPinningWithValidation = Utils.getBool(eContext.eval(sslConfig['bypassPinningWithFingerprint']), fallback: bypassSslPinningWithValidation);
      }
      
      if (sslConfig['fingerprintKey'] != null) {
        fingerprintKey = Utils.optionalString(eContext.eval(sslConfig['fingerprintKey'])) ?? fingerprintKey;
      }
    }

    bool manageCookies = Utils.getBool(api['manageCookies'], fallback: false);

    Completer<http.Response> completer = Completer();
    http.Response? response;

    try {
      http.Client client = await _getHttpClient(
          sslPinningEnabled: sslPinningEnabled,
          bypassSslCertificate: bypassSslCertificate,
          sslPinningCertificate: sslPinningCertificate,
          bypassSslPinningWithValidation: bypassSslPinningWithValidation,
          fingerprintKey: fingerprintKey);

      if (!kIsWeb && manageCookies) {
        List<Cookie> cookies = await _cookieJar.loadForRequest(Uri.parse(url));
        String cookieString = cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
        if (cookieString.isNotEmpty) {
          headers['cookie'] = cookieString;
        }
      }
      if (bodyBytes != null && bodyBytes.isNotEmpty && method != 'GET') {
        //we don't want to send body with the GET request as it may cause issues with some servers
        //see http spec
        http.Request req = http.Request(method, Uri.parse(url))
          ..bodyBytes = bodyBytes
          ..headers.addAll(headers);
        response = await client.send(req).then(http.Response.fromStream);
      } else {
        switch (method) {
          case 'POST':
            response =
                await client.post(Uri.parse(url), headers: headers, body: body);
            break;
          case 'PUT':
            response =
                await client.put(Uri.parse(url), headers: headers, body: body);
            break;
          case 'PATCH':
            response =
            await client.patch(Uri.parse(url), headers: headers, body: body);
            break;
          case 'DELETE':
            response =
            await client.delete(Uri.parse(url), headers: headers, body: body);
            break;
          case 'GET':
          default:
            response = await client.get(Uri.parse(url), headers: headers);
            break;
        }
      }
      // Store cookies for native apps
      if (!kIsWeb && manageCookies) {
        _cookieJar.saveFromResponse(Uri.parse(url), _extractCookies(response!));
      }

      final isOkay = response!.statusCode >= 200 && response!.statusCode <= 299;
      log('Response: ${response!.statusCode}');
      return HttpResponse(response, isOkay ? APIState.success : APIState.error,
          apiName: apiName, manageCookies: manageCookies);
    } catch (e) {
      return _handleError(e, apiName);
    }
  }

  List<Cookie> _extractCookies(http.Response response) {
    List<Cookie> cookies = [];
    response.headers['set-cookie']?.split(',').forEach((String cookie) {
      cookies.add(Cookie.fromSetCookieValue(cookie));
    });
    return cookies;
  }

  Future<http.Client> _getHttpClient({
    required bool sslPinningEnabled,
    required bool bypassSslCertificate,
    String? sslPinningCertificate,
    bool bypassSslPinningWithValidation = false,
    String? fingerprintKey,
  }) async {
    if (kIsWeb) {
      // SSL pinning is not supported on the web
      return http.Client();
    }

    if (sslPinningEnabled && sslPinningCertificate != null) {
      // Use certificate for pinning
      Uint8List bytes = base64.decode(sslPinningCertificate);
      SecurityContext context = SecurityContext.defaultContext;
      context.setTrustedCertificatesBytes(bytes);
      return IOClient(HttpClient(context: context));
    } 

    if (bypassSslCertificate == true) {
      // Bypass SSL verification
      return IOClient(
          HttpClient()..badCertificateCallback = (cert, host, port) => true);
    }

    if (bypassSslPinningWithValidation == true) {
      String? storedFingerprint;
      try {
        storedFingerprint = await StorageManager().readSecurely(fingerprintKey!); // fingerprintKey cannot be null, as it has a default value.
      } catch (e) {
        print('Error reading stored fingerprint: $e');
      }
      
      // Check SSL while bypassing
      HttpClient client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        if (storedFingerprint == null) {
          print('No stored fingerprint found for key: ${fingerprintKey}');
          return false;
        }
        
        String currentFingerprint = sha256.convert(cert.der).toString();

        // Compare with stored fingerprint
        bool fingerprintMatches = currentFingerprint == storedFingerprint;
        // only allow if the fingerprint matches
        return fingerprintMatches;
      };
      return IOClient(client);
    }

    // Default case when sslPinningEnabled is null
    return http.Client();
  }

  HttpResponse _handleError(Object error, String apiName) {
    String errorMessage;
    if (error is HandshakeException || error is TlsException) {
      errorMessage =
          'SSL Pinning failed: ${error.toString()}. Please check your certificate.';
    } else if (error is SocketException) {
      errorMessage =
          'Network error: ${error.message}. Please check your network connection.';
    } else {
      errorMessage = 'Unexpected error: ${error.toString()}.';
    }

    log(errorMessage);
    return HttpResponse.fromBody(
      errorMessage,
      {'Content-Type': 'text/plain'},
      500,
      'Internal Server Error',
      APIState.error,
    );
  }

  @override
  Future<HttpResponse> invokeMockAPI(DataContext eContext, dynamic mock) async {
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

  static String _getUrl(YamlMap apiDef) =>
      (apiDef['url'] ?? apiDef['uri'] ?? '').toString().trim();

  /// evaluate the URL, which can be prefix with ${app.baseUrl}
  static String resolveUrl(DataContext dataContext, String rawUrl) {
    RegExp regExp = RegExp(r'^\${app.baseUrl}');
    if (regExp.hasMatch(rawUrl)) {
      UserAppConfig? appConfig =
          Ensemble().getConfig()?.definitionProvider.getAppConfig();

      // non-Web will need the baseUrl
      String? baseUrl = appConfig?.baseUrl;

      // on Web we can get the base url from the browser even if baseUrl is not set.
      // Furthermore if told to use browser url, we'll get it and override the baseUrl
      if (kIsWeb &&
          (baseUrl == null ||
              baseUrl.isEmpty ||
              appConfig?.useBrowserUrl == true)) {
        baseUrl = '${Uri.base.scheme}://${Uri.base.host}' +
            (Uri.base.hasPort ? ':${Uri.base.port}' : '');
        log("baseUrl: $baseUrl. Port " +
            (Uri.base.hasPort ? Uri.base.port.toString() : ''));
      }

      if (baseUrl != null) {
        String url = rawUrl.replaceFirst(regExp, baseUrl);
        return dataContext.eval(url);
      }

      // throw exception if we can't resolve base url
      throw ConfigError(
          "Base Url cannot be resolved. Please define baseUrl in your app configuration");
    }
    // simply eval and return
    else {
      return dataContext.eval(rawUrl);
    }
  }

  /// parse a JSON-only response payload
  static dynamic parseResponsePayload(dynamic input) {
    // if the JSON is constructed in Javascript, we need to manually re-constructed here due to type differences
    if (input is Map) {
      Map<String, dynamic> rtn = {};
      input.forEach((key, value) {
        rtn[key] = value;
      });
      return rtn;
    } else if (input is List) {
      return input;
    } else if (input is String) {
      try {
        return json.decode(input);
      } on FormatException catch (_, e) {
        log('Warning - Only JSON response is supported');
      }
    }
    return null;
  }

  @override
  Future<void> init(String appId, Map<String, dynamic> config) async {
    // doesn't require initialization
  }
  @override
  HTTPAPIProvider clone() {
    return this; //configless so nothing to close
  }

  @override
  dispose() {
    // nothing to dispose
  }
}

/// a wrapper class around the http Response
class HttpResponse extends Response {
  final bool _manageCookies;
  late Map<String, String> _cookies;

  HttpResponse.updateState({required apiState}) : _manageCookies = false {
    super.updateState(apiState: apiState);
  }
// APIState get apiState => _apiState;
  HttpResponse.fromBody(dynamic body,
      [headers, statusCode, reasonPhrase, apiState = APIState.idle])
      : _manageCookies = false {
    super.body = body;
    super.headers = headers;
    super.statusCode = statusCode;
    super.reasonPhrase = reasonPhrase;
    super.apiState = apiState;
  }

  HttpResponse(http.Response response, APIState apiState,
      {String apiName = '', bool manageCookies = false})
      : _manageCookies = manageCookies {
    try {
      body = json.decode(response.body);
    } on FormatException catch (_, e) {
      log('Warning - Only JSON response is supported');
    }
    apiState = apiState;
    headers = response.headers;
    statusCode = response.statusCode;
    reasonPhrase = response.reasonPhrase;
    apiName = apiName;
    _cookies = _parseCookies(response);
  }

  Map<String, String> _parseCookies(http.Response response) {
    Map<String, String> cookies = {};
    if (_manageCookies) {
      response.headers['set-cookie']?.split(',').forEach((String rawCookie) {
        List<String> cookieParts = rawCookie.split(';')[0].split('=');
        if (cookieParts.length == 2) {
          cookies[cookieParts[0].trim()] = cookieParts[1].trim();
        }
      });
    }
    return cookies;
  }

  Map<String, String> get cookies => _cookies;

  @override
  bool get isOkay =>
      statusCode != null && statusCode! >= 200 && statusCode! <= 299;
// bool get isError => !isSuccess;
}
