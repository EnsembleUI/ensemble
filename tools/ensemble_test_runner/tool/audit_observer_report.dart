import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Audits observer snapshots in a generated test-runner report.
///
/// Run with `dart run tool/audit_observer_report.dart [--format=json] [report-path]` from the
/// ensemble_test_runner package. The path may be a report directory,
/// `index.html`, `results.json.gz`, or an uncompressed results JSON file.
Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('Usage: dart run tool/audit_observer_report.dart '
        '[--format=text|json] [--no-ocr] [report-path]');
    stdout.writeln(
        'Path may be a report directory, index.html, results.json.gz, or results.json.');
    stdout.writeln('If omitted, the tool prompts for the report path.');
    return;
  }
  final formats = args.where((arg) => arg.startsWith('--format=')).toList();
  final format = formats.isEmpty ? null : formats.first;
  if (formats.length > 1) {
    stderr.writeln('Specify --format only once.');
    exitCode = 2;
    return;
  }
  if (format != null &&
      format != '--format=json' &&
      format != '--format=text') {
    stderr.writeln('Unsupported output format. Use text or json.');
    exitCode = 2;
    return;
  }
  final positional = args.where((arg) => !arg.startsWith('--')).toList();
  if (args.any((arg) =>
      arg.startsWith('--') &&
      arg != '--format=json' &&
      arg != '--format=text' &&
      arg != '--no-ocr')) {
    stderr.writeln('Unknown option. Use --help for usage.');
    exitCode = 2;
    return;
  }
  if (positional.length > 1) {
    stderr.writeln('Provide one report path.');
    exitCode = 2;
    return;
  }
  final input = positional.isNotEmpty ? positional.first : _promptForPath();
  if (input == null || input.trim().isEmpty) {
    stderr.writeln('No report path provided.');
    exitCode = 2;
    return;
  }

  try {
    final reportFile = _resolveReportFile(input.trim());
    final document = _readDocument(reportFile);
    final audit = _ObserverReportAudit(
      reportFile,
      document,
      enableOcr: !args.contains('--no-ocr'),
    );
    await audit.run();
    if (format == '--format=json') {
      audit.printJson();
    } else {
      audit.printSummary();
    }
    if (audit.errors > 0) exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('Could not audit report: $error');
    exitCode = 2;
  }
}

String? _promptForPath() {
  stdout.write('Report path (directory, index.html, or results.json.gz): ');
  return stdin.readLineSync();
}

File _resolveReportFile(String input) {
  final path = p.normalize(p.absolute(input));
  final entity = FileSystemEntity.typeSync(path);
  if (entity == FileSystemEntityType.directory) {
    return File(p.join(path, 'results.json.gz'));
  }
  if (p.basename(path) == 'index.html') {
    return File(p.join(p.dirname(path), 'results.json.gz'));
  }
  return File(path);
}

Map<String, dynamic> _readDocument(File file) {
  if (!file.existsSync()) {
    throw FileSystemException('Report data file not found', file.path);
  }
  final bytes = file.readAsBytesSync();
  final content = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b
      ? gzip.decode(bytes)
      : bytes;
  final decoded = jsonDecode(utf8.decode(content));
  if (decoded is! Map)
    throw const FormatException('Report root is not JSON object');
  return Map<String, dynamic>.from(decoded);
}

class _ObserverReportAudit {
  _ObserverReportAudit(this.reportFile, this.document,
      {required this.enableOcr});

  final File reportFile;
  final Map<String, dynamic> document;
  final bool enableOcr;
  final List<_Finding> findings = [];
  final List<String> _notes = [];
  int tests = 0;
  int steps = 0;
  int observedSteps = 0;
  int elements = 0;
  int screenshots = 0;
  final Map<String, _RepeatedGeometry> _repeatedGeometry = {};
  final List<_ObservationRecord> _observationRecords = [];
  final Map<String, Set<String>> _screenNamesByScreenshot = {};
  final List<_VisualSnapshot> _visualSnapshots = [];
  final Set<String> _imagePaths = {};

  int get errors => findings.where((f) => f.severity == 'ERROR').length;
  int get warnings => findings.where((f) => f.severity == 'WARN').length;
  int get reviews => findings.where((f) => f.severity == 'REVIEW').length;

  Future<void> run() async {
    final testList = document['tests'];
    if (testList is! List) {
      _add('ERROR', 'Report has no tests list.');
      return;
    }
    tests = testList.length;
    if (document['state'] == 'loading') {
      _add('WARN',
          'Report is still marked as loading; audit may be incomplete.');
    }

    for (var ti = 0; ti < testList.length; ti++) {
      final test = _map(testList[ti]);
      if (test == null) {
        _add('ERROR', 'tests[$ti] is not an object.');
        continue;
      }
      final testLabel = '${test['id'] ?? 'test[$ti]'}';
      final testReport = _map(test['report']);
      final visitedScreens = testReport?['screensVisited'] is List
          ? (testReport!['screensVisited'] as List).whereType<String>().toSet()
          : <String>{};
      final stepList = test['steps'];
      if (stepList is! List) continue;
      for (var si = 0; si < stepList.length; si++) {
        steps++;
        final step = _map(stepList[si]);
        if (step == null) continue;
        final stepLabel = '$testLabel / step ${si + 1}';
        final shots = step['screenshots'];
        final screenshotInfos = <_ScreenshotInfo>[];
        final screenshotReferences = <String>{};
        if (shots is List) {
          for (final shotValue in shots) {
            final shot = _map(shotValue);
            if (shot == null) continue;
            final reference = shot['href'] ?? shot['file'];
            if (reference is String && reference.isNotEmpty) {
              screenshotReferences.add(reference);
            }
            screenshots++;
            final screenshotInfo = _auditScreenshot(shot, stepLabel);
            if (screenshotInfo != null) screenshotInfos.add(screenshotInfo);
          }
        }

        final observer = _map(step['observer']);
        final observation = _map(observer?['observationJson']);
        if (observation == null) continue;
        observedSteps++;
        _recordScreenshotScreens(testLabel, observation['screen'], shots);
        _auditObservation(
          observation,
          observer ?? const {},
          stepLabel,
          testLabel,
          visitedScreens,
          screenshotInfos,
          screenshotReferences,
        );
      }
    }
    if (enableOcr) await _auditScreenshotText();
    _auditCrossScreenContent();
    _auditScreenshotScreenMismatches();
    _auditRepeatedGeometry();
  }

  void _auditObservation(
    Map<String, dynamic> observation,
    Map<String, dynamic> observer,
    String where,
    String testLabel,
    Set<String> visitedScreens,
    List<_ScreenshotInfo> screenshotInfos,
    Set<String> screenshotReferences,
  ) {
    final viewport = _map(observation['viewport']);
    final viewportWidth = _number(viewport?['width']);
    final viewportHeight = _number(viewport?['height']);
    if (viewport == null ||
        viewportWidth == null ||
        viewportHeight == null ||
        viewportWidth <= 0 ||
        viewportHeight <= 0) {
      _add('ERROR', '$where: observer viewport is missing or invalid.');
    }
    final coordinateSpace = _map(observation['coordinateSpace']);
    if (coordinateSpace != null &&
        coordinateSpace['unit'] != null &&
        coordinateSpace['unit'] != 'logicalPixels') {
      _add('WARN',
          '$where: coordinate unit is ${coordinateSpace['unit']}, expected logicalPixels.');
    }

    final roots = observation['elements'];
    if (roots is! List) {
      _add('ERROR', '$where: observer elements is missing or not a list.');
      return;
    }
    final indices = <int>{};
    final locators = <String, List<Map<String, dynamic>>>{};
    final elementByIndex = <int, Map<String, dynamic>>{};
    final geometryGroups = <String, List<Map<String, dynamic>>>{};
    final offscreenLabels = <String, Set<String>>{};
    final titledStates = <String, List<Map<String, dynamic>>>{};

    var elementPosition = 0;
    void visit(List<dynamic> nodes) {
      for (final rawElement in nodes) {
        final ei = elementPosition++;
        final element = _map(rawElement);
        if (element == null) {
          _add('ERROR', '$where: elements[$ei] is not an object.');
          continue;
        }
        elements++;
        final index = _integer(element['index']);
        if (index == null) {
          _add('ERROR', '$where: element[$ei] has no valid index.');
        } else {
          if (!indices.add(index))
            _add('ERROR', '$where: duplicate element index $index.');
          elementByIndex[index] = element;
        }
        final type = element['type'];
        if (type is! String || type.trim().isEmpty) {
          _add('ERROR', '$where: element ${index ?? ei} has no type.');
        }

        final bounds = _map(element['bounds']);
        if (bounds == null) {
          _add('ERROR', '$where: element ${index ?? ei} has no bounds.');
        } else {
          final left = _number(bounds['left']);
          final top = _number(bounds['top']);
          final width = _number(bounds['width']);
          final height = _number(bounds['height']);
          if ([left, top, width, height].any((n) => n == null) ||
              width! <= 0 ||
              height! <= 0) {
            _add('ERROR', '$where: element ${index ?? ei} has invalid bounds.');
          } else if (viewportWidth != null && viewportHeight != null) {
            final intersects = left! < viewportWidth &&
                top! < viewportHeight &&
                left + width > 0 &&
                top + height > 0;
            if (element['visible'] == true && element['offscreen'] == true) {
              _add('ERROR',
                  '$where: element ${index ?? ei} is both visible and offscreen.');
            }
            if (element['offscreen'] == true && intersects) {
              _add('WARN',
                  '$where: element ${index ?? ei} is marked offscreen but bounds overlap viewport.');
            }
            if (element['visible'] == true && !intersects) {
              _add('WARN',
                  '$where: element ${index ?? ei} is marked visible but bounds do not overlap viewport.');
            }
          }
          if (width != null && height != null && width > 0 && height > 0) {
            final typeName = '${element['type'] ?? ''}'.toLowerCase();
            final hasIdentity = element['title'] != null ||
                element['id'] != null ||
                element['locator'] != null ||
                (element['actionExamples'] is List &&
                    (element['actionExamples'] as List).isNotEmpty);
            if (element['visible'] == true &&
                element['offscreen'] != true &&
                !hasIdentity &&
                const {'button', 'text', 'icon', 'switch', 'checkbox'}
                    .contains(typeName)) {
              final geometryKey = [
                typeName,
                for (final key in const ['left', 'top', 'width', 'height'])
                  _number(bounds[key])!.toStringAsFixed(1),
              ].join('|');
              geometryGroups
                  .putIfAbsent(geometryKey, () => <Map<String, dynamic>>[])
                  .add(element);
            }
          }
        }

        final visible = element['visible'];
        final offscreen = element['offscreen'];
        if (visible == true && offscreen == true) {
          // Already reported with bounds; retain check for malformed/no bounds.
          if (bounds == null)
            _add('ERROR',
                '$where: element ${index ?? ei} has contradictory visibility state.');
        }
        if (element['enabled'] == false && element['interactable'] == true) {
          _add('ERROR',
              '$where: disabled element ${index ?? ei} is marked interactable.');
        }
        if (element['interactable'] == true && offscreen == true) {
          _add('ERROR',
              '$where: offscreen element ${index ?? ei} is marked interactable.');
        }

        final locator = _map(element['locator']);
        if (locator != null && locator.isNotEmpty) {
          final key = jsonEncode(_canonical(locator));
          locators.putIfAbsent(key, () => []).add(element);
        }
        final examples = element['actionExamples'];
        if (offscreen == true && examples is List) {
          final names = examples.whereType<String>().map(_actionName).toSet();
          final hasDirectAction = names.any(const {
            'tap',
            'longPress',
            'doubleTap',
            'enterText',
            'replaceText'
          }.contains);
          if (hasDirectAction && !names.contains('scrollUntilVisible')) {
            _add('WARN',
                '$where: offscreen element ${index ?? ei} has direct actions but no scrollUntilVisible example.');
          }
        }
        final warning = element['warning'] ?? element['locatorWarning'];
        if (warning is String && warning.isNotEmpty) {
          if (locator == null && (examples is! List || examples.isEmpty)) {
            _add('WARN',
                '$where: ambiguous element ${index ?? ei} has neither a locator nor action examples.');
          }
          if (examples is List) {
            final unscopedTextActions = examples
                .whereType<String>()
                .where((example) {
                  final action = _actionName(example);
                  final isTextAction = const {
                    'waitForText',
                    'expectText',
                    'expectNoText',
                    'expectTextContains',
                  }.contains(action);
                  return isTextAction &&
                      !example.contains('bounds:') &&
                      !example.contains('occurrence:');
                })
                .map(_actionName)
                .toSet();
            if (unscopedTextActions.isNotEmpty) {
              _add('WARN',
                  '$where: ambiguous element ${index ?? ei} has unscoped text examples (${unscopedTextActions.join(', ')}).');
            }
          }
        }
        final children = element['children'];
        final title = element['title'];
        if (title is String && title.trim().isNotEmpty) {
          final titleKey = '${element['type'] ?? ''}|${_normalizeText(title)}';
          titledStates.putIfAbsent(titleKey, () => []).add(element);
        }
        if (offscreen == true && visible == false && title is String) {
          final normalized = _normalizeText(title);
          if (_isUsefulText(normalized)) {
            offscreenLabels
                .putIfAbsent('${element['type'] ?? ''}', () => <String>{})
                .add(normalized);
          }
        }
        if (children is List) visit(children);
      }
    }

    visit(roots);

    for (final titled in titledStates.entries) {
      final visibleMatches = titled.value.where((e) => e['visible'] == true);
      final offscreenMatches = titled.value
          .where((e) => e['visible'] == false && e['offscreen'] == true);
      if (visibleMatches.isNotEmpty && offscreenMatches.isNotEmpty) {
        final title = titled.key.split('|').skip(1).join('|');
        _add('REVIEW',
            '$where: "$title" is reported both visible and offscreen in separate nodes; check for duplicate or stale content.');
      }
    }

    final screen = observation['screen']?.toString();
    for (final group
        in geometryGroups.entries.where((entry) => entry.value.length > 1)) {
      final parts = group.key.split('|');
      if (parts.first == 'button') {
        _add(
          'WARN',
          '$where: ${group.value.length} visible anonymous button nodes share the exact bounds ${parts.skip(1).join(', ')}; these overlapping controls have no usable target identity and may be injected or duplicated UI.',
        );
      }
      final signature = '${screen ?? '(unknown)'}|${group.key}';
      final repeated = _repeatedGeometry.putIfAbsent(
        signature,
        () => _RepeatedGeometry(
          screen: screen ?? '(unknown)',
          type: parts.first,
          bounds: parts.skip(1).toList(),
        ),
      );
      repeated.occurrences++;
      if (repeated.examples.length < 3) {
        repeated.examples.add(
          '$where: elements ${group.value.map((element) => element['index']).join(', ')}',
        );
      }
    }
    if (screen != null && offscreenLabels.isNotEmpty) {
      _observationRecords.add(_ObservationRecord(
        testLabel: testLabel,
        where: where,
        screen: screen,
        visitedScreens: visitedScreens,
        labels: offscreenLabels,
        screenshotReferences: screenshotReferences,
      ));
    }
    if (screenshotInfos.isNotEmpty &&
        viewportWidth != null &&
        viewportHeight != null) {
      for (final screenshotInfo in screenshotInfos) {
        _visualSnapshots.add(_VisualSnapshot(
          where: where,
          screen: screen ?? '(unknown screen)',
          path: screenshotInfo.path,
          imageWidth: screenshotInfo.width,
          imageHeight: screenshotInfo.height,
          viewportWidth: viewportWidth.toDouble(),
          viewportHeight: viewportHeight.toDouble(),
          elements: elementByIndex.values.toList(growable: false),
        ));
      }
    }

    for (final collision
        in locators.entries.where((entry) => entry.value.length > 1)) {
      final label = collision.value
          .map((element) =>
              '#${element['index']} ${element['title'] ?? element['type']}')
          .join(', ');
      final hasWarnings = collision.value.every((element) {
        final warning = element['warning'] ?? element['locatorWarning'];
        return warning is String && warning.isNotEmpty;
      });
      _add(hasWarnings ? 'WARN' : 'ERROR',
          '$where: locator is shared by ${collision.value.length} elements ($label)${hasWarnings ? ' and warnings are present' : ' without locator warnings'}.');
    }

    _auditOverlays(
      observer['overlays'],
      elementByIndex,
      where,
      viewportWidth,
      viewportHeight,
      screenshotInfos.isEmpty ? null : screenshotInfos.first,
    );
  }

  void _auditOverlays(
    dynamic raw,
    Map<int, Map<String, dynamic>> byIndex,
    String where,
    num? viewportWidth,
    num? viewportHeight,
    _ScreenshotInfo? screenshotInfo,
  ) {
    if (raw is! List) return;
    for (final value in raw) {
      final overlay = _map(value);
      if (overlay == null) continue;
      final index = _integer(overlay['index']);
      if (index == null || !byIndex.containsKey(index)) {
        _add('WARN',
            '$where: screenshot overlay references unknown element index ${index ?? '(missing)'}.');
      }
      // Report overlays use percentages of the screenshot frame, whereas
      // observer bounds are logical pixels. Their tree indices also come from
      // the report tree, which intentionally retains extra structural nodes.
      for (final key in const ['left', 'top', 'width', 'height']) {
        final value = _number(overlay[key]);
        if (value == null || value < 0 || value > 100) {
          _add('WARN',
              '$where: screenshot overlay has invalid $key percentage.');
          break;
        }
      }
      final width = _number(overlay['width']);
      final height = _number(overlay['height']);
      if (width == 0 || height == 0) {
        _add('WARN', '$where: screenshot overlay has zero area.');
      }
      final element = byIndex[index];
      final bounds = _map(element?['bounds']);
      if (element != null &&
          bounds != null &&
          viewportWidth != null &&
          viewportHeight != null &&
          screenshotInfo != null &&
          (screenshotInfo.width / screenshotInfo.height -
                      viewportWidth / viewportHeight)
                  .abs() <
              0.01) {
        // When the screenshot has the viewport aspect ratio, overlay
        // percentages map directly back to logical observer coordinates.
        final overlayRect = [
          _number(overlay['left'])! * viewportWidth / 100,
          _number(overlay['top'])! * viewportHeight / 100,
          _number(overlay['width'])! * viewportWidth / 100,
          _number(overlay['height'])! * viewportHeight / 100,
        ];
        final left = _number(bounds['left'])!;
        final top = _number(bounds['top'])!;
        final right = left + _number(bounds['width'])!;
        final bottom = top + _number(bounds['height'])!;
        final clippedLeft = left.clamp(0, viewportWidth);
        final clippedTop = top.clamp(0, viewportHeight);
        final expected = [
          clippedLeft,
          clippedTop,
          right.clamp(0, viewportWidth) - clippedLeft,
          bottom.clamp(0, viewportHeight) - clippedTop,
        ];
        if (List.generate(4, (i) => (overlayRect[i] - expected[i]).abs())
            .any((difference) => difference > 2.0)) {
          _add('WARN',
              '$where: overlay for element $index does not align with its logical bounds.');
        }
      }
    }
  }

  _ScreenshotInfo? _auditScreenshot(Map<String, dynamic> shot, String where) {
    final href = shot['href'] ?? shot['file'];
    if (href is! String || href.isEmpty) {
      _add('WARN', '$where: screenshot has no file reference.');
      return null;
    }
    final reportDir = p.dirname(reportFile.path);
    final resolved = p.normalize(p.join(reportDir, href));
    if (!File(resolved).existsSync()) {
      _add('WARN', '$where: screenshot file is missing (${p.basename(href)}).');
      return null;
    }
    try {
      final decoded = img.decodeImage(File(resolved).readAsBytesSync());
      if (decoded == null) {
        _add('WARN', '$where: screenshot image could not be decoded.');
        return null;
      }
      _imagePaths.add(resolved);
      return _ScreenshotInfo(resolved, decoded.width, decoded.height);
    } on Object {
      _add('WARN', '$where: screenshot image could not be decoded.');
      return null;
    }
  }

  Future<void> _auditScreenshotText() async {
    if (_imagePaths.isEmpty || _visualSnapshots.isEmpty) {
      return;
    }
    if (!Platform.isMacOS) {
      _add('INFO',
          'Screenshot text audit skipped: macOS Vision is only available on macOS.');
      return;
    }
    final helper = File(p.join(
      p.dirname(Platform.script.toFilePath()),
      'observer_report_ocr.swift',
    ));
    if (!helper.existsSync()) {
      _add('INFO',
          'Screenshot text audit skipped: macOS Vision helper is missing.');
      return;
    }

    final tempDirectory =
        await Directory.systemTemp.createTemp('observer-audit-');
    try {
      final manifest = File(p.join(tempDirectory.path, 'screenshots.json'));
      manifest.writeAsStringSync(jsonEncode([
        for (final path in _imagePaths) {'path': path},
      ]));
      final result = await Process.run(
        'swift',
        [helper.path, manifest.path],
        runInShell: false,
      );
      if (result.exitCode != 0) {
        final detail = '${result.stderr}'.trim().split('\n').first;
        _add('INFO',
            'Screenshot text audit skipped: macOS Vision could not run${detail.isEmpty ? '.' : ' ($detail)'}');
        return;
      }
      final decoded = jsonDecode('${result.stdout}');
      if (decoded is! Map) {
        _add('INFO',
            'Screenshot text audit skipped: Vision returned invalid output.');
        return;
      }
      final recognized = <String, List<Map<String, dynamic>>>{
        for (final entry in decoded.entries)
          if (entry.value is List)
            entry.key.toString(): (entry.value as List)
                .whereType<Map>()
                .map((value) => Map<String, dynamic>.from(value))
                .toList(),
      };

      for (final snapshot in _visualSnapshots) {
        if ((snapshot.imageWidth / snapshot.imageHeight -
                    snapshot.viewportWidth / snapshot.viewportHeight)
                .abs() >=
            0.01) {
          continue; // Device frames need a frame-to-viewport transform.
        }
        final textBoxes = recognized[snapshot.path] ?? const [];
        final unmatchedText = <String>[];
        final misplacedText = <String>[];
        for (final textBox in textBoxes) {
          final rawText = textBox['text'];
          if (rawText is! String) continue;
          final normalized = _normalizeText(rawText);
          if (normalized.length < 5 || _number(textBox['confidence'])! < 0.70) {
            continue;
          }
          final ocrLeft = _number(textBox['x'])! * snapshot.viewportWidth;
          final ocrTop = _number(textBox['y'])! * snapshot.viewportHeight;
          final ocrWidth = _number(textBox['width'])! * snapshot.viewportWidth;
          final ocrHeight =
              _number(textBox['height'])! * snapshot.viewportHeight;
          final matching = snapshot.elements.where((element) {
            final title = element['title'];
            return element['visible'] == true &&
                title is String &&
                _textMatches(normalized, _normalizeText(title));
          }).toList();

          if (matching.isEmpty) {
            final hiddenMatch = snapshot.elements.any((element) {
              final title = element['title'];
              return element['visible'] != true &&
                  title is String &&
                  _textMatches(normalized, _normalizeText(title));
            });
            if (hiddenMatch) {
              _add('REVIEW',
                  '${snapshot.where}: screenshot OCR sees "$rawText", but the matching observer element is marked hidden or offscreen.',
                  screenshot: _reportRelativePath(snapshot.path));
            } else {
              unmatchedText.add(rawText);
            }
            continue;
          }

          final overlaps = matching.any((element) {
            final bounds = _map(element['bounds']);
            if (bounds == null) return false;
            final left = _number(bounds['left'])!;
            final top = _number(bounds['top'])!;
            final right = left + _number(bounds['width'])!;
            final bottom = top + _number(bounds['height'])!;
            final intersectionWidth =
                (right < ocrLeft + ocrWidth ? right : ocrLeft + ocrWidth) -
                    (left > ocrLeft ? left : ocrLeft);
            final intersectionHeight =
                (bottom < ocrTop + ocrHeight ? bottom : ocrTop + ocrHeight) -
                    (top > ocrTop ? top : ocrTop);
            if (intersectionWidth <= 0 || intersectionHeight <= 0) return false;
            final intersection = intersectionWidth * intersectionHeight;
            final ocrArea = ocrWidth * ocrHeight;
            return ocrArea > 0 && intersection / ocrArea >= 0.35;
          });
          if (!overlaps) {
            misplacedText.add(rawText);
          }
        }
        if (misplacedText.length >= 3) {
          _add('REVIEW',
              '${snapshot.where}: ${misplacedText.length} screenshot text regions are outside the bounds of their matching visible observer elements; likely bounds or screenshot alignment issue. Examples: ${misplacedText.take(5).join(' | ')}.',
              screenshot: _reportRelativePath(snapshot.path));
        } else {
          for (final text in misplacedText) {
            _note(
                '${snapshot.where}: OCR text "$text" is outside the matching observer bounds.');
          }
        }
        if (unmatchedText.length >= 3) {
          _add('REVIEW',
              '${snapshot.where}: screenshot contains ${unmatchedText.length} readable text regions with no matching visible observer titles; possible missing elements or screenshot/screen mismatch. Examples: ${unmatchedText.take(5).join(' | ')}.',
              screenshot: _reportRelativePath(snapshot.path));
        } else {
          for (final text in unmatchedText) {
            _note(
                '${snapshot.where}: OCR text "$text" has no matching observer title.');
          }
        }
      }
    } on Object catch (error) {
      _add('INFO', 'Screenshot text audit skipped: $error');
    } finally {
      try {
        await tempDirectory.delete(recursive: true);
      } on Object {
        // Temporary cleanup does not affect the audit result.
      }
    }
  }

  void _auditCrossScreenContent() {
    final visibleByScreen = <String, Map<String, Set<String>>>{};
    final tests = document['tests'];
    if (tests is! List) return;
    for (final testValue in tests) {
      final test = _map(testValue);
      final testSteps = test?['steps'];
      if (testSteps is! List) continue;
      for (final stepValue in testSteps) {
        final step = _map(stepValue);
        final observer = _map(step?['observer']);
        final observation = _map(observer?['observationJson']);
        final screen = observation?['screen']?.toString();
        final roots = observation?['elements'];
        if (screen == null || roots is! List) continue;
        final labels = visibleByScreen.putIfAbsent(screen, () => {});
        void visit(List<dynamic> nodes) {
          for (final value in nodes) {
            final element = _map(value);
            if (element == null) continue;
            final title = element['title'];
            if (element['visible'] == true && title is String) {
              final normalized = _normalizeText(title);
              if (_isUsefulText(normalized)) {
                labels
                    .putIfAbsent('${element['type'] ?? ''}', () => <String>{})
                    .add(normalized);
              }
            }
            final children = element['children'];
            if (children is List) visit(children);
          }
        }

        visit(roots);
      }
    }

    for (final record in _observationRecords) {
      final matchesByScreen = <String, Set<String>>{};
      for (final otherScreen
          in record.visitedScreens.where((screen) => screen != record.screen)) {
        // If this exact captured image was already reported under the
        // candidate screen, the pixels confirm that the offscreen labels can
        // belong to the current UI. Keep the screenshot/screen-name conflict
        // finding, which identifies the inconsistent metadata directly, but
        // do not report the same evidence as leaked foreign-screen content.
        final sameScreenshotWasSeenOnCandidateScreen =
            record.screenshotReferences.any((reference) =>
                _screenNamesByScreenshot['${record.testLabel}|$reference']
                    ?.contains(otherScreen) ==
                true);
        if (sameScreenshotWasSeenOnCandidateScreen) continue;
        final otherLabels = visibleByScreen[otherScreen];
        if (otherLabels == null) continue;
        for (final typedLabels in record.labels.entries) {
          final matches = typedLabels.value
              .intersection(otherLabels[typedLabels.key] ?? const <String>{});
          matchesByScreen
              .putIfAbsent(otherScreen, () => <String>{})
              .addAll(matches);
        }
      }
      final candidates = matchesByScreen.entries
          .where((entry) => entry.value.length >= 4)
          .toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      if (candidates.isNotEmpty) {
        final candidate = candidates.first;
        _add(
          'REVIEW',
          '${record.where}: ${candidate.value.length} offscreen labels also appear on visited screen "${candidate.key}" but not current screen "${record.screen}"; possible inactive-screen content. Matches: ${candidate.value.take(6).join(', ')}.',
        );
      }
    }
  }

  void _recordScreenshotScreens(
    String testLabel,
    dynamic screenValue,
    dynamic screenshotValues,
  ) {
    if (screenValue is! String || screenshotValues is! List) return;
    for (final value in screenshotValues) {
      final shot = _map(value);
      final reference = shot?['href'] ?? shot?['file'];
      if (reference is! String || reference.isEmpty) continue;
      final key = '$testLabel|$reference';
      _screenNamesByScreenshot
          .putIfAbsent(key, () => <String>{})
          .add(screenValue);
    }
  }

  void _auditScreenshotScreenMismatches() {
    for (final entry in _screenNamesByScreenshot.entries) {
      if (entry.value.length < 2) continue;
      final separator = entry.key.lastIndexOf('|');
      final testLabel = entry.key.substring(0, separator);
      final reference = entry.key.substring(separator + 1);
      _add('REVIEW',
          '$testLabel: the same screenshot (${p.basename(reference)}) is associated with different observer screens (${entry.value.join(', ')}); check whether the reported screen matches the captured UI.',
          screenshot: reference);
    }
  }

  void _auditRepeatedGeometry() {
    for (final repeated in _repeatedGeometry.values) {
      _add('REVIEW',
          'Indistinguishable ${repeated.type} nodes share bounds ${repeated.bounds.join(', ')} on "${repeated.screen}" in ${repeated.occurrences} snapshots; examples: ${repeated.examples.join('; ')}.');
    }
  }

  void printSummary() {
    stdout.writeln('Observer report audit');
    stdout.writeln('Report: ${reportFile.path}');
    stdout.writeln('State: ${document['state'] ?? 'unknown'}');
    stdout.writeln(
        'Tests: $tests | Steps: $steps | Observations: $observedSteps | Elements: $elements | Screenshots: $screenshots');
    stdout.writeln(
        'Findings: $errors errors, $warnings warnings, $reviews review candidates');
    if (_notes.isNotEmpty) {
      stdout.writeln(
          'OCR coverage notes: ${_notes.length} text regions may not have observer titles.');
    }
    if (findings.isNotEmpty) {
      final groups = <String, int>{};
      for (final finding in findings) {
        final key = '${finding.severity} ${finding.code}';
        groups.update(key, (count) => count + 1, ifAbsent: () => 1);
      }
      final sortedGroups = groups.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      stdout.writeln('Finding groups:');
      for (final group in sortedGroups) {
        stdout.writeln('  ${group.value} ${group.key}');
      }
      const maxPrintedFindings = 150;
      for (final finding in findings.take(maxPrintedFindings)) {
        stdout.writeln('${finding.severity}: ${finding.message}');
      }
      if (findings.length > maxPrintedFindings) {
        stdout.writeln(
            '... ${findings.length - maxPrintedFindings} additional findings omitted.');
      }
    }
    if (_notes.isNotEmpty) {
      stdout.writeln('OCR notes (possible missed text, lower confidence):');
      for (final note in _notes.take(12)) {
        stdout.writeln('INFO: $note');
      }
      if (_notes.length > 12) {
        stdout
            .writeln('... ${_notes.length - 12} additional OCR notes omitted.');
      }
    }
    if (findings.isEmpty) {
      stdout.writeln('No structural or consistency issues found.');
    }
  }

  void printJson() {
    stdout.writeln(jsonEncode({
      'schemaVersion': 1,
      'report': reportFile.path,
      'state': document['state'] ?? 'unknown',
      'counts': {
        'tests': tests,
        'steps': steps,
        'observations': observedSteps,
        'elements': elements,
        'screenshots': screenshots,
        'errors': errors,
        'warnings': warnings,
        'reviewCandidates': reviews,
        'ocrNotes': _notes.length,
      },
      'findings': [
        for (final finding in findings)
          {
            'code': finding.code,
            'severity': finding.severity,
            'confidence': finding.confidence,
            'message': finding.message,
            if (finding.screenshot != null) 'screenshot': finding.screenshot,
          },
      ],
    }));
  }

  void _add(String severity, String message, {String? screenshot}) {
    findings.add(_Finding(
      _findingCode(message),
      severity,
      severity == 'ERROR'
          ? 'high'
          : severity == 'WARN'
              ? 'medium'
              : severity == 'REVIEW'
                  ? 'low'
                  : 'informational',
      message,
      screenshot,
    ));
  }

  String _reportRelativePath(String path) =>
      p.relative(path, from: p.dirname(reportFile.path));

  void _note(String message) {
    if (_notes.length < 1000) _notes.add(message);
  }
}

class _Finding {
  const _Finding(
      this.code, this.severity, this.confidence, this.message, this.screenshot);
  final String code;
  final String severity;
  final String confidence;
  final String message;
  final String? screenshot;
}

String _findingCode(String message) {
  const rules = <(String, String)>[
    ('Report has no tests list', 'report.tests.missing'),
    ('Report is still marked as loading', 'report.incomplete'),
    ('coordinate unit', 'observer.coordinate_unit.unexpected'),
    ('viewport', 'observer.viewport.invalid'),
    ('not an object', 'report.structure.invalid'),
    ('elements is missing or not a list', 'observer.elements.missing'),
    ('duplicate element index', 'observer.element.duplicate_index'),
    ('has no valid index', 'observer.element.index_missing'),
    ('has no type', 'observer.element.type_missing'),
    ('has no bounds', 'observer.bounds.missing'),
    ('invalid bounds', 'observer.bounds.invalid'),
    (
      'marked offscreen but bounds overlap viewport',
      'observer.bounds.offscreen_inconsistent'
    ),
    (
      'marked visible but bounds do not overlap viewport',
      'observer.bounds.visible_outside_viewport'
    ),
    (
      'neither a locator nor action examples',
      'observer.locator.confidence_missing'
    ),
    (
      'direct actions but no scrollUntilVisible example',
      'observer.action.offscreen_missing_scroll'
    ),
    (
      'reported both visible and offscreen',
      'observer.duplicate_visibility_title'
    ),
    ('both visible and offscreen', 'observer.visibility.conflict'),
    ('disabled element', 'observer.interaction.disabled_but_interactable'),
    ('offscreen element', 'observer.interaction.offscreen_but_interactable'),
    ('locator is shared', 'observer.locator.duplicate'),
    ('unscoped text examples', 'observer.action.ambiguous_text_example'),
    ('screenshot overlay', 'report.overlay.invalid'),
    ('overlay for element', 'report.overlay.bounds_mismatch'),
    ('references unknown element index', 'report.overlay.element_unknown'),
    ('invalid left percentage', 'report.overlay.invalid_geometry'),
    ('screenshot has no file', 'report.screenshot.reference_missing'),
    ('screenshot file is missing', 'report.screenshot.file_missing'),
    ('could not be decoded', 'report.screenshot.decode_failed'),
    ('screenshot OCR sees', 'visual.hidden_text_mismatch'),
    ('outside the bounds', 'visual.element_bounds_mismatch'),
    ('no matching visible observer titles', 'visual.text_missing_from_tree'),
    (
      'offscreen labels also appear',
      'observer.possible_foreign_screen_content'
    ),
    ('same screenshot', 'report.screenshot.screen_name_conflict'),
    ('Indistinguishable', 'observer.indistinguishable_nodes'),
    (
      'visible anonymous button nodes share',
      'observer.control.duplicate_anonymous'
    ),
    (
      'reported both visible and offscreen',
      'observer.duplicate_visibility_title'
    ),
    ('matches multiple', 'observer.locator.ambiguous'),
  ];
  for (final (needle, code) in rules) {
    if (message.contains(needle)) return code;
  }
  return 'observer.audit.review';
}

class _ScreenshotInfo {
  const _ScreenshotInfo(this.path, this.width, this.height);
  final String path;
  final int width;
  final int height;
}

class _VisualSnapshot {
  const _VisualSnapshot({
    required this.where,
    required this.screen,
    required this.path,
    required this.imageWidth,
    required this.imageHeight,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.elements,
  });
  final String where;
  final String screen;
  final String path;
  final int imageWidth;
  final int imageHeight;
  final double viewportWidth;
  final double viewportHeight;
  final List<Map<String, dynamic>> elements;
}

class _RepeatedGeometry {
  _RepeatedGeometry({
    required this.screen,
    required this.type,
    required this.bounds,
  });
  final String screen;
  final String type;
  final List<String> bounds;
  final List<String> examples = [];
  int occurrences = 0;
}

class _ObservationRecord {
  const _ObservationRecord({
    required this.testLabel,
    required this.where,
    required this.screen,
    required this.visitedScreens,
    required this.labels,
    required this.screenshotReferences,
  });
  final String testLabel;
  final String where;
  final String screen;
  final Set<String> visitedScreens;
  final Map<String, Set<String>> labels;
  final Set<String> screenshotReferences;
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

num? _number(dynamic value) => value is num && value.isFinite ? value : null;

int? _integer(dynamic value) => value is int
    ? value
    : value is num
        ? value.toInt()
        : null;

String _actionName(String example) => example.split(':').first.trim();

String _normalizeText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _isUsefulText(String normalized) =>
    normalized.length >= 4 &&
    !const {'svg', 'image', 'icon', 'button'}.contains(normalized);

bool _textMatches(String first, String second) {
  final a = first.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  final b = second.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b || a.contains(b) || b.contains(a)) return true;
  final aWords = a.split(' ').where((word) => word.length >= 2).toSet();
  final bWords = b.split(' ').where((word) => word.length >= 2).toSet();
  final smaller = aWords.length <= bWords.length ? aWords : bWords;
  final larger = identical(smaller, aWords) ? bWords : aWords;
  if (smaller.length < 2) return false;
  final sharedWords = smaller.intersection(larger).length;
  return sharedWords >= (smaller.length * 0.65).ceil();
}

dynamic _canonical(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}
