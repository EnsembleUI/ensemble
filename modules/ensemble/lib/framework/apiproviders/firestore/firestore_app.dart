import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreApp {
  final FirebaseFirestore firestore;
  FirestoreApp(this.firestore);
  Query getQuery(Map api, {bool isCollectionGroup = false}) {
    String path = api['path'];
    Query collection;
    if (isCollectionGroup) {
      collection = firestore.collectionGroup(path);
    } else {
      collection = firestore.collection(path);
    }
    Query query = collection;

    // Check if queries are provided and apply them
    Map? queryMap = api['query'];
    if (queryMap != null) {
      List? whereMap = queryMap['where'];
      if (whereMap != null) {
        for (var condition in whereMap) {
          final field = condition['field'];
          final operator = condition['operator'];
          final value = condition['value'];
          if (![
            'array-contains',
            'array-contains-any',
            'in',
            'not-in',
            '==',
            '!=',
            '>',
            '>=',
            '<',
            '<=',
            'isNull'
          ].contains(operator)) {
            throw ArgumentError('Unsupported operator: $operator');
          }
          switch (operator) {
            case 'array-contains':
              query = query.where(field, arrayContains: value);
              break;
            case 'array-contains-any':
              query = query.where(field, arrayContainsAny: value);
              break;
            case 'in':
              query = query.where(field, whereIn: value);
              break;
            case 'not-in':
              query = query.where(field, whereNotIn: value);
              break;
            case '==':
              query = query.where(field, isEqualTo: value);
              break;
            case '!=':
              query = query.where(field, isNotEqualTo: value);
              break;
            case '>':
              query = query.where(field, isGreaterThan: value);
              break;
            case '>=':
              query = query.where(field, isGreaterThanOrEqualTo: value);
              break;
            case '<':
              query = query.where(field, isLessThan: value);
              break;
            case '<=':
              query = query.where(field, isLessThanOrEqualTo: value);
              break;
            case 'isNull':
              query = query.where(field, isNull: value);
              break;
            // Add more operators if needed
            default:
              throw ArgumentError('Unsupported operator: $operator');
          }
        }
      }
      // Apply 'orderBy' clauses
      if (queryMap.containsKey('orderBy')) {
        List orderByClauses = queryMap['orderBy'];
        for (var order in orderByClauses) {
          // Check if the orderBy clause is a string or a map
          if (order is String) {
            // If it's a string, orderBy this field in ascending order by default
            query = query.orderBy(order);
          } else if (order is Map) {
            // If it's a map, extract the field and descending flag
            String field = order.keys.first;
            bool descending = order[field]['descending'] ?? false;
            query = query.orderBy(field, descending: descending);
          }
        }
      }
      // Apply limit if present
      if (queryMap.containsKey('limit')) {
        query = query.limit(queryMap['limit']);
      }

      // Apply pagination constraints if present
      if (queryMap.containsKey('startAfter')) {
        query = query.startAfter(queryMap['startAfter']);
      }
      if (queryMap.containsKey('startAt')) {
        query = query.startAt(queryMap['startAt']);
      }
      if (queryMap.containsKey('endBefore')) {
        query = query.endBefore(queryMap['endBefore']);
      }
      if (queryMap.containsKey('endAt')) {
        query = query.endAt(queryMap['endAt']);
      }
      // Apply limitToLast if present
      if (queryMap.containsKey('limitToLast')) {
        query = query.limitToLast(queryMap['limitToLast']);
      }
    }
    return query;
  }

  Future<dynamic> performGetOperation(Map evaluatedApi) async {
    String path = evaluatedApi['path'];
    List<String> pathSegments = path.split('/');
    bool isDocumentPath = pathSegments.length % 2 == 0;
    if (isDocumentPath) {
      // Path points to a document
      DocumentReference docRef = firestore.doc(path);
      DocumentSnapshot docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        print('Document at $path does not exist.');
        return null;
      }
      return docSnapshot;
    }
    Query query = getQuery(evaluatedApi,
        isCollectionGroup: evaluatedApi['isCollectionGroup'] ?? false);
    return await query.get();
  }

  Future<DocumentReference> performAddOperation(Map evaluatedApi) async {
    String path = evaluatedApi['path'];
    Map<String, dynamic> data = evaluatedApi['data'];
    CollectionReference collection = firestore.collection(path);
    return await collection.add(data);
  }

  Future<void> performSetOperation(Map evaluatedApi) async {
    String path = evaluatedApi['path'];
    Map<String, dynamic> data = evaluatedApi['data'];
    DocumentReference docRef = firestore.doc(path);
    return await docRef.set(data);
  }

  Future<void> performUpdateOperation(Map evaluatedApi) async {
    String path = evaluatedApi['path'];
    Map<String, dynamic> data = evaluatedApi['data'];
    DocumentReference docRef = firestore.doc(path);
    return await docRef.update(data);
  }

  Future<void> performDeleteOperation(Map evaluatedApi) async {
    String path = evaluatedApi['path'];
    DocumentReference docRef = firestore.doc(path);
    return await docRef.delete();
  }
}
