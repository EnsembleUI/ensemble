import 'dart:convert';
import 'dart:math';
import 'dart:developer' as dev;

import 'package:crypto/crypto.dart';
import 'package:ensemble/action/invoke_api_action.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/stub/token_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

class OAuthControllerImpl implements OAuthController {
  static const accessTokenKey = '_accessToken';
  static const refreshTokenKey = '_refreshToken';

  @override
  Future<OAuthServiceToken?> authorize(
      BuildContext context, OAuthService service,
      {required String scope,
      bool forceNewTokens = false,
      InvokeAPIAction? tokenExchangeAPI}) async {
    // see if the tokens already exists
    const storage = FlutterSecureStorage();
    if (!forceNewTokens) {
      String? accessToken =
          await storage.read(key: service.name + accessTokenKey);
      String? refreshToken =
          await storage.read(key: service.name + refreshTokenKey);
      if (accessToken != null) {
        return OAuthServiceToken(
            accessToken: accessToken, refreshToken: refreshToken);
      }
    }

    ServiceCredentialPayload? servicePayload = getServicePayload(service);
    if (servicePayload != null) {
      OAuthCredential? credential =
          servicePayload.credential.platformCredential;
      if (credential == null) {
        throw RuntimeError(
            'OAuth Service is not correctly setup. Please check your configuration');
      }

      String codeVerifier = _generateCodeVerifier();
      String codeChallenge = _generateCodeChallenge(codeVerifier);
      String state = generateState();
      Uri uri = Uri.parse(servicePayload.authorizationURL);
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...{
          'response_type': 'code',
          'client_id': credential.clientId,
          'redirect_uri': credential.redirectUri,
          'scope': scope,
          'state': state,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256'
        }
      });

      // authorize with the service
      final result = await FlutterWebAuth2.authenticate(
          url: uri.toString(), callbackUrlScheme: credential.redirectScheme);
      final resultUri = Uri.parse(result);
      String? code = resultUri.queryParameters['code'];
      if (code != null && state == resultUri.queryParameters['state']) {
        // code exchange can be on the client or server
        OAuthServiceToken? token;
        if (tokenExchangeAPI == null) {
          token = await _getTokenFromClient(
              code: code,
              codeVerifier: codeVerifier,
              tokenURL: servicePayload.tokenURL,
              service: service,
              oauthCredential: credential);
        } else {
          token = await _getTokenFromServer(context,
              code: code,
              codeVerifier: codeVerifier,
              tokenExchangeAPI: tokenExchangeAPI);
        }
        // only write to storage if accessToken is returned
        if (token != null && token.accessToken != null) {
          await storage.write(
              key: service.name + accessTokenKey, value: token.accessToken);
          if (token.refreshToken != null) {
            await storage.write(
                key: service.name + refreshTokenKey, value: token.refreshToken);
          }
        }
        return token;
      }
    }
    return null;
  }

  String _generateCodeVerifier() {
    var random = Random.secure();
    var values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  String _generateCodeChallenge(String codeVerifier) {
    var bytes = utf8.encode(codeVerifier);
    var digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// exchange OAuth code for token on the server
  Future<OAuthServiceToken?> _getTokenFromServer(BuildContext context,
      {required String code,
      required String codeVerifier,
      required InvokeAPIAction tokenExchangeAPI}) async {
    try {
      Response? response = await InvokeAPIController().executeWithContext(
          context, tokenExchangeAPI,
          additionalInputs: {'code': code, 'codeVerifier': codeVerifier});
      // even when server received the access/refresh tokens, it has the option
      // to NOT send them to us if it doesn't make sense (e.g.g client doesn't
      // make any API call). We'll still mark this call as success by returning
      // an empty token, unless there's an exception thrown
      if (response != null) {
        return OAuthServiceToken(
            accessToken: response.body?['access_token'],
            refreshToken: response.body?['refresh_token']);
      }
    } catch (error) {
      // should we give user access to error object?
      dev.log("Error retrieving token from server. $error");
    }
    return null;
  }

  // var data = json.encode({
  //   'code': code,
  //   'serviceId': service.name,
  //   'token': JWT({'redirectUri': servicePayload.redirectUri})
  //       .sign(SecretKey(dotenv.env['OAUTH_TOKEN']!))
  // });
  // var response = await http.post(Uri.parse(tokenExchangeServer),
  //     body: data, headers: {'Content-Type': 'application/json'});
  // if (response.statusCode == 200) {
  //   var jsonResponse = json.decode(response.body);
  //   if (jsonResponse != null) {
  //     return OAuthServiceToken(
  //         accessToken: jsonResponse['access_token'],
  //         refreshToken: jsonResponse['refresh_token']);
  //   }
  // }
  // return null;
}

/// exchange OAuth code for token locally
Future<OAuthServiceToken?> _getTokenFromClient(
    {required String code,
    required String codeVerifier,
    required String tokenURL,
    required OAuthService service,
    required OAuthCredential oauthCredential}) async {
  var body = {
    'client_id': oauthCredential.clientId,
    'redirect_uri': oauthCredential.redirectUri,
    'grant_type': 'authorization_code',
    'code': code,
    'code_verifier': codeVerifier
  };
  // inject the client secret on Web. Note that PKCE technically don't required
  // clientSecret, but some clients (i.e. Google) still require it.
  if (kIsWeb) {
    String? webClientSecret = await StorageManager()
        .readSecurely('SERVICES_OAUTH_${service.name}_WEB_CLIENT_SECRET');
    if (webClientSecret != null && webClientSecret.isNotEmpty) {
      body['client_secret'] = webClientSecret;
    }
  }

  final response = await http.post(Uri.parse(tokenURL), body: body);
  if (response.statusCode >= 200 && response.statusCode <= 299) {
    var jsonResponse = json.decode(response.body);
    if (jsonResponse != null) {
      return OAuthServiceToken(
          accessToken: jsonResponse['access_token'],
          refreshToken: jsonResponse['refresh_token']);
    }
  }
  return null;
}

/// generate a unique state
String generateState() {
  var raw = List<int>.generate(32, (index) => Random.secure().nextInt(256));
  return base64Url.encode(raw);
}

ServiceCredentialPayload? getServicePayload(OAuthService service) {
  if (service == OAuthService.google) {
    return getGoogleServicePayload();
  } else if (service == OAuthService.microsoft) {
    return getMicrosoftServicePayload();
  } else if (service == OAuthService.yahoo) {
    return getYahooServicePayload();
  }
  return null;
}

/// These will come from our server
ServiceCredentialPayload? getGoogleServicePayload() {
  ServiceCredential? credential = _getServiceCredential(OAuthService.google);
  if (credential != null) {
    bool offline = credential.config?['offline'] == true;
    return ServiceCredentialPayload(
        credential: credential,
        authorizationURL:
            "https://accounts.google.com/o/oauth2/v2/auth${offline ? '?access_type=offline&prompt=consent' : ''}",
        tokenURL: "https://oauth2.googleapis.com/token");
  }
  return null;
}

ServiceCredentialPayload? getMicrosoftServicePayload() {
  ServiceCredential? credential = _getServiceCredential(OAuthService.microsoft);
  if (credential != null) {
    String? tenantId = credential.config?['tenantId'];
    if (tenantId == null) {
      throw RuntimeError('tenantId is required for connecting to Microsoft.');
    }
    return ServiceCredentialPayload(
        credential: credential,
        authorizationURL:
            'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?prompt=select_account',
        tokenURL:
            'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token');
  }
  return null;
}

ServiceCredentialPayload? getYahooServicePayload() {
  ServiceCredential? credential = _getServiceCredential(OAuthService.yahoo);
  if (credential != null) {
    return ServiceCredentialPayload(
        credential: credential,
        authorizationURL: 'https://api.login.yahoo.com/oauth2/request_auth',
        tokenURL: '// to be added');
  }
  return null;
}

ServiceCredential? _getServiceCredential(OAuthService service) =>
    Ensemble().getServices()?.getServiceCredential(service);

/// add authorization URL and token URL
class ServiceCredentialPayload {
  ServiceCredentialPayload(
      {required this.credential,
      required this.authorizationURL,
      required this.tokenURL});

  ServiceCredential credential;
  String authorizationURL;
  String tokenURL;
}
