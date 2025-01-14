import 'dart:io';

import '../utils.dart';

// Function to update AndroidManifest.xml with deep link and Branch configuration.
void updateAndroidManifestWithDeeplink({
  required String scheme,
  required List<String> links,
}) {
  String manifestContent = readFileContent(androidManifestFilePath);

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
  // Write the modified content back to the file
  writeFileContent(androidManifestFilePath, manifestContent);
}

// Function to add a block of code above a specific line in Info.plist
void addBlockAboveLineInInfoPlist(String scheme, String lineToFind) {
  File plistFile = File(iosInfoPlistFilePath);
  if (!plistFile.existsSync()) {
    throw Exception('Error: File does not exist at $iosInfoPlistFilePath');
  }

  String plistContent = plistFile.readAsStringSync();

  // Define the block to insert, now using the passed `scheme`
  final blockToInsert = '''
<dict>
          <key>CFBundleTypeRole</key>
          <string>Editor</string>
          <key>CFBundleURLSchemes</key>
          <array>
            <string>$scheme</string>
          </array>
          <key>CFBundleURLName</key>
          <string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </dict>
''';

  // Insert the block above the specified line
  if (!plistContent.contains(blockToInsert)) {
    int insertIndex = plistContent.indexOf(lineToFind);
    if (insertIndex != -1) {
      plistContent = plistContent.replaceRange(
          insertIndex, insertIndex, '$blockToInsert\n        ');
      plistFile.writeAsStringSync(plistContent);
      print('Block added above $lineToFind in Info.plist');
    } else {
      throw Exception(
          'Error: The line "$lineToFind" was not found in Info.plist.');
    }
  } else {
    print('Block already exists in Info.plist, skipping.');
  }
}
