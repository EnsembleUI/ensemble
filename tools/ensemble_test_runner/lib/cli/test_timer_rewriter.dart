import 'dart:io';

import 'package:ensemble_test_runner/cli/test_entry_validator.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Reads and applies bounded timer settings for temporary test runs.
final class TestTimerRewriter {
  const TestTimerRewriter._();

  static TimerRewriteConfig readConfig(String? testsDirPath) {
    if (testsDirPath == null) return const TimerRewriteConfig();
    final file = File(p.join(testsDirPath, 'config.yaml'));
    if (!file.existsSync()) return const TimerRewriteConfig();
    final dynamic config = loadYaml(file.readAsStringSync());
    if (config is! YamlMap) return const TimerRewriteConfig();
    final timers = config['timers'];
    if (timers is! YamlMap) return const TimerRewriteConfig();
    return TimerRewriteConfig(
      enabled: timers['enabled'] == true,
      maxStartAfterSeconds: _parseNonNegativeInt(
        timers['maxStartAfterSeconds'],
        fallback: 1,
      ),
      maxRepeatIntervalSeconds: _parseNonNegativeInt(
        timers['maxRepeatIntervalSeconds'],
        fallback: 1,
      ),
      maxNumberOfTimes: timers['maxNumberOfTimes'] == null
          ? null
          : _parseNonNegativeInt(timers['maxNumberOfTimes'], fallback: 0),
      maxNumberOfTimesByScreen: _parseScreenTimerCaps(
        timers['maxNumberOfTimesByScreen'],
      ),
    );
  }

  static void rewriteScreens({
    required String appDir,
    required String testsDirRelative,
    required TimerRewriteConfig config,
  }) {
    if (!config.enabled) return;
    final screensDir = Directory(
      p.join(
        p.normalize(p.absolute(appDir)),
        p.dirname(_withoutTrailingSlash(testsDirRelative)),
        'screens',
      ),
    );
    if (!screensDir.existsSync()) return;
    for (final entity in screensDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.yaml')) continue;
      final original = entity.readAsStringSync();
      final screenCap = config
          .maxNumberOfTimesByScreen[p.basenameWithoutExtension(entity.path)];
      final rewritten = capTimerValues(
        original,
        config,
        maxNumberOfTimes: screenCap ?? config.maxNumberOfTimes,
      );
      if (rewritten != original) entity.writeAsStringSync(rewritten);
    }
  }

  static String capTimerValues(
    String content,
    TimerRewriteConfig config, {
    int? maxNumberOfTimes,
  }) {
    final startAfter =
        RegExp(r'^(\s*startAfter:\s*)(\d+)(\s*)$', multiLine: true);
    final repeatInterval = RegExp(
      r'^(\s*repeatInterval:\s*)(\d+)(\s*)$',
      multiLine: true,
    );
    final maxNumberOfTimesPattern = RegExp(
      r'^(\s*maxNumberOfTimes:\s*)(\d+)(\s*)$',
      multiLine: true,
    );
    var rewritten = content
        .replaceAllMapped(
          startAfter,
          (match) => _capTimerLine(match, config.maxStartAfterSeconds),
        )
        .replaceAllMapped(
          repeatInterval,
          (match) => _capTimerLine(match, config.maxRepeatIntervalSeconds),
        );
    final maxTimes = maxNumberOfTimes ?? config.maxNumberOfTimes;
    if (maxTimes != null) {
      rewritten = rewritten.replaceAllMapped(
        maxNumberOfTimesPattern,
        (match) => _capTimerLine(match, maxTimes),
      );
    }
    return rewritten;
  }

  static Map<String, int> _parseScreenTimerCaps(dynamic value) {
    if (value is! YamlMap) return const {};
    final caps = <String, int>{};
    value.forEach((key, rawCap) {
      final cap = _parseNonNegativeInt(rawCap, fallback: -1);
      if (cap >= 0) caps[key.toString()] = cap;
    });
    return Map.unmodifiable(caps);
  }

  static String _capTimerLine(Match match, int maxValue) {
    final current = int.parse(match.group(2)!);
    if (current <= maxValue) return match.group(0)!;
    return '${match.group(1)}$maxValue${match.group(3)}';
  }

  static int _parseNonNegativeInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    final parsed = value is int ? value : int.tryParse(value.toString());
    return parsed == null || parsed < 0 ? fallback : parsed;
  }

  static String _withoutTrailingSlash(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }
}

/// Immutable timer-rewrite settings for one CLI test run.
///
/// This keeps test-run scheduling policy out of [TestAppPatcher] and lets
/// worker preparation apply the same settings to isolated app copies.
final class TestTimerRewritePlan {
  TestTimerRewritePlan({
    required this.testsDirRelative,
    required this.config,
  });

  factory TestTimerRewritePlan.forApp({
    required String appDir,
    required String? testsDirRelative,
  }) {
    if (testsDirRelative != null) {
      TestEntryValidator.validatePathWithinRoot(
        root: appDir,
        relativePath: testsDirRelative,
      );
    }
    final testsDirPath =
        testsDirRelative == null ? null : p.join(appDir, testsDirRelative);
    return TestTimerRewritePlan(
      testsDirRelative: testsDirRelative,
      config: TestTimerRewriter.readConfig(testsDirPath),
    );
  }

  final String? testsDirRelative;
  final TimerRewriteConfig config;

  bool get enabled => config.enabled;

  void applyTo(String appDir) {
    final testsDir = testsDirRelative;
    if (testsDir == null) return;
    TestTimerRewriter.rewriteScreens(
      appDir: appDir,
      testsDirRelative: testsDir,
      config: config,
    );
  }
}
