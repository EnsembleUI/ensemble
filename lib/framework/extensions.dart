/// return the Enum based on the input string
/// usage: MyEnum.values.from('name')
extension EnsembleEnum<T extends Enum> on Iterable<T> {
  /// get an Enum based on an input string
  T? from(dynamic name) {
    for (var value in this) {
      if (value.name == name) return value;
    }
    return null;
  }
}
