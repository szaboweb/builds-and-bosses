import '../physics/fixed_units.dart';
import 'event_bus.dart';

/// The direction of gravitational acceleration.
enum GravityDirection {
  normal, // +Y towards floor
  inverted, // -Y towards ceiling
  zero, // Floating, zero-G
}

/// Event emitted when an entity enters or exits a gravity inversion zone.
class GravityZoneChangedEvent extends RuleEvent {
  final String entityId;
  final GravityDirection direction;
  final Fixed gravityFactor;

  const GravityZoneChangedEvent({
    required this.entityId,
    required this.direction,
    required this.gravityFactor,
    required super.tick,
  });
}

/// A spatial zone modifying gravitational orientation and magnitude.
class GravityZone {
  final String id;
  final int minXMilli;
  final int minYMilli;
  final int maxXMilli;
  final int maxYMilli;
  final GravityDirection direction;
  final Fixed gravityFactor;

  const GravityZone({
    required this.id,
    required this.minXMilli,
    required this.minYMilli,
    required this.maxXMilli,
    required this.maxYMilli,
    this.direction = GravityDirection.inverted,
    this.gravityFactor = const Fixed(-1000), // -1.0g
  });

  /// Checks whether a given fixed-point point (in milli-units) is inside this zone.
  bool contains(int xMilli, int yMilli) {
    return xMilli >= minXMilli &&
        xMilli <= maxXMilli &&
        yMilli >= minYMilli &&
        yMilli <= maxYMilli;
  }
}

/// Manages active gravity zones and evaluates regional gravitational vectors.
class GravityZoneRegistry {
  final List<GravityZone> _zones = [];

  List<GravityZone> get zones => List.unmodifiable(_zones);

  void registerZone(GravityZone zone) {
    _zones.add(zone);
  }

  void removeZone(String zoneId) {
    _zones.removeWhere((z) => z.id == zoneId);
  }

  /// Evaluates effective gravity direction at position ([xMilli], [yMilli]).
  /// Returns standard normal gravity if not within any active zone.
  GravityDirection directionAt(int xMilli, int yMilli) {
    for (final zone in _zones) {
      if (zone.contains(xMilli, yMilli)) {
        return zone.direction;
      }
    }
    return GravityDirection.normal;
  }

  /// Evaluates effective gravity factor (1000 = 1.0g, -1000 = -1.0g).
  Fixed factorAt(int xMilli, int yMilli) {
    for (final zone in _zones) {
      if (zone.contains(xMilli, yMilli)) {
        return zone.gravityFactor;
      }
    }
    return Fixed.one;
  }
}
