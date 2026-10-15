import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
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

/// Checkpoint model to track timestamp and grid position
class Checkpoint {
  final Offset gridPosition;
  final int timestamp;
  final int dBm;

  Checkpoint({
    required this.gridPosition,
    required this.timestamp,
    required this.dBm,
  });
}

/// Separate style classes (with nullable constructor params + defaults)
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
    double? markerSize,
    double? iconSize,
    double? borderWidth,
    Color? borderColor,
    Color? modemColor,
    Color? modemIconColor,
    Color? routerColor,
    Color? routerIconColor,
  })  : markerSize = markerSize ?? 32.0,
        iconSize = iconSize ?? 20.0,
        borderWidth = borderWidth ?? 2.8,
        borderColor = borderColor ?? Colors.white,
        modemColor = modemColor ?? Colors.red,
        modemIconColor = modemIconColor ?? Colors.white,
        routerColor = routerColor ?? Colors.blue,
        routerIconColor = routerIconColor ?? Colors.white;

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
    double? dotSizeFactor,
    Color? color,
    Color? borderColor,
    double? borderWidth,
  })  : dotSizeFactor = dotSizeFactor ?? 0.4,
        color = color ?? Colors.blueAccent,
        borderColor = borderColor ?? const Color(0xB3FFFFFF),
        borderWidth = borderWidth ?? 1.8;
}

class LocationPinStyles {
  final double size;
  final Color color;

  const LocationPinStyles({
    double? size,
    Color? color,
  })  : size = size ?? 44.0,
        color = color ?? Colors.red;
}

class GridStyles {
  final double lineWidth;
  final int alpha;
  final Color lineColor;

  const GridStyles({
    double? lineWidth,
    int? alpha,
    Color? lineColor,
  })  : lineWidth = lineWidth ?? 0.6,
        alpha = alpha ?? 60,
        lineColor = lineColor ?? Colors.black;
}

class HeatmapStyles {
  final int fillAlpha;

  const HeatmapStyles({
    int? fillAlpha,
  }) : fillAlpha = fillAlpha ?? 123;
}

class PathStyles {
  final Color color;
  final double width;

  const PathStyles({
    Color? color,
    double? width,
  })  : color = color ?? const Color(0xFF1976D2),
        width = width ?? 2.8;
}

class SignalStyles {
  final Color excellentColor;
  final Color veryGoodColor;
  final Color goodColor;
  final Color fairColor;
  final Color poorColor;
  final Color badColor;

  const SignalStyles({
    Color? excellentColor,
    Color? veryGoodColor,
    Color? goodColor,
    Color? fairColor,
    Color? poorColor,
    Color? badColor,
  })  : excellentColor = excellentColor ?? const Color(0xFF388E3C),
        veryGoodColor = veryGoodColor ?? const Color(0xFF66BB6A),
        goodColor = goodColor ?? const Color(0xFFAFB42B),
        fairColor = fairColor ?? const Color(0xFFF57C00),
        poorColor = poorColor ?? const Color(0xFFE64A19),
        badColor = badColor ?? const Color(0xFFC62828);

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
    Color? startScanColor,
    Color? addCheckpointColor,
  })  : startScanColor = startScanColor ?? const Color(0xFF388E3C),
        addCheckpointColor = addCheckpointColor ?? const Color(0xFF1976D2);
}

/// Reusable WiFi Heatmap Widget
class WiFiHeatmapWidget extends StatefulWidget {
  final Future<SignalResult> Function()? getSignalStrength;
  final String floorPlan;
  final int gridSize;
  final Function(String message)? onShowMessage;
  final VoidCallback? onFirstCheckpoint;
  final VoidCallback? onAllGridsFilled;

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

  // External signal values (list of {timestamp, dbm} objects)
  final List<Map<String, dynamic>> signalValues;

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
    this.onFirstCheckpoint,
    this.onAllGridsFilled,
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
    this.signalValues = const [],
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

  // Checkpoint tracking
  final List<Checkpoint> _checkpoints = [];
  List<Map<String, dynamic>> _signalValues = [];

  final _stackKey = GlobalKey();
  bool _imageLoadFailed = false;
  bool _allGridsFilled = false;

  @override
  void initState() {
    super.initState();
    _floorPlan = File(widget.floorPlan);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImageSize();
    });
  }

  @override
  void didUpdateWidget(covariant WiFiHeatmapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // React to external signalValues updates
    if (!listEquals(widget.signalValues, _signalValues)) {
      _signalValues = List.from(widget.signalValues);
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
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
            if (_checkpoints.length >= 2)
              Positioned.fromRect(
                rect: _displayedImageRect!,
                child: CustomPaint(
                  painter: PathConnectionPainter(
                    gridPoints:
                        _checkpoints.map((c) => c.gridPosition).toList(),
                    colWidths: _colWidths,
                    rowHeights: _rowHeights,
                    pathStyles: widget.pathStyles,
                  ),
                ),
              ),
            if (_checkpoints.isNotEmpty && _markerGridPos != null)
              Positioned.fromRect(
                rect: _displayedImageRect!,
                child: CustomPaint(
                  painter: PathConnectionPainter(
                    gridPoints: [
                      _checkpoints.last.gridPosition,
                      _markerGridPos!
                    ],
                    colWidths: _colWidths,
                    rowHeights: _rowHeights,
                    pathStyles: widget.pathStyles,
                    isDotted: true,
                  ),
                ),
              ),
            ..._checkpoints.map(
              (checkpoint) => ScanPointDot(
                gridPos: checkpoint.gridPosition,
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
                                onPressed:
                                    _allGridsFilled ? null : _addCheckpoint,
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

    // Don't add checkpoint if it's the same as the last one
    if (_checkpoints.isNotEmpty &&
        _checkpoints.last.gridPosition == Offset(r.toDouble(), c.toDouble())) {
      return;
    }

    // Get current timestamp and dBm
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    int currentDbm;

    // Try to get dBm from latest signal value first
    if (_signalValues.isNotEmpty) {
      final lastSignal = _signalValues.last;
      currentDbm = lastSignal['dbm'] as int;
    } else if (widget.getSignalStrength != null) {
      try {
        final result = await widget.getSignalStrength!();
        currentDbm = result.dBm;
      } catch (e) {
        if (mounted) {
          widget.onShowMessage?.call('Error getting signal: $e');
        }
        return;
      }
    } else {
      final result = _getRandomSignal();
      currentDbm = result.dBm;
    }

    if (!mounted) return;

    final newPos = Offset(r.toDouble(), c.toDouble());
    final newCheckpoint = Checkpoint(
      gridPosition: newPos,
      timestamp: currentTimestamp,
      dBm: currentDbm,
    );

    setState(() {
      // Update the checkpoint cell itself
      final cell = _grid[r][c];
      cell.rssi = currentDbm;
      cell.color = widget.signalStyles.getSignalColor(currentDbm);
      cell.scanned = true;

      if (_checkpoints.isEmpty) {
        // First checkpoint - trigger callback to start timer
        _checkpoints.add(newCheckpoint);
        widget.onFirstCheckpoint?.call();
      } else {
        // Subsequent checkpoint - process the segment between previous and current
        final prevCheckpoint = _checkpoints.last;
        _processSegmentWithTimestamps(prevCheckpoint, newCheckpoint);
        _checkpoints.add(newCheckpoint);

        // Check if all grids are filled
        _checkAllGridsFilled();
      }
    });
  }

  void _processSegmentWithTimestamps(Checkpoint start, Checkpoint end) {
    final startR = start.gridPosition.dx.toInt();
    final startC = start.gridPosition.dy.toInt();
    final endR = end.gridPosition.dx.toInt();
    final endC = end.gridPosition.dy.toInt();

    // Get all cells between start and end
    final lineCells = _getLineCells(startR, startC, endR, endC);
    if (lineCells.length < 2) return;

    // Filter signal values between the two checkpoint timestamps
    final signalsInRange = _signalValues.where((signal) {
      final timestamp = signal['timestamp'] as int;
      return timestamp >= start.timestamp && timestamp <= end.timestamp;
    }).toList();

    // If no signals in range, use checkpoint values
    if (signalsInRange.isEmpty) {
      _fillCellsWithInterpolation(lineCells, start.dBm, end.dBm);
      return;
    }

    // Extract dBm values
    final dbmValues = signalsInRange.map((s) => s['dbm'] as int).toList();

    // Ensure start and end values are included
    if (dbmValues.first != start.dBm) {
      dbmValues.insert(0, start.dBm);
    }
    if (dbmValues.last != end.dBm) {
      dbmValues.add(end.dBm);
    }

    final numCells = lineCells.length;
    final numValues = dbmValues.length;

    // Map values to cells
    for (int i = 0; i < numCells; i++) {
      final gridPos = lineCells[i];
      final rr = gridPos.dx.toInt();
      final cc = gridPos.dy.toInt();

      if (rr >= 0 && rr < _grid.length && cc >= 0 && cc < _grid[rr].length) {
        final cell = _grid[rr][cc];

        // CRITICAL: Never overwrite cells that already have values
        if (cell.scanned) {
          continue;
        }

        int cellDbm;

        if (numValues == numCells) {
          // Perfect match - one value per cell
          cellDbm = dbmValues[i];
        } else if (numValues > numCells) {
          // More values than cells - use average
          final startIdx = (i * numValues) ~/ numCells;
          final endIdx = ((i + 1) * numValues) ~/ numCells;
          final valuesForCell = dbmValues.sublist(
            startIdx,
            endIdx.clamp(startIdx + 1, numValues),
          );
          cellDbm =
              valuesForCell.reduce((a, b) => a + b) ~/ valuesForCell.length;
        } else {
          // More cells than values - distribute values
          final valueIdx = (i * numValues) ~/ numCells;
          final safeIdx = valueIdx.clamp(0, numValues - 1);
          cellDbm = dbmValues[safeIdx];
        }

        cell.rssi = cellDbm;
        cell.color = widget.signalStyles.getSignalColor(cellDbm);
        cell.scanned = true;
      }
    }
  }

  void _fillCellsWithInterpolation(
      List<Offset> cells, int startDbm, int endDbm) {
    for (int i = 0; i < cells.length; i++) {
      final gridPos = cells[i];
      final rr = gridPos.dx.toInt();
      final cc = gridPos.dy.toInt();

      if (rr >= 0 && rr < _grid.length && cc >= 0 && cc < _grid[rr].length) {
        final cell = _grid[rr][cc];

        // CRITICAL: Never overwrite cells that already have values
        if (cell.scanned) {
          continue;
        }

        // Linear interpolation
        final ratio = cells.length > 1 ? i / (cells.length - 1) : 0.0;
        final cellDbm = (startDbm + (endDbm - startDbm) * ratio).round();

        cell.rssi = cellDbm;
        cell.color = widget.signalStyles.getSignalColor(cellDbm);
        cell.scanned = true;
      }
    }
  }

  void _checkAllGridsFilled() {
    // Check if all grid cells are scanned
    bool allFilled = true;
    for (final row in _grid) {
      for (final cell in row) {
        if (!cell.scanned) {
          allFilled = false;
          break;
        }
      }
      if (!allFilled) break;
    }

    if (allFilled && !_allGridsFilled) {
      _allGridsFilled = true;
      widget.onAllGridsFilled?.call();
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
      _checkpoints.clear();
      _signalValues.clear();
      _allGridsFilled = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _displayedImageRect != null) {
        setState(() => _createGrid());
      }
    });
  }
}

/// Wrapper Screen with Scaffold (Example Usage)
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

/// Reusable Widgets
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

/// Painters
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
