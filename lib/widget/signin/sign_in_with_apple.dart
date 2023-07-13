import 'dart:developer';
import 'dart:convert';

import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;

class EnsembleSignInWithApple extends StatefulWidget
    with Invokable, HasController<SignInWithAppleController, SignInWithAppleState> {
  static const type = 'SignInWithApple';
  EnsembleSignInWithApple({super.key});

  final SignInWithAppleController _controller = SignInWithAppleController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => SignInWithAppleState();

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {};

  @override
  Map<String, Function> setters() =>
      {
        'displayWidget': (widgetDef) => _controller.widgetDef = widgetDef,
        'scopes': (value) =>
        _controller.scopes =
            Utils.getListOfStrings(value) ?? _controller.scopes,
      };
}

class SignInWithAppleController extends WidgetController {
  dynamic widgetDef;
  List<String> scopes = [];
}

class SignInWithAppleState extends WidgetState<EnsembleSignInWithApple> {
  Widget? displayWidget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // build the display widget
    displayWidget = DataScopeWidget.getScope(context)
        ?.buildWidgetFromDefinition(widget._controller.widgetDef);
  }

  @override
  Widget buildWidget(BuildContext context) {
    return SignInWithAppleButton(
      onPressed: () async {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ]
        );
        String? response = await _signIn(credential.identityToken!);

        // Use those credentials to sign in to your firebase or server
        // Here's the sample code for firebase:
        // final oauthCredential = OAuthProvider('apple.com').credential(
        //   idToken: credential.identityToken,
        //   rawNonce: credential.rawNonce,
        // );
        // await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      },
    );
  }

  Future<String?> _signIn(String idToken) async {
    var data = json.encode({
      'service': 'apple',
      'idToken': idToken
    });
    var response = await http.post(Uri.parse(
        'http://127.0.0.1:5001/ensemble-web-studio/us-central1/oauth-sociallogin'),
        body: data, headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      log(jsonResponse.toString());
      return jsonResponse.toString();
    }
    return null;
  }
}


