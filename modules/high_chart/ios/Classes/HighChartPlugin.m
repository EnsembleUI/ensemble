#import "HighChartPlugin.h"
#if __has_include(<high_chart/high_chart-Swift.h>)
#import <high_chart/high_chart-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "high_chart-Swift.h"
#endif

@implementation HighChartPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftHighChartPlugin registerWithRegistrar:registrar];
}
@end
