import 'dart:io';

const String ensembleModulesFilePath = 'lib/generated/ensemble_modules.dart';
const String pubspecFilePath = 'pubspec.yaml';
const String androidManifestFilePath =
    'android/app/src/main/AndroidManifest.xml';
const String iosInfoPlistFilePath = 'ios/Runner/Info.plist';
const String webIndexFilePath = 'web/index.html';
const String ensemblePropertiesFilePath = 'ensemble/ensemble.properties';
const String ensembleConfigFilePath = 'ensemble/ensemble-config.yaml';
const String appDelegatePath = 'ios/Runner/AppDelegate.swift';
const String runnerEntitlementsPath = 'ios/Runner/Runner.entitlements';

// To read file content
String readFileContent(String filePath) {
  File file = File(filePath);
  if (!file.existsSync()) {
    throw Exception('$filePath not found.');
  }
  return file.readAsStringSync();
}

// Helper function to parse individual arguments in key=value format
String? getArgumentValue(List<String> arguments, String key,
    {bool required = false}) {
  for (var arg in arguments) {
    final parts = arg.split('=');
    if (parts.length == 2 && parts[0] == key) {
      return parts[1];
    }
  }

  if (required) {
    throw Exception('Missing required argument: $key');
  }

  return null;
}

// Process platforms argument, defaulting to ['ios', 'android', 'web'] if not specified
List<String> getPlatforms(List<String> arguments,
    {List<String> defaultPlatforms = const ['ios', 'android', 'web']}) {
  String? platformArg = getArgumentValue(arguments, 'platform');
  if (platformArg != null && platformArg.isNotEmpty) {
    return platformArg.split(',').map((platform) => platform.trim()).toList();
  }
  return defaultPlatforms;
}

// To update content using regex
String updateContent(String content, String regexPattern, String replacement) {
  final RegExp regex = RegExp(regexPattern);
  if (!regex.hasMatch(content) && !content.contains(replacement)) {
    throw Exception('Pattern not found: $regexPattern');
  }
  return content.replaceAllMapped(regex, (match) => replacement);
}

// To write updated content to file
void writeFileContent(String filePath, String content) {
  File file = File(filePath);
  file.writeAsStringSync(content);
}

// Add permission descriptions to Info.plist
void addPermissionDescriptionToInfoPlist(
    String plistPath, String key, dynamic description,
    {bool isArray = false, bool isBoolean = false, bool isDict = false}) {
  File plistFile = File(plistPath);
  if (!plistFile.existsSync()) {
    throw Exception('Error: File does not exist at $plistPath');
  }

  String plistContent = plistFile.readAsStringSync();
  bool updated = false;

  if (plistContent.contains('<key>$key</key>')) {
    if (!isArray && !isBoolean && !isDict) {
      RegExp regex = RegExp('<key>$key</key>\\s*<string>[^<]*</string>');
      String replacement = '<key>$key</key>\n    <string>$description</string>';
      plistContent = plistContent.replaceAll(regex, replacement);
      updated = true;
    } else if (isBoolean) {
      RegExp regex = RegExp('<key>$key</key>\\s*<(true|false)/>');
      String replacement =
          '<key>$key</key>\n    <${description ? 'true' : 'false'}/>';
      plistContent = plistContent.replaceAll(regex, replacement);
      updated = true;
    } else if (isArray) {
      RegExp regex =
          RegExp('<key>$key</key>\\s*<array>(.*?)</array>', dotAll: true);
      String arrayValues = (description as List)
          .map((item) => '        <string>$item</string>')
          .join('\n');
      String replacement =
          '<key>$key</key>\n    <array>\n$arrayValues\n    </array>';
      plistContent = plistContent.replaceAll(regex, replacement);
      updated = true;
    } else if (isDict) {
      RegExp regex =
          RegExp('<key>$key</key>\\s*<dict>(.*?)</dict>', dotAll: true);
      String dictValues = (description as Map<String, String>)
          .entries
          .map((entry) =>
              '        <key>${entry.key}</key>\n        <string>${entry.value}</string>')
          .join('\n');
      String replacement =
          '<key>$key</key>\n    <dict>\n$dictValues\n    </dict>';
      plistContent = plistContent.replaceAll(regex, replacement);
      updated = true;
    }
  }

  if (!updated) {
    // Find the closing </dict> tag to insert before
    final dictEndIndex = plistContent.lastIndexOf('</dict>');
    if (dictEndIndex != -1) {
      String toInsert;
      if (isArray) {
        String arrayValues = (description as List)
            .map((item) => '        <string>$item</string>')
            .join('\n');
        toInsert =
            '    <key>$key</key>\n    <array>\n$arrayValues\n    </array>\n';
      } else if (isBoolean) {
        toInsert =
            '    <key>$key</key>\n    <${description ? 'true' : 'false'}/>\n';
      } else if (isDict) {
        String dictValues = (description as Map<String, String>)
            .entries
            .map((entry) =>
                '        <key>${entry.key}</key>\n        <string>${entry.value}</string>')
            .join('\n');
        toInsert =
            '    <key>$key</key>\n    <dict>\n$dictValues\n    </dict>\n';
      } else {
        toInsert = '    <key>$key</key>\n    <string>$description</string>\n';
      }

      plistContent =
          plistContent.replaceRange(dictEndIndex, dictEndIndex, toInsert);
      updated = true;
    }
  }

  if (!updated) {
    throw Exception('Failed to update Info.plist with $key');
  }

  plistFile.writeAsStringSync(plistContent);
}

// Convert a string to a regex pattern
String toRegexPattern(String statement, {bool isBoolean = false}) {
  if (isBoolean) {
    // For boolean statements like 'static const useCamera = true;'
    final prefix = statement.split('=')[0].trim();
    return RegExp.escape(prefix) + r'\s*=\s*(true|false);';
  } else {
    // For code statements like imports or registrations that may be commented out
    String escapedStatement = RegExp.escape(statement);
    return r'\/\/\s*' + escapedStatement.replaceAll(' ', r'\s+');
  }
}

// Update ensemble_modules.dart file
void updateEnsembleModules(String filePath, List<String>? codeStatements,
    List<String>? useStatements) {
  String content = readFileContent(filePath);

  // Process code statements (imports and register statements)
  if (codeStatements != null && codeStatements.isNotEmpty) {
    for (var statement in codeStatements) {
      String regexPattern = toRegexPattern(statement);
      content = updateContent(content, regexPattern, statement);
    }
  }

  // Process use statements (e.g., static const useCamera = true)
  if (useStatements != null && useStatements.isNotEmpty) {
    for (var statement in useStatements) {
      String regexPattern = toRegexPattern(statement, isBoolean: true);
      content = updateContent(content, regexPattern, statement);
    }
  }

  writeFileContent(filePath, content);
}

// Update pubspec.yaml file and throw error if content is not updated
void updatePubspec(
    String filePath, List<Map<String, String>> pubspecDependencies) {
  String pubspecContent = readFileContent(filePath);

  for (var statementObj in pubspecDependencies) {
    pubspecContent = updateContent(pubspecContent, statementObj['regex'] ?? '',
        statementObj['statement'] ?? '');
  }

  writeFileContent(filePath, pubspecContent);
}

// Update AndroidManifest.xml with permissions and throw error if not updated
void updateAndroidPermissions(String manifestFilePath,
    {List<String>? permissions, List<String>? metaData}) {
  String manifestContent = readFileContent(manifestFilePath);

  if (permissions != null && permissions.isNotEmpty) {
    String comment =
        '<!-- UPDATE for your Starter. These are default permissions -->';

    for (var permission in permissions) {
      if (!manifestContent.contains(permission)) {
        manifestContent = manifestContent.replaceFirst(
          comment,
          '$comment\n    $permission',
        );
      }
    }
  }

  // Handle meta-data if provided
  if (metaData != null && metaData.isNotEmpty) {
    final applicationEndIndex = manifestContent.lastIndexOf('</application>');
    if (applicationEndIndex == -1) {
      throw Exception(
          'Error: Could not find </application> tag in AndroidManifest.xml');
    }

    for (String metaDataContent in metaData) {
      if (!manifestContent.contains(metaDataContent)) {
        manifestContent = manifestContent.replaceRange(applicationEndIndex,
            applicationEndIndex, '    $metaDataContent\n    ');
      }
    }
  }

  writeFileContent(manifestFilePath, manifestContent);
}

// Update Info.plist for iOS with permissions and descriptions
void updateIOSPermissions(String plistFilePath,
    List<Map<String, String>> iOSPermissions, List<String> arguments,
    {List<Map<String, dynamic>> additionalSettings = const []}) {
  for (var permission in iOSPermissions) {
    String? paramValue = getArgumentValue(arguments, permission['key']!);

    if (paramValue != null && paramValue.isNotEmpty) {
      addPermissionDescriptionToInfoPlist(
          plistFilePath, permission['value'] ?? '', paramValue);
    }
  }

  // Process additional settings (arrays, booleans, etc.) if provided
  for (var setting in additionalSettings) {
    if (setting['isArray'] == true) {
      addPermissionDescriptionToInfoPlist(
          plistFilePath, setting['key'], setting['value'],
          isArray: true);
    } else if (setting['isBoolean'] == true) {
      addPermissionDescriptionToInfoPlist(
          plistFilePath, setting['key'], setting['value'],
          isBoolean: true);
    } else {
      addPermissionDescriptionToInfoPlist(
          plistFilePath, setting['key'], setting['value']);
    }
  }
}

// To update an HTML file with a new content before a specific marker (like </head>)
void updateHtmlFile(String filePath, String marker, String contentToAdd) {
  // Check if the HTML file exists
  if (!File(filePath).existsSync()) {
    throw Exception('Error: $filePath not found');
  }

  String content = File(filePath).readAsStringSync();

  if (!content.contains(contentToAdd)) {
    // Insert the new content before the marker (e.g., </head>)
    content = content.replaceFirst(marker, '  $contentToAdd\n$marker');
    File(filePath).writeAsStringSync(content);
  }
}

void updatePropertiesFile(String filePath, String key, String value) {
  File propertiesFile = File(filePath);
  if (!propertiesFile.existsSync()) {
    throw Exception('Error: $filePath not found.');
  }

  List<String> lines = propertiesFile.readAsLinesSync();
  bool updated = false;

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('$key=')) {
      lines[i] = '$key=$value';
      updated = true;
      break;
    }
  }

  if (!updated) {
    lines.add('$key=$value');
  }

  propertiesFile.writeAsStringSync(lines.join('\n').trim());
}

void updateAppDelegateForGoogleMaps(String filePath, String googleMapsApiKey) {
  File appDelegateFile = File(filePath);
  if (!appDelegateFile.existsSync()) {
    throw Exception('Error: $filePath not found.');
  }

  // Read the file content
  String content = appDelegateFile.readAsStringSync();

  // Uncomment the Google Maps import and API key lines if they are commented
  content = content.replaceAllMapped(
      RegExp(r'\/\/\s*import\s+GoogleMaps'), (match) => 'import GoogleMaps');

  content = content.replaceAllMapped(
      RegExp(r'\/\/\s*GMSServices\.provideAPIKey\("(.*?)"\)'),
      (match) => '    GMSServices.provideAPIKey("$googleMapsApiKey")');

  // Write the updated content back to the file
  appDelegateFile.writeAsStringSync(content.trim());
  print('AppDelegate.swift updated successfully with Google Maps API key.');
}

extension StringExtensions on String {
  String capitalize() {
    return this.isEmpty
        ? this
        : this[0].toUpperCase() + this.substring(1).toLowerCase();
  }
}

// Function to update the Runner.entitlements file with the given keys and values.
void updateRunnerEntitlements({
  required String entitlementsFilePath,
  required String module,
  List<String>? deeplinkLinks,
}) {
  File entitlementsFile = File(entitlementsFilePath);
  if (!entitlementsFile.existsSync()) {
    throw Exception(
        'Error: Runner.entitlements file does not exist at $entitlementsFilePath');
  }

  String entitlementsContent = entitlementsFile.readAsStringSync();

  if (module == 'deeplink') {
    String deeplinkEntries = deeplinkLinks!
        .map((link) => '        <string>applinks:$link</string>')
        .join('\n');

    if (entitlementsContent
        .contains('<key>com.apple.developer.associated-domains</key>')) {
      entitlementsContent = entitlementsContent.replaceFirst(
          RegExp(
              '<key>com.apple.developer.associated-domains</key>\\s*<array>.*?</array>',
              dotAll: true),
          '''
<key>com.apple.developer.associated-domains</key>
    <array>
$deeplinkEntries
    </array>''');

      entitlementsFile.writeAsStringSync(entitlementsContent);
    } else {
      print(
          'No <key>com.apple.developer.associated-domains</key> block found in Runner.entitlements.');
    }
  } else if (module == 'notifications') {
    if (entitlementsContent.contains('<string>development</string>')) {
      // replace the existing value with 'production'
      entitlementsContent = entitlementsContent.replaceFirst(
          '<string>development</string>', '<string>production</string>');
      entitlementsFile.writeAsStringSync(entitlementsContent);
    } else {
      print(
          'No <key>aps-environment</key> block found in Runner.entitlements.');
    }
  }
}
