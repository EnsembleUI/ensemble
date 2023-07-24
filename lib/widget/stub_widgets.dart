import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter/cupertino.dart';

class StubWidget extends StatelessWidget {
  const StubWidget({super.key});

  @override
  Widget build(BuildContext context) {
    throw RuntimeError('$runtimeType is not enabled.');
  }
}

abstract class SignInWithGoogleBase {
  static const type = 'SignInWithGoogle';
}

class SignInWithGoogleStub extends StubWidget implements SignInWithGoogleBase {
  const SignInWithGoogleStub({super.key});
}

abstract class SignInWithAppleBase {
  static const type = 'SignInWithApple';
}

class SignInWithAppleStub extends StubWidget implements SignInWithAppleBase {
  const SignInWithAppleStub({super.key});
}
