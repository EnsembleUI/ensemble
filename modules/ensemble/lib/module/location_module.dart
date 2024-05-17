import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:get_it/get_it.dart';

abstract class LocationModule {}

class LocationModuleStub implements LocationModule {
  LocationModuleStub() {
    GetIt.I.registerSingleton<LocationManager>(LocationManagerStub());
    GetIt.I.registerFactory<EnsembleMap>(() => const EnsembleMapStub());
  }
}

abstract class EnsembleMap {
  static const type = 'Map';
}

class EnsembleMapStub extends StubWidget implements EnsembleMap {
  const EnsembleMapStub({super.key}) : super(moduleName: 'Location');
}
