import 'package:ensemble_test_runner/session/local/media_semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('media semantics', () {
    test('classifies standard image providers', () {
      expect(mediaWidgetType(Image.network('https://example.test/photo.png')),
          'image');
      expect(mediaWidgetType(Image.network('https://example.test/photo.gif')),
          'gif');
      expect(mediaWidgetType(Image.network('https://example.test/icon.svg')),
          'svg');
    });

    test('extracts stable source basenames', () {
      expect(mediaSourceLabel('https://example.test/assets/photo.png?cache=1'),
          'photo.png');
      expect(mediaSourceLabel('assets/illustration.svg'), 'illustration.svg');
      expect(mediaSourceLabel(<int>[1, 2, 3]), 'memory');
      expect(mediaSourceLabel('  '), isNull);
    });
  });
}
