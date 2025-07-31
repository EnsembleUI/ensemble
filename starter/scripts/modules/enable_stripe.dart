import 'dart:io';

import '../utils.dart';
import '../utils/proguard_utils.dart';

Future<void> main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final stripeStatements = {
    'moduleStatements': [
      "import 'package:ensemble_stripe/ensemble_stripe.dart';",
      "GetIt.I.registerSingleton<StripeModule>(StripeModuleImpl());",
    ],
    'useStatements': [
      'static const useStripe = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_stripe:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/ensemble_stripe''',
      'regex':
          r'#\s*ensemble_stripe:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/ensemble_stripe',
    }
  ];

  final iOSPermissions = [
    {
      'key': 'cameraDescription',
      'value': 'NSCameraUsageDescription',
    },
  ];

  const proguardRules = '''
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity\$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter\$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter\$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
-keep class com.stripe.** { *; }
''';

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      stripeStatements['moduleStatements'],
      stripeStatements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    // Update iOS configuration for Stripe
    if (platforms.contains('ios')) {
      updateIOSPermissions(iOSPermissions, arguments);
    }

    if (platforms.contains('android')) {
      createProguardRules(proguardRules);
    }

    print('Stripe module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
