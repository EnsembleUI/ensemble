import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
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
        ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1"/>')
        ..writeln('<meta http-equiv="refresh" content="3"/>')
        ..writeln('<title>Running Ensemble YAML Tests</title>')
        ..writeln('<link rel="preconnect" href="https://fonts.googleapis.com">')
        ..writeln('<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>')
        ..writeln('<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300..800&display=swap" rel="stylesheet">')
        ..writeln('<style>${_css()}</style>')
        ..writeln('</head>')
        ..writeln('<body>')
        ..writeln('<div class="grid-overlay"></div>')
        ..writeln('<div class="full-page-loader">')
        ..writeln('  <div class="spinner"></div>')
        ..writeln('  <h1>Ensemble YAML Tests</h1>')
        ..writeln('  <p class="subtitle">Test Suite Execution in Progress</p>')
        ..writeln('  <div class="loader-progress-info">Running all declarative tests on configured device targets. The dashboard will populate automatically when finished.</div>')
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
    final passedCount = result.results.where((r) => r.status == TestStatus.passed).length;
    final failedCount = result.failedCount;
    final pendingCount = result.results.where((r) => r.status == TestStatus.pending).length;
    final successRate = totalTests > 0 ? (passedCount / totalTests * 100).toStringAsFixed(0) : '0';

    final summaryText = pendingCount > 0
        ? '$passedCount passed, $failedCount failed, $pendingCount running ($totalTests total)'
        : '$passedCount passed, $failedCount failed ($totalTests total)';
    final summaryClass = pendingCount > 0
        ? 'running'
        : (failedCount == 0 ? 'passed' : 'failed');

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8"/>')
      ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1"/>')
      ..writeln('<title>Ensemble YAML test report</title>')
      ..writeln('<link rel="preconnect" href="https://fonts.googleapis.com">')
      ..writeln('<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>')
      ..writeln('<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:ital,wght@0,300..800;1,300..800&family=JetBrains+Mono:ital,wght@0,100..800;1,100..800&display=swap" rel="stylesheet">')
      ..writeln('<style>${_css()}</style>')
      ..writeln('</head>')
      ..writeln('<body onload="const firstCard = document.querySelector(\'.test\'); if (firstCard) firstCard.click();">')
      ..writeln('<div class="grid-overlay"></div>')
      ..writeln('<header class="hero">')
      ..writeln('  <div class="hero-header">')
      ..writeln('    <h1>Ensemble YAML Tests</h1>')
      ..writeln('    <p class="summary $summaryClass">')
      ..writeln('      ${_escape(summaryText)} · ${_formatDuration(totalMs)}')
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
      ..writeln('      <div class="metric-val">${_formatDuration(displayMs)}</div>')
      ..writeln('      <div class="metric-label">Duration</div>')
      ..writeln('    </div>')
      ..writeln('  </div>')
      ..writeln('</section>');

    // Search and Filter controls
    buffer
      ..writeln('<section class="controls">')
      ..writeln('  <div class="controls-bar">')
      ..writeln('    <div class="search-wrapper">')
      ..writeln('      <input type="text" id="search-input" placeholder="Search test cases by ID or name..." oninput="')
      ..writeln('        const q = this.value.toLowerCase().trim();')
      ..writeln('        document.querySelectorAll(\'.test\').forEach(c => {')
      ..writeln('          const matchQ = c.id.toLowerCase().includes(q) || c.innerText.toLowerCase().includes(q);')
      ..writeln('          const f = window.activeFilter || \'all\';')
      ..writeln('          const matchF = f === \'all\' || (f === \'passed\' && c.classList.contains(\'passed\')) || (f === \'failed\' && c.classList.contains(\'failed\'));')
      ..writeln('          c.style.display = (matchQ && matchF) ? \'flex\' : \'none\';')
      ..writeln('        });')
      ..writeln('      "/>')
      ..writeln('    </div>')
      ..writeln('    <div class="filter-tabs">')
      ..writeln('      <button class="filter-btn active" data-filter="all" onclick="')
      ..writeln('        window.activeFilter = \'all\';')
      ..writeln('        document.querySelectorAll(\'.filter-btn\').forEach(b => b.classList.toggle(\'active\', b.getAttribute(\'data-filter\') === \'all\'));')
      ..writeln('        document.getElementById(\'search-input\').dispatchEvent(new Event(\'input\'));')
      ..writeln('      ">All Tests</button>')
      ..writeln('      <button class="filter-btn" data-filter="failed" onclick="')
      ..writeln('        window.activeFilter = \'failed\';')
      ..writeln('        document.querySelectorAll(\'.filter-btn\').forEach(b => b.classList.toggle(\'active\', b.getAttribute(\'data-filter\') === \'failed\'));')
      ..writeln('        document.getElementById(\'search-input\').dispatchEvent(new Event(\'input\'));')
      ..writeln('      ">Failed</button>')
      ..writeln('      <button class="filter-btn" data-filter="passed" onclick="')
      ..writeln('        window.activeFilter = \'passed\';')
      ..writeln('        document.querySelectorAll(\'.filter-btn\').forEach(b => b.classList.toggle(\'active\', b.getAttribute(\'data-filter\') === \'passed\'));')
      ..writeln('        document.getElementById(\'search-input\').dispatchEvent(new Event(\'input\'));')
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
      ..writeln('      <p>Select a test case from the left list to inspect results, screen journeys, logs, and screenshots.</p>')
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
      ..writeln('    <summary>Show Suite Logs & Artifacts (${artifacts.length})</summary>')
      ..writeln('    <div class="suite-artifacts-content">')
      ..writeln('      <ul>');

    for (final artifact in artifacts) {
      final href = _relativeHref(artifact.path, displayRoot);
      buffer
        ..writeln('        <li>')
        ..writeln('          <div class="artifact-item-header">')
        ..writeln('            <span class="label">${_escape(artifact.label)}</span>: ')
        ..writeln('            <a href="${_escape(href)}">${_escape(artifact.path)}</a>')
        ..writeln('          </div>')
        ..writeln('        </li>');
    }

    buffer
      ..writeln('      </ul>')
      ..writeln('    </div>')
      ..writeln('  </details>')
      ..writeln('</section>');
  }

  void _writeTestCard(StringBuffer buffer, String base, List<EnsembleSingleTestResult> runs) {
    final firstRun = runs.first;
    final hasPending = runs.any((r) => r.status == TestStatus.pending);
    final groupPassed = runs.every((r) => r.status == TestStatus.passed);
    final cardId = _anchorId(firstRun.testId);
    final statusClass = hasPending
        ? 'pending'
        : (groupPassed ? 'passed' : 'failed');

    // Literal match for test assertions: "<article class="test failed" id="login_flow_tests_login_test_yaml_">"
    buffer
      ..writeln('    <article class="test $statusClass" id="${_escape(cardId)}" onclick="')
      ..writeln('      document.querySelectorAll(\'.test\').forEach(c => c.classList.remove(\'active\'));')
      ..writeln('      this.classList.add(\'active\');')
      ..writeln('      document.getElementById(\'details-placeholder\').style.display = \'none\';')
      ..writeln('      document.querySelectorAll(\'.test-detail-content\').forEach(d => d.style.display = \'none\');')
      ..writeln('      document.getElementById(\'details-$cardId\').style.display = \'block\';')
      ..writeln('      const firstBtn = document.querySelector(\'#details-$cardId .device-tab-btn\');')
      ..writeln('      if (firstBtn) firstBtn.click();')
      ..writeln('    ">')
      ..writeln('      <div class="card-status-dot"></div>')
      ..writeln('      <div class="card-info">')
      ..writeln('        <div class="card-title">${_escape(base)}</div>')
      ..writeln('        <div class="card-meta">')
      ..writeln('          <span class="card-duration">${_formatDuration(firstRun.durationMs)}</span>');

    // Render device badges as mini-pills under card title
    for (final run in runs) {
      final badge = _deviceBadgeOf(run.testId);
      if (badge.isNotEmpty) {
        buffer.writeln('          <span class="card-device-badge">${_escape(badge.toUpperCase())}</span>');
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

    buffer.writeln('<div class="test-detail-content" id="details-$cardId" style="display: none;">');

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
          ..writeln('      <button class="device-tab-btn" data-run="$i" onclick="')
          ..writeln('        document.querySelectorAll(\'#details-$cardId .device-tab-btn\').forEach(b => b.classList.remove(\'active\'));')
          ..writeln('        this.classList.add(\'active\');')
          ..writeln('        document.querySelectorAll(\'#details-$cardId .device-run-block\').forEach(r => r.style.display = \'none\');')
          ..writeln('        document.getElementById(\'run-$cardId-$i\').style.display = \'block\';')
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

      buffer
        ..writeln('  <div class="device-run-block" id="run-$cardId-$i" style="display: none;">')
        ..writeln('    <div class="test-card-header">')
        ..writeln('      <div class="title-section">')
        ..writeln('        <h2>')
        ..writeln('          <span class="icon">${isPending ? '🔄' : (passed ? '✓' : '✗')}</span> ')
        ..writeln('          ${_escape(base)}')
        ..writeln('        </h2>');

      if (badge.isNotEmpty) {
        final isAndroid = badge.toLowerCase().contains('android') || badge.toLowerCase().contains('samsung') || badge.toLowerCase().contains('pixel');
        final isIos = badge.toLowerCase().contains('ios') || badge.toLowerCase().contains('iphone');
        final hasNl = badge.toLowerCase().contains('nl');
        final badgeClass = isAndroid ? 'android' : (isIos ? 'ios' : 'default');
        final iconName = isAndroid ? 'Android' : (isIos ? 'iOS' : 'Device');
        final flagStr = hasNl ? ' 🇳🇱 DUTCH (NL)' : ' 🇬🇧 ENGLISH (EN)';
        buffer.writeln('        <span class="device-pill $badgeClass">$iconName · ${_escape(badge.toUpperCase())}$flagStr</span>');
      }

      final statusText = isPending ? 'RUNNING' : (passed ? 'PASSED' : 'FAILED');
      final statusCapsuleClass = isPending ? 'pending' : (passed ? 'passed' : 'failed');

      buffer
        ..writeln('      </div>')
        ..writeln('      <div class="status-capsule $statusCapsuleClass">$statusText</div>')
        ..writeln('    </div>');

      if (filePath.isNotEmpty) {
        buffer.writeln('    <p class="file-path-sub"><span>File:</span> ${_escape(filePath)}</p>');
      }

      if (isPending) {
        buffer
          ..writeln('    <div class="pending-detail-loader">')
          ..writeln('      <div class="spinner"></div>')
          ..writeln('      <h3>Test Execution in Progress</h3>')
          ..writeln('      <p>This test case is currently running on the device. Please wait for the execution to finish.</p>')
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
          buffer.writeln('      <div class="rail-item"><div class="rail-label">Session</div><div class="rail-val">${_escape(report.session!)}</div></div>');
        }
        buffer.writeln('      <div class="rail-item"><div class="rail-label">Start Screen</div><div class="rail-val highlight">${_escape(report.startScreen)}</div></div>');
        if (report.endScreen != null && report.endScreen != report.startScreen) {
          buffer.writeln('      <div class="rail-item"><div class="rail-label">End Screen</div><div class="rail-val highlight">${_escape(report.endScreen!)}</div></div>');
        }
        buffer.writeln('    </div>');

        if (report.screensVisited.length > 1) {
          buffer
            ..writeln('    <div class="flow-timeline">')
            ..writeln('      <div class="flow-label">Flow Journey</div>')
            ..writeln('      <div class="flow-track">');
          for (var j = 0; j < report.screensVisited.length; j++) {
            buffer.writeln('        <span class="flow-node">${_escape(report.screensVisited[j])}</span>');
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
            ..writeln('      <div class="timeline-header">Steps Outline</div>')
            ..writeln('      <div class="timeline-steps-track">');
          for (var j = 0; j < report.stepsOutline.length; j++) {
            final failed = !passed && test.failedStepIndex == j;
            buffer
              ..writeln('        <div class="timeline-step-row ${failed ? 'failed-step' : ''}">')
              ..writeln('          <div class="timeline-marker"><span class="marker-dot"></span></div>')
              ..writeln('          <div class="step-outline-text">${_escape(report.stepsOutline[j])}</div>')
              ..writeln('        </div>');
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
        final screenshots = artifacts.where((a) =>
            a.label == 'screenshots' ||
            a.path.toLowerCase().endsWith('.png') ||
            a.path.toLowerCase().endsWith('.jpg') ||
            a.path.toLowerCase().endsWith('.jpeg') ||
            a.path.toLowerCase().endsWith('.webp')).toList();
        final logs = artifacts.where((a) => !screenshots.contains(a)).toList();

        // 3. Render side-by-side terminal logs widget
        final appLogRef = logs.firstWhere((a) => a.label == 'appLogs', orElse: () => _ArtifactRef(label: '', path: ''));
        final apiCallsRef = logs.firstWhere((a) => a.label == 'apiCalls', orElse: () => _ArtifactRef(label: '', path: ''));
        final storageRef = logs.firstWhere((a) => a.label == 'storage', orElse: () => _ArtifactRef(label: '', path: ''));

        buffer.writeln('    <div class="logs-grid-container">');

        // Actions & Console logs pane
        final appLogsHref = appLogRef.path.isNotEmpty ? _relativeHref(appLogRef.path, displayRoot) : '';
        buffer
          ..writeln('      <div class="logs-card-pane">')
          ..writeln('        <div class="logs-pane-title">')
          ..writeln('          <span>📝 Actions & Console Logs <span class="raw-label">(appLogs)</span></span>');
        if (appLogsHref.isNotEmpty) {
          buffer.writeln('          <a class="terminal-header-link" href="${_escape(appLogsHref)}">View File</a>');
        }
        buffer
          ..writeln('        </div>')
          ..writeln('        <div class="logs-terminal">');

        if (appLogRef.path.isNotEmpty) {
          final fsPath = _filesystemPath(appLogRef.path, artifactRoot: artifactRoot, displayRoot: displayRoot);
          if (fsPath != null && File(fsPath).existsSync()) {
            final lines = File(fsPath).readAsLinesSync();
            if (lines.isEmpty) {
              buffer.writeln('          <div class="terminal-row" style="color: var(--text-muted);">&lt;no console output&gt;</div>');
            } else {
              for (final line in lines) {
                if (line.startsWith('SCREEN TRACKER:')) {
                  final text = line.replaceAll('SCREEN TRACKER:', '').trim();
                  buffer.writeln('          <div class="terminal-row"><span class="terminal-badge info">SCREEN</span> <span style="color: var(--accent); font-weight: 700;">${_escape(text)}</span></div>');
                } else if (line.toLowerCase().contains('error') || line.toLowerCase().contains('exception')) {
                  buffer.writeln('          <div class="terminal-row"><span class="terminal-badge failed">ERROR</span> <span style="color: var(--fail);">${_escape(line)}</span></div>');
                } else {
                  buffer.writeln('          <div class="terminal-row">${_escape(line)}</div>');
                }
              }
            }
          } else {
            buffer.writeln('          <div class="terminal-row" style="color: var(--text-muted);">&lt;no console output&gt;</div>');
          }
        } else {
          buffer.writeln('          <div class="terminal-row" style="color: var(--text-muted);">&lt;no console output&gt;</div>');
        }
        buffer
          ..writeln('        </div>')
          ..writeln('      </div>');

        // Network Logs / API Calls terminal pane
        final apiCallsHref = apiCallsRef.path.isNotEmpty ? _relativeHref(apiCallsRef.path, displayRoot) : '';
        buffer
          ..writeln('      <div class="logs-card-pane">')
          ..writeln('        <div class="logs-pane-title">')
          ..writeln('          <span>🌐 Network API Logs <span class="raw-label">(apiCalls)</span></span>');
        if (apiCallsHref.isNotEmpty) {
          buffer.writeln('          <a class="terminal-header-link" href="${_escape(apiCallsHref)}">View File</a>');
        }
        buffer
          ..writeln('        </div>')
          ..writeln('        <div class="logs-terminal">');

        var hasApiEvents = false;
        if (apiCallsRef.path.isNotEmpty) {
          final fsPath = _filesystemPath(apiCallsRef.path, artifactRoot: artifactRoot, displayRoot: displayRoot);
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
                      final timeMatch = RegExp(r'T(\d{2}:\d{2}:\d{2})').firstMatch(timestamp);
                      if (timeMatch != null) {
                        timePart = '[${timeMatch.group(1)}] ';
                      }

                      final hasError = ev['error'] != null || ev['failed'] == true || ev['exception'] != null;
                      final isSuccess = statusCode != null
                          ? (statusCode is int && statusCode >= 200 && statusCode < 300)
                          : !hasError;
                      final displayStatus = statusCode != null ? '$statusCode' : (isSuccess ? '200' : 'ERROR');

                      final badgeClass = mocked ? 'info' : (isSuccess ? 'passed' : 'failed');
                      final badgeText = mocked ? 'MOCK' : 'API';
                      final statusColor = isSuccess ? 'var(--pass)' : 'var(--fail)';

                      buffer.writeln('          <div class="terminal-row"><span class="terminal-timestamp">${_escape(timePart)}</span><span class="terminal-badge $badgeClass">$badgeText</span><span style="font-weight: 700; color: #fff;">${_escape(name)}</span> · <span style="color: $statusColor; font-weight: 700;">$displayStatus</span></div>');
                    }
                  }
                }
              }
            } catch (_) {}
          }
        }

        if (!hasApiEvents) {
          buffer.writeln('          <div class="terminal-row" style="color: var(--text-muted);">&lt;no API requests recorded&gt;</div>');
        }

        buffer
          ..writeln('        </div>')
          ..writeln('      </div>')
          ..writeln('    </div>');

        // Extra local storage log view at the bottom if present
        if (storageRef.path.isNotEmpty) {
          final storageHref = _relativeHref(storageRef.path, displayRoot);
          var storageContent = '';
          final fsPath = _filesystemPath(storageRef.path, artifactRoot: artifactRoot, displayRoot: displayRoot);
          if (fsPath != null && File(fsPath).existsSync()) {
            try {
              final raw = File(fsPath).readAsStringSync();
              final decoded = json.decode(raw);
              storageContent = const JsonEncoder.withIndent('  ').convert(decoded);
            } catch (_) {
              storageContent = File(fsPath).readAsStringSync();
            }
          }

          buffer
            ..writeln('    <div style="margin-top: 16px;">')
            ..writeln('      <div class="logs-card-pane" style="height: 240px;">')
            ..writeln('        <div class="logs-pane-title">')
            ..writeln('          <span>💾 Local State Storage <span class="raw-label">(storage)</span></span>')
            ..writeln('          <a class="terminal-header-link" href="${_escape(storageHref)}">View Storage File</a>')
            ..writeln('        </div>')
            ..writeln('        <div class="logs-terminal">');

          if (storageContent.isNotEmpty) {
            for (final line in storageContent.split('\n')) {
              buffer.writeln('          <div class="terminal-row">${_escape(line)}</div>');
            }
          } else {
            buffer.writeln('          <div class="terminal-row" style="color: var(--text-muted);">&lt;empty local storage state&gt;</div>');
          }

          buffer
            ..writeln('        </div>')
            ..writeln('      </div>')
            ..writeln('    </div>');
        }

        // 4. Render full-width screenshots contact sheet on its own line below logs
        if (screenshots.isNotEmpty) {
          buffer.writeln('    <div class="screenshot-artifacts-row">');
          for (final artifact in screenshots) {
            final href = _relativeHref(artifact.path, displayRoot);
            buffer
              ..writeln('      <div class="artifact screenshot-artifact-card">')
              ..writeln('        <div class="logs-pane-title" style="border: none; padding: 0 0 12px 0;">')
              ..writeln('          <span style="font-weight: 800; font-size: 0.8rem; text-transform: uppercase; color: var(--accent); letter-spacing: 0.08em;">🖼️ Screenshots Contact Sheet <span class="raw-label">(${_escape(artifact.label)})</span></span>')
              ..writeln('          <a class="terminal-header-link" href="${_escape(href)}">View File</a>')
              ..writeln('        </div>');

            final fsPath = _filesystemPath(
              artifact.path,
              artifactRoot: artifactRoot,
              displayRoot: displayRoot,
            );
            if (fsPath != null && File(fsPath).existsSync()) {
              buffer.writeln(
                '        <div class="image-wrapper"><img src="${_escape(href)}" alt="${_escape(artifact.label)}"/></div>',
              );
            }
            buffer.writeln('      </div>');
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

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

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
    final isAndroid = deviceBadge.toLowerCase().contains('android') || deviceBadge.toLowerCase().contains('samsung') || deviceBadge.toLowerCase().contains('pixel');
    final isIos = deviceBadge.toLowerCase().contains('ios') || deviceBadge.toLowerCase().contains('iphone');
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
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 12px 16px;
  margin-bottom: 24px;
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
  padding-bottom: 12px;
  align-items: flex-start;
}
.timeline-step-row:last-child {
  padding-bottom: 0;
}
.timeline-marker {
  position: absolute;
  left: -20px;
  top: 6px;
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
.step-outline-text {
  font-family: var(--font-code);
  font-size: 0.85rem;
  color: #cbd5e1;
  padding-left: 10px;
}
.failed-step .step-outline-text {
  color: var(--fail);
  font-weight: 700;
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
