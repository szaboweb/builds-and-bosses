import 'dart:math';

import 'package:flame/extensions.dart';

import 'arena_map_component.dart';

/// Owns locomotion state, platformer physics, flight, jump impulse and
/// arena platform/ground collision resolution for the player character.
/// Extracted from PlayerComponent per docs/ARCHITECTURE.md.
class PlayerLocomotionController {
  Vector2 velocity = Vector2.zero();

  /// Free vertical movement ("flight"): -1 up, 0 idle, +1 down.
  double verticalFlightInput = 0.0;

  bool isOnGround = true;
  bool isOnMovingPlatform = false;
  double dropThroughTimer = 0.0;
  bool isFacingLeft = false;
  int characterStrength = 10;

  /// Whether the character possesses flight capability or is actively flying.
  bool hasFlight = false;

  /// Whether the character is in a gaseous / intangible form (e.g. Gaseous Form spell).
  /// In this state, the character floats freely through platforms and cannot land on them.
  bool isGaseous = false;

  /// Solid physical obstacles (such as standing enemies or heavy constructs)
  /// that block upward passage unless the character is gaseous.
  List<Rect> solidObstacles = const [];

  /// Rideable surfaces (such as the back of a large beast, mount, or boss)
  /// where characters can land and stand on top instead of sliding off.
  List<Rect> rideableSurfaces = const [];

  /// Whether the player is currently standing on a rideable living entity.
  bool isOnRideableEntity = false;

  /// Kinematic displacement of the living entity being ridden.
  Vector2? rideableDisplacement;

  /// Perform a jump if currently on the ground or a platform.
  bool jump({required double jumpVelocity}) {
    if (isOnGround) {
      velocity.y = jumpVelocity;
      isOnGround = false;
      isOnMovingPlatform = false;
      isOnRideableEntity = false;
      return true;
    }
    return false;
  }

  /// Drop down through a semi-solid platform if not on the main ground floor.
  void dropDown({
    required Vector2 position,
    required Vector2 size,
    ArenaMapComponent? arena,
  }) {
    if (isOnGround && arena != null) {
      if ((position.y + size.y / 2) < arena.groundY - 10) {
        position.y += 8.0;
        isOnGround = false;
        isOnMovingPlatform = false;
        dropThroughTimer = 0.28;
      }
    }
  }

  /// Resets velocities, flight input, and drop-through timer on plan cancel or respawn.
  void reset() {
    velocity.setZero();
    verticalFlightInput = 0.0;
    dropThroughTimer = 0.0;
    isOnMovingPlatform = false;
    isOnRideableEntity = false;
    solidObstacles = const [];
    rideableSurfaces = const [];
    rideableDisplacement = null;
  }

  /// Updates physics timers, integrates velocity/flight into position, and
  /// resolves ground and semi-solid platform landings.
  void updatePhysics({
    required double dt,
    required Vector2 position,
    required Vector2 size,
    required double moveSpeed,
    required double gravity,
    required Rect movementBounds,
    ArenaMapComponent? arena,
  }) {
    if (dropThroughTimer > 0) {
      dropThroughTimer = max(0.0, dropThroughTimer - dt);
    }

    final groundY = arena?.groundY ?? movementBounds.bottom;
    final leftX = arena != null
        ? arena.leftWallX + size.x / 2
        : movementBounds.left + size.x / 2;
    final rightX = arena != null
        ? arena.rightWallX - size.x / 2
        : movementBounds.right - size.x / 2;
    final topY = arena != null ? 20.0 : movementBounds.top + 20.0;

    // Carry standing rider along with the kinematic moving platform or rideable entity
    if (isOnMovingPlatform && arena != null) {
      position.x += arena.movingPlatform.lastDisplacementX;
    } else if (isOnRideableEntity && rideableDisplacement != null) {
      position.x += rideableDisplacement!.x;
      position.y += rideableDisplacement!.y;
    }

    final isFlying = verticalFlightInput != 0;
    if (isFlying) {
      hasFlight = true;
    }
    _applyVelocity(dt, gravity, isFlying);

    if (velocity.x != 0) {
      position.x += velocity.x * moveSpeed * dt;
      isFacingLeft = velocity.x < 0;
    }
    position.x = position.x.clamp(leftX, rightX);

    final prevFeetY = position.y + size.y / 2;
    final prevHeadY = position.y - size.y / 2;
    if (isFlying) {
      position.y += verticalFlightInput * moveSpeed * dt;
      position.y = position.y.clamp(topY, groundY - size.y / 2);
    } else {
      position.y += velocity.y * dt;
    }

    _resolveUpwardObstacleCollisions(
      position: position,
      size: size,
      prevHeadY: prevHeadY,
    );

    _resolveDownwardObstacleDeflection(
      position: position,
      size: size,
      prevFeetY: prevFeetY,
    );

    _resolveLandings(
      position: position,
      size: size,
      prevFeetY: prevFeetY,
      groundY: groundY,
      arena: arena,
      isFlying: isFlying,
    );
  }

  void _resolveUpwardObstacleCollisions({
    required Vector2 position,
    required Vector2 size,
    required double prevHeadY,
  }) {
    if (isGaseous || solidObstacles.isEmpty) return;

    final currentHeadY = position.y - size.y / 2;
    final halfWidth = size.x / 2;

    for (final obstacle in solidObstacles) {
      final overlapsX =
          (position.x + halfWidth > obstacle.left + 2) &&
          (position.x - halfWidth < obstacle.right - 2);
      if (!overlapsX) continue;

      if (prevHeadY >= obstacle.bottom - 12.0 &&
          currentHeadY < obstacle.bottom) {
        position.y = obstacle.bottom + size.y / 2;
        if (velocity.y < 0) {
          velocity.y = 0;
        }
        return;
      }
    }
  }

  void _resolveDownwardObstacleDeflection({
    required Vector2 position,
    required Vector2 size,
    required double prevFeetY,
  }) {
    if (isGaseous || solidObstacles.isEmpty) return;

    final currentFeetY = position.y + size.y / 2;
    final halfWidth = size.x / 2;

    for (final obstacle in solidObstacles) {
      final overlapsX =
          (position.x + halfWidth > obstacle.left + 2) &&
          (position.x - halfWidth < obstacle.right - 2);
      if (!overlapsX) continue;

      if (prevFeetY <= obstacle.top + 12.0 && currentFeetY >= obstacle.top) {
        final obstacleCenterX = (obstacle.left + obstacle.right) / 2;
        if (position.x >= obstacleCenterX) {
          position.x = obstacle.right + halfWidth + 1.0;
        } else {
          position.x = obstacle.left - halfWidth - 1.0;
        }
        return;
      }
    }
  }

  void _applyVelocity(double dt, double gravity, bool isFlying) {
    if (isFlying) {
      velocity.y = 0;
    } else {
      velocity.y += gravity * dt;
      velocity.y = velocity.y.clamp(-650.0, 750.0);
    }
  }

  void _resolveLandings({
    required Vector2 position,
    required Vector2 size,
    required double prevFeetY,
    required double groundY,
    required ArenaMapComponent? arena,
    required bool isFlying,
  }) {
    final currentFeetY = position.y + size.y / 2;
    isOnGround = false;
    isOnMovingPlatform = false;
    isOnRideableEntity = false;

    // 1. Solid ground landing
    if (currentFeetY >= groundY) {
      position.y = groundY - size.y / 2;
      velocity.y = 0;
      if (verticalFlightInput > 0) {
        verticalFlightInput = 0;
      }
      isOnGround = true;
      return;
    }

    // 2. Elevated semi-solid platform & rideable living entity landings
    if (isGaseous ||
        verticalFlightInput < 0 ||
        velocity.y < 0 ||
        dropThroughTimer > 0) {
      return;
    }

    // Check rideable surfaces (mounts / large beasts / boss backs)
    for (final surface in rideableSurfaces) {
      if (_canLandOn(surface, position.x, prevFeetY, currentFeetY)) {
        position.y = surface.top - size.y / 2;
        velocity.y = 0;
        if (verticalFlightInput > 0) {
          verticalFlightInput = 0;
        }
        isOnGround = true;
        isOnRideableEntity = true;
        return;
      }
    }

    if (arena == null) return;

    _resolvePlatformLandings(
      position: position,
      size: size,
      prevFeetY: prevFeetY,
      currentFeetY: currentFeetY,
      arena: arena,
    );
  }

  bool _canLandOn(Rect plat, double x, double prevY, double currentY) {
    if (x < plat.left - 10 || x > plat.right + 10) return false;
    return prevY <= plat.top + 6.0 && currentY >= plat.top;
  }

  void _resolvePlatformLandings({
    required Vector2 position,
    required Vector2 size,
    required double prevFeetY,
    required double currentFeetY,
    required ArenaMapComponent arena,
  }) {
    final movingPlatRect = arena.movingPlatform.toRect();
    for (final plat in arena.platforms) {
      if (!_canLandOn(plat, position.x, prevFeetY, currentFeetY)) continue;

      final isMovingPlat = (plat == movingPlatRect);
      if (isMovingPlat &&
          !arena.movingPlatform.canSupportCharacter(
            characterStrength,
            hasFlight: hasFlight || verticalFlightInput != 0,
          )) {
        continue;
      }
      position.y = plat.top - size.y / 2;
      velocity.y = 0;
      if (verticalFlightInput > 0) {
        verticalFlightInput = 0;
      }
      isOnGround = true;
      isOnMovingPlatform = isMovingPlat;
      return;
    }
  }
}
