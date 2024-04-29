import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'dart:math' show asin, cos, pi, sin, sqrt;

import 'package:ensemble_ts_interpreter/invokables/invokablecommons.dart';

class FirestoreDocumentReference with Invokable {
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
}

class FirestoreQuery with Invokable {
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
}

class FirestoreGeoPoint with Invokable {
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
}

class FirestoreTimestamp with Invokable {
  final Timestamp timestamp;

  FirestoreTimestamp(this.timestamp);

  @override
  Map<String, Function> getters() {
    return {
      'seconds': () => timestamp.seconds,
      'nanoseconds': () => timestamp.nanoseconds,
      'toDate': () => Date(timestamp.toDate()),
    };
  }

  @override
  Map<String, Function> setters() => {};

  @override
  Map<String, Function> methods() {
    return {
      'toDate': () => Date(timestamp.toDate()),
    };
  }
}
