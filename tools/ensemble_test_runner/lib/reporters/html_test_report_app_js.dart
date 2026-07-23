/// Client-side app script for the HTML report shell.
const ensembleHtmlTestReportAppJs = r'''

  const POLL_MS = 2000;
  let pollTimer = null;
  let renderedComplete = false;
  let activeFilter = 'all';
  let activeSort = 'execution';
  let activeModalTab = 'api';
  let currentModalCardId = '';
  let currentModalStepIndex = -1;

  function escapeHtml(str) {
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function formatDuration(ms) {
    if (ms == null) return '';
    if (ms < 1000) return ms + 'ms';
    const seconds = ms / 1000;
    if (seconds < 60) return seconds.toFixed(1) + 's';
    const minutes = Math.floor(ms / 60000);
    const remaining = (ms % 60000) / 1000;
    return minutes + 'm ' + remaining.toFixed(1) + 's';
  }

  function formatStepText(text) {
    const escaped = escapeHtml(text);
    const parenIndex = escaped.indexOf('(');
    if (parenIndex === -1) return '<span class="step-action">' + escaped + '</span>';
    return '<span class="step-action">' + escaped.substring(0, parenIndex) + '</span><span class="step-args">' + escaped.substring(parenIndex) + '</span>';
  }

  function anchorId(testId) {
    return String(testId).replace(/[^A-Za-z0-9_-]+/g, '_');
  }

  function resolveBlobValue(value, blobs) {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      if (Object.keys(value).length === 1 && typeof value['$b'] === 'string') {
        return resolveBlobValue(blobs[value['$b']], blobs);
      }
      const out = {};
      Object.keys(value).forEach((k) => { out[k] = resolveBlobValue(value[k], blobs); });
      return out;
    }
    if (Array.isArray(value)) {
      return value.map((item) => resolveBlobValue(item, blobs));
    }
    return value;
  }

  function inheritNestedStepPayloads(tests) {
    (tests || []).forEach((test) => {
      const steps = test.steps || [];
      let parent = null;
      for (let i = 0; i < steps.length; i++) {
        const step = steps[i] || {};
        const nested = String(step.stepText || '').startsWith('  ');
        if (!nested) {
          parent = {
            apiCalls: step.apiCalls || [],
            appLogs: step.appLogs || [],
            storageChanges: step.storageChanges || [],
            screenshots: step.screenshots || []
          };
          step.apiCalls = parent.apiCalls;
          step.appLogs = parent.appLogs;
          step.storageChanges = parent.storageChanges;
          step.screenshots = parent.screenshots;
        } else if (parent) {
          step.apiCalls = parent.apiCalls;
          step.appLogs = parent.appLogs;
          step.storageChanges = parent.storageChanges;
          step.screenshots = parent.screenshots;
        } else {
          step.apiCalls = [];
          step.appLogs = [];
          step.storageChanges = [];
          step.screenshots = [];
        }
        steps[i] = step;
      }
      test.steps = steps;
    });
  }

  function hydrateReport(report) {
    const blobs = report.blobs || {};
    const resolved = resolveBlobValue(report, blobs);
    delete resolved.blobs;
    inheritNestedStepPayloads(resolved.tests || []);
    return resolved;
  }

  async function gunzipToText(buffer) {
    if (typeof DecompressionStream === 'undefined') {
      throw new Error('Gzip decompression is not supported in this browser');
    }
    const ds = new DecompressionStream('gzip');
    const stream = new Blob([buffer]).stream().pipeThrough(ds);
    return await new Response(stream).text();
  }

  async function loadResults() {
    const res = await fetch('results.json.gz?t=' + Date.now(), { cache: 'no-store' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const bytes = await res.arrayBuffer();
    const text = await gunzipToText(bytes);
    return hydrateReport(JSON.parse(text));
  }

  async function pollAndRender() {
    try {
      const report = await loadResults();
      if (!report) {
        showError('Report data is empty.');
        return;
      }
      if (report.state === 'complete') {
        if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
        if (!renderedComplete) {
          renderedComplete = true;
          renderComplete(report);
        }
        return;
      }
      showLoading();
    } catch (e) {
      showError('Waiting for results.json.gz… Serve the report folder over HTTP (e.g. Live Server).');
    }
  }

  function showLoading() {
    document.getElementById('report-loader').style.display = 'flex';
    document.getElementById('report-app').style.display = 'none';
    document.getElementById('report-error').style.display = 'none';
  }

  function showError(msg) {
    document.getElementById('report-loader').style.display = 'none';
    document.getElementById('report-app').style.display = 'none';
    const err = document.getElementById('report-error');
    err.style.display = 'block';
    err.textContent = msg;
  }

  function renderComplete(report) {
    document.getElementById('report-loader').style.display = 'none';
    document.getElementById('report-error').style.display = 'none';
    document.getElementById('report-app').style.display = 'block';

    const summary = report.summary || {};
    const tests = report.tests || [];
    const passed = summary.passed || 0;
    const failed = summary.failed || 0;
    const pending = summary.pending || 0;
    const total = tests.length;
    const displayMs = summary.wallTimeMs != null ? summary.wallTimeMs : (summary.totalMs || 0);
    const successRate = total > 0 ? Math.round((passed / total) * 100) : 0;
    const summaryText = pending > 0
      ? (passed + ' passed, ' + failed + ' failed, ' + pending + ' running (' + total + ' total)')
      : (passed + ' passed, ' + failed + ' failed (' + total + ' total)');
    const summaryClass = pending > 0 ? 'running' : (failed === 0 ? 'passed' : 'failed');

    document.getElementById('hero-summary').className = 'summary ' + summaryClass;
    document.getElementById('hero-summary').textContent = summaryText + ' · ' + formatDuration(displayMs);

    let metrics = '';
    metrics += '<div class="metric-card"><div class="metric-val">' + total + '</div><div class="metric-label">Total Tests</div></div>';
    if (pending > 0) {
      metrics += '<div class="metric-card metric-running"><div class="metric-val">' + pending + '</div><div class="metric-label">Running</div></div>';
    }
    metrics += '<div class="metric-card metric-passed"><div class="metric-val">' + passed + '</div><div class="metric-label">Passed</div></div>';
    metrics += '<div class="metric-card metric-failed"><div class="metric-val">' + failed + '</div><div class="metric-label">Failed</div></div>';
    metrics += '<div class="metric-card metric-rate"><div class="metric-val">' + successRate + '%</div><div class="metric-label">Success Rate</div></div>';
    metrics += '<div class="metric-card metric-duration"><div class="metric-val">' + formatDuration(displayMs) + '</div><div class="metric-label">Suite Duration</div></div>';
    document.getElementById('metrics-grid').innerHTML = metrics;

    renderSuiteArtifacts(report.suiteArtifacts || []);

    window.currentReport = report;

    const grouped = {};
    const groupedKeys = [];
    tests.forEach(t => {
      const base = t.baseId || t.id;
      if (!grouped[base]) {
        grouped[base] = [];
        groupedKeys.push(base);
      }
      grouped[base].push(t);
    });

    if (activeSort === 'alphabetical') {
      groupedKeys.sort((a, b) => a.localeCompare(b));
    } else if (activeSort === 'duration') {
      groupedKeys.sort((a, b) => {
        const maxA = Math.max(...grouped[a].map(t => t.durationMs || 0));
        const maxB = Math.max(...grouped[b].map(t => t.durationMs || 0));
        return maxB - maxA;
      });
    } else if (activeSort === 'status') {
      groupedKeys.sort((a, b) => {
        const failedA = grouped[a].some(t => t.status === 'failed') ? 1 : 0;
        const failedB = grouped[b].some(t => t.status === 'failed') ? 1 : 0;
        return failedB - failedA;
      });
    }

    window.stepData = {};
    const listPane = document.getElementById('test-list-pane');
    const detailPane = document.getElementById('test-detail-pane');
    listPane.innerHTML = '';
    detailPane.innerHTML = '<div id="details-placeholder" class="detail-placeholder"><div class="placeholder-icon">🔍</div><h3>No Test Selected</h3><p>Select a test case from the left list to inspect results, screen journeys, logs, and screenshots.</p></div>';

    groupedKeys.forEach(base => {
      const runs = grouped[base];
      listPane.appendChild(buildSidebarCard(base, runs));
      detailPane.appendChild(buildDetailsGroup(base, runs));
    });

    const firstCard = document.querySelector('.test');
    if (firstCard) firstCard.click();
  }

  function renderSuiteArtifacts(artifacts) {
    const host = document.getElementById('suite-artifacts-host');
    if (!artifacts.length) { host.innerHTML = ''; return; }
    let html = '<section class="suite-artifacts-container"><details class="suite-artifacts-card">';
    html += '<summary>Show Suite Logs & Artifacts (' + artifacts.length + ')</summary>';
    html += '<div class="suite-artifacts-content"><ul>';
    artifacts.forEach(a => {
      html += '<li><div class="artifact-item-header"><span class="label">' + escapeHtml(a.label) + '</span>';
      if (a.content != null) {
        html += '</div>';
        if (a.source) {
          html += '<div class="artifact-source">' + escapeHtml(a.source) + '</div>';
        }
        let body = '';
        try {
          body = typeof a.content === 'string' ? a.content : JSON.stringify(a.content, null, 2);
        } catch (e) {
          body = String(a.content);
        }
        html += '<pre class="artifact-embedded">' + escapeHtml(body) + '</pre>';
      } else {
        html += ': <a href="' + escapeHtml(a.href || a.path || '#') + '">' + escapeHtml(a.path || a.href || '') + '</a></div>';
      }
      html += '</li>';
    });
    html += '</ul></div></details></section>';
    host.innerHTML = html;
  }

  function buildSidebarCard(base, runs) {
    const first = runs[0];
    const hasPending = runs.some(r => r.status === 'pending');
    const groupPassed = runs.every(r => r.status === 'passed');
    const maxDurationMs = Math.max(...runs.map(r => r.durationMs || 0));
    const cardId = anchorId(first.id);
    const statusClass = hasPending ? 'pending' : (groupPassed ? 'passed' : 'failed');
    const el = document.createElement('article');
    el.className = 'test ' + statusClass;
    el.id = cardId;
    let badges = '';
    runs.forEach(run => {
      if (run.deviceBadge) {
        badges += '<span class="card-device-badge">' + escapeHtml(String(run.deviceBadge).toUpperCase()) + '</span>';
      }
    });
    el.innerHTML = '<div class="card-status-dot"></div><div class="card-info"><div class="card-title">' + escapeHtml(base) + '</div><div class="card-meta"><span class="card-duration">' + formatDuration(maxDurationMs) + '</span>' + badges + '</div></div>';
    el.onclick = function() {
      document.querySelectorAll('.test').forEach(c => c.classList.remove('active'));
      el.classList.add('active');
      document.getElementById('details-placeholder').style.display = 'none';
      document.querySelectorAll('.test-detail-content').forEach(d => d.style.display = 'none');
      const details = document.getElementById('details-' + cardId);
      if (details) details.style.display = 'block';
      const firstBtn = document.querySelector('#details-' + cardId + ' .device-tab-btn');
      if (firstBtn) firstBtn.click();
      else {
        const firstBlock = document.querySelector('#details-' + cardId + ' .device-run-block');
        if (firstBlock) firstBlock.style.display = 'block';
      }
    };
    return el;
  }

  function deviceButtonText(badge) {
    if (!badge) return 'Device';
    const parts = badge.split('_');
    return parts.map(p => p.charAt(0).toUpperCase() + p.slice(1)).join(' ');
  }

  function buildDetailsGroup(base, runs) {
    const cardId = anchorId(runs[0].id);
    const wrap = document.createElement('div');
    wrap.className = 'test-detail-content';
    wrap.id = 'details-' + cardId;
    wrap.style.display = 'none';

    let html = '';
    if (runs.length > 1) {
      html += '<div class="device-selector-bar"><span class="selector-label">Device Runs:</span><div class="device-tabs">';
      runs.forEach((run, i) => {
        html += '<button class="device-tab-btn" data-run="' + i + '">' + escapeHtml(deviceButtonText(run.deviceBadge)) + '</button>';
      });
      html += '</div></div>';
    }

    runs.forEach((test, i) => {
      const stepKey = cardId + '-' + i;
      window.stepData[stepKey] = test.steps || [];
      html += buildRunBlock(base, test, cardId, i, stepKey);
    });
    wrap.innerHTML = html;

    wrap.querySelectorAll('.device-tab-btn').forEach(btn => {
      btn.onclick = function() {
        wrap.querySelectorAll('.device-tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        wrap.querySelectorAll('.device-run-block').forEach(r => r.style.display = 'none');
        const run = document.getElementById('run-' + cardId + '-' + btn.getAttribute('data-run'));
        if (run) run.style.display = 'block';
      };
    });
    return wrap;
  }

  function buildRunBlock(base, test, cardId, i, stepKey) {
    const passed = test.status === 'passed';
    const isPending = test.status === 'pending';
    const badge = test.deviceBadge || '';
    let html = '<div class="device-run-block" id="run-' + cardId + '-' + i + '" style="display: none;">';
    html += '<div class="test-card-header"><div class="title-section"><h2>';
    html += '<span class="icon">' + (isPending ? '🔄' : (passed ? '✓' : '✗')) + '</span> ' + escapeHtml(base) + '</h2>';
    if (badge) {
      const lower = badge.toLowerCase();
      const isAndroid = lower.includes('android') || lower.includes('samsung') || lower.includes('pixel');
      const isIos = lower.includes('ios') || lower.includes('iphone');
      const hasNl = lower.includes('nl');
      const badgeClass = isAndroid ? 'android' : (isIos ? 'ios' : 'default');
      const iconName = isAndroid ? 'Android' : (isIos ? 'iOS' : 'Device');
      const flagStr = hasNl ? ' 🇳🇱 DUTCH (NL)' : ' 🇬🇧 ENGLISH (EN)';
      html += '<span class="device-pill ' + badgeClass + '">' + iconName + ' · ' + escapeHtml(badge.toUpperCase()) + flagStr + '</span>';
    }
    const statusText = isPending ? 'RUNNING' : (passed ? 'PASSED' : 'FAILED');
    const statusCapsuleClass = isPending ? 'pending' : (passed ? 'passed' : 'failed');
    html += '</div><div class="status-capsule ' + statusCapsuleClass + '">' + statusText + '</div></div>';

    if (test.filePath) {
      html += '<p class="file-path-sub"><span>File:</span> ' + escapeHtml(test.filePath) + '</p>';
    }

    if (isPending) {
      html += '<div class="pending-detail-loader"><div class="spinner"></div><h3>Test Execution in Progress</h3><p>This test case is currently running on the device.</p></div>';
      html += '</div>';
      return html;
    }

    html += '<p class="meta">' + formatDuration(test.durationMs);
    if (test.attempts > 1) html += ' · attempts ' + test.attempts + '/' + ((test.retry || 0) + 1);
    html += '</p>';

    const report = test.report || {};
    if (report.session) {
      html += '<div class="meta-dashboard-rail">';
      html += '<div class="rail-item"><div class="rail-label">Session</div><div class="rail-val">' + escapeHtml(report.session) + '</div></div>';
      html += '</div>';
    }

    const visited = report.screensVisited || [];
    if (visited.length > 0) {
      html += '<div class="flow-timeline"><div class="flow-label">Flow Journey</div><div class="flow-track">';
      visited.forEach((s, j) => {
        const screensMap = report.screens || {};
        const hasData = screensMap[s] !== undefined;
        if (hasData) {
          const escapedScreen = s.replace(/'/g, "\\'");
          html += '<span class="flow-node interactive" style="cursor: pointer; text-decoration: underline; color: var(--accent); font-weight: 700;" title="Click to view Widget Debug Tree & Performance Logs" onclick="openScreenDialog(\'' + anchorId(test.id) + '\', \'' + escapedScreen + '\')">' + escapeHtml(s) + '</span>';
        } else {
          html += '<span class="flow-node">' + escapeHtml(s) + '</span>';
        }
        if (j < visited.length - 1) html += '<span class="flow-arrow">→</span>';
      });
      html += '</div></div>';
    }

    const outline = report.stepsOutline || [];
    const durations = report.stepDurationsMs || [];
    if (outline.length) {
      html += '<div class="timeline-steps-container"><div class="timeline-header">Steps Outline</div><div class="timeline-steps-track">';
      let top = -1;
      outline.forEach((line, j) => {
        const nested = line.startsWith('  ');
        if (!nested) top++;
        const durationMs = (!nested && top < durations.length) ? durations[top] : null;
        const failed = !nested && test.failedStepIndex != null && test.failedStepIndex === top;
        const speedClass = durationMs == null ? 'fast' : (durationMs < 500 ? 'fast' : (durationMs < 2000 ? 'normal' : 'slow'));
        html += '<div class="timeline-step-row' + (failed ? ' failed-step' : '') + '" style="cursor:pointer;" onclick="openStepDialog(\'' + stepKey + '\', ' + j + ')">';
        html += '<div class="timeline-marker"><span class="marker-dot"></span></div><div class="step-outline-body"><div class="step-outline-top-row">';
        html += '<div class="step-outline-text">' + formatStepText(line) + '</div>';
        if (durationMs != null) html += '<span class="step-duration ' + speedClass + '">' + escapeHtml(formatDuration(durationMs)) + '</span>';
        html += '</div>';
        if (failed && test.message) html += '<div class="step-error-reason">' + escapeHtml(test.message) + '</div>';
        html += '</div></div>';
      });
      html += '</div></div>';
    }

    if (!passed && test.message) {
      html += '<pre class="error">' + escapeHtml(test.message) + '</pre>';
    }

    html += renderTerminals(test);
    html += renderScreenshotGallery(test);
    html += '</div>';
    return html;
  }

  function renderConsoleRows(lines) {
    if (!lines || !lines.length) {
      return '<div class="terminal-row" style="color: var(--text-muted);">&lt;no console output&gt;</div>';
    }
    return lines.map(line => {
      let logBody = line;
      let timePart = '';
      if (line.startsWith('[')) {
        const closeBrace = line.indexOf(']');
        if (closeBrace !== -1) {
          const tStr = line.substring(1, closeBrace);
          logBody = line.substring(closeBrace + 1).trim();
          const timeMatch = /T(\d{2}:\d{2}:\d{2})/.exec(tStr);
          if (timeMatch) timePart = '[' + timeMatch[1] + '] ';
        }
      }
      if (logBody.startsWith('SCREEN TRACKER:')) {
        const text = logBody.replace('SCREEN TRACKER:', '').trim();
        return '<div class="terminal-row"><span class="terminal-timestamp">' + escapeHtml(timePart) + '</span><span class="terminal-badge info">SCREEN</span> <span style="color: var(--accent); font-weight: 700;">' + escapeHtml(text) + '</span></div>';
      }
      if (logBody.toLowerCase().includes('error') || logBody.toLowerCase().includes('exception')) {
        return '<div class="terminal-row"><span class="terminal-timestamp">' + escapeHtml(timePart) + '</span><span class="terminal-badge failed">ERROR</span> <span style="color: var(--fail);">' + escapeHtml(logBody) + '</span></div>';
      }
      return '<div class="terminal-row"><span class="terminal-timestamp">' + escapeHtml(timePart) + '</span>' + escapeHtml(logBody) + '</div>';
    }).join('');
  }

  function renderApiRows(events) {
    if (!events || !events.length) {
      return '<div class="terminal-row" style="color: var(--text-muted);">&lt;no API requests recorded&gt;</div>';
    }
    return events.map(ev => {
      const name = ev.name || 'API';
      const statusCode = ev.statusCode;
      const mocked = ev.mocked === true;
      const timestamp = ev.timestamp || '';
      let timePart = '';
      const timeMatch = /T(\d{2}:\d{2}:\d{2})/.exec(timestamp);
      if (timeMatch) timePart = '[' + timeMatch[1] + '] ';
      const hasError = ev.error != null || ev.failed === true || ev.exception != null;
      const isSuccess = statusCode != null ? (statusCode >= 200 && statusCode < 300) : !hasError;
      const displayStatus = statusCode != null ? statusCode : (isSuccess ? '200' : 'ERROR');
      const badgeClass = mocked ? 'info' : (isSuccess ? 'passed' : 'failed');
      let badgeText = 'API';
      if (mocked) badgeText = 'MOCK';
      else {
        const type = (ev.type || '').toLowerCase();
        if (type === 'firestore') badgeText = 'FIRESTORE';
        else if (type === 'functions') badgeText = 'FUNC';
      }
      const statusColor = isSuccess ? 'var(--pass)' : 'var(--fail)';
      return '<div class="terminal-row"><span class="terminal-timestamp">' + escapeHtml(timePart) + '</span><span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span style="font-weight: 700; color: #fff;">' + escapeHtml(name) + '</span> · <span style="color: ' + statusColor + '; font-weight: 700;">' + displayStatus + '</span></div>';
    }).join('');
  }

  function flattenStepField(test, field) {
    const out = [];
    const steps = test.steps || [];
    for (let i = 0; i < steps.length; i++) {
      const step = steps[i] || {};
      // Nested outline rows inherit parent payloads — skip to avoid double-counting.
      if (String(step.stepText || '').startsWith('  ')) continue;
      const items = step[field] || [];
      for (let j = 0; j < items.length; j++) out.push(items[j]);
    }
    return out;
  }

  function renderTerminals(test) {
    const consoleLines = flattenStepField(test, 'appLogs');
    const events = flattenStepField(test, 'apiCalls');
    const storage = test.storage || {};
    const keys = storage.keys || {};
    let storageContent = '';
    try { storageContent = JSON.stringify(keys, null, 2); } catch (e) { storageContent = String(keys); }

    let html = '<div class="logs-grid-container">';
    html += '<div class="logs-card-pane"><div class="logs-pane-title"><span>📝 Actions & Console Logs</span>';
    html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'logs\')">⛶ Open Fullscreen</button></div>';
    html += '<div class="logs-terminal">' + renderConsoleRows(consoleLines) + '</div></div>';

    html += '<div class="logs-card-pane"><div class="logs-pane-title"><span>🌐 Network API Logs</span>';
    html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'apis\')">⛶ Open Fullscreen</button></div>';
    html += '<div class="logs-terminal">' + renderApiRows(events) + '</div></div></div>';

    if (Object.keys(keys).length > 0) {
      html += '<div class="logs-grid-container" style="margin-top:16px;"><div class="logs-card-pane" style="grid-column:1/-1;"><div class="logs-pane-title"><span>💾 Local State Storage</span>';
      html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'storage\')">⛶ Open Fullscreen</button></div>';
      html += '<div class="logs-terminal"><div class="terminal-row">' + escapeHtml(storageContent) + '</div></div></div></div>';
    }
    return html;
  }

  function renderScreenshotGallery(test) {
    const frames = flattenStepField(test, 'screenshots');
    if (!frames.length) return '';
    let html = '<div class="screenshot-artifacts-row"><div class="artifact screenshot-artifact-card">';
    html += '<div class="logs-pane-title" style="border:none;padding:0 0 12px 0;"><span style="font-weight:800;font-size:0.8rem;text-transform:uppercase;color:var(--accent);letter-spacing:0.08em;">🖼️ Screenshots</span>';
    html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'screenshots\')">⛶ Open Fullscreen</button></div>';
    html += '<div class="screenshot-gallery">';
    frames.forEach((frame, idx) => {
      const href = frame.href || '';
      const label = frame.label || frame.file || ('Frame ' + (idx + 1));
      const failed = frame.failed === true;
      html += '<figure class="screenshot-gallery-tile' + (failed ? ' failed' : '') + '">';
      html += '<div class="screenshot-tile-header-bar"><span class="screenshot-index-pill">' + (idx + 1) + '</span>';
      html += '<span class="screenshot-tile-caption" title="' + escapeHtml(label) + '">' + escapeHtml(label) + '</span></div>';
      html += '<div class="screenshot-gallery-frame">';
      if (href) html += '<a href="' + escapeHtml(href) + '" target="_blank" rel="noopener"><img src="' + escapeHtml(href) + '" alt="' + escapeHtml(label) + '" loading="lazy"/></a>';
      html += '</div></figure>';
    });
    html += '</div></div></div>';
    return html;
  }

  function applySearchFilter() {
    const q = (document.getElementById('search-input').value || '').toLowerCase().trim();
    const f = activeFilter || 'all';
    document.querySelectorAll('.test').forEach(c => {
      const matchQ = c.id.toLowerCase().includes(q) || c.innerText.toLowerCase().includes(q);
      const matchF = f === 'all' || (f === 'passed' && c.classList.contains('passed')) || (f === 'failed' && c.classList.contains('failed'));
      c.style.display = (matchQ && matchF) ? 'flex' : 'none';
    });
  }

  function setFilter(f) {
    activeFilter = f;
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.toggle('active', b.getAttribute('data-filter') === f));
    applySearchFilter();
  }

  function applySort() {
    const select = document.getElementById('sort-select');
    if (select) {
      activeSort = select.value;
    }
    if (window.currentReport) {
      renderComplete(window.currentReport);
      applySearchFilter();
    }
  }

  // --- Step modal (retargeted to window.stepData) ---
  function getStorageStateAtStep(cardId, targetStepIndex) {
    const deviceData = window.stepData && window.stepData[cardId];
    if (!deviceData) return {};
    const stepKeys = Object.keys(deviceData).map(k => parseInt(k, 10)).filter(n => !isNaN(n)).sort((a, b) => a - b);
    const state = {};
    for (const stepKey of stepKeys) {
      if (stepKey > targetStepIndex) break;
      const stepObj = deviceData[stepKey];
      const changes = (stepObj && stepObj.storageChanges) || [];
      for (const change of changes) {
        const key = change.key;
        if (!key) continue;
        const kind = (change.change || '').toLowerCase();
        if (kind === 'removed') delete state[key];
        else if (kind === 'added' || kind === 'modified') state[key] = change.after;
      }
    }
    return state;
  }

  function openStepDialog(cardId, stepIndex) {
    currentModalCardId = cardId;
    currentModalStepIndex = parseInt(stepIndex, 10);
    const data = window.stepData && window.stepData[cardId] && window.stepData[cardId][stepIndex];
    if (!data) return;
    const deviceData = window.stepData[cardId];
    const stepKeys = Object.keys(deviceData).map(k => parseInt(k, 10)).filter(n => !isNaN(n)).sort((a, b) => a - b);
    const pos = stepKeys.indexOf(currentModalStepIndex);
    const prevBtn = document.querySelector('.modal-nav-btn.prev');
    const nextBtn = document.querySelector('.modal-nav-btn.next');
    if (prevBtn) prevBtn.style.visibility = (pos > 0) ? 'visible' : 'hidden';
    if (nextBtn) nextBtn.style.visibility = (pos < stepKeys.length - 1) ? 'visible' : 'hidden';

    const titleText = (data.stepText || '').trim();
    document.getElementById('modal-step-title').textContent = titleText;

    const apiList = document.getElementById('modal-api-list');
    apiList.innerHTML = '';
    const apiCalls = data.apiCalls || [];
    document.getElementById('modal-api-count').textContent = apiCalls.length;
    if (!apiCalls.length) {
      apiList.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no API requests recorded for this step&gt;</div>';
    } else {
      apiCalls.forEach(ev => {
        const name = ev.name || 'API';
        const statusCode = ev.statusCode;
        const mocked = ev.mocked === true;
        const timestamp = ev.timestamp || '';
        let timePart = '';
        const timeMatch = /T(\d{2}:\d{2}:\d{2})/.exec(timestamp);
        if (timeMatch) timePart = '[' + timeMatch[1] + '] ';
        const isSuccess = statusCode != null ? (statusCode >= 200 && statusCode < 300) : (ev.error == null && ev.failed !== true && ev.exception == null);
        const displayStatus = statusCode != null ? statusCode : (isSuccess ? '200' : 'ERROR');
        const badgeClass = mocked ? 'info' : (isSuccess ? 'passed' : 'failed');
        let badgeText = 'API';
        if (mocked) badgeText = 'MOCK';
        else {
          const type = (ev.type || '').toLowerCase();
          if (type === 'firestore') badgeText = 'FIRESTORE';
          else if (type === 'functions') badgeText = 'FUNC';
        }
        const statusColor = isSuccess ? 'var(--pass)' : 'var(--fail)';
        let prettyResponse = '';
        if (ev.responseBody) {
          try {
            prettyResponse = typeof ev.responseBody === 'string' ? JSON.stringify(JSON.parse(ev.responseBody), null, 2) : JSON.stringify(ev.responseBody, null, 2);
          } catch (e) { prettyResponse = String(ev.responseBody); }
        }
        const request = ev.request || {};
        const method = request.method || 'GET';
        const url = request.url || '';
        const errorMsg = ev.error || '';
        let requestDetailsHtml = '';
        if (request.headers && Object.keys(request.headers).length > 0) {
          requestDetailsHtml += '<div style="margin-top: 8px;"><div class="api-detail-sublabel">Headers</div><pre class="api-detail-pre">' + escapeHtml(JSON.stringify(request.headers, null, 2)) + '</pre></div>';
        }
        if (request.parameters && Object.keys(request.parameters).length > 0) {
          requestDetailsHtml += '<div style="margin-top: 8px;"><div class="api-detail-sublabel">Parameters / Query</div><pre class="api-detail-pre">' + escapeHtml(JSON.stringify(request.parameters, null, 2)) + '</pre></div>';
        }
        if (request.body && (typeof request.body === 'object' ? Object.keys(request.body).length > 0 : String(request.body).length > 0)) {
          const bodyStr = typeof request.body === 'object' ? JSON.stringify(request.body, null, 2) : String(request.body);
          requestDetailsHtml += '<div style="margin-top: 8px;"><div class="api-detail-sublabel">Body / Data</div><pre class="api-detail-pre">' + escapeHtml(bodyStr) + '</pre></div>';
        }
        const container = document.createElement('div');
        container.className = 'api-event-container';
        const errorHtml = errorMsg ? '<div class="api-detail-section"><div class="api-detail-label" style="color: var(--fail);">Error</div><div style="color: var(--fail); font-weight: 700;">' + escapeHtml(errorMsg) + '</div></div>' : '';
        const responseHtml = prettyResponse ? '<div class="api-detail-section"><div class="api-detail-label">Response Body</div><pre class="api-detail-pre">' + escapeHtml(prettyResponse) + '</pre></div>' : '';
        const requestHtml = url ? '<div class="api-detail-section"><div class="api-detail-label">Request</div><div class="api-detail-url"><span style="color: var(--accent); font-weight: 700; margin-right: 6px;">' + escapeHtml(method) + '</span>' + escapeHtml(url) + '</div>' + requestDetailsHtml + '</div>' : '';
        container.innerHTML = '<div class="api-event-header" onclick="toggleApiDetails(this)"><div class="api-event-header-left"><span class="api-caret">▶</span><span class="terminal-timestamp">' + escapeHtml(timePart) + '</span><span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span style="font-weight: 700; color: #fff;">' + escapeHtml(name) + '</span></div><span style="color: ' + statusColor + '; font-weight: 700;">' + displayStatus + '</span></div><div class="api-event-details">' + requestHtml + errorHtml + responseHtml + '</div>';
        apiList.appendChild(container);
      });
    }

    const logsList = document.getElementById('modal-logs-list');
    logsList.innerHTML = renderConsoleRows(data.appLogs || []);
    document.getElementById('modal-logs-count').textContent = (data.appLogs || []).length;

    const storageList = document.getElementById('modal-storage-list');
    storageList.innerHTML = '';
    const storageChanges = data.storageChanges || [];
    document.getElementById('modal-storage-count').textContent = storageChanges.length;
    const currentState = getStorageStateAtStep(cardId, stepIndex);
    const changedKeys = new Set(storageChanges.map(c => c.key).filter(Boolean));
    if (!storageChanges.length && Object.keys(currentState).length === 0) {
      storageList.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no storage changes for this step&gt;</div>';
    } else {
      storageChanges.forEach(change => {
        const key = change.key || '(unknown)';
        const kind = (change.change || '').toLowerCase();
        let badgeClass = 'info', badgeText = 'MOD', valueColor = 'var(--accent)', detail = '';
        if (kind === 'added') { badgeClass = 'passed'; badgeText = 'ADD'; valueColor = 'var(--pass)'; detail = formatStorageValue(change.after); }
        else if (kind === 'removed') { badgeClass = 'failed'; badgeText = 'DEL'; valueColor = 'var(--fail)'; detail = formatStorageValue(change.before); }
        else { detail = formatStorageValue(change.before) + ' → ' + formatStorageValue(change.after); }
        const row = document.createElement('div');
        row.className = 'terminal-row';
        row.innerHTML = '<span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span style="font-weight: 700; color: #fff;">' + escapeHtml(key) + '</span> <span style="color: ' + valueColor + ';">' + escapeHtml(detail) + '</span>';
        storageList.appendChild(row);
      });
      Object.keys(currentState).filter(k => !changedKeys.has(k)).sort().forEach(key => {
        const row = document.createElement('div');
        row.className = 'terminal-row';
        row.innerHTML = '<span class="terminal-badge info" style="background: rgba(255,255,255,0.06); color: var(--text-muted); border: 1px solid rgba(255,255,255,0.15); margin-right: 6px;">VAL</span><span style="font-weight: 700; color: var(--text-muted);">' + escapeHtml(key) + '</span> <span style="color: #cbd5e1;">' + escapeHtml(formatStorageValue(currentState[key])) + '</span>';
        storageList.appendChild(row);
      });
    }

    const shotsList = document.getElementById('modal-screenshots-list');
    shotsList.innerHTML = '';
    const screenshots = data.screenshots || [];
    document.getElementById('modal-screenshots-count').textContent = screenshots.length;
    if (!screenshots.length) {
      shotsList.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no screenshot for this step&gt;</div>';
    } else {
      screenshots.forEach((shot, index) => {
        const href = shot.href || '';
        const rawLabel = shot.label || shot.file || 'Screenshot';
        const card = document.createElement('div');
        card.className = 'modal-screenshot-card' + (screenshots.length === 1 ? ' single-layout' : '');
        if (href) {
          let labelHtml = '';
          if (screenshots.length > 1) {
            let cleanLabel = getCleanScreenshotLabel(rawLabel, titleText) || ('Screenshot ' + (index + 1));
            labelHtml = '<div class="modal-screenshot-label">' + escapeHtml(cleanLabel) + '</div>';
          }
          card.innerHTML = '<a href="' + escapeHtml(href) + '" target="_blank" rel="noopener"><img src="' + escapeHtml(href) + '" alt="' + escapeHtml(rawLabel) + '" loading="lazy"/></a>' + labelHtml;
        } else {
          card.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">' + escapeHtml(rawLabel) + '</div>';
        }
        if (screenshots.length === 1) {
          const container = document.createElement('div');
          container.className = 'single-screenshot-container';
          container.appendChild(card);
          shotsList.appendChild(container);
        } else {
          shotsList.appendChild(card);
        }
      });
    }

    switchModalTab(activeModalTab);
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
    titleText = titleText.replace(/📝|🌐|💾|🖼️/g, '').trim();
    const rawLabelIdx = titleText.indexOf('(');
    if (rawLabelIdx !== -1) titleText = titleText.substring(0, rawLabelIdx).trim();
    document.getElementById('fullscreen-card-badge').textContent = type.toUpperCase();
    document.getElementById('fullscreen-card-title').textContent = titleText;
    const contentArea = document.getElementById('fullscreen-card-content');
    contentArea.innerHTML = '';
    contentArea.className = 'fullscreen-card-content-area';
    if (type === 'screenshots') {
      contentArea.classList.add('grid-layout');
      cardEl.querySelectorAll('.screenshot-gallery-tile').forEach(tile => {
        contentArea.appendChild(tile.cloneNode(true));
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
      if (event.target.id !== 'step-modal-overlay' && !event.target.classList.contains('modal-close-btn')) return;
    }
    document.getElementById('step-modal-overlay').style.display = 'none';
    activeModalTab = 'api';
  }

  function navigateStep(direction, event) {
    if (event) event.stopPropagation();
    const deviceData = window.stepData && window.stepData[currentModalCardId];
    if (!deviceData) return;
    const stepKeys = Object.keys(deviceData).map(k => parseInt(k, 10)).filter(n => !isNaN(n)).sort((a, b) => a - b);
    const currentPos = stepKeys.indexOf(currentModalStepIndex);
    const nextPos = currentPos + direction;
    if (nextPos < 0 || nextPos >= stepKeys.length) return;
    openStepDialog(currentModalCardId, stepKeys[nextPos]);
  }

  function switchModalTab(tab) {
    activeModalTab = tab;
    document.querySelectorAll('.modal-tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.getAttribute('data-tab') === tab);
    });
    document.querySelectorAll('.modal-tab-content').forEach(content => { content.style.display = 'none'; });
    const pane = document.getElementById('modal-tab-' + tab);
    if (pane) pane.style.display = 'flex';
  }

  function formatStorageValue(value) {
    if (value === undefined || value === null) return 'null';
    let text;
    if (typeof value === 'string') text = value;
    else { try { text = JSON.stringify(value); } catch (e) { text = String(value); } }
    return text;
  }

  function getCleanScreenshotLabel(label, titleText) {
    let clean = label.replace(/^\d+\.\s*/, '').trim();
    if (clean.toLowerCase() === titleText.toLowerCase()) return '';
    if (clean.toLowerCase().startsWith(titleText.toLowerCase())) {
      let suffix = clean.substring(titleText.length).trim().replace(/^[(\-\s]+|[)\-\s]+$/g, '').trim();
      if (suffix) return suffix;
    }
    return clean;
  }

  let activeScreenTab = 'screen-debugtree';

  function openScreenDialog(cardId, screenName) {
    const tests = (window.currentReport && window.currentReport.tests) || [];
    const test = tests.find(t => anchorId(t.id) === cardId);
    if (!test || !test.report || !test.report.screens) return;
    const screenData = test.report.screens[screenName];
    if (!screenData) return;

    document.getElementById('modal-screen-title').innerText = screenName;

    // 1. Render Widget Debug Tree
    const treeEl = document.getElementById('modal-screen-debugtree-content');
    if (screenData.debugTree) {
      treeEl.innerHTML = '<pre style="margin: 0; white-space: pre-wrap; word-break: break-all; color: #cbd5e1; text-align: left;">' + escapeHtml(screenData.debugTree) + '</pre>';
    } else {
      treeEl.innerHTML = '<div style="color: var(--text-muted); padding: 12px;">&lt;no debug tree captured&gt;</div>';
    }

    // 2. Render Performance Logs
    const perfEl = document.getElementById('modal-screen-perf-content');
    if (screenData.performance) {
      let body = '';
      try {
        body = typeof screenData.performance === 'string' ? screenData.performance : JSON.stringify(screenData.performance, null, 2);
      } catch (e) {
        body = String(screenData.performance);
      }
      perfEl.innerHTML = '<pre style="margin: 0; white-space: pre-wrap; word-break: break-all; color: #cbd5e1; text-align: left;">' + escapeHtml(body) + '</pre>';
    } else {
      perfEl.innerHTML = '<div style="color: var(--text-muted); padding: 12px;">&lt;no performance logs captured&gt;</div>';
    }

    switchScreenTab(activeScreenTab);
    document.getElementById('screen-modal-overlay').style.display = 'flex';
  }

  function closeScreenDialog(event) {
    if (event) {
      if (event.target.id !== 'screen-modal-overlay' && !event.target.classList.contains('modal-close-btn')) return;
    }
    document.getElementById('screen-modal-overlay').style.display = 'none';
    activeScreenTab = 'screen-debugtree';
  }

  function switchScreenTab(tab) {
    activeScreenTab = tab;
    document.querySelectorAll('.screen-tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.getAttribute('data-tab') === tab);
    });
    // Hide all screen tab contents
    document.getElementById('modal-tab-screen-debugtree').style.display = 'none';
    document.getElementById('modal-tab-screen-perf').style.display = 'none';

    const pane = document.getElementById('modal-tab-' + tab);
    if (pane) pane.style.display = 'block';
  }

  window.addEventListener('DOMContentLoaded', () => {
    pollAndRender();
    pollTimer = setInterval(pollAndRender, POLL_MS);
  });

''';
