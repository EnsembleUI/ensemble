/// Same as [num.clamp] but optimized for non-null [double].
///
/// This is faster because it avoids polymorphism, boxing, and special cases for
/// floating point numbers.
//
part of 'ensemble_dropdown.dart';
double _clampDouble(double x, double min, double max) {
  assert(min <= max && !max.isNaN && !min.isNaN);
  if (x < min) {
    return min;
  }
  if (x > max) {
    return max;
  }
  if (x.isNaN) {
    return max;
  }
  return x;
}
