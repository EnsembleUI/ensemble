import 'dart:io';
import '../utils.dart';
import '../utils/deeplink_utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);

  String? branchIOLiveKey =
      getArgumentValue(arguments, 'branch_live_key', required: true);
  String? branchIOTestKey =
      getArgumentValue(arguments, 'branch_test_key', required: true);
  bool useTestKey =
      getArgumentValue(arguments, 'use_test_key')?.toLowerCase() == 'true';
  String? scheme = getArgumentValue(arguments, 'scheme', required: true);
  List<String> links = getArgumentValue(arguments, 'links')?.split(',') ?? [];

  if (branchIOLiveKey == null ||
      branchIOLiveKey.isEmpty ||
      branchIOTestKey == null ||
      branchIOTestKey.isEmpty) {
    print(
        'Error: Missing branch_live_key argument. Usage: npm run useDeeplink branch_live_key=<branch_live_key> branch_test_key=<branch_test_key> use_test_key=<true|false> scheme=<scheme> links=<link1,link2>');
    exit(1);
  }

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_deeplink/deferred_link_manager.dart';",
      'GetIt.I.registerSingleton<DeferredLinkManager>(DeferredLinkManagerImpl());',
    ],
    'useStatements': [
      'static const useDeeplink = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_deeplink:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await getEnsembleRef()}
      path: modules/deeplink''',
      'regex':
          r'#\s*ensemble_deeplink:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/deeplink',
    }
  ];

  // Prepare Branch.io initialization script for web
  final branchScript = '''
<script>
    (function (b, r, a, n, c, h, _, s, d, k) {
      if (!b[n] || !b[n]._q) {
        for (; s < _.length; ) c(h, _[s++]);
        d = r.createElement(a);
        d.async = 1;
        d.src = "https://cdn.branch.io/branch-latest.min.js";
        k = r.getElementsByTagName(a)[0];
        k.parentNode.insertBefore(d, k);
        b[n] = h;
      }
    })(window, document, "script", "branch", function (b, r) {
        b[r] = function () {
          b._q.push([r, arguments]);
        };
      }, { _q: [], _v: 1 },
      "addListener applyCode autoAppIndex banner closeBanner closeJourney creditHistory credits data deepview deepviewCta first getCode init link logout redeem referrals removeListener sendSMS setBranchViewData setIdentity track validateCode trackCommerceEvent logEvent disableTracking".split(" "),
      0
    );
    branch.init("$branchIOLiveKey");
  </script>''';

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    // Inject the Branch.io script for the web platform
    if (platforms.contains('web')) {
      updateHtmlFile(
        '</head>',
        branchScript,
      );
    }

    updatePropertiesFile('branchTestKey', branchIOTestKey);
    updatePropertiesFile('branchLiveKey', branchIOLiveKey);

    // Modify AndroidManifest.xml for deep linking
    if (platforms.contains('android')) {
      final branchMetaData = [
        '<meta-data android:name="io.branch.sdk.BranchKey" android:value="$branchIOLiveKey" />',
        '<meta-data android:name="io.branch.sdk.BranchKey.test" android:value="$branchIOTestKey" />',
        '<meta-data android:name="io.branch.sdk.TestMode" android:value="${useTestKey.toString().capitalize()}" />',
      ];
      updateAndroidPermissions(metaData: branchMetaData);
      updateAndroidManifestWithDeeplink(
        scheme: scheme ?? '',
        links: links,
      );
    }

    // Modify Info.plist for deep linking on iOS
    if (platforms.contains('ios')) {
      addPermissionDescriptionToInfoPlist(
        'branch_universal_link_domains',
        links,
        isArray: true,
      );

      addPermissionDescriptionToInfoPlist(
        'branch_key',
        {
          'live': branchIOLiveKey,
          'test': branchIOTestKey,
        },
        isDict: true,
      );

      addBlockAboveLineInInfoPlist(
        scheme ?? '',
        '<!-- Google Sign in, replace with your URL scheme -->',
      );

      updateRunnerEntitlements(
        module: 'deeplink',
        deeplinkLinks: links,
      );
    }

    print(
        'Deeplink module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
