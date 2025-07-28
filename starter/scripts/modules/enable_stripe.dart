import 'dart:io';

import '../utils.dart';

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

    // Update ensemble-config.yaml to enable Stripe
    updateStripeConfig(arguments);

    print('Stripe module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}

void updateStripeConfig(List<String> arguments) {
  final publishableKey = getArgumentValue(arguments, 'publishableKey');
  final stripeAccountId = getArgumentValue(arguments, 'stripeAccountId');
  final merchantIdentifier = getArgumentValue(arguments, 'merchantIdentifier');

  if (publishableKey == null) {
    throw Exception('Missing required parameter: publishableKey');
  }

  try {
    final file = File(ensembleConfigFilePath);
    if (!file.existsSync()) {
      throw Exception('Config file not found.');
    }

    String content = file.readAsStringSync();

    // Simple approach: replace each commented line individually
    // This is more reliable than complex regex patterns
    content = content.replaceAll('#stripe:', 'stripe:');
    content = content.replaceAll('#  enabled: true', '  enabled: true');
    content = content.replaceAll(
        '#  publishableKey: "pk_test_your_publishable_key_here"',
        '  publishableKey: "$publishableKey"');
    if (stripeAccountId != null) {
      content = content.replaceAll(
          '#  stripeAccountId: "acct_optional_account_id"  # Optional',
          '  stripeAccountId: "$stripeAccountId"  # Optional');
    }
    if (merchantIdentifier != null) {
      content = content.replaceAll(
          '#  merchantIdentifier: "merchant.com.yourapp"   # Optional, for Apple Pay',
          '  merchantIdentifier: "$merchantIdentifier"   # Optional, for Apple Pay');
    }

    file.writeAsStringSync(content);
  } catch (e) {
    throw Exception(
        'Failed to update Stripe configuration in ensemble-config.yaml: $e');
  }
}
