#import "ReceiveSharingIntentPlugin.h"
#if __has_include(<flutter_share_receiver/flutter_share_receiver-Swift.h>)
#import <flutter_share_receiver/flutter_share_receiver-Swift.h>
#else
#import "flutter_share_receiver-Swift.h"
#endif

@implementation ReceiveSharingIntentPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftReceiveSharingIntentPlugin registerWithRegistrar:registrar];
}
@end
