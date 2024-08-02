/**
 * Trarverse the given "paths" from "root" and return the value
 */
dynamic getProp(Map? root, List<String> paths) {
  dynamic result = root;
  for (var path in paths) {
    if (result == null) return null;
    result = result[path];
  }
  return result;
}