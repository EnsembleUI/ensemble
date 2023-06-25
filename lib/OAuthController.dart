import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:developer' as developer;

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class OAuthController {
  static const accessTokenKey = '_accessToken';
  static const refreshTokenKey = '_refreshToken';

  Future<OAuthServiceToken?> authorize(String serviceId,
      {required String scope, bool forceNewTokens = false}) async {
    // see if the tokens already exists
    const storage = FlutterSecureStorage();
    if (!forceNewTokens) {
      String? accessToken = await storage.read(key: serviceId + accessTokenKey);
      String? refreshToken =
          await storage.read(key: serviceId + refreshTokenKey);
      if (accessToken != null) {
        return OAuthServiceToken(
            accessToken: accessToken, refreshToken: refreshToken);
      }
    }

    OAuthServicePayload? servicePayload = await getServicePayload(serviceId);
    if (servicePayload != null) {
      String state = generateState();
      Uri uri = Uri.parse(servicePayload.authorizationURL);
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...{
          'response_type': 'code',
          'client_id': servicePayload.clientId,
          'redirect_uri': servicePayload.redirectUri,
          'scope': scope,
          'state': state
        }
      });

      // authorize with the service
      final result = await FlutterWebAuth2.authenticate(
          url: uri.toString(),
          callbackUrlScheme: servicePayload.redirectScheme);
      final resultUri = Uri.parse(result);
      String? code = resultUri.queryParameters['code'];
      if (code != null && state == resultUri.queryParameters['state']) {
        OAuthServiceToken? token = await exchangeCodeForTokens(
            code, serviceId, servicePayload.redirectUri);
        if (token != null) {
          await storage.write(
              key: serviceId + accessTokenKey, value: token.accessToken);
          if (token.refreshToken != null) {
            await storage.write(
                key: serviceId + refreshTokenKey, value: token.refreshToken);
          }
          return token;
        }
      }
    }
    return null;
  }

  Future<OAuthServiceToken?> exchangeCodeForTokens(
      String code, String serviceId, String redirectUri) async {
    String? exchangeServer = Ensemble().getServices()?.tokenExchangeServer;
    if (exchangeServer == null) {
      throw ConfigError("tokenExchangeServer is required");
    }
    var data = json.encode({
      'code': code,
      'serviceId': serviceId,
      'token': JWT({'redirectUri': redirectUri})
          .sign(SecretKey(dotenv.env['OAUTH_TOKEN']!))
    });
    var response = await http.post(Uri.parse(exchangeServer),
        body: data, headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
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

  Future<OAuthServicePayload?> getServicePayload(String serviceId) {
    if (serviceId == 'google') {
      return getGoogleServicePayload();
    } else if (serviceId == 'microsoft') {
      return getMicrosoftServicePayload();
    } else if (serviceId == 'yahoo') {
      return getYahooServicePayload();
    }
    return Future.value(null);
  }

  /// These will come from our server
  Future<OAuthServicePayload?> getGoogleServicePayload() async {
    APICredential? credential = _getAPICredential(ServiceName.google);
    if (credential != null) {
      return Future.value(OAuthServicePayload(
          authorizationURL:
              'https://accounts.google.com/o/oauth2/v2/auth?access_type=offline&prompt=consent',
          clientId: credential.clientId,
          redirectUri: credential.redirectUri,
          redirectScheme: credential.redirectScheme));
    }
    return null;
  }

  Future<OAuthServicePayload?> getMicrosoftServicePayload() async {
    APICredential? credential = _getAPICredential(ServiceName.microsoft);
    if (credential != null) {
      return Future.value(OAuthServicePayload(
          authorizationURL:
              'https://login.microsoftonline.com/f3a999e9-2d73-4a55-86fb-0f90c0294c5f/oauth2/v2.0/authorize',
          clientId: credential.clientId,
          redirectUri: credential.redirectUri,
          redirectScheme: credential.redirectScheme));
    }
    return null;
  }

  Future<OAuthServicePayload?> getYahooServicePayload() async {
    APICredential? credential = _getAPICredential(ServiceName.yahoo);
    if (credential != null) {
      return Future.value(OAuthServicePayload(
          authorizationURL:
          'https://api.login.yahoo.com/oauth2/request_auth',
          clientId: credential.clientId,
          redirectUri: credential.redirectUri,
          redirectScheme: credential.redirectScheme));
    }
    return null;
  }

  APICredential? _getAPICredential(ServiceName serviceName) =>
      Ensemble().getServices()?.apiCredentials?[serviceName];
}

class OAuthServicePayload {
  OAuthServicePayload(
      {required this.authorizationURL,
      required this.clientId,
      String? redirectUri,
      String? redirectScheme}) {
    if (redirectUri == null) {
      throw ConfigError(
          "API's redirectUri not found. Please double check your config.");
    }
    this.redirectUri = redirectUri;

    if (redirectUri.startsWith('https')) {
      this.redirectScheme = 'https';
    } else {
      // redirect scheme is required for custom scheme
      if (redirectScheme == null) {
        throw ConfigError(
            "API's redirectScheme is required for non-https scheme.");
      }
      this.redirectScheme = redirectScheme;
    }
  }

  String authorizationURL;
  String clientId;

  // redirect can be https or a custom scheme e.g. myApp://
  // if redirectURL is a https URL, its scheme must be 'https'
  // if redirectURL is a custom scheme e.g. 'myApp://auth', its scheme should be e.g. 'myApp'
  late String redirectUri;
  late String redirectScheme;
}

class OAuthServiceToken {
  OAuthServiceToken({required this.accessToken, this.refreshToken});
  String accessToken;
  String? refreshToken;
}
