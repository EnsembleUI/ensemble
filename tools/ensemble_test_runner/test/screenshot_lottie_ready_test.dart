import 'dart:convert';
import 'dart:typed_data';

import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble_test_runner/runner/screenshot_lottie_ready.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  test('compositionReady resets when source changes', () {
    final controller = LottieController();
    expect(controller.compositionReady, isFalse);

    controller.compositionReady = true;
    controller.updateSource('https://example.com/a.json');
    expect(controller.source, 'https://example.com/a.json');
    expect(controller.compositionReady, isFalse);

    controller.compositionReady = true;
    controller.updateSource('https://example.com/a.json');
    expect(controller.compositionReady, isTrue);
  });

  testWidgets('areVisibleLottiesReady is true when no Lotties are present',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(areVisibleLottiesReady(tester), isTrue);
  });

  testWidgets(
    'areVisibleLottiesReady is false until compositionReady',
    (tester) async {
      final lottie = EnsembleLottie();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: lottie),
        ),
      );

      expect(areVisibleLottiesReady(tester), isTrue);

      lottie.controller.updateSource('https://example.com/placement.json');
      expect(areVisibleLottiesReady(tester), isFalse);

      lottie.controller.compositionReady = true;
      expect(areVisibleLottiesReady(tester), isTrue);
    },
  );

  testWidgets(
    'seekVisibleLottiesForScreenshot moves controller to mid progress',
    (tester) async {
      final lottie = EnsembleLottie();
      lottie.controller.updateSource('asset://placement.json');
      lottie.controller.compositionReady = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(height: 0, child: lottie)),
        ),
      );

      // LottieState owns the AnimationController after mount.
      final animation = lottie.controller.lottieController!;
      animation.duration = const Duration(seconds: 10);
      expect(animation.value, 0.0);

      seekVisibleLottiesForScreenshot(tester, progress: 0.45);
      expect(animation.value, closeTo(0.45, 1e-9));
    },
  );

  testWidgets(
    'waitForVisibleLottiesReady seeks after composition is ready',
    (tester) async {
      final lottie = EnsembleLottie();
      lottie.controller.updateSource('https://example.com/placement.json');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(height: 0, child: lottie)),
        ),
      );

      final animation = lottie.controller.lottieController!;
      animation.duration = const Duration(seconds: 10);

      Future<void>.delayed(const Duration(milliseconds: 25), () {
        lottie.controller.compositionReady = true;
      });

      await waitForVisibleLottiesReady(
        tester,
        timeout: const Duration(seconds: 1),
        pollInterval: const Duration(milliseconds: 10),
        progress: 0.4,
      );

      expect(areVisibleLottiesReady(tester), isTrue);
      expect(animation.value, closeTo(0.4, 1e-9));
    },
  );

  testWidgets(
    'initializeLottieController marks compositionReady',
    (tester) async {
      final animation = AnimationController(vsync: const TestVSync());
      addTearDown(animation.dispose);

      final controller = LottieController();
      controller.lottieController = animation;

      final composition = await LottieComposition.fromBytes(
        Uint8List.fromList(utf8.encode(_minimalLottieJson)),
      );
      controller.initializeLottieController(composition);

      expect(controller.compositionReady, isTrue);
      expect(animation.duration, composition.duration);
      animation.stop();
    },
  );
}

const _minimalLottieJson =
    '{"v":"5.5.7","fr":60,"ip":0,"op":60,"w":100,"h":100,"layers":[]}';
