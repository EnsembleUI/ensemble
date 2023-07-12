import 'dart:developer';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/signin/google/google_sign_in_button.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SignInWithGoogle extends StatefulWidget
    with
        Invokable,
        HasController<SignInWithGoogleController, SignInWithGoogleState> {
  static const type = 'SignInWithGoogle';

  SignInWithGoogle({super.key});

  final SignInWithGoogleController _controller = SignInWithGoogleController();

  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => SignInWithGoogleState();

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

class SignInWithGoogleController extends WidgetController {
  dynamic widgetDef;
  List<String> scopes = [];
}

class SignInWithGoogleState extends WidgetState<SignInWithGoogle> {
  late GoogleSignIn _googleSignIn;
  Widget? displayWidget;

  @override
  void initState() {
    super.initState();

    _googleSignIn = GoogleSignIn(
        clientId: getClientId(),
        serverClientId: getServerClientId(),
        scopes: widget._controller.scopes
    );
    _googleSignIn.onCurrentUserChanged.listen((account) async {
      if (account != null) {
        var googleAuthentication = await account.authentication;
        log("idToken: ${googleAuthentication.idToken}. accessToken: ${googleAuthentication.accessToken}");

        bool isAuthorized;
        if (kIsWeb) {
          isAuthorized =
              await _googleSignIn.canAccessScopes(widget._controller.scopes);
          if (!isAuthorized) {
            isAuthorized =
                await _googleSignIn.requestScopes(widget._controller.scopes);
          }
        } else {
          isAuthorized = true;
        }

        log("Authorized: $isAuthorized");
        log(account.toString());

        _sendTokens(googleAuthentication.idToken!, account.serverAuthCode);
      } else {
        log("can't log in");
      }
    });
  }

  void _sendTokens(String idToken, String? serverAuthCode) async {
    var data = json.encode({
      'service': 'google',
      'idToken': idToken,
      'serverAuthCode': serverAuthCode
    });
    var response = await http.post(Uri.parse(
        'http://127.0.0.1:5001/ensemble-web-studio/us-central1/oauth-sociallogin'),
        body: data, headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      log(jsonResponse.toString());
    }
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      log(error.toString());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // build the display widget
    displayWidget = DataScopeWidget.getScope(context)
        ?.buildWidgetFromDefinition(widget._controller.widgetDef);
  }


  @override
  Widget buildWidget(BuildContext context) {
    return buildGoogleSignInButton(
        mobileWidget: displayWidget,
        onPressed: _handleSignIn);
  }

  String getClientId() {
    SignInCredential? credential =
    Ensemble()
        .getSignInServices()
        ?.signInCredentials?[ServiceName.google];
    String? clientId;
    if (kIsWeb) {
      clientId = credential?.webClientId;
    } else if (Platform.isAndroid) {
      clientId = credential?.androidClientId;
    } else if (Platform.isIOS) {
      clientId = credential?.iOSClientId;
    }
    if (clientId != null) {
      return clientId;
    }
    throw LanguageError("Google SignIn provider is required.",
        recovery: "Please check your configuration.");
  }

  // serverClientId is not supported on Web
  String? getServerClientId() => kIsWeb ? null : Ensemble()
      .getSignInServices()
      ?.signInCredentials?[ServiceName.google]?.serverClientId;

}