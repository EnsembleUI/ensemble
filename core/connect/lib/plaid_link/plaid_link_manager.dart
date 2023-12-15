import 'package:ensemble/framework/stub/plaid_link_manager.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

class PlaidLinkManagerImpl extends PlaidLinkManager {
  @override
  void openPlaidLink(String plaidLink, PlaidLinkSuccessCallback onSuccess,
      PlaidLinkEventCallback onEvent, PlaidLinkErrorCallback onExit) {
    // Subscribe to all events

    PlaidLink.onSuccess.listen((successData) {
      onSuccess(PlaidLinkSuccess.fromLinkSuccess(successData).toJson());
    });
    PlaidLink.onEvent.listen((eventData) {
      onEvent(eventData.toJson());
    });
    PlaidLink.onExit.listen((exitData) {
      onExit(exitData.toJson());
    });

    PlaidLink.open(configuration: LinkTokenConfiguration(token: plaidLink));
  }
}

class PlaidLinkSuccess {
  final String publicToken;
  final PlaidLinkSuccessMetadata metadata;

  PlaidLinkSuccess({
    required this.publicToken,
    required this.metadata,
  });

  factory PlaidLinkSuccess.fromLinkSuccess(LinkSuccess data) {
    return PlaidLinkSuccess(
      publicToken: data.publicToken,
      metadata: PlaidLinkSuccessMetadata(
        linkSessionId: data.metadata.linkSessionId,
        institution: PlaidLinkInstitution(
          id: data.metadata.institution?.id ?? '',
          name: data.metadata.institution?.name ?? '',
        ),
        accounts: data.metadata.accounts
            .map(
              (e) => PlaidLinkAccount(
                  id: e.id,
                  mask: e.mask,
                  name: e.name,
                  type: e.type,
                  subtype: e.subtype,
                  verificationStatus: e.verificationStatus),
            )
            .toList(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'publicToken': publicToken,
      'metadata': metadata.toJson(),
    };
  }
}

class PlaidLinkSuccessMetadata {
  final String linkSessionId;
  final PlaidLinkInstitution? institution;
  final List<PlaidLinkAccount> accounts;

  PlaidLinkSuccessMetadata({
    required this.linkSessionId,
    required this.institution,
    required this.accounts,
  });

  factory PlaidLinkSuccessMetadata.fromJson(dynamic json) {
    return PlaidLinkSuccessMetadata(
      linkSessionId: json['linkSessionId'],
      institution: json['institution'] != null
          ? PlaidLinkInstitution.fromJson(json['institution'])
          : null,
      accounts: (json['accounts'] as List)
          .map((info) => PlaidLinkAccount.fromJson(info))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'linkSessionId': linkSessionId,
      'institution': institution?.toJson(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
    };
  }

  String description() {
    String description =
        "linkSessionId: $linkSessionId, institution.id: ${institution?.id}, institution.name: ${institution?.name}, accounts: ";

    for (PlaidLinkAccount a in accounts) {
      description += a.description();
    }

    return description;
  }
}

class PlaidLinkInstitution {
  final String id;
  final String name;

  PlaidLinkInstitution({
    required this.id,
    required this.name,
  });

  factory PlaidLinkInstitution.fromJson(dynamic json) {
    return PlaidLinkInstitution(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
    };
  }

  String description() {
    return "id: $id, name: $name";
  }
}

class PlaidLinkAccount {
  final String id;
  final String? mask;
  final String name;
  final String type;
  final String subtype;
  final String? verificationStatus;

  PlaidLinkAccount({
    required this.id,
    required this.mask,
    required this.name,
    required this.type,
    required this.subtype,
    required this.verificationStatus,
  });

  factory PlaidLinkAccount.fromJson(dynamic json) {
    return PlaidLinkAccount(
      id: json['id'],
      name: json['name'],
      mask: json['mask'],
      type: json['type'],
      subtype: json['subtype'],
      verificationStatus: json['verificationStatus'],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'mask': mask,
      'type': type,
      'subtype': subtype,
      'verificationStatus': verificationStatus,
    };
  }

  String description() {
    return "[id: $id, mask: $mask, name: $name, type: $type, subtype: $subtype, verification_status: $verificationStatus]";
  }
}
