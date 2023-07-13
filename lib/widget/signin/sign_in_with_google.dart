import 'dart:developer';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/signin/google/google_sign_in_button.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
        'widget': (widgetDef) => _controller.widgetDef = widgetDef,
        'onAuthenticated': (action) => _controller.onAuthenticated =
            EnsembleAction.fromYaml(action, initiator: this),
        'scopes': (value) =>
            _controller.scopes =
              Utils.getListOfStrings(value) ?? _controller.scopes,
      };

}

class SignInWithGoogleController extends WidgetController {
  dynamic widgetDef;
  List<String> scopes = [];

  EnsembleAction? onAuthenticated;
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

        // at this point the user is authenticated.
        // On non-Web, Authorization is automatic with authentication.
        // On Web, Authorization has to be done separately, and has
        //  to be triggered manually by the user (e.g. button click)
        // TODO: authorize for Web
        bool isAuthorized = true;
        if (kIsWeb) {
          isAuthorized =
              await _googleSignIn.canAccessScopes(widget._controller.scopes);
        }
        _onAuthenticated(account, googleAuthentication);
      } else {
        //log("TO BE IMPLEMENTED: log out");
      }
    });
  }

  void _onAuthenticated(GoogleSignInAccount account, GoogleSignInAuthentication googleAuthentication) {
    log("idToken: ${googleAuthentication.idToken}");
    log("serverAuthcode: ${account.serverAuthCode}");

    // save the access token to storage. This will become
    // the bearer token to any API with serviceId = google
    if (googleAuthentication.accessToken != null) {
      var key = ServiceName.google.name;
      const FlutterSecureStorage().write(
          key: "${key}_accessToken",
          value: googleAuthentication.accessToken);
    }

    // update the user information in storage
    StorageManager().updateUser(context, account.id, name: account.displayName,
        email: account.email, photo: account.photoUrl);

    // trigger the callback
    if (widget._controller.onAuthenticated != null) {
      ScreenController().executeAction(
          context,
          widget._controller.onAuthenticated!,
          event: EnsembleEvent(widget, data: {
            'id': account.id,
            'name': account.displayName,
            'email': account.email,
            'photo': account.photoUrl,

            // server can verify and decode to get user info, useful for Sign In
            'idToken': googleAuthentication.idToken,

            // server can exchange this for accessToken/refreshToken
            'serverAuthCode': account.serverAuthCode
          }));
    }

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
      // sign out so user can switch to another account
      // when clicking on the button multiple times
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();

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