import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ensemble/action/navigation_action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Handlers for the full declarative vocabulary beyond the original MVP set.
class ExtendedStepHandlers {
  static Future<bool> tryExecute(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    switch (step.type) {
      case 'reloadScreen':
        await _reloadScreen(executor);
        return true;
      case 'restartApp':
        await _restartApp(executor);
        return true;
      case 'resetAppState':
        await _resetAppState(executor);
        return true;
      case 'trigger':
        await _trigger(executor, step);
        return true;
      case 'launchApp':
        await _restartApp(executor);
        return true;
      case 'doubleTap':
        await executor.tapWidget(executor.requireId(step));
        await executor.tapWidget(executor.requireId(step));
        return true;
      case 'longPress':
        await executor.longPressWidget(executor.requireId(step));
        return true;
      case 'focus':
        await executor.focusWidget(executor.requireId(step));
        return true;
      case 'unfocus':
        await executor.unfocus();
        return true;
      case 'selectIndex':
        await _selectIndex(executor, step);
        return true;
      case 'check':
        await executor.tapWidget(executor.requireId(step));
        return true;
      case 'uncheck':
        await _uncheck(executor, step);
        return true;
      case 'setSlider':
        await _setSlider(executor, step);
        return true;
      case 'chooseDate':
      case 'chooseTime':
        await executor.enterTextOn(
          executor.requireId(step),
          step.args['value']?.toString() ?? '',
        );
        return true;
      case 'scroll':
        await _scroll(executor, step);
        return true;
      case 'swipe':
        await _swipe(executor, step);
        return true;
      case 'drag':
        await _drag(executor, step);
        return true;
      case 'pullToRefresh':
        await _pullToRefresh(executor, step);
        return true;
      case 'expectExists':
        executor.assertions.expectExists(executor.requireId(step));
        return true;
      case 'expectNotExists':
        executor.assertions.expectNotExists(executor.requireId(step));
        return true;
      case 'expectTextContains':
        final text = step.args['text']?.toString();
        if (text == null) {
          throw EnsembleTestFailure('expectTextContains requires "text"');
        }
        executor.assertions.expectTextContains(text);
        return true;
      case 'expectChecked':
        executor.assertions.expectChecked(
          executor.requireId(step),
          step.args['equals'] as bool? ?? true,
        );
        return true;
      case 'expectSelected':
        executor.assertions.expectChecked(
          executor.requireId(step),
          step.args['equals'] as bool? ?? true,
        );
        return true;
      case 'expectProperty':
        executor.assertions.expectProperty(
          executor.requireId(step),
          step.args['property']?.toString() ?? 'label',
          step.args['equals'],
        );
        return true;
      case 'expectStyle':
        executor.assertions.expectProperty(
          executor.requireId(step),
          'style',
          step.args['equals'],
        );
        return true;
      case 'expectListCount':
        executor.assertions.expectListCount(
          listId: step.args['id']?.toString() ?? executor.requireId(step),
          expected: step.args['equals'] as int? ??
              (throw EnsembleTestFailure('expectListCount requires "equals"')),
          itemId: step.args['itemId']?.toString(),
        );
        return true;
      case 'expectListContains':
        executor.assertions.expectListContains(
          listId: step.args['id']?.toString() ?? '',
          text: step.args['text']?.toString() ?? '',
        );
        return true;
      case 'expectListItem':
        executor.assertions
            .expectVisible(step.args['itemId']?.toString() ?? '');
        return true;
      case 'expectEmpty':
        executor.assertions.expectListCount(
          listId: executor.requireId(step),
          expected: 0,
        );
        return true;
      case 'expectNotEmpty':
        executor.assertions.expectListCount(
          listId: executor.requireId(step),
          expected: 1,
          atLeast: true,
        );
        return true;
      case 'expectNotVisited':
        final screen = step.args['screen']?.toString();
        if (screen == null) {
          throw EnsembleTestFailure('expectNotVisited requires "screen"');
        }
        executor.assertions.expectNotVisited(screen);
        return true;
      case 'expectBackStack':
        executor.assertions.expectBackStack(
          (step.args['screens'] as List?)?.map((e) => e.toString()).toList() ??
              [],
        );
        return true;
      case 'expectCanGoBack':
        executor.assertions.expectCanGoBack(
          step.args['equals'] as bool? ?? true,
        );
        return true;
      case 'goBack':
        await _goBack(executor);
        return true;
      case 'mockApiFromFixture':
        await _mockApiFromFixture(executor, step);
        return true;
      case 'clearApiMocks':
        executor.context.apiOverlay.clearMocks();
        return true;
      case 'mockApiException':
        await _mockApiException(executor, step);
        return true;
      case 'mockTimeout':
        await _mockTimeout(executor, step);
        return true;
      case 'expectApiCallOrder':
        executor.assertions.expectApiCallOrder(
          (step.args['names'] as List?)?.map((e) => e.toString()).toList() ??
              [],
        );
        return true;
      case 'expectLastApiCall':
        executor.assertions
            .expectLastApiCall(step.args['name']?.toString() ?? '');
        return true;
      case 'removeStorage':
        final key = step.args['key']?.toString();
        if (key == null)
          throw EnsembleTestFailure('removeStorage requires "key"');
        executor.context.removeStorage(key);
        return true;
      case 'clearStorage':
        await executor.context.clearStorage();
        return true;
      case 'setAuth':
        _setAuth(executor, step);
        return true;
      case 'clearAuth':
        _clearAuth(executor);
        return true;
      case 'setPermission':
        _setPermission(executor, step);
        return true;
      case 'setDevice':
        await _setDevice(executor, step);
        return true;
      case 'setLocale':
        await _setLocale(executor, step);
        return true;
      case 'setTheme':
        _setTheme(executor, step);
        return true;
      case 'runScript':
        _runScript(executor, step, expectResult: false);
        return true;
      case 'expectScript':
      case 'expectScriptResult':
        _runScript(executor, step, expectResult: true);
        return true;
      case 'expectConsoleLog':
        executor.assertions
            .expectConsoleLog(step.args['contains']?.toString() ?? '');
        return true;
      case 'logStorage':
        final key = step.args['key']?.toString();
        if (key == null || key.isEmpty) {
          final storage = StorageManager();
          final entries = storage.getKeys().map(
                (key) => MapEntry(key, storage.read(key)),
              );
          final content =
              _prettyJson(Map<String, dynamic>.fromEntries(entries));
          final path = await executor.tester.runAsync(() {
            return executor.context.logger.writeLogFile(
              testId: executor.context.testCase.id,
              name: 'storage',
              content: content,
              extension: 'json',
            );
          });
          executor.context.logger.log(
            'storage: $path',
          );
        } else {
          final content = _prettyJson(StorageManager().read(key));
          final path = await executor.tester.runAsync(() {
            return executor.context.logger.writeLogFile(
              testId: executor.context.testCase.id,
              name: 'storage_$key',
              content: content,
              extension: 'json',
            );
          });
          executor.context.logger.log(
            'storage[$key]: $path',
          );
        }
        return true;
      case 'logPerformance':
        final path = await executor.tester.runAsync(() {
          return writeAppPerformanceLog(executor.context);
        });
        executor.context.logger.log('appPerformance: $path');
        return true;
      case 'expectAccessible':
        executor.assertions.expectAccessible(executor.requireId(step));
        return true;
      case 'expectSemanticsLabel':
        executor.assertions.expectSemanticsLabel(
          executor.requireId(step),
          step.args['label']?.toString() ?? '',
        );
        return true;
      case 'expectNoOverflow':
        executor.assertions.expectNoOverflow(executor.requireId(step));
        return true;
      case 'expectError':
        executor.assertions.expectErrorRecorded(
          step.args['contains']?.toString(),
        );
        return true;
      case 'expectNoErrors':
        executor.assertions.expectNoRenderErrors();
        return true;
      case 'screenshot':
        await _screenshot(executor, step);
        return true;
      case 'dumpTree':
        final path = await executor.tester.runAsync(() {
          return executor.context.logger.writeLogFile(
            testId: executor.context.testCase.id,
            name: 'dump_tree',
            content: _captureDebugDumpApp(),
            extension: 'txt',
          );
        });
        executor.context.logger.log('dumpTree: $path');
        return true;
      case 'expectNoConsoleErrors':
        executor.assertions.expectNoConsoleErrors();
        return true;
      case 'expectNoRenderErrors':
        executor.assertions.expectNoRenderErrors();
        return true;
      default:
        return false;
    }
  }

  static Future<void> _reloadScreen(TestStepExecutor e) async {
    final tracker = ScreenTracker();
    final current =
        tracker.getCurrentScreenIdentifier() ?? e.context.testCase.startScreen;
    if (current == null || current.isEmpty) {
      throw EnsembleTestFailure('No current screen to reload');
    }
    await e.openScreenByName(current);
  }

  static Future<void> _restartApp(TestStepExecutor e) async {
    EnsembleTestHarness.resetTestRuntime();
    e.context.runtime.clear();
    e.context.apiOverlay.resetCalls();
    final screen = e.context.testCase.startScreen ??
        ScreenTracker().getCurrentScreenIdentifier();
    if (screen == null || screen.isEmpty) {
      throw EnsembleTestFailure(
        'restartApp requires startScreen or a tracked current screen',
      );
    }
    await e.openScreenByName(screen);
  }

  static Future<void> _resetAppState(TestStepExecutor e) async {
    ScreenTracker().clearAll();
    e.context.apiOverlay.resetCalls();
    e.context.runtime.clear();
    await StorageManager().clearPublicStorage();
  }

  static Future<void> _trigger(TestStepExecutor e, TestStep step) async {
    final action = step.args['action']?.toString() ?? 'onTap';
    switch (action) {
      case 'onLoad':
        await _reloadScreen(e);
      case 'onTap':
      case 'onLongPress':
        final id = step.args['id']?.toString();
        if (id == null || id.isEmpty) {
          throw EnsembleTestFailure('trigger onTap requires "id"');
        }
        if (action == 'onLongPress') {
          await e.longPressWidget(id);
        } else {
          await e.tapWidget(id);
        }
      default:
        throw EnsembleTestFailure('Unsupported trigger action: $action');
    }
  }

  static Future<void> _selectIndex(TestStepExecutor e, TestStep step) async {
    final id = e.requireId(step);
    final index = step.args['index'] as int? ?? 0;
    await e.tapWidget(id);
    final options = find.byType(ListTile);
    if (options.evaluate().length <= index) {
      throw EnsembleTestFailure('selectIndex: no option at index $index');
    }
    await e.tester.tap(options.at(index));
    await e.settle();
  }

  static Future<void> _uncheck(TestStepExecutor e, TestStep step) async {
    final id = e.requireId(step);
    try {
      e.assertions.expectChecked(id, true);
      await e.tapWidget(id);
    } on EnsembleTestFailure {
      // already unchecked
    }
  }

  static Future<void> _setSlider(TestStepExecutor e, TestStep step) async {
    final id = e.requireId(step);
    final value = (step.args['value'] as num?)?.toDouble() ?? 0.5;
    final finder = e.assertions.finderForId(id);
    final sliderFinder =
        find.descendant(of: finder, matching: find.byType(Slider));
    if (sliderFinder.evaluate().isEmpty) {
      throw EnsembleTestFailure('setSlider: no Slider under id "$id"');
    }
    final slider = e.tester.widget<Slider>(sliderFinder);
    final target =
        slider.min + (slider.max - slider.min) * value.clamp(0.0, 1.0);
    await e.tester.drag(sliderFinder, Offset(target * 50, 0));
    await e.settle();
  }

  static Future<void> _scroll(TestStepExecutor e, TestStep step) async {
    final delta = step.args['delta'] as int? ?? -300;
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) {
      throw EnsembleTestFailure('scroll: no Scrollable found');
    }
    await e.tester.drag(scrollable.first, Offset(0, delta.toDouble()));
    await e.settle();
  }

  static Future<void> _swipe(TestStepExecutor e, TestStep step) async {
    final direction = step.args['direction']?.toString() ?? 'left';
    Offset offset;
    switch (direction) {
      case 'right':
        offset = const Offset(300, 0);
      case 'up':
        offset = const Offset(0, 300);
      case 'down':
        offset = const Offset(0, -300);
      default:
        offset = const Offset(-300, 0);
    }
    final target = step.args['id'] != null
        ? e.assertions.finderForId(step.args['id'].toString())
        : find.byType(Scrollable).first;
    await e.tester.drag(target, offset);
    await e.settle();
  }

  static Future<void> _drag(TestStepExecutor e, TestStep step) async {
    final id = e.requireId(step);
    final dx = (step.args['dx'] as num?)?.toDouble() ?? 0;
    final dy = (step.args['dy'] as num?)?.toDouble() ?? -100;
    await e.tester.drag(e.assertions.finderForId(id), Offset(dx, dy));
    await e.settle();
  }

  static Future<void> _pullToRefresh(TestStepExecutor e, TestStep step) async {
    final scrollable = step.args['id'] != null
        ? e.assertions.finderForId(step.args['id'].toString())
        : find.byType(Scrollable).first;
    await e.tester.drag(scrollable, const Offset(0, 300));
    await e.settle();
  }

  static Future<void> _goBack(TestStepExecutor e) async {
    final scope = e.assertions.activeScope();
    if (scope != null) {
      ScreenController().executeAction(
        // ignore: deprecated_member_use
        scope.dataContext.buildContext,
        NavigateBackAction.from(payload: null),
      );
      await e.settle();
      return;
    }
    final navigator = find.byType(Navigator);
    if (navigator.evaluate().isNotEmpty) {
      final state = e.tester.state<NavigatorState>(navigator.first);
      state.pop();
      await e.settle();
      return;
    }
    throw EnsembleTestFailure('goBack: no navigator or active scope');
  }

  static Future<void> _mockApiFromFixture(
      TestStepExecutor e, TestStep step) async {
    final name = step.args['name']?.toString();
    final fixture = step.args['fixture']?.toString();
    if (name == null || fixture == null) {
      throw EnsembleTestFailure(
          'mockApiFromFixture requires "name" and "fixture"');
    }
    final body = await _readFixture(e, fixture);
    e.context.apiOverlay.setMock(
      name,
      MockAPIResponse(
        statusCode: step.args['statusCode'] as int? ?? 200,
        body: body,
      ),
    );
  }

  static Future<void> _mockApiException(
      TestStepExecutor e, TestStep step) async {
    final name = step.args['name']?.toString();
    if (name == null)
      throw EnsembleTestFailure('mockApiException requires "name"');
    e.context.apiOverlay.setApiException(
      name,
      Exception(step.args['message']?.toString() ?? 'API exception (test)'),
    );
  }

  static Future<void> _mockTimeout(TestStepExecutor e, TestStep step) async {
    final name = step.args['name']?.toString();
    if (name == null) throw EnsembleTestFailure('mockTimeout requires "name"');
    e.context.apiOverlay.setMock(
      name,
      MockAPIResponse(
        statusCode: 200,
        body: {},
        delayMs: step.args['delayMs'] as int? ?? 60000,
      ),
    );
  }

  static void _setAuth(TestStepExecutor e, TestStep step) {
    final user = step.args['user'];
    if (user is Map) {
      e.context.runtime.authUser = Map<String, dynamic>.from(user);
      StorageManager().writeToSystemStorage(
        'ensemble.auth.user',
        e.context.runtime.authUser,
      );
    }
  }

  static void _clearAuth(TestStepExecutor e) {
    e.context.runtime.authUser = null;
    StorageManager().removeFromSystemStorage('ensemble.auth.user');
  }

  static void _setPermission(TestStepExecutor e, TestStep step) {
    final name = step.args['name']?.toString();
    final value = step.args['value']?.toString() ?? 'granted';
    if (name != null) {
      e.context.runtime.permissions[name] = value;
    }
  }

  static Future<void> _setDevice(TestStepExecutor e, TestStep step) async {
    final width = (step.args['width'] as num?)?.toDouble() ?? 390;
    final height = (step.args['height'] as num?)?.toDouble() ?? 844;
    final size = Size(width, height);
    await e.tester.binding.setSurfaceSize(size);
    e.tester.view.physicalSize = size;
    e.tester.view.devicePixelRatio = 1.0;
    e.tester.view.padding = FakeViewPadding.zero;
    e.tester.view.viewPadding = FakeViewPadding.zero;
    e.context.runtime.deviceSize = size;
    await e.settle();
  }

  static Future<void> _setLocale(TestStepExecutor e, TestStep step) async {
    final locale = step.args['locale']?.toString() ?? 'en';
    e.context.setEnv('APP_LOCALE', locale);
    e.context.runtime.locale = Locale(locale.split('_').first);
  }

  static void _setTheme(TestStepExecutor e, TestStep step) {
    final theme =
        step.args['mode']?.toString() ?? step.args['theme']?.toString();
    if (theme != null) {
      e.context.setEnv('APP_THEME', theme);
      e.context.runtime.themeMode = theme;
    }
  }

  static void _runScript(
    TestStepExecutor e,
    TestStep step, {
    required bool expectResult,
  }) {
    final scope = e.assertions.activeScope();
    if (scope == null) {
      throw EnsembleTestFailure('runScript requires an active Ensemble screen');
    }
    final script =
        step.args['script']?.toString() ?? step.args['path']?.toString();
    if (script == null) {
      throw EnsembleTestFailure('runScript requires "script" or "path"');
    }
    final result = scope.dataContext.eval(script);
    if (expectResult) {
      final expected = step.args['equals'];
      if (!_deepEquals(result, expected)) {
        throw EnsembleTestFailure(
          'Expected script result "$expected", got "$result".',
        );
      }
    }
  }

  static Future<dynamic> _readFixture(TestStepExecutor e, String path) async {
    Object? lastError;
    for (final candidate in _fixtureAssetCandidates(e, path)) {
      try {
        final raw = await rootBundle.loadString(candidate);
        return json.decode(raw);
      } catch (error) {
        lastError = error;
      }
    }
    throw EnsembleTestFailure(
      'Fixture not found: $path. Use tests/fixtures/<name>.json. $lastError',
    );
  }

  static List<String> _fixtureAssetCandidates(TestStepExecutor e, String path) {
    final sourcePath = e.context.testCase.sourcePath;
    final candidates = <String>[];
    if (sourcePath != null && sourcePath.contains('/')) {
      final testDir = sourcePath.substring(0, sourcePath.lastIndexOf('/'));
      candidates.add(
        path.startsWith('fixtures/')
            ? '$testDir/$path'
            : '$testDir/fixtures/$path',
      );
    }
    candidates.add(path);
    if (!path.startsWith('ensemble/')) candidates.add('ensemble/$path');
    return candidates.toSet().toList();
  }

  static Future<void> _screenshot(TestStepExecutor e, TestStep step) async {
    final args =
        e.context.testCase.options.screenshots.toScreenshotArgs(step.args);
    await captureScreenshot(e, args: args);
  }

  static Future<void> captureScreenshot(
    TestStepExecutor e, {
    required Map<String, dynamic> args,
    bool deferWrite = false,
    bool pumpBeforeCapture = true,
  }) async {
    if (pumpBeforeCapture) {
      await e.tester.pump();
    }
    final rawName = args['name']?.toString();
    final name = rawName == null || rawName.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : rawName;
    final fileName = _safeFileName('${e.context.testCase.id}_$name.png');
    final directory = Directory('build/ensemble_test_runner/screenshots');
    final file = File('${directory.path}/$fileName');
    final device = resolveScreenshotDevice(args);

    if (pumpBeforeCapture) {
      await e.tester.pump();
    }

    final renderView = e.tester.binding.renderViews.first;
    final layer = renderView.debugLayer;
    if (layer is! OffsetLayer) {
      throw EnsembleTestFailure(
        'screenshot requires a painted render view.',
      );
    }

    final image = layer.toImageSync(
      renderView.paintBounds,
      pixelRatio: renderView.flutterView.devicePixelRatio,
    );
    final path = file.path;

    Future<void> writeImage() async {
      final byteData = await _addDeviceFrame(image, device);
      image.dispose();
      if (byteData == null) {
        throw EnsembleTestFailure('Failed to encode screenshot as PNG.');
      }

      directory.createSync(recursive: true);
      file.writeAsBytesSync(byteData.buffer.asUint8List());
    }

    if (deferWrite) {
      e.context.runtime.pendingScreenshotWrites.add(writeImage);
    } else {
      await e.tester.runAsync(writeImage);
    }

    e.context.logger.log('screenshot: $path');
  }

  static Future<ByteData?> _addDeviceFrame(
    ui.Image screenImage,
    DeviceInfo device,
  ) async {
    final padding = device.frameSize.shortestSide * 0.025;
    final outputWidth = (device.frameSize.width + padding * 2).ceil();
    final outputHeight = (device.frameSize.height + padding * 2).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
    );

    canvas.drawColor(const Color(0xFFE9EDF3), BlendMode.src);
    canvas.save();
    canvas.translate(padding, padding);
    device.framePainter.paint(canvas, device.frameSize);

    final screenPath = device.screenPath;
    final screenRect = screenPath.getBounds();
    canvas.save();
    canvas.clipPath(screenPath);
    canvas.drawImageRect(
      screenImage,
      Rect.fromLTWH(
        0,
        0,
        screenImage.width.toDouble(),
        screenImage.height.toDouble(),
      ),
      screenRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(outputWidth, outputHeight);
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData;
  }

  static String _captureDebugDumpApp() {
    final previousDebugPrint = debugPrint;
    final lines = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        lines.add(message);
      }
    };
    try {
      debugDumpApp();
    } finally {
      debugPrint = previousDebugPrint;
    }
    if (lines.isEmpty) {
      return '<empty widget tree>';
    }
    return lines.join('\n');
  }

  static String _prettyJson(Object? value) {
    return JsonEncoder.withIndent('  ', (value) => value.toString())
        .convert(value);
  }

  static String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  static bool _deepEquals(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_deepEquals(a[k], b[k])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return false;
  }
}
