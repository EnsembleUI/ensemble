import 'package:ensemble/action/invoke_api_action.dart';

/// an Action to sign in with the Server after authenticating with social sign in
class SignInWithServerAPIAction extends InvokeAPIAction {
  SignInWithServerAPIAction(
      {required InvokeAPIAction apiAction, this.signInCredentials})
      : super(
      initiator: apiAction.initiator,
      apiName: apiAction.apiName,
      id: apiAction.id,
      inputs: apiAction.inputs,
      onResponse: apiAction.onResponse,
      onError: apiAction.onError);

  /// the map of sign in credentials returned by the server
  Map? signInCredentials;

  factory SignInWithServerAPIAction.fromMap({required Map payload }) {
    InvokeAPIAction apiAction = InvokeAPIAction.fromYaml(payload: payload);
    return SignInWithServerAPIAction(
        apiAction: apiAction, signInCredentials: payload['setSignInCredentialsOnResponse']);
  }
}