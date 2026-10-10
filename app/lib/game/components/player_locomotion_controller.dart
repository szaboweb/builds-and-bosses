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

  /// Perform a jump if currently on the ground or a platform.
  bool jump({required double jumpVelocity}) {
    if (isOnGround) {
      velocity.y = jumpVelocity;
      isOnGround = false;
      isOnMovingPlatform = false;
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

    // Carry standing rider along with the kinematic moving platform
    if (isOnMovingPlatform && arena != null) {
      position.x += arena.movingPlatform.lastDisplacementX;
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
    if (isFlying) {
      position.y += verticalFlightInput * moveSpeed * dt;
      position.y = position.y.clamp(topY, groundY - size.y / 2);
    } else {
      position.y += velocity.y * dt;
    }

    _resolveLandings(
      position: position,
      size: size,
      prevFeetY: prevFeetY,
      groundY: groundY,
      arena: arena,
      isFlying: isFlying,
    );
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

    // 2. Elevated semi-solid platform landings
    // Do not land if gaseous (intangible / phased), flying UPWARD (verticalFlightInput < 0),
    // jumping UPWARD (velocity.y < 0), dropping through, or no arena.
    if (isGaseous ||
        verticalFlightInput < 0 ||
        velocity.y < 0 ||
        dropThroughTimer > 0 ||
        arena == null) {
      return;
    }

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
