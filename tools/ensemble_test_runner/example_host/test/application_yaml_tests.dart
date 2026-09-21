import 'package:ensemble_test_runner/ensemble_test_runner.dart';

import 'host_app_test_driver.dart';

Future<void> main() => runApplicationYamlTests(driver: HostAppTestDriver());
