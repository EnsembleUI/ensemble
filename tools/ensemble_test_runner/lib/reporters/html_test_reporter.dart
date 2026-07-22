import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/step_log_grouping.dart';
import 'package:ensemble_test_runner/reporters/step_outline_format.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:path/path.dart' as p;

/// Writes a browsable HTML report that links existing suite artifacts.
class HtmlTestReporter {
  /// Writes `report/index.html` under [artifactRoot] and returns the display path.
  String write(
    EnsembleTestRunResult result, {
    String? artifactRoot,
    String? displayRoot,
    int? wallTimeMs,
    bool isSuiteRunning = false,
  }) {
    final root = artifactRoot ?? ensembleTestArtifactRoot;
    final display = displayRoot ?? _defaultDisplayRoot;
    final reportDir = Directory(p.join(root, 'report'));
    reportDir.createSync(recursive: true);
    final file = File(p.join(reportDir.path, 'index.html'));
    file.writeAsStringSync(
      buildHtml(
        result,
        artifactRoot: root,
        displayRoot: display,
        wallTimeMs: wallTimeMs,
        isSuiteRunning: isSuiteRunning,
      ),
    );
    return p.join(display, 'report', 'index.html').replaceAll('\\', '/');
  }

  String buildHtml(
    EnsembleTestRunResult result, {
    required String artifactRoot,
    required String displayRoot,
    int? wallTimeMs,
    bool isSuiteRunning = false,
  }) {
    if (isSuiteRunning) {
      final loadingBuffer = StringBuffer()
        ..writeln('<!DOCTYPE html>')
        ..writeln('<html lang="en">')
        ..writeln('<head>')
        ..writeln('<meta charset="utf-8"/>')
        ..writeln(
            '<meta name="viewport" content="width=device-width, initial-scale=1"/>')
        ..writeln('<meta http-equiv="refresh" content="3"/>')
        ..writeln('<title>Ensemble Test Runner</title>')
        ..writeln('<link rel="preconnect" href="https://fonts.googleapis.com">')
        ..writeln(
            '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>')
        ..writeln(
            '<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300..800&display=swap" rel="stylesheet">')
        ..writeln('<style>${_css()}</style>')
        ..writeln('</head>')
        ..writeln('<body>')
        ..writeln('<div class="grid-overlay"></div>')
        ..writeln('<div class="full-page-loader">')
        ..writeln('  <div class="spinner"></div>')
        ..writeln('  <h1>Ensemble Test Runner</h1>')
        ..writeln('  <p class="subtitle">Test Suite Execution in Progress</p>')
        ..writeln(
            '  <div class="loader-progress-info">Running all declarative tests on configured device targets. The dashboard will populate automatically when finished.</div>')
        ..writeln('  <div class="skeleton-line-full"></div>')
        ..writeln('  <div class="skeleton-line-full"></div>')
        ..writeln('  <div class="skeleton-line-full"></div>')
        ..writeln('</div>')
        ..writeln('</body>')
        ..writeln('</html>');
      return loadingBuffer.toString();
    }

    final totalMs = result.results.fold<int>(0, (sum, r) => sum + r.durationMs);
    final displayMs = wallTimeMs ?? totalMs;
    final ordered = [
      ...result.results.where((r) => r.status == TestStatus.failed),
      ...result.results.where((r) => r.status != TestStatus.failed),
    ];

    // Group tests by base test ID to avoid duplicate sidebar cards for multi-device runs
    final grouped = <String, List<EnsembleSingleTestResult>>{};
    for (final test in ordered) {
      final base = _baseId(test.testId);
      grouped.putIfAbsent(base, () => []).add(test);
    }
    final groupedKeys = grouped.keys.toList();

    final totalTests = result.results.length;
    final passedCount =
        result.results.where((r) => r.status == TestStatus.passed).length;
    final failedCount = result.failedCount;
    final pendingCount =
        result.results.where((r) => r.status == TestStatus.pending).length;
    final successRate = totalTests > 0
        ? (passedCount / totalTests * 100).toStringAsFixed(0)
        : '0';

    final summaryText = pendingCount > 0
        ? '$passedCount passed, $failedCount failed, $pendingCount running ($totalTests total)'
        : '$passedCount passed, $failedCount failed ($totalTests total)';
    final summaryClass =
        pendingCount > 0 ? 'running' : (failedCount == 0 ? 'passed' : 'failed');

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8"/>')
      ..writeln(
          '<meta name="viewport" content="width=device-width, initial-scale=1"/>')
      ..writeln('<title>Ensemble Test Runner Report</title>')
      ..writeln('<link rel="preconnect" href="https://fonts.googleapis.com">')
      ..writeln(
          '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>')
      ..writeln(
          '<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:ital,wght@0,300..800;1,300..800&family=JetBrains+Mono:ital,wght@0,100..800;1,100..800&display=swap" rel="stylesheet">')
      ..writeln('<style>${_css()}</style>')
      ..writeln('</head>')
      ..writeln(
          '<body onload="const firstCard = document.querySelector(\'.test\'); if (firstCard) firstCard.click();">')
      ..writeln('<div class="grid-overlay"></div>')
      ..writeln('<header class="hero">')
      ..writeln('  <div class="hero-header">')
      ..writeln('    <h1>Ensemble Test Runner</h1>')
      ..writeln('    <p class="summary $summaryClass">')
      ..writeln('      ${_escape(summaryText)} · ${_formatDuration(displayMs)}')
      ..writeln('    </p>')
      ..writeln('  </div>')
      ..writeln('</header>');

    // Metrics Dashboard
    buffer
      ..writeln('<section class="dashboard">')
      ..writeln('  <div class="metrics-grid">')
      ..writeln('    <div class="metric-card">')
      ..writeln('      <div class="metric-val">$totalTests</div>')
      ..writeln('      <div class="metric-label">Total Tests</div>')
      ..writeln('    </div>');

    if (pendingCount > 0) {
      buffer
        ..writeln('    <div class="metric-card metric-running">')
        ..writeln('      <div class="metric-val">$pendingCount</div>')
        ..writeln('      <div class="metric-label">Running</div>')
        ..writeln('    </div>');
    }

    buffer
      ..writeln('    <div class="metric-card metric-passed">')
      ..writeln('      <div class="metric-val">$passedCount</div>')
      ..writeln('      <div class="metric-label">Passed</div>')
      ..writeln('    </div>')
      ..writeln('    <div class="metric-card metric-failed">')
      ..writeln('      <div class="metric-val">$failedCount</div>')
      ..writeln('      <div class="metric-label">Failed</div>')
      ..writeln('    </div>')
      ..writeln('    <div class="metric-card metric-rate">')
      ..writeln('      <div class="metric-val">$successRate%</div>')
      ..writeln('      <div class="metric-label">Success Rate</div>')
      ..writeln('    </div>')
      ..writeln('    <div class="metric-card metric-duration">')
      ..writeln(
          '      <div class="metric-val">${_formatDuration(displayMs)}</div>')
      ..writeln('      <div class="metric-label">Suite Duration</div>')
      ..writeln('    </div>')
      ..writeln('  </div>')
      ..writeln('</section>');

    // Search and Filter controls
    buffer
      ..writeln('<section class="controls">')
      ..writeln('  <div class="controls-bar">')
      ..writeln('    <div class="search-wrapper">')
      ..writeln(
          '      <input type="text" id="search-input" placeholder="Search test cases by ID or name..." oninput="')
      ..writeln('        const q = this.value.toLowerCase().trim();')
      ..writeln('        document.querySelectorAll(\'.test\').forEach(c => {')
      ..writeln(
          '          const matchQ = c.id.toLowerCase().includes(q) || c.innerText.toLowerCase().includes(q);')
      ..writeln('          const f = window.activeFilter || \'all\';')
      ..writeln(
          '          const matchF = f === \'all\' || (f === \'passed\' && c.classList.contains(\'passed\')) || (f === \'failed\' && c.classList.contains(\'failed\'));')
      ..writeln(
          '          c.style.display = (matchQ && matchF) ? \'flex\' : \'none\';')
      ..writeln('        });')
      ..writeln('      "/>')
      ..writeln('    </div>')
      ..writeln('    <div class="filter-tabs">')
      ..writeln(
          '      <button class="filter-btn active" data-filter="all" onclick="')
      ..writeln('        window.activeFilter = \'all\';')
      ..writeln(
          '        document.querySelectorAll(\'.filter-btn\').forEach(b => b.classList.toggle(\'active\', b.getAttribute(\'data-filter\') === \'all\'));')
      ..writeln(
          '        document.getElementById(\'search-input\').dispatchEvent(new Event(\'input\'));')
      ..writeln('      ">All Tests</button>')
      ..writeln(
          '      <button class="filter-btn" data-filter="failed" onclick="')
      ..writeln('        window.activeFilter = \'failed\';')
      ..writeln(
          '        document.querySelectorAll(\'.filter-btn\').forEach(b => b.classList.toggle(\'active\', b.getAttribute(\'data-filter\') === \'failed\'));')
      ..writeln(
          '        document.getElementById(\'search-input\').dispatchEvent(new Event(\'input\'));')
      ..writeln('      ">Failed</button>')
      ..writeln(
          '      <button class="filter-btn" data-filter="passed" onclick="')
      ..writeln('        window.activeFilter = \'passed\';')
      ..writeln(
          '        document.querySelectorAll(\'.filter-btn\').forEach(b => b.classList.toggle(\'active\', b.getAttribute(\'data-filter\') === \'passed\'));')
      ..writeln(
          '        document.getElementById(\'search-input\').dispatchEvent(new Event(\'input\'));')
      ..writeln('      ">Passed</button>')
      ..writeln('    </div>')
      ..writeln('  </div>')
      ..writeln('</section>');

    _writeSuiteArtifacts(
      buffer,
      result.suiteLogs,
      artifactRoot: artifactRoot,
      displayRoot: displayRoot,
    );

    // Master-Detail Split Screen Container
    buffer.writeln('<div class="dashboard-container">');

    // Left Pane (Sidebar List of small cards grouped by test case)
    buffer.writeln('  <aside class="test-list-pane">');
    for (final base in groupedKeys) {
      _writeTestCard(buffer, base, grouped[base]!);
    }
    buffer.writeln('  </aside>');

    // Right Pane (Inspector View)
    buffer
      ..writeln('  <section class="test-detail-pane">')
      ..writeln('    <div id="details-placeholder" class="detail-placeholder">')
      ..writeln('      <div class="placeholder-icon">🔍</div>')
      ..writeln('      <h3>No Test Selected</h3>')
      ..writeln(
          '      <p>Select a test case from the left list to inspect results, screen journeys, logs, and screenshots.</p>')
      ..writeln('    </div>');

    // Render detailed content for each group
    for (final base in groupedKeys) {
      _writeTestDetailsGroup(
        buffer,
        base,
        grouped[base]!,
        artifactRoot: artifactRoot,
        displayRoot: displayRoot,
      );
    }
    buffer.writeln('  </section>');
    buffer.writeln('</div>');

    buffer
      ..writeln(_buildStepModalHtmlAndScript())
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }

  void _writeSuiteArtifacts(
    StringBuffer buffer,
    List<String> suiteLogs, {
    required String artifactRoot,
    required String displayRoot,
  }) {
    final artifacts = _parseArtifacts(suiteLogs);
    if (artifacts.isEmpty) return;

    buffer
      ..writeln('<section class="suite-artifacts-container">')
      ..writeln('  <details class="suite-artifacts-card">')
      ..writeln(
          '    <summary>Show Suite Logs & Artifacts (${artifacts.length})</summary>')
      ..writeln('    <div class="suite-artifacts-content">')
      ..writeln('      <ul>');

    for (final artifact in artifacts) {
      final href = _relativeHref(artifact.path, displayRoot);
      buffer
        ..writeln('        <li>')
        ..writeln('          <div class="artifact-item-header">')
        ..writeln(
            '            <span class="label">${_escape(artifact.label)}</span>: ')
        ..writeln(
            '            <a href="${_escape(href)}">${_escape(artifact.path)}</a>')
        ..writeln('          </div>')
        ..writeln('        </li>');
    }

    buffer
      ..writeln('      </ul>')
      ..writeln('    </div>')
      ..writeln('  </details>')
      ..writeln('</section>');
  }

  void _writeTestCard(
      StringBuffer buffer, String base, List<EnsembleSingleTestResult> runs) {
    final firstRun = runs.first;
    final hasPending = runs.any((r) => r.status == TestStatus.pending);
    final groupPassed = runs.every((r) => r.status == TestStatus.passed);
    final cardId = _anchorId(firstRun.testId);
    final statusClass =
        hasPending ? 'pending' : (groupPassed ? 'passed' : 'failed');

    // Literal match for test assertions: "<article class="test failed" id="login_flow_tests_login_test_yaml_">"
    buffer
      ..writeln(
          '    <article class="test $statusClass" id="${_escape(cardId)}" onclick="')
      ..writeln(
          '      document.querySelectorAll(\'.test\').forEach(c => c.classList.remove(\'active\'));')
      ..writeln('      this.classList.add(\'active\');')
      ..writeln(
          '      document.getElementById(\'details-placeholder\').style.display = \'none\';')
      ..writeln(
          '      document.querySelectorAll(\'.test-detail-content\').forEach(d => d.style.display = \'none\');')
      ..writeln(
          '      document.getElementById(\'details-$cardId\').style.display = \'block\';')
      ..writeln(
          '      const firstBtn = document.querySelector(\'#details-$cardId .device-tab-btn\');')
      ..writeln('      if (firstBtn) {')
      ..writeln('        firstBtn.click();')
      ..writeln('      } else {')
      ..writeln(
          '        const firstBlock = document.querySelector(\'#details-$cardId .device-run-block\');')
      ..writeln('        if (firstBlock) firstBlock.style.display = \'block\';')
      ..writeln('      }')
      ..writeln('    ">')
      ..writeln('      <div class="card-status-dot"></div>')
      ..writeln('      <div class="card-info">')
      ..writeln('        <div class="card-title">${_escape(base)}</div>')
      ..writeln('        <div class="card-meta">')
      ..writeln(
          '          <span class="card-duration">${_formatDuration(firstRun.durationMs)}</span>');

    // Render device badges as mini-pills under card title
    for (final run in runs) {
      final badge = _deviceBadgeOf(run.testId);
      if (badge.isNotEmpty) {
        buffer.writeln(
            '          <span class="card-device-badge">${_escape(badge.toUpperCase())}</span>');
      }
    }

    buffer
      ..writeln('        </div>')
      ..writeln('      </div>')
      ..writeln('    </article>');
  }

  void _writeTestDetailsGroup(
    StringBuffer buffer,
    String base,
    List<EnsembleSingleTestResult> runs, {
    required String artifactRoot,
    required String displayRoot,
  }) {
    final firstRun = runs.first;
    final cardId = _anchorId(firstRun.testId);

    buffer.writeln(
        '<div class="test-detail-content" id="details-$cardId" style="display: none;">');

    // 1. selector buttons if more than 1 run
    if (runs.length > 1) {
      buffer
        ..writeln('  <div class="device-selector-bar">')
        ..writeln('    <span class="selector-label">Device Runs:</span>')
        ..writeln('    <div class="device-tabs">');
      for (var i = 0; i < runs.length; i++) {
        final run = runs[i];
        final badge = _deviceBadgeOf(run.testId);
        final tabText = _deviceButtonText(badge);
        buffer
          ..writeln(
              '      <button class="device-tab-btn" data-run="$i" onclick="')
          ..writeln(
              '        document.querySelectorAll(\'#details-$cardId .device-tab-btn\').forEach(b => b.classList.remove(\'active\'));')
          ..writeln('        this.classList.add(\'active\');')
          ..writeln(
              '        document.querySelectorAll(\'#details-$cardId .device-run-block\').forEach(r => r.style.display = \'none\');')
          ..writeln(
              '        document.getElementById(\'run-$cardId-$i\').style.display = \'block\';')
          ..writeln('      ">$tabText</button>');
      }
      buffer
        ..writeln('    </div>')
        ..writeln('  </div>');
    }

    // 2. detail blocks for each device run
    for (var i = 0; i < runs.length; i++) {
      final test = runs[i];
      final passed = test.status == TestStatus.passed;
      final isPending = test.status == TestStatus.pending;
      final badge = _deviceBadgeOf(test.testId);
      final filePath = _filePathOf(test.testId);

      final stepDataJson = _buildStepDataJson(test, artifactRoot, displayRoot);
      buffer
        ..writeln('  <script>')
        ..writeln('    window.stepData = window.stepData || {};')
        ..writeln('    window.stepData[\'$cardId-$i\'] = $stepDataJson;')
        ..writeln('  </script>')
        ..writeln(
            '  <div class="device-run-block" id="run-$cardId-$i" style="display: none;">')
        ..writeln('    <div class="test-card-header">')
        ..writeln('      <div class="title-section">')
        ..writeln('        <h2>')
        ..writeln(
            '          <span class="icon">${isPending ? '🔄' : (passed ? '✓' : '✗')}</span> ')
        ..writeln('          ${_escape(base)}')
        ..writeln('        </h2>');

      if (badge.isNotEmpty) {
        final isAndroid = badge.toLowerCase().contains('android') ||
            badge.toLowerCase().contains('samsung') ||
            badge.toLowerCase().contains('pixel');
        final isIos = badge.toLowerCase().contains('ios') ||
            badge.toLowerCase().contains('iphone');
        final hasNl = badge.toLowerCase().contains('nl');
        final badgeClass = isAndroid ? 'android' : (isIos ? 'ios' : 'default');
        final iconName = isAndroid ? 'Android' : (isIos ? 'iOS' : 'Device');
        final flagStr = hasNl ? ' 🇳🇱 DUTCH (NL)' : ' 🇬🇧 ENGLISH (EN)';
        buffer.writeln(
            '        <span class="device-pill $badgeClass">$iconName · ${_escape(badge.toUpperCase())}$flagStr</span>');
      }

      final statusText = isPending ? 'RUNNING' : (passed ? 'PASSED' : 'FAILED');
      final statusCapsuleClass =
          isPending ? 'pending' : (passed ? 'passed' : 'failed');

      buffer
        ..writeln('      </div>')
        ..writeln(
            '      <div class="status-capsule $statusCapsuleClass">$statusText</div>')
        ..writeln('    </div>');

      if (filePath.isNotEmpty) {
        buffer.writeln(
            '    <p class="file-path-sub"><span>File:</span> ${_escape(filePath)}</p>');
      }

      if (isPending) {
        buffer
          ..writeln('    <div class="pending-detail-loader">')
          ..writeln('      <div class="spinner"></div>')
          ..writeln('      <h3>Test Execution in Progress</h3>')
          ..writeln(
              '      <p>This test case is currently running on the device. Please wait for the execution to finish.</p>')
          ..writeln('      <div class="skeleton-line"></div>')
          ..writeln('      <div class="skeleton-line"></div>')
          ..writeln('      <div class="skeleton-line"></div>')
          ..writeln('    </div>');
      } else {
        buffer
          ..writeln('    <p class="meta">${_formatDuration(test.durationMs)}'
              '${test.attempts > 1 ? ' · attempts ${test.attempts}/${test.retry + 1}' : ''}'
              '</p>');

        final report = test.report;
        if (report != null) {
          buffer.writeln('    <div class="meta-dashboard-rail">');
          if (report.session != null) {
            buffer.writeln(
                '      <div class="rail-item"><div class="rail-label">Session</div><div class="rail-val">${_escape(report.session!)}</div></div>');
          }
          buffer.writeln(
              '      <div class="rail-item"><div class="rail-label">Start Screen</div><div class="rail-val highlight">${_escape(report.startScreen)}</div></div>');
          if (report.endScreen != null &&
              report.endScreen != report.startScreen) {
            buffer.writeln(
                '      <div class="rail-item"><div class="rail-label">End Screen</div><div class="rail-val highlight">${_escape(report.endScreen!)}</div></div>');
          }
          buffer.writeln('    </div>');

          if (report.screensVisited.length > 1) {
            buffer
              ..writeln('    <div class="flow-timeline">')
              ..writeln('      <div class="flow-label">Flow Journey</div>')
              ..writeln('      <div class="flow-track">');
            for (var j = 0; j < report.screensVisited.length; j++) {
              buffer.writeln(
                  '        <span class="flow-node">${_escape(report.screensVisited[j])}</span>');
              if (j < report.screensVisited.length - 1) {
                buffer.writeln('        <span class="flow-arrow">→</span>');
              }
            }
            buffer.writeln('      </div>');
            buffer.writeln('    </div>');
          }

          if (report.stepsOutline.isNotEmpty) {
            buffer
              ..writeln('    <div class="timeline-steps-container">')
              ..writeln(
                  '      <div class="timeline-header">Steps Outline</div>')
              ..writeln('      <div class="timeline-steps-track">');
            var j = 0;
            for (final line in stepOutlineDisplayLines(
              stepsOutline: report.stepsOutline,
              stepDurationsMs: report.stepDurationsMs,
              failedStepIndex: !passed ? test.failedStepIndex : null,
            )) {
              final formattedText = _formatStepText(report.stepsOutline[j]);
              final speedClass = line.durationMs == null
                  ? 'fast'
                  : (line.durationMs! < 500
                      ? 'fast'
                      : (line.durationMs! < 2000 ? 'normal' : 'slow'));

              buffer
                ..writeln(
                    '        <div class="timeline-step-row ${line.failed ? 'failed-step' : ''}" style="cursor: pointer;" onclick="openStepDialog(\'$cardId-$i\', $j)">')
                ..writeln(
                    '          <div class="timeline-marker"><span class="marker-dot"></span></div>')
                ..writeln('          <div class="step-outline-body">')
                ..writeln('            <div class="step-outline-top-row">')
                ..writeln(
                    '              <div class="step-outline-text">$formattedText</div>');

              if (line.durationMs != null) {
                buffer.writeln(
                    '              <span class="step-duration $speedClass">${_escape(_formatDuration(line.durationMs!))}</span>');
              }
              buffer.writeln('            </div>');

              if (line.failed && test.message != null) {
                buffer.writeln(
                    '            <div class="step-error-reason">${_escape(test.message!)}</div>');
              }

              buffer
                ..writeln('          </div>')
                ..writeln('        </div>');
              j++;
            }
            buffer.writeln('      </div>');
            buffer.writeln('    </div>');
          }
        }

        if (!passed && test.message != null) {
          buffer.writeln(
            '    <pre class="error">${_escape(test.message!)}</pre>',
          );
        }

        final artifacts = _parseArtifacts(test.logs);
        if (artifacts.isNotEmpty) {
          final screenshotManifests = _screenshotManifestArtifacts(artifacts);
          final logs = artifacts
              .where((a) =>
                  a.label != 'screenshots' && a.label != 'screenshotFrames')
              .toList();

          // 3. Render side-by-side terminal logs widget
          final appLogRef = logs.firstWhere((a) => a.label == 'appLogs',
              orElse: () => _ArtifactRef(label: '', path: ''));
          final apiCallsRef = logs.firstWhere((a) => a.label == 'apiCalls',
              orElse: () => _ArtifactRef(label: '', path: ''));
          final storageRef = logs.firstWhere((a) => a.label == 'storage',
              orElse: () => _ArtifactRef(label: '', path: ''));

          buffer.writeln('    <div class="logs-grid-container">');

          // Actions & Console logs pane
          final appLogsHref = appLogRef.path.isNotEmpty
              ? _relativeHref(appLogRef.path, displayRoot)
              : '';
          buffer
            ..writeln('      <div class="logs-card-pane">')
            ..writeln('        <div class="logs-pane-title">')
            ..writeln(
                '          <span>📝 Actions & Console Logs <span class="raw-label">(appLogs)</span></span>');
          if (appLogsHref.isNotEmpty) {
            buffer.writeln(
                '          <button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'logs\')">⛶ Open Fullscreen</button>');
          }
          buffer
            ..writeln('        </div>')
            ..writeln('        <div class="logs-terminal">');

          if (appLogRef.path.isNotEmpty) {
            final fsPath = _filesystemPath(appLogRef.path,
                artifactRoot: artifactRoot, displayRoot: displayRoot);
            if (fsPath != null && File(fsPath).existsSync()) {
              final lines = File(fsPath).readAsLinesSync();
              if (lines.isEmpty) {
                buffer.writeln(
                    '          <div class="terminal-row" style="color: var(--text-muted);">&lt;no console output&gt;</div>');
              } else {
                for (final line in lines) {
                  var logBody = line;
                  var timePart = '';
                  if (line.startsWith('[')) {
                    final closeBrace = line.indexOf(']');
                    if (closeBrace != -1) {
                      final tStr = line.substring(1, closeBrace);
                      logBody = line.substring(closeBrace + 1).trim();
                      final timeMatch =
                          RegExp(r'T(\d{2}:\d{2}:\d{2})').firstMatch(tStr);
                      if (timeMatch != null) {
                        timePart = '[${timeMatch.group(1)}] ';
                      }
                    }
                  }

                  if (logBody.startsWith('SCREEN TRACKER:')) {
                    final text =
                        logBody.replaceAll('SCREEN TRACKER:', '').trim();
                    buffer.writeln(
                        '          <div class="terminal-row"><span class="terminal-timestamp">${_escape(timePart)}</span><span class="terminal-badge info">SCREEN</span> <span style="color: var(--accent); font-weight: 700;">${_escape(text)}</span></div>');
                  } else if (logBody.toLowerCase().contains('error') ||
                      logBody.toLowerCase().contains('exception')) {
                    buffer.writeln(
                        '          <div class="terminal-row"><span class="terminal-timestamp">${_escape(timePart)}</span><span class="terminal-badge failed">ERROR</span> <span style="color: var(--fail);">${_escape(logBody)}</span></div>');
                  } else {
                    buffer.writeln(
                        '          <div class="terminal-row"><span class="terminal-timestamp">${_escape(timePart)}</span>${_escape(logBody)}</div>');
                  }
                }
              }
            } else {
              buffer.writeln(
                  '          <div class="terminal-row" style="color: var(--text-muted);">&lt;no console output&gt;</div>');
            }
          } else {
            buffer.writeln(
                '          <div class="terminal-row" style="color: var(--text-muted);">&lt;no console output&gt;</div>');
          }
          buffer
            ..writeln('        </div>')
            ..writeln('      </div>');

          // Network Logs / API Calls terminal pane
          final apiCallsHref = apiCallsRef.path.isNotEmpty
              ? _relativeHref(apiCallsRef.path, displayRoot)
              : '';
          buffer
            ..writeln('      <div class="logs-card-pane">')
            ..writeln('        <div class="logs-pane-title">')
            ..writeln(
                '          <span>🌐 Network API Logs <span class="raw-label">(apiCalls)</span></span>');
          if (apiCallsHref.isNotEmpty) {
            buffer.writeln(
                '          <button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'apis\')">⛶ Open Fullscreen</button>');
          }
          buffer
            ..writeln('        </div>')
            ..writeln('        <div class="logs-terminal">');

          var hasApiEvents = false;
          if (apiCallsRef.path.isNotEmpty) {
            final fsPath = _filesystemPath(apiCallsRef.path,
                artifactRoot: artifactRoot, displayRoot: displayRoot);
            if (fsPath != null && File(fsPath).existsSync()) {
              try {
                final decoded = json.decode(File(fsPath).readAsStringSync());
                if (decoded is Map && decoded['events'] is List) {
                  final events = decoded['events'] as List;
                  if (events.isNotEmpty) {
                    hasApiEvents = true;
                    for (final ev in events) {
                      if (ev is Map) {
                        final name = ev['name']?.toString() ?? 'API';
                        final statusCode = ev['statusCode'];
                        final mocked = ev['mocked'] == true;
                        final timestamp = ev['timestamp']?.toString() ?? '';
                        var timePart = '';
                        final timeMatch = RegExp(r'T(\d{2}:\d{2}:\d{2})')
                            .firstMatch(timestamp);
                        if (timeMatch != null) {
                          timePart = '[${timeMatch.group(1)}] ';
                        }

                        final hasError = ev['error'] != null ||
                            ev['failed'] == true ||
                            ev['exception'] != null;
                        final isSuccess = statusCode != null
                            ? (statusCode is int &&
                                statusCode >= 200 &&
                                statusCode < 300)
                            : !hasError;
                        final displayStatus = statusCode != null
                            ? '$statusCode'
                            : (isSuccess ? '200' : 'ERROR');

                        final badgeClass =
                            mocked ? 'info' : (isSuccess ? 'passed' : 'failed');
                        final String badgeText;
                        if (mocked) {
                          badgeText = 'MOCK';
                        } else {
                          final type = ev['type']?.toString().toLowerCase();
                          if (type == 'firestore') {
                            badgeText = 'FIRESTORE';
                          } else if (type == 'functions') {
                            badgeText = 'FUNC';
                          } else {
                            badgeText = 'API';
                          }
                        }
                        final statusColor =
                            isSuccess ? 'var(--pass)' : 'var(--fail)';

                        buffer.writeln(
                            '          <div class="terminal-row"><span class="terminal-timestamp">${_escape(timePart)}</span><span class="terminal-badge $badgeClass">$badgeText</span><span style="font-weight: 700; color: #fff;">${_escape(name)}</span> · <span style="color: $statusColor; font-weight: 700;">$displayStatus</span></div>');
                      }
                    }
                  }
                }
              } catch (_) {}
            }
          }

          if (!hasApiEvents) {
            buffer.writeln(
                '          <div class="terminal-row" style="color: var(--text-muted);">&lt;no API requests recorded&gt;</div>');
          }

          buffer
            ..writeln('        </div>')
            ..writeln('      </div>')
            ..writeln('    </div>');

          // Extra local storage log view at the bottom if present
          if (storageRef.path.isNotEmpty) {
            var storageContent = '';
            final fsPath = _filesystemPath(storageRef.path,
                artifactRoot: artifactRoot, displayRoot: displayRoot);
            if (fsPath != null && File(fsPath).existsSync()) {
              try {
                final raw = File(fsPath).readAsStringSync();
                final decoded = json.decode(raw);
                // Prefer end-of-test keys snapshot when present (new artifact shape).
                final display = (decoded is Map && decoded['keys'] is Map)
                    ? decoded['keys']
                    : decoded;
                storageContent =
                    const JsonEncoder.withIndent('  ').convert(display);
              } catch (_) {
                storageContent = File(fsPath).readAsStringSync();
              }
            }

            buffer
              ..writeln('    <div style="margin-top: 16px;">')
              ..writeln(
                  '      <div class="logs-card-pane" style="height: 240px;">')
              ..writeln('        <div class="logs-pane-title">')
              ..writeln(
                  '          <span>💾 Local State Storage <span class="raw-label">(storage)</span></span>')
              ..writeln(
                  '          <button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'storage\')">⛶ Open Fullscreen</button>')
              ..writeln('        </div>')
              ..writeln('        <div class="logs-terminal">');

            if (storageContent.isNotEmpty) {
              for (final line in storageContent.split('\n')) {
                buffer.writeln(
                    '          <div class="terminal-row">${_escape(line)}</div>');
              }
            } else {
              buffer.writeln(
                  '          <div class="terminal-row" style="color: var(--text-muted);">&lt;empty local storage state&gt;</div>');
            }

            buffer
              ..writeln('        </div>')
              ..writeln('      </div>')
              ..writeln('    </div>');
          }

          // 4. HTML contact-sheet gallery from per-step frames (no composite PNG)
          if (screenshotManifests.isNotEmpty) {
            buffer.writeln('    <div class="screenshot-artifacts-row">');
            for (final artifact in screenshotManifests) {
              _writeScreenshotGallery(
                buffer,
                artifact: artifact,
                artifactRoot: artifactRoot,
                displayRoot: displayRoot,
              );
            }
            buffer.writeln('    </div>');
          }
        }
      }

      buffer.writeln('  </div>');
    }

    buffer.writeln('</div>');
  }

  List<_ArtifactRef> _parseArtifacts(List<String> logs) {
    final artifacts = <_ArtifactRef>[];
    for (final log in logs) {
      final separator = log.indexOf(':');
      if (separator <= 0) continue;
      final label = log.substring(0, separator).trim();
      final path = log.substring(separator + 1).trim();
      if (label.isEmpty || path.isEmpty) continue;
      if (label == 'htmlReport') continue;
      artifacts.add(_ArtifactRef(label: label, path: path));
    }
    return artifacts;
  }

  /// Prefer `screenshotFrames` / `screenshots` pointing at `*_frames.json`.
  /// Dedupes when both labels point at the same manifest.
  List<_ArtifactRef> _screenshotManifestArtifacts(
      List<_ArtifactRef> artifacts) {
    final seen = <String>{};
    final out = <_ArtifactRef>[];
    void add(String displayPath, String label) {
      final framesPath = screenshotFramesManifestDisplayPath(displayPath);
      final key = framesPath.toLowerCase();
      if (!seen.add(key)) return;
      out.add(_ArtifactRef(label: label, path: framesPath));
    }

    for (final a in artifacts) {
      if (a.label == 'screenshotFrames') {
        add(a.path, 'screenshotFrames');
      }
    }
    for (final a in artifacts) {
      if (a.label == 'screenshots') {
        add(a.path, 'screenshots');
      }
    }
    return out;
  }

  void _writeScreenshotGallery(
    StringBuffer buffer, {
    required _ArtifactRef artifact,
    required String artifactRoot,
    required String displayRoot,
  }) {
    final framesDisplayPath =
        screenshotFramesManifestDisplayPath(artifact.path);
    buffer
      ..writeln('      <div class="artifact screenshot-artifact-card">')
      ..writeln('        <div class="logs-pane-title">')
      ..writeln(
        '          <span>🖼️ Screenshots <span class="raw-label">(${_escape(artifact.label)})</span></span>',
      )
      ..writeln(
        '          <button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'screenshots\')">⛶ Open Fullscreen</button>',
      )
      ..writeln('        </div>');

    final framesFs = _filesystemPath(
      framesDisplayPath,
      artifactRoot: artifactRoot,
      displayRoot: displayRoot,
    );
    final framesDirDisplay = p.dirname(framesDisplayPath);

    if (framesFs != null && File(framesFs).existsSync()) {
      try {
        final decoded = json.decode(File(framesFs).readAsStringSync());
        if (decoded is Map && decoded['frames'] is List) {
          final frames = <Map<String, dynamic>>[];
          for (final frame in decoded['frames']) {
            if (frame is Map) {
              frames.add(Map<String, dynamic>.from(frame));
            }
          }
          if (frames.isNotEmpty) {
            _writeScreenshotFrameTiles(
              buffer,
              frames: frames,
              hrefForFrame: (frame) {
                final fileName = frame['file']?.toString() ?? '';
                if (fileName.isEmpty) return null;
                final displayPath =
                    p.join(framesDirDisplay, fileName).replaceAll('\\', '/');
                return _relativeHref(displayPath, displayRoot);
              },
            );
          } else {
            buffer.writeln(
              '        <div class="terminal-row" style="color: var(--text-muted);">No screenshot frames</div>',
            );
          }
        }
      } catch (_) {
        buffer.writeln(
          '        <div class="terminal-row" style="color: var(--text-muted);">Could not read frames manifest</div>',
        );
      }
    } else {
      // Legacy single contact-sheet PNG fallback
      final legacyPng =
          artifact.path.toLowerCase().endsWith('.png') ? artifact.path : null;
      if (legacyPng != null) {
        final fsPath = _filesystemPath(
          legacyPng,
          artifactRoot: artifactRoot,
          displayRoot: displayRoot,
        );
        if (fsPath != null && File(fsPath).existsSync()) {
          final href = _relativeHref(legacyPng, displayRoot);
          buffer.writeln(
            '        <div class="image-wrapper"><img src="${_escape(href)}" alt="screenshots"/></div>',
          );
        }
      }
    }
    buffer.writeln('      </div>');
  }

  void _writeScreenshotFrameTiles(
    StringBuffer buffer, {
    required List<Map<String, dynamic>> frames,
    required String? Function(Map<String, dynamic> frame) hrefForFrame,
  }) {
    final byDevice = <String, List<Map<String, dynamic>>>{};
    for (final frame in frames) {
      final device = frame['deviceLabel']?.toString() ??
          frame['deviceId']?.toString() ??
          '';
      byDevice.putIfAbsent(device, () => []).add(frame);
    }
    for (final entry in byDevice.entries) {
      if (entry.key.isNotEmpty && byDevice.length > 1) {
        buffer.writeln(
          '        <div class="screenshot-gallery-device">${_escape(entry.key)}</div>',
        );
      }
      buffer
        ..writeln(
            '        <div class="screenshot-gallery-container" style="padding: 16px 20px 0 20px;">')
        ..writeln('          <div class="screenshot-gallery">');
      for (final frame in entry.value) {
        final href = hrefForFrame(frame);
        if (href == null || href.isEmpty) continue;
        final label = frame['label']?.toString() ??
            frame['file']?.toString() ??
            'screenshot';
        final failed = frame['failed'] == true;
        final tileClass = failed
            ? 'screenshot-gallery-tile failed'
            : 'screenshot-gallery-tile';
        final stepMatch = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(label);
        final indexStr = stepMatch?.group(1) ?? '';
        final cleanLabel = stepMatch?.group(2) ?? label;
        buffer
          ..writeln('            <figure class="$tileClass">')
          ..writeln('              <div class="screenshot-tile-header-bar">');
        if (indexStr.isNotEmpty) {
          buffer.writeln(
              '                <span class="screenshot-index-pill">#$indexStr</span>');
        }
        buffer
          ..writeln(
              '                <span class="screenshot-tile-caption" title="${_escape(label)}">${_escape(cleanLabel)}</span>')
          ..writeln('              </div>')
          ..writeln(
              '              <div class="screenshot-gallery-frame"><img src="${_escape(href)}" alt="${_escape(label)}" loading="lazy"/></div>')
          ..writeln('            </figure>');
      }
      buffer
        ..writeln('          </div>')
        ..writeln('        </div>');
    }
  }

  String _relativeHref(String artifactDisplayPath, String displayRoot) {
    final normalized = artifactDisplayPath.replaceAll('\\', '/');
    final reportDir = p.join(displayRoot, 'report').replaceAll('\\', '/');
    return p.relative(normalized, from: reportDir).replaceAll('\\', '/');
  }

  String? _filesystemPath(
    String artifactDisplayPath, {
    required String artifactRoot,
    required String displayRoot,
  }) {
    final normalized = artifactDisplayPath.replaceAll('\\', '/');
    final display = displayRoot.replaceAll('\\', '/');
    String relative;
    if (normalized == display || normalized.startsWith('$display/')) {
      relative = p.relative(normalized, from: display);
    } else if (p.isAbsolute(normalized)) {
      return normalized;
    } else {
      relative = normalized;
    }
    return p.normalize(p.join(artifactRoot, relative));
  }

  String _anchorId(String testId) =>
      testId.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

  String _buildStepDataJson(
    EnsembleSingleTestResult test,
    String artifactRoot,
    String displayRoot,
  ) {
    final report = test.report;
    if (report == null) return '[]';

    final logs = _parseArtifacts(test.logs);
    final appLogRef = logs.firstWhere((a) => a.label == 'appLogs',
        orElse: () => _ArtifactRef(label: '', path: ''));
    final apiCallsRef = logs.firstWhere((a) => a.label == 'apiCalls',
        orElse: () => _ArtifactRef(label: '', path: ''));
    final storageRef = logs.firstWhere((a) => a.label == 'storage',
        orElse: () => _ArtifactRef(label: '', path: ''));
    final screenshotsRef = logs.firstWhere(
      (a) => a.label == 'screenshots',
      orElse: () => _ArtifactRef(label: '', path: ''),
    );

    final consoleLines = <String>[];
    if (appLogRef.path.isNotEmpty) {
      final fsPath = _filesystemPath(appLogRef.path,
          artifactRoot: artifactRoot, displayRoot: displayRoot);
      if (fsPath != null && File(fsPath).existsSync()) {
        consoleLines.addAll(File(fsPath).readAsLinesSync());
      }
    }

    final apiEvents = <Map<String, dynamic>>[];
    if (apiCallsRef.path.isNotEmpty) {
      final fsPath = _filesystemPath(apiCallsRef.path,
          artifactRoot: artifactRoot, displayRoot: displayRoot);
      if (fsPath != null && File(fsPath).existsSync()) {
        try {
          final decoded = json.decode(File(fsPath).readAsStringSync());
          if (decoded is Map && decoded['events'] is List) {
            for (final ev in decoded['events']) {
              if (ev is Map) {
                apiEvents.add(Map<String, dynamic>.from(ev));
              }
            }
          }
        } catch (_) {}
      }
    }

    final storageSteps = <Map<String, dynamic>>[];
    if (storageRef.path.isNotEmpty) {
      final fsPath = _filesystemPath(storageRef.path,
          artifactRoot: artifactRoot, displayRoot: displayRoot);
      if (fsPath != null && File(fsPath).existsSync()) {
        try {
          final decoded = json.decode(File(fsPath).readAsStringSync());
          if (decoded is Map && decoded['steps'] is List) {
            for (final step in decoded['steps']) {
              if (step is Map) {
                storageSteps.add(Map<String, dynamic>.from(step));
              }
            }
          }
        } catch (_) {}
      }
    }

    final screenshotFrames = <Map<String, dynamic>>[];
    String? framesManifestDisplay;
    final screenshotFramesRef = logs.firstWhere(
      (a) => a.label == 'screenshotFrames',
      orElse: () => _ArtifactRef(label: '', path: ''),
    );
    if (screenshotFramesRef.path.isNotEmpty) {
      framesManifestDisplay = screenshotFramesRef.path;
    } else if (screenshotsRef.path.isNotEmpty) {
      framesManifestDisplay =
          screenshotFramesManifestDisplayPath(screenshotsRef.path);
    }
    if (framesManifestDisplay != null && framesManifestDisplay.isNotEmpty) {
      final fsPath = _filesystemPath(
        framesManifestDisplay,
        artifactRoot: artifactRoot,
        displayRoot: displayRoot,
      );
      if (fsPath != null && File(fsPath).existsSync()) {
        try {
          final decoded = json.decode(File(fsPath).readAsStringSync());
          if (decoded is Map && decoded['frames'] is List) {
            final sheetDir = p.dirname(framesManifestDisplay);
            for (final frame in decoded['frames']) {
              if (frame is! Map) continue;
              final entry = Map<String, dynamic>.from(frame);
              final fileName = entry['file']?.toString();
              if (fileName != null && fileName.isNotEmpty) {
                final displayPath =
                    p.join(sheetDir, fileName).replaceAll('\\', '/');
                entry['href'] = _relativeHref(displayPath, displayRoot);
              }
              screenshotFrames.add(entry);
            }
          }
        } catch (_) {}
      }
    }

    final grouped = groupLogsByStep(
      stepsOutline: report.stepsOutline,
      stepDurationsMs: report.stepDurationsMs,
      stepStartTimes: report.stepStartTimes,
      apiEvents: apiEvents,
      rawConsoleLines: consoleLines,
      storageSteps: storageSteps,
      screenshotFrames: screenshotFrames,
    );

    return json.encode(grouped);
  }

  String _buildStepModalHtmlAndScript() {
    return '''
<div id="step-modal-overlay" class="modal-overlay" style="display: none;" onclick="closeStepDialog(event)">
  <button class="modal-nav-btn prev" onclick="navigateStep(-1, event)">&#10094;</button>
  <div class="modal-card" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-header-left">
        <span class="modal-badge">STEP DETAILS</span>
        <h3 id="modal-step-title"></h3>
      </div>
      <button class="modal-close-btn" onclick="closeStepDialog(event)">&times;</button>
    </div>
    <div class="modal-body">
      <div class="modal-tabs">
        <button class="modal-tab-btn active" data-tab="api" onclick="switchModalTab('api')">🌐 API Calls (<span id="modal-api-count">0</span>)</button>
        <button class="modal-tab-btn" data-tab="logs" onclick="switchModalTab('logs')">📝 Console Logs (<span id="modal-logs-count">0</span>)</button>
        <button class="modal-tab-btn" data-tab="storage" onclick="switchModalTab('storage')">💾 Storage (<span id="modal-storage-count">0</span>)</button>
        <button class="modal-tab-btn" data-tab="screenshots" onclick="switchModalTab('screenshots')">🖼️ Screenshots (<span id="modal-screenshots-count">0</span>)</button>
      </div>
      <div class="modal-tab-content" id="modal-tab-api">
        <div id="modal-api-list" class="modal-list"></div>
      </div>
      <div class="modal-tab-content" id="modal-tab-logs" style="display: none;">
        <div id="modal-logs-list" class="modal-list logs-terminal"></div>
      </div>
      <div class="modal-tab-content" id="modal-tab-storage" style="display: none;">
        <div id="modal-storage-list" class="modal-list logs-terminal"></div>
      </div>
      <div class="modal-tab-content" id="modal-tab-screenshots" style="display: none;">
        <div id="modal-screenshots-list" class="modal-list modal-screenshots-grid"></div>
      </div>
    </div>
  </div>
  <button class="modal-nav-btn next" onclick="navigateStep(1, event)">&#10095;</button>
</div>

<div id="fullscreen-card-overlay" class="modal-overlay" style="display: none;" onclick="closeFullscreenCard(event)">
  <div class="fullscreen-card-modal" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-header-left">
        <span id="fullscreen-card-badge" class="modal-badge">CARD DETAILS</span>
        <h3 id="fullscreen-card-title"></h3>
      </div>
      <button class="modal-close-btn" onclick="closeFullscreenCard(event)">&times;</button>
    </div>
    <div class="modal-body" style="padding: 0; overflow: hidden; display: flex; flex-direction: column;">
      <div id="fullscreen-card-content" class="fullscreen-card-content-area"></div>
    </div>
  </div>
</div>

<script>
  let activeModalTab = 'api';
  let currentModalCardId = '';
  let currentModalStepIndex = -1;

  function getStorageStateAtStep(cardId, targetStepIndex) {
    const deviceData = window.stepData && window.stepData[cardId];
    if (!deviceData) return {};
    const stepKeys = Object.keys(deviceData).map(k => parseInt(k)).sort((a, b) => a - b);
    const state = {};
    for (const stepKey of stepKeys) {
      if (stepKey > targetStepIndex) break;
      const stepObj = deviceData[stepKey];
      const changes = stepObj.storageChanges || [];
      for (const change of changes) {
        const key = change.key;
        if (!key) continue;
        const kind = (change.change || '').toLowerCase();
        if (kind === 'removed') {
          delete state[key];
        } else if (kind === 'added' || kind === 'modified') {
          state[key] = change.after;
        }
      }
    }
    return state;
  }

  function openStepDialog(cardId, stepIndex) {
    currentModalCardId = cardId;
    currentModalStepIndex = parseInt(stepIndex);

    const data = window.stepData && window.stepData[cardId] && window.stepData[cardId][stepIndex];
    if (!data) return;

    const deviceData = window.stepData && window.stepData[cardId];
    if (deviceData) {
      const stepKeys = Object.keys(deviceData).map(k => parseInt(k)).sort((a, b) => a - b);
      const pos = stepKeys.indexOf(currentModalStepIndex);
      const prevBtn = document.querySelector('.modal-nav-btn.prev');
      const nextBtn = document.querySelector('.modal-nav-btn.next');
      if (prevBtn) prevBtn.style.visibility = (pos > 0) ? 'visible' : 'hidden';
      if (nextBtn) nextBtn.style.visibility = (pos < stepKeys.length - 1) ? 'visible' : 'hidden';
    }

    const titleText = (data.stepText || '').trim();
    document.getElementById('modal-step-title').textContent = titleText;
    
    // API list populator
    const apiList = document.getElementById('modal-api-list');
    apiList.innerHTML = '';
    const apiCalls = data.apiCalls || [];
    document.getElementById('modal-api-count').textContent = apiCalls.length;
    
    if (apiCalls.length === 0) {
      apiList.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no API requests recorded for this step&gt;</div>';
    } else {
      apiCalls.forEach(ev => {
        const name = ev.name || 'API';
        const statusCode = ev.statusCode;
        const mocked = ev.mocked === true;
        const timestamp = ev.timestamp || '';
        let timePart = '';
        const timeMatch = /T(\\d{2}:\\d{2}:\\d{2})/.exec(timestamp);
        if (timeMatch) {
          timePart = '[' + timeMatch[1] + '] ';
        }
        
        const isSuccess = statusCode != null ? (statusCode >= 200 && statusCode < 300) : (ev.error == null && ev.failed !== true && ev.exception == null);
        const displayStatus = statusCode != null ? statusCode : (isSuccess ? '200' : 'ERROR');
        
        const badgeClass = mocked ? 'info' : (isSuccess ? 'passed' : 'failed');
        let badgeText = 'API';
        if (mocked) {
          badgeText = 'MOCK';
        } else {
          const type = (ev.type || '').toLowerCase();
          if (type === 'firestore') {
            badgeText = 'FIRESTORE';
          } else if (type === 'functions') {
            badgeText = 'FUNC';
          }
        }
        
        const statusColor = isSuccess ? 'var(--pass)' : 'var(--fail)';
        
        let prettyResponse = '';
        if (ev.responseBody) {
          try {
            prettyResponse = typeof ev.responseBody === 'string'
              ? JSON.stringify(JSON.parse(ev.responseBody), null, 2)
              : JSON.stringify(ev.responseBody, null, 2);
          } catch (e) {
            prettyResponse = String(ev.responseBody);
          }
        }
        
        const request = ev.request || {};
        const method = request.method || 'GET';
        const url = request.url || '';
        const errorMsg = ev.error || '';
        
        let requestDetailsHtml = '';
        if (request.headers && Object.keys(request.headers).length > 0) {
          requestDetailsHtml += `<div style="margin-top: 8px;"><div class="api-detail-sublabel">Headers</div><pre class="api-detail-pre">\${escapeHtml(JSON.stringify(request.headers, null, 2))}</pre></div>`;
        }
        if (request.parameters && Object.keys(request.parameters).length > 0) {
          requestDetailsHtml += `<div style="margin-top: 8px;"><div class="api-detail-sublabel">Parameters / Query</div><pre class="api-detail-pre">\${escapeHtml(JSON.stringify(request.parameters, null, 2))}</pre></div>`;
        }
        if (request.body && (typeof request.body === 'object' ? Object.keys(request.body).length > 0 : String(request.body).length > 0)) {
          const bodyStr = typeof request.body === 'object' ? JSON.stringify(request.body, null, 2) : String(request.body);
          requestDetailsHtml += `<div style="margin-top: 8px;"><div class="api-detail-sublabel">Body / Data</div><pre class="api-detail-pre">\${escapeHtml(bodyStr)}</pre></div>`;
        }
        
        const container = document.createElement('div');
        container.className = 'api-event-container';
        
        let errorHtml = errorMsg ? `<div class="api-detail-section"><div class="api-detail-label" style="color: var(--fail);">Error</div><div style="color: var(--fail); font-weight: 700;">\${escapeHtml(errorMsg)}</div></div>` : '';
        let responseHtml = prettyResponse ? `<div class="api-detail-section"><div class="api-detail-label">Response Body</div><pre class="api-detail-pre">\${escapeHtml(prettyResponse)}</pre></div>` : '';
        let requestHtml = url ? `<div class="api-detail-section"><div class="api-detail-label">Request</div><div class="api-detail-url"><span style="color: var(--accent); font-weight: 700; margin-right: 6px;">\${escapeHtml(method)}</span>\${escapeHtml(url)}</div>\${requestDetailsHtml}</div>` : '';
        
        container.innerHTML = `
          <div class="api-event-header" onclick="toggleApiDetails(this)">
            <div class="api-event-header-left">
              <span class="api-caret">▶</span>
              <span class="terminal-timestamp">\${escapeHtml(timePart)}</span>
              <span class="terminal-badge \${badgeClass}">\${badgeText}</span>
              <span style="font-weight: 700; color: #fff;">\${escapeHtml(name)}</span>
            </div>
            <span style="color: \${statusColor}; font-weight: 700;">\${displayStatus}</span>
          </div>
          <div class="api-event-details">
            \${requestHtml}
            \${errorHtml}
            \${responseHtml}
          </div>
        `;
        apiList.appendChild(container);
      });
    }
    
    // Logs list populator
    const logsList = document.getElementById('modal-logs-list');
    logsList.innerHTML = '';
    const appLogs = data.appLogs || [];
    document.getElementById('modal-logs-count').textContent = appLogs.length;
    
    if (appLogs.length === 0) {
      logsList.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no console output for this step&gt;</div>';
    } else {
      appLogs.forEach(line => {
        let logBody = line;
        let timePart = '';
        if (line.startsWith('[')) {
          const closeBrace = line.indexOf(']');
          if (closeBrace !== -1) {
            const tStr = line.substring(1, closeBrace);
            logBody = line.substring(closeBrace + 1).trim();
            const timeMatch = /T(\\d{2}:\\d{2}:\\d{2})/.exec(tStr);
            if (timeMatch) {
              timePart = '[' + timeMatch[1] + '] ';
            }
          }
        }
        
        const row = document.createElement('div');
        row.className = 'terminal-row';
        
        if (logBody.startsWith('SCREEN TRACKER:')) {
          const text = logBody.replace('SCREEN TRACKER:', '').trim();
          row.innerHTML = `<span class="terminal-timestamp">\${escapeHtml(timePart)}</span><span class="terminal-badge info">SCREEN</span> <span style="color: var(--accent); font-weight: 700;">\${escapeHtml(text)}</span>`;
        } else if (logBody.toLowerCase().includes('error') || logBody.toLowerCase().includes('exception')) {
          row.innerHTML = `<span class="terminal-timestamp">\${escapeHtml(timePart)}</span><span class="terminal-badge failed">ERROR</span> <span style="color: var(--fail);">\${escapeHtml(logBody)}</span>`;
        } else {
          row.innerHTML = `<span class="terminal-timestamp">\${escapeHtml(timePart)}</span>\${escapeHtml(logBody)}`;
        }
        logsList.appendChild(row);
      });
    }

    // Storage changes populator
    const storageList = document.getElementById('modal-storage-list');
    storageList.innerHTML = '';
    const storageChanges = data.storageChanges || [];
    document.getElementById('modal-storage-count').textContent = storageChanges.length;

    const currentState = getStorageStateAtStep(cardId, stepIndex);
    const changedKeys = new Set(storageChanges.map(c => c.key).filter(Boolean));

    if (storageChanges.length === 0 && Object.keys(currentState).length === 0) {
      storageList.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no storage changes for this step&gt;</div>';
    } else {
      storageChanges.forEach(change => {
        const key = change.key || '(unknown)';
        const kind = (change.change || '').toLowerCase();
        let badgeClass = 'info';
        let badgeText = 'MOD';
        let valueColor = 'var(--accent)';
        let detail = '';

        if (kind === 'added') {
          badgeClass = 'passed';
          badgeText = 'ADD';
          valueColor = 'var(--pass)';
          detail = formatStorageValue(change.after);
        } else if (kind === 'removed') {
          badgeClass = 'failed';
          badgeText = 'DEL';
          valueColor = 'var(--fail)';
          detail = formatStorageValue(change.before);
        } else {
          badgeClass = 'info';
          badgeText = 'MOD';
          valueColor = 'var(--accent)';
          detail = formatStorageValue(change.before) + ' → ' + formatStorageValue(change.after);
        }

        const row = document.createElement('div');
        row.className = 'terminal-row';
        row.innerHTML = `<span class="terminal-badge \${badgeClass}">\${badgeText}</span><span style="font-weight: 700; color: #fff;">\${escapeHtml(key)}</span> <span style="color: \${valueColor};">\${escapeHtml(detail)}</span>`;
        storageList.appendChild(row);
      });
    }

    // Unchanged storage keys populator
    const unchangedKeys = Object.keys(currentState).filter(k => !changedKeys.has(k)).sort();
    if (unchangedKeys.length > 0) {
      unchangedKeys.forEach(key => {
        const val = currentState[key];
        const detail = formatStorageValue(val);
        const row = document.createElement('div');
        row.className = 'terminal-row';
        row.innerHTML = `<span class="terminal-badge info" style="background: rgba(255, 255, 255, 0.06); color: var(--text-muted); border: 1px solid rgba(255, 255, 255, 0.15); margin-right: 6px;">VAL</span><span style="font-weight: 700; color: var(--text-muted);">\${escapeHtml(key)}</span> <span style="color: #cbd5e1;">\${escapeHtml(detail)}</span>`;
        storageList.appendChild(row);
      });
    }

    // Screenshots populator
    const shotsList = document.getElementById('modal-screenshots-list');
    shotsList.innerHTML = '';
    const screenshots = data.screenshots || [];
    document.getElementById('modal-screenshots-count').textContent = screenshots.length;

    if (screenshots.length === 0) {
      shotsList.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no screenshot for this step&gt;</div>';
    } else if (screenshots.length === 1) {
      const shot = screenshots[0];
      const href = shot.href || '';
      const rawLabel = shot.label || shot.file || 'Screenshot';
      const container = document.createElement('div');
      container.className = 'single-screenshot-container';
      const card = document.createElement('div');
      card.className = 'modal-screenshot-card single-layout';
      if (href) {
        // No caption under a single shot — the modal title already names the step.
        card.innerHTML = `<a href="\${escapeHtml(href)}" target="_blank" rel="noopener"><img src="\${escapeHtml(href)}" alt="\${escapeHtml(rawLabel)}" loading="lazy"/></a>`;
      } else {
        card.innerHTML = `<div class="terminal-row" style="color: var(--text-muted);">\${escapeHtml(rawLabel)}</div>`;
      }
      container.appendChild(card);
      shotsList.appendChild(container);
    } else {
      screenshots.forEach((shot, index) => {
        const href = shot.href || '';
        const rawLabel = shot.label || shot.file || 'Screenshot';
        let cleanLabel = getCleanScreenshotLabel(rawLabel, titleText);
        if (!cleanLabel) {
          cleanLabel = 'Screenshot ' + (index + 1);
        }
        const card = document.createElement('div');
        card.className = 'modal-screenshot-card';
        if (href) {
          card.innerHTML = `<a href="\${escapeHtml(href)}" target="_blank" rel="noopener"><img src="\${escapeHtml(href)}" alt="\${escapeHtml(rawLabel)}" loading="lazy"/></a><div class="modal-screenshot-label">\${escapeHtml(cleanLabel)}</div>`;
        } else {
          card.innerHTML = `<div class="terminal-row" style="color: var(--text-muted);">\${escapeHtml(rawLabel)}</div>`;
        }
        shotsList.appendChild(card);
      });
    }
    
    // Retain selected tab
    switchModalTab(activeModalTab);
    
    // Show overlay
    document.getElementById('step-modal-overlay').style.display = 'flex';
  }
  
  function toggleApiDetails(headerEl) {
    const parent = headerEl.parentElement;
    const details = parent.querySelector('.api-event-details');
    const caret = headerEl.querySelector('.api-caret');
    if (!details) return;
    
    const isExpanded = details.style.display === 'block';
    details.style.display = isExpanded ? 'none' : 'block';
    caret.style.transform = isExpanded ? 'rotate(0deg)' : 'rotate(90deg)';
  }

  function openFullscreenCard(btnEl, type) {
    const cardEl = btnEl.closest('.logs-card-pane') || btnEl.closest('.screenshot-artifact-card');
    if (!cardEl) return;
    
    const titleEl = cardEl.querySelector('.logs-pane-title span');
    let titleText = titleEl ? titleEl.textContent : 'Fullscreen View';
    
    const badgeText = type.toUpperCase();
    titleText = titleText.replace(/📝|🌐|💾|🖼️/g, '').trim();
    const rawLabelIdx = titleText.indexOf('(');
    if (rawLabelIdx !== -1) {
      titleText = titleText.substring(0, rawLabelIdx).trim();
    }
    
    document.getElementById('fullscreen-card-badge').textContent = badgeText;
    document.getElementById('fullscreen-card-title').textContent = titleText;
    
    const contentArea = document.getElementById('fullscreen-card-content');
    contentArea.innerHTML = '';
    contentArea.className = 'fullscreen-card-content-area';
    
    if (type === 'screenshots') {
      contentArea.classList.add('grid-layout');
      const galleries = cardEl.querySelectorAll('.screenshot-gallery');
      galleries.forEach(gallery => {
        gallery.querySelectorAll('.screenshot-gallery-tile').forEach(tile => {
          const imgEl = tile.querySelector('img');
          if (!imgEl) return;
          const indexEl = tile.querySelector('.screenshot-index-pill');
          const capEl = tile.querySelector('.screenshot-tile-caption');
          
          const indexStr = indexEl ? indexEl.textContent : '';
          const captionStr = capEl ? capEl.textContent : '';
          const fullTitle = capEl ? (capEl.getAttribute('title') || captionStr) : imgEl.alt;
          
          const newTile = document.createElement('div');
          newTile.className = 'screenshot-gallery-tile';
          
          let badgeHtml = indexStr ? `<span class="screenshot-index-pill">\${escapeHtml(indexStr)}</span>` : '';
          
          newTile.innerHTML = `
            <div class="screenshot-tile-header-bar">
              \${badgeHtml}
              <span class="screenshot-tile-caption" title="\${escapeHtml(fullTitle)}">\${escapeHtml(captionStr)}</span>
            </div>
            <div class="screenshot-gallery-frame">
              <a href="\${escapeHtml(imgEl.src)}" target="_blank" rel="noopener" style="width: 100%; display: block;">
                <img src="\${escapeHtml(imgEl.src)}" alt="\${escapeHtml(imgEl.alt)}" style="width: 100%; height: auto; display: block;" />
              </a>
            </div>
          `;
          contentArea.appendChild(newTile);
        });
      });
    } else {
      const terminal = cardEl.querySelector('.logs-terminal');
      if (terminal) {
        contentArea.innerHTML = terminal.innerHTML;
        contentArea.classList.add('logs-terminal');
        contentArea.style.padding = '24px';
        contentArea.style.maxHeight = 'none';
      }
    }
    
    document.getElementById('fullscreen-card-overlay').style.display = 'flex';
  }
  
  function closeFullscreenCard(event) {
    document.getElementById('fullscreen-card-overlay').style.display = 'none';
  }

  function closeStepDialog(event) {
    if (event) {
      if (event.target.id !== 'step-modal-overlay' && !event.target.classList.contains('modal-close-btn')) {
        return;
      }
    }
    document.getElementById('step-modal-overlay').style.display = 'none';
    // Reset activeModalTab to api when completely closing the modal dialog
    activeModalTab = 'api';
  }
  
  function navigateStep(direction, event) {
    if (event) event.stopPropagation();
    const nextIndex = currentModalStepIndex + direction;
    const deviceData = window.stepData && window.stepData[currentModalCardId];
    if (!deviceData) return;
    const stepKeys = Object.keys(deviceData).map(k => parseInt(k)).sort((a, b) => a - b);
    if (stepKeys.length === 0) return;
    
    const currentPos = stepKeys.indexOf(currentModalStepIndex);
    let nextPos = currentPos + direction;
    if (nextPos < 0 || nextPos >= stepKeys.length) return;
    
    const nextStepIndex = stepKeys[nextPos];
    openStepDialog(currentModalCardId, nextStepIndex);
  }
  
  function switchModalTab(tab) {
    activeModalTab = tab;
    document.querySelectorAll('.modal-tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.getAttribute('data-tab') === tab);
    });
    document.querySelectorAll('.modal-tab-content').forEach(content => {
      content.style.display = 'none';
    });
    const pane = document.getElementById('modal-tab-' + tab);
    if (pane) pane.style.display = 'flex';
  }

  function formatStorageValue(value) {
    if (value === undefined || value === null) return 'null';
    let text;
    if (typeof value === 'string') {
      text = value;
    } else {
      try {
        text = JSON.stringify(value);
      } catch (e) {
        text = String(value);
      }
    }
    if (text.length > 120) {
      return text.substring(0, 117) + '...';
    }
    return text;
  }
  
  function getCleanScreenshotLabel(label, titleText) {
    let clean = label.replace(/^\d+\.\s*/, '').trim();
    if (clean.toLowerCase() === titleText.toLowerCase()) {
      return '';
    }
    if (clean.toLowerCase().startsWith(titleText.toLowerCase())) {
      let suffix = clean.substring(titleText.length).trim();
      suffix = suffix.replace(/^[(\-\s]+|[)\-\s]+\$/g, '').trim();
      if (suffix) {
        return suffix;
      }
    }
    return clean;
  }

  function escapeHtml(str) {
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }
</script>
''';
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  String _formatStepText(String text) {
    final escaped = _escape(text);
    final parenIndex = escaped.indexOf('(');
    if (parenIndex == -1) {
      return '<span class="step-action">$escaped</span>';
    }
    final action = escaped.substring(0, parenIndex);
    final args = escaped.substring(parenIndex);
    return '<span class="step-action">$action</span><span class="step-args">$args</span>';
  }

  String _formatDuration(int durationMs) {
    if (durationMs < 1000) return '${durationMs}ms';
    final seconds = durationMs / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = durationMs ~/ 60000;
    final remainingSeconds = (durationMs % 60000) / 1000;
    return '${minutes}m ${remainingSeconds.toStringAsFixed(1)}s';
  }

  String _baseId(String testId) {
    final match = RegExp(r'^(.*?)\[(.*?)\]').firstMatch(testId);
    if (match != null) {
      return match.group(1)!.trim();
    }
    final pathMatch = RegExp(r'^(.*?)\s*\(').firstMatch(testId);
    if (pathMatch != null) {
      return pathMatch.group(1)!.trim();
    }
    return testId.trim();
  }

  String _deviceBadgeOf(String testId) {
    final match = RegExp(r'\[(.*?)\]').firstMatch(testId);
    return match?.group(1)?.trim() ?? '';
  }

  String _filePathOf(String testId) {
    final match = RegExp(r'\((.*?)\)').firstMatch(testId);
    return match?.group(1)?.trim() ?? '';
  }

  String _deviceButtonText(String deviceBadge) {
    if (deviceBadge.isEmpty) return 'Default Run';
    final isAndroid = deviceBadge.toLowerCase().contains('android') ||
        deviceBadge.toLowerCase().contains('samsung') ||
        deviceBadge.toLowerCase().contains('pixel');
    final isIos = deviceBadge.toLowerCase().contains('ios') ||
        deviceBadge.toLowerCase().contains('iphone');
    final hasNl = deviceBadge.toLowerCase().contains('nl');
    final osName = isAndroid ? 'Android' : (isIos ? 'iOS' : 'Device');
    final flagStr = hasNl ? ' 🇳🇱 NL' : ' 🇬🇧 EN';
    return '$osName · ${deviceBadge.toUpperCase()}$flagStr';
  }

  String _css() => '''
:root {
  --bg: #030712;
  --card: rgba(17, 24, 39, 0.45);
  --text: #f9fafb;
  --text-muted: #9ca3af;
  --pass: #10b981;
  --pass-bg: rgba(16, 185, 129, 0.12);
  --fail: #f43f5e;
  --fail-bg: rgba(244, 63, 94, 0.12);
  --accent: #06b6d4;
  --border: rgba(255, 255, 255, 0.05);
  --code: #090d16;
  --font-ui: 'Plus Jakarta Sans', sans-serif;
  --font-code: 'JetBrains Mono', monospace;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  font-family: var(--font-ui);
  color: var(--text);
  background-color: var(--bg);
  line-height: 1.6;
  padding-bottom: 80px;
  position: relative;
  overflow-x: hidden;
  height: 100vh;
  display: flex;
  flex-direction: column;
}

/* Cyber Blueprint Grid Pattern overlay */
.grid-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background-image: 
    linear-gradient(var(--border) 1px, transparent 1px),
    linear-gradient(90deg, var(--border) 1px, transparent 1px);
  background-size: 24px 24px;
  pointer-events: none;
  z-index: -1;
  opacity: 0.35;
}

.hero, .dashboard, .controls, .suite-artifacts-container {
  max-width: 1600px;
  margin: 0 auto;
  padding: 16px 24px;
  width: 100%;
}

.hero {
  padding-top: 24px;
  padding-bottom: 8px;
}
.hero-header h1 {
  margin: 0;
  font-size: 2.2rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  background: linear-gradient(135deg, #ffffff 30%, #a1a1aa 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.summary {
  margin: 4px 0 0 0;
  font-weight: 600;
  font-size: 1rem;
  color: var(--accent);
}
.summary.passed { color: var(--pass); }
.summary.failed { color: var(--fail); }

/* Dashboard Metrics Grid */
.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
  margin-bottom: 8px;
}
.metric-card {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 16px;
  backdrop-filter: blur(12px);
  transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
}
.metric-card:hover {
  transform: translateY(-2px);
  border-color: rgba(255, 255, 255, 0.1);
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.5);
}
.metric-val {
  font-size: 1.8rem;
  font-weight: 800;
  line-height: 1.1;
  letter-spacing: -0.02em;
}
.metric-label {
  font-size: 0.7rem;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.1em;
  margin-top: 4px;
  font-weight: 700;
}
.metric-passed .metric-val { color: var(--pass); }
.metric-failed .metric-val { color: var(--fail); }
.metric-rate .metric-val { color: var(--accent); }

/* Controls bar */
.controls-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  background: rgba(17, 24, 39, 0.8);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 10px 16px;
  backdrop-filter: blur(20px);
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.3);
}
.search-wrapper {
  flex: 1;
  min-width: 280px;
}
#search-input {
  width: 100%;
  background: rgba(0, 0, 0, 0.45);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 8px 14px;
  color: #fff;
  font-size: 0.9rem;
  outline: none;
  font-family: var(--font-ui);
  transition: all 0.25s ease;
}
#search-input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px rgba(6, 182, 212, 0.15);
}
.filter-tabs {
  display: flex;
  gap: 6px;
}
.filter-btn {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: var(--text-muted);
  padding: 8px 16px;
  font-size: 0.85rem;
  font-weight: 700;
  cursor: pointer;
  font-family: var(--font-ui);
  transition: all 0.2s ease;
}
.filter-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #fff;
}
.filter-btn.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #000;
}

/* Collapsible Suite Artifacts */
.suite-artifacts-container {
  margin-top: 4px;
  margin-bottom: 4px;
}
.suite-artifacts-card {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 12px 16px;
  backdrop-filter: blur(12px);
}
.suite-artifacts-card summary {
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--accent);
  cursor: pointer;
  outline: none;
  user-select: none;
}
.suite-artifacts-content {
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid var(--border);
}
.suite-artifacts-content ul {
  list-style: none;
  padding: 0;
  margin: 0;
}
.suite-artifacts-content li {
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 12px;
  margin-bottom: 8px;
}
.suite-artifacts-content li:last-child {
  margin-bottom: 0;
}
.suite-artifacts-content .label {
  font-weight: 700;
  color: var(--accent);
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.artifact-item-header a {
  font-family: var(--font-code);
  font-size: 0.8rem;
}

/* Master-Detail Split Screen Layout */
.dashboard-container {
  display: flex;
  max-width: 1600px;
  margin: 0 auto;
  gap: 24px;
  padding: 0 24px 24px 24px;
  flex: 1;
  min-height: 0;
  width: 100%;
}

/* Left Sidebar Pane */
.test-list-pane {
  width: 400px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  gap: 10px;
  overflow-y: auto;
  padding-right: 8px;
}

/* Right Detail Pane */
.test-detail-pane {
  flex: 1;
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 28px;
  backdrop-filter: blur(12px);
  overflow-y: auto;
}

/* Compact Test Card (Left sidebar) */
.test {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 14px 16px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 12px;
  transition: all 0.2s ease;
  user-select: none;
}
.test.passed {
  border-left: 4px solid var(--pass);
}
.test.failed {
  border-left: 4px solid var(--fail);
}
.test:hover {
  border-color: rgba(255, 255, 255, 0.1);
  background: rgba(255, 255, 255, 0.02);
}
.test.active {
  background: rgba(6, 182, 212, 0.08);
  border-color: var(--accent);
  box-shadow: 0 0 12px rgba(6, 182, 212, 0.25);
}
.card-status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.passed .card-status-dot {
  background: var(--pass);
  box-shadow: 0 0 6px var(--pass);
}
.failed .card-status-dot {
  background: var(--fail);
  box-shadow: 0 0 6px var(--fail);
}
.card-info {
  flex: 1;
  min-width: 0;
}
.card-title {
  font-weight: 700;
  font-size: 0.9rem;
  color: #fff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.card-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 4px;
  font-size: 0.75rem;
  color: var(--text-muted);
  flex-wrap: wrap;
}
.card-duration {
  font-family: var(--font-code);
  font-size: 0.7rem;
}
.card-device-badge {
  background: rgba(6, 182, 212, 0.12);
  border: 1px solid rgba(6, 182, 212, 0.3);
  color: var(--accent);
  padding: 1px 5px;
  border-radius: 4px;
  font-weight: 800;
  font-size: 0.6rem;
  text-transform: uppercase;
}

/* Device Selector Bar */
.device-selector-bar {
  display: flex;
  align-items: center;
  gap: 12px;
  background: rgba(15, 23, 42, 0.9);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 12px 16px;
  margin-bottom: 24px;
  position: sticky;
  top: -28px;
  z-index: 100;
  backdrop-filter: blur(12px);
}
.selector-label {
  font-size: 0.75rem;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--text-muted);
  letter-spacing: 0.05em;
}
.device-tabs {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.device-tab-btn {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: var(--text-muted);
  padding: 6px 14px;
  font-size: 0.8rem;
  font-weight: 700;
  cursor: pointer;
  font-family: var(--font-ui);
  transition: all 0.2s ease;
}
.device-tab-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #fff;
}
.device-tab-btn.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #000;
}

/* Detail Placeholder */
.detail-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--text-muted);
  text-align: center;
  padding: 40px;
}
.placeholder-icon {
  font-size: 3.5rem;
  margin-bottom: 16px;
}
.detail-placeholder h3 {
  margin: 0 0 8px 0;
  font-size: 1.3rem;
  color: #fff;
}
.detail-placeholder p {
  margin: 0;
  font-size: 0.9rem;
  max-width: 320px;
}

/* Detail Inspector Content */
.test-detail-content {
  animation: fadeIn 0.2s ease-out;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(4px); }
  to { opacity: 1; transform: translateY(0); }
}

.test-card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 16px;
}
.title-section {
  flex: 1;
}
.test-card-header h2 {
  margin: 0;
  font-size: 1.6rem;
  font-weight: 800;
  display: flex;
  align-items: center;
  gap: 12px;
  letter-spacing: -0.02em;
}
.test-card-header .icon {
  font-size: 1.4rem;
}

/* Status capsule */
.status-capsule {
  padding: 6px 16px;
  border-radius: 30px;
  font-size: 0.8rem;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
.status-capsule.passed {
  background: var(--pass-bg);
  border: 1px solid var(--pass);
  color: var(--pass);
}
.status-capsule.failed {
  background: var(--fail-bg);
  border: 1px solid var(--fail);
  color: var(--fail);
}

/* Platform Device Pill Badge */
.device-pill {
  display: inline-flex;
  align-items: center;
  padding: 4px 12px;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 800;
  margin-top: 8px;
}
.device-pill.android {
  background: rgba(61, 220, 132, 0.1);
  border: 1px solid rgba(61, 220, 132, 0.3);
  color: #3ddc84;
}
.device-pill.ios {
  background: rgba(56, 189, 248, 0.1);
  border: 1px solid rgba(56, 189, 248, 0.3);
  color: #38bdf8;
}
.device-pill.default {
  background: rgba(6, 182, 212, 0.1);
  border: 1px solid rgba(6, 182, 212, 0.3);
  color: var(--accent);
}

.file-path-sub {
  font-size: 0.85rem;
  color: var(--text-muted);
  margin: 6px 0 0 0;
}
.file-path-sub span {
  font-weight: 700;
  color: var(--accent);
}

.meta {
  color: var(--text-muted);
  font-size: 0.85rem;
  margin: 12px 0 20px 0;
  font-family: var(--font-code);
}

/* Horizontal Timeline Dashboard Rail */
.meta-dashboard-rail {
  display: flex;
  gap: 24px;
  background: rgba(0, 0, 0, 0.2);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 16px 20px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}
.rail-item {
  flex: 1;
  min-width: 140px;
}
.rail-label {
  font-size: 0.7rem;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--text-muted);
  letter-spacing: 0.05em;
}
.rail-val {
  font-size: 0.95rem;
  font-weight: 600;
  margin-top: 4px;
}
.rail-val.highlight {
  color: var(--accent);
}

/* Screens Flow Timeline Journey */
.flow-timeline {
  background: rgba(0, 0, 0, 0.2);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 16px 20px;
  margin-bottom: 20px;
}
.flow-label {
  font-size: 0.7rem;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--text-muted);
  letter-spacing: 0.05em;
  margin-bottom: 8px;
}
.flow-track {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px 12px;
  font-size: 0.9rem;
}
.flow-node {
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 4px 10px;
  font-weight: 700;
  color: #fff;
}
.flow-arrow {
  color: var(--accent);
  font-weight: 800;
}

/* Timeline steps */
.timeline-steps-container {
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 24px;
  margin-bottom: 24px;
}
.timeline-header {
  font-size: 0.8rem;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--text-muted);
  letter-spacing: 0.08em;
  margin-bottom: 18px;
}
.timeline-steps-track {
  display: flex;
  flex-direction: column;
  position: relative;
  padding-left: 20px;
}
.timeline-steps-track::before {
  content: '';
  position: absolute;
  top: 8px;
  bottom: 8px;
  left: 5px;
  width: 2px;
  background: var(--border);
}
.timeline-step-row {
  display: flex;
  position: relative;
  padding: 10px 12px;
  margin-bottom: 8px;
  align-items: flex-start;
  border-radius: 8px;
  transition: background 0.2s ease, border 0.2s ease;
  border: 1px solid transparent;
}
.timeline-step-row:hover {
  background: rgba(255, 255, 255, 0.02);
}
.timeline-step-row.failed-step {
  background: rgba(244, 63, 94, 0.03);
  border: 1px solid rgba(244, 63, 94, 0.15);
  box-shadow: 0 0 10px rgba(244, 63, 94, 0.05);
}
.timeline-step-row:last-child {
  margin-bottom: 0;
}
.timeline-marker {
  position: absolute;
  left: -20px;
  top: 14px;
  width: 12px;
  height: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.marker-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--pass);
  box-shadow: 0 0 6px var(--pass);
}
.failed-step .marker-dot {
  background: var(--fail);
  box-shadow: 0 0 8px var(--fail);
  animation: pulse 1.5s infinite;
}
@keyframes pulse {
  0% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.3); opacity: 0.6; }
  100% { transform: scale(1); opacity: 1; }
}
.step-outline-body {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
  min-width: 0;
}
.step-outline-top-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  width: 100%;
}
.step-outline-text {
  font-family: var(--font-code);
  font-size: 0.88rem;
  color: #e2e8f0;
  padding-left: 8px;
}
.step-outline-text .step-action {
  color: var(--accent);
  font-weight: 700;
}
.step-outline-text .step-args {
  color: #94a3b8;
  font-weight: 400;
}
.failed-step .step-outline-text .step-action {
  color: var(--fail);
}
.step-duration {
  flex-shrink: 0;
  font-family: var(--font-code);
  font-size: 0.75rem;
  font-weight: 600;
  border-radius: 999px;
  padding: 2px 8px;
  background: rgba(255, 255, 255, 0.03);
}
.step-duration.fast {
  color: var(--text-muted, #9ca3af);
  border: 1px solid rgba(255, 255, 255, 0.08);
}
.step-duration.normal {
  color: var(--accent);
  border: 1px solid rgba(6, 182, 212, 0.25);
  background: rgba(6, 182, 212, 0.03);
}
.step-duration.slow {
  color: #f59e0b;
  border: 1px solid rgba(245, 158, 11, 0.25);
  background: rgba(245, 158, 11, 0.03);
}
.failed-step .step-duration {
  color: var(--fail);
  border-color: rgba(244, 63, 94, 0.35);
  background: rgba(244, 63, 94, 0.03);
}
.step-error-reason {
  font-family: var(--font-code);
  font-size: 0.8rem;
  color: #fda4af;
  background: rgba(244, 63, 94, 0.08);
  border-left: 3px solid var(--fail);
  border-radius: 4px;
  padding: 8px 12px;
  margin-top: 4px;
  width: 100%;
  white-space: pre-wrap;
  word-break: break-all;
}

/* Terminal logs split pane styling */
.logs-grid-container {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-top: 24px;
}
.logs-card-pane {
  background: rgba(0, 0, 0, 0.35);
  border: 1px solid var(--border);
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  height: 360px;
  overflow: hidden;
}
.logs-pane-title {
  font-size: 0.8rem;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--accent);
  letter-spacing: 0.05em;
  padding: 12px 16px;
  border-bottom: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.terminal-header-link {
  font-size: 0.75rem;
  color: var(--accent);
  text-decoration: none;
  font-weight: 700;
}
.terminal-header-link:hover {
  text-decoration: underline;
  color: #fff;
}
.logs-terminal {
  flex: 1;
  padding: 12px 16px;
  overflow-y: auto;
  font-family: var(--font-code);
  font-size: 0.8rem;
  background: var(--code);
  color: #cbd5e1;
}
.terminal-row {
  margin-bottom: 6px;
  line-height: 1.4;
  white-space: pre-wrap;
  word-break: break-all;
}
.terminal-timestamp {
  color: var(--text-muted);
  margin-right: 8px;
}
.terminal-badge {
  display: inline-block;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 0.65rem;
  font-weight: 800;
  margin-right: 6px;
}
.terminal-badge.passed {
  background: var(--pass-bg);
  color: var(--pass);
}
.terminal-badge.failed {
  background: var(--fail-bg);
  color: var(--fail);
}
.terminal-badge.info {
  background: rgba(6, 182, 212, 0.1);
  color: var(--accent);
}

/* Artifact Layout styling */
.screenshot-artifacts-row {
  margin-top: 24px;
  width: 100%;
}
.screenshot-artifact-card {
  width: 100%;
  background: rgba(0, 0, 0, 0.35);
  border: 1px solid var(--border);
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  padding-bottom: 24px;
  margin-top: 16px;
}
.screenshot-gallery-device {
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--text-muted);
  margin: 16px 20px 0;
}
.screenshot-gallery {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 16px;
  margin-top: 12px;
}
@media (max-width: 1200px) {
  .screenshot-gallery {
    grid-template-columns: repeat(4, 1fr);
  }
}
@media (max-width: 768px) {
  .screenshot-gallery {
    grid-template-columns: repeat(2, 1fr);
  }
}
.screenshot-gallery-tile {
  margin: 0;
  background: transparent;
  border: none;
  overflow: visible;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  width: auto;
  min-width: 0;
  box-shadow: none;
}
.screenshot-tile-header-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  min-width: 0;
  margin-bottom: 10px;
  font-family: var(--font-code);
  font-size: 0.72rem;
}
.screenshot-index-pill {
  background: rgba(6, 182, 212, 0.12);
  color: var(--accent);
  border: 1px solid rgba(6, 182, 212, 0.3);
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: 800;
  flex-shrink: 0;
}
.screenshot-gallery-tile.failed .screenshot-index-pill {
  background: rgba(239, 68, 68, 0.12);
  color: var(--fail);
  border-color: rgba(239, 68, 68, 0.3);
}
.screenshot-tile-caption {
  color: var(--text-muted);
  font-weight: 600;
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  text-align: left;
}
.screenshot-gallery-tile:hover .screenshot-tile-caption {
  color: #fff;
}
.screenshot-gallery-frame {
  background: transparent;
  aspect-ratio: auto;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  width: 100%;
  border-radius: 18px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4);
  border: 1px solid rgba(255, 255, 255, 0.06);
  transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.25s ease, border-color 0.25s ease;
}
.screenshot-gallery-frame:hover {
  transform: translateY(-5px);
  box-shadow: 0 16px 32px rgba(0, 0, 0, 0.6), 0 0 15px rgba(6, 182, 212, 0.15);
  border-color: rgba(6, 182, 212, 0.3);
}
.screenshot-gallery-tile.failed .screenshot-gallery-frame {
  border-color: rgba(239, 68, 68, 0.4);
  box-shadow: 0 10px 25px rgba(239, 68, 68, 0.15), 0 0 0 1px rgba(239, 68, 68, 0.3);
}
.screenshot-gallery-frame img {
  display: block;
  width: 100%;
  height: auto;
  object-fit: contain;
}
.fullscreen-sheet-btn {
  background: transparent;
  border: 1px solid rgba(6, 182, 212, 0.3);
  border-radius: 6px;
  color: var(--accent);
  font-size: 0.72rem;
  font-weight: 700;
  padding: 4px 8px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  transition: all 0.2s;
}
.fullscreen-sheet-btn:hover {
  background: rgba(6, 182, 212, 0.1);
  border-color: var(--accent);
  color: #fff;
}
.fullscreen-card-modal {
  width: 95%;
  max-width: 1400px;
  height: 90vh;
  background: #0f172a;
  border: 1px solid var(--border);
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7);
  overflow: hidden;
  animation: modalScaleUp 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}
.fullscreen-card-content-area {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
}
.fullscreen-card-content-area.grid-layout {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 20px;
}
@media (max-width: 1200px) {
  .fullscreen-card-content-area.grid-layout {
    grid-template-columns: repeat(4, 1fr);
  }
}
@media (max-width: 768px) {
  .fullscreen-card-content-area.grid-layout {
    grid-template-columns: repeat(2, 1fr);
  }
}
.fullscreen-sheet-tile {
  width: 280px;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.fullscreen-sheet-tile img {
  width: 100%;
  height: auto;
  border-radius: 12px;
  border: 1px solid var(--border);
  box-shadow: 0 10px 25px rgba(0,0,0,0.4);
  transition: transform 0.2s;
}
.fullscreen-sheet-tile img:hover {
  transform: scale(1.02);
  border-color: var(--accent);
}
.fullscreen-sheet-tile figcaption {
  margin-top: 10px;
  font-size: 0.8rem;
  color: var(--text-muted);
  text-align: center;
  word-break: break-word;
}
.artifact {
  background: rgba(0, 0, 0, 0.35);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 20px;
  display: flex;
  flex-direction: column;
}
.image-wrapper {
  overflow: hidden;
  border-radius: 8px;
  border: 1px solid var(--border);
  margin-top: 8px;
  background: #020617;
}
.artifact img {
  display: block;
  max-width: 100%;
  transition: transform 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}
.artifact img:hover {
  transform: scale(1.04);
}

.raw-label {
  font-family: var(--font-code);
  font-size: 0.75rem;
  color: var(--text-muted);
  font-weight: 500;
  text-transform: none;
  letter-spacing: 0;
  margin-left: 6px;
  opacity: 0.8;
}

a {
  color: #38bdf8;
  text-decoration: none;
  transition: color 0.15s ease;
}
a:hover {
  color: #7dd3fc;
  text-decoration: underline;
}

/* Pending Loading State details */
.metric-running .metric-val {
  color: var(--accent);
  animation: pulse-glow 1.5s infinite;
}
.summary.running {
  color: var(--accent);
}
.test.pending {
  border-left: 4px solid var(--accent);
}
.test.pending .card-status-dot {
  background: var(--accent);
  box-shadow: 0 0 6px var(--accent);
  animation: pulse-glow 1.5s infinite;
}
.status-capsule.pending {
  background: rgba(6, 182, 212, 0.1);
  border: 1px solid var(--accent);
  color: var(--accent);
}

.pending-detail-loader {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 40px;
  text-align: center;
}
.pending-detail-loader .spinner {
  width: 48px;
  height: 48px;
  border: 4px solid rgba(6, 182, 212, 0.1);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 24px;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
.pending-detail-loader h3 {
  margin: 0 0 8px 0;
  font-size: 1.4rem;
  color: #fff;
  font-weight: 800;
  letter-spacing: -0.01em;
}
.pending-detail-loader p {
  color: var(--text-muted);
  font-size: 0.95rem;
  max-width: 400px;
  margin: 0 0 32px 0;
}
.skeleton-line {
  height: 12px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border);
  border-radius: 6px;
  width: 80%;
  margin-bottom: 12px;
  position: relative;
  overflow: hidden;
}
.skeleton-line::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.05), transparent);
  transform: translateX(-100%);
  animation: shimmer 1.6s infinite;
}
@keyframes shimmer {
  100% { transform: translateX(100%); }
}
@keyframes pulse-glow {
  0% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.2); opacity: 0.6; }
  100% { transform: scale(1); opacity: 1; }
}

.full-page-loader {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100vh;
  width: 100vw;
  background: var(--bg);
  color: var(--text);
  text-align: center;
  padding: 40px;
}
.full-page-loader .spinner {
  width: 64px;
  height: 64px;
  border: 4px solid rgba(6, 182, 212, 0.1);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 32px;
  box-shadow: 0 0 20px rgba(6, 182, 212, 0.2);
}
.full-page-loader h1 {
  margin: 0 0 12px 0;
  font-size: 2.5rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  background: linear-gradient(135deg, #ffffff 30%, #a1a1aa 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.full-page-loader .subtitle {
  color: var(--accent);
  font-size: 1.2rem;
  font-weight: 700;
  margin: 0 0 20px 0;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
.full-page-loader .loader-progress-info {
  color: var(--text-muted);
  font-size: 1rem;
  max-width: 480px;
  margin: 0 0 48px 0;
  line-height: 1.6;
}
.skeleton-line-full {
  height: 16px;
  background: rgba(255, 255, 255, 0.02);
  border: 1px solid var(--border);
  border-radius: 8px;
  width: 60%;
  max-width: 600px;
  margin-bottom: 16px;
  position: relative;
  overflow: hidden;
}
.skeleton-line-full::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.04), transparent);
  transform: translateX(-100%);
  animation: shimmer 1.6s infinite;
}
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(15, 23, 42, 0.85);
  backdrop-filter: blur(8px);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
}
.modal-nav-btn {
  background: rgba(15, 23, 42, 0.6);
  border: 1px solid rgba(255, 255, 255, 0.08);
  color: #cbd5e1;
  font-size: 1.8rem;
  width: 56px;
  height: 56px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s ease;
  z-index: 1001;
  user-select: none;
  backdrop-filter: blur(8px);
  flex-shrink: 0;
}
.modal-nav-btn:hover {
  background: rgba(6, 182, 212, 0.15);
  border-color: var(--accent);
  color: #fff;
  box-shadow: 0 0 15px rgba(6, 182, 212, 0.25);
}
.modal-nav-btn.prev {
  margin-right: 20px;
}
.modal-nav-btn.next {
  margin-left: 20px;
}
@media (max-width: 1200px) {
  .modal-nav-btn {
    width: 48px;
    height: 48px;
    font-size: 1.5rem;
  }
  .modal-nav-btn.prev {
    margin-right: 12px;
  }
  .modal-nav-btn.next {
    margin-left: 12px;
  }
}
@media (max-width: 768px) {
  .modal-nav-btn {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
  }
  .modal-nav-btn.prev {
    left: 10px;
    margin-right: 0;
  }
  .modal-nav-btn.next {
    right: 10px;
    margin-left: 0;
  }
}
.modal-card {
  width: 980px;
  max-width: 95%;
  height: 750px;
  max-height: 90vh;
  background: #0f172a;
  border: 1px solid var(--border);
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.6);
  overflow: hidden;
  animation: modalScaleUp 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}
@keyframes modalScaleUp {
  from { transform: scale(0.95); opacity: 0; }
  to { transform: scale(1); opacity: 1; }
}
.modal-header {
  padding: 20px 24px;
  border-bottom: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: rgba(255, 255, 255, 0.01);
}
.modal-header-left {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}
.modal-badge {
  font-size: 0.65rem;
  font-weight: 800;
  color: var(--accent);
  letter-spacing: 0.1em;
}
#modal-step-title {
  margin: 0;
  font-size: 1.15rem;
  color: #fff;
  font-family: var(--font-code);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.modal-close-btn {
  background: transparent;
  border: none;
  color: var(--text-muted);
  font-size: 1.8rem;
  cursor: pointer;
  line-height: 1;
  padding: 0 0 0 16px;
  transition: color 0.2s;
}
.modal-close-btn:hover {
  color: #fff;
}
.modal-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
  padding: 20px 24px;
}
.modal-tabs {
  display: flex;
  gap: 16px;
  border-bottom: 1px solid var(--border);
  margin-bottom: 20px;
}
.modal-tab-btn {
  background: transparent;
  border: none;
  color: var(--text-muted);
  padding: 10px 4px;
  font-size: 0.9rem;
  font-weight: 700;
  cursor: pointer;
  position: relative;
  transition: color 0.2s;
}
.modal-tab-btn:hover {
  color: #fff;
}
.modal-tab-btn.active {
  color: var(--accent);
}
.modal-tab-btn.active::after {
  content: '';
  position: absolute;
  bottom: -1px;
  left: 0;
  right: 0;
  height: 2px;
  background: var(--accent);
}
.modal-tab-content {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}
.modal-list {
  flex: 1;
  overflow-y: auto;
  padding-right: 8px;
}
.modal-screenshots-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  align-content: flex-start;
}
.modal-screenshot-card {
  width: fit-content;
  max-width: min(220px, 100%);
  background: transparent;
  border: none;
  border-radius: 0;
  overflow: visible;
}
.modal-screenshot-card img {
  display: block;
  width: auto;
  max-width: 100%;
  height: auto;
  max-height: 360px;
  object-fit: contain;
}
.modal-screenshot-label {
  padding: 8px 10px;
  font-size: 0.75rem;
  color: var(--text-muted);
  font-family: var(--font-code);
  word-break: break-word;
}
.modal-screenshot-card a {
  position: relative;
  display: block;
  overflow: hidden;
  border-radius: 0;
}
.modal-screenshot-card a::after {
  content: '🔍 Open Full Size';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(15, 23, 42, 0.75);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 0.85rem;
  font-weight: 700;
  opacity: 0;
  transition: opacity 0.2s ease;
  backdrop-filter: blur(2px);
}
.modal-screenshot-card a:hover::after {
  opacity: 1;
}
.single-screenshot-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;
  padding: 10px 0;
}
.modal-screenshot-card.single-layout {
  width: fit-content;
  max-width: min(300px, 100%);
  border: none;
  border-radius: 0;
  box-shadow: none;
  transition: none;
}
.modal-screenshot-card.single-layout:hover {
  transform: none;
  border-color: transparent;
  box-shadow: none;
}
.modal-screenshot-card.single-layout img {
  max-height: 520px;
}
.api-event-container {
  border: 1px solid var(--border);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.01);
  margin-bottom: 8px;
  overflow: hidden;
  transition: border-color 0.2s;
}
.api-event-container:hover {
  border-color: rgba(6, 182, 212, 0.3);
}
.api-event-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px;
  cursor: pointer;
  user-select: none;
  transition: background 0.2s;
}
.api-event-header:hover {
  background: rgba(255, 255, 255, 0.03);
}
.api-event-header-left {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.api-caret {
  display: inline-block;
  width: 14px;
  color: var(--text-muted);
  font-size: 0.65rem;
  transition: transform 0.2s;
}
.api-event-details {
  display: none;
  padding: 14px 18px;
  background: rgba(0, 0, 0, 0.15);
  border-top: 1px solid var(--border);
  font-family: var(--font-code);
  font-size: 0.8rem;
  animation: fadeIn 0.20s ease;
}
.api-detail-section {
  margin-bottom: 12px;
}
.api-detail-section:last-child {
  margin-bottom: 0;
}
.api-detail-label {
  font-size: 0.65rem;
  font-weight: 800;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 6px;
}
.api-detail-sublabel {
  font-size: 0.6rem;
  font-weight: 700;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-top: 8px;
  margin-bottom: 4px;
}
.api-detail-pre {
  margin: 0;
  background: #090d16;
  padding: 12px;
  border-radius: 6px;
  border: 1px solid var(--border);
  overflow-x: auto;
  max-height: 250px;
  color: #38bdf8;
}
.api-detail-url {
  color: #a7f3d0;
  word-break: break-all;
}
''';

  static const _defaultDisplayRoot = String.fromEnvironment(
    'ensembleTestArtifactDisplayRoot',
    defaultValue: 'build/ensemble_test_runner',
  );
}

class _ArtifactRef {
  final String label;
  final String path;

  const _ArtifactRef({required this.label, required this.path});
}

/// True when this Flutter test process is a parallel CLI worker shard.
bool isEnsembleTestParallelWorker() {
  const suffix = String.fromEnvironment('ensembleTestWorkerSuffix');
  return suffix.isNotEmpty;
}
