import 'dart:io';

import 'utils.dart';
import 'utils/firebase_utils.dart';

// Adds the Firebase Performance SDK to the project
void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  try {
    addDependency('firebase_performance', '^0.10.0+11');

    if (platforms.contains('android')) {
      addClasspathDependency(
          "classpath 'com.google.firebase:perf-plugin:1.4.2'");
      addPluginDependency("apply plugin: 'com.google.firebase.firebase-perf'");
    }

    // Configure iOS-specific settings
    if (platforms.contains('ios')) {
      addPod('FirebasePerformance');
    }

    print(
        'Firebase Performance SDK enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}

void addPod(String pod) {
  final podfile = File('ios/Podfile');
  if (!podfile.existsSync()) {
    throw 'ios/Podfile not found';
  }

  final lines = podfile.readAsLinesSync();
  final newLines = <String>[];
  bool added = false;

  for (var line in lines) {
    newLines.add(line);
    if (line.contains('use_frameworks!')) {
      newLines.add("  pod '$pod'");
      added = true;
    }
  }

  if (!added) {
    throw 'use_frameworks! not found in ios/Podfile';
  }

  podfile.writeAsStringSync(newLines.join('\n'));
}

void addDependency(String dependency, String version) {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw 'pubspec.yaml not found';
  }

  // find dependencies section with regex, don't do it with lines
  final content = pubspec.readAsStringSync();
  final dependencies =
      RegExp(r'dependencies:', multiLine: true).firstMatch(content);

  if (dependencies == null) {
    throw 'dependencies section not found in pubspec.yaml';
  }

  final newContent = content.replaceFirst(dependencies.group(0)!,
      '${dependencies.group(0)}\n  $dependency: $version\n');

  pubspec.writeAsStringSync(newContent);
}
