import 'package:ensemble_test_runner/runner/test_font_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('font family aliases include package and unqualified names', () {
    expect(
      TestFontLoader.familyAliases(
        'packages/font_awesome_flutter/FontAwesomeSolid',
      ),
      containsAll([
        'packages/font_awesome_flutter/FontAwesomeSolid',
        'FontAwesomeSolid',
        'fontawesomesolid',
      ]),
    );
  });

  test('asset candidates include a decoded manifest path', () {
    expect(
      TestFontLoader.assetCandidates(
        'packages/font_awesome_flutter/lib/fonts/Font%20Awesome.otf',
      ),
      contains('packages/font_awesome_flutter/lib/fonts/Font Awesome.otf'),
    );
  });
}
