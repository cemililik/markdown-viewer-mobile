/// Coerces a JSON-bridged number into a positive [double].
///
/// The `flutter_inappwebview` bridge sometimes delivers integers as
/// [int] and decimals as [double]; both cases are accepted. Returns
/// `null` for anything that is not a finite positive number.
double? asPositiveDouble(Object? raw) {
  if (raw is num) {
    final value = raw.toDouble();
    if (value > 0 && value.isFinite) {
      return value;
    }
  }
  return null;
}
