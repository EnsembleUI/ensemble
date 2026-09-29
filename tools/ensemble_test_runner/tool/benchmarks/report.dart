import 'dart:convert';
import 'dart:io';

void writeBenchmarkReport(File file, List<Map<String, dynamic>> runs) {
  file.parent.createSync(recursive: true);
  final data = jsonEncode(runs).replaceAll('<', r'\u003c');
  file.writeAsStringSync(
      '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Runner benchmarks</title>
<style>body{font:15px system-ui;background:#101722;color:#e8edf5;margin:32px auto;max-width:1200px;padding:0 24px}h1{font-size:28px}select,button{font:inherit;padding:8px;margin:8px;background:#223047;color:inherit;border:1px solid #57677f;border-radius:4px}table{width:100%;border-collapse:collapse;margin:16px 0}th,td{text-align:left;padding:9px;border-bottom:1px solid #31405a}th{color:#9ec6fc}pre{white-space:pre-wrap;background:#192438;padding:16px;max-height:500px;overflow:auto}.muted{color:#adbbce}.bad{color:#ffb0a5}svg{width:100%;height:180px;background:#192438}details{margin:12px 0}a{color:#9ec6fc}</style>
<h1>Test-runner benchmarks</h1><p class="muted">Exclusive elapsed time excludes nested work. Elapsed time is not CPU time. Worker work totals can exceed suite wall time.</p>
<p id="empty" class="empty" hidden></p><div id="history" hidden>
<label>Run <select id="run"></select></label><label>Case <select id="case"></select></label>
<div id="context"></div><div id="coverage"></div><h2>Fixed-workload trend</h2><svg id="trend" viewBox="0 0 1000 180" role="img" aria-label="Median microseconds per iteration across compatible runs"></svg><div id="trendLabels"></div>
<h2>Service cost per iteration</h2><table><thead><tr><th>Service</th><th>Exclusive µs</th><th>Inclusive µs</th><th>Calls / iteration</th><th>Median / p95 µs per call</th></tr></thead><tbody id="services"></tbody></table>
<h2>Operation breakdown</h2><table><thead><tr><th>Operation</th><th>Exclusive µs / iteration</th><th>Median / p95 µs per call</th><th>Calls / iteration</th><th>Work counters / iteration</th></tr></thead><tbody id="ops"></tbody></table>
<h2>Nested operation paths</h2><table><thead><tr><th>Path</th><th>Exclusive µs / iteration</th><th>Median / p95 µs</th><th>Calls / iteration</th></tr></thead><tbody id="nested"></tbody></table>
<details open><summary>Baseline comparison</summary><pre id="comparison"></pre></details><details><summary>Case, resources, variability and worker details</summary><pre id="details"></pre></details>
<details><summary>Skipped and invalid cases</summary><pre id="skipped"></pre></details>
</div>
<script>const runs=$data;
const byId=id=>document.getElementById(id), fmt=n=>n==null?'unavailable':Number(n).toFixed(2);
function cell(row,value){const td=document.createElement('td');td.textContent=value;row.append(td)}
function row(table,values){const tr=document.createElement('tr');values.forEach(v=>cell(tr,v));byId(table).append(tr)}
function canonical(v){if(Array.isArray(v))return v.map(canonical);if(v&&typeof v==='object')return Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])]));return v}function key(r){return JSON.stringify(canonical([r.environment,r.catalogueHash,r.preset,r.mode,r.workers,r.protocol,r.selection]))}
function cases(){const r=runs[byId('run').value];byId('case').replaceChildren();if(!r)return;for(const c of r.cases){const o=new Option(c.id+' — '+c.status,c.id);byId('case').add(o)}const preferred=r.cases.find(c=>c.kind==='workflow'&&c.status==='measured')||r.cases.find(c=>c.status==='measured'&&c.service!=='control')||r.cases[0];if(preferred)byId('case').value=preferred.id;render()}
function render(){const r=runs[byId('run').value];if(!r)return;const c=r.cases.find(c=>c.id===byId('case').value);if(!c)return;
byId('context').textContent=r.timestamp+' | '+r.branch+' | '+r.commit+' | '+r.mode+' | baseline: '+(r.baselineRunId||'no baseline');
byId('coverage').textContent=JSON.stringify(r.coverage||{});byId('services').replaceChildren();byId('ops').replaceChildren();const grouped={};
for(const op of c.operations||[]){const g=grouped[op.service]||(grouped[op.service]={exclusive:0,inclusive:0,calls:0});g.exclusive+=op.exclusiveUsPerIteration||0;g.calls+=op.invocationsPerIteration||0;g.inclusive+=(op.perCallUs.mean||0)*(op.invocationsPerIteration||0)}
if(c.services){for(const g of c.services.slice().sort((a,b)=>b.exclusiveUsPerIteration-a.exclusiveUsPerIteration))row('services',[g.service,fmt(g.exclusiveUsPerIteration),fmt(g.inclusiveUsPerIteration),fmt(g.invocationsPerIteration),fmt(g.perCallUs.median)+' / '+fmt(g.perCallUs.p95)])}else{for(const [name,g] of Object.entries(grouped).sort((a,b)=>b[1].exclusive-a[1].exclusive))row('services',[name,fmt(g.exclusive),fmt(g.inclusive),fmt(g.calls),'legacy summary'])}
for(const op of (c.operations||[]).slice().sort((a,b)=>b.exclusiveUsPerIteration-a.exclusiveUsPerIteration))row('ops',[op.key,fmt(op.exclusiveUsPerIteration),fmt(op.perCallUs.median)+' / '+fmt(op.perCallUs.p95),fmt(op.invocationsPerIteration),JSON.stringify(op.countersPerIteration)]);
byId('nested').replaceChildren();for(const n of c.nestedOperations||[])row('nested',[n.path,fmt(n.exclusiveUsPerIteration),fmt(n.perCallUs.median)+' / '+fmt(n.perCallUs.p95),fmt(n.callsPerIteration)]);
byId('comparison').textContent=JSON.stringify((r.comparison||[]).find(x=>x.caseId===c.id)||{message:r.baselineRunId?'No compatible measured case':'no baseline'},null,2);byId('details').textContent=JSON.stringify({case:c,environment:r.environment,resources:r.resources,workers:r.workerResults,suiteWallMs:r.suiteWallMs,longestWorkerWallMs:r.longestWorkerWallMs,workerProcesses:c.workers,collectionOverhead:r.collectionOverhead},null,2);byId('skipped').textContent=JSON.stringify(r.cases.filter(c=>c.status!=='measured'),null,2);
const points=runs.slice().reverse().filter(x=>key(x)===key(r)).map(x=>({run:x,c:x.cases.find(y=>y.id===c.id&&y.status==='measured')})).filter(x=>x.c&&x.c.timePerOperationUs.median!=null);byId('trend').replaceChildren();if(points.length){const max=Math.max(1,...points.map(x=>x.c.timePerOperationUs.median));const poly=document.createElementNS('http://www.w3.org/2000/svg','polyline');poly.setAttribute('points',points.map((x,i)=>(20+i*960/Math.max(1,points.length-1))+','+(160-x.c.timePerOperationUs.median/max*140)).join(' '));poly.setAttribute('fill','none');poly.setAttribute('stroke','#8bbcff');poly.setAttribute('stroke-width','3');byId('trend').append(poly)}byId('trendLabels').textContent=points.map(x=>x.run.timestamp+' '+fmt(x.c.timePerOperationUs.median)+' µs').join(' | ')}
if(runs.length){byId('history').hidden=false;runs.forEach((r,i)=>byId('run').add(new Option(r.timestamp+' '+r.commit,i)));byId('run').onchange=cases;byId('case').onchange=render;cases()}else{byId('empty').hidden=false;byId('empty').textContent='No benchmark runs are stored yet. From tools/ensemble_test_runner, run “dart run tool/benchmark_runner.dart --preset=quick”, then rerun “dart run tool/benchmark_runner.dart --history” to refresh this report.'}</script></html>''');
}
