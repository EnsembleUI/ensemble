import 'package:ensemble/framework/error_handling.dart';

typedef ContactSuccessCallback = void Function(
    List<Map<String, dynamic>> contacts);
typedef ContactErrorCallback = void Function(dynamic);

abstract class ContactManager {
  void getPhoneContacts(
      ContactSuccessCallback onSuccess, ContactErrorCallback onError);
}

class ContactManagerStub extends ContactManager {
  @override
  void getPhoneContacts(
      ContactSuccessCallback onSuccess, ContactErrorCallback onError) {
    throw ConfigError(
        "Phone Contact Service is not enabled. Please review the Ensemble documentation.");
  }
}
