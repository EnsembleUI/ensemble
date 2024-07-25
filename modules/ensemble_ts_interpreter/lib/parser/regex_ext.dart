/// Extension on the RegExp class to add a global flag functionality.
/// The global flag is used to determine if the RegExp should find all matches
/// in the input string (true) or just the first match (false).
extension RegExpExtension on RegExp {
  // Expando is a way to associate additional properties with objects without modifying their classes.
  // Here, it's used to store the global flag for each RegExp instance.
  static final Expando<bool> _globalFlag = Expando<bool>();

  /// Getter for the global flag. Returns true if the global flag is set,
  /// otherwise returns false.
  bool get global => _globalFlag[this] ?? false;

  /// Setter for the global flag. Allows setting the global flag to true or false.
  set global(bool value) {
    _globalFlag[this] = value;
  }
}
