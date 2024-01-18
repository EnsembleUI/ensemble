import 'dart:typed_data';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get_it/get_it.dart';

class GetPhoneContactAction extends EnsembleAction {
  GetPhoneContactAction({
    super.initiator,
    this.id,
    this.onSuccess,
    this.onError,
  });

  final String? id;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;

  EnsembleAction? getOnSuccess(DataContext dataContext) =>
      dataContext.eval(onSuccess);

  EnsembleAction? getOnError(DataContext dataContext) =>
      dataContext.eval(onError);

  factory GetPhoneContactAction.fromMap(
      {Invokable? initiator, dynamic payload}) {
    if (payload is Map) {
      return GetPhoneContactAction(
        initiator: initiator,
        id: Utils.optionalString(payload['id']),
        onSuccess: EnsembleAction.fromYaml(payload['onSuccess']),
        onError: EnsembleAction.fromYaml(payload['onError']),
      );
    }
    throw LanguageError(
        "${ActionType.getPhoneContacts.name} action requires payload");
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    GetIt.I<ContactManager>().getPhoneContacts((contacts) {
      if (getOnSuccess(scopeManager.dataContext) != null) {
        final contactsData =
            contacts.map((contact) => contact.toJson()).toList();

        ScreenController().executeActionWithScope(
          context,
          scopeManager,
          getOnSuccess(scopeManager.dataContext)!,
          event: EnsembleEvent(
            initiator,
            data: {'contacts': contactsData},
          ),
        );
      }
    }, (error) {
      if (getOnError(scopeManager.dataContext) != null) {
        ScreenController().executeActionWithScope(
          context,
          scopeManager,
          getOnError(scopeManager.dataContext)!,
          event: EnsembleEvent(initiator!, error: error),
        );
      }
    });
    return Future.value(null);
  }
}

class GetPhoneContactPhotoAction extends EnsembleAction {
  GetPhoneContactPhotoAction({
    super.initiator,
    this.id,
    required this.contactId,
  });

  final String? id;
  final String contactId;

  String getContactId(DataContext dataContext) => dataContext.eval(contactId);

  factory GetPhoneContactPhotoAction.fromMap(
      {Invokable? initiator, dynamic payload}) {
    if (payload is Map) {
      final contactId = Utils.optionalString(payload['contactId']);
      if (contactId == null) {
        throw LanguageError(
            "${ActionType.getPhoneContactPhoto.name} action requires contactId");
      }

      return GetPhoneContactPhotoAction(
        initiator: initiator,
        id: Utils.optionalString(payload['id']),
        contactId: contactId,
      );
    }

    throw LanguageError(
        "${ActionType.getPhoneContactPhoto.name} action requires payload");
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    GetIt.I<ContactManager>()
        .getContactPhoto(getContactId(scopeManager.dataContext), (imageData) {
      if (id != null) {
        scopeManager.dataContext.addDataContextById(
            id!, PhoneContactPhotoResponse(image: imageData));
        updateContactData(scopeManager, context, id!);
      }
    }, (error) {
      throw RuntimeError('Contact Photo Error: $error');
    });

    return Future.value(null);
  }

  void updateContactData(
      ScopeManager scopeManager, BuildContext context, String id) {
    final contactData = scopeManager.dataContext.getContextById(id);
    scopeManager
        .dispatch(ModelChangeEvent(SimpleBindingSource(id), contactData));
  }
}

class PhoneContactPhotoResponse with Invokable {
  Uint8List? _image;

  PhoneContactPhotoResponse({Uint8List? image}) {
    if (image != null) {
      setImage(image);
    }
  }

  void setImage(Uint8List image) {
    _image = image;
  }

  Uint8List? getImage() {
    return _image;
  }

  @override
  Map<String, Function> getters() {
    return {
      'image': () => _image,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}
