import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'otp_pin_field_method_channel.dart';

abstract class OtpPinFieldPlatform extends PlatformInterface {
  /// Constructs a OtpPinFieldPlatform.
  OtpPinFieldPlatform() : super(token: _token);

  static final Object _token = Object();

  static OtpPinFieldPlatform _instance = MethodChannelOtpPinField();

  /// The default instance of [OtpPinFieldPlatform] to use.
  ///
  /// Defaults to [MethodChannelOtpPinField].
  static OtpPinFieldPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OtpPinFieldPlatform] when
  /// they register themselves.
  static set instance(OtpPinFieldPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> requestPhoneHint() {
    throw UnimplementedError('requestPhoneHint has not been implemented.');
  }

  Future<void> listenForCode(Map<String, String> smsCodeRegexPattern) {
    throw UnimplementedError('listenForCode has not been implemented.');
  }

  Future<void> unregisterListener() {
    throw UnimplementedError('unregisterListener has not been implemented.');
  }

  Future<String> getAppSignature() {
    throw UnimplementedError('getAppSignature has not been implemented.');
  }
}
