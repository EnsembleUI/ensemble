[![Pub](https://img.shields.io/pub/v/ensemble_otp.svg)](https://pub.dartlang.org/packages/ensemble_otp)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

# Ensemble OTP

A beautiful and highly customizable Flutter widget for OTP and PIN code input fields. Features include beautiful animations, custom styling, SMS autofill, custom keyboards, and extensive customization options. Perfect for authentication flows, verification screens, and any application requiring secure PIN or OTP input.

## ✨ Features

- **Beautiful Animations**: Smooth and engaging animations for better user experience
- **Highly Customizable**: Extensive styling options for colors, borders, sizes, and more
- **SMS Autofill**: Automatic OTP detection from SMS messages (Android & iOS)
- **Custom Keyboards**: Built-in custom keyboard or use your own custom keyboard
- **Multiple Input Types**: Text, password, or custom character masking
- **Accessibility**: Full accessibility support for better user experience
- **Cross-Platform**: Works on Android, iOS, and Web
- **Lightweight**: Minimal dependencies and optimized performance

## 🚀 Quick Start

### Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  ensemble_otp: ^1.0.2
```

Then run:
```bash
flutter pub get
```

### Basic Usage

```dart
import 'package:ensemble_otp/ensemble_otp.dart';

class OTPVerificationScreen extends StatefulWidget {
  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpPinFieldController = GlobalKey<OtpPinFieldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify OTP')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            OtpPinField(
              key: _otpPinFieldController,
              fieldCount: 6,
              onSubmit: (text) {
                print('Entered OTP: $text');
                // Handle OTP verification
              },
              onChange: (text) {
                print('Current OTP: $text');
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _otpPinFieldController.currentState?.clear();
              },
              child: Text('Clear OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 🔧 Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fieldCount` | `int` | `4` | Total length of PIN number & number of PIN boxes |
| `highlightBorder` | `bool` | `true` | Highlight the focused PIN box |
| `activeFieldBorderColor` | `Color` | `Colors.black` | Color of the focused PIN box |
| `activeFieldBackgroundColor` | `Color` | `Colors.transparent` | Background color of the focused PIN box |
| `defaultFieldBorderColor` | `Color` | `Colors.black45` | Color of the unfocused PIN box |
| `defaultFieldBackgroundColor` | `Color` | `Colors.transparent` | Background color of the unfocused PIN box |
| `fieldPadding` | `double` | `20.0` | Padding for PIN box |
| `fieldBorderRadius` | `double` | `2.0` | Border radius for PIN box |
| `fieldBorderWidth` | `double` | `2.0` | Border width for PIN box |
| `textStyle` | `TextStyle` | `TextStyle(fontSize: 18.0, color: Colors.black)` | TextStyle for styling PIN characters |
| `otpPinFieldInputType` | `OtpPinFieldInputType` | `OtpPinFieldInputType.none` | Input type (none, password, custom) |
| `otpPinInputCustom` | `String` | `"*"` | Special character to mask the PIN code |
| `onSubmit` | `void Function(String)` | - | Callback when max length is reached |
| `onChange` | `void Function(String)` | - | Callback when PIN changes |
| `otpPinFieldStyle` | `OtpPinFieldStyle` | `OtpPinFieldStyle()` | Customization for individual PIN boxes |
| `fieldHeight` | `double` | `45.0` | Height of PIN boxes |
| `fieldWidth` | `double` | `70.0` | Width of PIN boxes |
| `otpPinFieldDecoration` | `OtpPinFieldDecoration` | `OtpPinFieldDecoration.underlinedPinBoxDecoration` | Predefined decoration styles |
| `keyboardType` | `TextInputType` | `TextInputType.number` | Type of input keyboard |
| `autofocus` | `bool` | `false` | Autofocus on view entered |
| `cursorColor` | `Color` | `Color.black` | Color of the cursor |
| `cursorWidth` | `double` | `2` | Width of the cursor |
| `showCursor` | `bool` | `true` | Show cursor in OTP PIN fields |
| `mainAxisAlignment` | `MainAxisAlignment` | `MainAxisAlignment.center` | Spacing in OTP PIN fields |
| `showCustomKeyboard` | `bool` | `false` | Show custom keyboard instead of default |
| `customKeyboard` | `Widget` | - | Custom keyboard widget |
| `showDefaultKeyboard` | `bool` | `true` | Show default OS keyboard |
| `autoFillEnable` | `bool` | `false` | Enable SMS autofill functionality |
| `smsRegex` | `String` | `'\\d{0,4}'` | Regex pattern for OTP detection |
| `phoneNumbersHint` | `bool` | `false` | Show phone number hint for autofill |
| `textInputAction` | `TextInputAction` | `TextInputAction.done` | Keyboard action button |
| `filledFieldBackgroundColor` | `Color` | `Colors.transparent` | Background color of filled fields |
| `filledFieldBorderColor` | `Color` | `Colors.transparent` | Border color of filled fields |

## 🎨 Advanced Customization

### Custom Styling

```dart
OtpPinField(
  fieldCount: 6,
  otpPinFieldStyle: OtpPinFieldStyle(
    defaultFieldBorderColor: Colors.grey,
    activeFieldBorderColor: Colors.blue,
    filledFieldBackgroundColor: Colors.blue.withValues(alpha: 0.1),
    fieldBorderRadius: 8.0,
    fieldBorderWidth: 2.0,
  ),
  textStyle: TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.bold,
    color: Colors.blue,
  ),
  onSubmit: (text) => print('OTP: $text'),
)
```

### Custom Keyboard

```dart
OtpPinField(
  fieldCount: 4,
  showCustomKeyboard: true,
  customKeyboard: CustomNumericKeyboard(
    onKeyPressed: (value) {
      // Handle key press
    },
    onBackspace: () {
      // Handle backspace
    },
    onSubmit: () {
      // Handle submit
    },
  ),
  onSubmit: (text) => print('OTP: $text'),
)
```

### SMS Autofill

```dart
OtpPinField(
  fieldCount: 6,
  autoFillEnable: true,
  smsRegex: '\\d{6}', // 6-digit OTP
  phoneNumbersHint: true, // Show phone number hint
  onSubmit: (text) => print('OTP: $text'),
)
```

## 📱 Platform Support

- ✅ **Android**: Full support with SMS autofill
- ✅ **iOS**: Full support with native SMS autofill
- ✅ **Web**: Full support with web-specific optimizations

## 🔍 Examples

Check out the `example/` directory for complete working examples:

- Basic OTP input
- Custom styling
- Custom keyboard implementation
- SMS autofill integration
- Advanced customization

## 🤝 Contributing

We welcome contributions! Please feel free to:

- Report bugs and issues
- Suggest new features
- Submit pull requests
- Improve documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Created by Shivam Mishra [@shivbo96](https://github.com/shivbo96)
- Part of the Ensemble UI ecosystem

---

**Built with ❤️ for the Flutter community** 
