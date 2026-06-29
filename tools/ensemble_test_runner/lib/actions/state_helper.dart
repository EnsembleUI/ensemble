import 'package:ensemble/framework/scope.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Writes a dot-path value into the active [ScopeManager] data context.
void setStatePath(ScopeManager scope, String path, dynamic value) {
  final parts = path.split('.').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    throw EnsembleTestFailure('setState path cannot be empty');
  }
  if (parts.length == 1) {
    scope.dataContext.addDataContextById(parts.first, value);
    return;
  }

  final root = parts.first;
  final existing = scope.dataContext.getContextMap()[root];
  final Map<String, dynamic> rootMap = existing is Map
      ? Map<String, dynamic>.from(existing)
      : <String, dynamic>{};

  var cursor = rootMap;
  for (var i = 1; i < parts.length - 1; i++) {
    final key = parts[i];
    final next = cursor[key];
    if (next is Map) {
      cursor[key] = Map<String, dynamic>.from(next);
    } else {
      cursor[key] = <String, dynamic>{};
    }
    cursor = cursor[key] as Map<String, dynamic>;
  }
  cursor[parts.last] = value;
  scope.dataContext.addDataContextById(root, rootMap);
}
