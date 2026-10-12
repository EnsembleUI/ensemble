import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads semantics values while managing the temporary semantics handle.
///
/// Flutter changed the typed semantics flag API between supported versions.
/// This boundary keeps that compatibility code out of the assertion facade.
final class AssertionSemantics {
  final WidgetTester tester;

  const AssertionSemantics(this.tester);

  T read<T>(T Function() callback) {
    final handle = tester.ensureSemantics();
    try {
      return callback();
    } finally {
      handle.dispose();
    }
  }

  bool isEnabled(SemanticsData data) => _flag(
        data,
        typed: (flags) => flags.isEnabled,
        legacy: SemanticsFlag.isEnabled,
      );

  bool isChecked(SemanticsData data) => _flag(
        data,
        typed: (flags) => flags.isChecked,
        legacy: SemanticsFlag.isChecked,
      );

  bool _flag(
    SemanticsData data, {
    required Object? Function(dynamic flags) typed,
    required SemanticsFlag legacy,
  }) {
    final compatibleData = data as dynamic;
    try {
      return _flagValue(typed(compatibleData.flagsCollection)) == true;
    } on NoSuchMethodError {
      return compatibleData.hasFlag(legacy) == true;
    }
  }

  bool? _flagValue(Object? value) {
    if (value is bool) return value;
    return switch (value?.toString().split('.').last) {
      'isTrue' || 'checked' => true,
      'isFalse' || 'unchecked' => false,
      _ => null,
    };
  }
}
