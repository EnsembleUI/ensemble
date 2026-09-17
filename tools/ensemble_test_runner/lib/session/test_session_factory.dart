import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/session/test_execution_session.dart';

/// Configuration for creating a [TestExecutionSession].
///
/// Standalone creation still requires a valid Flutter test context; the host
/// supplies tester/harness dependencies. Callers interact only through
/// [TestExecutionSession].
class TestSessionConfiguration {
  final String? sessionId;
  final String? startScreen;
  final Map<String, dynamic> startScreenInputs;
  final SessionPermissions permissions;
  final Duration? defaultActionTimeout;
  final Duration? defaultWaitTimeout;

  TestSessionConfiguration({
    this.sessionId,
    this.startScreen,
    this.startScreenInputs = const {},
    SessionPermissions? permissions,
    this.defaultActionTimeout,
    this.defaultWaitTimeout,
  }) : permissions = permissions ?? SessionPermissions.restrictedUi;

  Map<String, dynamic> toJson() => {
        if (sessionId != null) 'sessionId': sessionId,
        if (startScreen != null) 'startScreen': startScreen,
        if (startScreenInputs.isNotEmpty) 'startScreenInputs': startScreenInputs,
        'permissions': permissions.toJson(),
        if (defaultActionTimeout != null)
          'defaultActionTimeoutMs': defaultActionTimeout!.inMilliseconds,
        if (defaultWaitTimeout != null)
          'defaultWaitTimeoutMs': defaultWaitTimeout!.inMilliseconds,
      };

  factory TestSessionConfiguration.fromJson(Map<String, dynamic> json) {
    final permsRaw = json['permissions'];
    return TestSessionConfiguration(
      sessionId: json['sessionId']?.toString(),
      startScreen: json['startScreen']?.toString(),
      startScreenInputs: json['startScreenInputs'] is Map
          ? Map<String, dynamic>.from(json['startScreenInputs'] as Map)
          : const {},
      permissions: permsRaw is Map
          ? SessionPermissions.fromJson(Map<String, dynamic>.from(permsRaw))
          : SessionPermissions.restrictedUi,
      defaultActionTimeout: json['defaultActionTimeoutMs'] is int
          ? Duration(milliseconds: json['defaultActionTimeoutMs'] as int)
          : null,
      defaultWaitTimeout: json['defaultWaitTimeoutMs'] is int
          ? Duration(milliseconds: json['defaultWaitTimeoutMs'] as int)
          : null,
    );
  }
}

/// Abstract factory for standalone (YAML-independent) sessions.
abstract interface class TestSessionFactory {
  Future<TestExecutionSession> create(TestSessionConfiguration config);
}
