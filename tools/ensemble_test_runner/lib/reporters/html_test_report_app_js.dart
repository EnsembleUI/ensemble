/// Client-side app script for the HTML report shell.
const ensembleHtmlTestReportAppJs = r'''

  const POLL_MS = 2000;
  let pollTimer = null;
  let renderedComplete = false;
  let activeFilter = 'all';
  let activeFeature = 'all';
  let activeProfile = 'all';
  let activeSort = 'execution';
  let activeModalTab = 'api';
  let currentModalCardId = '';
  let currentModalStepIndex = -1;
  let activeStorageSubTab = 'public';

  /** Screenshot overlay visibility — shared across step modal + fullscreen sheet.
   *  Sheet defaults: observation layers off (clear picture); action rings on. */
  const screenshotOverlayPrefs = {
    obsHighlights: false,
    obsLabels: false,
    actionHighlights: true,
  };

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

  /** Strip a shared screen-name prefix (e.g. ExtenderPositioning_) for readable journey chips. */
  function shortenScreenLabels(names) {
    const list = (names || []).map((n) => String(n || ''));
    if (list.length < 2) return { prefix: '', labels: list };
    let prefix = list[0];
    for (let i = 1; i < list.length; i++) {
      while (prefix && !list[i].startsWith(prefix)) {
        prefix = prefix.slice(0, -1);
      }
      if (!prefix) break;
    }
    const cut = Math.max(prefix.lastIndexOf('_'), prefix.lastIndexOf('/'), prefix.lastIndexOf('.'));
    if (cut < 2) return { prefix: '', labels: list };
    const shared = prefix.slice(0, cut + 1);
    const labels = list.map((n) => n.slice(shared.length) || n);
    if (labels.some((l) => !l)) return { prefix: '', labels: list };
    return { prefix: shared.slice(0, -1), labels: labels };
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
            secureStorageChanges: step.secureStorageChanges || [],
            keychainChanges: step.keychainChanges || [],
            screenshots: step.screenshots || [],
            observer: step.observer || null
          };
          step.apiCalls = parent.apiCalls;
          step.appLogs = parent.appLogs;
          step.storageChanges = parent.storageChanges;
          step.secureStorageChanges = parent.secureStorageChanges;
          step.keychainChanges = parent.keychainChanges;
          step.screenshots = parent.screenshots;
          step.observer = parent.observer;
        } else if (parent) {
          step.apiCalls = parent.apiCalls;
          step.appLogs = parent.appLogs;
          step.storageChanges = parent.storageChanges;
          step.secureStorageChanges = parent.secureStorageChanges;
          step.keychainChanges = parent.keychainChanges;
          step.screenshots = parent.screenshots;
          step.observer = parent.observer;
        } else {
          step.apiCalls = [];
          step.appLogs = [];
          step.storageChanges = [];
          step.secureStorageChanges = [];
          step.keychainChanges = [];
          step.screenshots = [];
          step.observer = null;
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

  let sqlJsPromise = null;

  async function loadSqlJs() {
    if (window.initSqlJs) {
      return await window.initSqlJs({
        locateFile: file => 'https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.10.3/' + file,
      });
    }

    await new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.10.3/sql-wasm.js';
      script.onload = resolve;
      script.onerror = () => reject(new Error('Could not load SQLite reader'));
      document.head.appendChild(script);
    });

    return await window.initSqlJs({
      locateFile: file => 'https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.10.3/' + file,
    });
  }

  function rowsFromStatement(statement) {
    const rows = [];
    while (statement.step()) {
      rows.push(statement.getAsObject());
    }
    statement.free();
    return rows;
  }

  let cachedDbBytes = null;
  async function getHistoryDb(forceFetch = false) {
    const SQL = await (sqlJsPromise ||= loadSqlJs());
    if (cachedDbBytes && !forceFetch) {
      return new SQL.Database(cachedDbBytes);
    }
    try {
      const res = await fetch('ensemble_test_history.db?t=' + Date.now(), { cache: 'no-store' });
      if (!res.ok) return null;
      cachedDbBytes = new Uint8Array(await res.arrayBuffer());
      return new SQL.Database(cachedDbBytes);
    } catch (e) {
      return null;
    }
  }

  async function loadHistory(forceFetch = false) {
    let db = null;
    try {
      db = await getHistoryDb(forceFetch);
      if (!db) return null;
      const runs = rowsFromStatement(db.prepare(`
        SELECT
          id,
          created_at AS createdAt,
          status,
          duration_ms AS durationMs,
          passed_tests AS passed,
          failed_tests AS failed,
          total_tests AS total,
          commit_hash AS commitHash,
          branch,
          build_number AS buildNumber,
          pr_number AS prNumber
        FROM runs
        ORDER BY id DESC
      `));
      return { runs };
    } catch (e) {
      return null;
    } finally {
      if (db) db.close();
    }
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
      showError('Waiting for test results... Serve the report folder over HTTP (e.g. Live Server).');
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
    const total = tests.length;
    const displayMs = summary.wallTimeMs != null ? summary.wallTimeMs : (summary.totalMs || 0);
    const successRate = total > 0 ? Math.round((passed / total) * 100) : 0;
    const summaryText = passed + ' passed, ' + failed + ' failed (' + total + ' total)';
    const summaryClass = failed === 0 ? 'passed' : 'failed';
    const metadata = report.metadata || {};
    const target = metadata.deviceName || metadata.deviceId || '';
    const executionLabel = metadata.mode
      ? ' · ' + metadata.mode + (target ? ' on ' + target : '')
      : '';

    document.getElementById('hero-summary').className = 'summary ' + summaryClass;
    document.getElementById('hero-summary').textContent = summaryText + ' · ' + formatDuration(displayMs) + executionLabel;

    let metrics = '';
    metrics += '<div class="metric-card"><div class="metric-val">' + total + '</div><div class="metric-label">Total Tests</div></div>';
    metrics += '<div class="metric-card metric-passed"><div class="metric-val">' + passed + '</div><div class="metric-label">Passed</div></div>';
    metrics += '<div class="metric-card metric-failed"><div class="metric-val">' + failed + '</div><div class="metric-label">Failed</div></div>';
    metrics += '<div class="metric-card metric-rate"><div class="metric-val">' + successRate + '%</div><div class="metric-label">Success Rate</div></div>';
    metrics += '<div class="metric-card metric-duration"><div class="metric-val">' + formatDuration(displayMs) + '</div><div class="metric-label">Suite Duration</div></div>';
    document.getElementById('metrics-grid').innerHTML = metrics;

    renderHistory(null);
    loadHistory().then(renderHistory);
    renderSuiteArtifacts(report.suiteArtifacts || []);

    window.currentReport = report;
    updateFeatureFilterOptions(tests);
    updateProfileFilterOptions(tests);

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
    window.stepMeta = {};
    window.storageSnapshots = {};
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

  function formatDateTime(value) {
    if (!value) return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    return date.toLocaleString();
  }

  function formatDurationShort(ms) {
    if (ms === 0) return '0s';
    const totalSeconds = Math.round(ms / 1000);
    if (totalSeconds < 60) return totalSeconds + 's';
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return seconds > 0 ? minutes + 'm' + seconds + 's' : minutes + 'm';
  }

  function drawDurationChart(chartRuns) {
    if (!chartRuns.length) return '<div class="no-chart-data">No data</div>';
    
    const width = 500;
    const height = 180;
    const paddingLeft = 45;
    const paddingRight = 15;
    const paddingTop = 20;
    const paddingBottom = 30;
    
    const chartWidth = width - paddingLeft - paddingRight;
    const chartHeight = height - paddingTop - paddingBottom;
    
    const durations = chartRuns.map(r => r.durationMs || 0);
    const maxVal = Math.max(...durations, 1000);
    const yMax = maxVal * 1.15; // 15% padding at top
    
    let yGrid = '';
    const ySegments = 4;
    for (let i = 0; i <= ySegments; i++) {
      const val = yMax * (i / ySegments);
      const y = height - paddingBottom - (val / yMax) * chartHeight;
      yGrid += '<line x1="' + paddingLeft + '" y1="' + y + '" x2="' + (width - paddingRight) + '" y2="' + y + '" stroke="rgba(255,255,255,0.06)" stroke-dasharray="3,3"/>';
      yGrid += '<text x="' + (paddingLeft - 8) + '" y="' + (y + 4) + '" fill="#9ca3af" font-size="9" text-anchor="end">' + formatDurationShort(val) + '</text>';
    }
    
    const points = [];
    const stepX = chartRuns.length > 1 ? chartWidth / (chartRuns.length - 1) : chartWidth;
    
    chartRuns.forEach((run, i) => {
      const x = paddingLeft + i * stepX;
      const y = height - paddingBottom - ((run.durationMs || 0) / yMax) * chartHeight;
      points.push({ x, y, run });
    });
    
    let pathD = '';
    let fillD = '';
    if (points.length) {
      pathD = 'M ' + points[0].x + ' ' + points[0].y;
      fillD = 'M ' + points[0].x + ' ' + (height - paddingBottom);
      fillD += ' L ' + points[0].x + ' ' + points[0].y;
      
      for (let i = 1; i < points.length; i++) {
        pathD += ' L ' + points[i].x + ' ' + points[i].y;
        fillD += ' L ' + points[i].x + ' ' + points[i].y;
      }
      
      fillD += ' L ' + points[points.length - 1].x + ' ' + (height - paddingBottom) + ' Z';
    }
    
    let circles = '';
    points.forEach((pt) => {
      const tooltipTitle = 'Run #' + pt.run.id;
      const tooltipRows = JSON.stringify([
        { label: 'Date', val: formatDateTime(pt.run.createdAt) },
        { label: 'Duration', val: formatDuration(pt.run.durationMs || 0) }
      ]);
      circles += '<circle cx="' + pt.x + '" cy="' + pt.y + '" r="4.5" fill="#06b6d4" stroke="#030712" stroke-width="1.5" class="chart-point" ' +
        'onmouseover="showChartTooltip(event, \'' + escapeHtml(tooltipTitle) + '\', ' + escapeHtml(tooltipRows) + ')" ' +
        'onmousemove="moveChartTooltip(event)" ' +
        'onmouseout="hideChartTooltip()"/>';
    });
    
    let xLabels = '';
    points.forEach((pt, i) => {
      if (points.length <= 10 || i % 2 === 0 || i === points.length - 1) {
        xLabels += '<text x="' + pt.x + '" y="' + (height - 10) + '" fill="#9ca3af" font-size="9" text-anchor="middle">#' + pt.run.id + '</text>';
      }
    });
    
    let svg = '<svg viewBox="0 0 ' + width + ' ' + height + '" width="100%" height="100%" xmlns="http://www.w3.org/2000/svg" style="overflow: visible;">';
    svg += '<defs>';
    svg += '  <linearGradient id="chartGradient" x1="0" y1="0" x2="0" y2="1">';
    svg += '    <stop offset="0%" stop-color="#06b6d4" stop-opacity="0.25"/>';
    svg += '    <stop offset="100%" stop-color="#06b6d4" stop-opacity="0.0"/>';
    svg += '  </linearGradient>';
    svg += '</defs>';
    svg += yGrid;
    if (fillD) svg += '<path d="' + fillD + '" fill="url(#chartGradient)"/>';
    if (pathD) svg += '<path d="' + pathD + '" fill="none" stroke="#06b6d4" stroke-width="2.5" style="filter: drop-shadow(0px 0px 4px rgba(6,182,212,0.6));"/>';
    svg += circles;
    svg += xLabels;
    svg += '</svg>';
    
    return svg;
  }

  function drawSuccessRateChart(chartRuns) {
    if (!chartRuns.length) return '<div class="no-chart-data">No data</div>';
    
    const width = 500;
    const height = 180;
    const paddingLeft = 45;
    const paddingRight = 15;
    const paddingTop = 20;
    const paddingBottom = 30;
    
    const chartWidth = width - paddingLeft - paddingRight;
    const chartHeight = height - paddingTop - paddingBottom;
    
    const maxTests = Math.max(...chartRuns.map(r => r.total || 0), 1);
    let yMax = 10;
    if (maxTests <= 5) yMax = 5;
    else if (maxTests <= 10) yMax = 10;
    else if (maxTests <= 25) yMax = 25;
    else if (maxTests <= 50) yMax = 50;
    else if (maxTests <= 100) yMax = 100;
    else yMax = Math.ceil(maxTests / 100) * 100;
    
    let yGrid = '';
    const ySegments = 4;
    for (let i = 0; i <= ySegments; i++) {
      const val = Math.round(yMax * (i / ySegments));
      const y = height - paddingBottom - (val / yMax) * chartHeight;
      yGrid += '<line x1="' + paddingLeft + '" y1="' + y + '" x2="' + (width - paddingRight) + '" y2="' + y + '" stroke="rgba(255,255,255,0.06)" stroke-dasharray="3,3"/>';
      yGrid += '<text x="' + (paddingLeft - 8) + '" y="' + (y + 4) + '" fill="#9ca3af" font-size="9" text-anchor="end">' + val + '</text>';
    }
    
    const barCount = chartRuns.length;
    const totalBarWidth = chartWidth / barCount;
    const singleBarWidth = Math.max(totalBarWidth * 0.35, 4);
    const gap = Math.max(totalBarWidth * 0.05, 1);
    
    let bars = '';
    let xLabels = '';
    
    chartRuns.forEach((run, i) => {
      const xPass = paddingLeft + i * totalBarWidth + (totalBarWidth - 2 * singleBarWidth - gap) / 2;
      const xFail = xPass + singleBarWidth + gap;
      
      const passed = Number(run.passed || 0);
      const failed = Number(run.failed || 0);
      const total = Number(run.total || 0);
      
      const passHeight = (passed / yMax) * chartHeight;
      const failHeight = (failed / yMax) * chartHeight;
      
      const yPass = height - paddingBottom - passHeight;
      const yFail = height - paddingBottom - failHeight;
      
      // Passed bar (green)
      if (passed > 0) {
        bars += '<rect x="' + xPass + '" y="' + yPass + '" width="' + singleBarWidth + '" height="' + passHeight + '" fill="#10b981" rx="2" class="chart-bar-segment"/>';
      } else {
        bars += '<rect x="' + xPass + '" y="' + (height - paddingBottom - 1) + '" width="' + singleBarWidth + '" height="1" fill="rgba(16, 185, 129, 0.25)"/>';
      }
      
      // Failed bar (red)
      if (failed > 0) {
        bars += '<rect x="' + xFail + '" y="' + yFail + '" width="' + singleBarWidth + '" height="' + failHeight + '" fill="#f43f5e" rx="2" class="chart-bar-segment"/>';
      } else {
        bars += '<rect x="' + xFail + '" y="' + (height - paddingBottom - 1) + '" width="' + singleBarWidth + '" height="1" fill="rgba(244, 63, 94, 0.25)"/>';
      }
      
      // Transparent overlay to trigger tooltip
      const hoverWidth = 2 * singleBarWidth + gap;
      const tooltipTitle = 'Run #' + run.id;
      const tooltipRows = JSON.stringify([
        { label: 'Total', val: total },
        { label: 'Passed', val: passed },
        { label: 'Failed', val: failed }
      ]);
      bars += '<rect x="' + xPass + '" y="' + (height - paddingBottom - chartHeight) + '" width="' + hoverWidth + '" height="' + chartHeight + '" fill="transparent" style="cursor: pointer;" ' +
        'onmouseover="showChartTooltip(event, \'' + escapeHtml(tooltipTitle) + '\', ' + escapeHtml(tooltipRows) + ')" ' +
        'onmousemove="moveChartTooltip(event)" ' +
        'onmouseout="hideChartTooltip()"/>';
      
      if (barCount <= 10 || i % 2 === 0 || i === barCount - 1) {
        xLabels += '<text x="' + (xPass + singleBarWidth + gap / 2) + '" y="' + (height - 10) + '" fill="#9ca3af" font-size="9" text-anchor="middle">#' + run.id + '</text>';
      }
    });
    
    let svg = '<svg viewBox="0 0 ' + width + ' ' + height + '" width="100%" height="100%" xmlns="http://www.w3.org/2000/svg" style="overflow: visible;">';
    svg += yGrid;
    svg += bars;
    svg += xLabels;
    svg += '</svg>';
    
    return svg;
  }

  async function renderHistory(history) {
    const host = document.getElementById('history-host');
    if (!host) return;
    const runs = (history && Array.isArray(history.runs)) ? history.runs : [];
    if (!runs.length) {
      host.innerHTML = '';
      return;
    }

    let runsCount = runs.length;
    let overallAvgDuration = 0;
    let overallSuccessRate = 0;
    let chartRuns = [];
    let db = null;

    try {
      db = await getHistoryDb();
      if (db) {
        const summary = rowsFromStatement(db.prepare(`
          SELECT
            COUNT(*) AS count,
            AVG(duration_ms) AS avgDuration,
            SUM(passed_tests) AS sumPassed,
            SUM(total_tests) AS sumTotal
          FROM runs
        `))[0];
        
        runsCount = summary.count || runs.length;
        overallAvgDuration = Math.round(summary.avgDuration || 0);
        overallSuccessRate = (summary.sumTotal || 0) > 0 ? Math.round((summary.sumPassed / summary.sumTotal) * 100) : 0;
      }
    } catch (e) {
      if (runs.length) {
        const sumDuration = runs.reduce((sum, r) => sum + (r.durationMs || 0), 0);
        overallAvgDuration = Math.round(sumDuration / runs.length);
        const totalPassed = runs.reduce((sum, r) => sum + (r.passed || 0), 0);
        const totalTests = runs.reduce((sum, r) => sum + (r.total || 0), 0);
        overallSuccessRate = totalTests > 0 ? Math.round((totalPassed / totalTests) * 100) : 0;
      }
    } finally {
      if (db) db.close();
    }

    chartRuns = [...runs].reverse().slice(-10);

    let html = '<section class="history-container">';
    html += '<div class="history-metrics-grid">';
    html += '  <div class="metric-card"><div class="metric-val">' + runsCount + '</div><div class="metric-label">Total Runs</div></div>';
    html += '  <div class="metric-card"><div class="metric-val">' + formatDuration(overallAvgDuration) + '</div><div class="metric-label">Average Duration</div></div>';
    html += '  <div class="metric-card"><div class="metric-val">' + overallSuccessRate + '%</div><div class="metric-label">Overall Success Rate</div></div>';
    html += '</div>';

    html += '<div class="history-charts-row">';
    html += '  <div class="history-chart-card">';
    html += '    <div class="history-chart-title">Execution Duration (Last 10 Runs)</div>';
    html += '    <div class="history-chart-body">' + drawDurationChart(chartRuns) + '</div>';
    html += '  </div>';
    html += '  <div class="history-chart-card">';
    html += '    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">';
    html += '      <div class="history-chart-title">Test Volume & Results (Last 10 Runs)</div>';
    html += '      <div style="display:flex; gap:12px; font-size:0.7rem; font-weight:700;">';
    html += '        <span style="display:flex; align-items:center; gap:5px; color:#94a3b8;"><span style="display:inline-block; width:8px; height:8px; background:#10b981; border-radius:2px;"></span>Passed</span>';
    html += '        <span style="display:flex; align-items:center; gap:5px; color:#94a3b8;"><span style="display:inline-block; width:8px; height:8px; background:#f43f5e; border-radius:2px;"></span>Failed</span>';
    html += '      </div>';
    html += '    </div>';
    html += '    <div class="history-chart-body">' + drawSuccessRateChart(chartRuns) + '</div>';
    html += '  </div>';
    html += '</div>';

    html += '<div class="history-card" style="margin-top:0;">';
    html += '<div class="history-header"><h2>Test Execution History</h2><span>' + runs.length + ' total runs</span></div>';
    html += '<div class="history-table-wrap"><table class="history-table">';
    html += '<thead><tr><th>Run ID</th><th>Date & Time</th><th>Status</th><th>Duration</th><th>Tests</th><th>Branch</th></tr></thead><tbody>';

    runs.forEach(run => {
      const status = String(run.status || 'unknown').toLowerCase();
      const statusClass = status === 'passed' ? 'passed' : 'failed';
      const passed = Number(run.passed || 0);
      const total = Number(run.total || 0);
      const failed = Number(run.failed || 0);
      const testsText = failed
        ? (passed + ' passed, ' + failed + ' failed')
        : (passed + '/' + total);
      
      const branch = run.branch ? String(run.branch) : '';
      
      const isCollapsible = failed > 0;
      if (isCollapsible) {
        html += '<tr onclick="toggleHistoryRunDetails(' + run.id + ')" style="cursor: pointer;">';
        html += '<td><span class="history-caret" id="history-caret-' + run.id + '">▶</span>#' + escapeHtml(run.id || '') + '</td>';
      } else {
        html += '<tr>';
        html += '<td>#' + escapeHtml(run.id || '') + '</td>';
      }
      
      html += '<td>' + escapeHtml(formatDateTime(run.createdAt)) + '</td>';
      html += '<td><span class="history-status ' + escapeHtml(statusClass) + '">' + escapeHtml(status) + '</span></td>';
      html += '<td>' + escapeHtml(formatDuration(run.durationMs || 0)) + '</td>';
      html += '<td>' + escapeHtml(testsText) + '</td>';
      html += '<td>' + escapeHtml(branch || '-') + '</td>';
      html += '</tr>';
      
      if (isCollapsible) {
        html += '<tr class="history-detail-row" id="history-details-' + run.id + '" style="display: none;">';
        html += '<td colspan="6"><div class="run-details-expanded-container"></div></td>';
        html += '</tr>';
      }
    });

    html += '</tbody></table></div></div></section>';
    host.innerHTML = html;
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
    const groupPassed = runs.every(r => r.status === 'passed');
    const maxDurationMs = Math.max(...runs.map(r => r.durationMs || 0));
    const cardId = anchorId(first.id);
    const statusClass = groupPassed ? 'passed' : 'failed';
    const el = document.createElement('article');
    el.className = 'test ' + statusClass;
    el.id = cardId;
    el.dataset.features = Array.from(new Set(runs.map(run => run.feature || '').filter(Boolean))).join('|');
    el.dataset.profiles = Array.from(new Set(runs.map(run => run.profile || '').filter(Boolean))).join('|');
    let badges = '';
    const seenBadges = new Set();
    runs.forEach(run => {
      if (run.deviceBadge) {
        const badge = String(run.deviceBadge).toUpperCase();
        if (!seenBadges.has(badge)) {
          seenBadges.add(badge);
          badges += '<span class="card-device-badge">' + escapeHtml(badge) + '</span>';
        }
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
      scheduleScreenshotChipLayout(details);
    };
    return el;
  }

  function deviceButtonText(badge) {
    if (!badge) return 'Device';
    const parts = badge.split('_');
    return parts.map(p => p.charAt(0).toUpperCase() + p.slice(1)).join(' ');
  }

  function deviceRunLabel(run) {
    const device = run.device || {};
    if (device.id) return deviceButtonText(String(device.id));
    return deviceButtonText(run.deviceBadge);
  }

  function scenarioRunLabel(run) {
    if (!run.scenarioId) return '';
    return String(run.scenarioId)
      .split(/[_-]+/)
      .filter(Boolean)
      .map(p => p.charAt(0).toUpperCase() + p.slice(1))
      .join(' ');
  }

  function deviceRunKey(run) {
    const device = run.device || {};
    return String(device.id || run.deviceBadge || 'default');
  }

  function groupedDeviceRuns(runs) {
    const groups = [];
    const byKey = {};
    runs.forEach((run, runIndex) => {
      const key = deviceRunKey(run);
      if (!byKey[key]) {
        byKey[key] = {
          key: key,
          label: deviceRunLabel(run),
          entries: []
        };
        groups.push(byKey[key]);
      }
      byKey[key].entries.push({ run: run, runIndex: runIndex });
    });
    return groups;
  }

  function buildDetailsGroup(base, runs) {
    const cardId = anchorId(runs[0].id);
    const wrap = document.createElement('div');
    wrap.className = 'test-detail-content';
    wrap.id = 'details-' + cardId;
    wrap.style.display = 'none';

    let html = '';
    const deviceGroups = groupedDeviceRuns(runs);
    const hasScenarioSelectors = deviceGroups.some(group => group.entries.filter(entry => entry.run.scenarioId).length > 1);
    if (deviceGroups.length > 1 || hasScenarioSelectors) {
      html += '<div class="run-selector-panel">';
    }
    if (deviceGroups.length > 1) {
      html += '<div class="run-selector-row device-selector-row"><span class="selector-label">Device Runs</span><div class="device-tabs">';
      deviceGroups.forEach((group, i) => {
        html += '<button class="device-tab-btn" data-device="' + i + '">' + escapeHtml(group.label) + '</button>';
      });
      html += '</div></div>';
    }

    deviceGroups.forEach((group, deviceIndex) => {
      const scenarioEntries = group.entries.filter(entry => entry.run.scenarioId);
      if (scenarioEntries.length > 1) {
        const display = deviceGroups.length === 1 ? 'flex' : 'none';
        html += '<div class="run-selector-row scenario-selector-bar" data-device="' + deviceIndex + '" style="display: ' + display + ';"><span class="selector-label">Scenarios</span><div class="device-tabs">';
        scenarioEntries.forEach(entry => {
          html += '<button class="scenario-tab-btn device-tab-btn" data-run="' + entry.runIndex + '">' + escapeHtml(scenarioRunLabel(entry.run) || 'Scenario') + '</button>';
        });
        html += '</div></div>';
      }
    });
    if (deviceGroups.length > 1 || hasScenarioSelectors) {
      html += '</div>';
    }

    runs.forEach((test, i) => {
      const stepKey = cardId + '-' + i;
      window.stepData[stepKey] = test.steps || [];
      window.stepMeta[stepKey] = {
        message: test.message || null,
        failedStepIndex: test.failedStepIndex != null ? test.failedStepIndex : null,
      };
      window.storageSnapshots[stepKey] = test.storage || {};
      html += buildRunBlock(base, test, cardId, i, stepKey);
    });
    wrap.innerHTML = html;

    function showRun(runIndex) {
      wrap.querySelectorAll('.device-run-block').forEach(r => r.style.display = 'none');
      const run = document.getElementById('run-' + cardId + '-' + runIndex);
      if (run) run.style.display = 'block';
      scheduleScreenshotChipLayout(run || wrap);
    }

    function showDevice(deviceIndex) {
      wrap.querySelectorAll('.device-tab-btn[data-device]').forEach(b => b.classList.remove('active'));
      const deviceBtn = wrap.querySelector('.device-tab-btn[data-device="' + deviceIndex + '"]');
      if (deviceBtn) deviceBtn.classList.add('active');

      wrap.querySelectorAll('.scenario-selector-bar').forEach(bar => bar.style.display = 'none');
      const scenarioBar = wrap.querySelector('.scenario-selector-bar[data-device="' + deviceIndex + '"]');
      if (scenarioBar) {
        scenarioBar.style.display = 'flex';
        const firstScenario = scenarioBar.querySelector('.scenario-tab-btn');
        if (firstScenario) {
          firstScenario.click();
          return;
        }
      }

      const firstEntry = deviceGroups[deviceIndex] && deviceGroups[deviceIndex].entries[0];
      if (firstEntry) showRun(firstEntry.runIndex);
    }

    wrap.querySelectorAll('.device-tab-btn[data-device]').forEach(btn => {
      btn.onclick = function() {
        showDevice(Number(btn.getAttribute('data-device')));
      };
    });

    wrap.querySelectorAll('.scenario-tab-btn').forEach(btn => {
      btn.onclick = function() {
        const bar = btn.closest('.scenario-selector-bar');
        if (bar) bar.querySelectorAll('.scenario-tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        showRun(btn.getAttribute('data-run'));
      };
    });
    return wrap;
  }

  function buildRunBlock(base, test, cardId, i, stepKey) {
    const passed = test.status === 'passed';
    const badge = test.deviceBadge || '';
    const device = test.device || {};
    let html = '<div class="device-run-block" id="run-' + cardId + '-' + i + '" style="display: none;">';
    html += '<div class="test-card-header"><div class="title-section"><h2>';
    html += '<span class="icon">' + (passed ? '✓' : '✗') + '</span> ' + escapeHtml(base) + '</h2>';
    if (badge || device.id || device.platform) {
      const platform = String(device.platform || badge || '').toLowerCase();
      const id = String(device.id || badge || '').toUpperCase();
      const locale = String(device.locale || '').toLowerCase();
      const lower = (platform + ' ' + id).toLowerCase();
      const isAndroid = lower.includes('android') || lower.includes('samsung') || lower.includes('pixel');
      const isIos = lower.includes('ios') || lower.includes('iphone');
      const hasNl = locale === 'nl' || locale.startsWith('nl_') || locale.startsWith('nl-');
      const hasEn = locale === 'en' || locale.startsWith('en_') || locale.startsWith('en-');
      const badgeClass = isAndroid ? 'android' : (isIos ? 'ios' : 'default');
      const iconName = isAndroid ? 'Android' : (isIos ? 'iOS' : 'Device');
      const flagStr = hasNl ? ' 🇳🇱 DUTCH (NL)' : (hasEn ? ' 🇬🇧 ENGLISH (EN)' : '');
      html += '<span class="device-pill ' + badgeClass + '">' + iconName + ' · ' + escapeHtml(id) + flagStr + '</span>';
      if (device.model) {
        html += '<span class="device-pill default">' + escapeHtml(device.model) + '</span>';
      }
    }
    const statusText = passed ? 'PASSED' : 'FAILED';
    const statusCapsuleClass = passed ? 'passed' : 'failed';
    html += '</div><div class="status-capsule ' + statusCapsuleClass + '">' + statusText + '</div></div>';

    if (test.filePath) {
      html += '<p class="file-path-sub"><span>File:</span> ' + escapeHtml(test.filePath) + '</p>';
    }
    if (test.description) {
      html += '<p class="test-description">' + escapeHtml(test.description) + '</p>';
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
      const screensMap = report.screens || {};
      const shortened = shortenScreenLabels(visited);
      const uniqueCount = new Set(visited).size;
      const seenCounts = {};
      html += '<div class="flow-timeline">';
      html += '<div class="flow-header"><div class="flow-label">Flow Journey</div><div class="flow-meta">';
      html += '<span class="flow-meta-chip"><strong>' + visited.length + '</strong> screen' + (visited.length === 1 ? '' : 's') + '</span>';
      if (uniqueCount !== visited.length) {
        html += '<span class="flow-meta-chip"><strong>' + uniqueCount + '</strong> unique</span>';
      }
      if (shortened.prefix) {
        html += '<span class="flow-meta-chip prefix" title="Shared screen prefix">' + escapeHtml(shortened.prefix) + '</span>';
      }
      html += '</div></div><div class="flow-track">';
      visited.forEach((s, j) => {
        seenCounts[s] = (seenCounts[s] || 0) + 1;
        const visitNum = seenCounts[s];
        const isRevisit = visitNum > 1;
        const hasData = screensMap[s] !== undefined;
        const label = shortened.labels[j] || s;
        const classes = ['flow-node'];
        if (j === 0) classes.push('start');
        if (j === visited.length - 1) classes.push('end');
        if (isRevisit) classes.push('revisit');
        if (hasData) classes.push('interactive');
        const titleParts = [s];
        if (isRevisit) titleParts.push('visit #' + visitNum);
        if (hasData) titleParts.push('Click for widget tree & performance');
        const title = titleParts.join(' · ');
        const tag = hasData ? 'button' : 'span';
        const typeAttr = hasData ? ' type="button"' : '';
        const clickAttr = hasData
          ? ' onclick="openScreenDialog(\'' + anchorId(test.id) + '\', \'' + String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'") + '\')"'
          : '';
        html += '<' + tag + typeAttr + ' class="' + classes.join(' ') + '" title="' + escapeHtml(title) + '"' + clickAttr + '>';
        html += '<span class="flow-idx">' + (j + 1) + '</span>';
        html += '<span class="flow-name">' + escapeHtml(label) + '</span>';
        if (isRevisit) html += '<span class="flow-revisit">×' + visitNum + '</span>';
        if (hasData) html += '<span class="flow-inspect" aria-hidden="true"></span>';
        html += '</' + tag + '>';
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
        const skipped = !nested && test.failedStepIndex != null && top > test.failedStepIndex;
        const speedClass = durationMs == null ? 'fast' : (durationMs < 500 ? 'fast' : (durationMs < 2000 ? 'normal' : 'slow'));
        html += '<div class="timeline-step-row' + (failed ? ' failed-step' : (skipped ? ' skipped-step' : '')) + '" style="cursor:pointer;" onclick="openStepDialog(\'' + stepKey + '\', ' + j + ')">';
        html += '<div class="timeline-marker"><span class="marker-dot"></span></div><div class="step-outline-body"><div class="step-outline-top-row">';
        html += '<div class="step-outline-text">' + formatStepText(line) + '</div>';
        if (durationMs != null) html += '<span class="step-duration ' + speedClass + '">' + escapeHtml(formatDuration(durationMs)) + '</span>';
        html += '</div>';
        if (failed && test.message) html += '<div class="step-error-reason">' + escapeHtml(test.message) + '</div>';
        html += '</div></div>';
      });
      html += '</div></div>';
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

  /** Screenshot frames paired with that step's Observer overlays (for gallery/sheet). */
  function flattenScreenshotFramesWithOverlays(test) {
    const out = [];
    const steps = test.steps || [];
    for (let i = 0; i < steps.length; i++) {
      const step = steps[i] || {};
      if (String(step.stepText || '').startsWith('  ')) continue;
      const items = step.screenshots || [];
      const overlays = (step.observer && Array.isArray(step.observer.overlays))
        ? step.observer.overlays
        : [];
      for (let j = 0; j < items.length; j++) {
        out.push({ frame: items[j], overlays: overlays });
      }
    }
    return out;
  }

  function renderTerminals(test) {
    const consoleLines = flattenStepField(test, 'appLogs');
    const events = flattenStepField(test, 'apiCalls');
    const storage = test.storage || {};
    const keys = storage.keys || {};
    const secureKeys = storage.secureStorageKeys || {};
    const keychainKeys = storage.keychainKeys || {};
    let storageContent = '';
    try { storageContent = JSON.stringify(keys, null, 2); } catch (e) { storageContent = String(keys); }

    let html = '<div class="logs-grid-container">';
    html += '<div class="logs-card-pane"><div class="logs-pane-title"><span>📝 Actions & Console Logs</span>';
    html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'logs\')">⛶ Open Fullscreen</button></div>';
    html += '<div class="logs-terminal">' + renderConsoleRows(consoleLines) + '</div></div>';

    html += '<div class="logs-card-pane"><div class="logs-pane-title"><span>🌐 Network API Logs</span>';
    html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'apis\')">⛶ Open Fullscreen</button></div>';
    html += '<div class="logs-terminal">' + renderApiRows(events) + '</div></div></div>';

    const hasKeys = Object.keys(keys).length > 0;
    const hasSecure = Object.keys(secureKeys).length > 0;
    const hasKeychain = Object.keys(keychainKeys).length > 0;

    if (hasKeys || hasSecure || hasKeychain) {
      html += '<div class="storage-grid-container">';
      if (hasKeys) {
        html += '<div class="logs-card-pane"><div class="logs-pane-title"><span>💾 Local State Storage</span>';
        html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'storage\')">⛶ Open Fullscreen</button></div>';
        html += '<div class="logs-terminal"><div class="terminal-row">' + escapeHtml(storageContent) + '</div></div></div>';
      }
      if (hasSecure) {
        html += '<div class="logs-card-pane"><div class="logs-pane-title"><span>🔐 Secure Storage</span>';
        html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'secureStorage\')">⛶ Open Fullscreen</button></div>';
        html += '<div class="logs-terminal"><div class="terminal-row">' + escapeHtml(JSON.stringify(secureKeys, null, 2)) + '</div></div></div>';
      }
      if (hasKeychain) {
        html += '<div class="logs-card-pane"><div class="logs-pane-title"><span>🔑 Keychain</span>';
        html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'keychain\')">⛶ Open Fullscreen</button></div>';
        html += '<div class="logs-terminal"><div class="terminal-row">' + escapeHtml(JSON.stringify(keychainKeys, null, 2)) + '</div></div></div>';
      }
      html += '</div>';
    }
    return html;
  }

  function renderScreenshotGallery(test) {
    const frames = flattenScreenshotFramesWithOverlays(test);
    if (!frames.length) return '';
    let html = '<div class="screenshot-artifacts-row"><div class="artifact screenshot-artifact-card">';
    html += '<div class="logs-pane-title" style="border:none;padding:0 0 12px 0;"><span style="font-weight:800;font-size:0.8rem;text-transform:uppercase;color:var(--accent);letter-spacing:0.08em;">🖼️ Screenshots</span>';
    html += '<button class="fullscreen-sheet-btn" onclick="openFullscreenCard(this, \'screenshots\')">⛶ Open Fullscreen</button></div>';
    html += screenshotOverlayToolbarHtml();
    html += '<div class="screenshot-gallery">';
    frames.forEach((entry, idx) => {
      const frame = entry.frame || {};
      const overlays = entry.overlays || [];
      const href = frame.href || '';
      const label = frame.screen || frame.label || frame.file || ('Frame ' + (idx + 1));
      const failed = frame.failed === true;
      let pillIndex = idx + 1;
      let cleanLabel = label;
      const match = label.match(/^(\d+)\.\s*(.*)$/);
      if (match) {
        pillIndex = match[1];
        cleanLabel = match[2];
      }
      html += '<figure class="screenshot-gallery-tile' + (failed ? ' failed' : '') + '">';
      html += '<div class="screenshot-tile-header-bar"><span class="screenshot-index-pill">' + pillIndex + '</span>';
      html += '<span class="screenshot-tile-caption" title="' + escapeHtml(label) + '">' + escapeHtml(cleanLabel) + '</span></div>';
      html += '<div class="screenshot-gallery-frame">';
      if (href) html += renderScreenshotImage(frame, label, overlays);
      html += '</div></figure>';
    });
    html += '</div></div></div>';
    return html;
  }

  function applySearchFilter() {
    const q = (document.getElementById('search-input').value || '').toLowerCase().trim();
    const f = activeFilter || 'all';
    const feature = activeFeature || 'all';
    const profile = activeProfile || 'all';
    document.querySelectorAll('.test').forEach(c => {
      const matchQ = c.id.toLowerCase().includes(q) || c.innerText.toLowerCase().includes(q);
      const matchF = f === 'all' || (f === 'passed' && c.classList.contains('passed')) || (f === 'failed' && c.classList.contains('failed'));
      const features = (c.dataset.features || '').split('|').filter(Boolean);
      const matchFeature = feature === 'all' || features.includes(feature);
      const profiles = (c.dataset.profiles || '').split('|').filter(Boolean);
      const matchProfile = profile === 'all' || profiles.includes(profile);
      c.style.display = (matchQ && matchF && matchFeature && matchProfile) ? 'flex' : 'none';
    });
  }

  function setFilter(f) {
    activeFilter = f;
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.toggle('active', b.getAttribute('data-filter') === f));
    applySearchFilter();
  }

  function updateFeatureFilterOptions(tests) {
    const select = document.getElementById('feature-select');
    if (!select) return;
    const previous = activeFeature || select.value || 'all';
    const features = Array.from(new Set((tests || []).map(t => t.feature).filter(Boolean))).sort((a, b) => a.localeCompare(b));
    const wrapper = select.closest('.sort-wrapper');
    if (wrapper) wrapper.style.display = features.length > 1 ? '' : 'none';
    if (features.length <= 1) {
      activeFeature = 'all';
      select.value = 'all';
      return;
    }
    select.innerHTML = '<option value="all">All Features</option>' + features.map(feature => '<option value="' + escapeHtml(feature) + '">' + escapeHtml(feature) + '</option>').join('');
    activeFeature = features.includes(previous) ? previous : 'all';
    select.value = activeFeature;
  }

  function applyFeatureFilter() {
    const select = document.getElementById('feature-select');
    activeFeature = select ? select.value : 'all';
    applySearchFilter();
  }

  function updateProfileFilterOptions(tests) {
    const select = document.getElementById('profile-select');
    if (!select) return;
    const previous = activeProfile || select.value || 'all';
    const profiles = Array.from(new Set((tests || []).map(t => t.profile).filter(Boolean))).sort((a, b) => a.localeCompare(b));
    const wrapper = select.closest('.sort-wrapper');
    if (wrapper) wrapper.style.display = profiles.length > 1 ? '' : 'none';
    if (profiles.length <= 1) {
      activeProfile = 'all';
      select.value = 'all';
      return;
    }
    select.innerHTML = '<option value="all">All Profiles</option>' + profiles.map(profile => '<option value="' + escapeHtml(profile) + '">' + escapeHtml(profile) + '</option>').join('');
    activeProfile = profiles.includes(previous) ? previous : 'all';
    select.value = activeProfile;
  }

  function applyProfileFilter() {
    const select = document.getElementById('profile-select');
    activeProfile = select ? select.value : 'all';
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
  function stepFailureMessage(deviceData, stepIndex, meta) {
    const message = meta && meta.message;
    const failedStepIndex = meta && meta.failedStepIndex;
    if (!message || failedStepIndex == null) return null;
    const step = deviceData[stepIndex];
    if (!step) return null;
    if (String(step.stepText || '').startsWith('  ')) return null;
    let top = -1;
    const keys = Object.keys(deviceData)
      .map(k => parseInt(k, 10))
      .filter(n => !isNaN(n) && n <= stepIndex)
      .sort((a, b) => a - b);
    for (const key of keys) {
      const text = String((deviceData[key] && deviceData[key].stepText) || '');
      if (!text.startsWith('  ')) top++;
    }
    return top === failedStepIndex ? message : null;
  }

  function getStorageStateAtStep(cardId, targetStepIndex, field) {
    const deviceData = window.stepData && window.stepData[cardId];
    if (!deviceData) return {};
    const stepKeys = Object.keys(deviceData).map(k => parseInt(k, 10)).filter(n => !isNaN(n)).sort((a, b) => a - b);
    const snapshot = window.storageSnapshots && window.storageSnapshots[cardId];
    const snapshotField = field === 'secureStorageChanges' ? 'secureStorageKeys' : field === 'keychainChanges' ? 'keychainKeys' : 'keys';
    const state = Object.assign({}, (snapshot && snapshot[snapshotField]) || {});
    // Rewind the final snapshot to the state immediately after the requested
    // step so initial values remain visible even if they never changed.
    for (let i = stepKeys.length - 1; i > targetStepIndex; i--) {
      const stepObj = deviceData[stepKeys[i]];
      const changes = (stepObj && stepObj[field || 'storageChanges']) || [];
      for (const change of changes) {
        const key = change.key;
        if (!key) continue;
        const kind = (change.change || '').toLowerCase();
        if (kind === 'added') delete state[key];
        else if (kind === 'removed' || kind === 'modified') state[key] = change.before;
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

    const errorEl = document.getElementById('modal-step-error');
    const meta = (window.stepMeta && window.stepMeta[cardId]) || {};
    const stepError = stepFailureMessage(deviceData, currentModalStepIndex, meta);
    if (stepError) {
      errorEl.style.display = 'block';
      errorEl.textContent = stepError;
      if (data.observer && typeof data.observer === 'object') {
        // Overlays live on the failure screenshot — open that tab by default.
        activeModalTab = 'screenshots';
      }
    } else {
      errorEl.style.display = 'none';
      errorEl.textContent = '';
    }

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
    storageList.className = 'modal-list storage-tab-content';
    const storageSubTabs = document.createElement('div');
    storageSubTabs.className = 'storage-sub-tabs';
    const storagePanels = document.createElement('div');
    storagePanels.className = 'storage-sub-panels';
    const publicStoragePanel = document.createElement('div');
    const secureStoragePanel = document.createElement('div');
    const keychainPanel = document.createElement('div');
    publicStoragePanel.className = 'storage-sub-panel logs-terminal';
    secureStoragePanel.className = 'storage-sub-panel';
    keychainPanel.className = 'storage-sub-panel';
    const publicStorageList = publicStoragePanel;
    const storageSubTabDefinitions = [
      { id: 'public', label: 'Public Storage', panel: publicStoragePanel },
      { id: 'secure', label: 'Secure Storage', panel: secureStoragePanel },
      { id: 'keychain', label: 'Keychain', panel: keychainPanel }
    ];
    storageSubTabDefinitions.forEach(definition => {
      const button = document.createElement('button');
      button.className = 'storage-sub-tab-btn' + (definition.id === activeStorageSubTab ? ' active' : '');
      button.textContent = definition.label;
      button.onclick = () => {
        activeStorageSubTab = definition.id;
        storageSubTabDefinitions.forEach(item => {
          item.panel.style.display = item.id === activeStorageSubTab ? 'block' : 'none';
        });
        storageSubTabs.querySelectorAll('.storage-sub-tab-btn').forEach(item => item.classList.remove('active'));
        button.classList.add('active');
      };
      storageSubTabs.appendChild(button);
      definition.panel.style.display = definition.id === activeStorageSubTab ? 'block' : 'none';
      storagePanels.appendChild(definition.panel);
    });
    storageList.appendChild(storageSubTabs);
    storageList.appendChild(storagePanels);
    const storageChanges = data.storageChanges || [];
    document.getElementById('modal-storage-count').textContent = storageChanges.length;
    const currentState = getStorageStateAtStep(cardId, stepIndex);
    const changedKeys = new Set(storageChanges.map(c => c.key).filter(Boolean));
    if (!storageChanges.length && Object.keys(currentState).length === 0) {
      publicStorageList.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no storage changes for this step&gt;</div>';
    } else {
      storageChanges.forEach(change => {
        const key = change.key || '(unknown)';
        const kind = (change.change || '').toLowerCase();
        let badgeClass = 'info', badgeText = 'MOD', valueColor = 'var(--accent)';
        const row = document.createElement('div');
        row.className = 'terminal-row';

        if (kind === 'added') {
          badgeClass = 'passed';
          badgeText = 'ADD';
          valueColor = 'var(--pass)';
          const formatted = prettyFormatStorageValue(change.after);
          const isLong = formatted.length > 80 || formatted.includes('\n');
          if (isLong) {
            row.className = 'terminal-row storage-collapsible';
            row.innerHTML = '<div class="storage-header" onclick="toggleStorageDetails(this)"><span class="api-caret">▶</span><span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span class="storage-key-name">' + escapeHtml(key) + '</span><span class="storage-summary-preview">Value added (click to view)</span></div>' +
                            '<div class="storage-details" style="display: none;"><pre class="storage-pretty-val">' + escapeHtml(formatted) + '</pre></div>';
          } else {
            row.innerHTML = '<span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span class="storage-key-name">' + escapeHtml(key) + '</span> <span style="color: ' + valueColor + ';">' + escapeHtml(formatStorageValue(change.after)) + '</span>';
          }
        }
        else if (kind === 'removed') {
          badgeClass = 'failed';
          badgeText = 'DEL';
          valueColor = 'var(--fail)';
          const formatted = prettyFormatStorageValue(change.before);
          const isLong = formatted.length > 80 || formatted.includes('\n');
          if (isLong) {
            row.className = 'terminal-row storage-collapsible';
            row.innerHTML = '<div class="storage-header" onclick="toggleStorageDetails(this)"><span class="api-caret">▶</span><span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span class="storage-key-name">' + escapeHtml(key) + '</span><span class="storage-summary-preview">Value removed (click to view)</span></div>' +
                            '<div class="storage-details" style="display: none;"><pre class="storage-pretty-val">' + escapeHtml(formatted) + '</pre></div>';
          } else {
            row.innerHTML = '<span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span class="storage-key-name">' + escapeHtml(key) + '</span> <span style="color: ' + valueColor + ';">' + escapeHtml(formatStorageValue(change.before)) + '</span>';
          }
        }
        else {
          const beforeFormatted = prettyFormatStorageValue(change.before);
          const afterFormatted = prettyFormatStorageValue(change.after);
          const isLong = beforeFormatted.length > 40 || afterFormatted.length > 40 || beforeFormatted.includes('\n') || afterFormatted.includes('\n');

          if (isLong) {
            row.className = 'terminal-row storage-collapsible';
            row.innerHTML = '<div class="storage-header" onclick="toggleStorageDetails(this)"><span class="api-caret">▶</span><span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span class="storage-key-name">' + escapeHtml(key) + '</span><span class="storage-summary-preview">Value modified (click to compare)</span></div>' +
                            '<div class="storage-details" style="display: none;">' +
                            '  <div class="storage-diff-container">' +
                            '    <div class="storage-diff-pane before">' +
                            '      <div class="storage-diff-header">Before</div>' +
                            '      <pre class="storage-diff-pre">' + escapeHtml(beforeFormatted) + '</pre>' +
                            '    </div>' +
                            '    <div class="storage-diff-pane after">' +
                            '      <div class="storage-diff-header">After</div>' +
                            '      <pre class="storage-diff-pre">' + escapeHtml(afterFormatted) + '</pre>' +
                            '    </div>' +
                            '  </div>' +
                            '</div>';
          } else {
            row.innerHTML = '<span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span class="storage-key-name">' + escapeHtml(key) + '</span> <span style="color: var(--text-muted);">' + escapeHtml(formatStorageValue(change.before)) + '</span> <span style="color: var(--accent); font-weight: bold; margin: 0 6px;">→</span> <span style="color: var(--accent);">' + escapeHtml(formatStorageValue(change.after)) + '</span>';
          }
        }
        publicStorageList.appendChild(row);
      });
      Object.keys(currentState).filter(k => !changedKeys.has(k)).sort().forEach(key => {
        const val = currentState[key];
        const formatted = prettyFormatStorageValue(val);
        const isLong = formatted.length > 80 || formatted.includes('\n');
        const row = document.createElement('div');
        row.className = 'terminal-row';
        if (isLong) {
          row.className = 'terminal-row storage-collapsible';
          row.innerHTML = '<div class="storage-header" onclick="toggleStorageDetails(this)"><span class="api-caret">▶</span><span class="terminal-badge info" style="background: rgba(255,255,255,0.06); color: var(--text-muted); border: 1px solid rgba(255,255,255,0.15); margin-right: 6px;">VAL</span><span class="storage-key-name" style="color: var(--text-muted);">' + escapeHtml(key) + '</span><span class="storage-summary-preview">Value view (click to inspect)</span></div>' +
                          '<div class="storage-details" style="display: none;"><pre class="storage-pretty-val">' + escapeHtml(formatted) + '</pre></div>';
        } else {
          row.innerHTML = '<span class="terminal-badge info" style="background: rgba(255,255,255,0.06); color: var(--text-muted); border: 1px solid rgba(255,255,255,0.15); margin-right: 6px;">VAL</span><span style="font-weight: 700; color: var(--text-muted);">' + escapeHtml(key) + '</span> <span style="color: #cbd5e1;">' + escapeHtml(formatStorageValue(val)) + '</span>';
        }
        publicStorageList.appendChild(row);
      });
    }

    function appendSimpleStorageSection(title, changesField, stateField, target) {
      const changes = data[changesField] || [];
      const state = getStorageStateAtStep(cardId, stepIndex, changesField);
      const section = document.createElement('div');
      section.style.marginTop = '18px';
      const body = document.createElement('div');
      body.className = 'logs-terminal';
      if (!changes.length && !Object.keys(state).length) {
        body.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no changes&gt;</div>';
      } else {
        changes.forEach(change => {
          const key = change.key || '(unknown)';
          const row = document.createElement('div');
          const kind = (change.change || '').toLowerCase();
          let badgeClass = 'info', badgeText = 'MOD';
          if (kind === 'added') {
            badgeClass = 'passed';
            badgeText = 'ADD';
          } else if (kind === 'removed') {
            badgeClass = 'failed';
            badgeText = 'DEL';
          }
          const beforeFormatted = change.before === undefined ? '' : prettyFormatStorageValue(change.before);
          const afterFormatted = change.after === undefined ? '' : prettyFormatStorageValue(change.after);
          const isLong = beforeFormatted.length > 40 || afterFormatted.length > 40 || beforeFormatted.includes('\n') || afterFormatted.includes('\n');
          if (isLong) {
            row.className = 'terminal-row storage-collapsible';
            let details = '';
            if (kind === 'modified') {
              details = '<div class="storage-diff-container">' +
                '<div class="storage-diff-pane before"><div class="storage-diff-header">Before</div><pre class="storage-diff-pre">' + escapeHtml(beforeFormatted) + '</pre></div>' +
                '<div class="storage-diff-pane after"><div class="storage-diff-header">After</div><pre class="storage-diff-pre">' + escapeHtml(afterFormatted) + '</pre></div>' +
                '</div>';
            } else {
              const value = kind === 'removed' ? beforeFormatted : afterFormatted;
              details = '<pre class="storage-pretty-val">' + escapeHtml(value) + '</pre>';
            }
            const summary = kind === 'added' ? 'Value added (click to view)' : kind === 'removed' ? 'Value removed (click to view)' : 'Value modified (click to compare)';
            row.innerHTML = '<div class="storage-header" onclick="toggleStorageDetails(this)"><span class="api-caret">▶</span><span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span class="storage-key-name">' + escapeHtml(key) + '</span><span class="storage-summary-preview">' + summary + '</span></div><div class="storage-details" style="display: none;">' + details + '</div>';
          } else if (kind === 'modified') {
            row.innerHTML = '<span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span class="storage-key-name">' + escapeHtml(key) + '</span> <span style="color: var(--text-muted);">' + escapeHtml(beforeFormatted) + '</span> <span style="color: var(--accent); font-weight: bold; margin: 0 6px;">→</span> <span style="color: var(--accent);">' + escapeHtml(afterFormatted) + '</span>';
          } else {
            const value = kind === 'removed' ? beforeFormatted : afterFormatted;
            const color = kind === 'added' ? 'var(--pass)' : kind === 'removed' ? 'var(--fail)' : 'var(--accent)';
            row.innerHTML = '<span class="terminal-badge ' + badgeClass + '">' + badgeText + '</span><span class="storage-key-name">' + escapeHtml(key) + '</span> <span style="color: ' + color + ';">' + escapeHtml(value) + '</span>';
          }
          body.appendChild(row);
        });
        Object.keys(state).filter(k => !changes.some(c => c.key === k)).sort().forEach(key => {
          const formatted = prettyFormatStorageValue(state[key]);
          const row = document.createElement('div');
          row.className = 'terminal-row';
          const isLong = formatted.length > 80 || formatted.includes('\n');
          if (isLong) {
            row.className = 'terminal-row storage-collapsible';
            row.innerHTML = '<div class="storage-header" onclick="toggleStorageDetails(this)"><span class="api-caret">▶</span><span class="terminal-badge info" style="background: rgba(255,255,255,0.06); color: var(--text-muted); border: 1px solid rgba(255,255,255,0.15); margin-right: 6px;">VAL</span><span class="storage-key-name" style="color: var(--text-muted);">' + escapeHtml(key) + '</span><span class="storage-summary-preview">Value view (click to inspect)</span></div><div class="storage-details" style="display: none;"><pre class="storage-pretty-val">' + escapeHtml(formatted) + '</pre></div>';
          } else {
            row.innerHTML = '<span class="terminal-badge info" style="background: rgba(255,255,255,0.06); color: var(--text-muted); border: 1px solid rgba(255,255,255,0.15); margin-right: 6px;">VAL</span><span class="storage-key-name" style="color: var(--text-muted);">' + escapeHtml(key) + '</span> <span style="color: #cbd5e1;">' + escapeHtml(formatStorageValue(state[key])) + '</span>';
          }
          body.appendChild(row);
        });
      }
      section.appendChild(body);
      target.appendChild(section);
    }
    appendSimpleStorageSection('Secure Storage', 'secureStorageChanges', 'secureStorage', secureStoragePanel);
    appendSimpleStorageSection('Keychain', 'keychainChanges', 'keychain', keychainPanel);

    const shotsList = document.getElementById('modal-screenshots-list');
    const shotsToolbar = document.getElementById('modal-screenshots-toolbar');
    shotsList.innerHTML = '';
    const screenshots = data.screenshots || [];
    const observerOverlays = (data.observer && Array.isArray(data.observer.overlays))
      ? data.observer.overlays
      : [];
    document.getElementById('modal-screenshots-count').textContent = screenshots.length;
    if (shotsToolbar) {
      shotsToolbar.innerHTML = screenshots.length ? screenshotOverlayToolbarHtml() : '';
    }
    if (!screenshots.length) {
      shotsList.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no screenshot for this step&gt;</div>';
    } else {
      const container = document.createElement('div');
      container.className = screenshots.length === 1
        ? 'single-screenshot-container'
        : 'modal-screenshots-centered';
      const useSingleLayout = screenshots.length <= 2;
      screenshots.forEach((shot, index) => {
        const href = shot.href || '';
        const rawLabel = shot.screen || shot.label || shot.file || 'Screenshot';
        const card = document.createElement('div');
        card.className = 'modal-screenshot-card' + (useSingleLayout ? ' single-layout' : '');
        if (href) {
          let labelHtml = '';
          if (screenshots.length > 1) {
            let cleanLabel = getCleanScreenshotLabel(rawLabel, titleText) || ('Screenshot ' + (index + 1));
            labelHtml = '<div class="modal-screenshot-label">' + escapeHtml(cleanLabel) + '</div>';
          }
          card.innerHTML = renderScreenshotImage(shot, rawLabel, observerOverlays) + labelHtml;
        } else {
          card.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">' + escapeHtml(rawLabel) + '</div>';
        }
        container.appendChild(card);
      });
      shotsList.appendChild(container);
    }
    applyScreenshotOverlayPrefs();
    scheduleScreenshotChipLayout(shotsList);

    renderObserverTab(data);

    switchModalTab(activeModalTab);
    document.getElementById('step-modal-overlay').style.display = 'flex';
  }

  function renderObserverTab(data) {
    const panel = document.getElementById('modal-observer-panel');
    const countEl = document.getElementById('modal-observer-count');
    const observerBtn = document.querySelector('.modal-tab-btn[data-tab="observer"]');
    panel.innerHTML = '';
    const observer = data.observer;
    if (!observer || typeof observer !== 'object') {
      countEl.textContent = '0';
      if (observerBtn) observerBtn.style.display = 'none';
      panel.innerHTML = '<div class="terminal-row" style="color: var(--text-muted);">&lt;no observer capture for this step&gt;</div>';
      if (activeModalTab === 'observer') activeModalTab = 'screenshots';
      return;
    }
    if (observerBtn) observerBtn.style.display = '';
    const elements = Array.isArray(observer.elements) ? observer.elements : [];
    const total = countObserverNodes(elements);
    countEl.textContent = String(total);
    window.__observerCopyPayload = {
      screen: observer.screen || null,
      elements: elements,
    };
    const screen = observer.screen || '';
    let html = '';
    html += '<div class="observer-toolbar">';
    if (screen) {
      html += '<div class="observer-screen-label">Screen: ' + escapeHtml(String(screen)) + '</div>';
    } else {
      html += '<div class="observer-screen-label"></div>';
    }
    html += '<button type="button" class="observer-copy-json-btn" onclick="copyObserverJson()">Copy JSON</button>';
    html += '</div>';
    html += '<div class="observer-elements-heading">Elements (' + total + ')</div>';
    if (!elements.length) {
      html += '<div class="terminal-row" style="color: var(--text-muted);">&lt;no elements&gt;</div>';
    } else {
      html += '<div class="observer-tree-wrap"><ul class="observer-tree">';
      html += renderObserverTreeNodes(elements, 0);
      html += '</ul></div>';
    }
    panel.innerHTML = html;
    bindObserverHintTooltips(panel);
  }

  function getObserverFloatingTooltip() {
    let tip = document.getElementById('observer-floating-tooltip');
    if (!tip) {
      tip = document.createElement('div');
      tip.id = 'observer-floating-tooltip';
      tip.className = 'observer-floating-tooltip';
      tip.setAttribute('role', 'tooltip');
      document.body.appendChild(tip);
    }
    return tip;
  }

  function hideObserverHintTooltip() {
    const tip = document.getElementById('observer-floating-tooltip');
    if (tip) tip.classList.remove('is-visible');
    document.querySelectorAll('.observer-hint.is-open').forEach(function (el) {
      el.classList.remove('is-open');
    });
  }

  function positionObserverFloatingTooltip(anchor) {
    const tip = getObserverFloatingTooltip();
    const chip = anchor.querySelector('.observer-hint-chip') || anchor;
    const chipRect = chip.getBoundingClientRect();
    const tipW = tip.offsetWidth;
    const tipH = tip.offsetHeight;
    const gap = 6;
    const pad = 8;
    const spaceBelow = window.innerHeight - chipRect.bottom - pad;
    const spaceAbove = chipRect.top - pad;
    let top;
    if (spaceBelow < tipH && spaceAbove > spaceBelow) {
      top = chipRect.top - tipH - gap;
    } else {
      top = chipRect.bottom + gap;
    }
    let left = chipRect.left;
    if (left + tipW > window.innerWidth - pad) {
      left = Math.max(pad, window.innerWidth - tipW - pad);
    }
    if (left < pad) left = pad;
    if (top < pad) top = pad;
    if (top + tipH > window.innerHeight - pad) {
      top = Math.max(pad, window.innerHeight - tipH - pad);
    }
    tip.style.top = Math.round(top) + 'px';
    tip.style.left = Math.round(left) + 'px';
  }

  function showObserverHintTooltip(hint) {
    const title = hint.getAttribute('data-tip-title') || '';
    const body = hint.getAttribute('data-tip-body') || '';
    const listRaw = hint.getAttribute('data-tip-list') || '';
    const list = listRaw ? listRaw.split('|').filter(Boolean) : [];
    if (!body && !list.length) return;

    const tip = getObserverFloatingTooltip();
    let html = '';
    if (title) {
      html += '<div class="observer-hint-tooltip-title">' + escapeHtml(title) + '</div>';
    }
    if (list.length) {
      html += '<ul class="observer-hint-tooltip-list">';
      for (let i = 0; i < list.length; i++) {
        html += '<li><code>' + escapeHtml(String(list[i])) + '</code></li>';
      }
      html += '</ul>';
    } else if (body) {
      html += '<code class="observer-hint-tooltip-body">' + escapeHtml(body) + '</code>';
    }
    tip.innerHTML = html;
    tip.classList.add('is-visible');
    hint.classList.add('is-open');
    positionObserverFloatingTooltip(hint);
  }

  function bindObserverHintTooltips(root) {
    if (!root) return;
    if (!root.__observerHintsBound) {
      root.__observerHintsBound = true;
      root.addEventListener('mouseover', function (e) {
        const hint = e.target.closest && e.target.closest('.observer-hint');
        if (!hint || !root.contains(hint)) return;
        showObserverHintTooltip(hint);
      });
      root.addEventListener('mouseout', function (e) {
        const hint = e.target.closest && e.target.closest('.observer-hint');
        if (!hint || !root.contains(hint)) return;
        const next = e.relatedTarget;
        if (next && hint.contains(next)) return;
        hideObserverHintTooltip();
      });
      root.addEventListener('focusin', function (e) {
        const hint = e.target.closest && e.target.closest('.observer-hint');
        if (!hint || !root.contains(hint)) return;
        showObserverHintTooltip(hint);
      });
      root.addEventListener('focusout', function (e) {
        const hint = e.target.closest && e.target.closest('.observer-hint');
        if (!hint || !root.contains(hint)) return;
        const next = e.relatedTarget;
        if (next && hint.contains(next)) return;
        hideObserverHintTooltip();
      });
    }
    const treeWrap = root.querySelector('.observer-tree-wrap');
    if (treeWrap && !treeWrap.__observerScrollBound) {
      treeWrap.__observerScrollBound = true;
      treeWrap.addEventListener('scroll', hideObserverHintTooltip, { passive: true });
    }
  }

  function countObserverNodes(nodes) {
    let n = 0;
    (Array.isArray(nodes) ? nodes : []).forEach(function (el) {
      n += 1;
      if (el && Array.isArray(el.children)) n += countObserverNodes(el.children);
    });
    return n;
  }

  function renderObserverTreeNodes(nodes, depth) {
    let html = '';
    (Array.isArray(nodes) ? nodes : []).forEach(function (el) {
      html += renderObserverTreeNode(el || {}, depth);
    });
    return html;
  }

  function renderObserverTreeNode(el, depth) {
    const type = el.type || 'widget';
    const id = el.id ? String(el.id) : '';
    const title = el.title ? String(el.title) : '';
    // Prefer a single label — title, else id. Avoid repeating when they match.
    const label = title || id;
    const selector = el.selector ? String(el.selector) : '';
    const kids = Array.isArray(el.children) ? el.children : [];
    const hasKids = kids.length > 0;
    const actions = Array.isArray(el.supportedActions) ? el.supportedActions : [];
    const stateBits = [];
    if (el.enabled != null) stateBits.push('enabled=' + el.enabled);
    if (el.checked != null) stateBits.push('checked=' + el.checked);
    if (el.interactable != null) stateBits.push('interactable=' + el.interactable);
    if (el.value) stateBits.push('value=' + String(el.value));
    if (Array.isArray(el.options) && el.options.length) {
      stateBits.push('options=[' + el.options.map(String).join(', ') + ']');
    }
    if (el.warning) stateBits.push('warning=' + String(el.warning));

    let html = '<li class="observer-tree-node" data-depth="' + depth + '">';
    html += '<div class="observer-tree-row">';
    if (hasKids) {
      html += '<button type="button" class="observer-tree-toggle" aria-expanded="true" onclick="toggleObserverTreeNode(this)">▾</button>';
    } else {
      html += '<span class="observer-tree-toggle-spacer"></span>';
    }
    html += '<code class="observer-type">' + escapeHtml(String(type)) + '</code>';
    if (label) {
      html += '<span class="observer-title">' + escapeHtml(label) + '</span>';
    }
    if (selector) {
      html += '<span class="observer-hint" tabindex="0" data-tip-title="Selector" data-tip-body="' +
        escapeHtml(selector) + '">';
      html += '<span class="observer-hint-chip" aria-label="Selector">';
      html += '<span class="observer-hint-glyph" aria-hidden="true">sel</span>';
      html += '</span></span>';
    }
    if (actions.length) {
      html += '<span class="observer-hint" tabindex="0" data-tip-title="Supported actions" data-tip-list="' +
        escapeHtml(actions.join('|')) + '">';
      html += '<span class="observer-hint-chip" aria-label="' + actions.length + ' supported actions">';
      html += '<span class="observer-hint-glyph" aria-hidden="true">act</span>';
      html += '<span class="observer-hint-count">' + actions.length + '</span>';
      html += '</span></span>';
    }
    if (stateBits.length) {
      html += '<span class="observer-state">' + escapeHtml(stateBits.join(' · ')) + '</span>';
    }
    html += '</div>';
    if (hasKids) {
      html += '<ul class="observer-tree-children">';
      html += renderObserverTreeNodes(kids, depth + 1);
      html += '</ul>';
    }
    html += '</li>';
    return html;
  }

  function toggleObserverTreeNode(btn) {
    const li = btn.closest('.observer-tree-node');
    if (!li) return;
    let kids = null;
    for (let i = 0; i < li.children.length; i++) {
      if (li.children[i].classList.contains('observer-tree-children')) {
        kids = li.children[i];
        break;
      }
    }
    if (!kids) return;
    const open = kids.style.display !== 'none';
    kids.style.display = open ? 'none' : '';
    btn.textContent = open ? '▸' : '▾';
    btn.setAttribute('aria-expanded', open ? 'false' : 'true');
  }

  async function copyObserverJson() {
    const payload = window.__observerCopyPayload;
    if (!payload) return;
    const text = JSON.stringify(payload, null, 2);
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
      } else {
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.left = '-9999px';
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
      }
      const btn = document.querySelector('.observer-copy-json-btn');
      if (btn) {
        const prev = btn.textContent;
        btn.textContent = 'Copied';
        setTimeout(function () { btn.textContent = prev || 'Copy JSON'; }, 1200);
      }
    } catch (_) {
      const btn = document.querySelector('.observer-copy-json-btn');
      if (btn) {
        btn.textContent = 'Copy failed';
        setTimeout(function () { btn.textContent = 'Copy JSON'; }, 1500);
      }
    }
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
      const toolbar = document.createElement('div');
      toolbar.className = 'screenshot-overlay-toolbar-host';
      toolbar.innerHTML = screenshotOverlayToolbarHtml();
      contentArea.appendChild(toolbar);
      const grid = document.createElement('div');
      grid.className = 'fullscreen-screenshots-grid';
      cardEl.querySelectorAll('.screenshot-gallery-tile').forEach(tile => {
        grid.appendChild(tile.cloneNode(true));
      });
      contentArea.appendChild(grid);
      applyScreenshotOverlayPrefs();
      scheduleScreenshotChipLayout(contentArea);
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
    hideObserverHintTooltip();
    document.querySelectorAll('.modal-tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.getAttribute('data-tab') === tab);
    });
    document.querySelectorAll('.modal-tab-content').forEach(content => { content.style.display = 'none'; });
    const pane = document.getElementById('modal-tab-' + tab);
    if (pane) pane.style.display = 'flex';
    if (tab === 'screenshots') scheduleScreenshotChipLayout(pane);
  }

  function formatStorageValue(value) {
    if (value === undefined || value === null) return 'null';
    let text;
    if (typeof value === 'string') text = value;
    else { try { text = JSON.stringify(value); } catch (e) { text = String(value); } }
    return text;
  }

  function prettyFormatStorageValue(value) {
    if (value === undefined || value === null) return 'null';
    let parsed = value;
    if (typeof value === 'string') {
      try {
        parsed = JSON.parse(value);
      } catch (e) {
        return value;
      }
    }
    try {
      return JSON.stringify(parsed, null, 2);
    } catch (e) {
      return String(value);
    }
  }

  window.toggleStorageDetails = function(header) {
    const details = header.nextElementSibling;
    const caret = header.querySelector('.api-caret');
    const isExpanded = details.style.display === 'block' || details.style.display === 'flex';
    const isDiff = details.querySelector('.storage-diff-container') !== null;
    details.style.display = isExpanded ? 'none' : (isDiff ? 'flex' : 'block');
    caret.style.transform = isExpanded ? 'rotate(0deg)' : 'rotate(90deg)';
  }

  window.switchAppTab = function(tab) {
    document.querySelectorAll('.app-tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.getAttribute('data-app-tab') === tab);
    });
    document.querySelectorAll('.app-tab-content').forEach(content => {
      content.style.display = content.id === 'app-tab-content-' + tab ? 'block' : 'none';
    });
  }

  window.toggleHistoryRunDetails = function(runId) {
    const detailRow = document.getElementById('history-details-' + runId);
    const caret = document.getElementById('history-caret-' + runId);
    if (!detailRow || !caret) return;
    
    const isExpanded = detailRow.style.display === 'table-row';
    if (isExpanded) {
      detailRow.style.display = 'none';
      caret.style.transform = 'rotate(0deg)';
    } else {
      loadHistoryRunDetails(runId).then(detailsHtml => {
        const container = detailRow.querySelector('.run-details-expanded-container');
        if (container) container.innerHTML = detailsHtml;
        detailRow.style.display = 'table-row';
        caret.style.transform = 'rotate(90deg)';
      });
    }
  }

  async function loadHistoryRunDetails(runId) {
    let db = null;
    try {
      db = await getHistoryDb();
      if (!db) return '<div class="run-all-passed-banner" style="background:rgba(244,63,94,0.05); color:var(--fail); border-color:rgba(244,63,94,0.2);">Could not open history database.</div>';
      
      const runs = rowsFromStatement(db.prepare("SELECT * FROM runs WHERE id = " + runId));
      if (!runs.length) return '<div class="run-all-passed-banner" style="background:rgba(244,63,94,0.05); color:var(--fail); border-color:rgba(244,63,94,0.2);">Run not found.</div>';
      const run = runs[0];
      
      const failedTests = rowsFromStatement(db.prepare("SELECT * FROM failed_tests WHERE run_id = " + runId));
      
      let html = '<div class="run-details-expanded-content">';
      
      // Metadata Grid
      html += '  <div class="run-metadata-grid">';
      html += '    <div class="run-metadata-item"><strong>Branch:</strong> <span>' + escapeHtml(run.branch || 'N/A') + '</span></div>';
      html += '    <div class="run-metadata-item"><strong>Commit:</strong> <span>' + escapeHtml(run.commit_hash || 'N/A') + '</span></div>';
      html += '    <div class="run-metadata-item"><strong>Build Number:</strong> <span>' + escapeHtml(run.build_number || 'N/A') + '</span></div>';
      html += '    <div class="run-metadata-item"><strong>PR Number:</strong> <span>' + escapeHtml(run.pr_number || 'N/A') + '</span></div>';
      html += '    <div class="run-metadata-item"><strong>Date:</strong> <span>' + escapeHtml(formatDateTime(run.created_at)) + '</span></div>';
      html += '    <div class="run-metadata-item"><strong>Duration:</strong> <span>' + escapeHtml(formatDuration(run.duration_ms || 0)) + '</span></div>';
      html += '  </div>';
      
      // Metrics Grid for this run
      const passed = Number(run.passed_tests || 0);
      const failed = Number(run.failed_tests || 0);
      const total = Number(run.total_tests || 0);
      const successRate = total > 0 ? Math.round((passed / total) * 100) : 0;
      
      html += '  <div class="run-metrics-mini-grid">';
      html += '    <div class="run-metric-mini"><div class="mini-val">' + total + '</div><div class="mini-label">Total</div></div>';
      html += '    <div class="run-metric-mini mini-passed"><div class="mini-val">' + passed + '</div><div class="mini-label">Passed</div></div>';
      html += '    <div class="run-metric-mini mini-failed"><div class="mini-val">' + failed + '</div><div class="mini-label">Failed</div></div>';
      html += '    <div class="run-metric-mini mini-rate"><div class="mini-val">' + successRate + '%</div><div class="mini-label">Success Rate</div></div>';
      html += '  </div>';
      
      // Failed Tests list
      if (failed === 0) {
        html += '  <div class="run-all-passed-banner">🎉 All ' + total + ' tests passed successfully in this run!</div>';
      } else {
        html += '  <div class="run-failed-tests-list">';
        html += '    <h4>Failed Tests Details (' + failed + ')</h4>';
        failedTests.forEach(ft => {
          const testId = ft.test_id || '(unknown)';
          const device = ft.device || '';
          const scenario = ft.scenario || '';
          const filename = ft.file_name || '';
          const failedStep = ft.failed_step || '';
          const failedStepIndex = Number.isFinite(Number(ft.failed_step_index))
            ? Number(ft.failed_step_index) + 1
            : null;
          const errorSummary = ft.error_summary || 'Test execution failed.';
          
          html += '    <div class="run-failed-test-card">';
          html += '      <div class="run-failed-test-header">';
          html += '        <span class="run-failed-test-title">' + escapeHtml(testId) + '</span>';
          if (device) html += '        <span class="device-badge" style="background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.15); color: #cbd5e1; font-size: 0.65rem; padding: 2px 6px; border-radius: 4px; font-weight: 700; margin-left: 8px;">' + escapeHtml(device) + '</span>';
          html += '      </div>';
          if (filename) {
            html += '      <div class="run-failed-test-file">File: <code style="color:var(--accent); font-size:0.75rem;">' + escapeHtml(filename) + '</code></div>';
          }
          if (failedStep) {
            const stepLabel = failedStepIndex == null
              ? failedStep
              : '#' + failedStepIndex + ' ' + failedStep;
            html += '      <div class="run-failed-test-file">Failed step: <code style="color:var(--fail); font-size:0.75rem;">' + escapeHtml(stepLabel) + '</code></div>';
          }
          html += '      <pre class="run-failed-test-error">' + escapeHtml(errorSummary) + '</pre>';
          html += '    </div>';
        });
        html += '  </div>';
      }
      
      html += '</div>';
      return html;
    } catch (e) {
      return '<div class="run-all-passed-banner" style="background:rgba(244,63,94,0.05); color:var(--fail); border-color:rgba(244,63,94,0.2);">Error loading details: ' + escapeHtml(String(e)) + '</div>';
    } finally {
      if (db) db.close();
    }
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

  function renderScreenshotImage(frame, label, observerOverlays) {
    const href = frame.href || '';
    if (!href) return '';
    let html = '<a class="screenshot-image-link" href="' + escapeHtml(href) + '" target="_blank" rel="noopener">';
    html += '<span class="screenshot-image-wrap">';
    html += '<img src="' + escapeHtml(href) + '" alt="' + escapeHtml(label) + '" loading="lazy"/>';

    const highlight = frame.highlight || null;
    let highlightRect = null;
    if (highlight) {
      const left = Number(highlight.left || 0);
      const top = Number(highlight.top || 0);
      const width = Number(highlight.width || 0);
      const height = Number(highlight.height || 0);
      if (width > 0 && height > 0) {
        highlightRect = { left: left, top: top, width: width, height: height };
      }
    }

    // Observer boxes for every element except the action/failure target —
    // that control keeps the step ring; observer only contributes type/id chips.
    const overlays = Array.isArray(observerOverlays) ? observerOverlays : [];
    const actionCandidates = [];
    overlays.forEach((overlay) => {
      const left = Number(overlay.left || 0);
      const top = Number(overlay.top || 0);
      const width = Number(overlay.width || 0);
      const height = Number(overlay.height || 0);
      if (!(width > 0 && height > 0)) return;
      const rect = { left: left, top: top, width: width, height: height };
      if (highlightRect && observerOverlapsHighlight(rect, highlightRect)) {
        // Prefer keyed + smaller controls (checkbox inside a card) so the action
        // label does not inherit the parent row's `card` type.
        const area = Math.max(width * height, 0.0001);
        const score = (overlay.id ? 1000 : 0) + (1 / area);
        actionCandidates.push({ overlay: overlay, score: score });
        return;
      }
      const compact = isCompactObserverRect(width, height);
      html += '<span class="screenshot-highlight observer' +
          (compact ? ' compact' : '') +
          '" style="left:' + left.toFixed(4) + '%;top:' + top.toFixed(4) + '%;width:' + width.toFixed(4) + '%;height:' + height.toFixed(4) + '%;">';
      html += renderObserverChips(overlay.id, overlay.type, compact);
      html += '</span>';
    });

    // Action / assertion / failure ring on top — primary focus of the step.
    if (highlightRect) {
      const kind = highlight.kind === 'assertion' || highlight.kind === 'failure'
        ? highlight.kind
        : 'action';
      const compactAction = isCompactObserverRect(highlightRect.width, highlightRect.height);
      html += '<span class="screenshot-highlight ' + kind +
          (compactAction ? ' compact' : '') +
          '" style="left:' + highlightRect.left.toFixed(4) + '%;top:' + highlightRect.top.toFixed(4) + '%;width:' + highlightRect.width.toFixed(4) + '%;height:' + highlightRect.height.toFixed(4) + '%;">';
      html += '<span class="screenshot-highlight-dot"></span>';
      if (actionCandidates.length) {
        actionCandidates.sort((a, b) => b.score - a.score);
        const best = actionCandidates[0].overlay || {};
        html += renderObserverChips(best.id, best.type, compactAction);
      }
      html += '</span>';
    }
    html += '<button type="button" class="screenshot-copy-btn" title="Copy screenshot with current overlay settings" onclick="event.preventDefault();event.stopPropagation();copyScreenshotOverlay(this);">Copy</button>';
    html += '</span></a>';
    return html;
  }

  function screenshotOverlayToolbarHtml() {
    return '<div class="screenshot-overlay-toolbar">' +
        '<div class="screenshot-overlay-switches">' +
          screenshotOverlaySwitchHtml('obsHighlights', 'Observation highlights') +
          screenshotOverlaySwitchHtml('obsLabels', 'Observation labels') +
          screenshotOverlaySwitchHtml('actionHighlights', 'Action highlights') +
        '</div>' +
      '</div>';
  }

  function screenshotOverlaySwitchHtml(key, label) {
    const checked = screenshotOverlayPrefs[key] ? ' checked' : '';
    return '<label class="screenshot-overlay-switch">' +
        '<input type="checkbox" data-overlay-pref="' + key + '"' + checked +
        ' onchange="setScreenshotOverlayPref(\'' + key + '\', this.checked)">' +
        '<span class="screenshot-overlay-switch-ui" aria-hidden="true"></span>' +
        '<span class="screenshot-overlay-switch-label">' + escapeHtml(label) + '</span>' +
      '</label>';
  }

  function setScreenshotOverlayPref(key, enabled) {
    if (!Object.prototype.hasOwnProperty.call(screenshotOverlayPrefs, key)) return;
    screenshotOverlayPrefs[key] = !!enabled;
    applyScreenshotOverlayPrefs();
  }

  function applyScreenshotOverlayPrefs() {
    const root = document.documentElement;
    root.classList.toggle('hide-obs-highlights', !screenshotOverlayPrefs.obsHighlights);
    root.classList.toggle('hide-obs-labels', !screenshotOverlayPrefs.obsLabels);
    root.classList.toggle('hide-action-highlights', !screenshotOverlayPrefs.actionHighlights);
    document.querySelectorAll('input[data-overlay-pref]').forEach((input) => {
      const key = input.getAttribute('data-overlay-pref');
      if (!key || !Object.prototype.hasOwnProperty.call(screenshotOverlayPrefs, key)) return;
      input.checked = !!screenshotOverlayPrefs[key];
    });
    scheduleScreenshotChipLayout(document);
  }

  function ensureImageReady(img) {
    if (!img) return Promise.reject(new Error('missing image'));
    if (img.complete && img.naturalWidth > 0) return Promise.resolve(img);
    return new Promise((resolve, reject) => {
      const onLoad = () => {
        cleanup();
        resolve(img);
      };
      const onError = () => {
        cleanup();
        reject(new Error('image failed to load'));
      };
      const cleanup = () => {
        img.removeEventListener('load', onLoad);
        img.removeEventListener('error', onError);
      };
      img.addEventListener('load', onLoad);
      img.addEventListener('error', onError);
    });
  }

  function pctStyle(el, prop) {
    return Number(String(el.style[prop] || '0').replace('%', '')) || 0;
  }

  async function composeScreenshotCanvas(wrap) {
    layoutChipsInWrap(wrap);
    const img = wrap.querySelector('img');
    await ensureImageReady(img);
    const w = img.naturalWidth;
    const h = img.naturalHeight;
    if (!(w > 0 && h > 0)) throw new Error('invalid image size');
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0, w, h);

    const prefs = screenshotOverlayPrefs;
    const lineW = Math.max(2, Math.round(w * 0.004));
    wrap.querySelectorAll('.screenshot-highlight').forEach((hl) => {
      const left = pctStyle(hl, 'left') / 100 * w;
      const top = pctStyle(hl, 'top') / 100 * h;
      const width = pctStyle(hl, 'width') / 100 * w;
      const height = pctStyle(hl, 'height') / 100 * h;
      if (!(width > 0 && height > 0)) return;
      const isObserver = hl.classList.contains('observer');
      const isAction = hl.classList.contains('action') ||
          hl.classList.contains('assertion') ||
          hl.classList.contains('failure');

      if (isObserver && prefs.obsHighlights) {
        ctx.save();
        ctx.strokeStyle = '#00b4d8';
        ctx.lineWidth = Math.max(2, lineW - 1);
        ctx.strokeRect(left, top, width, height);
        ctx.restore();
      }
      if (isAction && prefs.actionHighlights) {
        ctx.save();
        if (hl.classList.contains('failure')) {
          ctx.setLineDash([Math.max(6, lineW * 2), Math.max(4, lineW)]);
          ctx.strokeStyle = '#f43f5e';
        } else if (hl.classList.contains('assertion')) {
          ctx.strokeStyle = '#00d5ff';
        } else {
          ctx.strokeStyle = '#ff3f6f';
        }
        ctx.lineWidth = lineW;
        ctx.strokeRect(left, top, width, height);
        ctx.restore();
      }
      if (prefs.obsLabels) {
        drawScreenshotChipsOnCanvas(ctx, hl, left, top, width, height, w, h, wrap);
      }
    });
    return canvas;
  }

  function drawScreenshotChipsOnCanvas(ctx, hl, left, top, width, height, canvasW, canvasH, wrap) {
    const chipsRoot = hl.querySelector('.screenshot-observer-chips');
    if (!chipsRoot) return;
    const chips = chipsRoot.querySelectorAll('.screenshot-observer-chip');
    if (!chips.length) return;
    const compact = hl.classList.contains('compact');
    const fontSize = Math.max(compact ? 9 : 11, Math.round(canvasW * (compact ? 0.011 : 0.013)));
    const padX = Math.max(4, Math.round(fontSize * 0.45));
    const padY = Math.max(2, Math.round(fontSize * 0.25));
    const chipH = fontSize + padY * 2;
    const gap = 3;
    ctx.save();
    ctx.font = '700 ' + fontSize + 'px ui-sans-serif, system-ui, -apple-system, sans-serif';
    ctx.textBaseline = 'middle';

    const items = [];
    chips.forEach((chip) => {
      const text = (chip.textContent || '').trim();
      if (!text) return;
      items.push({
        text: text,
        tw: ctx.measureText(text).width + padX * 2,
        fill: chip.classList.contains('type') ? 'rgba(161, 98, 7, 0.92)' : 'rgba(0, 95, 135, 0.92)',
      });
    });
    if (!items.length) {
      ctx.restore();
      return;
    }

    const sx = wrap && wrap.clientWidth ? canvasW / wrap.clientWidth : 1;
    const sy = wrap && wrap.clientHeight ? canvasH / wrap.clientHeight : 1;
    const chipLeftCss = parseFloat(chipsRoot.style.left || '0') || 0;
    const chipTopCss = parseFloat(chipsRoot.style.top || '0') || 0;
    // chips are positioned relative to the highlight element.
    let cx = left + chipLeftCss * sx;
    let cy = top + chipTopCss * sy;

    items.forEach((item) => {
      const tw = Math.min(item.tw, (compact ? 110 : 140) * sx);
      roundRectFill(ctx, cx, cy, tw, chipH, 3, item.fill);
      ctx.fillStyle = '#fff';
      ctx.fillText(item.text, cx + padX, cy + chipH / 2);
      cx += tw + gap;
    });
    ctx.restore();
  }

  function roundRectFill(ctx, x, y, w, h, r, fill) {
    const radius = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.arcTo(x + w, y, x + w, y + h, radius);
    ctx.arcTo(x + w, y + h, x, y + h, radius);
    ctx.arcTo(x, y + h, x, y, radius);
    ctx.arcTo(x, y, x + w, y, radius);
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
  }

  async function copyScreenshotOverlay(btn) {
    if (!btn || btn.classList.contains('is-busy')) return;
    const wrap = btn.closest('.screenshot-image-wrap');
    if (!wrap) return;
    const prev = btn.textContent;
    btn.classList.remove('is-done', 'is-failed');
    btn.classList.add('is-busy');
    btn.textContent = '…';
    try {
      const canvas = await composeScreenshotCanvas(wrap);
      const blob = await new Promise((resolve, reject) => {
        canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('toBlob failed'))), 'image/png');
      });
      if (!(navigator.clipboard && window.ClipboardItem)) {
        throw new Error('clipboard image API unavailable');
      }
      await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
      btn.classList.remove('is-busy');
      btn.classList.add('is-done');
      btn.textContent = 'Copied';
      setTimeout(() => {
        btn.classList.remove('is-done');
        btn.textContent = prev;
      }, 1400);
    } catch (err) {
      console.warn('copyScreenshotOverlay failed', err);
      btn.classList.remove('is-busy');
      btn.classList.add('is-failed');
      btn.textContent = 'Failed';
      setTimeout(() => {
        btn.classList.remove('is-failed');
        btn.textContent = prev;
      }, 1600);
    }
  }

  /** Small hit targets (checkboxes / icons) — narrow chips above, not over the row title. */
  function isCompactObserverRect(widthPct, heightPct) {
    return widthPct < 16 || heightPct < 7;
  }

  function formatObserverChipText(text, compact) {
    const s = String(text || '');
    const max = compact ? 20 : 28;
    if (s.length <= max) return s;
    // Keep a readable suffix so *_checkbox / *_button ids stay recognizable.
    const head = compact ? 6 : 10;
    const tail = compact ? 9 : 10;
    return s.slice(0, head) + '…' + s.slice(-tail);
  }

  function renderObserverChips(id, type, compact) {
    const chips = [];
    if (id) {
      chips.push('<span class="screenshot-observer-chip id" title="' +
          escapeHtml(String(id)) + '">' +
          escapeHtml(formatObserverChipText(id, !!compact)) + '</span>');
    }
    if (type) {
      chips.push('<span class="screenshot-observer-chip type">' +
          escapeHtml(String(type)) + '</span>');
    }
    if (!chips.length) return '';
    return '<span class="screenshot-observer-chips">' + chips.join('') + '</span>';
  }

  /** Place labels inside the image with collision avoidance (no off-screen clip). */
  /** Scale modal phone shots into available space and keep overlay % boxes
   *  locked to the image (wrap must match img pixel box, not letterbox). */
  function fitScreenshotFrames(root) {
    const scope = root && root.querySelectorAll ? root : document;
    const cards = scope.querySelectorAll(
      '#modal-tab-screenshots .modal-screenshot-card.single-layout, #modal-tab-screenshots .modal-screenshot-card'
    );
    cards.forEach((card) => {
      const container = card.closest('.single-screenshot-container') ||
          card.closest('.modal-screenshots-centered') ||
          card.parentElement;
      const wrap = card.querySelector('.screenshot-image-wrap');
      const img = card.querySelector('img');
      if (!container || !wrap || !img) return;

      const apply = () => {
        const nw = img.naturalWidth || 0;
        const nh = img.naturalHeight || 0;
        if (!(nw > 0 && nh > 0)) return;
        const availW = Math.max(container.clientWidth - 8, 80);
        const availH = Math.max(container.clientHeight - 8, 80);
        if (!(availW > 0 && availH > 0)) return;
        const scale = Math.min(availW / nw, availH / nh, 1);
        const w = Math.max(1, Math.floor(nw * scale));
        const h = Math.max(1, Math.floor(nh * scale));
        img.style.width = w + 'px';
        img.style.height = h + 'px';
        img.style.maxWidth = 'none';
        img.style.maxHeight = 'none';
        wrap.style.width = w + 'px';
        wrap.style.height = h + 'px';
      };

      if (img.complete && img.naturalWidth > 0) {
        apply();
      } else {
        img.addEventListener('load', apply, { once: true });
      }
    });
  }

  function scheduleScreenshotFitAndLayout(root) {
    const target = root || document;
    requestAnimationFrame(() => {
      fitScreenshotFrames(target);
      requestAnimationFrame(() => layoutScreenshotChips(target));
    });
  }

  function scheduleScreenshotChipLayout(root) {
    scheduleScreenshotFitAndLayout(root);
  }

  function layoutScreenshotChips(root) {
    const scope = root && root.querySelectorAll ? root : document;
    scope.querySelectorAll('.screenshot-image-wrap').forEach(layoutChipsInWrap);
  }

  function layoutChipsInWrap(wrap) {
    const wrapW = wrap.clientWidth;
    const wrapH = wrap.clientHeight;
    if (!(wrapW > 0 && wrapH > 0)) return;

    const placed = [];
    const highlights = Array.from(wrap.querySelectorAll('.screenshot-highlight'));
    // Larger targets first so cards claim space before tiny checkboxes nudge away.
    highlights.sort((a, b) => (b.offsetWidth * b.offsetHeight) - (a.offsetWidth * a.offsetHeight));

    highlights.forEach((hl) => {
      const chips = hl.querySelector(':scope > .screenshot-observer-chips');
      if (!chips) return;
      if (window.getComputedStyle(chips).display === 'none') return;

      chips.style.right = 'auto';
      chips.style.bottom = 'auto';
      chips.style.transform = 'none';
      chips.style.left = '0px';
      chips.style.top = '0px';

      const hlL = hl.offsetLeft;
      const hlT = hl.offsetTop;
      const hlW = hl.offsetWidth;
      const hlH = hl.offsetHeight;
      const cw = Math.max(chips.offsetWidth, 1);
      const ch = Math.max(chips.offsetHeight, 1);
      const gap = 3;

      const candidates = [
        { left: 0, top: -ch - gap },                         // above-left
        { left: Math.max(0, hlW - cw), top: -ch - gap },     // above-right
        { left: hlW + gap, top: Math.max(0, (hlH - ch) / 2) }, // right-middle
        { left: 0, top: hlH + gap },                         // below-left
        { left: Math.max(0, hlW - cw), top: hlH + gap },     // below-right
        { left: 2, top: 2 },                                 // inside-top-left
        { left: Math.max(2, hlW - cw - 2), top: 2 },         // inside-top-right
      ];

      function clamp(left, top) {
        let x = hlL + left;
        let y = hlT + top;
        if (x < 0) left -= x;
        if (y < 0) top -= y;
        x = hlL + left;
        y = hlT + top;
        if (x + cw > wrapW) left -= (x + cw - wrapW);
        if (y + ch > wrapH) top -= (y + ch - wrapH);
        return { left: left, top: top };
      }

      function overlaps(left, top) {
        const x = hlL + left;
        const y = hlT + top;
        const r = x + cw;
        const b = y + ch;
        for (let i = 0; i < placed.length; i++) {
          const p = placed[i];
          if (!(r <= p.l || x >= p.r || b <= p.t || y >= p.b)) return true;
        }
        return false;
      }

      let chosen = null;
      for (let i = 0; i < candidates.length; i++) {
        const c = clamp(candidates[i].left, candidates[i].top);
        if (overlaps(c.left, c.top)) continue;
        chosen = c;
        break;
      }
      if (!chosen) {
        let c = clamp(2, 2);
        for (let n = 0; n < 24; n++) {
          if (!overlaps(c.left, c.top)) break;
          c = clamp(c.left, c.top + ch + gap);
        }
        chosen = c;
      }

      chips.style.left = chosen.left + 'px';
      chips.style.top = chosen.top + 'px';
      const x = hlL + chosen.left;
      const y = hlT + chosen.top;
      placed.push({ l: x - 2, t: y - 2, r: x + cw + 2, b: y + ch + 2 });
    });
  }

  /** True when [observer] mostly covers the same control as [highlight]. */
  function observerOverlapsHighlight(observer, highlight) {
    const ox2 = observer.left + observer.width;
    const oy2 = observer.top + observer.height;
    const hx2 = highlight.left + highlight.width;
    const hy2 = highlight.top + highlight.height;
    const ix = Math.max(0, Math.min(ox2, hx2) - Math.max(observer.left, highlight.left));
    const iy = Math.max(0, Math.min(oy2, hy2) - Math.max(observer.top, highlight.top));
    const inter = ix * iy;
    if (inter <= 0) return false;
    const oArea = observer.width * observer.height;
    const hArea = highlight.width * highlight.height;
    if (oArea <= 0 || hArea <= 0) return false;
    // Same control: observer covers most of the highlight, or vice versa.
    return (inter / hArea) >= 0.45 || (inter / oArea) >= 0.45;
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

  window.showChartTooltip = function(event, title, rows) {
    const tooltip = document.getElementById('chart-tooltip');
    if (!tooltip) return;
    
    let html = '<div class="chart-tooltip-title">' + escapeHtml(title) + '</div>';
    rows.forEach(r => {
      html += '<div class="chart-tooltip-row">';
      html += '  <span class="chart-tooltip-label">' + escapeHtml(r.label) + ':</span>';
      html += '  <span class="chart-tooltip-val">' + escapeHtml(r.val) + '</span>';
      html += '</div>';
    });
    
    tooltip.innerHTML = html;
    tooltip.style.display = 'flex';
    moveChartTooltip(event);
  }

  window.moveChartTooltip = function(event) {
    const tooltip = document.getElementById('chart-tooltip');
    if (!tooltip || tooltip.style.display === 'none') return;
    
    // Add offset from pointer position
    const offsetX = 12;
    const offsetY = 12;
    
    let x = event.pageX + offsetX;
    let y = event.pageY + offsetY;
    
    // Boundary checks (viewport width)
    const tooltipWidth = tooltip.offsetWidth;
    const tooltipHeight = tooltip.offsetHeight;
    
    if (x + tooltipWidth > window.innerWidth + window.pageXOffset) {
      x = event.pageX - tooltipWidth - offsetX;
    }
    if (y + tooltipHeight > window.innerHeight + window.pageYOffset) {
      y = event.pageY - tooltipHeight - offsetY;
    }
    
    tooltip.style.left = x + 'px';
    tooltip.style.top = y + 'px';
  }

  window.hideChartTooltip = function() {
    const tooltip = document.getElementById('chart-tooltip');
    if (tooltip) tooltip.style.display = 'none';
  }

  window.addEventListener('DOMContentLoaded', () => {
    applyScreenshotOverlayPrefs();
    pollAndRender();
    pollTimer = setInterval(pollAndRender, POLL_MS);
  });
  window.addEventListener('resize', () => scheduleScreenshotChipLayout(document));

''';
