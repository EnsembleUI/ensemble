#import "EnsembleAgentPlugin.h"
#if __has_include(<ensemble_agent/ensemble_agent-Swift.h>)
#import <ensemble_agent/ensemble_agent-Swift.h>
#else
#import "ensemble_agent-Swift.h"
#endif

@implementation EnsembleAgentPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftEnsembleAgentPlugin registerWithRegistrar:registrar];
}
@end
