import 'dart:io';

// To read file content
String readFileContent(String filePath) {
  File file = File(filePath);
  if (!file.existsSync()) {
    throw Exception('Error: $filePath not found.');
  }
  return file.readAsStringSync();
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
