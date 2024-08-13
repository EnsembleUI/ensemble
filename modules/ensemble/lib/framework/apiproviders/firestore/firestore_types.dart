import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'dart:math' show asin, cos, pi, sin, sqrt;

import 'package:ensemble_ts_interpreter/invokables/invokablecommons.dart';
import 'package:flutter/rendering.dart';

mixin WrapsNativeType<T> {
  T unwrap();
}
class FirestoreDocumentReference with Invokable,WrapsNativeType<DocumentReference> {
  final DocumentReference reference;

  FirestoreDocumentReference(this.reference);

  @override
  Map<String, Function> getters() {
    return {
      'path': () => reference.path,
      'id': () => reference.id,
      'parent': () => FirestoreCollectionReference(reference.parent),
    };
  }

  @override
  Map<String, Function> setters() => {};

  @override
  Map<String, Function> methods() {
    return {
      'get': () async => await reference.get(),
      // Additional methods as needed, like delete, set, update
    };
  }

  @override
  DocumentReference unwrap() {
    return reference;
  }
}

class FirestoreQuery with Invokable, WrapsNativeType<Query> {
  final Query query;

  FirestoreQuery(this.query);

  @override
  Map<String, Function> getters() {
    // Define if needed based on your specific use cases.
    return {};
  }

  @override
  Map<String, Function> setters() => {}; // Query does not have direct setters.

  @override
  Map<String, Function> methods() {
    return {
      'where': (List<dynamic> arguments) => FirestoreQuery(query.where(
          arguments[0],
          isEqualTo: arguments.length > 1 ? arguments[1] : null)),
      'orderBy': (List<dynamic> arguments) => FirestoreQuery(query.orderBy(
          arguments[0],
          descending: arguments.length > 1 ? arguments[1] : false)),
      'limit': (List<dynamic> arguments) =>
          FirestoreQuery(query.limit(arguments[0])),
      'limitToLast': (List<dynamic> arguments) =>
          FirestoreQuery(query.limitToLast(arguments[0])),
      'startAt': (List<dynamic> arguments) =>
          FirestoreQuery(query.startAt(arguments)),
      'startAfter': (List<dynamic> arguments) =>
          FirestoreQuery(query.startAfter(arguments)),
      'endBefore': (List<dynamic> arguments) =>
          FirestoreQuery(query.endBefore(arguments)),
      'endAt': (List<dynamic> arguments) =>
          FirestoreQuery(query.endAt(arguments)),
      'snapshots': () => query.snapshots(),
      'get': () async => await query.get(),
    };
  }

  @override
  Query<Object?> unwrap() {
    return query;
  }

}

class FirestoreCollectionReference extends FirestoreQuery {
  FirestoreCollectionReference(CollectionReference collectionReference)
      : super(collectionReference);

  CollectionReference get collection => query as CollectionReference;

  @override
  Map<String, Function> getters() {
    // First, get the base getters from FirestoreQuery
    var base = super.getters();
    // Add or override with CollectionReference specific getters
    base.addAll({
      'id': () => collection.id,
      'parent': () => collection.parent != null
          ? FirestoreDocumentReference(collection.parent!)
          : null,
    });
    return base;
  }

  @override
  Map<String, Function> methods() {
    var methods = super.methods(); // Retrieve methods from FirestoreQuery
    // Add or override with CollectionReference specific methods
    methods.addAll({
      'add': (Map<String, dynamic> data) async => await collection.add(data),
      'doc': (String? documentPath) =>
          FirestoreDocumentReference(collection.doc(documentPath)),
    });
    return methods;
  }
  @override
  CollectionReference unwrap() {
    return collection;
  }
}

class FirestoreGeoPoint with Invokable, WrapsNativeType<GeoPoint> {
  final GeoPoint geoPoint;

  FirestoreGeoPoint(this.geoPoint);

  @override
  Map<String, Function> getters() {
    return {
      'latitude': () => geoPoint.latitude,
      'longitude': () => geoPoint.longitude,
    };
  }

  // As GeoPoint is immutable, we provide an empty map for setters.
  @override
  Map<String, Function> setters() => {};

  // Implementing a simple distanceTo method as an example.
  @override
  Map<String, Function> methods() {
    return {
      'distanceTo': (FirestoreGeoPoint other) {
        const double earthRadiusKm = 6371;
        double dLat =
            _degreesToRadians(other.geoPoint.latitude - geoPoint.latitude);
        double dLon =
            _degreesToRadians(other.geoPoint.longitude - geoPoint.longitude);
        double lat1 = _degreesToRadians(geoPoint.latitude);
        double lat2 = _degreesToRadians(other.geoPoint.latitude);

        double a = sin(dLat / 2) * sin(dLat / 2) +
            sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
        double c = 2 * asin(sqrt(a));
        return earthRadiusKm * c;
      },
    };
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  @override
  GeoPoint unwrap() {
    return geoPoint;
  }
}

class StaticFirestoreTimestamp with Invokable {
  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'fromDate': (Date d) => FirestoreTimestamp.fromDate(d),
      'fromMillis': (int milliseconds) =>
          FirestoreTimestamp(Timestamp.fromMillisecondsSinceEpoch(milliseconds)),
      'fromMicroseconds': (int microseconds) => FirestoreTimestamp(
          Timestamp.fromMicrosecondsSinceEpoch(microseconds)),
      'now': () => FirestoreTimestamp(Timestamp.now()),
      'init': (int seconds, int nanoseconds) =>
          FirestoreTimestamp(Timestamp(seconds, nanoseconds)),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}
class FirestoreTimestamp with Invokable, SupportsPrimitiveOperations, WrapsNativeType<Timestamp> {
  final Timestamp timestamp;

  FirestoreTimestamp(this.timestamp);
  FirestoreTimestamp.fromDate(Date date)
      : timestamp = Timestamp.fromDate(date.dateTime);

  @override
  Map<String, Function> getters() {
    return {
      'seconds': () => timestamp.seconds,
      'nanoseconds': () => timestamp.nanoseconds,
    };
  }

  @override
  Map<String, Function> setters() => {};

  @override
  Map<String, Function> methods() {
    return {
      'toDate': () => Date(timestamp.toDate()),
      'toString': () => timestamp.toDate().toString(),
      'toMillis': () => timestamp.millisecondsSinceEpoch,
      'toMicroseconds': () => timestamp.microsecondsSinceEpoch,
      'valueOf': () => timestamp.toString(),
      'isEqual': (dynamic other) => other is FirestoreTimestamp &&
          timestamp == other.timestamp,
    };
  }

  @override
  String toString() {
    return methods()['toString']!();
  }


  @override
  runOperation(String operator, rhs) {
    if (rhs is FirestoreTimestamp) {
      switch (operator) {
        case '+':
          return FirestoreTimestamp(Timestamp(
              timestamp.seconds + rhs.timestamp.seconds,
              timestamp.nanoseconds + rhs.timestamp.nanoseconds));
        case '-':
          return FirestoreTimestamp(Timestamp(
              timestamp.seconds - rhs.timestamp.seconds,
              timestamp.nanoseconds - rhs.timestamp.nanoseconds));
        default:
          throw Exception('Unsupported operation: $operator');
      }
    }
    throw Exception('Unsupported operation: $operator');
  }

  @override
  Timestamp unwrap() {
    return timestamp;
  }

}
