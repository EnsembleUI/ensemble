/// Shared CSS for the Ensemble HTML test report shell.
const ensembleHtmlTestReportCss = r'''
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

.hero, .dashboard, .controls, .suite-artifacts-container, .history-container {
  max-width: 1600px;
  margin: 0 auto;
  padding: 16px 24px;
  width: 100%;
}

.hero {
  padding-top: 24px;
  padding-bottom: 16px;
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  flex-wrap: wrap;
  gap: 16px;
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

.history-container {
  padding-top: 0;
  padding-bottom: 8px;
}
.history-card {
  background: rgba(17, 24, 39, 0.7);
  border: 1px solid var(--border);
  border-radius: 12px;
  overflow: hidden;
  backdrop-filter: blur(12px);
}
.history-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  padding: 14px 18px;
  border-bottom: 1px solid var(--border);
}
.history-header h2 {
  margin: 0;
  font-size: 0.95rem;
  color: var(--accent);
  text-transform: uppercase;
  letter-spacing: 0.08em;
}
.history-header span {
  color: var(--text-muted);
  font-size: 0.8rem;
  font-weight: 700;
}
.history-table-wrap {
  overflow-x: auto;
}
.history-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.85rem;
}
.history-table th,
.history-table td {
  padding: 10px 18px;
  text-align: left;
  border-bottom: 1px solid rgba(255, 255, 255, 0.04);
  white-space: nowrap;
}
.history-table th {
  color: var(--text-muted);
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}
.history-table tr:last-child td {
  border-bottom: none;
}
.history-status {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  padding: 2px 8px;
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
}
.history-status.passed {
  color: var(--pass);
  background: var(--pass-bg);
  border: 1px solid rgba(16, 185, 129, 0.35);
}
.history-status.failed {
  color: var(--fail);
  background: var(--fail-bg);
  border: 1px solid rgba(244, 63, 94, 0.35);
}

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
.sort-wrapper {
  display: flex;
  align-items: center;
  gap: 8px;
}
.sort-label {
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--text-muted);
  letter-spacing: 0.05em;
}
.sort-select {
  background: rgba(0, 0, 0, 0.45);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: #fff;
  padding: 6px 12px;
  font-size: 0.8rem;
  font-weight: 700;
  outline: none;
  cursor: pointer;
  font-family: var(--font-ui);
  transition: all 0.2s ease;
}
.sort-select:hover {
  background: rgba(255, 255, 255, 0.05);
  border-color: var(--accent);
}
.sort-select option {
  background: #0f172a;
  color: #fff;
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
.artifact-source {
  font-family: var(--font-code);
  font-size: 0.72rem;
  color: var(--text-muted);
  margin: 4px 0 8px;
}
.artifact-embedded {
  margin: 0;
  max-height: 320px;
  overflow: auto;
  padding: 12px;
  border-radius: 8px;
  background: var(--surface-2, rgba(0,0,0,0.25));
  font-family: var(--font-code);
  font-size: 0.75rem;
  white-space: pre-wrap;
  word-break: break-word;
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
  position: sticky;
  top: 10px;
  max-height: calc(100vh - 20px);
}
.test-list-pane::-webkit-scrollbar {
  width: 6px;
}
.test-list-pane::-webkit-scrollbar-track {
  background: transparent;
}
.test-list-pane::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 4px;
}
.test-list-pane::-webkit-scrollbar-thumb:hover {
  background: rgba(6, 182, 212, 0.3);
}

/* Right Detail Pane */
.test-detail-pane {
  flex: 1;
  min-width: 0;
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 28px;
  backdrop-filter: blur(12px);
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

/* Run Matrix Selector */
.run-selector-panel {
  background: rgba(15, 23, 42, 0.95);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 10px 12px;
  margin-bottom: 24px;
  position: sticky;
  top: 10px;
  z-index: 100;
  backdrop-filter: blur(12px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
}
.run-selector-row {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 34px;
}
.run-selector-row + .run-selector-row {
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
}
.selector-label {
  width: 96px;
  flex: 0 0 96px;
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
  padding: 5px 12px;
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
.storage-sub-tabs {
  display: flex;
  gap: 8px;
  padding: 0 0 12px;
  border-bottom: 1px solid var(--border);
  flex-wrap: wrap;
}
.storage-sub-tab-btn {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: var(--text-muted);
  padding: 7px 14px;
  font-size: 0.78rem;
  font-weight: 800;
  cursor: pointer;
  font-family: var(--font-ui);
  transition: all 0.2s ease;
}
.storage-sub-tab-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #fff;
}
.storage-sub-tab-btn.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #000;
}
.storage-sub-panels {
  min-height: 80px;
}
.storage-sub-panel {
  min-height: 80px;
}
.storage-sub-panel.logs-terminal {
  padding: 12px 16px;
}

@media (max-width: 800px) {
  .run-selector-row {
    align-items: flex-start;
    flex-direction: column;
    gap: 6px;
  }
  .selector-label {
    width: auto;
    flex: none;
  }
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
.test-description {
  margin: 12px 0 0;
  color: var(--text-secondary);
  font-size: 0.95rem;
  line-height: 1.55;
  max-width: 860px;
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
  margin-right: 8px;
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
  background: linear-gradient(180deg, rgba(6, 182, 212, 0.04), rgba(0, 0, 0, 0.22));
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 16px 18px 18px;
  margin-bottom: 20px;
}
.flow-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}
.flow-label {
  font-size: 0.7rem;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--text-muted);
  letter-spacing: 0.08em;
  margin: 0;
}
.flow-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.flow-meta-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--text-muted);
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 3px 10px;
}
.flow-meta-chip strong {
  color: var(--text);
  font-weight: 700;
}
.flow-meta-chip.prefix {
  color: var(--accent);
  background: rgba(6, 182, 212, 0.08);
  border-color: rgba(6, 182, 212, 0.2);
  font-family: var(--font-code);
  font-size: 0.68rem;
  max-width: 280px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.flow-track {
  display: flex;
  align-items: stretch;
  flex-wrap: wrap;
  gap: 10px 0;
  row-gap: 12px;
}
.flow-node {
  position: relative;
  appearance: none;
  -webkit-appearance: none;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  max-width: 100%;
  background: rgba(255, 255, 255, 0.035);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
  padding: 7px 12px 7px 8px;
  color: var(--text);
  font-family: var(--font-ui);
  font-size: 0.82rem;
  font-weight: 600;
  line-height: 1.2;
  margin: 0 28px 0 0;
  transition: border-color 0.15s ease, background 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
}
.flow-node:last-child {
  margin-right: 0;
}
.flow-node:not(:last-child)::after {
  content: '';
  position: absolute;
  left: calc(100% + 8px);
  top: 50%;
  width: 12px;
  height: 2px;
  background: linear-gradient(90deg, rgba(6, 182, 212, 0.65), rgba(6, 182, 212, 0.15));
  border-radius: 2px;
  transform: translateY(-50%);
  pointer-events: none;
}
.flow-node:not(:last-child)::before {
  content: '';
  position: absolute;
  left: calc(100% + 16px);
  top: 50%;
  width: 5px;
  height: 5px;
  border-right: 2px solid rgba(6, 182, 212, 0.55);
  border-top: 2px solid rgba(6, 182, 212, 0.55);
  transform: translateY(-50%) rotate(45deg);
  pointer-events: none;
}
.flow-idx {
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: rgba(6, 182, 212, 0.12);
  border: 1px solid rgba(6, 182, 212, 0.28);
  color: var(--accent);
  font-family: var(--font-code);
  font-size: 0.68rem;
  font-weight: 700;
}
.flow-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 180px;
}
.flow-node.start {
  border-color: rgba(16, 185, 129, 0.35);
  background: rgba(16, 185, 129, 0.08);
}
.flow-node.start .flow-idx {
  background: rgba(16, 185, 129, 0.18);
  border-color: rgba(16, 185, 129, 0.4);
  color: var(--pass);
}
.flow-node.end {
  border-color: rgba(6, 182, 212, 0.4);
  background: rgba(6, 182, 212, 0.08);
}
.flow-node.revisit {
  border-style: dashed;
}
.flow-revisit {
  flex-shrink: 0;
  font-size: 0.62rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: var(--text-muted);
  background: rgba(255, 255, 255, 0.06);
  border-radius: 999px;
  padding: 2px 6px;
}
.flow-node.interactive {
  cursor: pointer;
  text-align: left;
}
.flow-node.interactive:hover {
  border-color: rgba(6, 182, 212, 0.55);
  background: rgba(6, 182, 212, 0.12);
  box-shadow: 0 0 0 3px rgba(6, 182, 212, 0.1);
  transform: translateY(-1px);
}
.flow-node.interactive:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}
.flow-inspect {
  flex-shrink: 0;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--accent);
  box-shadow: 0 0 6px rgba(6, 182, 212, 0.7);
  opacity: 0.85;
}
@media (max-width: 640px) {
  .flow-name {
    max-width: 140px;
  }
  .flow-node {
    margin-right: 22px;
    padding: 6px 10px 6px 7px;
  }
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
.skipped-step .marker-dot {
  background: rgba(255, 255, 255, 0.15);
  box-shadow: none;
}
.skipped-step .step-outline-text {
  color: var(--text-muted);
  opacity: 0.55;
}
.skipped-step .step-outline-text .step-action {
  color: var(--text-muted);
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
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  gap: 16px;
  margin-top: 24px;
}
.storage-grid-container {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 16px;
  margin-top: 16px;
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
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 16px;
  margin-top: 12px;
}
@media (max-width: 1200px) {
  .screenshot-gallery {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}
@media (max-width: 768px) {
  .screenshot-gallery {
    grid-template-columns: repeat(2, minmax(0, 1fr));
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
  transition: box-shadow 0.2s ease, border-color 0.2s ease;
}
.screenshot-gallery-frame:hover {
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
.screenshot-image-link {
  display: block;
  width: 100%;
  text-decoration: none;
}
.screenshot-image-wrap {
  display: block;
  position: relative;
  width: 100%;
}
.screenshot-highlight {
  position: absolute;
  pointer-events: none;
  box-sizing: border-box;
  border-radius: 7px;
  background: transparent;
  border: none;
  outline-offset: 4px;
}
.screenshot-highlight::before,
.screenshot-highlight::after {
  display: none;
}
.screenshot-highlight.action {
  outline: 3px solid #ff3f6f;
  filter: drop-shadow(0 0 7px rgba(244, 63, 94, 0.55));
}
.screenshot-highlight.assertion {
  outline: 3px solid #00d5ff;
  filter: drop-shadow(0 0 7px rgba(6, 182, 212, 0.55));
}
.screenshot-highlight.failure {
  outline: 3px dashed var(--fail);
  background: rgba(244, 63, 94, 0.14);
  filter: drop-shadow(0 0 9px rgba(244, 63, 94, 0.75));
  animation: failure-highlight-pulse 1.5s infinite;
}
@keyframes failure-highlight-pulse {
  0% { outline-offset: 4px; opacity: 1; }
  50% { outline-offset: 7px; opacity: 0.75; }
  100% { outline-offset: 4px; opacity: 1; }
}
.screenshot-highlight-dot {
  display: none;
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
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 20px;
}
@media (max-width: 1200px) {
  .fullscreen-card-content-area.grid-layout {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}
@media (max-width: 768px) {
  .fullscreen-card-content-area.grid-layout {
    grid-template-columns: repeat(2, minmax(0, 1fr));
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
  transition: border-color 0.2s ease;
}
.fullscreen-sheet-tile img:hover {
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
.modal-tab-btn, .screen-tab-btn {
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
.modal-tab-btn:hover, .screen-tab-btn:hover {
  color: #fff;
}
.modal-tab-btn.active, .screen-tab-btn.active {
  color: var(--accent);
}
.modal-tab-btn.active::after, .screen-tab-btn.active::after {
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

/* Storage Diff Viewer styling */
.storage-collapsible {
  cursor: pointer;
  padding: 0 !important;
}
.storage-header {
  padding: 10px 12px;
  display: flex;
  align-items: center;
  width: 100%;
}
.storage-header:hover {
  background: rgba(255, 255, 255, 0.02);
}
.storage-details {
  padding: 14px 16px;
  background: rgba(0, 0, 0, 0.15);
  border-top: 1px solid var(--border);
}
.storage-key-name {
  font-weight: 700;
  color: #fff;
  margin-right: 12px;
}
.storage-summary-preview {
  color: var(--text-muted);
  font-size: 0.72rem;
  font-style: italic;
  flex: 1;
  text-align: right;
  padding-right: 8px;
}
.storage-pretty-val {
  margin: 0;
  font-family: var(--font-code);
  font-size: 0.78rem;
  color: #cbd5e1;
  white-space: pre-wrap;
  word-break: break-all;
}
.storage-diff-container {
  display: flex;
  gap: 16px;
  width: 100%;
  flex-wrap: wrap;
}
.storage-diff-pane {
  flex: 1;
  min-width: 250px;
  background: rgba(0, 0, 0, 0.2);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
.storage-diff-pane.before {
  border-color: rgba(244, 63, 94, 0.25);
  background: rgba(244, 63, 94, 0.02);
}
.storage-diff-pane.after {
  border-color: rgba(16, 185, 129, 0.25);
  background: rgba(16, 185, 129, 0.02);
}
.storage-diff-header {
  font-size: 0.7rem;
  font-weight: 800;
  text-transform: uppercase;
  padding: 6px 12px;
  border-bottom: 1px solid var(--border);
  letter-spacing: 0.05em;
}
.storage-diff-pane.before .storage-diff-header {
  color: var(--fail);
  background: rgba(244, 63, 94, 0.06);
  border-color: rgba(244, 63, 94, 0.15);
}
.storage-diff-pane.after .storage-diff-header {
  color: var(--pass);
  background: rgba(16, 185, 129, 0.06);
  border-color: rgba(16, 185, 129, 0.15);
}
.storage-diff-pre {
  margin: 0;
  padding: 12px;
  font-family: var(--font-code);
  font-size: 0.78rem;
  color: #cbd5e1;
  white-space: pre-wrap;
  word-break: break-all;
  overflow-y: auto;
  max-height: 240px;
}

/* App Tab Navigation & History Details */
.app-tab-navigation {
  display: flex;
  gap: 6px;
}
.app-tab-btn {
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
.app-tab-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #fff;
}
.app-tab-btn.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #000;
}
.history-caret {
  display: inline-block;
  transition: transform 0.2s;
  font-size: 0.65rem;
  margin-right: 8px;
  color: var(--accent);
}
.history-detail-row {
  background: rgba(0, 0, 0, 0.2) !important;
}
.run-details-expanded-container {
  padding: 20px 24px;
}
.run-details-expanded-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.run-metadata-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
  background: rgba(255, 255, 255, 0.01);
  padding: 14px 18px;
  border-radius: 8px;
  border: 1px solid var(--border);
}
.run-metadata-item {
  font-size: 0.8rem;
  color: #94a3b8;
}
.run-metadata-item strong {
  color: #cbd5e1;
  margin-right: 6px;
}
.run-metrics-mini-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 12px;
  margin-bottom: 4px;
}
.run-metric-mini {
  background: rgba(255, 255, 255, 0.02);
  border: 1px solid var(--border);
  padding: 10px 14px;
  border-radius: 6px;
  text-align: center;
}
.run-metric-mini .mini-val {
  font-size: 1.25rem;
  font-weight: 800;
  color: #fff;
}
.run-metric-mini .mini-label {
  font-size: 0.65rem;
  color: var(--text-muted);
  text-transform: uppercase;
  margin-top: 2px;
  letter-spacing: 0.05em;
}
.run-metric-mini.mini-passed {
  border-color: rgba(16, 185, 129, 0.15);
}
.run-metric-mini.mini-passed .mini-val {
  color: var(--pass);
}
.run-metric-mini.mini-failed {
  border-color: rgba(244, 63, 94, 0.15);
}
.run-metric-mini.mini-failed .mini-val {
  color: var(--fail);
}
.run-metric-mini.mini-rate .mini-val {
  color: var(--accent);
}
.run-all-passed-banner {
  padding: 14px;
  background: rgba(16, 185, 129, 0.04);
  border: 1px solid rgba(16, 185, 129, 0.15);
  color: var(--pass);
  border-radius: 6px;
  font-weight: 700;
  font-size: 0.85rem;
  text-align: center;
}
.run-failed-tests-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.run-failed-tests-list h4 {
  font-size: 0.8rem;
  color: var(--fail);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin: 0;
}
.run-failed-test-card {
  background: rgba(244, 63, 94, 0.01);
  border: 1px solid rgba(244, 63, 94, 0.12);
  border-radius: 8px;
  padding: 14px 18px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.run-failed-test-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.run-failed-test-title {
  font-family: var(--font-code);
  font-size: 0.85rem;
  font-weight: 700;
  color: #fff;
}
.run-failed-test-file {
  font-size: 0.78rem;
  color: var(--text-muted);
}
.run-failed-test-error {
  margin: 0;
  padding: 12px;
  background: #090d16;
  border: 1px solid var(--border);
  border-radius: 6px;
  font-family: var(--font-code);
  font-size: 0.78rem;
  color: var(--fail);
  white-space: pre-wrap;
  word-break: break-all;
  max-height: 180px;
  overflow-y: auto;
}

/* History Charts and Metric Panels */
.history-metrics-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  margin: 0 0 20px 0;
}
.history-charts-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(450px, 1fr));
  gap: 16px;
  margin: 0 0 24px 0;
}
.history-chart-card {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 20px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.15);
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.history-chart-title {
  font-size: 0.88rem;
  font-weight: 700;
  color: #fff;
  letter-spacing: 0.05em;
}
.history-chart-body {
  flex: 1;
  height: 180px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.chart-point {
  transition: r 0.15s ease, fill 0.15s ease;
  cursor: pointer;
}
.chart-point:hover {
  r: 6;
  fill: #22d3ee;
}
.chart-bar-segment {
  transition: opacity 0.15s ease;
  cursor: pointer;
}
.chart-bar-segment:hover {
  opacity: 0.85;
}
.no-chart-data {
  color: var(--text-muted);
  font-size: 0.85rem;
  font-style: italic;
}

/* Dynamic HTML Tooltip */
.chart-tooltip {
  position: absolute;
  padding: 8px 12px;
  background: rgba(15, 23, 42, 0.95);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 8px;
  color: #f1f5f9;
  font-family: var(--font-ui);
  font-size: 0.75rem;
  pointer-events: none;
  z-index: 10000;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(8px);
  display: none;
  flex-direction: column;
  gap: 4px;
}
.chart-tooltip-title {
  font-weight: 700;
  color: #fff;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  padding-bottom: 4px;
  margin-bottom: 2px;
}
.chart-tooltip-row {
  display: flex;
  justify-content: space-between;
  gap: 16px;
}
.chart-tooltip-val {
  font-weight: 600;
  font-family: var(--font-code);
}
''';
