

import 'package:ensemble/action/invoke_api_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_auth/signin/widget/sign_in_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


/// a wrapper container to wrap around the Connect widget to capture onTap
class ConnectWidgetContainer extends StatelessWidget {
  const ConnectWidgetContainer({super.key, required this.widget, required this.onTap});
  final Widget widget;
  final ConnectWidgetTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      widget,
      Positioned.fill(
          child: Material(
              color: Colors.transparent, child: InkWell(onTap: onTap)))
    ]);
  }
}
typedef ConnectWidgetTapCallback = Future<void> Function();

class ConnectController extends SignInButtonController {
  List<String>? initialScopes;
  dynamic widgetDef;

  // these are initialized in the widget (as they need initiator)
  InvokeAPIAction? tokenExchangeAPI;
  EnsembleAction? onInitiated;
  EnsembleAction? onCanceled;
  EnsembleAction? onAuthorized;
  EnsembleAction? onError;

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'initialScopes': (scopes) => initialScopes = Utils.getListOfStrings(scopes),
      'widget': (value) => widgetDef = value,
    });
    return setters;
  }
}

class ConnectUtils {
  static String getScopesAsString(List<String>? scopes) {
    if (scopes != null) {
      return scopes.join(' ').trim();
    }
    return '';
  }
}