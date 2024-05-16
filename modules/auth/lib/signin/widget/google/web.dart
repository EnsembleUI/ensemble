import 'package:ensemble_auth/signin/widget/google/stub.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;

/// Renders a web-only SIGN IN button.
/// For web there are really only 2 options for this library:
/// 1. renderButton - pre-defined button with very limited styles
/// 2. completely custom button and call signInSilently(), which trigger the one-tap UX. Problem with this is if the user click Cancel, user can't log in for another 2 hours
/// 3. Maybe don't use this library?
Widget buildGoogleSignInButton(
    {Widget? mobileWidget, required HandleSignInFn? onPressed}) {
  return (GoogleSignInPlatform.instance as web.GoogleSignInPlugin).renderButton(
      configuration: web.GSIButtonConfiguration(
          // expose these options?
          // shape: web.GSIButtonShape.rectangular,
          // minimumWidth: 400,
          logoAlignment: web.GSIButtonLogoAlignment.left,

          // medium is the only applicable option (large will have 2 lines with weird user selection)
          size: web.GSIButtonSize.medium,

          text: web.GSIButtonText.signinWith));
}
