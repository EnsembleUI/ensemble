import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// A fixed Flutter host used by the production CLI's worker implementation.
Future<void> prepareWorkerProject(Directory root, {bool fail = false}) async {
  root.createSync(recursive: true);
  const packageRoot = String.fromEnvironment('ensembleBenchmarkPackageRoot');
  if (packageRoot.isEmpty)
    throw StateError('Worker fixture needs benchmark package root');
  File(p.join(root.path, 'pubspec.yaml'))
      .writeAsStringSync('''name: benchmark_fixture
environment:
  sdk: ">=3.5.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  ensemble_test_runner:
    path: ${jsonEncode(packageRoot)}
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
  assets:
    - tests/
''');
  final source = File(p.join(packageRoot, '.dart_tool', 'package_config.json'));
  final config = jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  for (final entry in config['packages'] as List) {
    entry['rootUri'] =
        source.uri.resolve(entry['rootUri'] as String).toString();
  }
  (config['packages'] as List).add({
    'name': 'benchmark_fixture',
    'rootUri': '../',
    'packageUri': 'lib/',
    'languageVersion': '3.5'
  });
  final dartTool = Directory(p.join(root.path, '.dart_tool'))..createSync();
  File(p.join(dartTool.path, 'package_config.json'))
      .writeAsStringSync(jsonEncode(config));
  final graph = jsonDecode(
      File(p.join(packageRoot, '.dart_tool', 'package_graph.json'))
          .readAsStringSync()) as Map<String, dynamic>;
  graph['roots'] = ['benchmark_fixture'];
  (graph['packages'] as List).add({
    'name': 'benchmark_fixture',
    'version': '0.0.0',
    'dependencies': ['ensemble_test_runner', 'flutter'],
    'devDependencies': ['flutter_test']
  });
  File(p.join(dartTool.path, 'package_graph.json'))
      .writeAsStringSync(jsonEncode(graph));
  for (final name in ['version']) {
    final file = File(p.join(packageRoot, '.dart_tool', name));
    if (file.existsSync()) file.copySync(p.join(dartTool.path, name));
  }
  final tests = Directory(p.join(root.path, 'tests'))..createSync();
  for (var i = 0; i < 8; i++)
    File(p.join(tests.path, '$i.test.yaml')).writeAsStringSync(jsonEncode({
      'id': 'worker_test_$i',
      'parallel': true,
      'steps': [
        {
          'expectText': {'text': fail && i == 7 ? 'Missing' : 'Ready'}
        }
      ]
    }));
  Directory(p.join(root.path, 'test')).createSync();
  File(p.join(root.path, 'test', 'benchmark_test.dart')).writeAsStringSync(
      _entry
          .replaceAll(
              '__TRACE_ROOT__', jsonEncode(p.join(root.path, 'child-traces')))
          .replaceAll(
              '__RESOURCES_URI__',
              File(p.join(packageRoot, 'tool', 'benchmarks', 'resources.dart'))
                  .uri
                  .toString()));
  final traces = Directory(p.join(root.path, 'child-traces'));
  if (traces.existsSync()) traces.deleteSync(recursive: true);
  traces.createSync();
}

const _entry = r'''
import 'dart:convert';
import 'dart:io';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import '__RESOURCES_URI__';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
 LiveTestWidgetsFlutterBinding.ensureInitialized();
 testWidgets('benchmark worker fixture',(tester) async {
  const worker=int.fromEnvironment('ensembleTestWorkerIndex');
  final collector=BenchmarkCollector(caseId:'worker_fixture',sample:0,processId:pid.toString(),worker:worker,dimensions:const {'executionMode':'widget'});
  final cpu=processCpuMicroseconds();
  final rss=ProcessInfo.currentRss;
  final result=await RunnerBenchmark.collect(collector,()=>RunnerBenchmark.async('worker_workload','execute',() async {
    const shard=String.fromEnvironment('ensembleTestShardId');
    final plan=await EnsembleTestExecutionPlanner.build(testsAssetPrefix:'tests/',selection:EnsembleTestSelection(exactIds:shard.isEmpty?{}:shard.split(',').toSet()));
    return runApplicationTestPlan(driver:Driver(),plan:plan,tester:tester,mode:ExecutionMode.widget);
  }));
  File(__TRACE_ROOT__+'/worker_${worker}_$pid.json').writeAsStringSync(jsonEncode({'spans':collector.toJson(),'resources':{'worker':worker,'processId':pid,'cpuTimeUs':cpu==null?null:(processCpuMicroseconds()??cpu)-cpu,'rssBeforeBytes':rss,'rssAfterBytes':ProcessInfo.currentRss,'peakRssBytes':ProcessInfo.maxRss}}));
  final report=jsonEncode(result.toJson());
  const reportFile=String.fromEnvironment('ensembleTestReportFile');
  if(reportFile.isNotEmpty){final file=File(reportFile);file.parent.createSync(recursive:true);file.writeAsStringSync(report);}
  print('ENSEMBLE_TEST_JSON_REPORT:'+report);
  if(result.failedCount>0)fail(result.summary);
 });
}
class Driver implements ApplicationTestDriver {
  @override Future<void> setUpSuite(TestSuiteContext context) async {print('ENSEMBLE_BENCHMARK_WORKLOAD_READY');}
  @override Future<void> prepareTest(TestLaunchContext context) async {}
  @override Future<TestApplicationHandle> launch(WidgetTester tester,TestLaunchContext context) async {
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Text('Ready'))));
    return Handle();
  }
  @override Future<void> tearDownTest(WidgetTester tester,TestLaunchContext context,TestApplicationHandle? handle) async {await tester.pumpWidget(const SizedBox.shrink());}
  @override Future<void> tearDownSuite() async {}
}
class Handle implements TestApplicationHandle {
  @override ApplicationTestServices get services=>const ApplicationTestServices();
}
''';
