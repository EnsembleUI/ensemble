import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/module/location_module.dart';
import 'package:ensemble_location/location_manager.dart';
import 'package:ensemble_location/widget/maps/maps.dart';
import 'package:get_it/get_it.dart';

class LocationModuleImpl implements LocationModule {
  LocationModuleImpl() {
    GetIt.I.registerSingleton<LocationManager>(LocationManagerImpl());
    GetIt.I.registerFactory<EnsembleMap>(() => EnsembleMapWidget());
  }
}
