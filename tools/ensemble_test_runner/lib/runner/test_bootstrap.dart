import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/encrypted_storage_manager.dart';
import 'package:ensemble/framework/secrets.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/entry/runner_runtime_configuration.dart';

/// Per-test bootstrap data applied before the widget tree mounts.
class EnsembleTestSetup {
  final Map<String, dynamic>? envOverrides;
  final Map<String, dynamic>? initialPublicStorage;
  final Map<String, dynamic>? initialSecureStorage;
  final Map<String, dynamic>? initialKeychain;

  const EnsembleTestSetup({
    this.envOverrides,
    this.initialPublicStorage,
    this.initialSecureStorage,
    this.initialKeychain,
  });
}

/// Applies test environment and storage bootstrap data to [config].
Future<void> applyTestBootstrap(
    EnsembleConfig config, EnsembleTestSetup setup) async {
  if (setup.envOverrides != null && setup.envOverrides!.isNotEmpty) {
    config.updateEnvOverrides(setup.envOverrides!);
  }
  await applyTestStorageBootstrap(setup);
}

Future<void> applyTestStorageBootstrap(EnsembleTestSetup setup) async {
  return await RunnerBenchmark.async('lifecycle', 'applyTestStorageBootstrap',
      () async {
    for (final entry in setup.initialPublicStorage?.entries ??
        const Iterable<MapEntry<String, dynamic>>.empty()) {
      await StorageManager().write(entry.key, entry.value);
    }
    final secureEntries = setup.initialSecureStorage?.entries.toList() ??
        const <MapEntry<String, dynamic>>[];
    if (secureEntries.isNotEmpty) {
      await SecretsStore().initialize();
      installTestEncryptionKey();
    }
    for (final entry in secureEntries) {
      EncryptedStorageManager.setSecureStorage({
        'key': entry.key,
        'value': entry.value,
      });
      for (var attempt = 0; attempt < 50; attempt++) {
        if (StorageManager().read('enc_${entry.key}') != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    for (final entry in setup.initialKeychain?.entries ??
        const Iterable<MapEntry<String, dynamic>>.empty()) {
      await StorageManager().writeSecurely(key: entry.key, value: entry.value);
    }
  });
}

/// Installs the per-run test encryption key and clears the cached key.
void installTestEncryptionKey() {
  final fromDefine =
      RunnerRuntimeConfiguration.current.string('ensembleTestEncryptionKey');
  final key = fromDefine.isNotEmpty ? fromDefine : _fallbackTestEncryptionKey();
  if (key.length != 32) {
    throw StateError(
      'ensembleTestEncryptionKey must be exactly 32 characters '
      '(got ${key.length}).',
    );
  }
  EncryptedStorageManager.resetCachedKey();
  SecretsStore().secretCache['encryptionKey'] = key;
}

String _fallbackTestEncryptionKey() => 'EnsembleTestKey00000000000000000';
