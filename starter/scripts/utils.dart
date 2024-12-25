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
const String androidBuildGradleFilePath = 'android/build.gradle';
const String androidAppBuildGradleFilePath = 'android/app/build.gradle';
const String androidSettingsGradleFilePath = 'android/settings.gradle';
const String proguardRulesFilePath = 'android/app/proguard-rules.pro';

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
void addPermissionDescriptionToInfoPlist(String key, dynamic description,
    {bool isArray = false, bool isBoolean = false, bool isDict = false}) {
  File plistFile = File(iosInfoPlistFilePath);
  if (!plistFile.existsSync()) {
    throw Exception('Error: File does not exist at $iosInfoPlistFilePath');
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
void updateEnsembleModules(
    List<String>? codeStatements, List<String>? useStatements) {
  String content = readFileContent(ensembleModulesFilePath);

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

  writeFileContent(ensembleModulesFilePath, content);
}

// Update pubspec.yaml file and throw error if content is not updated
void updatePubspec(List<Map<String, String>> pubspecDependencies) {
  String pubspecContent = readFileContent(pubspecFilePath);

  for (var statementObj in pubspecDependencies) {
    pubspecContent = updateContent(pubspecContent, statementObj['regex'] ?? '',
        statementObj['statement'] ?? '');
  }

  writeFileContent(pubspecFilePath, pubspecContent);
}

// Update AndroidManifest.xml with permissions and throw error if not updated
void updateAndroidPermissions(
    {List<String>? permissions, List<String>? metaData}) {
  String manifestContent = readFileContent(androidManifestFilePath);

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

  writeFileContent(androidManifestFilePath, manifestContent);
}

void updateMainActivity(Map<String, List<Map<String, String>>> updates) {
  const baseDir = 'android/app/src/main';

  String? activityFilePath = findMainActivity(baseDir);
  if (activityFilePath == null) {
    throw Exception('MainActivity not found in $baseDir');
  }

  String content = readFileContent(activityFilePath);
  bool isKotlin = activityFilePath.endsWith('.kt');

  try {
    final patterns = isKotlin ? updates['kotlin']! : updates['java']!;
    bool requiresUpdate = false;
    String updatedContent = content;

    // Check if any of the desired states already exist
    for (final update in patterns) {
      final desiredContent = update['replacement'] ?? '';
      if (!content.contains(desiredContent)) {
        requiresUpdate = true;
        break;
      }
    }

    // Apply updates if needed
    if (requiresUpdate) {
      for (final update in patterns) {
        try {
          final newContent = updateContent(updatedContent,
              update['pattern'] ?? '', update['replacement'] ?? '');
          if (newContent != updatedContent) {
            updatedContent = newContent;
          }
        } catch (_) {
          // Continue with next pattern if one fails
          continue;
        }
      }

      // Write changes if content was modified
      if (updatedContent != content) {
        writeFileContent(activityFilePath, updatedContent);
      }
    }
  } catch (e) {
    throw Exception('Failed to update MainActivity: $e');
  }
}

/// Finds the MainActivity file in the project
String? findMainActivity(String baseDir) {
  final commonPaths = ['kotlin', 'java'];

  for (final path in commonPaths) {
    final dir = Directory('$baseDir/$path');
    if (!dir.existsSync()) continue;

    try {
      final files = dir.listSync(recursive: true);
      final activityFile = files.firstWhere(
        (file) =>
            file.path.endsWith('MainActivity.kt') ||
            file.path.endsWith('MainActivity.java'),
        orElse: () => File(''),
      );

      if (activityFile.path.isNotEmpty) {
        return activityFile.path;
      }
    } catch (_) {
      continue;
    }
  }

  return null;
}

// Update Info.plist for iOS with permissions and descriptions
void updateIOSPermissions(
    List<Map<String, String>> iOSPermissions, List<String> arguments,
    {List<Map<String, dynamic>> additionalSettings = const []}) {
  for (var permission in iOSPermissions) {
    String? paramValue = getArgumentValue(arguments, permission['key']!);

    if (paramValue != null && paramValue.isNotEmpty) {
      addPermissionDescriptionToInfoPlist(
          permission['value'] ?? '', paramValue);
    }
  }

  // Process additional settings (arrays, booleans, etc.) if provided
  for (var setting in additionalSettings) {
    if (setting['isArray'] == true) {
      addPermissionDescriptionToInfoPlist(setting['key'], setting['value'],
          isArray: true);
    } else if (setting['isBoolean'] == true) {
      addPermissionDescriptionToInfoPlist(setting['key'], setting['value'],
          isBoolean: true);
    } else {
      addPermissionDescriptionToInfoPlist(setting['key'], setting['value']);
    }
  }
}

// To update an HTML file with a new content before a specific marker (like </head>)
void updateHtmlFile(String marker, String contentToAdd,
    {String? removalPattern}) {
  if (!File(webIndexFilePath).existsSync()) {
    throw Exception('Error: $webIndexFilePath not found');
  }

  String content = File(webIndexFilePath).readAsStringSync();

  // Remove existing tag
  if (removalPattern != null) {
    content = removeExistingTag(content, removalPattern);
  }

  if (!content.contains(contentToAdd)) {
    content = content.replaceFirst(marker, '  $contentToAdd\n$marker');
    File(webIndexFilePath).writeAsStringSync(content);
  }
}

String removeExistingTag(String content, String pattern) {
  final regex = RegExp(pattern);
  final lines = content.split('\n');
  final filteredLines = lines.where((line) => !regex.hasMatch(line)).toList();
  return filteredLines.join('\n');
}

void updatePropertiesFile(String key, String value) {
  File propertiesFile = File(ensemblePropertiesFilePath);
  if (!propertiesFile.existsSync()) {
    throw Exception('Error: $ensemblePropertiesFilePath not found.');
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

void updateAppDelegateForGoogleMaps(String googleMapsApiKey) {
  File appDelegateFile = File(appDelegatePath);
  if (!appDelegateFile.existsSync()) {
    throw Exception('Error: $appDelegatePath not found.');
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
  String module = 'deeplink',
  List<String>? deeplinkLinks,
}) {
  File entitlementsFile = File(runnerEntitlementsPath);
  if (!entitlementsFile.existsSync()) {
    throw Exception(
        'Error: Runner.entitlements file does not exist at $runnerEntitlementsPath');
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
  } else if (module == 'networkInfo') {
    if (!entitlementsContent.contains(
        '<key>com.apple.security.personal-information.location</key>')) {
      entitlementsContent = entitlementsContent.replaceFirst('</dict>', '''
    <key>com.apple.security.personal-information.location</key>
    <true/>
    <key>com.apple.developer.networking.wifi-info</key>
    <true/>
</dict>''');
      entitlementsFile.writeAsStringSync(entitlementsContent);
    }
  }
}

/// Retrieves the ensemble version.
///
/// If [version] is provided and different from the current ensemble version,
/// it updates the `pubspec.yaml` with the new version.
/// Otherwise, it returns the existing version or defaults to 'main'.
///
/// Returns the effective ensemble version as a [String].
Future<String> packageVersion({String? version}) async {
  try {
    final current = await getEnsembleVersion();
    if (version != null &&
        version.trim().isNotEmpty &&
        version.trim() != current) {
      return await updateEnsembleVersion(version.trim())
          ? version.trim()
          : current;
    }
    return current;
  } catch (e) {
    print('Error: $e');
    return 'main';
  }
}

/// Reads the pubspec.yaml file and returns the 'ref' of the 'ensemble' package.
/// Returns 'main' if the 'ref' is not found or the 'ensemble' package is not a git dependency.
Future<String> getEnsembleVersion() async {
  final file = File(pubspecFilePath);
  if (!await file.exists()) return 'main';

  try {
    final lines = await file.readAsLines();
    final refInfo = _findEnsembleGitRef(lines);
    return refInfo['ref']?.isNotEmpty == true ? refInfo['ref'] : 'main';
  } catch (e) {
    print('Error reading ensemble version: $e');
    return 'main';
  }
}

/// Updates the 'ref' value of the 'ensemble' package in pubspec.yaml.
///
/// [newVersion] - The new version to set for the 'ensemble' package.
///
/// Returns `true` if the update was successful, `false` otherwise.
Future<bool> updateEnsembleVersion(String newVersion) async {
  final file = File(pubspecFilePath);

  try {
    final lines = await file.readAsLines();
    final refInfo = _findEnsembleGitRef(lines);

    if (refInfo['index'] != null) {
      final indentation = refInfo['indentation'] ?? '';
      lines[refInfo['index']] = '${indentation}ref: $newVersion';
      await file.writeAsString(lines.join('\n'));
      return true;
    } else {
      print("'ref:' not found under 'ensemble' git dependency.");
      return false;
    }
  } catch (e) {
    print('Error updating ensemble version: $e');
    return false;
  }
}

/// Helper function to locate the 'ref' line within the 'ensemble' git dependency.
///
/// Returns a [Map] containing:
/// - 'ref': The current ref value (if found).
/// - 'index': The line index of the 'ref:' key (if found).
/// - 'indentation': The indentation before the 'ref:' key (if found).
Map<String, dynamic> _findEnsembleGitRef(List<String> lines) {
  bool inEnsemble = false;
  bool inGit = false;

  for (int i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trim();
    if (trimmed.startsWith('ensemble:')) {
      inEnsemble = true;
      inGit = false;
      continue;
    }
    if (inEnsemble) {
      if (trimmed.startsWith('git:')) {
        inGit = true;
        continue;
      }
      if (inGit && trimmed.startsWith('ref:')) {
        final ref = trimmed.split(':').last.trim();
        final indentation = lines[i].substring(0, lines[i].indexOf('ref:'));
        return {'ref': ref, 'index': i, 'indentation': indentation};
      }
      // If another dependency starts, exit the ensemble block
      if (trimmed.endsWith(':') &&
          !trimmed.startsWith('git:') &&
          !trimmed.startsWith('ref:')) {
        break;
      }
    }
  }
  return {};
}
