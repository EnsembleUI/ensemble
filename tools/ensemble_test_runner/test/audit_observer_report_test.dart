import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('observer audit distinguishes valid scroll content from foreign content',
      () async {
    final temp = await Directory.systemTemp.createTemp('observer-audit-test-');
    addTearDown(() => temp.delete(recursive: true));
    final report = File(p.join(temp.path, 'results.json'));
    report.writeAsStringSync(jsonEncode(_referenceReport()));

    final result = await Process.run(
      'dart',
      [
        'run',
        'tool/audit_observer_report.dart',
        '--format=json',
        '--no-ocr',
        report.path,
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
    final audit = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final counts = audit['counts'] as Map<String, dynamic>;
    final findings = audit['findings'] as List<dynamic>;
    expect(counts['errors'], 0);
    expect(counts['warnings'], 0);
    expect(counts['reviewCandidates'], 1);
    expect(
      findings.any((value) =>
          (value as Map<String, dynamic>)['code'] ==
          'observer.possible_foreign_screen_content'),
      isTrue,
    );
  });

  test(
      'same screenshot under a visited screen suppresses foreign-content noise',
      () async {
    final temp = await Directory.systemTemp.createTemp('observer-audit-test-');
    addTearDown(() => temp.delete(recursive: true));
    final report = File(p.join(temp.path, 'results.json'));
    final data = _referenceReport();
    final steps = ((data['tests'] as List).single as Map)['steps'] as List;
    for (final value in steps) {
      (value as Map<String, dynamic>)['screenshots'] = [
        {'href': 'screenshots/same-screen.webp'},
      ];
    }
    report.writeAsStringSync(jsonEncode(data));

    final result = await _runAudit(report);
    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
    final audit = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final findings = audit['findings'] as List<dynamic>;
    expect(
      findings.any((value) =>
          (value as Map<String, dynamic>)['code'] ==
          'observer.possible_foreign_screen_content'),
      isFalse,
    );
    expect(
      findings.any((value) =>
          (value as Map<String, dynamic>)['code'] ==
          'report.screenshot.screen_name_conflict'),
      isTrue,
    );
  });

  test('observer audit reports contradictory visible and offscreen state',
      () async {
    final temp = await Directory.systemTemp.createTemp('observer-audit-test-');
    addTearDown(() => temp.delete(recursive: true));
    final report = File(p.join(temp.path, 'results.json'));
    final data = _referenceReport(includeForeignContent: false);
    final step = (((data['tests'] as List).single as Map)['steps'] as List).last
        as Map<String, dynamic>;
    final observation =
        ((step['observer'] as Map)['observationJson'] as Map<String, dynamic>);
    ((observation['elements'] as List).single as Map<String, dynamic>)
      ..['visible'] = true
      ..['offscreen'] = true;
    report.writeAsStringSync(jsonEncode(data));

    final result = await Process.run(
      'dart',
      [
        'run',
        'tool/audit_observer_report.dart',
        '--format=json',
        '--no-ocr',
        report.path,
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 1, reason: '${result.stderr}\n${result.stdout}');
    final audit = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final findings = audit['findings'] as List<dynamic>;
    expect(
      findings.any((value) =>
          (value as Map<String, dynamic>)['code'] ==
          'observer.visibility.conflict'),
      isTrue,
    );
  });

  test('observer audit warns on overlapping anonymous button nodes', () async {
    final temp = await Directory.systemTemp.createTemp('observer-audit-test-');
    addTearDown(() => temp.delete(recursive: true));
    final report = File(p.join(temp.path, 'results.json'));
    final data = _referenceReport(includeForeignContent: false);
    final steps = ((data['tests'] as List).single as Map)['steps'] as List;
    final observation =
        ((steps.single as Map)['observer'] as Map)['observationJson'] as Map;
    observation['elements'] = [
      {
        'index': 1,
        'type': 'button',
        'visible': true,
        'offscreen': false,
        'interactable': false,
        'bounds': {'left': 0, 'top': 0, 'width': 402, 'height': 62},
      },
      {
        'index': 2,
        'type': 'button',
        'visible': true,
        'offscreen': false,
        'interactable': false,
        'bounds': {'left': 0, 'top': 0, 'width': 402, 'height': 62},
      },
    ];
    report.writeAsStringSync(jsonEncode(data));

    final result = await _runAudit(report);
    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
    final audit = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final findings = audit['findings'] as List<dynamic>;
    final duplicateFindings = findings
        .where((value) =>
            (value as Map<String, dynamic>)['code'] ==
            'observer.control.duplicate_anonymous')
        .toList();
    expect(duplicateFindings, hasLength(1));
    expect(
      (duplicateFindings.single as Map<String, dynamic>)['severity'],
      'WARN',
    );
  });

  test('ambiguous text examples require occurrence or another scope', () async {
    final temp = await Directory.systemTemp.createTemp('observer-audit-test-');
    addTearDown(() => temp.delete(recursive: true));
    final report = File(p.join(temp.path, 'results.json'));
    final element = _element(1, 'Sensor 2', 100)
      ..['warning'] = 'Suggested locator matches multiple observed elements'
      ..['actionExamples'] = [
        'expectText:\n  text: "Sensor 2"',
        'waitForText:\n  text: "Sensor 2"\n  occurrence: 2',
      ];
    final data = _referenceReport(includeForeignContent: false);
    final steps = ((data['tests'] as List).single as Map)['steps'] as List;
    final observation =
        ((steps.single as Map)['observer'] as Map)['observationJson'] as Map;
    observation['elements'] = [element];
    report.writeAsStringSync(jsonEncode(data));

    final result = await _runAudit(report);
    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
    final audit = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final findings = audit['findings'] as List<dynamic>;
    expect(findings, hasLength(1));
    expect(
      (findings.single as Map<String, dynamic>)['code'],
      'observer.action.ambiguous_text_example',
    );
  });
}

Future<ProcessResult> _runAudit(File report) => Process.run(
      'dart',
      [
        'run',
        'tool/audit_observer_report.dart',
        '--format=json',
        '--no-ocr',
        report.path,
      ],
      workingDirectory: Directory.current.path,
    );

Map<String, dynamic> _referenceReport({bool includeForeignContent = true}) {
  final visitedScreens = includeForeignContent
      ? ['AccountDetails', 'ConfirmationDialog']
      : ['ConfirmationDialog'];
  final steps = <Map<String, dynamic>>[
    if (includeForeignContent)
      _step('AccountDetails', [
        _element(1, 'Account', 10),
        _element(2, 'Connected services', 40),
        _element(3, 'Restart service', 70),
        _element(4, 'Network settings', 100),
      ]),
    _step('ConfirmationDialog', [
      _element(
        1,
        'Scroll destination item',
        900,
        visible: false,
        offscreen: true,
        actionExamples: ['scrollUntilVisible: target by title'],
      ),
      if (includeForeignContent) ...[
        _element(2, 'Account', 1000, visible: false, offscreen: true),
        _element(3, 'Connected services', 1040,
            visible: false, offscreen: true),
        _element(4, 'Restart service', 1070, visible: false, offscreen: true),
        _element(5, 'Network settings', 1100, visible: false, offscreen: true),
      ],
    ]),
  ];
  return {
    'state': 'complete',
    'tests': [
      {
        'id': 'observer_reference_cases',
        'report': {'screensVisited': visitedScreens},
        'steps': steps,
      },
    ],
  };
}

Map<String, dynamic> _step(
        String screen, List<Map<String, dynamic>> elements) =>
    {
      'observer': {
        'observationJson': {
          'screen': screen,
          'viewport': {'width': 402, 'height': 874},
          'elements': elements,
        },
      },
      'screenshots': <dynamic>[],
    };

Map<String, dynamic> _element(
  int index,
  String title,
  num top, {
  bool visible = true,
  bool offscreen = false,
  List<String> actionExamples = const [],
}) =>
    {
      'index': index,
      'type': 'text',
      'title': title,
      'visible': visible,
      'offscreen': offscreen,
      'enabled': false,
      'interactable': false,
      'bounds': {'left': 16, 'top': top, 'width': 260, 'height': 32},
      'actionExamples': actionExamples,
    };
