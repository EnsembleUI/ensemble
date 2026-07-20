import 'package:ensemble/framework/app_info.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Resolves a device/step theme value to an Ensemble Themes entry name.
///
/// Accepts aliases (`light` → `Light`, `dark` → `Dark`) and case-insensitive
/// matches against registered theme names when [registeredNames] is provided.
String? resolveEnsembleThemeName(
  String? raw, {
  List<String> registeredNames = const [],
}) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final aliased = switch (value.toLowerCase()) {
    'light' => 'Light',
    'dark' => 'Dark',
    _ => value,
  };

  if (registeredNames.isEmpty) return aliased;

  for (final name in registeredNames) {
    if (name == aliased) return name;
  }
  for (final name in registeredNames) {
    if (name.toLowerCase() == aliased.toLowerCase()) return name;
  }
  for (final name in registeredNames) {
    if (name.toLowerCase() == value.toLowerCase()) return name;
  }
  return null;
}

/// Seeds saved-theme storage so configureThemes can pick it on first paint.
Future<void> seedEnsembleTestTheme(String? raw) async {
  final name = resolveEnsembleThemeName(raw);
  if (name == null) return;

  final appId = AppInfo().appId;
  final keys = <String>{
    if (appId != null && appId.isNotEmpty) '${appId}_theme',
    '_theme',
  };
  for (final key in keys) {
    await StorageManager().write(key, name);
  }
}

/// Applies [raw] via [EnsembleThemeManager] when that theme is registered.
///
/// Returns the resolved theme name when applied, otherwise null.
String? applyEnsembleTestTheme(String? raw) {
  final manager = EnsembleThemeManager();
  final name = resolveEnsembleThemeName(
    raw,
    registeredNames: manager.getThemeNames(),
  );
  if (name == null) return null;
  manager.setTheme(name);
  return name;
}

/// Applies [testCase.deviceTarget.theme] when present.
String? applyDeviceThemeForTestCase(EnsembleTestCase testCase) {
  return applyEnsembleTestTheme(testCase.deviceTarget?.theme);
}
