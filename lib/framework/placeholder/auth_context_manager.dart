import 'package:ensemble/framework/error_handling.dart';

abstract class AuthContextManagerBase {}

class AuthContextManagerStub implements AuthContextManagerBase {
  AuthContextManagerStub() {
    throw RuntimeError('Auth is not enabled.');
  }
}
