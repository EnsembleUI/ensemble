// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'stub.dart';

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
