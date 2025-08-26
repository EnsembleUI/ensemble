# js_widget

A Flutter package that allows you to use any JavaScript-based widget as a Flutter widget through webview integration. This library is heavily inspired by and re-uses the awesome work that [high_chart](https://github.com/senthilnasa/high_chart) has done. I just made it generic for any JS widget instead of just highchart.

## Features

- 🚀 **Cross-platform support**: Works on both web and mobile platforms
- 🔧 **Generic implementation**: Use any JavaScript widget, not just charts
- 📱 **Webview integration**: Seamless integration with Flutter webview
- 🎨 **Customizable**: Support for custom loaders, scripts, and event listeners
- 📐 **Flexible sizing**: Configurable widget dimensions
- 🔌 **Event handling**: Listen to JavaScript events from your widgets

## Getting started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  js_widget: ^0.0.1
```

### Import

```dart
import 'package:js_widget/js_widget.dart';
```

## Usage

### Basic Example

```dart
JsWidget(
  id: 'my-chart',
  size: const Size(400, 300),
  createHtmlTag: () => 'div',
  scriptToInstantiate: () => 'new Chart(ctx, config)',
  data: '{"labels": ["A", "B", "C"], "datasets": [{"data": [1, 2, 3]}]}',
  scripts: [
    'https://cdn.jsdelivr.net/npm/chart.js',
  ],
)
```

### Advanced Example with Custom Loader and Event Listener

```dart
JsWidget(
  id: 'advanced-chart',
  size: const Size(600, 400),
  createHtmlTag: () => 'canvas',
  scriptToInstantiate: () => '''
    const ctx = document.getElementById('advanced-chart');
    const chart = new Chart(ctx, {
      type: 'line',
      data: $data,
      options: {
        responsive: true,
        interaction: {
          mode: 'index',
          intersect: false,
        },
      }
    });
    
    // Listen for chart events
    chart.canvas.addEventListener('click', function(evt) {
      const points = chart.getElementsAtEventForMode(evt, 'nearest', {intersect: true}, true);
      if (points.length) {
        const firstPoint = points[0];
        const label = chart.data.labels[firstPoint.index];
        const value = chart.data.datasets[firstPoint.datasetIndex].data[firstPoint.index];
        window.flutter_inappwebview.callHandler('chartClick', label, value);
      }
    });
  ''',
  data: jsonEncode(chartData),
  scripts: [
    'https://cdn.jsdelivr.net/npm/chart.js',
  ],
  loader: const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Loading chart...'),
      ],
    ),
  ),
  listener: (String message) {
    print('Received message from JS: $message');
  },
)
```

## API Reference

### JsWidget

The main widget class that renders JavaScript widgets.

#### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | `String` | Yes | Unique identifier for the widget |
| `size` | `Size` | Yes | Dimensions of the widget (width × height) |
| `createHtmlTag` | `Function` | Yes | Function that returns the HTML tag to create |
| `scriptToInstantiate` | `Function` | Yes | Function that returns the JavaScript code to instantiate the widget |
| `data` | `String` | Yes | Data to pass to the JavaScript widget |
| `loader` | `Widget` | No | Widget to show while loading (defaults to `CircularProgressIndicator`) |
| `scripts` | `List<String>` | No | List of JavaScript files to load |
| `listener` | `Function(String)?` | No | Callback function for JavaScript messages |
| `preCreateScript` | `Function?` | No | Function that returns JavaScript code to run before widget creation |

#### Methods

- `evalScript(String script)`: Execute JavaScript code in the webview context

## Platform Support

- ✅ **Web**: Full support using `dart:html`
- ✅ **Android**: Full support using `webview_flutter`
- ✅ **iOS**: Full support using `webview_flutter`
- ❌ **Desktop**: Limited support (shows unsupported platform message)

## Examples

Check out the `example/` directory for complete working examples:

- **Chart.js Integration**: See how to integrate Chart.js for beautiful charts
- **Custom Widgets**: Learn how to create custom JavaScript widgets

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [high_chart](https://github.com/senthilnasa/high_chart)
- Built with Flutter and Dart
- Uses [webview_flutter](https://pub.dev/packages/webview_flutter) for mobile support

## Issues and Feedback

Please file issues and feature requests on the [GitHub repository](https://github.com/EnsembleUI/ensemble/issues).
