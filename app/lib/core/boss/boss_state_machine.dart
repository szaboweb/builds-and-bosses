/// Core discrete behavioral states for all Boss entities in Builds & Bosses.
enum BossState {
  /// Standing still or resting between patrol sweeps.
  idle,

  /// Moving horizontally across its patrol path or platform bounds.
  patrol,

  /// Actively moving towards the hero when within aggressive radius.
  chase,

  /// Telegraphing an upcoming melee strike or ranged blast (windup phase).
  windup,

  /// Actively delivering combat impact (active hitbox / projectile spawn).
  attack,

  /// Post-strike recovery / vulnerable cooldown window.
  recovering,

  /// Staggered / stunned by heavy impact or counter-shove.
  stagger,

  /// Boss HP depleted to 0; combat finished.
  dead,
}

/// Headless, deterministic finite state machine governing Boss behavior.
///
/// Cleanly isolates AI state transitions from Flame rendering and physics.
class BossStateMachine {
  BossState _state;
  double _stateTimer = 0.0;
  bool _isFacingLeft = false;
  double _patrolDirection = 1.0;

  // Configurable state durations
  final double windupDuration;
  final double attackDuration;
  final double recoveryDuration;

  BossStateMachine({
    BossState initialState = BossState.patrol,
    this.windupDuration = 0.45,
    this.attackDuration = 0.25,
    this.recoveryDuration = 0.4,
  }) : _state = initialState;

  BossState get state => _state;
  double get stateTimer => _stateTimer;
  bool get isFacingLeft => _isFacingLeft;
  double get patrolDirection => _patrolDirection;

  /// Whether the boss is permitted to move horizontally under current state.
  bool get canMove => _state == BossState.patrol || _state == BossState.chase;

  /// Whether the boss is in an active attacking sequence (windup, attack, or recovery).
  bool get isAttacking =>
      _state == BossState.windup ||
      _state == BossState.attack ||
      _state == BossState.recovering;

  /// Advances state timer and executes deterministic transitions.
  void update(double dt) {
    if (_state == BossState.dead) return;

    _stateTimer += dt;

    switch (_state) {
      case BossState.windup:
        if (_stateTimer >= windupDuration) {
          _transitionTo(BossState.attack);
        }
        break;

      case BossState.attack:
        if (_stateTimer >= attackDuration) {
          _transitionTo(BossState.recovering);
        }
        break;

      case BossState.recovering:
        if (_stateTimer >= recoveryDuration) {
          _transitionTo(BossState.patrol);
        }
        break;

      case BossState.stagger:
        // Stagger timer is externally ticked down or capped
        break;

      case BossState.idle:
      case BossState.patrol:
      case BossState.chase:
      case BossState.dead:
        break;
    }
  }

  /// Reverses horizontal patrol direction and synchronizes facing flag.
  void reversePatrol() {
    _patrolDirection = -_patrolDirection;
    _isFacingLeft = _patrolDirection < 0;
  }

  /// Explicitly sets the facing direction (true = left, false = right).
  void setFacing({required bool faceLeft}) {
    _isFacingLeft = faceLeft;
    _patrolDirection = faceLeft ? -1.0 : 1.0;
  }

  /// Initiates a telegraphing windup for an upcoming attack.
  bool initiateAttack() {
    if (!canMove) return false;
    _transitionTo(BossState.windup);
    return true;
  }

  /// Triggers a stagger state with custom duration (e.g. from heavy knockback).
  void triggerStagger(double duration) {
    if (_state == BossState.dead) return;
    _transitionTo(BossState.stagger);
    _stateTimer = 0.0;
  }

  /// Resumes patrol after a stagger or stun expires.
  void recoverFromStagger() {
    if (_state == BossState.stagger) {
      _transitionTo(BossState.patrol);
    }
  }

  /// Marks the boss as dead.
  void triggerDeath() {
    _transitionTo(BossState.dead);
  }

  void _transitionTo(BossState newState) {
    _state = newState;
    _stateTimer = 0.0;
  }
}
