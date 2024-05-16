#import "OtpPinFieldPlugin.h"
#if __has_include(<otp_pin_field/otp_pin_field-Swift.h>)
#import <otp_pin_field/otp_pin_field-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "otp_pin_field-Swift.h"
#endif

@implementation OtpPinFieldPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftOtpPinFieldPlugin registerWithRegistrar:registrar];
}
@end
