import 'dart:io';
import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  String? branchIOLiveKey =
      getArgumentValue(arguments, 'branch_live_key', required: true);
  String? branchIOTestKey = getArgumentValue(arguments, 'branch_test_key');
  bool useTestKey =
      getArgumentValue(arguments, 'use_test_key')?.toLowerCase() == 'true';
  String? scheme = getArgumentValue(arguments, 'scheme', required: true);
  List<String> links = getArgumentValue(arguments, 'links')?.split(',') ?? [];

  if (branchIOLiveKey == null || branchIOLiveKey.isEmpty) {
    print(
        'Error: Missing branch_live_key argument. Usage: npm run useConnect branch_live_key=<branch_live_key> branch_test_key=<branch_test_key> use_test_key=<true|false> scheme=<scheme> links=<link1,link2>');
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
      ref: main
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
      ensembleModulesFilePath,
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecFilePath, pubspecDependencies);

    // Inject the Branch.io script for the web platform
    if (platforms.contains('web')) {
      updateHtmlFile(
        webIndexFilePath,
        '</head>',
        branchScript,
      );
    }

    // Modify AndroidManifest.xml for deep linking
    if (platforms.contains('android')) {
      updateAndroidManifestWithDeeplink(
        androidManifestFilePath,
        branchIOLiveKey: branchIOLiveKey,
        branchIOTestKey: branchIOTestKey,
        useTestKey: useTestKey,
        scheme: scheme ?? '',
        links: links,
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

/// Function to update AndroidManifest.xml with deep link and Branch configuration.
void updateAndroidManifestWithDeeplink(
  String manifestFilePath, {
  required String? branchIOLiveKey,
  required String? branchIOTestKey,
  required bool useTestKey,
  required String scheme,
  required List<String> links,
}) {
  String manifestContent = readFileContent(manifestFilePath);

  // Update the launchMode for the main activity from "singleTop" to "singleTask"
  manifestContent = manifestContent.replaceFirst(
    'android:launchMode="singleTop"',
    'android:launchMode="singleTask"',
  );

  // Add the Branch URI scheme and App Links inside the MainActivity
  final branchURIScheme = '''
    <!-- Branch URI Scheme -->
            <intent-filter>
                <data android:scheme="$scheme" android:host="open"/>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
            </intent-filter>
            ''';

  final branchAppLinks = '''
            <!-- Branch App Links -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                ${links.map((link) {
    final parts = link.split("://");
    final scheme = parts.length > 1 ? parts[0] : 'https';
    final host = parts[parts.length - 1].replaceAll('/', '');
    return '<data android:scheme="$scheme" android:host="$host" />';
  }).join("\n                ")}
            </intent-filter>''';

  // Insert the Branch-related intent filters inside the <activity> tag for MainActivity
  if (!manifestContent.contains('<!-- Branch URI Scheme -->')) {
    manifestContent = manifestContent.replaceFirst(
      '</activity>',
      '$branchURIScheme\n$branchAppLinks\n        </activity>',
    );
  }

  // Add the Branch meta-data at the end of the <application> block
  final branchMetaData = '''
    <!-- Branch init -->
        <meta-data android:name="io.branch.sdk.BranchKey" android:value="$branchIOLiveKey" />
        <meta-data android:name="io.branch.sdk.BranchKey.test" android:value="$branchIOTestKey" />
        <meta-data android:name="io.branch.sdk.TestMode" android:value="${useTestKey.toString().capitalize()}" />''';

  if (!manifestContent.contains('io.branch.sdk.BranchKey')) {
    manifestContent = manifestContent.replaceFirst(
      '</application>',
      '$branchMetaData\n    </application>',
    );
  }

  // Write the modified content back to the file
  writeFileContent(manifestFilePath, manifestContent);
}

extension StringExtensions on String {
  String capitalize() {
    return this.isEmpty
        ? this
        : this[0].toUpperCase() + this.substring(1).toLowerCase();
  }
}
