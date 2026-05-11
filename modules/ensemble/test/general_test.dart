import 'package:ensemble/ensemble.dart';
import 'package:ensemble/action/saveFile/save_mobile.dart';
import 'package:ensemble/framework/definition_providers/remote_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test directory concat', () {
    expect(Ensemble().concatDirectory('hello', 'there'), 'hello/there/');
    expect(Ensemble().concatDirectory('hello/', 'there'), 'hello/there/');
    expect(Ensemble().concatDirectory('hello/', '/there'), 'hello/there/');
    expect(Ensemble().concatDirectory('/hello/', '/there/'), 'hello/there/');

    expect(Ensemble().concatDirectory('one/two', 'three'), 'one/two/three/');
    expect(Ensemble().concatDirectory('one/two/', '/three'), 'one/two/three/');
    expect(Ensemble().concatDirectory('one/two', '/three/four/'),
        'one/two/three/four/');
  });

  test('remote screen identifiers reject path traversal', () {
    expect(RemoteDefinitionProvider.isSafeScreenIdentifier('Hello Home'), true);
    expect(RemoteDefinitionProvider.isSafeScreenIdentifier('home_01'), true);
    expect(RemoteDefinitionProvider.isSafeScreenIdentifier('../admin'), false);
    expect(RemoteDefinitionProvider.isSafeScreenIdentifier('foo/bar'), false);
    expect(RemoteDefinitionProvider.isSafeScreenIdentifier(r'foo\bar'), false);
    expect(RemoteDefinitionProvider.isSafeScreenIdentifier('foo%2fbar'), false);
  });

  test('saved file names reject path segments', () {
    expect(sanitizeFileName('report.pdf'), 'report.pdf');
    expect(sanitizeFileName(' report.pdf '), 'report.pdf');
    expect(() => sanitizeFileName('../report.pdf'), throwsArgumentError);
    expect(() => sanitizeFileName('foo/bar.pdf'), throwsArgumentError);
    expect(() => sanitizeFileName(r'foo\bar.pdf'), throwsArgumentError);
    expect(() => sanitizeFileName('foo%2fbar.pdf'), throwsArgumentError);
  });
}
