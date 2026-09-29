import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'cases.dart';
import 'resources.dart';
import 'results.dart';
import 'operation_cases.dart';

const workerPrefix = 'ENSEMBLE_BENCHMARK_V1:';

void benchmarkWorkerMain() {
  final options = jsonDecode(const String.fromEnvironment(
      'ensembleBenchmarkOptions',
      defaultValue: '{}')) as Map<String, dynamic>;
  testWidgets('standalone runner benchmark', (tester) async {
    final mode = options['mode'] as String? ?? 'widget';
    final root = mode == 'integration'
        ? Directory.systemTemp.createTempSync('ensemble_bench_fixture_')
        : Directory(options['fixtureRoot'] as String)
      ..createSync(recursive: true);
    EnsembleTestHarness.ensureTestPlugins();
    await tester.runAsync(StorageManager().init);
    final fixtures = BenchmarkFixtures(tester, root);
    final cases = buildCases(fixtures, mode: mode);
    final requestedServices =
        (options['services'] as List? ?? []).cast<String>();
    final operationCasesForServices = operationCases.entries
        .where(
            (entry) => requestedServices.contains(entry.key.split('.').first))
        .map((entry) => entry.value)
        .toSet();
    final selected = cases
        .where((c) =>
            ((options['case'] != null ||
                    options['preset'] == 'full' ||
                    c.quick) &&
                ((options['services'] as List? ?? []).isEmpty ||
                    (options['services'] as List).contains(c.service) ||
                    operationCasesForServices.contains(c.id)) &&
                (options['case'] == null || options['case'] == c.id)) ||
            (c.service == 'control' && options['includeControls'] != false))
        .toList();
    if (options['catalogueOnly'] == true) {
      emitWorker({
        'catalogue': [for (final c in cases) c.toJson()],
        'selected': [for (final c in selected) c.toJson()],
        'bindingEnvironment': {
          'devicePixelRatio': tester.view.devicePixelRatio,
          'physicalWidth': tester.view.physicalSize.width,
          'physicalHeight': tester.view.physicalSize.height
        }
      }, options, mode);
      return;
    }
    print('${workerPrefix}ready');
    final watch = Stopwatch()..start();
    final results = <Map<String, Object?>>[];
    for (final c in selected) {
      print('${workerPrefix}case:${c.id}');
      if (c.skipReason != null) {
        results.add({
          ...c.toJson(),
          'status': 'skipped',
          'reason': c.skipReason,
          'samples': <Object>[]
        });
        continue;
      }
      final beforeRss = ProcessInfo.currentRss;
      final cpuBefore = processCpuMicroseconds();
      final samples = <Map<String, Object?>>[];
      Object? warmupError;
      final warmups = c.cold ? 0 : options['warmups'] as int? ?? 3;
      for (var i = 0; i < warmups; i++) {
        try {
          await c.prepare?.call();
          final result = await c.body();
          c.verify?.call(result);
        } catch (error) {
          warmupError = error;
          break;
        } finally {
          try {
            await c.cleanup?.call();
          } catch (error) {
            warmupError ??= error;
          }
        }
        if (warmupError != null) break;
      }
      if (warmupError != null) {
        results.add({
          ...c.toJson(),
          'status': 'invalid',
          'reason': 'Warmup failed: $warmupError',
          'samples': <Object>[]
        });
        continue;
      }
      for (var index = 0; index < (options['samples'] as int? ?? 10); index++) {
        final collector = BenchmarkCollector(
            caseId: c.id,
            sample: index + (options['sampleOffset'] as int? ?? 0),
            processId: pid.toString(),
            worker: options['worker'] as int? ?? 0,
            dimensions: {'executionMode': mode, ...c.dimensions},
            disabledExecutables:
                c.dimensions['codecFallback'] == true ? {'cwebp'} : {},
            executables: {
              'flutter': const String.fromEnvironment(
                  'ensembleBenchmarkFlutter',
                  defaultValue: 'flutter')
            });
        var elapsed = 0, iterations = 0;
        var preparationUs = 0, cleanupUs = 0, verificationUs = 0;
        Object? observation;
        final external = <Map<String, dynamic>>[];
        Object? error;
        final minimum = (options['minimumSampleMs'] as int? ?? 200) * 1000;
        do {
          Stopwatch? measurementClock;
          var counted = false;
          try {
            final preparation = Stopwatch()..start();
            try {
              await c.prepare?.call();
            } finally {
              preparation.stop();
              preparationUs += preparation.elapsedMicroseconds;
            }
            final clock = measurementClock = Stopwatch()..start();
            final result = await RunnerBenchmark.collect(
                collector,
                () => RunnerBenchmark.async(
                    'benchmark_harness', 'case', () async => c.body()));
            clock.stop();
            elapsed += clock.elapsedMicroseconds;
            iterations++;
            counted = true;
            final verification = Stopwatch()..start();
            try {
              c.verify?.call(result);
              external.addAll(c.externalMeasurements?.call() ?? []);
            } finally {
              verification.stop();
              verificationUs += verification.elapsedMicroseconds;
            }
            if (c.id == 'screenshot.sustained.100')
              observation = {'rssCheckpointsBytes': result};
            if (collector.spans.any((s) => s.endUs == null))
              throw StateError('Unclosed measurement spans');
          } catch (e) {
            if (measurementClock != null && !counted) {
              measurementClock.stop();
              elapsed += measurementClock.elapsedMicroseconds;
              iterations++;
            }
            error = e;
          } finally {
            final cleanup = Stopwatch()..start();
            try {
              await c.cleanup?.call();
            } catch (e) {
              error ??= e;
            } finally {
              cleanup.stop();
              cleanupUs += cleanup.elapsedMicroseconds;
            }
          }
        } while (error == null &&
            c.batchable &&
            !c.cold &&
            elapsed < minimum &&
            iterations < 500000);
        if (iterations == 500000 && elapsed < minimum)
          error = StateError(
              'Batch limit reached before minimum measurement duration');
        samples.add({
          'caseId': c.id,
          'index': index + (options['sampleOffset'] as int? ?? 0),
          'valid': error == null,
          'error': error?.toString(),
          'iterations': iterations,
          'elapsedUs': elapsed,
          'fixturePreparationUs': preparationUs,
          'fixtureCleanupUs': cleanupUs,
          'verificationUs': verificationUs,
          if (observation != null) 'resourceObservations': observation,
          'batchCapped': iterations == 500000 && elapsed < minimum,
          'externalProcessResources': [
            for (final e in external) e['resources']
          ],
          'spans': [
            ...collector.toJson(),
            for (final e in external)
              for (final raw in e['spans'] as List)
                {
                  ...raw as Map,
                  'caseId': c.id,
                  'sample': index + (options['sampleOffset'] as int? ?? 0)
                }
          ]
        });
        if (mode == 'widget') {
          final sample = samples.last;
          sample['summary'] = summarizeCase({
            'samples': [sample]
          });
          final path =
              '${File(options['workerOutput'] as String).parent.path}/spans/${c.id}.${sample['index']}.json.gz';
          final file = File(path);
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(
              gzip.encode(utf8.encode(jsonEncode(sample['spans']))));
          sample.remove('spans');
          sample['spansPath'] = path;
        }
      }
      final cpuAfter = processCpuMicroseconds();
      results.add({
        ...c.toJson(),
        'status':
            samples.every((s) => s['valid'] == true) ? 'measured' : 'invalid',
        'samples': samples,
        'resources': {
          'scope': options['isolatedCase'] == true
              ? 'dedicated-case-process'
              : 'shared-process',
          'rssBeforeBytes': beforeRss,
          'rssAfterBytes': ProcessInfo.currentRss,
          'processPeakRssBytes': ProcessInfo.maxRss,
          'cpuTimeUs': cpuBefore == null || cpuAfter == null
              ? null
              : cpuAfter - cpuBefore,
          'cpuScope':
              'Case interval including preparation, warmup and result collection; excludes process bootstrap',
          if (cpuBefore == null || cpuAfter == null)
            'cpuUnavailableReason': 'getrusage unavailable on this platform'
        }
      });
    }
    emitWorker({
      'cases': results,
      'workerWallMs': watch.elapsedMilliseconds,
      'processId': pid,
      'worker': options['worker'] ?? 0
    }, options, mode);
    if (mode == 'integration') root.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(hours: 3)));
}

void emitWorker(
    Map<String, Object?> result, Map<String, dynamic> options, String mode) {
  final bytes = gzip.encode(utf8.encode(jsonEncode(result)));
  if (mode == 'widget') {
    File(options['workerOutput'] as String).writeAsBytesSync(bytes);
  } else {
    final checksum = sha256.convert(bytes).toString();
    print('${workerPrefix}${jsonEncode({
          'event': 'start',
          'size': bytes.length,
          'sha256': checksum
        })}');
    for (var offset = 0; offset < bytes.length; offset += 1200) {
      print('${workerPrefix}${jsonEncode({
            'event': 'chunk',
            'offset': offset,
            'data': base64Encode(Uint8List.fromList(
                bytes.sublist(offset, (offset + 1200).clamp(0, bytes.length))))
          })}');
    }
    print('${workerPrefix}${jsonEncode({'event': 'end', 'sha256': checksum})}');
  }
}
