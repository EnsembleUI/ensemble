import 'dart:io';

const String ensembleModulesFilePath = 'lib/generated/ensemble_modules.dart';
const String pubspecFilePath = 'pubspec.yaml';
const String androidManifestFilePath =
    'android/app/src/main/AndroidManifest.xml';
const String iosInfoPlistFilePath = 'ios/Runner/Info.plist';

// To read file content
String readFileContent(String filePath) {
  File file = File(filePath);
  if (!file.existsSync()) {
    throw Exception('$filePath not found.');
  }
  return file.readAsStringSync();
}

// Helper function to parse individual arguments in key=value format
String? getArgumentValue(List<String> arguments, String key) {
  for (var arg in arguments) {
    final parts = arg.split('=');
    if (parts.length == 2 && parts[0] == key) {
      return parts[1];
    }
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
  if (!regex.hasMatch(content)) {
    throw Exception('Pattern not found: $regexPattern');
  }
  return content.replaceAllMapped(regex, (match) => replacement);
}

// To write updated content to file
void writeFileContent(String filePath, String content) {
  File file = File(filePath);
  file.writeAsStringSync(content);
}

// Add permission to AndroidManifest.xml
void addPermissionToAndroidManifest(
    String manifestPath, String comment, String permission) {
  String manifestContent = readFileContent(manifestPath);

  if (!manifestContent.contains(permission)) {
    manifestContent = manifestContent.replaceFirst(
      comment,
      '$comment\n    $permission',
    );
    writeFileContent(manifestPath, manifestContent);
  } else {
    throw Exception('Permission already exists in AndroidManifest.xml');
  }
}

// Add permission descriptions to Info.plist
void addPermissionDescriptionToInfoPlist(
    String plistPath, String key, dynamic description,
    {bool isArray = false, bool isBoolean = false}) {
  File plistFile = File(plistPath);
  if (!plistFile.existsSync()) {
    throw Exception('Error: File does not exist at $plistPath');
  }

  String plistContent = plistFile.readAsStringSync();
  bool updated = false;

  if (plistContent.contains('<key>$key</key>')) {
    if (!isArray && !isBoolean) {
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
    String filePath, List<String> codeStatements, List<String> useStatements) {
  String content = readFileContent(filePath);

  // Process code statements (imports and register statements)
  for (var statement in codeStatements) {
    String regexPattern = toRegexPattern(statement);
    content = updateContent(content, regexPattern, statement);
  }

  // Process use statements (e.g., static const useCamera = true)
  for (var statement in useStatements) {
    String regexPattern = toRegexPattern(statement, isBoolean: true);
    content = updateContent(content, regexPattern, statement);
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
void updateAndroidPermissions(
    String manifestFilePath, List<String> permissions) {
  for (var permission in permissions) {
    addPermissionToAndroidManifest(
        manifestFilePath,
        '<!-- UPDATE for your Starter. These are default permissions -->',
        permission);
  }
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
