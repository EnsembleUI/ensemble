import 'dart:typed_data';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class PhoneContactAction extends EnsembleAction {
  PhoneContactAction({
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

  factory PhoneContactAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null) {
      throw LanguageError(
          "${ActionType.getPhoneContacts.name} action requires payload");
    }

    return PhoneContactAction(
      initiator: initiator,
      id: Utils.optionalString(payload['id']),
      onSuccess: EnsembleAction.fromYaml(payload['onSuccess']),
      onError: EnsembleAction.fromYaml(payload['onError']),
    );
  }
}

class PhoneContactPhotoAction extends EnsembleAction {
  PhoneContactPhotoAction({
    super.initiator,
    this.id,
    required this.contactId,
  });

  final String? id;
  final String contactId;

  String getContactId(DataContext dataContext) => dataContext.eval(contactId);

  factory PhoneContactPhotoAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    if (payload == null) {
      throw LanguageError(
          "${ActionType.getPhoneContactPhoto.name} action requires payload");
    }

    final contactId = Utils.optionalString(payload['contactId']);
    if (contactId == null) {
      throw LanguageError(
          "${ActionType.getPhoneContactPhoto.name} action requires contactId");
    }

    return PhoneContactPhotoAction(
      initiator: initiator,
      id: Utils.optionalString(payload['id']),
      contactId: contactId,
    );
  }
}

class PhoneContactPhotoResponse with Invokable {
  Uint8List? _image;

  PhoneContactPhotoResponse({Uint8List? image}) {
    if (image != null) {
      setImage(image);
    }
  }

  setImage(Uint8List image) {
    _image = image;
  }

  Uint8List? getImage() {
    return _image;
  }

  @override
  Map<String, Function> getters() {
    return {
      'image': () => _image,
      'isError': () => '',
      'isLoading': () => false,
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
