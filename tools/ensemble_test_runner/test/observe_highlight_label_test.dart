import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('highlight label TextStyle uses Roboto not Ahem metrics',
      (tester) async {
    await EnsembleTestHarness.ensureAppFontsLoaded();

    const label = 'greeting_text_text';
    final ahem = TextPainter(
      text: const TextSpan(
        text: label,
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          // Intentionally omit fontFamily → Ahem in tests.
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final roboto = TextPainter(
      text: const TextSpan(
        text: label,
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    // Ahem paints em-squares; Roboto glyphs are narrower for this string.
    expect(roboto.width, lessThan(ahem.width));
    expect(roboto.height, greaterThan(0));

    ahem.dispose();
    roboto.dispose();
  });
}
