import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/stub/token_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' as foundation;

class HTTPAPIProvider extends APIProvider {
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
          headers['Authorization'] = 'Bearer ${token.accessToken}';
        }
      }

      // this is the Bearer token. TODO: consolidate with the above
      OAuthService? serviceName =
          OAuthService.values.from(api['authorization']?['serviceId']);
      if (serviceName != null) {
        OAuthServiceToken? token =
            await GetIt.instance<TokenManager>().getServiceTokens(serviceName);
        if (token != null) {
          headers['Authorization'] = 'Bearer ${token.accessToken}';
        }
      }
    }

    if (api['headers'] is YamlMap) {
      (api['headers'] as YamlMap).forEach((key, value) {
        if (value != null) {
          headers[key.toString()] = eContext.eval(value).toString();
        }
      });
    }
    // Support JSON (or Yaml) body only.
    // Here it's converted to YAML already
    String? bodyPayload;
    if (api['body'] != null) {
      try {
        bodyPayload = json.encode(eContext.eval(api['body']));

        // set Content-Type as json but don't override user's value if exists
        if (headers['Content-Type'] == null) {
          headers['Content-Type'] = 'application/json';
        }
      } on FormatException catch (_, e) {
        log("Only JSON data supported: " + e.toString());
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

    Completer<http.Response> completer = Completer();
    http.Response response;
    switch (method) {
      case 'POST':
        response =
            await http.post(Uri.parse(url), headers: headers, body: body);
        break;
      case 'PUT':
        response = await http.put(Uri.parse(url), headers: headers, body: body);
        break;
      case 'PATCH':
        response =
            await http.patch(Uri.parse(url), headers: headers, body: body);
        break;
      case 'DELETE':
        response =
            await http.delete(Uri.parse(url), headers: headers, body: body);
        break;
      case 'GET':
      default:
        response = await http.get(Uri.parse(url), headers: headers);
        break;
    }
    final isOkay = response.statusCode >= 200 && response.statusCode <= 299;
    log('Response: ${response.statusCode}');
    return HttpResponse(response, isOkay ? APIState.success : APIState.error,
        apiName: apiName);
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
  HttpResponse.updateState({required apiState}) {
    super.updateState(apiState: apiState);
  }
// APIState get apiState => _apiState;
  HttpResponse.fromBody(dynamic body,
      [headers, statusCode, reasonPhrase, apiState = APIState.idle]) {
    super.body = body;
    super.headers = headers;
    super.statusCode = statusCode;
    super.reasonPhrase = reasonPhrase;
    super.apiState = apiState;
  }

  HttpResponse(http.Response response, APIState apiState,
      {String apiName = ''}) {
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
  }
  @override
  bool get isOkay =>
      statusCode != null && statusCode! >= 200 && statusCode! <= 299;
// bool get isError => !isSuccess;
}
