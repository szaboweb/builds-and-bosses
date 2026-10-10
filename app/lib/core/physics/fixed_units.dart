/// Fixed-point integer arithmetic in milli-units (1/1000th unit)
/// guaranteeing cross-platform determinism across all physics calculations.
///
/// Unit conversions:
/// - 1 tile = 1000 milli-units (1 tile = 5 feet)
/// - 1 foot = 200 milli-units (5 feet = 1000 milli-units)
class Fixed implements Comparable<Fixed> {
  final int raw;

  const Fixed(this.raw);

  static const Fixed zero = Fixed(0);
  static const Fixed one = Fixed(1000);
  static const Fixed half = Fixed(500);

  factory Fixed.fromInt(int value) => Fixed(value * 1000);

  factory Fixed.fromTiles(int tiles) => Fixed(tiles * 1000);

  factory Fixed.fromFeet(int feet) => Fixed(feet * 200);

  factory Fixed.fromMilli(int milli) => Fixed(milli);

  Fixed add(Fixed other) => Fixed(raw + other.raw);

  Fixed sub(Fixed other) => Fixed(raw - other.raw);

  Fixed negate() => Fixed(-raw);

  /// Fixed-point multiplication with floor division: (raw * other.raw) ~/ 1000.
  Fixed mulFixed(Fixed other) {
    final product = raw * other.raw;
    return Fixed(_floorDiv(product, 1000));
  }

  /// Fixed-point division with floor division: (raw * 1000) ~/ other.raw.
  Fixed divFixed(Fixed other) {
    if (other.raw == 0) {
      throw ArgumentError('Division by zero in Fixed.divFixed');
    }
    final numerator = raw * 1000;
    return Fixed(_floorDiv(numerator, other.raw));
  }

  Fixed mulInt(int factor) => Fixed(raw * factor);

  Fixed divInt(int divisor) {
    if (divisor == 0) {
      throw ArgumentError('Division by zero in Fixed.divInt');
    }
    return Fixed(_floorDiv(raw, divisor));
  }

  Fixed clamp(Fixed min, Fixed max) {
    if (raw < min.raw) return min;
    if (raw > max.raw) return max;
    return this;
  }

  Fixed abs() => Fixed(raw.abs());

  int toIntFloor() => _floorDiv(raw, 1000);

  int toIntRound() => _floorDiv(raw + (raw >= 0 ? 500 : -500), 1000);

  int toFeetFloor() => _floorDiv(raw, 200);

  bool isLessThan(Fixed other) => raw < other.raw;

  bool isLessThanOrEqual(Fixed other) => raw <= other.raw;

  bool isGreaterThan(Fixed other) => raw > other.raw;

  bool isGreaterThanOrEqual(Fixed other) => raw >= other.raw;

  bool hasSameValue(Fixed other) => raw == other.raw;

  @override
  int compareTo(Fixed other) => raw.compareTo(other.raw);

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() {
    final sign = raw < 0 ? '-' : '';
    final absRaw = raw.abs();
    final whole = absRaw ~/ 1000;
    final frac = (absRaw % 1000).toString().padLeft(3, '0');
    return '$sign$whole.$frac';
  }

  static int _floorDiv(int a, int b) {
    if (b < 0) {
      a = -a;
      b = -b;
    }
    return a >= 0 ? a ~/ b : (a - b + 1) ~/ b;
  }
}
