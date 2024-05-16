abstract class Context {
  void addDataContext(Map<String, dynamic> data);
  void addDataContextById(String id, dynamic value);
  bool hasContext(String id);
  dynamic getContextById(String id);
  Map<String,dynamic> getContextMap();
  void addToThisContext(String id, dynamic value);
}

class SimpleContext implements Context {
  final Map<String, dynamic> _dataContext;

  SimpleContext(Map<String, dynamic> initialData) : _dataContext = initialData;

  @override
  void addDataContext(Map<String, dynamic> data) {
    _dataContext.addAll(data);
  }

  @override
  void addDataContextById(String id, dynamic value) {
    _dataContext[id] = value;
  }

  @override
  bool hasContext(String id) {
    return _dataContext.containsKey(id);
  }

  @override
  dynamic getContextById(String id) {
    return _dataContext[id];
  }

  @override
  Map<String, dynamic> getContextMap() {
    return _dataContext;
  }

  @override
  void addToThisContext(String id, value) {
    _dataContext[id] = value;
  }
}
