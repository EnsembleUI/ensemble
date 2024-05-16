import 'package:ensemble_auth/signin/widget/google/stub.dart';
import 'package:flutter/material.dart';


/// Renders a SIGN IN button that calls `handleSignIn` onclick.
Widget buildGoogleSignInButton(
    {Widget? mobileWidget, required HandleSignInFn? onPressed}) {
  if (mobileWidget != null) {
    return Stack(children: <Widget>[
      mobileWidget,
      Positioned.fill(
          child: Material(
              color: Colors.transparent, child: InkWell(onTap: onPressed)))
    ]);
  }
  return ElevatedButton(
    onPressed: onPressed,
    child: const Text('Sign in with Google'),
  );
}
