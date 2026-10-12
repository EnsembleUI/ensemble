// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:path/path.dart' as p;

/// Handles platform project checks and source rewrites used by the CLI.
///
/// Keeping these platform-specific transformations outside [TestAppPatcher]
/// leaves the test entry lifecycle focused on its file transaction.
class AppPlatformSupport {
  AppPlatformSupport({required this.appDir, required this.rewriteIfChanged});

  final String appDir;
  final void Function(File file, String Function(String content) rewrite)
      rewriteIfChanged;

  /// Firebase 12 / current Ensemble plugins require iOS 15+.
  static const minIntegrationIosDeploymentTarget = '15.0';
  static const androidDesugarJdkLibsCoordinate =
      'com.android.tools:desugar_jdk_libs:2.1.4';

  /// Raises iOS deployment files to [minIntegrationIosDeploymentTarget].
  void applyIosDeploymentTargetFix() {
    final podfile = File(p.join(appDir, 'ios', 'Podfile'));
    if (podfile.existsSync()) {
      rewriteIfChanged(podfile, raisePodfilePlatform);
    }
    final pbxproj = File(
      p.join(appDir, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    );
    if (pbxproj.existsSync()) {
      rewriteIfChanged(pbxproj, raisePbxprojDeploymentTarget);
    }
    final frameworkPlist = File(
      p.join(appDir, 'ios', 'Flutter', 'AppFrameworkInfo.plist'),
    );
    if (frameworkPlist.existsSync()) {
      rewriteIfChanged(frameworkPlist, raisePlistMinimumOsVersion);
    }
  }

  /// Enables Android core library desugaring required by Ensemble plugins.
  void applyAndroidDesugaringFix() {
    final kts = File(p.join(appDir, 'android', 'app', 'build.gradle.kts'));
    if (kts.existsSync()) {
      rewriteIfChanged(kts, enableGradleKtsCoreLibraryDesugaring);
      return;
    }
    final groovy = File(p.join(appDir, 'android', 'app', 'build.gradle'));
    if (groovy.existsSync()) {
      rewriteIfChanged(groovy, enableGradleGroovyCoreLibraryDesugaring);
    }
  }

  /// Applies platform requirements for the selected test execution.
  ///
  /// Platform-specific setup policy belongs here so the app patcher can keep
  /// coordinating the file transaction without interpreting platform rules.
  void prepareForTestRun({
    required ExecutionMode mode,
    required String? targetPlatform,
    required bool fixIosDeploymentTarget,
  }) {
    if (mode != ExecutionMode.integration || targetPlatform != 'ios') return;
    if (fixIosDeploymentTarget) {
      applyIosDeploymentTargetFix();
      return;
    }
    final message = iosDeploymentTargetRequirementMessage(appDir);
    if (message != null) throw StateError(message);
  }

  /// Returns an error when Android desugaring is missing, or null when OK.
  static String? androidDesugaringRequirementMessage(String appDir) {
    final kts = File(p.join(appDir, 'android', 'app', 'build.gradle.kts'));
    final groovy = File(p.join(appDir, 'android', 'app', 'build.gradle'));
    if (!kts.existsSync() && !groovy.existsSync()) return null;
    final content =
        kts.existsSync() ? kts.readAsStringSync() : groovy.readAsStringSync();
    final enabled = content.contains('isCoreLibraryDesugaringEnabled') ||
        RegExp(r'coreLibraryDesugaringEnabled\s+true').hasMatch(content);
    final hasDep = content.contains('desugar_jdk_libs');
    if (enabled && hasDep) return null;
    return 'Android core library desugaring is required by Ensemble plugins '
        '(flutter_local_notifications). Enable it in android/app/build.gradle(.kts) '
        'or run `dart run ensemble_test_runner:ensemble_test --doctor --fix`.';
  }

  static String enableGradleKtsCoreLibraryDesugaring(String content) {
    var updated = content;
    if (!updated.contains('isCoreLibraryDesugaringEnabled') &&
        updated.contains('compileOptions {')) {
      updated = updated.replaceFirst(
        'compileOptions {',
        'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',
      );
    }
    if (!updated.contains('desugar_jdk_libs')) {
      final dep =
          '    coreLibraryDesugaring("$androidDesugarJdkLibsCoordinate")\n';
      if (updated.contains('dependencies {')) {
        updated =
            updated.replaceFirst('dependencies {', 'dependencies {\n$dep');
      } else {
        updated = '$updated\ndependencies {\n$dep}\n';
      }
    }
    return updated;
  }

  static String enableGradleGroovyCoreLibraryDesugaring(String content) {
    var updated = content;
    if (!RegExp(r'coreLibraryDesugaringEnabled\s+true').hasMatch(updated) &&
        updated.contains('compileOptions {')) {
      updated = updated.replaceFirst(
        'compileOptions {',
        'compileOptions {\n        coreLibraryDesugaringEnabled true',
      );
    }
    if (!updated.contains('desugar_jdk_libs')) {
      final dep =
          "    coreLibraryDesugaring '$androidDesugarJdkLibsCoordinate'\n";
      if (updated.contains('dependencies {')) {
        updated =
            updated.replaceFirst('dependencies {', 'dependencies {\n$dep');
      } else {
        updated = '$updated\ndependencies {\n$dep}\n';
      }
    }
    return updated;
  }

  /// Returns an actionable error when iOS deployment is below the minimum.
  static String? iosDeploymentTargetRequirementMessage(String appDir) {
    final min = minIntegrationIosDeploymentTarget;
    final iosDir = Directory(p.join(appDir, 'ios'));
    if (!iosDir.existsSync()) return null;

    final podfile = File(p.join(appDir, 'ios', 'Podfile'));
    if (!podfile.existsSync()) {
      return 'ios/Podfile is missing; CocoaPods will default to iOS 13.0. '
          'Firebase plugins require $min. Set `platform :ios, \'$min\'` in '
          'ios/Podfile, or run `dart run ensemble_test_runner:ensemble_test '
          '--doctor --fix`.';
    }
    final content = podfile.readAsStringSync();
    final match = RegExp(
      r'''^#?\s*platform\s*:ios\s*,\s*['"]([0-9.]+)['"]''',
      multiLine: true,
    ).firstMatch(content);
    final version = match?.group(1);
    final commented =
        match != null && match.group(0)!.trimLeft().startsWith('#');
    if (version == null || commented || iosVersionLessThan(version, min)) {
      final current =
          version == null || commented ? 'unset (defaults to 13.0)' : version;
      return 'iOS deployment target is $current; Firebase plugins require $min. '
          'Set `platform :ios, \'$min\'` in ios/Podfile (and matching '
          'IPHONEOS_DEPLOYMENT_TARGET), or run '
          '`dart run ensemble_test_runner:ensemble_test --doctor --fix`.';
    }
    return null;
  }

  static String raisePodfilePlatform(
    String content, {
    String min = minIntegrationIosDeploymentTarget,
  }) {
    final platformLine = RegExp(
      r'''^#?\s*platform\s*:ios\s*,\s*['"]([0-9.]+)['"][ \t]*$''',
      multiLine: true,
    );
    final match = platformLine.firstMatch(content);
    if (match == null) return "platform :ios, '$min'\n\n$content";
    final current = match.group(1)!;
    final target = iosVersionLessThan(current, min) ? min : current;
    final replacement = "platform :ios, '$target'";
    if (match.group(0) == replacement) return content;
    return content.replaceFirst(match.group(0)!, replacement);
  }

  static String raisePbxprojDeploymentTarget(
    String content, {
    String min = minIntegrationIosDeploymentTarget,
  }) {
    return content.replaceAllMapped(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);'),
      (match) {
        final current = match.group(1)!;
        if (!iosVersionLessThan(current, min)) return match.group(0)!;
        return 'IPHONEOS_DEPLOYMENT_TARGET = $min;';
      },
    );
  }

  static String raisePlistMinimumOsVersion(
    String content, {
    String min = minIntegrationIosDeploymentTarget,
  }) {
    return content.replaceAllMapped(
      RegExp(r'(<key>MinimumOSVersion</key>\s*<string>)([0-9.]+)(</string>)'),
      (match) {
        final current = match.group(2)!;
        if (!iosVersionLessThan(current, min)) return match.group(0)!;
        return '${match.group(1)}$min${match.group(3)}';
      },
    );
  }

  static bool iosVersionLessThan(String current, String minimum) {
    List<int> parts(String value) =>
        value.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final left = parts(current);
    final right = parts(minimum);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final a = i < left.length ? left[i] : 0;
      final b = i < right.length ? right[i] : 0;
      if (a != b) return a < b;
    }
    return false;
  }
}
