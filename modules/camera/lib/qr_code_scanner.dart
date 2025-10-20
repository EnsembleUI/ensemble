// Backward compatibility re-export
// This file re-exports the QR scanner from the new ensemble_qr_scanner module
// to maintain backward compatibility for apps already using ensemble_camera
//
// Apps using ensemble_camera can continue to import from here without breaking.
// New apps should use ensemble_qr_scanner directly for lighter dependencies.

export 'package:ensemble_qr_scanner/qr_code_scanner.dart';
