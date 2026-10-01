import 'dart:convert';
import 'dart:io';

void writeBenchmarkReport(File file, List<Map<String, dynamic>> runs) {
  file.parent.createSync(recursive: true);
  final data = jsonEncode(runs).replaceAll('<', r'\u003c');
  final html = r'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <title>Runner benchmark history</title>
  <style>
    :root{color-scheme:dark;--bg:#0a1020;--panel:#121b2d;--panel2:#18243a;--line:#2a3952;--text:#edf3fc;--muted:#9babc2;--blue:#8eb8ff;--cyan:#60dfc0;--orange:#ffbd72;--red:#ff8793;--green:#75dfaa;--radius:16px}
    *{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at 80% -10%,#1a3151 0,transparent 35%),var(--bg);color:var(--text);font:15px/1.5 Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    .page{width:calc(100% - 48px);max-width:1440px;margin:0 auto;padding:42px 0 72px}.hero{display:flex;justify-content:space-between;align-items:flex-end;gap:24px;margin-bottom:28px}.eyebrow{color:var(--cyan);font-size:12px;font-weight:750;letter-spacing:.13em;text-transform:uppercase}.hero h1{font-size:clamp(30px,4vw,44px);letter-spacing:-.04em;line-height:1.1;margin:9px 0 10px}.hero p{max-width:740px;color:var(--muted);margin:0}.hero-note{color:var(--muted);text-align:right;font-size:13px;max-width:250px}
    .panel{background:linear-gradient(145deg,rgba(24,36,58,.96),rgba(17,26,43,.96));border:1px solid var(--line);border-radius:var(--radius);box-shadow:0 16px 40px rgba(0,0,0,.16)}.controls{display:flex;align-items:end;gap:16px;padding:18px 20px;margin-bottom:18px}.field{display:grid;gap:7px;min-width:0}.field.run{flex:1}.field.case{flex:1.25}.field label,.label{color:var(--muted);font-size:12px;font-weight:700;letter-spacing:.06em;text-transform:uppercase}select{width:100%;min-width:0;min-height:44px;background:#0d1728;color:var(--text);border:1px solid #3a4d6c;border-radius:10px;padding:0 38px 0 12px;font:inherit}select:focus-visible,button:focus-visible{outline:2px solid var(--cyan);outline-offset:2px}
    .meta{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin:0 0 18px}.chip{display:inline-flex;align-items:center;gap:7px;background:#16243a;border:1px solid var(--line);border-radius:999px;padding:6px 10px;color:#cad7e8;font-size:12px}.chip strong{color:var(--text);font-weight:650}.chip.good{color:var(--green)}.chip.warn{color:var(--orange)}.chip.bad{color:var(--red)}
    .stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin:0 0 18px}.stat{padding:18px 20px;min-height:120px}.stat .label{display:block}.stat strong{display:block;font-size:clamp(22px,3vw,30px);line-height:1.15;letter-spacing:-.035em;margin:13px 0 5px}.stat small{color:var(--muted)}
    .section{padding:22px 24px;margin:18px 0}.section-head{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;margin:0 0 18px}.section h2{font-size:19px;letter-spacing:-.02em;margin:0}.section-head p{color:var(--muted);font-size:13px;margin:4px 0 0}.trend-empty{display:flex;align-items:center;gap:12px;min-height:118px;background:#0e1727;border:1px dashed #3b4a63;border-radius:12px;padding:20px;color:var(--muted)}.trend-empty strong{color:var(--text)}
    svg{display:block;width:100%;height:auto;min-height:190px;background:#0e1727;border-radius:12px}.grid-line{stroke:#24334a;stroke-width:1}.axis-label{fill:#8d9db5;font-size:12px}.trend-line{fill:none;stroke:var(--cyan);stroke-width:3;stroke-linecap:round;stroke-linejoin:round}.trend-point{fill:var(--bg);stroke:var(--cyan);stroke-width:3}.trend-summary{color:var(--muted);font-size:13px;margin-top:12px}.trend-ends{display:flex;justify-content:space-between;gap:16px;color:var(--muted);font-size:12px;margin-top:8px}
    .table-wrap{overflow:auto;border:1px solid var(--line);border-radius:12px}table{width:100%;border-collapse:collapse;min-width:760px}th,td{text-align:left;padding:12px 14px;border-bottom:1px solid var(--line);vertical-align:top}th{position:sticky;top:0;background:#152239;color:#b9c9df;font-size:11px;font-weight:750;letter-spacing:.06em;text-transform:uppercase;white-space:nowrap}tbody tr:last-child td{border-bottom:0}tbody tr:hover{background:rgba(142,184,255,.045)}td.numeric{font-variant-numeric:tabular-nums;white-space:nowrap}.service-name{font-weight:700}.bar{height:4px;background:#27364d;border-radius:99px;margin-top:8px;min-width:70px;overflow:hidden}.bar span{display:block;height:100%;background:linear-gradient(90deg,var(--blue),var(--cyan));border-radius:inherit}.counter{display:inline-block;margin:0 5px 4px 0;padding:2px 7px;border-radius:6px;background:#1d2b42;color:#bacce4;font-size:11px;white-space:nowrap}
    .subsections{display:grid;grid-template-columns:1fr 1fr;gap:16px}.subpanel{padding:18px;background:rgba(10,16,32,.34);border:1px solid var(--line);border-radius:12px}.subpanel h3{font-size:15px;margin:0 0 12px}.subpanel p{color:var(--muted);font-size:13px;margin:0}.delta{font-size:20px;font-weight:750;margin:5px 0}.delta.good{color:var(--green)}.delta.bad{color:var(--red)}.delta.neutral{color:var(--muted)}
    details{border-top:1px solid var(--line);padding:16px 0}details:first-of-type{margin-top:4px}summary{cursor:pointer;color:#cbd8e9;font-weight:650}pre{white-space:pre-wrap;overflow:auto;max-height:460px;background:#0d1728;color:#c6d5e8;padding:16px;border-radius:10px;font:12px/1.55 ui-monospace,SFMono-Regular,Menlo,monospace}.empty{max-width:760px;padding:24px 26px;border:1px solid #3b4d69;background:#131f33;border-radius:14px;color:var(--muted)}.empty h2{font-size:18px;color:var(--text);margin:0 0 8px}.empty code{display:inline-block;color:var(--cyan);background:#0b1423;border-radius:7px;padding:6px 9px;margin:8px 0}.footer{color:#73839b;font-size:12px;text-align:center;margin-top:28px}
    @media(max-width:850px){.page{width:calc(100% - 32px);padding-top:28px}.hero{display:block}.hero-note{text-align:left;margin-top:12px;max-width:none}.stats{grid-template-columns:repeat(2,minmax(0,1fr))}.subsections{grid-template-columns:1fr}.controls{align-items:stretch;flex-direction:column}.field.run,.field.case{flex:auto}.section{padding:18px 16px}}
    @media(max-width:480px){.page{width:calc(100% - 22px);padding-top:22px}.stats{grid-template-columns:1fr 1fr;gap:9px}.stat{padding:14px;min-height:108px}.stat strong{font-size:21px}.chip{font-size:11px}.section{padding:15px 12px}.trend-ends{font-size:10px}}
  </style>
</head>
<body>
  <main class="page">
    <header class="hero">
      <div><div class="eyebrow">Ensemble · Performance</div><h1>Runner benchmarks</h1><p>See which runner services take the time, what they do per call, and how the same workload changes between compatible runs.</p></div>
      <div class="hero-note">Timings are elapsed wall time, not CPU time. Nested service time is excluded from exclusive totals.</div>
    </header>
    <p id="empty" class="empty" hidden></p>
    <div id="history" hidden>
      <section class="panel controls" aria-label="Report selection">
        <div class="field run"><label for="run">Benchmark run</label><select id="run"></select></div>
        <div class="field case"><label for="case">Workload case</label><select id="case"></select></div>
      </section>
      <div id="meta" class="meta"></div>
      <section id="stats" class="stats" aria-label="Selected case summary"></section>
      <section class="panel section">
        <div class="section-head"><div><h2>Workload trend</h2><p>Median time per iteration for this case across compatible runs.</p></div><span id="trend-count" class="chip"></span></div>
        <div id="trend-empty" class="trend-empty" hidden></div>
        <svg id="trend" viewBox="0 0 1000 250" role="img" aria-label="Selected workload timing across compatible benchmark runs"></svg>
        <div id="trend-summary" class="trend-summary"></div><div id="trend-ends" class="trend-ends"></div>
      </section>
      <section class="panel section">
        <div class="section-head"><div><h2>Service cost</h2><p>Services are ranked by exclusive time per iteration. Per-call timing includes warm and slow outliers.</p></div></div>
        <div class="table-wrap"><table><thead><tr><th>Service</th><th>Exclusive / iteration</th><th>Inclusive / iteration</th><th>Calls / iteration</th><th>Median / p95 per call</th></tr></thead><tbody id="services"></tbody></table></div>
      </section>
      <section class="panel section">
        <div class="section-head"><div><h2>Operation breakdown</h2><p>Find the specific runner operation contributing to each service cost.</p></div></div>
        <div class="table-wrap"><table><thead><tr><th>Operation</th><th>Exclusive / iteration</th><th>Median / p95 per call</th><th>Calls / iteration</th><th>Work counters / iteration</th></tr></thead><tbody id="ops"></tbody></table></div>
      </section>
      <section class="panel section">
        <div class="section-head"><div><h2>Comparison and run coverage</h2><p>Compare only matching workloads and environments. Coverage keeps skipped and invalid work visible.</p></div></div>
        <div class="subsections">
          <div class="subpanel"><h3>Baseline comparison</h3><div id="comparison"></div></div>
          <div class="subpanel"><h3>Catalogue coverage</h3><div id="coverage" class="meta"></div></div>
        </div>
      </section>
      <section class="panel section">
        <details><summary>Nested operation paths</summary><div class="table-wrap"><table><thead><tr><th>Operation path</th><th>Exclusive / iteration</th><th>Median / p95 per call</th><th>Calls / iteration</th></tr></thead><tbody id="nested"></tbody></table></div></details>
        <details><summary id="exceptions-title">Skipped and invalid cases</summary><div class="table-wrap"><table><thead><tr><th>Case</th><th>Status</th><th>Reason</th></tr></thead><tbody id="exceptions"></tbody></table></div></details>
        <details><summary>Environment, resources and raw case data</summary><pre id="details"></pre></details>
      </section>
      <footer class="footer">Generated from the standalone runner benchmark history. Detailed spans remain in each run’s export folder.</footer>
    </div>
  </main>
  <script>
    const runs = __BENCHMARK_RUNS__;
    const byId = id => document.getElementById(id);
    const number = value => value == null || !Number.isFinite(Number(value)) ? '—' : new Intl.NumberFormat(undefined,{maximumFractionDigits:1}).format(Number(value));
    const duration = microseconds => {
      if (microseconds == null || !Number.isFinite(Number(microseconds))) return '—';
      const value = Number(microseconds);
      if (Math.abs(value) >= 1000000) return number(value / 1000000) + ' s';
      if (Math.abs(value) >= 1000) return number(value / 1000) + ' ms';
      return number(value) + ' µs';
    };
    const shortHash = value => value ? String(value).slice(0,8) : 'unknown revision';
    const statusClass = status => status === 'measured' ? 'good' : status === 'invalid' ? 'bad' : 'warn';
    function addChip(parent, label, value, className) {
      const chip = document.createElement('span');
      chip.className = 'chip' + (className ? ' ' + className : '');
      const strong = document.createElement('strong');
      strong.textContent = value;
      chip.append(label + ' ', strong);
      parent.append(chip);
    }
    function addStat(label, value, note) {
      const card = document.createElement('article');
      card.className = 'panel stat';
      const name = document.createElement('span'); name.className = 'label'; name.textContent = label;
      const result = document.createElement('strong'); result.textContent = value;
      const hint = document.createElement('small'); hint.textContent = note;
      card.append(name, result, hint); byId('stats').append(card);
    }
    function addCell(row, value, className) {
      const cell = document.createElement('td');
      if (className) cell.className = className;
      cell.textContent = value == null ? '—' : String(value);
      row.append(cell); return cell;
    }
    function addRow(bodyId, values) {
      const row = document.createElement('tr');
      values.forEach(value => addCell(row, value));
      byId(bodyId).append(row);
      return row;
    }
    function counterSummary(counters) {
      const entries = Object.entries(counters || {});
      if (!entries.length) return '—';
      return entries.map(([name, value]) => name.replace(/([A-Z])/g,' $1').replaceAll('_',' ') + ': ' + number(value)).join(' · ');
    }
    function canonical(value) {
      if (Array.isArray(value)) return value.map(canonical);
      if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key,canonical(value[key])]));
      return value;
    }
    function environmentKey(run) {
      const environment=Object.assign({},run.environment || {});
      delete environment.fixtureSourceHash;
      return JSON.stringify(canonical([environment,run.catalogueHash,run.preset,run.mode,run.workers,run.protocol,run.selection]));
    }
    function comparisonFor(run,item) {
      const stored=(run.comparison || []).find(entry=>entry.caseId===item.id);
      if (stored) return stored;
      const currentIndex=Number(byId('run').value);
      const dimensions=JSON.stringify(canonical(item.dimensions));
      const previous=runs.slice(currentIndex+1).find(candidate=>{
        if (environmentKey(candidate)!==environmentKey(run)) return false;
        const priorCase=(candidate.cases || []).find(entry=>entry.id===item.id && entry.status==='measured');
        return priorCase && priorCase.fixtureVersion===item.fixtureVersion && JSON.stringify(canonical(priorCase.dimensions))===dimensions;
      });
      if (!previous) return null;
      const priorCase=previous.cases.find(entry=>entry.id===item.id && entry.status==='measured');
      const baseline=priorCase.timePerOperationUs && priorCase.timePerOperationUs.median;
      const current=item.timePerOperationUs && item.timePerOperationUs.median;
      return {
        caseId:item.id,
        baselineRunId:previous.runId,
        baselineTimestamp:previous.timestamp,
        baselineMedianUs:baseline,
        medianUs:current,
        deltaUs:baseline == null || current == null ? null : Number(current)-Number(baseline),
        deltaPercent:baseline == null || current == null || Number(baseline)===0 ? null : (Number(current)-Number(baseline))/Number(baseline)*100
      };
    }
    function selectedRun() { return runs[Number(byId('run').value)]; }
    function selectCase() {
      const run = selectedRun();
      byId('case').replaceChildren();
      if (!run) return;
      (run.cases || []).forEach(item => {
        const option = new Option(item.id + ' · ' + item.status,item.id);
        byId('case').add(option);
      });
      const preferred = run.cases.find(item => item.kind === 'workflow' && item.status === 'measured') || run.cases.find(item => item.status === 'measured' && item.service !== 'control') || run.cases[0];
      if (preferred) byId('case').value = preferred.id;
      render();
    }
    function addSvgElement(name, attributes, text) {
      const element = document.createElementNS('http://www.w3.org/2000/svg',name);
      Object.entries(attributes || {}).forEach(([key,value]) => element.setAttribute(key,String(value)));
      if (text != null) element.textContent = text;
      byId('trend').append(element);
      return element;
    }
    function renderTrend(run, item) {
      const points = runs.slice().reverse().filter(candidate => environmentKey(candidate) === environmentKey(run))
        .map(candidate => ({run:candidate,case:(candidate.cases || []).find(entry => entry.id === item.id && entry.status === 'measured')}))
        .filter(point => point.case && point.case.timePerOperationUs && point.case.timePerOperationUs.median != null);
      byId('trend-count').textContent = points.length + (points.length === 1 ? ' compatible run' : ' compatible runs');
      byId('trend').replaceChildren();
      byId('trend').hidden = points.length < 2;
      byId('trend-empty').hidden = points.length >= 2;
      byId('trend-ends').replaceChildren();
      if (points.length < 2) {
        byId('trend-empty').textContent = points.length === 1
          ? 'Only one compatible run includes this case. Run the same preset and selection again to build a trend.'
          : 'No compatible runs contain this case yet.';
        byId('trend-summary').textContent = '';
        return;
      }
      const values = points.map(point => Number(point.case.timePerOperationUs.median));
      let min = Math.min(...values), max = Math.max(...values);
      if (min === max) { min = Math.max(0,min * .9); max = max * 1.1 || 1; }
      const left=90,right=980,top=24,bottom=212;
      for (let tick=0;tick<=4;tick++) {
        const y=top+(bottom-top)*tick/4;
        const value=max-(max-min)*tick/4;
        addSvgElement('line',{x1:left,y1:y,x2:right,y2:y,class:'grid-line'});
        addSvgElement('text',{x:left-12,y:y+4,'text-anchor':'end',class:'axis-label'},duration(value));
      }
      const coords=values.map((value,index)=>({
        x:left+(right-left)*index/(values.length-1),
        y:bottom-(value-min)/(max-min)*(bottom-top),
        point:points[index],value
      }));
      addSvgElement('polyline',{points:coords.map(point => point.x+','+point.y).join(' '),class:'trend-line'});
      coords.forEach(point => {
        const circle=addSvgElement('circle',{cx:point.x,cy:point.y,r:5,class:'trend-point'});
        const title=document.createElementNS('http://www.w3.org/2000/svg','title');
        title.textContent=new Date(point.point.run.timestamp).toLocaleString()+': '+duration(point.value);
        circle.append(title);
      });
      addSvgElement('text',{x:left,y:240,class:'axis-label'},new Date(points[0].run.timestamp).toLocaleDateString());
      addSvgElement('text',{x:right,y:240,'text-anchor':'end',class:'axis-label'},new Date(points[points.length-1].run.timestamp).toLocaleDateString());
      byId('trend-summary').textContent='Median per iteration ranged from '+duration(min)+' to '+duration(max)+'. Hover a point to see its run time.';
      const first=document.createElement('span'); first.textContent=new Date(points[0].run.timestamp).toLocaleString()+' · '+duration(values[0]);
      const last=document.createElement('span'); last.textContent=new Date(points[points.length-1].run.timestamp).toLocaleString()+' · '+duration(values[values.length-1]);
      byId('trend-ends').append(first,last);
    }
    function render() {
      const run=selectedRun(); if (!run) return;
      const item=(run.cases || []).find(entry => entry.id === byId('case').value); if (!item) return;
      byId('meta').replaceChildren();
      addChip(byId('meta'),'Run',new Date(run.timestamp).toLocaleString());
      addChip(byId('meta'),'Branch',run.branch || 'unknown');
      addChip(byId('meta'),'Revision',shortHash(run.commit));
      addChip(byId('meta'),'Mode',run.mode || 'unknown');
      addChip(byId('meta'),'Case status',item.status,statusClass(item.status));

      byId('stats').replaceChildren();
      const services=item.services || [];
      const serviceTotal=services.reduce((sum,service)=>sum+Number(service.exclusiveUsPerIteration || 0),0);
      addStat('Case median',duration(item.timePerOperationUs && item.timePerOperationUs.median),'elapsed per iteration');
      addStat('Service exclusive total',duration(serviceTotal),'sum of exclusive service time per iteration');
      addStat('Runner operations',String((item.operations || []).length),'distinct operations in this case');
      addStat('Valid samples',(item.validSampleCount || 0)+' / '+(item.sampleCount || 0),'valid / total measured samples');

      byId('services').replaceChildren();
      const maxService=Math.max(1,...services.map(service=>Number(service.exclusiveUsPerIteration || 0)));
      services.slice().sort((a,b)=>Number(b.exclusiveUsPerIteration || 0)-Number(a.exclusiveUsPerIteration || 0)).forEach(service=>{
        const row=document.createElement('tr');
        const name=addCell(row,service.service); name.textContent='';
        const title=document.createElement('div'); title.className='service-name'; title.textContent=service.service;
        const bar=document.createElement('div'); bar.className='bar';
        const fill=document.createElement('span'); fill.style.width=Math.max(0,Math.min(100,Number(service.exclusiveUsPerIteration || 0)/maxService*100))+'%';
        bar.append(fill); name.append(title,bar);
        addCell(row,duration(service.exclusiveUsPerIteration),'numeric');
        addCell(row,duration(service.inclusiveUsPerIteration),'numeric');
        addCell(row,number(service.invocationsPerIteration),'numeric');
        addCell(row,duration(service.perCallUs && service.perCallUs.median)+' / '+duration(service.perCallUs && service.perCallUs.p95),'numeric');
        byId('services').append(row);
      });
      if (!services.length) addRow('services',['No measured service spans','','','','']);

      byId('ops').replaceChildren();
      (item.operations || []).slice().sort((a,b)=>Number(b.exclusiveUsPerIteration || 0)-Number(a.exclusiveUsPerIteration || 0)).forEach(operation=>{
        addRow('ops',[
          operation.operation || operation.key,
          duration(operation.exclusiveUsPerIteration),
          duration(operation.perCallUs && operation.perCallUs.median)+' / '+duration(operation.perCallUs && operation.perCallUs.p95),
          number(operation.invocationsPerIteration),
          counterSummary(operation.countersPerIteration)
        ]);
      });
      if (!(item.operations || []).length) addRow('ops',['No operation spans','','','','']);

      byId('nested').replaceChildren();
      (item.nestedOperations || []).slice().sort((a,b)=>Number(b.exclusiveUsPerIteration || 0)-Number(a.exclusiveUsPerIteration || 0)).forEach(operation=>{
        addRow('nested',[operation.path,duration(operation.exclusiveUsPerIteration),duration(operation.perCallUs && operation.perCallUs.median)+' / '+duration(operation.perCallUs && operation.perCallUs.p95),number(operation.callsPerIteration)]);
      });
      if (!(item.nestedOperations || []).length) addRow('nested',['No nested operation paths','','','']);

      byId('coverage').replaceChildren();
      const coverage=run.coverage || {};
      addChip(byId('coverage'),'Catalogue',number(coverage.catalogueCases)+' cases');
      addChip(byId('coverage'),'Measured',number(coverage.measured),'good');
      addChip(byId('coverage'),'Skipped',number(coverage.skipped),'warn');
      addChip(byId('coverage'),'Invalid',number(coverage.invalid),Number(coverage.invalid || 0) ? 'bad' : 'good');
      addChip(byId('coverage'),'Operation coverage',number(coverage.operations && coverage.operations.measured)+' / '+number(coverage.operations && coverage.operations.selected));
      addChip(byId('coverage'),'Missing',number(coverage.missing),Number(coverage.missing || 0) ? 'bad' : 'good');

      const comparison=comparisonFor(run,item);
      const comparisonRoot=byId('comparison'); comparisonRoot.replaceChildren();
      if (comparison && comparison.baselineMedianUs != null && comparison.medianUs != null) {
        const summary=document.createElement('p');
        const change=comparison.deltaPercent == null ? null : Number(comparison.deltaPercent);
        const sign=change > 0 ? '+' : '';
        summary.className='delta '+(change == null ? 'neutral' : change > 1 ? 'bad' : change < -1 ? 'good' : 'neutral');
        summary.textContent=change == null ? 'Change unavailable' : sign+number(change)+'%';
        const note=document.createElement('p');
        const baselineRun=runs.find(entry=>entry.runId===comparison.baselineRunId);
        const baselineLabel=baselineRun ? new Date(baselineRun.timestamp).toLocaleString()+' · '+shortHash(baselineRun.commit) : comparison.baselineTimestamp ? new Date(comparison.baselineTimestamp).toLocaleString() : 'previous compatible run';
        note.textContent='Median changed from '+duration(comparison.baselineMedianUs)+' to '+duration(comparison.medianUs)+'. Compared with '+baselineLabel+'.';
        comparisonRoot.append(summary,note);
      } else {
        const note=document.createElement('p');
        note.textContent=run.baselineRunId ? 'No compatible measured baseline case is available.' : 'No compatible baseline yet. A later run with the same workload and environment will appear here.';
        comparisonRoot.append(note);
      }

      renderTrend(run,item);
      const exceptions=(run.cases || []).filter(entry=>entry.status !== 'measured');
      byId('exceptions-title').textContent='Skipped and invalid cases ('+exceptions.length+')';
      byId('exceptions').replaceChildren();
      exceptions.forEach(entry=>addRow('exceptions',[entry.id,entry.status,entry.reason || 'No reason recorded']));
      if (!exceptions.length) addRow('exceptions',['All selected cases measured','','']);
      byId('details').textContent=JSON.stringify({environment:run.environment,protocol:run.protocol,resources:run.resources,workers:run.workerResults,suiteWallMs:run.suiteWallMs,longestWorkerWallMs:run.longestWorkerWallMs,collectionOverhead:run.collectionOverhead,case:item},null,2);
    }
    if (runs.length) {
      byId('history').hidden=false;
      runs.forEach((run,index)=>{
        const date=new Date(run.timestamp).toLocaleString();
        byId('run').add(new Option(date+' · '+(run.branch || 'unknown')+' · '+shortHash(run.commit),String(index)));
      });
      byId('run').onchange=selectCase;
      byId('case').onchange=render;
      selectCase();
    } else {
      const empty=byId('empty'); empty.hidden=false;
      const heading=document.createElement('h2'); heading.textContent='No benchmark runs yet';
      const note=document.createElement('p'); note.textContent='This page is ready, but its history database has no recorded runs. From tools/ensemble_test_runner, run this command first:';
      const command=document.createElement('code'); command.textContent='dart run tool/benchmark_runner.dart --preset=quick';
      const next=document.createElement('p'); next.textContent='The command records results and generates this report. Run --history later to refresh it.';
      empty.append(heading,note,command,next);
    }
  </script>
</body>
</html>''';
  file.writeAsStringSync(html.replaceFirst('__BENCHMARK_RUNS__', data));
}
