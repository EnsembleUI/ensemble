import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:ensemble_auth/signin/sign_in_with_phone.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  Future<void> verifyPhoneNumber({
    String? autoRetrievedSmsCodeForTesting,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    int? forceResendingToken,
    PhoneMultiFactorInfo? multiFactorInfo,
    MultiFactorSession? multiFactorSession,
    String? phoneNumber,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (phoneNumber == '+1234567890') {
      print('Mock: Verification code sent successfully for $phoneNumber');
      codeSent('testVerificationId', null);
    } else if (phoneNumber == '') {
      print('Mock: Empty phone number provided');
      verificationFailed(FirebaseAuthException(
        code: 'empty-phone-number',
        message: 'Phone number cannot be empty.',
      ));
    } else {
      print('Mock: Invalid phone number provided: $phoneNumber');
      verificationFailed(FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'Invalid phone number provided.',
      ));
    }
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    if (credential is PhoneAuthCredential && credential.smsCode == '123456') {
      print('Mock: Successful sign-in with SMS code ${credential.smsCode}');
      return MockUserCredential();
    } else {
      print('Mock: Invalid verification code provided');
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'The verification code is invalid.',
      );
    }
  }

  @override
  User? get currentUser => MockUser();
}

class MockUserCredential extends Mock implements UserCredential {
  @override
  User? get user => MockUser();
}

class MockUser extends Mock implements User {
  @override
  String get uid => 'mock-uid';

  @override
  String get phoneNumber => '+1234567890';
}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late SignInWithPhone signInWithPhone;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    signInWithPhone = SignInWithPhone(firebaseAuth: mockFirebaseAuth);
    print('Setup: MockFirebaseAuth and SignInWithPhone initialized');
  });

  group('SignInWithPhone Tests', () {
    test('Send Phone Verification Code - Success', () async {
      print('Test: Send Phone Verification Code - Success');
      bool successCallbackCalled = false;

      await signInWithPhone.sendPhoneVerificationCode(
        phoneNumber: '+1234567890',
        onSuccess: (verificationId, resendToken) {
          successCallbackCalled = true;
          print('Callback: Success - Verification ID: $verificationId');
          expect(verificationId, equals('testVerificationId'));
        },
        onError: (error) {
          fail('Error callback should not be called on success');
        },
      );

      expect(successCallbackCalled, isTrue);
    });

    test('Send Phone Verification Code - Empty Phone Number', () async {
      print('Test: Send Phone Verification Code - Empty Phone Number');
      bool errorCallbackCalled = false;

      await signInWithPhone.sendPhoneVerificationCode(
        phoneNumber: '',
        onSuccess: (verificationId, resendToken) {
          fail('Success callback should not be called for empty phone number');
        },
        onError: (error) {
          errorCallbackCalled = true;
          print(
              'Callback: Error - Code: ${error.code}, Message: ${error.message}');
          expect(error.code, equals('empty-phone-number'));
          expect(error.message, equals('Phone number cannot be empty.'));
        },
      );

      expect(errorCallbackCalled, isTrue);
    });

    test('Verify Phone Code - Success', () async {
      print('Test: Verify Phone Code - Success');
      final user = await signInWithPhone.verifyPhoneCode(
        smsCode: '123456',
        verificationId: 'testVerificationId',
      );

      print('Result: User ID: ${user?.id}, Phone Number: ${user?.phoneNumber}');
      expect(user, isNotNull);
      expect(user?.phoneNumber, equals('+1234567890'));
      expect(user?.id, equals('mock-uid'));
    });

    test('Verify Phone Code - Invalid Code', () async {
      print('Test: Verify Phone Code - Invalid Code');
      expect(
        () async => await signInWithPhone.verifyPhoneCode(
          smsCode: '654321',
          verificationId: 'testVerificationId',
        ),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.message,
          'message',
          equals('The verification code is invalid.'),
        )),
      );
    });

    test('Resend Phone Verification Code - Success', () async {
      print('Test: Resend Phone Verification Code - Success');
      bool successCallbackCalled = false;

      await signInWithPhone.resendPhoneVerificationCode(
        phoneNumber: '+1234567890',
        resendToken: 12345,
        onSuccess: (verificationId, resendToken) {
          successCallbackCalled = true;
          print('Callback: Success - Verification ID: $verificationId');
          expect(verificationId, equals('testVerificationId'));
          expect(resendToken, isNull); // Simulated null token
        },
        onError: (error) {
          fail('Error callback should not be called on success');
        },
      );

      expect(successCallbackCalled, isTrue);
    });

    test('Resend Phone Verification Code - Invalid Phone Number', () async {
      print('Test: Resend Phone Verification Code - Invalid Phone Number');
      bool errorCallbackCalled = false;

      await signInWithPhone.resendPhoneVerificationCode(
        phoneNumber: '+0987654321',
        resendToken: 12345,
        onSuccess: (verificationId, resendToken) {
          fail('Success callback should not be called on failure');
        },
        onError: (error) {
          errorCallbackCalled = true;
          print(
              'Callback: Error - Code: ${error.code}, Message: ${error.message}');
          expect(error.code, equals('invalid-phone-number'));
          expect(error.message, equals('Invalid phone number provided.'));
        },
      );

      expect(errorCallbackCalled, isTrue);
    });
  });
}
