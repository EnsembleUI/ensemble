import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

typedef VerificationSuccessCallback = void Function(
    String verificationId, int? resendToken);
typedef VerificationErrorCallback = void Function(FirebaseAuthException error);

class SignInWithVerificationCode {
  final FirebaseAuth _auth;
  final Logger _logger = Logger('SignInWithVerificationCode');

  SignInWithVerificationCode({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  /// Sends a phone verification code to the specified [phoneNumber].
  Future<void> sendVerificationCode({
    required String provider,
    required String phoneNumber,
    required VerificationSuccessCallback onSuccess,
    required VerificationErrorCallback onError,
  }) async {
    if (provider == 'firebase') {
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
  Future<AuthenticatedUser?> validateVerificationCode({
    required String provider,
    required String smsCode,
    required String verificationId,
  }) async {
    try {
      if (provider == 'firebase') {
        return await _validateFirebaseVerificationCode(
          smsCode: smsCode,
          verificationId: verificationId,
        );
      } else {
        throw ArgumentError('Unsupported provider: $provider');
      }
    } catch (e) {
      _logger.warning('Error during phone code verification: ${e.toString()}');
      rethrow;
    }
  }

  /// Resends a phone verification code using [resendToken].
  Future<void> resendVerificationCode({
    required String provider,
    required String phoneNumber,
    required int resendToken,
    required VerificationSuccessCallback onSuccess,
    required VerificationErrorCallback onError,
  }) async {
    if (provider == 'firebase') {
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
      _logger.severe('Unexpected error in _verifyPhoneNumber: ${e.toString()}');
      rethrow;
    }
  }

  /// Validate the phone code using Firebase's [signInWithCredential].
  Future<AuthenticatedUser?> _validateFirebaseVerificationCode({
    required String smsCode,
    required String verificationId,
  }) async {
    try {
      _logger.info('Verifying phone code with verificationId: $verificationId');
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

      return AuthenticatedUser(
        id: userCredential.user!.uid,
        phoneNumber: userCredential.user!.phoneNumber ?? '',
        provider: SignInProvider.firebase,
      );
    } catch (e) {
      _logger.warning('Error during phone code verification: ${e.toString()}');
      rethrow;
    }
  }

  /// Log the Firebase error and pass it to [onError].
  void _handleFirebaseError(
      FirebaseAuthException e, VerificationErrorCallback onError) {
    _logger.warning('Firebase error occurred: ${e.code} - ${e.message}');
    onError(e);
  }
}
