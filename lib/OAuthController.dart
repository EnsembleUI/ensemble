import 'dart:convert';
import 'dart:math';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

class OAuthController {
  static const accessTokenKey = '_accessToken';
  static const refreshTokenKey = '_refreshToken';
  static const redirectURL = 'https://app.ensembleui.com/oauth-go';

  Future<OAuthServiceToken?> authorize(String serviceId,
      {required String scope, bool forceNewTokens = false}) async {

    // see if the tokens already exists
    const storage = FlutterSecureStorage();
    if (!forceNewTokens) {
      String? accessToken = await storage.read(key: serviceId + accessTokenKey);
      String? refreshToken = await storage.read(key: serviceId + refreshTokenKey);
      if (accessToken != null) {
        return OAuthServiceToken(accessToken: accessToken,
            refreshToken: refreshToken);
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
          'redirect_uri': redirectURL,
          'scope': scope,
          'state': state
        }
      });

      // authorize with the service
      final result = await FlutterWebAuth2.authenticate(url: uri.toString(), callbackUrlScheme: 'https');
      final resultUri = Uri.parse(result);
      String? code = resultUri.queryParameters['code'];
      if (code != null && state == resultUri.queryParameters['state']) {
        OAuthServiceToken? token = await exchangeCodeForTokens(code, serviceId);
        if (token != null) {
          await storage.write(key: serviceId + accessTokenKey, value: token.accessToken);
          if (token.refreshToken != null) {
            await storage.write(key: serviceId + refreshTokenKey, value: token.refreshToken);
          }
          return token;
        }
      }

    }
    return null;
  }

  Future<OAuthServiceToken?> exchangeCodeForTokens(String code, String serviceId) async {
    var data = json.encode({
      'code': code,
      'serviceId': serviceId
    });
    var response = await http.post(
        Uri.parse('https://us-central1-ensemble-web-studio.cloudfunctions.net/oauth-gettoken'),
        body: data,
        headers: {
          'Content-Type': 'application/json'
        });
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      if (jsonResponse != null) {
        return OAuthServiceToken(
          accessToken: jsonResponse['access_token'],
          refreshToken: jsonResponse['refresh_token']
        );
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
      return getGmailServicePayload();
    } else if (serviceId == 'microsoft') {
      return getMicrosoftServicePayload();
    }
    return Future.value(null);
  }

  /// These will come from our server
  Future<OAuthServicePayload?> getGmailServicePayload() async {
    return Future.value(OAuthServicePayload(
        authorizationURL: 'https://accounts.google.com/o/oauth2/v2/auth?access_type=offline&prompt=consent',
        clientId: '326748243798-btoriljk7i7sgsr9mvas90b0gn9vfebm.apps.googleusercontent.com'));
  }
  Future<OAuthServicePayload?> getMicrosoftServicePayload() async {
    return Future.value(OAuthServicePayload(
        authorizationURL: 'https://login.microsoftonline.com/f3a999e9-2d73-4a55-86fb-0f90c0294c5f/oauth2/v2.0/authorize',
        clientId: '36501417-8ad8-4885-82eb-232f345524ac'));
  }

}

class OAuthServicePayload {
  OAuthServicePayload({required this.authorizationURL, required this.clientId});
  String authorizationURL;
  String clientId;
}
class OAuthServiceToken {
  OAuthServiceToken({required this.accessToken, this.refreshToken});
  String accessToken;
  String? refreshToken;
}