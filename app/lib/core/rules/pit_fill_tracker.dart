import 'event_bus.dart';

/// Event emitted when a pit tile becomes completely filled and turns into a walkable surface.
class PitFilledEvent extends RuleEvent {
  final String pitId;
  final int tileX;
  final int tileY;

  const PitFilledEvent({
    required this.pitId,
    required this.tileX,
    required this.tileY,
    required super.tick,
  });
}

/// A trackable pit cell with a finite volume capacity.
class PitCell {
  final String id;
  final int tileX;
  final int tileY;
  final int capacityMilli;
  int currentFillMilli;

  PitCell({
    required this.id,
    required this.tileX,
    required this.tileY,
    this.capacityMilli = 1000, // 1000 = 1 full tile volume
    this.currentFillMilli = 0,
  });

  bool get isFilled => currentFillMilli >= capacityMilli;

  /// Adds fill volume to the pit. Returns true if this contribution caused the pit to become filled.
  bool addFill(int volumeMilli) {
    if (isFilled) return false;
    currentFillMilli += volumeMilli;
    return isFilled;
  }
}

/// Tracks pit fillings across a dungeon level.
class PitFillTracker {
  final Map<String, PitCell> _pits = {};

  void registerPit(PitCell pit) {
    _pits[pit.id] = pit;
  }

  PitCell? pitAt(int tileX, int tileY) {
    for (final pit in _pits.values) {
      if (pit.tileX == tileX && pit.tileY == tileY) {
        return pit;
      }
    }
    return null;
  }

  /// Deposits an object with [volumeMilli] into pit [pitId].
  /// Emits [PitFilledEvent] if the pit reaches full capacity.
  PitFilledEvent? deposit({
    required String pitId,
    required int volumeMilli,
    required int tick,
  }) {
    final pit = _pits[pitId];
    if (pit == null) return null;

    final justFilled = pit.addFill(volumeMilli);
    if (justFilled) {
      return PitFilledEvent(
        pitId: pit.id,
        tileX: pit.tileX,
        tileY: pit.tileY,
        tick: tick,
      );
    }
    return null;
  }

  /// True if the tile at ([tileX], [tileY]) is an open (unfilled) pit hazard.
  bool isOpenPit(int tileX, int tileY) {
    final pit = pitAt(tileX, tileY);
    if (pit == null) return false;
    return !pit.isFilled;
  }
}
