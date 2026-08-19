import 'package:ensemble/widget/fintech/finicity_connect_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildFinicityConnectInstantiateScript', () {
    test('JSON-encodes connect URI for safe embedding', () {
      final script = buildFinicityConnectInstantiateScript(
        connectUri: 'https://connect2.finicity.com?token=abc',
        widgetId: 'finicityConnect',
        left: 0,
        top: 10,
        position: 'absolute',
      );
      expect(
        script,
        contains('window.finicityConnect.launch("https://connect2.finicity.com?token=abc"'),
      );
    });

    test('neutralizes JavaScript breakout in connect URI', () {
      const malicious = '"); alert(1); //';
      final script = buildFinicityConnectInstantiateScript(
        connectUri: malicious,
        widgetId: 'finicityConnect',
        left: 0,
        top: 0,
        position: 'absolute',
      );
      expect(script, contains('window.finicityConnect.launch('));
      expect(script, isNot(contains('launch(""); alert(1);')));
      expect(script, contains(r'\"); alert(1); //'));
    });

    test('JSON-encodes overlay and position values', () {
      final script = buildFinicityConnectInstantiateScript(
        connectUri: 'https://example.com',
        widgetId: 'widget-1',
        left: 4,
        top: 8,
        position: "absolute'; alert(1); '",
        overlay: "rgba(0,0,0,0.5)",
      );
      expect(script, contains('overlay: "rgba(0,0,0,0.5)",'));
      expect(script, contains(r"position = \"absolute'; alert(1); '\""));
      expect(script, isNot(contains("position = 'absolute'; alert(1);")));
    });
  });
}
