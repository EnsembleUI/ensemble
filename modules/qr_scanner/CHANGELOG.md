## 1.2.47

 - **REFACTOR**(qr_scanner): improve scan window handling and layout for QR code scanner. ([a54f86b0](https://github.com/ensembleUI/ensemble/commit/a54f86b03c2d8255fad5dfb50c35d452be1a4e64))
 - **FIX**(qr_scanner): upgrade mobile_scanner dependency in qr_scanner. ([ec22c726](https://github.com/ensembleUI/ensemble/commit/ec22c726dc6b1ec5a9c687d7dfeef9aa8f7c882c))
 - **DOCS**: update package and module READMEs. ([2f7e2dec](https://github.com/ensembleUI/ensemble/commit/2f7e2deccf3110badc169d78c22afb64870897f6))

# Changelog

All notable changes to the ensemble_qr_scanner module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-10-20

### Added
- Initial release of standalone QR scanner module
- Extracted from ensemble_camera module for lighter dependencies
- QR Code and Barcode scanning support
- Multiple barcode format support (Code 128, Code 39, Code 93, EAN, UPC, etc.)
- Customizable scan overlay UI
- Camera controls (flash, flip, pause/resume)
- Event callbacks (onReceived, onInitialized, onPermissionSet)
- Backward compatibility maintained via re-export in ensemble_camera

### Dependencies
- mobile_scanner: ^6.0.11
- ensemble: core framework
- flutter: SDK

### Migration
- New apps can use `ensemble_qr_scanner` directly for lightweight QR scanning
- Existing apps using `ensemble_camera` continue to work without changes
- No breaking changes
