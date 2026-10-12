/// The only runner boundary that knows about the optional device-preview
/// implementation.
///
/// Screenshot, viewport, and report code depend on this small surface instead
/// of importing the preview package directly. Keeping the package import here
/// makes the integration replaceable and prevents the preview API from
/// spreading through the execution layers.
library;

import 'package:ensemble_device_preview/ensemble_device_preview.dart'
    as preview;

typedef DeviceInfo = preview.DeviceInfo;

/// Device collections used by screenshot selection.
abstract final class DeviceCatalog {
  static List<DeviceInfo> get all => preview.Devices.all;
  static List<DeviceInfo> get android => preview.Devices.android.all;
  static List<DeviceInfo> get ios => preview.Devices.ios.all;
  static DeviceInfo get defaultAndroid => preview.Devices.android.all.first;
  static DeviceInfo get defaultIos => preview.Devices.ios.iPhone15Pro;
}
