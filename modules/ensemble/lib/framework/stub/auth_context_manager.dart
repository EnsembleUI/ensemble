import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

abstract class AuthContextManager {
  Future<AuthenticatedUser?> getSignedInUser();
  Future<void> signOut();
}

class AuthContextManagerStub implements AuthContextManager {
  AuthContextManagerStub() {
    throw RuntimeError('Auth is not enabled.');
  }

  @override
  Future<AuthenticatedUser?> getSignedInUser() {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }
}

/// an abstraction of the currently signed in User over the different
/// Sign-in providers (firebase, auth0, ..) as well as Sign-in clients (google, apple, ...)
class AuthenticatedUser with Invokable {
  AuthenticatedUser(
      {this.client,
      this.provider,
      required this.id,
      this.name,
      this.email,
      this.photo,
      this.data,
      this.phoneNumber,
      this.emailLVerified,
      this.tenantId,
      this.creationTime,
      this.lastSignInTime,
      this.isAnonymous = false});

  final SignInClient? client;
  SignInProvider? provider;

  // basic info provided by the sign in clients
  String? id;
  String? name;
  String? email;
  String? photo;

  // extra info provided if use Firebase
  String? phoneNumber;
  bool? emailLVerified;
  String? tenantId;
  DateTime? creationTime;
  DateTime? lastSignInTime;

  bool isAnonymous;

  // optional server credentials (bearer token, cookies, ....) associated with this user account
  // TODO: move to secure storage
  Map? data;
  void setServerCredentials(Map? credentials) {
    if (credentials != null) {
      (data ??= {}).addAll(credentials);
    }
  }

  @override
  Map<String, Function> getters() {
    return {
      'client': () => client?.name,
      'provider': () => provider?.name,
      'id': () => id,
      'name': () => name,
      'email': () => email,
      'photo': () => photo,
      'data': () => data,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

enum SignInClient { google, apple, microsoft, auth0 }

enum SignInProvider {
  local, // store the login state locally on the client
  server, // login on the server. Client will trigger onAuthenticated but not onSignedIn
  firebase,
  auth0
}
