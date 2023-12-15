library finicityconnectstate;

export 'native/unsupportedfinicityconnectstate.dart'
    if (dart.library.html) 'web/finicityconnectstate.dart'
    if (dart.library.io) 'native/finicityconnectstate.dart';
