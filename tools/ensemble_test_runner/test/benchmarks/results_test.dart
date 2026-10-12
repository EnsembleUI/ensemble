import 'package:flutter_test/flutter_test.dart';
import '../../tool/benchmarks/results.dart';

void main() {
  test('measurement quality reports insufficient sample evidence', () {
    final summary = summarizeCase({
      'id': 'case',
      'samples': [
        {
          'index': 0,
          'valid': true,
          'iterations': 1,
          'elapsedUs': 250000,
          'batchCapped': false,
          'spans': <Map<String, Object?>>[],
        },
      ],
    });

    expect(summary['measurementQuality'], {
      'classification': 'insufficient-samples',
      'minimumReliableSamples': 3,
      'stableCoefficientOfVariation': 0.1,
      'validSamples': 1,
      'totalSamples': 1,
      'singleIterationSamples': 1,
      'coefficientOfVariation': 0.0,
      'warnings': [
        'Collect at least 3 valid samples before comparing revisions.',
        '1 valid sample(s) completed one iteration; the sample duration floor did not batch them.',
      ],
    });
  });

  test('measurement quality identifies noisy samples without invalidating them',
      () {
    final summary = summarizeCase({
      'id': 'case',
      'samples': [
        for (final entry in [(0, 100000), (1, 200000), (2, 300000)])
          {
            'index': entry.$1,
            'valid': true,
            'iterations': 1,
            'elapsedUs': entry.$2,
            'batchCapped': false,
            'spans': <Map<String, Object?>>[],
          },
      ],
    });

    final quality = summary['measurementQuality'] as Map;
    expect(quality['classification'], 'unstable');
    expect(quality['validSamples'], 3);
    expect(quality['singleIterationSamples'], 3);
    expect((quality['warnings'] as List).length, 2);
  });
  test('memory measurement reports bounded high-water mark evidence', () {
    final summary = summarizeCase({
      'id': 'case',
      'samples': [
        for (final entry in [
          (0, 1000, 1200, 1000, 1400),
          (1, 1100, 1050, 1400, 1800),
          (2, 1200, 1500, 1800, 1800)
        ])
          {
            'index': entry.$1,
            'valid': true,
            'iterations': 2,
            'elapsedUs': 100000,
            'batchCapped': false,
            'memoryResources': {
              'rssBeforeBytes': entry.$2,
              'rssAfterBytes': entry.$3,
              'peakRssBeforeBytes': entry.$4,
              'peakRssAfterBytes': entry.$5,
              'peakRssDeltaBytes': entry.$5 - entry.$4,
            },
            'spans': <Map<String, Object?>>[],
          },
      ],
    });

    final memory = summary['memoryMeasurement'] as Map;
    expect(memory['measurement'], 'process-high-water-mark-delta');
    expect(memory['scope'], 'sample-boundary');
    expect(memory['samples'], 3);
    expect((memory['peakRssDeltaBytes'] as Map)['median'], 400);
    expect((memory['rssDeltaBytes'] as Map)['median'], 200);
    expect(memory['warnings'], isEmpty);
  });

  test('memory measurement marks missing sample evidence', () {
    final memory = memoryMeasurement([
      {
        'valid': true,
        'memoryResources': {
          'peakRssDeltaBytes': 0,
          'rssBeforeBytes': 100,
          'rssAfterBytes': 100,
        },
      },
      {'valid': true},
    ]);

    expect(memory['samples'], 1);
    expect(
      memory['warnings'],
      contains('Memory evidence is missing for one or more valid samples.'),
    );
  });
}
