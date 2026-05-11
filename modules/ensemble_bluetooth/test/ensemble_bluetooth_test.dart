import 'package:flutter_test/flutter_test.dart';

import 'package:ensemble_bluetooth/ensemble_bluetooth.dart';

void main() {
  test('encodes bluetooth handler strings as script-safe literals', () {
    expect(BluetoothManagerImpl.encodeHandlerInput('hello'), '"hello"');
    expect(BluetoothManagerImpl.encodeHandlerInput('"); ensemble.closeApp(); //'),
        r'"\"); ensemble.closeApp(); //"');
  });

  test('preserves json payloads for bluetooth handlers', () {
    expect(BluetoothManagerImpl.encodeHandlerInput('{"value":1}'), '{"value":1}');
  });
}
