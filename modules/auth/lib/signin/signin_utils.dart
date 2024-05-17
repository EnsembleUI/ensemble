import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignInUtils {
  /// convert a Google user account to our User
  static AuthenticatedUser fromGoogleUser(GoogleSignInAccount account,
          {SignInProvider? provider}) =>
      AuthenticatedUser(
          client: SignInClient.google,
          provider: provider,
          id: account.id,
          name: account.displayName,
          email: account.email,
          photo: account.photoUrl);
}
