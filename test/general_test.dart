import 'package:ensemble/ensemble.dart';
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
}
