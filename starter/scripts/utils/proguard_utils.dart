import 'dart:io';

import '../utils.dart';

void createProguardRules(String rules) {
  try {
    final file = File(proguardRulesFilePath);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    final content = file.readAsStringSync();

    if (!content.contains(rules) && rules.isNotEmpty) {
      file.writeAsStringSync('$content\n$rules');
      updateBuildGradleProguardFiles();
    }
  } catch (e) {
    throw Exception(
        '❌ Starter Error: Failed to create proguard-rules.pro file: $e');
  }
}

void updateBuildGradleProguardFiles() {
  try {
    final file = File(androidAppBuildGradleFilePath);
    if (!file.existsSync()) {
      throw Exception('build.gradle file not found.');
    }

    String content = file.readAsStringSync();

    // Update the proguardFiles in the build.gradle file
    if (!content.contains('proguardFiles')) {
      content = content.replaceAllMapped(
          RegExp(r'buildTypes\s*{[^}]*release\s*{', multiLine: true),
          (match) =>
              "buildTypes {\n        release {\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'");
    }

    file.writeAsStringSync(content);
  } catch (e) {
    throw Exception('❌ Starter Error: Failed to update build.gradle: $e');
  }
}
