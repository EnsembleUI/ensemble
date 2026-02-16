import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

/// Models
class Device {
  final String type;
  Offset position;

  Device({required this.type, required this.position});

  bool get isModem => type == 'modem';
}

class GridCell {
  final int row;
  final int col;
  int rssi = -100;
  Color? color;
  bool scanned = false;

  GridCell({required this.row, required this.col});
}

class SignalResult {
  final int dBm;
  final Color color;

  SignalResult(this.dBm, this.color);
}

/// Separate style classes
class DeviceStyles {
  final double markerSize;
  final double iconSize;
  final double borderWidth;
  final Color borderColor;
  final Color modemColor;
  final Color modemIconColor;
  final Color routerColor;
  final Color routerIconColor;

  const DeviceStyles({
    this.markerSize = 36.0,
    this.iconSize = 22.0,
    this.borderWidth = 2.8,
    this.borderColor = Colors.white,
    this.modemColor = Colors.red,
    this.modemIconColor = Colors.white,
    this.routerColor = Colors.blue,
    this.routerIconColor = Colors.white,
  });

  Color getDeviceColor(Device device) =>
      device.isModem ? modemColor : routerColor;

  Color getDeviceIconColor(Device device) =>
      device.isModem ? modemIconColor : routerIconColor;
}

class ScanPointStyles {
  final double dotSizeFactor;
  final Color color;
  final Color borderColor;
  final double borderWidth;

  const ScanPointStyles({
    this.dotSizeFactor = 0.4,
    this.color = Colors.blueAccent,
    this.borderColor = const Color(0xB3FFFFFF),
    this.borderWidth = 1.8,
  });
}

class LocationPinStyles {
  final double size;
  final Color color;

  const LocationPinStyles({
    this.size = 44.0,
    this.color = Colors.red,
  });
}

class GridStyles {
  final double lineWidth;
  final int alpha;
  final Color lineColor;

  const GridStyles({
    this.lineWidth = 0.6,
    this.alpha = 60,
    this.lineColor = Colors.black,
  });
}

class HeatmapStyles {
  final int fillAlpha;

  const HeatmapStyles({
    this.fillAlpha = 123,
  });
}

class PathStyles {
  final Color color;
  final double width;

  const PathStyles({
    this.color = const Color(0xFF1976D2),
    this.width = 2.8,
  });
}

class SignalStyles {
  final Color excellentColor;
  final Color veryGoodColor;
  final Color goodColor;
  final Color fairColor;
  final Color poorColor;
  final Color badColor;

  const SignalStyles({
    this.excellentColor = const Color(0xFF388E3C),
    this.veryGoodColor = const Color(0xFF66BB6A),
    this.goodColor = const Color(0xFFAFB42B),
    this.fairColor = const Color(0xFFF57C00),
    this.poorColor = const Color(0xFFE64A19),
    this.badColor = const Color(0xFFC62828),
  });

  Color getSignalColor(int dBm) {
    if (dBm >= -50) return excellentColor;
    if (dBm >= -60) return veryGoodColor;
    if (dBm >= -70) return goodColor;
    if (dBm >= -80) return fairColor;
    if (dBm >= -90) return poorColor;
    return badColor;
  }
}

class ButtonStyles {
  final Color startScanColor;
  final Color addCheckpointColor;

  const ButtonStyles({
    this.startScanColor = const Color(0xFF388E3C),
    this.addCheckpointColor = const Color(0xFF1976D2),
  });
}

/// Reusable WiFi Heatmap Widget
class WiFiHeatmapWidget extends StatefulWidget {
  final Future<SignalResult> Function()? getSignalStrength;
  final String floorPlan;
  final int gridSize;
  final Function(String message)? onShowMessage;

  // Separate style classes
  final DeviceStyles deviceStyles;
  final ScanPointStyles scanPointStyles;
  final LocationPinStyles locationPinStyles;
  final GridStyles gridStyles;
  final HeatmapStyles heatmapStyles;
  final PathStyles pathStyles;
  final SignalStyles signalStyles;
  final ButtonStyles buttonStyles;

  // Icons moved out of styles
  final Icon? modemIcon;
  final Icon? routerIcon;
  final Icon? locationPinIcon;

  // Error state customization
  final String errorTitle;
  final String errorMessage;
  final IconData errorIcon;
  final Color errorIconColor;
  final double errorIconSize;
  final TextStyle? errorTitleStyle;
  final TextStyle? errorMessageStyle;

  const WiFiHeatmapWidget({
    super.key,
    this.getSignalStrength,
    required this.floorPlan,
    this.gridSize = 12,
    this.onShowMessage,
    this.deviceStyles = const DeviceStyles(),
    this.scanPointStyles = const ScanPointStyles(),
    this.locationPinStyles = const LocationPinStyles(),
    this.gridStyles = const GridStyles(),
    this.heatmapStyles = const HeatmapStyles(),
    this.pathStyles = const PathStyles(),
    this.signalStyles = const SignalStyles(),
    this.buttonStyles = const ButtonStyles(),
    this.modemIcon,
    this.routerIcon,
    this.locationPinIcon,
    this.errorTitle = 'Invalid or missing floor plan',
    this.errorMessage = 'Please provide a valid image path',
    this.errorIcon = Icons.broken_image,
    this.errorIconColor = Colors.redAccent,
    this.errorIconSize = 80.0,
    this.errorTitleStyle,
    this.errorMessageStyle,
  });

  @override
  State<WiFiHeatmapWidget> createState() => _WiFiHeatmapWidgetState();
}

class _WiFiHeatmapWidgetState extends State<WiFiHeatmapWidget> {
  File? _floorPlan;
  Device? _modem;
  final List<Device> _routers = [];

  Size? _originalImageSize;
  Rect? _displayedImageRect;

  String _mode = 'setup';

  List<List<GridCell>> _grid = [];
  List<double> _rowHeights = [];
  List<double> _colWidths = [];

  Offset? _markerGridPos;
  final List<Offset> _scannedGridPositions = [];

  Timer? _signalTimer;
  List<int> _currentSegmentDbms = [];

  final _stackKey = GlobalKey();

  bool _imageLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _floorPlan = File(widget.floorPlan);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImageSize();
    });
  }

  @override
  void dispose() {
    _signalTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    if (_floorPlan == null) return;

    try {
      final completer = Completer<Size>();
      final provider = FileImage(_floorPlan!);

      provider.resolve(const ImageConfiguration()).addListener(
            ImageStreamListener(
              (info, _) {
                completer.complete(Size(
                    info.image.width.toDouble(), info.image.height.toDouble()));
              },
              onError: (exception, stackTrace) {
                print('Image load error: $exception');
                if (mounted) {
                  setState(() => _imageLoadFailed = true);
                  widget.onShowMessage?.call('Failed to load floor plan image');
                }
                completer.completeError(exception, stackTrace);
              },
            ),
          );

      _originalImageSize = await completer.future;
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    } catch (e) {
      print('Image loading failed: $e');
      if (mounted) {
        setState(() => _imageLoadFailed = true);
        widget.onShowMessage?.call('Invalid or inaccessible floor plan file');
      }
    }
  }

  void _updateDisplayedRect(BoxConstraints constraints) {
    if (_originalImageSize == null || !mounted) return;

    final availW = constraints.maxWidth;
    final availH = constraints.maxHeight;

    if (availW <= 0 || availH <= 0) return;

    final newRect = Rect.fromLTWH(0, 0, availW, availH);

    if (_displayedImageRect == null ||
        (_displayedImageRect!.left - newRect.left).abs() > 1 ||
        (_displayedImageRect!.top - newRect.top).abs() > 1 ||
        (_displayedImageRect!.width - newRect.width).abs() > 1 ||
        (_displayedImageRect!.height - newRect.height).abs() > 1) {
      _displayedImageRect = newRect;

      if (_mode == 'scanning' && _grid.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _createGrid());
          }
        });
      }
    }
  }

  Icon _getDeviceIcon(Device device) {
    if (device.isModem) {
      return widget.modemIcon ??
          Icon(Icons.wifi,
              color: widget.deviceStyles.modemIconColor,
              size: widget.deviceStyles.iconSize);
    } else {
      return widget.routerIcon ??
          Icon(Icons.router,
              color: widget.deviceStyles.routerIconColor,
              size: widget.deviceStyles.iconSize);
    }
  }

  Icon _getLocationPinIcon() {
    return widget.locationPinIcon ??
        Icon(
          Icons.location_on,
          color: widget.locationPinStyles.color,
          size: widget.locationPinStyles.size,
        );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.errorIcon,
            size: widget.errorIconSize,
            color: widget.errorIconColor,
          ),
          const SizedBox(height: 16),
          Text(
            widget.errorTitle,
            style: widget.errorTitleStyle ??
                const TextStyle(
                  fontSize: 20,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.errorMessage,
            style: widget.errorMessageStyle ??
                const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSetupModeContent() {
    if (_imageLoadFailed || _displayedImageRect == null) {
      return _buildErrorState();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fromRect(
          rect: _displayedImageRect!,
          child: Image.file(
            _floorPlan!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorState();
            },
          ),
        ),
        if (_modem != null)
          DraggableDevice(
            device: _modem!,
            imageRect: _displayedImageRect!,
            deviceStyles: widget.deviceStyles,
            getIcon: _getDeviceIcon,
            onPositionChanged: (newPos) =>
                setState(() => _modem!.position = newPos),
          ),
        ..._routers.map(
          (r) => DraggableDevice(
            device: r,
            imageRect: _displayedImageRect!,
            deviceStyles: widget.deviceStyles,
            getIcon: _getDeviceIcon,
            onPositionChanged: (newPos) => setState(() => r.position = newPos),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningModeContent() {
    if (_imageLoadFailed || _displayedImageRect == null) {
      return _buildErrorState();
    }

    return ClipRect(
      child: Stack(
        key: _stackKey,
        children: [
          Positioned.fromRect(
            rect: _displayedImageRect!,
            child: Image.file(
              _floorPlan!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorState();
              },
            ),
          ),
          if (_grid.isNotEmpty) ...[
            Positioned.fromRect(
              rect: _displayedImageRect!,
              child: VariableGridPainterWidget(
                grid: _grid,
                colWidths: _colWidths,
                rowHeights: _rowHeights,
                gridStyles: widget.gridStyles,
                heatmapStyles: widget.heatmapStyles,
              ),
            ),
            if (_scannedGridPositions.length >= 2)
              Positioned.fromRect(
                rect: _displayedImageRect!,
                child: CustomPaint(
                  painter: PathConnectionPainter(
                    gridPoints: _scannedGridPositions,
                    colWidths: _colWidths,
                    rowHeights: _rowHeights,
                    pathStyles: widget.pathStyles,
                  ),
                ),
              ),
            if (_scannedGridPositions.isNotEmpty && _markerGridPos != null)
              Positioned.fromRect(
                rect: _displayedImageRect!,
                child: CustomPaint(
                  painter: PathConnectionPainter(
                    gridPoints: [_scannedGridPositions.last, _markerGridPos!],
                    colWidths: _colWidths,
                    rowHeights: _rowHeights,
                    pathStyles: widget.pathStyles,
                    isDotted: true,
                  ),
                ),
              ),
            ..._scannedGridPositions.map(
              (pos) => ScanPointDot(
                gridPos: pos,
                colWidths: _colWidths,
                rowHeights: _rowHeights,
                imageRect: _displayedImageRect!,
                scanPointStyles: widget.scanPointStyles,
              ),
            ),
            if (_modem != null)
              FixedDeviceMarker(
                  device: _modem!,
                  imageRect: _displayedImageRect!,
                  deviceStyles: widget.deviceStyles,
                  getIcon: _getDeviceIcon),
            ..._routers.map((router) => FixedDeviceMarker(
                device: router,
                imageRect: _displayedImageRect!,
                deviceStyles: widget.deviceStyles,
                getIcon: _getDeviceIcon)),
            if (_markerGridPos != null)
              MarkerPin(
                gridPos: _markerGridPos!,
                colWidths: _colWidths,
                rowHeights: _rowHeights,
                imageRect: _displayedImageRect!,
                locationPinStyles: widget.locationPinStyles,
                getIcon: _getLocationPinIcon,
              ),
          ],
          if (_displayedImageRect != null && _grid.isNotEmpty)
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (d) => _updateMarkerFromGlobalPos(d.globalPosition),
                onPanStart: (d) => _updateMarkerFromGlobalPos(d.globalPosition),
                onPanUpdate: (d) =>
                    _updateMarkerFromGlobalPos(d.globalPosition),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_floorPlan == null || widget.floorPlan.isEmpty || _imageLoadFailed) {
      return _buildErrorState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_originalImageSize == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final double availableWidth = constraints.maxWidth;
        final double imageAspectRatio =
            _originalImageSize!.width / _originalImageSize!.height;

        final double imageDisplayWidth = availableWidth;
        final double imageDisplayHeight = imageDisplayWidth / imageAspectRatio;

        const double buttonAreaHeight = 76.0;

        final double totalHeight =
            imageDisplayHeight + (_mode == 'scanning' ? buttonAreaHeight : 0);

        _updateDisplayedRect(BoxConstraints(
          maxWidth: imageDisplayWidth,
          maxHeight: imageDisplayHeight,
        ));

        return SizedBox(
          height: totalHeight,
          child: _displayedImageRect == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    SizedBox(
                      width: imageDisplayWidth,
                      height: imageDisplayHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _mode == 'setup'
                              ? _buildSetupModeContent()
                              : _buildScanningModeContent(),
                          if (!_imageLoadFailed && _mode == 'setup')
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: _buildFloatingActions(),
                            ),
                        ],
                      ),
                    ),
                    if (_mode == 'scanning')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _grid.isNotEmpty
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.pin_drop),
                                label: const Text('Add Checkpoint'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  backgroundColor:
                                      widget.buttonStyles.addCheckpointColor,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _addCheckpoint,
                              )
                            : const SizedBox(height: 52),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'modem',
          backgroundColor: widget.deviceStyles.modemColor,
          onPressed: _addModem,
          child: widget.modemIcon ??
              Icon(
                Icons.wifi,
                color: widget.deviceStyles.modemIconColor,
                size: widget.deviceStyles.iconSize,
              ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'router',
          backgroundColor: widget.deviceStyles.routerColor,
          onPressed: _addRouter,
          child: widget.routerIcon ??
              Icon(
                Icons.router,
                color: widget.deviceStyles.routerIconColor,
                size: widget.deviceStyles.iconSize,
              ),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'start',
          backgroundColor: widget.buttonStyles.startScanColor,
          onPressed: _startScanning,
          child: const Icon(Icons.navigate_next_outlined, color: Colors.white),
        ),
      ],
    );
  }

  void _createGrid() {
    if (_displayedImageRect == null) return;

    final w = _displayedImageRect!.width;
    final h = _displayedImageRect!.height;

    final n = widget.gridSize.clamp(4, 32);

    _colWidths = List.generate(n, (_) => w / n);
    _rowHeights = List.generate(n, (_) => h / n);

    _colWidths[n - 1] += w - _colWidths.fold(0.0, (a, b) => a + b);
    _rowHeights[n - 1] += h - _rowHeights.fold(0.0, (a, b) => a + b);

    _grid = List.generate(
      n,
      (r) => List.generate(n, (c) => GridCell(row: r, col: c)),
    );

    _markerGridPos = Offset((n ~/ 2).toDouble(), (n ~/ 2).toDouble());
  }

  void _updateMarkerFromGlobalPos(Offset global) {
    if (_displayedImageRect == null || _grid.isEmpty) return;

    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(global);
    final relX = (local.dx - _displayedImageRect!.left).clamp(
      0.0,
      _displayedImageRect!.width,
    );
    final relY = (local.dy - _displayedImageRect!.top).clamp(
      0.0,
      _displayedImageRect!.height,
    );

    int col = 0;
    double sumX = 0;
    for (int i = 0; i < _colWidths.length; i++) {
      sumX += _colWidths[i];
      if (relX <= sumX) {
        col = i;
        break;
      }
    }

    int row = 0;
    double sumY = 0;
    for (int i = 0; i < _rowHeights.length; i++) {
      sumY += _rowHeights[i];
      if (relY <= sumY) {
        row = i;
        break;
      }
    }

    setState(() => _markerGridPos = Offset(row.toDouble(), col.toDouble()));
  }

  Future<void> _addCheckpoint() async {
    if (_markerGridPos == null) return;

    final r = _markerGridPos!.dx.toInt();
    final c = _markerGridPos!.dy.toInt();

    if (r < 0 || r >= _grid.length || c < 0 || c >= _grid[r].length) return;

    if (_scannedGridPositions.isNotEmpty &&
        _scannedGridPositions.last == Offset(r.toDouble(), c.toDouble())) {
      return;
    }

    SignalResult? result;

    if (widget.getSignalStrength != null) {
      try {
        result = await widget.getSignalStrength!();
      } catch (e) {
        if (mounted) {
          widget.onShowMessage?.call('Error getting signal: $e');
        }
        return;
      }
    } else {
      result = _getRandomSignal();
    }

    if (!mounted) return;

    final newPos = Offset(r.toDouble(), c.toDouble());

    setState(() {
      final cell = _grid[r][c];
      cell.rssi = result!.dBm;
      cell.color = result.color;
      cell.scanned = true;

      _scannedGridPositions.add(newPos);

      if (_scannedGridPositions.length == 1) {
        _currentSegmentDbms = [result.dBm];
        _startSignalTimer();
      } else {
        _currentSegmentDbms.add(result.dBm);

        final prevPos = _scannedGridPositions[_scannedGridPositions.length - 2];
        _processSegment(prevPos, newPos, _currentSegmentDbms);

        _currentSegmentDbms = [result.dBm];
      }
    });
  }

  void _startSignalTimer() {
    _signalTimer?.cancel();
    _signalTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      SignalResult result;
      if (widget.getSignalStrength != null) {
        try {
          result = await widget.getSignalStrength!();
        } catch (e) {
          return;
        }
      } else {
        result = _getRandomSignal();
      }

      _currentSegmentDbms.add(result.dBm);
    });
  }

  void _processSegment(Offset start, Offset end, List<int> dbms) {
    final startR = start.dx.toInt();
    final startC = start.dy.toInt();
    final endR = end.dx.toInt();
    final endC = end.dy.toInt();

    final lineCells = _getLineCells(startR, startC, endR, endC);
    if (lineCells.length < 2) return;

    final numCells = lineCells.length;
    List<int> cellDbms = List.filled(numCells, dbms.first);

    cellDbms[0] = dbms[0];
    cellDbms[numCells - 1] = dbms.last;

    final middleSamplesCount = dbms.length - 2;
    final middleCellsCount = numCells - 2;

    if (middleCellsCount > 0) {
      if (middleSamplesCount > 0) {
        for (int j = 1; j < numCells - 1; j++) {
          final startS = ((j - 1) * middleSamplesCount) ~/ middleCellsCount;
          var endS = (j * middleSamplesCount) ~/ middleCellsCount;
          if (endS <= startS) endS = startS + 1;
          endS = min(endS, middleSamplesCount);

          int sum = 0;
          int count = 0;
          for (int s = startS; s < endS; s++) {
            sum += dbms[1 + s];
            count++;
          }
          if (count > 0) {
            cellDbms[j] = sum ~/ count;
          }
        }
      } else {
        final avg = (dbms[0] + dbms.last) ~/ 2;
        for (int j = 1; j < numCells - 1; j++) {
          cellDbms[j] = avg;
        }
      }
    }

    for (int i = 0; i < numCells; i++) {
      final gpos = lineCells[i];
      final rr = gpos.dx.toInt();
      final cc = gpos.dy.toInt();
      if (rr >= 0 && rr < _grid.length && cc >= 0 && cc < _grid[rr].length) {
        final cell = _grid[rr][cc];
        final d = cellDbms[i];
        cell.rssi = d;
        cell.color = widget.signalStyles.getSignalColor(d);
        cell.scanned = true;
      }
    }
  }

  List<Offset> _getLineCells(int r0, int c0, int r1, int c1) {
    final cells = <Offset>[];
    final dr = (r1 - r0).abs();
    final dc = (c1 - c0).abs();
    final sr = r0 < r1 ? 1 : -1;
    final sc = c0 < c1 ? 1 : -1;
    int err = dr - dc;
    int r = r0;
    int c = c0;

    while (true) {
      cells.add(Offset(r.toDouble(), c.toDouble()));
      if (r == r1 && c == c1) break;

      final e2 = 2 * err;
      if (e2 > -dc) {
        err -= dc;
        r += sr;
      }
      if (e2 < dr) {
        err += dr;
        c += sc;
      }
    }
    return cells;
  }

  SignalResult _getRandomSignal() {
    final possibleValues = [
      -48,
      -52,
      -55,
      -58,
      -62,
      -65,
      -68,
      -72,
      -75,
      -78,
      -82,
      -86,
      -92,
      -97,
    ];

    final random = Random();
    final dBm = possibleValues[random.nextInt(possibleValues.length)];
    return SignalResult(dBm, widget.signalStyles.getSignalColor(dBm));
  }

  void _addModem() {
    if (_displayedImageRect == null || _modem != null) return;

    final center = Offset(
      (_displayedImageRect!.width - widget.deviceStyles.markerSize) / 2,
      (_displayedImageRect!.height - widget.deviceStyles.markerSize) / 2,
    );

    setState(() => _modem = Device(type: 'modem', position: center));
  }

  void _addRouter() {
    if (_displayedImageRect == null) return;

    final center = Offset(
      (_displayedImageRect!.width - widget.deviceStyles.markerSize) / 2,
      (_displayedImageRect!.height - widget.deviceStyles.markerSize) / 2,
    );
    setState(() => _routers.add(Device(type: 'router', position: center)));
  }

  void _startScanning() {
    if (_modem == null) {
      widget.onShowMessage?.call('Please place the modem first');
      return;
    }

    setState(() {
      _mode = 'scanning';
      _grid.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _displayedImageRect != null) {
        setState(() => _createGrid());
      }
    });
  }
}

///  Wrapper Screen with Scaffold (Example Usage)
class WiFiHeatmapScreen extends StatefulWidget {
  final Future<SignalResult> Function()? getSignalStrength;
  final String floorPlan;
  final int gridSize;
  final DeviceStyles? deviceStyles;
  final ScanPointStyles? scanPointStyles;
  final LocationPinStyles? locationPinStyles;
  final GridStyles? gridStyles;
  final HeatmapStyles? heatmapStyles;
  final PathStyles? pathStyles;
  final SignalStyles? signalStyles;
  final ButtonStyles? buttonStyles;

  const WiFiHeatmapScreen({
    super.key,
    this.getSignalStrength,
    required this.floorPlan,
    this.gridSize = 12,
    this.deviceStyles,
    this.scanPointStyles,
    this.locationPinStyles,
    this.gridStyles,
    this.heatmapStyles,
    this.pathStyles,
    this.signalStyles,
    this.buttonStyles,
  });

  @override
  State<WiFiHeatmapScreen> createState() => _WiFiHeatmapScreenState();
}

class _WiFiHeatmapScreenState extends State<WiFiHeatmapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WiFi Heatmap')),
      body: WiFiHeatmapWidget(
        floorPlan: widget.floorPlan,
        gridSize: widget.gridSize,
        getSignalStrength: widget.getSignalStrength,
        deviceStyles: widget.deviceStyles ?? const DeviceStyles(),
        scanPointStyles: widget.scanPointStyles ?? const ScanPointStyles(),
        locationPinStyles:
            widget.locationPinStyles ?? const LocationPinStyles(),
        gridStyles: widget.gridStyles ?? const GridStyles(),
        heatmapStyles: widget.heatmapStyles ?? const HeatmapStyles(),
        pathStyles: widget.pathStyles ?? const PathStyles(),
        signalStyles: widget.signalStyles ?? const SignalStyles(),
        buttonStyles: widget.buttonStyles ?? const ButtonStyles(),
        onShowMessage: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      ),
    );
  }
}

///  Reusable Widgets
class DeviceMarker extends StatelessWidget {
  final Device device;
  final DeviceStyles deviceStyles;
  final Icon Function(Device) getIcon;

  const DeviceMarker({
    super.key,
    required this.device,
    required this.deviceStyles,
    required this.getIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: deviceStyles.markerSize,
      height: deviceStyles.markerSize,
      decoration: BoxDecoration(
        color: deviceStyles.getDeviceColor(device),
        shape: BoxShape.circle,
        border: Border.all(
          color: deviceStyles.borderColor,
          width: deviceStyles.borderWidth,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: getIcon(device),
    );
  }
}

class DraggableDevice extends StatelessWidget {
  final Device device;
  final Rect imageRect;
  final ValueChanged<Offset> onPositionChanged;
  final DeviceStyles deviceStyles;
  final Icon Function(Device) getIcon;

  const DraggableDevice({
    super.key,
    required this.device,
    required this.imageRect,
    required this.onPositionChanged,
    required this.deviceStyles,
    required this.getIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: imageRect.left + device.position.dx,
      top: imageRect.top + device.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final newDx = (device.position.dx + details.delta.dx).clamp(
            0.0,
            imageRect.width - deviceStyles.markerSize,
          );
          final newDy = (device.position.dy + details.delta.dy).clamp(
            0.0,
            imageRect.height - deviceStyles.markerSize,
          );
          onPositionChanged(Offset(newDx, newDy));
        },
        child: DeviceMarker(
            device: device, deviceStyles: deviceStyles, getIcon: getIcon),
      ),
    );
  }
}

class FixedDeviceMarker extends StatelessWidget {
  final Device device;
  final Rect imageRect;
  final DeviceStyles deviceStyles;
  final Icon Function(Device) getIcon;

  const FixedDeviceMarker({
    super.key,
    required this.device,
    required this.imageRect,
    required this.deviceStyles,
    required this.getIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: imageRect.left + device.position.dx,
      top: imageRect.top + device.position.dy,
      child: DeviceMarker(
          device: device, deviceStyles: deviceStyles, getIcon: getIcon),
    );
  }
}

class ScanPointDot extends StatelessWidget {
  final Offset gridPos;
  final List<double> colWidths;
  final List<double> rowHeights;
  final Rect imageRect;
  final ScanPointStyles scanPointStyles;

  const ScanPointDot({
    super.key,
    required this.gridPos,
    required this.colWidths,
    required this.rowHeights,
    required this.imageRect,
    required this.scanPointStyles,
  });

  @override
  Widget build(BuildContext context) {
    final r = gridPos.dx.toInt();
    final c = gridPos.dy.toInt();

    double x = colWidths.take(c).fold(0.0, (a, b) => a + b) + colWidths[c] / 2;
    double y =
        rowHeights.take(r).fold(0.0, (a, b) => a + b) + rowHeights[r] / 2;

    final cellW = colWidths[c];
    final cellH = rowHeights[r];
    final dotSize = min(cellW, cellH) * scanPointStyles.dotSizeFactor;

    return Positioned(
      left: imageRect.left + x - dotSize / 2,
      top: imageRect.top + y - dotSize / 2,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scanPointStyles.color,
          border: Border.all(
            color: scanPointStyles.borderColor,
            width: scanPointStyles.borderWidth,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(1, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class MarkerPin extends StatelessWidget {
  final Offset gridPos;
  final List<double> colWidths;
  final List<double> rowHeights;
  final Rect imageRect;
  final LocationPinStyles locationPinStyles;
  final Icon Function() getIcon;

  const MarkerPin({
    super.key,
    required this.gridPos,
    required this.colWidths,
    required this.rowHeights,
    required this.imageRect,
    required this.locationPinStyles,
    required this.getIcon,
  });

  @override
  Widget build(BuildContext context) {
    final r = gridPos.dx.toInt();
    final c = gridPos.dy.toInt();

    final center = Offset(
      colWidths.take(c).fold(0.0, (a, b) => a + b) + colWidths[c] / 2,
      rowHeights.take(r).fold(0.0, (a, b) => a + b) + rowHeights[r] / 2,
    );

    final icon = getIcon();

    return Positioned(
      left: imageRect.left + center.dx - locationPinStyles.size / 2,
      top: imageRect.top + center.dy - locationPinStyles.size * 0.85,
      child: IconTheme(
        data: IconThemeData(
          size: locationPinStyles.size,
          color: locationPinStyles.color,
          shadows: const [
            Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 3)),
          ],
        ),
        child: icon,
      ),
    );
  }
}

///  Painters
class VariableGridPainterWidget extends StatelessWidget {
  final List<List<GridCell>> grid;
  final List<double> colWidths;
  final List<double> rowHeights;
  final GridStyles gridStyles;
  final HeatmapStyles heatmapStyles;

  const VariableGridPainterWidget({
    super.key,
    required this.grid,
    required this.colWidths,
    required this.rowHeights,
    required this.gridStyles,
    required this.heatmapStyles,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VariableGridPainter(
        grid: grid,
        colWidths: colWidths,
        rowHeights: rowHeights,
        gridStyles: gridStyles,
        heatmapStyles: heatmapStyles,
      ),
      size: Size.infinite,
    );
  }
}

class _VariableGridPainter extends CustomPainter {
  final List<List<GridCell>> grid;
  final List<double> colWidths;
  final List<double> rowHeights;
  final GridStyles gridStyles;
  final HeatmapStyles heatmapStyles;

  _VariableGridPainter({
    required this.grid,
    required this.colWidths,
    required this.rowHeights,
    required this.gridStyles,
    required this.heatmapStyles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Heatmap fills
    double y = 0;
    for (int r = 0; r < grid.length; r++) {
      double x = 0;
      for (int c = 0; c < grid[r].length; c++) {
        final cell = grid[r][c];
        if (cell.scanned && cell.color != null) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, colWidths[c], rowHeights[r]),
            Paint()..color = cell.color!.withAlpha(heatmapStyles.fillAlpha),
          );
        }
        x += colWidths[c];
      }
      y += rowHeights[r];
    }

    // Grid lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = gridStyles.lineColor.withAlpha(gridStyles.alpha)
      ..strokeWidth = gridStyles.lineWidth;

    y = 0;
    for (final h in rowHeights) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      y += h;
    }
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    double x = 0;
    for (final w in colWidths) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      x += w;
    }
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PathConnectionPainter extends CustomPainter {
  final List<Offset> gridPoints;
  final List<double> colWidths;
  final List<double> rowHeights;
  final PathStyles pathStyles;
  final bool isDotted;

  PathConnectionPainter({
    required this.gridPoints,
    required this.colWidths,
    required this.rowHeights,
    required this.pathStyles,
    this.isDotted = false,
  });

  Offset _gridToPixel(Offset g) {
    final r = g.dx.toInt();
    final c = g.dy.toInt();
    final x =
        colWidths.take(c).fold<double>(0, (a, b) => a + b) + colWidths[c] / 2;
    final y =
        rowHeights.take(r).fold<double>(0, (a, b) => a + b) + rowHeights[r] / 2;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (gridPoints.length < 2) return;

    final paint = Paint()
      ..color = pathStyles.color
      ..strokeWidth = pathStyles.width
      ..style = PaintingStyle.stroke;

    if (isDotted) {
      paint.strokeCap = StrokeCap.round;
      const dashPattern = [8.0, 5.0];
      for (int i = 0; i < gridPoints.length - 1; i++) {
        final a = _gridToPixel(gridPoints[i]);
        final b = _gridToPixel(gridPoints[i + 1]);
        _drawDashedLine(canvas, a, b, paint, dashPattern);
      }
    } else {
      for (int i = 0; i < gridPoints.length - 1; i++) {
        final a = _gridToPixel(gridPoints[i]);
        final b = _gridToPixel(gridPoints[i + 1]);
        canvas.drawLine(a, b, paint);
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    List<double> pattern,
  ) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 1e-6) return;

    double traveled = 0.0;
    bool shouldDraw = true;
    int patternIndex = 0;

    while (traveled < dist) {
      final segmentLength = pattern[patternIndex % pattern.length];
      final progress = traveled / dist;
      final nextProgress = (traveled + segmentLength) / dist;

      final x1 = a.dx + dx * progress;
      final y1 = a.dy + dy * progress;
      final x2 = a.dx + dx * nextProgress.clamp(0.0, 1.0);
      final y2 = a.dy + dy * nextProgress.clamp(0.0, 1.0);

      if (shouldDraw) {
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }

      traveled += segmentLength;
      shouldDraw = !shouldDraw;
      patternIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
