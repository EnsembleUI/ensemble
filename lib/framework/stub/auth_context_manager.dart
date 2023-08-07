import 'package:ensemble/framework/error_handling.dart';

abstract class AuthContextManager {}

class AuthContextManagerStub implements AuthContextManager {
  AuthContextManagerStub() {
    throw RuntimeError('Auth is not enabled.');
  }
}
