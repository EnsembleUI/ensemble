[![Pub](https://img.shields.io/pub/v/ensemble_icons.svg)](https://pub.dartlang.org/packages/ensemble_icons)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

# Ensemble Icons

A comprehensive Flutter icon package providing access to multiple icon libraries including Material Design, Remix Icons, and Font Awesome. Perfect for Flutter applications that need consistent, high-quality icons across different design systems.

## ✨ Features

- **Multiple Icon Libraries**: Material Design, Remix Icons, and Font Awesome
- **Easy Integration**: Simple API for using icons in your Flutter apps
- **Customizable**: Support for custom sizing, colors, and styling
- **High Quality**: Vector-based icons that scale perfectly
- **Ensemble UI Ready**: Designed to work seamlessly with Ensemble UI framework

## 🚀 Quick Start

### Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  ensemble_icons: ^1.0.1
```

Then run:
```bash
flutter pub get
```

### Basic Usage

```dart
import 'package:ensemble_icons/ensemble_icons.dart';

// Use Material Design icons
Icon(
  icon: MaterialIcons.home,
  size: 24.0,
  color: Colors.blue,
)

// Use Remix Icons
Icon(
  icon: RemixIcons.home,
  size: 24.0,
  color: Colors.green,
)

// Use Font Awesome icons
Icon(
  icon: FontAwesomeIcons.home,
  size: 24.0,
  color: Colors.orange,
)
```

## 🎨 Icon Libraries

### Material Design Icons
- **Version**: Latest Flutter SDK version
- **Features**: Google's Material Design icon set
- **Usage**: `MaterialIcons.iconName`

### Remix Icons
- **Version**: v4.2.0 (2024-03-13)
- **Features**: Open-source icon library with 2,000+ icons
- **Usage**: `RemixIcons.iconName`

### Font Awesome Icons
- **Version**: v6.5.1 (2024-03-11)
- **Features**: Professional icon toolkit with 1,600+ free icons
- **Usage**: `FontAwesomeIcons.iconName`

## 🔧 Advanced Usage

### Custom Icon Widget

```dart
class CustomIcon extends StatelessWidget {
  final String iconName;
  final String library;
  final double size;
  final Color? color;

  const CustomIcon({
    Key? key,
    required this.iconName,
    this.library = 'default',
    this.size = 24.0,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    
    switch (library) {
      case 'remix':
        iconData = RemixIcons.values.firstWhere(
          (icon) => icon.name == iconName,
          orElse: () => RemixIcons.question,
        );
        break;
      case 'fontAwesome':
        iconData = FontAwesomeIcons.values.firstWhere(
          (icon) => icon.name == iconName,
          orElse: () => FontAwesomeIcons.question,
        );
        break;
      default:
        iconData = MaterialIcons.values.firstWhere(
          (icon) => icon.name == iconName,
          orElse: () => MaterialIcons.help,
        );
    }

    return Icon(
      iconData,
      size: size,
      color: color,
    );
  }
}
```

### Ensemble UI Integration

```yaml
- Icon:
    name: "home"
    library: "remix"  # default / remix / fontAwesome
    size: "24"
    color: "#007AFF"
```

## 📚 API Reference

### Icon Classes

| Class | Description | Icons Available |
|-------|-------------|-----------------|
| `MaterialIcons` | Material Design icons | 1,000+ |
| `RemixIcons` | Remix icon library | 2,000+ |
| `FontAwesomeIcons` | Font Awesome icons | 1,600+ |

### Common Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `size` | `double` | `24.0` | Icon size in logical pixels |
| `color` | `Color?` | `null` | Icon color (inherits from theme if null) |
| `semanticLabel` | `String?` | `null` | Accessibility label for screen readers |

## 🔄 Updating Icon Libraries

### Remix Icons
Follow the documentation in the [update folder](/update/) to update to the latest version.

### Font Awesome
Update the `font_awesome_flutter` dependency in `pubspec.yaml` to get the latest icons.

### Material Icons
Material icons are automatically updated with Flutter SDK updates.

## 📱 Platform Support

- ✅ **Android**: Full support
- ✅ **iOS**: Full support
- ✅ **Web**: Full support
- ✅ **Desktop**: Full support

## 🤝 Contributing

We welcome contributions! Please feel free to:
- Report bugs and issues
- Suggest new features
- Submit pull requests
- Improve documentation

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Part of the Ensemble UI ecosystem
- Built for the Flutter community

---

**Built with ❤️ for the Flutter community**
