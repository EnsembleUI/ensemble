# Ensemble Device Preview

[![Pub](https://img.shields.io/pub/v/ensemble_device_preview.svg)](https://pub.dev/packages/ensemble_device_preview)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/EnsembleUI/ensemble/blob/main/LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.5+-blue.svg)](https://flutter.dev)

A Flutter package that helps you approximate how your app looks and performs on different devices. Perfect for development and testing, allowing developers to preview their Flutter apps across various screen sizes, orientations, and device types.

Built for the Ensemble UI ecosystem, this package provides comprehensive device simulation capabilities to ensure your Flutter applications look great on all target devices.

## ✨ Features

- **Multi-Device Simulation**: Preview your app on phones, tablets, desktops, and more
- **Orientation Support**: Test both portrait and landscape orientations
- **Theme Switching**: Toggle between light and dark themes
- **Accessibility Testing**: Test with various accessibility settings
- **Responsive Design**: Ensure your UI works across different screen sizes
- **Development Tools**: Built-in toolbar for easy configuration
- **Custom Devices**: Create and save custom device configurations

## 🚀 Quick Start

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ensemble_device_preview: ^1.1.1
```

### Basic Usage

Wrap your app with `DevicePreview`:

```dart
import 'package:ensemble_device_preview/ensemble_device_preview.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true, // Enable device preview
      builder: (context) => MyApp(),
    ),
  );
}
```

### Advanced Configuration

```dart
DevicePreview(
  enabled: true,
  builder: (context) => MyApp(),
  data: DevicePreviewData(
    isToolbarVisible: true,
    isEnabled: true,
    orientation: Orientation.portrait,
    deviceIdentifier: 'iPhone 14',
    locale: 'en-US',
    isFrameVisible: true,
    isDarkMode: false,
    boldText: false,
    isVirtualKeyboardVisible: false,
    disableAnimations: false,
    highContrast: false,
    accessibleNavigation: false,
    invertColors: false,
    textScaleFactor: 1.0,
  ),
)
```

## 🎯 Use Cases

- **Development Testing**: Preview your app on different devices during development
- **Design Validation**: Ensure your UI looks good across various screen sizes
- **QA Testing**: Test responsive behavior without needing physical devices
- **Client Demos**: Show your app on different devices during presentations
- **Cross-Platform Development**: Test how your app looks on different platforms

## 🔧 Configuration Options

### Device Preview Settings

- **Toolbar Position**: Top, bottom, left, or right
- **Theme**: Light or dark theme for the preview interface
- **Background**: Customize the background appearance

### Device Simulation

- **Frame Visibility**: Show or hide device frames
- **Orientation**: Portrait or landscape mode
- **Custom Devices**: Create and save custom device configurations

### Accessibility Testing

- **Text Scaling**: Test with different text sizes
- **High Contrast**: Simulate high contrast mode
- **Bold Text**: Test with bold text enabled
- **Color Inversion**: Test with inverted colors

## 📱 Supported Devices

The package includes a comprehensive collection of device presets:

- **iOS Devices**: iPhone, iPad models
- **Android Devices**: Various phone and tablet sizes
- **Desktop**: Windows, macOS, and Linux screen sizes
- **Web**: Common browser viewport sizes

## 🎨 Customization

### Custom Device Creation

```dart
final customDevice = CustomDeviceInfo(
  name: 'Custom Tablet',
  screenSize: Size(1024, 768),
  pixelDensity: 2.0,
  platform: TargetPlatform.android,
  safeAreas: EdgeInsets.all(20),
);
```

### Theme Customization

```dart
DevicePreview(
  builder: (context) => MyApp(),
  data: DevicePreviewData(
    settings: DevicePreviewSettingsData(
      toolbarPosition: DevicePreviewToolBarPositionData.top,
      toolbarTheme: DevicePreviewToolBarThemeData.light,
      backgroundTheme: DevicePreviewBackgroundThemeData.dark,
    ),
  ),
)
```

## 🧪 Testing

Run the tests to ensure everything works correctly:

```bash
flutter test
```

## 📚 API Reference

### Main Classes

- `DevicePreview`: Main widget for device preview functionality
- `DevicePreviewData`: Configuration data for device preview
- `CustomDeviceInfo`: Custom device configuration
- `DevicePreviewSettingsData`: Settings for the preview interface

### Key Methods

- `DevicePreview.appBuilder()`: Builder function for device preview
- `DevicePreviewData.fromJson()`: Create from JSON data
- `CustomDeviceInfo.create()`: Create custom device

## 🌐 Platform Support

- ✅ **iOS**: Full support
- ✅ **Android**: Full support
- ✅ **Web**: Full support
- ✅ **Windows**: Full support
- ✅ **macOS**: Full support
- ✅ **Linux**: Full support

## 🤝 Contributing

We welcome contributions! Please see our [contributing guidelines](https://github.com/EnsembleUI/ensemble/blob/main/CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original `device_preview` package by [Alois Deniel](https://github.com/aloisdeniel)
- Flutter team for the amazing framework
- Community contributors and users

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/EnsembleUI/ensemble/issues)
- **Documentation**: [pub.dev](https://pub.dev/documentation/ensemble_device_preview)
- **Community**: [Ensemble UI Discord](https://discord.gg/ensembleui)

---

Built with ❤️ by the Ensemble UI team