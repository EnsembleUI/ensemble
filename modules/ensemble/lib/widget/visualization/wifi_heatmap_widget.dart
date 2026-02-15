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

/// WiFi Heatmap Theme Configuration
class WiFiHeatmapTheme {
  final double? deviceMarkerSize;
  final double? deviceIconSize;
  final Color? modemColor;
  final Color? modemIconColor;
  final Icon? modemIcon;
  final Color? routerColor;
  final Color? routerIconColor;
  final Icon? routerIcon;
  final double? deviceBorderWidth;
  final Color? deviceBorderColor;

  final double? scanPointDotSizeFactor;
  final Color? scanPointColor;
  final Color? scanPointBorderColor;
  final double? scanPointBorderWidth;

  final double? locationPinSize;
  final Color? locationPinColor;
  final Icon? locationPinIcon;

  final double? gridLineWidth;
  final int? gridAlpha;
  final Color? gridLineColor;

  final int? heatmapFillAlpha;

  final Color? pathColor;
  final double? pathWidth;

  final int? defaultGridSize;
  final double? targetCellSize;

  final Color? excellentSignalColor;
  final Color? veryGoodSignalColor;
  final Color? goodSignalColor;
  final Color? fairSignalColor;
  final Color? poorSignalColor;
  final Color? badSignalColor;

  final Color? startScanButtonColor;
  final Color? addCheckpointButtonColor;

  const WiFiHeatmapTheme({
    this.deviceMarkerSize,
    this.deviceIconSize,
    this.modemColor,
    this.modemIconColor,
    this.modemIcon,
    this.routerColor,
    this.routerIconColor,
    this.routerIcon,
    this.deviceBorderWidth,
    this.deviceBorderColor,
    this.scanPointDotSizeFactor,
    this.scanPointColor,
    this.scanPointBorderColor,
    this.scanPointBorderWidth,
    this.locationPinSize,
    this.locationPinColor,
    this.locationPinIcon,
    this.gridLineWidth,
    this.gridAlpha,
    this.gridLineColor,
    this.heatmapFillAlpha,
    this.pathColor,
    this.pathWidth,
    this.defaultGridSize,
    this.targetCellSize,
    this.excellentSignalColor,
    this.veryGoodSignalColor,
    this.goodSignalColor,
    this.fairSignalColor,
    this.poorSignalColor,
    this.badSignalColor,
    this.startScanButtonColor,
    this.addCheckpointButtonColor,
  });

  // Default values
  double get _deviceMarkerSize => deviceMarkerSize ?? 36.0;
  double get _deviceIconSize => deviceIconSize ?? 22.0;
  Color get _modemColor => modemColor ?? Colors.red;
  Color get _modemIconColor => modemIconColor ?? Colors.white;
  Color get _routerColor => routerColor ?? Colors.blue;
  Color get _routerIconColor => routerIconColor ?? Colors.white;
  double get _deviceBorderWidth => deviceBorderWidth ?? 2.8;
  Color get _deviceBorderColor => deviceBorderColor ?? Colors.white;

  double get _scanPointDotSizeFactor => scanPointDotSizeFactor ?? 0.4;
  Color get _scanPointColor => scanPointColor ?? Colors.blueAccent;
  Color get _scanPointBorderColor =>
      scanPointBorderColor ?? const Color(0xB3FFFFFF);
  double get _scanPointBorderWidth => scanPointBorderWidth ?? 1.8;

  double get _locationPinSize => locationPinSize ?? 44.0;
  Color get _locationPinColor => locationPinColor ?? Colors.red;

  double get _gridLineWidth => gridLineWidth ?? 0.6;
  int get _gridAlpha => gridAlpha ?? 60;
  Color get _gridLineColor => gridLineColor ?? Colors.black;

  int get _heatmapFillAlpha => heatmapFillAlpha ?? 123;

  Color get _pathColor => pathColor ?? const Color(0xFF1976D2);
  double get _pathWidth => pathWidth ?? 2.8;

  int get _defaultGridSize => defaultGridSize ?? 12;

  Color get _excellentSignalColor =>
      excellentSignalColor ?? const Color(0xFF388E3C);
  Color get _veryGoodSignalColor =>
      veryGoodSignalColor ?? const Color(0xFF66BB6A);
  Color get _goodSignalColor => goodSignalColor ?? const Color(0xFFAFB42B);
  Color get _fairSignalColor => fairSignalColor ?? const Color(0xFFF57C00);
  Color get _poorSignalColor => poorSignalColor ?? const Color(0xFFE64A19);
  Color get _badSignalColor => badSignalColor ?? const Color(0xFFC62828);

  Color get _startScanButtonColor =>
      startScanButtonColor ?? const Color(0xFF388E3C);
  Color get _addCheckpointButtonColor =>
      addCheckpointButtonColor ?? const Color(0xFF1976D2);

  Color getSignalColor(int dBm) {
    if (dBm >= -50) return _excellentSignalColor;
    if (dBm >= -60) return _veryGoodSignalColor;
    if (dBm >= -70) return _goodSignalColor;
    if (dBm >= -80) return _fairSignalColor;
    if (dBm >= -90) return _poorSignalColor;
    return _badSignalColor;
  }

  Color getDeviceColor(Device device) =>
      device.isModem ? _modemColor : _routerColor;
  Color getDeviceIconColor(Device device) =>
      device.isModem ? _modemIconColor : _routerIconColor;

  Icon getDeviceIcon(Device device) {
    if (device.isModem) {
      return modemIcon ??
          Icon(Icons.wifi, color: _modemIconColor, size: _deviceIconSize);
    } else {
      return routerIcon ??
          Icon(Icons.router, color: _routerIconColor, size: _deviceIconSize);
    }
  }

  Icon getLocationPinIcon() {
    return locationPinIcon ??
        Icon(
          Icons.location_on,
          color: _locationPinColor,
          size: _locationPinSize,
        );
  }
}

/// Reusable WiFi Heatmap Widget
class WiFiHeatmapWidget extends StatefulWidget {
  final Future<SignalResult> Function()? getSignalStrength;
  final String floorPlan;
  final int? gridSize;
  final Function(String message)? onShowMessage;
  final WiFiHeatmapTheme theme;

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
    this.gridSize,
    this.onShowMessage,
    this.theme = const WiFiHeatmapTheme(),
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

  int get _effectiveGridSize =>
      widget.gridSize ?? widget.theme._defaultGridSize;

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

    // Use full available dimensions - no padding
    final newRect = Rect.fromLTWH(0, 0, availW, availH);

    // Only update if rect has actually changed significantly
    if (_displayedImageRect == null ||
        (_displayedImageRect!.left - newRect.left).abs() > 1 ||
        (_displayedImageRect!.top - newRect.top).abs() > 1 ||
        (_displayedImageRect!.width - newRect.width).abs() > 1 ||
        (_displayedImageRect!.height - newRect.height).abs() > 1) {
      _displayedImageRect = newRect;

      // Recreate grid when image rect changes in scanning mode
      if (_mode == 'scanning' && _grid.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _createGrid());
          }
        });
      }
    }
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
            theme: widget.theme,
            onPositionChanged: (newPos) =>
                setState(() => _modem!.position = newPos),
          ),
        ..._routers.map(
          (r) => DraggableDevice(
            device: r,
            imageRect: _displayedImageRect!,
            theme: widget.theme,
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
                theme: widget.theme,
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
                    theme: widget.theme,
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
                    theme: widget.theme,
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
                theme: widget.theme,
              ),
            ),
            if (_modem != null)
              FixedDeviceMarker(
                  device: _modem!,
                  imageRect: _displayedImageRect!,
                  theme: widget.theme),
            ..._routers.map((router) => FixedDeviceMarker(
                device: router,
                imageRect: _displayedImageRect!,
                theme: widget.theme)),
            if (_markerGridPos != null)
              MarkerPin(
                gridPos: _markerGridPos!,
                colWidths: _colWidths,
                rowHeights: _rowHeights,
                imageRect: _displayedImageRect!,
                theme: widget.theme,
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

        // Calculate image display dimensions (no padding, full width)
        final double imageDisplayWidth = availableWidth;
        final double imageDisplayHeight = imageDisplayWidth / imageAspectRatio;

        // Button area height (only for scanning mode)
        const double buttonAreaHeight = 76.0;

        // Total height: image + button area (only in scanning mode)
        final double totalHeight =
            imageDisplayHeight + (_mode == 'scanning' ? buttonAreaHeight : 0);

        // Update displayed rect with exact image dimensions
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
                                      widget.theme._addCheckpointButtonColor,
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
          backgroundColor: widget.theme._modemColor,
          onPressed: _addModem,
          child: widget.theme.modemIcon ??
              Icon(
                Icons.wifi,
                color: widget.theme._modemIconColor,
                size: widget.theme._deviceIconSize,
              ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'router',
          backgroundColor: widget.theme._routerColor,
          onPressed: _addRouter,
          child: widget.theme.routerIcon ??
              Icon(
                Icons.router,
                color: widget.theme._routerIconColor,
                size: widget.theme._deviceIconSize,
              ),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'start',
          backgroundColor: widget.theme._startScanButtonColor,
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

    final n = _effectiveGridSize.clamp(4, 32);

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
        cell.color = widget.theme.getSignalColor(d);
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
    return SignalResult(dBm, widget.theme.getSignalColor(dBm));
  }

  void _addModem() {
    if (_displayedImageRect == null || _modem != null) return;

    final center = Offset(
      (_displayedImageRect!.width - widget.theme._deviceMarkerSize) / 2,
      (_displayedImageRect!.height - widget.theme._deviceMarkerSize) / 2,
    );

    setState(() => _modem = Device(type: 'modem', position: center));
  }

  void _addRouter() {
    if (_displayedImageRect == null) return;

    final center = Offset(
      (_displayedImageRect!.width - widget.theme._deviceMarkerSize) / 2,
      (_displayedImageRect!.height - widget.theme._deviceMarkerSize) / 2,
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
      // Clear grid to force recreation with current image rect
      _grid.clear();
    });

    // Recreate grid after mode change
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
  final int? gridSize;
  final WiFiHeatmapTheme? theme;

  const WiFiHeatmapScreen({
    super.key,
    this.getSignalStrength,
    required this.floorPlan,
    this.gridSize,
    this.theme,
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
        theme: widget.theme ?? const WiFiHeatmapTheme(),
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
  final WiFiHeatmapTheme theme;

  const DeviceMarker({super.key, required this.device, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: theme._deviceMarkerSize,
      height: theme._deviceMarkerSize,
      decoration: BoxDecoration(
        color: theme.getDeviceColor(device),
        shape: BoxShape.circle,
        border: Border.all(
          color: theme._deviceBorderColor,
          width: theme._deviceBorderWidth,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: theme.getDeviceIcon(device),
    );
  }
}

class DraggableDevice extends StatelessWidget {
  final Device device;
  final Rect imageRect;
  final ValueChanged<Offset> onPositionChanged;
  final WiFiHeatmapTheme theme;

  const DraggableDevice({
    super.key,
    required this.device,
    required this.imageRect,
    required this.onPositionChanged,
    required this.theme,
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
            imageRect.width - theme._deviceMarkerSize,
          );
          final newDy = (device.position.dy + details.delta.dy).clamp(
            0.0,
            imageRect.height - theme._deviceMarkerSize,
          );
          onPositionChanged(Offset(newDx, newDy));
        },
        child: DeviceMarker(device: device, theme: theme),
      ),
    );
  }
}

class FixedDeviceMarker extends StatelessWidget {
  final Device device;
  final Rect imageRect;
  final WiFiHeatmapTheme theme;

  const FixedDeviceMarker({
    super.key,
    required this.device,
    required this.imageRect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: imageRect.left + device.position.dx,
      top: imageRect.top + device.position.dy,
      child: DeviceMarker(device: device, theme: theme),
    );
  }
}

class ScanPointDot extends StatelessWidget {
  final Offset gridPos;
  final List<double> colWidths;
  final List<double> rowHeights;
  final Rect imageRect;
  final WiFiHeatmapTheme theme;

  const ScanPointDot({
    super.key,
    required this.gridPos,
    required this.colWidths,
    required this.rowHeights,
    required this.imageRect,
    required this.theme,
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
    final dotSize = min(cellW, cellH) * theme._scanPointDotSizeFactor;

    return Positioned(
      left: imageRect.left + x - dotSize / 2,
      top: imageRect.top + y - dotSize / 2,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme._scanPointColor,
          border: Border.all(
            color: theme._scanPointBorderColor,
            width: theme._scanPointBorderWidth,
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
  final WiFiHeatmapTheme theme;

  const MarkerPin({
    super.key,
    required this.gridPos,
    required this.colWidths,
    required this.rowHeights,
    required this.imageRect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final r = gridPos.dx.toInt();
    final c = gridPos.dy.toInt();

    final center = Offset(
      colWidths.take(c).fold(0.0, (a, b) => a + b) + colWidths[c] / 2,
      rowHeights.take(r).fold(0.0, (a, b) => a + b) + rowHeights[r] / 2,
    );

    final icon = theme.getLocationPinIcon();

    return Positioned(
      left: imageRect.left + center.dx - theme._locationPinSize / 2,
      top: imageRect.top + center.dy - theme._locationPinSize * 0.85,
      child: IconTheme(
        data: IconThemeData(
          size: theme._locationPinSize,
          color: theme._locationPinColor,
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
  final WiFiHeatmapTheme theme;

  const VariableGridPainterWidget({
    super.key,
    required this.grid,
    required this.colWidths,
    required this.rowHeights,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VariableGridPainter(
        grid: grid,
        colWidths: colWidths,
        rowHeights: rowHeights,
        theme: theme,
      ),
      size: Size.infinite,
    );
  }
}

class _VariableGridPainter extends CustomPainter {
  final List<List<GridCell>> grid;
  final List<double> colWidths;
  final List<double> rowHeights;
  final WiFiHeatmapTheme theme;

  _VariableGridPainter({
    required this.grid,
    required this.colWidths,
    required this.rowHeights,
    required this.theme,
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
            Paint()..color = cell.color!.withAlpha(theme._heatmapFillAlpha),
          );
        }
        x += colWidths[c];
      }
      y += rowHeights[r];
    }

    // Grid lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = theme._gridLineColor.withAlpha(theme._gridAlpha)
      ..strokeWidth = theme._gridLineWidth;

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
  final WiFiHeatmapTheme theme;
  final bool isDotted;

  PathConnectionPainter({
    required this.gridPoints,
    required this.colWidths,
    required this.rowHeights,
    required this.theme,
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
      ..color = theme._pathColor
      ..strokeWidth = theme._pathWidth
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
