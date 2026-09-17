/// Acceptance status for remote-execution milestones.
enum AcceptanceStatus {
  implemented,
  verified,
  blocked,
  unverified,
}

class AcceptanceCell {
  final String criterion;
  final String platform;
  final AcceptanceStatus status;
  final String notes;

  const AcceptanceCell({
    required this.criterion,
    required this.platform,
    required this.status,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'criterion': criterion,
        'platform': platform,
        'status': status.name,
        if (notes.isNotEmpty) 'notes': notes,
      };
}

/// Ledger required by the remote execution plan. Fake-provider-only work is at
/// most [AcceptanceStatus.implemented], never production-ready.
abstract final class RemoteAcceptanceLedger {
  RemoteAcceptanceLedger._();

  static List<AcceptanceCell> current() => const [
        AcceptanceCell(
          criterion: 'Packaging builds',
          platform: 'android',
          status: AcceptanceStatus.implemented,
          notes:
              'AndroidFtlPackager builds APK/androidTest or emits stubs when SDK missing.',
        ),
        AcceptanceCell(
          criterion: 'Packaging builds',
          platform: 'ios',
          status: AcceptanceStatus.implemented,
          notes: 'IosFtlPackager emits XCTest zip placeholders; cloud unverified.',
        ),
        AcceptanceCell(
          criterion: 'Artifact export E2E (pass)',
          platform: 'android',
          status: AcceptanceStatus.unverified,
          notes:
              'Local ArtifactExportProof covers pass envelope; FTL directoriesToPull path is a hypothesis until real device collect.',
        ),
        AcceptanceCell(
          criterion: 'Artifact export E2E (pass)',
          platform: 'ios',
          status: AcceptanceStatus.unverified,
          notes: 'Export path hypothesis only; awaiting Phase 2b cloud proof.',
        ),
        AcceptanceCell(
          criterion: 'Artifact export E2E (fail)',
          platform: 'android',
          status: AcceptanceStatus.unverified,
          notes: 'Local fail envelope + reconciler taxonomy covered in unit tests.',
        ),
        AcceptanceCell(
          criterion: 'Artifact export E2E (fail)',
          platform: 'ios',
          status: AcceptanceStatus.unverified,
        ),
        AcceptanceCell(
          criterion: 'Real FTL execution + collect',
          platform: 'android',
          status: AcceptanceStatus.unverified,
          notes:
              'Requires ENSEMBLE_TEST_FTL_PROJECT_ID + ADC. Missing creds ⇒ unverified, not passed. Blocks multi-device orchestration.',
        ),
        AcceptanceCell(
          criterion: 'Real FTL execution + collect',
          platform: 'ios',
          status: AcceptanceStatus.unverified,
          notes: 'Separate milestone after Android verification.',
        ),
        AcceptanceCell(
          criterion: 'Envelope complete after cleanup',
          platform: 'shared',
          status: AcceptanceStatus.implemented,
          notes:
              'Entry emits RemoteRunEnvelope only after restorePreSuiteStorageAtSuiteEnd; cleanupErrors included.',
        ),
        AcceptanceCell(
          criterion: 'Multi-device orchestrate + durable resume',
          platform: 'shared',
          status: AcceptanceStatus.implemented,
          notes:
              'RemoteOrchestrator + FileRemoteRunStore + GcsRemoteRunStore CAS. Multi-device gated on Android verified.',
        ),
        AcceptanceCell(
          criterion: 'Unified reports + correct exit codes',
          platform: 'shared',
          status: AcceptanceStatus.implemented,
          notes:
              'RemoteReportReconciler: pass/testFailure/incomplete/infra/artifact.',
        ),
        AcceptanceCell(
          criterion: 'Widget/local integration backward compatible',
          platform: 'shared',
          status: AcceptanceStatus.implemented,
          notes: 'ExecutionTarget defaults to local; existing mode path unchanged.',
        ),
      ];

  static bool get isProductionReady {
    final cells = current();
    bool verified(String criterion, String platform) => cells.any(
          (c) =>
              c.criterion == criterion &&
              c.platform == platform &&
              c.status == AcceptanceStatus.verified,
        );
    return verified('Real FTL execution + collect', 'android') &&
        verified('Real FTL execution + collect', 'ios') &&
        verified('Artifact export E2E (pass)', 'android') &&
        verified('Artifact export E2E (pass)', 'ios') &&
        verified('Artifact export E2E (fail)', 'android') &&
        verified('Artifact export E2E (fail)', 'ios');
  }

  static String renderMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Remote execution acceptance ledger')
      ..writeln()
      ..writeln(
        'Statuses: `implemented` | `verified` | `blocked` | `unverified`.',
      )
      ..writeln()
      ..writeln(
        '**Production-ready:** ${isProductionReady ? 'YES' : 'NO'} '
        '(requires verified Android and iOS cloud E2E + artifact rows).',
      )
      ..writeln()
      ..writeln('| Criterion | Android | iOS | Shared |')
      ..writeln('|-----------|---------|-----|--------|');

    final criteria = <String>{};
    for (final c in current()) {
      criteria.add(c.criterion);
    }
    for (final criterion in criteria) {
      String cell(String platform) {
        final match = current().where(
          (c) => c.criterion == criterion && c.platform == platform,
        );
        if (match.isEmpty) return '';
        return match.first.status.name;
      }

      final shared = cell('shared');
      if (shared.isNotEmpty) {
        buffer.writeln('| $criterion | | | $shared |');
      } else {
        buffer.writeln(
          '| $criterion | ${cell('android')} | ${cell('ios')} | |',
        );
      }
    }
    buffer.writeln();
    for (final c in current()) {
      if (c.notes.isEmpty) continue;
      buffer.writeln('- **${c.criterion}** (${c.platform}): ${c.notes}');
    }
    return buffer.toString();
  }
}
