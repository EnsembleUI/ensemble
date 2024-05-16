library highchart;

export 'src/unsupported.dart'
    if (dart.library.html) 'src/web/high_chart.dart'
    if (dart.library.io) 'src/mobile/high_chart.dart';
