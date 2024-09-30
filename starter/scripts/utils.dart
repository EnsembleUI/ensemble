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
    throw Exception('Error: $filePath not found.');
  }
  return file.readAsStringSync();
}

// process platforms argument
List<String> getPlatforms(List<String> arguments,
    {List<String> defaultPlatforms = const ['ios', 'android', 'web']}) {
  List<String> platforms = defaultPlatforms;

  if (arguments.contains('--platform')) {
    String platformArg = arguments[arguments.indexOf('--platform') + 1];
    platforms =
        platformArg.split(',').map((platform) => platform.trim()).toList();
  }

  return platforms;
}

// To update content using regex
String updateContent(String content, String regexPattern, String replacement) {
  return content.replaceAllMapped(
    RegExp(regexPattern),
    (match) => replacement,
  );
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
  }
}

// Add permission descriptions to Info.plist
void addPermissionDescriptionToInfoPlist(
  String plistPath,
  String key,
  dynamic description, {
  bool isArray = false,
  bool isBoolean = false,
}) {
  File plistFile = File(plistPath);
  if (!plistFile.existsSync()) {
    print('Error: File does not exist at $plistPath');
    return;
  }

  String plistContent = plistFile.readAsStringSync();

  if (plistContent.contains('<key>$key</key>')) {
    if (!isArray && !isBoolean) {
      RegExp regex = RegExp('<key>$key</key>\\s*<string>[^<]*</string>');
      String replacement = '<key>$key</key>\n    <string>$description</string>';
      plistContent = plistContent.replaceAll(regex, replacement);
    } else if (isBoolean) {
      RegExp regex = RegExp('<key>$key</key>\\s*<(true|false)/>');
      String replacement =
          '<key>$key</key>\n    <${description ? 'true' : 'false'}/>';
      plistContent = plistContent.replaceAll(regex, replacement);
    } else if (isArray) {
      RegExp regex =
          RegExp('<key>$key</key>\\s*<array>(.*?)</array>', dotAll: true);
      String arrayValues = (description as List)
          .map((item) => '        <string>$item</string>')
          .join('\n');
      String replacement =
          '<key>$key</key>\n    <array>\n$arrayValues\n    </array>';
      plistContent = plistContent.replaceAll(regex, replacement);
    }
  } else {
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

      plistContent = plistContent.replaceRange(
        dictEndIndex,
        dictEndIndex,
        toInsert,
      );
    } else {
      return;
    }
  }

  plistFile.writeAsStringSync(plistContent);
}

// convert a string to a regex pattern for matching commented-out code
String toRegexPattern(String statement, {bool isBoolean = false}) {
  if (isBoolean) {
    final prefix = statement.split('=')[0].trim();
    return RegExp.escape(prefix) + r'\s*=\s*(true|false);';
  } else {
    String escapedStatement = RegExp.escape(statement);
    return r'\/\/\s*' + escapedStatement.replaceAll(' ', r'\s+');
  }
}

// Update ensemble_modules.dart file
void updateEnsembleModules(
    String filePath,
    List<Map<String, String>> importStatements,
    List<Map<String, String>> registerStatements,
    List<Map<String, String>> useStatements) {
  String? content = readFileContent(filePath);

  for (var statementObj in importStatements) {
    content = updateContent(
      content ?? '',
      statementObj['regex'] ?? '',
      statementObj['statement'] ?? '',
    );
  }

  for (var statementObj in useStatements) {
    content = updateContent(
      content ?? '',
      statementObj['regex'] ?? '',
      statementObj['statement'] ?? '',
    );
  }

  for (var statementObj in registerStatements) {
    content = updateContent(
      content ?? '',
      statementObj['regex'] ?? '',
      statementObj['statement'] ?? '',
    );
  }

  writeFileContent(filePath, content ?? '');
}

// Update pubspec.yaml file
void updatePubspec(
    String filePath, List<Map<String, String>> pubspecDependencies) {
  String? pubspecContent = readFileContent(filePath);

  for (var statementObj in pubspecDependencies) {
    pubspecContent = updateContent(
      pubspecContent ?? '',
      statementObj['regex'] ?? '',
      statementObj['statement'] ?? '',
    );
  }

  writeFileContent(filePath, pubspecContent ?? '');
}

// Update AndroidManifest.xml with permissions
void updateAndroidPermissions(
    String manifestFilePath, List<String> permissions) {
  for (var permission in permissions) {
    addPermissionToAndroidManifest(
      manifestFilePath,
      '<!-- UPDATE for your Starter. These are default permissions -->',
      permission,
    );
  }
}

// Update Info.plist for iOS with permissions and descriptions
void updateIOSPermissions(
  String plistFilePath,
  List<Map<String, String>> iOSPermissions,
  List<String> arguments, {
  List<Map<String, dynamic>> additionalSettings = const [],
}) {
  // Process the iOS permissions
  for (var permission in iOSPermissions) {
    String paramValue = '';
    if (arguments.contains(permission['paramKey'])) {
      paramValue = arguments[arguments.indexOf(permission['paramKey']!) + 1];
    }

    if (paramValue.isNotEmpty) {
      addPermissionDescriptionToInfoPlist(
          plistFilePath, permission['key'] ?? '', paramValue);
    }
  }

  // Process additional settings (arrays, booleans, etc.) if provided
  if (additionalSettings.isNotEmpty) {
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
}
