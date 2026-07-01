/// Registers location services and widgets with Ensemble.
library location_module;

import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/module/location_module.dart';
import 'package:ensemble_location/location_manager.dart';
import 'package:ensemble_location/widget/maps/maps.dart';
import 'package:get_it/get_it.dart';

/// Location module registration hook.
class LocationModuleImpl implements LocationModule {
  /// Registers the location manager and map widget factory.
  LocationModuleImpl() {
    GetIt.I.registerSingleton<LocationManager>(LocationManagerImpl());
    GetIt.I.registerFactory<EnsembleMap>(() => EnsembleMapWidget());
  }
}
