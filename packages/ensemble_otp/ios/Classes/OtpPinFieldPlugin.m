#import "OtpPinFieldPlugin.h"
#if __has_include(<ensemble_otp/ensemble_otp-Swift.h>)
#import <ensemble_otp/ensemble_otp-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "ensemble_otp-Swift.h"
#endif

@implementation OtpPinFieldPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftOtpPinFieldPlugin registerWithRegistrar:registrar];
}
@end
