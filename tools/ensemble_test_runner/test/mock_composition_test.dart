import 'package:ensemble_test_runner/mocks/mock_composition.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockComposition.parsePath', () {
    test('parses dotted and bracket segments', () {
      expect(
        MockComposition.parsePath('body.status[0].Children[1].Active'),
        ['body', 'status', 0, 'Children', 1, 'Active'],
      );
    });

    test('parses JSON Pointer paths', () {
      expect(
        MockComposition.parsePath('/body/status/0/Active'),
        ['body', 'status', 0, 'Active'],
      );
    });
  });

  group('MockComposition.setPath', () {
    test('updates nested values', () {
      final target = <String, dynamic>{
        'body': {
          'status': [
            {
              'Children': [
                {'Active': true},
              ],
            },
          ],
        },
      };
      MockComposition.setPath(
        target,
        'body.status[0].Children[0].Active',
        false,
      );
      expect(target['body']['status'][0]['Children'][0]['Active'], isFalse);
    });
  });

  group('MockComposition.resolveFile', () {
    test('applies \$extends and \$merge', () async {
      final files = <String, String>{
        'suite/tests/mocks/base.mock.json': '''
{
  "getDevices": {
    "body": {
      "status": [
        { "Name": "A", "Active": true, "SignalStrength": -70 }
      ]
    }
  }
}
''',
        'suite/tests/mocks/patch.mock.json': '''
{
  "\$extends": "mocks/base.mock.json",
  "getDevices": {
    "\$merge": {
      "body.status[0].SignalStrength": -26,
      "body.status[0].Active": false
    }
  }
}
''',
      };

      final resolved = await MockComposition.resolveFile(
        testAssetPath: 'suite/tests/home.test.yaml',
        mockFilePath: 'mocks/patch.mock.json',
        assetLoader: (path) async {
          final content = files[path];
          if (content == null) {
            throw FlutterError('Missing $path');
          }
          return content;
        },
        resolveAssetPath: (from, relative) {
          final segments = from.split('/')..removeLast();
          for (final part in relative.split('/')) {
            if (part.isEmpty || part == '.') continue;
            if (part == '..') {
              if (segments.isNotEmpty) segments.removeLast();
              continue;
            }
            segments.add(part);
          }
          return segments.join('/');
        },
      );

      final body = resolved['getDevices']!['body'] as Map;
      final device = (body['status'] as List).single as Map;
      expect(device['Name'], 'A');
      expect(device['SignalStrength'], -26);
      expect(device['Active'], isFalse);
    });

    test('rejects \$merge without a base API', () async {
      await expectLater(
        () => MockComposition.resolveFile(
          testAssetPath: 'suite/tests/home.test.yaml',
          mockFilePath: 'mocks/orphan.mock.json',
          assetLoader: (path) async => '''
{
  "getDevices": {
    "\$merge": { "body.count": 1 }
  }
}
''',
          resolveAssetPath: (from, relative) => 'suite/tests/$relative',
        ),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (e) => e.toString(),
            'message',
            contains(r'$merge'),
          ),
        ),
      );
    });
  });
}
