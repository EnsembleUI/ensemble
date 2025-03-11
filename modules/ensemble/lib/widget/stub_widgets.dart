import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';

class StubWidget extends StatelessWidget {
  const StubWidget({super.key, required this.moduleName});
  final String moduleName;

  @override
  Widget build(BuildContext context) {
    throw RuntimeError(
        'This widget requires the $moduleName module to be enabled.');
  }
}

abstract class SignInWithGoogle {
  static const type = 'SignInWithGoogle';
}

class SignInWithGoogleStub extends StubWidget implements SignInWithGoogle {
  const SignInWithGoogleStub({super.key}) : super(moduleName: 'Auth');
}

abstract class SignInWithApple {
  static const type = 'SignInWithApple';
}

class SignInWithAppleStub extends StubWidget implements SignInWithApple {
  const SignInWithAppleStub({super.key}) : super(moduleName: 'Auth');
}

abstract class ConnectWithGoogle {
  static const type = 'ConnectWithGoogle';
}

class ConnectWithGoogleStub extends StubWidget implements ConnectWithGoogle {
  const ConnectWithGoogleStub({super.key}) : super(moduleName: 'Auth');
}

abstract class ConnectWithMicrosoft {
  static const type = 'ConnectWithMicrosoft';
}

class ConnectWithMicrosoftStub extends StubWidget
    implements ConnectWithMicrosoft {
  const ConnectWithMicrosoftStub({super.key}) : super(moduleName: 'Auth');
}

abstract class SignInWithAuth0 {
  static const type = 'SignInWithAuth0';
}

class SignInWithAuth0Stub extends StubWidget implements SignInWithAuth0 {
  const SignInWithAuth0Stub({super.key}) : super(moduleName: 'Auth');
}

abstract class SignInAnonymous {
  Future<void> signInAnonymously(BuildContext context,
      {required SignInAnonymousAction action});
}

class SignInAnonymousStub implements SignInAnonymous {
  @override
  Future<void> signInAnonymously(BuildContext context,
      {required SignInAnonymousAction action}) {
    throw ConfigError(
        "Auth is not enabled. Please review the Ensemble documentation.");
  }
}

abstract class SignInWithCustomToken {
  Future<void> signInWithCustomToken(BuildContext context,
      {required SignInWithCustomTokenAction action});
}

class SignInWithCustomTokenStub implements SignInWithCustomToken {
  @override
  Future<void> signInWithCustomToken(BuildContext context,
      {required SignInWithCustomTokenAction action}) {
    throw ConfigError(
        "Auth is not enabled. Please review the Ensemble documentation.");
  }
}