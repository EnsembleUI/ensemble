import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/html_test_report_app_js.dart';
import 'package:ensemble_test_runner/reporters/html_test_report_css.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:path/path.dart' as p;

/// Writes a thin HTML report shell once; test data lives in results.json.gz.
class HtmlTestReporter {
  /// Writes the HTML shell (if needed) and results.
  ///
  /// When [isSuiteRunning] is true: writes shell + loading results.
  /// When false: writes complete results; writes shell only if missing.
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
    final htmlFile = File(p.join(reportDir.path, 'index.html'));

    if (isSuiteRunning) {
      htmlFile.writeAsStringSync(buildShellHtml());
      TestReportDocument.writeResults(
        reportDir,
        TestReportDocument.buildLoading(wallTimeMs: wallTimeMs),
      );
    } else {
      if (!htmlFile.existsSync()) {
        htmlFile.writeAsStringSync(buildShellHtml());
      }
      TestReportDocument.writeResults(
        reportDir,
        TestReportDocument.buildComplete(
          result,
          artifactRoot: root,
          displayRoot: display,
          wallTimeMs: wallTimeMs,
        ),
      );
      TestReportDocument.cleanTransientArtifacts(root);
    }

    return p.join(display, 'report', 'index.html').replaceAll('\\', '/');
  }

  /// Updates results only (suite finished). Does not rewrite index.html.
  String writeResultsOnly(
    EnsembleTestRunResult result, {
    String? artifactRoot,
    String? displayRoot,
    int? wallTimeMs,
  }) {
    final root = artifactRoot ?? ensembleTestArtifactRoot;
    final display = displayRoot ?? _defaultDisplayRoot;
    final reportDir = Directory(p.join(root, 'report'));
    reportDir.createSync(recursive: true);
    final htmlFile = File(p.join(reportDir.path, 'index.html'));
    if (!htmlFile.existsSync()) {
      htmlFile.writeAsStringSync(buildShellHtml());
    }
    TestReportDocument.writeResults(
      reportDir,
      TestReportDocument.buildComplete(
        result,
        artifactRoot: root,
        displayRoot: display,
        wallTimeMs: wallTimeMs,
      ),
    );
    TestReportDocument.cleanTransientArtifacts(root);
    return p.join(display, 'report', TestReportDocument.resultsFileName)
        .replaceAll('\\', '/');
  }

  /// Thin HTML shell (no embedded test payload).
  String buildShellHtml() {
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
      ..writeln('<style>$ensembleHtmlTestReportCss</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<div class="grid-overlay"></div>')
      ..writeln(
          '<div id="report-error" style="display:none;padding:48px;color:var(--fail);font-family:var(--font-sans);"></div>')
      ..writeln(
          '<div id="report-loader" class="full-page-loader" style="display:flex;">')
      ..writeln('  <div class="spinner"></div>')
      ..writeln('  <h1>Ensemble Test Runner</h1>')
      ..writeln('  <p class="subtitle">Test Suite Execution in Progress</p>')
      ..writeln(
          '  <div class="loader-progress-info">Running declarative tests. This page updates automatically when results.json.gz is ready.</div>')
      ..writeln('  <div class="skeleton-line-full"></div>')
      ..writeln('  <div class="skeleton-line-full"></div>')
      ..writeln('  <div class="skeleton-line-full"></div>')
      ..writeln('</div>')
      ..writeln('<div id="report-app" style="display:none;">')
      ..writeln('<header class="hero">')
      ..writeln('  <div class="hero-header">')
      ..writeln('    <h1>Ensemble Test Runner</h1>')
      ..writeln('    <p class="summary" id="hero-summary"></p>')
      ..writeln('  </div>')
      ..writeln('</header>')
      ..writeln('<section class="dashboard">')
      ..writeln('  <div class="metrics-grid" id="metrics-grid"></div>')
      ..writeln('</section>')
      ..writeln('<section class="controls">')
      ..writeln('  <div class="controls-bar">')
      ..writeln('    <div class="search-wrapper">')
      ..writeln(
          '      <input type="text" id="search-input" placeholder="Search test cases by ID or name..." oninput="applySearchFilter()"/>')
      ..writeln('    </div>')
      ..writeln('    <div class="filter-tabs">')
      ..writeln(
          "      <button class=\"filter-btn active\" data-filter=\"all\" onclick=\"setFilter('all')\">All Tests</button>")
      ..writeln(
          "      <button class=\"filter-btn\" data-filter=\"failed\" onclick=\"setFilter('failed')\">Failed</button>")
      ..writeln(
          "      <button class=\"filter-btn\" data-filter=\"passed\" onclick=\"setFilter('passed')\">Passed</button>")
      ..writeln('    </div>')
      ..writeln('    <div class="sort-wrapper">')
      ..writeln('      <span class="sort-label">Sort:</span>')
      ..writeln('      <select id="sort-select" onchange="applySort()" class="sort-select">')
      ..writeln('        <option value="execution">Execution Order</option>')
      ..writeln('        <option value="alphabetical">Name (A-Z)</option>')
      ..writeln('        <option value="duration">Duration (Slowest)</option>')
      ..writeln('        <option value="status">Status (Failed First)</option>')
      ..writeln('      </select>')
      ..writeln('    </div>')
      ..writeln('  </div>')
      ..writeln('</section>')
      ..writeln('<div id="suite-artifacts-host"></div>')
      ..writeln('<div class="dashboard-container">')
      ..writeln('  <aside class="test-list-pane" id="test-list-pane"></aside>')
      ..writeln(
          '  <section class="test-detail-pane" id="test-detail-pane"></section>')
      ..writeln('</div>')
      ..writeln('</div>')
      ..writeln(_modalMarkup())
      ..writeln('<script>')
      ..writeln(ensembleHtmlTestReportAppJs)
      ..writeln('</script>')
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }

  /// Kept for callers that still expect an HTML string; also writes results.
  String buildHtml(
    EnsembleTestRunResult result, {
    required String artifactRoot,
    required String displayRoot,
    int? wallTimeMs,
    bool isSuiteRunning = false,
  }) {
    final reportDir = Directory(p.join(artifactRoot, 'report'));
    reportDir.createSync(recursive: true);
    if (isSuiteRunning) {
      TestReportDocument.writeResults(
        reportDir,
        TestReportDocument.buildLoading(wallTimeMs: wallTimeMs),
      );
    } else {
      TestReportDocument.writeResults(
        reportDir,
        TestReportDocument.buildComplete(
          result,
          artifactRoot: artifactRoot,
          displayRoot: displayRoot,
          wallTimeMs: wallTimeMs,
        ),
      );
      TestReportDocument.cleanTransientArtifacts(artifactRoot);
    }
    return buildShellHtml();
  }

  String _modalMarkup() {
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
        <button class="modal-tab-btn" data-tab="performance" onclick="switchModalTab('performance')">⚡ Performance (<span id="modal-perf-count">0</span>)</button>
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
      <div class="modal-tab-content" id="modal-tab-performance" style="display: none;">
        <div id="modal-perf-list" class="modal-list"></div>
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

<div id="screen-modal-overlay" class="modal-overlay" style="display: none;" onclick="closeScreenDialog(event)">
  <div class="modal-card" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-header-left">
        <span class="modal-badge">SCREEN DETAILS</span>
        <h3 id="modal-screen-title"></h3>
      </div>
      <button class="modal-close-btn" onclick="closeScreenDialog(event)">&times;</button>
    </div>
    <div class="modal-body">
      <div class="modal-tabs">
        <button class="screen-tab-btn active" data-tab="screen-debugtree" onclick="switchScreenTab('screen-debugtree')">🌳 Widget Debug Tree</button>
        <button class="screen-tab-btn" data-tab="screen-perf" onclick="switchScreenTab('screen-perf')">⚡ Performance Timeline</button>
      </div>
      <div class="modal-tab-content" id="modal-tab-screen-debugtree">
        <div id="modal-screen-debugtree-content" class="modal-list logs-terminal" style="font-family: var(--font-code); font-size: 0.75rem; max-height: 500px; overflow: auto; text-align: left; padding: 16px; background: rgba(0,0,0,0.3); border: 1px solid var(--border); border-radius: 8px;"></div>
      </div>
      <div class="modal-tab-content" id="modal-tab-screen-perf" style="display: none;">
        <div id="modal-screen-perf-content" class="modal-list logs-terminal" style="font-family: var(--font-code); font-size: 0.75rem; max-height: 500px; overflow: auto; text-align: left; padding: 16px; background: rgba(0,0,0,0.3); border: 1px solid var(--border); border-radius: 8px;"></div>
      </div>
    </div>
  </div>
</div>
''';
  }

  static const _defaultDisplayRoot = String.fromEnvironment(
    'ensembleTestArtifactDisplayRoot',
    defaultValue: 'build/ensemble_test_runner',
  );
}

/// True when this Flutter test process is a parallel CLI worker shard.
bool isEnsembleTestParallelWorker() {
  const suffix = String.fromEnvironment('ensembleTestWorkerSuffix');
  return suffix.isNotEmpty;
}
