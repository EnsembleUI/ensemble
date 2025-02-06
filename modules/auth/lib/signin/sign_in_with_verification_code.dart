import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef VerificationSuccessCallback = void Function(
    String verificationId, int? resendToken);
typedef VerificationErrorCallback = void Function(FirebaseAuthException error);

class SignInWithVerificationCode {
  final FirebaseAuth _auth;

  SignInWithVerificationCode({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  /// Sends a phone verification code to the specified [phoneNumber].
  Future<void> sendVerificationCode({
    required String provider,
    required String method,
    required String phoneNumber,
    required VerificationSuccessCallback onSuccess,
    required VerificationErrorCallback onError,
  }) async {
    if (provider == 'firebase') {
      if (method != 'phone') {
        throw ArgumentError('Unsupported method: $method');
      }
      await _sendVerificationCode(
        phoneNumber: phoneNumber,
        onSuccess: onSuccess,
        onError: onError,
      );
    } else {
      throw ArgumentError('Unsupported provider: $provider');
    }
  }

  /// Verifies the phone code with the provided [smsCode] and [verificationId].
  Future<Map<String, dynamic>?> validateVerificationCode({
    required String provider,
    required String method,
    required String smsCode,
    required String verificationId,
  }) async {
    try {
      if (provider == 'firebase') {
        if (method != 'phone') {
          throw ArgumentError('Unsupported method: $method');
        }
        return await _validateFirebaseVerificationCode(
          smsCode: smsCode,
          verificationId: verificationId,
        );
      } else {
        throw ArgumentError('Unsupported provider: $provider');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Resends a phone verification code using [resendToken].
  Future<void> resendVerificationCode({
    required String provider,
    required String method,
    required String phoneNumber,
    required int resendToken,
    required VerificationSuccessCallback onSuccess,
    required VerificationErrorCallback onError,
  }) async {
    if (provider == 'firebase') {
      if (method != 'phone') {
        throw ArgumentError('Unsupported method: $method');
      }
      await _sendVerificationCode(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        onSuccess: onSuccess,
        onError: onError,
      );
    } else {
      throw ArgumentError('Unsupported provider: $provider');
    }
  }

  /// Verify the phone number using Firebase's [verifyPhoneNumber].
  Future<void> _sendVerificationCode({
    required String phoneNumber,
    int? forceResendingToken,
    required VerificationSuccessCallback onSuccess,
    required VerificationErrorCallback onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          _handleFirebaseError(e, onError);
        },
        codeSent: (String verificationId, int? resendToken) {
          onSuccess(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Validate the phone code using Firebase's [signInWithCredential].
  Future<Map<String, dynamic>?> _validateFirebaseVerificationCode({
    required String smsCode,
    required String verificationId,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'User not found.',
        );
      }

      final String? idToken = await userCredential.user!.getIdToken();

      final authenticatedUser = AuthenticatedUser(
        id: userCredential.user!.uid,
        phoneNumber: userCredential.user!.phoneNumber ?? '',
        provider: SignInProvider.firebase,
      );

      return {
        'user': authenticatedUser,
        'idToken': idToken,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Log the Firebase error and pass it to [onError].
  void _handleFirebaseError(
      FirebaseAuthException e, VerificationErrorCallback onError) {
    onError(e);
  }
}
