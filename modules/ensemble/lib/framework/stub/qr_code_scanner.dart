import 'package:ensemble/widget/stub_widgets.dart';

abstract class EnsembleQRCodeScanner {
  static const type = 'QRCodeScanner';
}

class EnsembleQRCodeScannerStub extends StubWidget
    implements EnsembleQRCodeScanner {
  const EnsembleQRCodeScannerStub({super.key})
      : super(moduleName: 'ensemble_qr_scanner');
}
