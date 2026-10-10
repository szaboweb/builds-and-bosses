import 'event_bus.dart';

/// A deterministic status effect applied to an entity.
///
/// Status re-application does NOT stack; instead, it refreshes the duration
/// by resetting [startTick] to the current tick.
class Status {
  final String id;
  final String holderId;
  final String sourceId;
  final int startTick;
  final int durationTicks;
  final Set<String> tags;

  const Status({
    required this.id,
    required this.holderId,
    required this.sourceId,
    required this.startTick,
    required this.durationTicks,
    this.tags = const {},
  });

  /// True if the status has expired at [currentTick].
  /// A duration of 0 or negative is treated as permanent unless removed explicitly.
  bool isExpired(int currentTick) {
    if (durationTicks <= 0) return false;
    return currentTick >= startTick + durationTicks;
  }

  /// Creates a refreshed copy of this status starting at [newStartTick].
  Status refresh(int newStartTick) {
    return Status(
      id: id,
      holderId: holderId,
      sourceId: sourceId,
      startTick: newStartTick,
      durationTicks: durationTicks,
      tags: tags,
    );
  }
}

/// Event emitted when a status expires.
class StatusExpiredEvent extends RuleEvent {
  final Status status;

  const StatusExpiredEvent({required this.status, required super.tick});
}

/// Event emitted when a status is applied or refreshed.
class StatusAppliedEvent extends RuleEvent {
  final Status status;
  final bool isRefreshed;

  const StatusAppliedEvent({
    required this.status,
    required super.tick,
    required this.isRefreshed,
  });
}

/// Tracks active statuses across entities with deterministic tick-based lifecycle.
class StatusTracker {
  /// Internal storage: holderId -> (statusId -> Status)
  final Map<String, Map<String, Status>> _statuses = {};

  /// Applies a [status] at [currentTick].
  ///
  /// If the status already exists on [status.holderId], it does not stack;
  /// its [startTick] is updated to [currentTick].
  StatusAppliedEvent applyStatus(Status status, int currentTick) {
    final holderMap = _statuses.putIfAbsent(status.holderId, () => {});
    final existing = holderMap[status.id];

    if (existing != null) {
      final refreshed = existing.refresh(currentTick);
      holderMap[status.id] = refreshed;
      return StatusAppliedEvent(
        status: refreshed,
        tick: currentTick,
        isRefreshed: true,
      );
    }

    holderMap[status.id] = status;
    return StatusAppliedEvent(
      status: status,
      tick: currentTick,
      isRefreshed: false,
    );
  }

  /// Removes an active status by [statusId] from [holderId].
  Status? removeStatus(String holderId, String statusId) {
    final holderMap = _statuses[holderId];
    if (holderMap == null) return null;
    final removed = holderMap.remove(statusId);
    if (holderMap.isEmpty) {
      _statuses.remove(holderId);
    }
    return removed;
  }

  /// Advances to [currentTick], purging expired statuses and returning expiry events.
  List<StatusExpiredEvent> updateTick(int currentTick) {
    final expiredEvents = <StatusExpiredEvent>[];
    final holdersToRemove = <String>[];

    for (final entry in _statuses.entries) {
      final holderId = entry.key;
      final holderMap = entry.value;
      final expiredIds = <String>[];

      for (final status in holderMap.values) {
        if (status.isExpired(currentTick)) {
          expiredIds.add(status.id);
          expiredEvents.add(
            StatusExpiredEvent(status: status, tick: currentTick),
          );
        }
      }

      for (final id in expiredIds) {
        holderMap.remove(id);
      }

      if (holderMap.isEmpty) {
        holdersToRemove.add(holderId);
      }
    }

    for (final holderId in holdersToRemove) {
      _statuses.remove(holderId);
    }

    return expiredEvents;
  }

  /// Returns all active statuses for [holderId].
  List<Status> activeStatusesFor(String holderId) {
    final holderMap = _statuses[holderId];
    if (holderMap == null) return const [];
    return holderMap.values.toList(growable: false);
  }

  /// Checks if [holderId] currently holds a status containing [tag].
  bool hasTag(String holderId, String tag) {
    final holderMap = _statuses[holderId];
    if (holderMap == null) return false;
    for (final status in holderMap.values) {
      if (status.tags.contains(tag)) return true;
    }
    return false;
  }

  /// Collects all unique active tags for [holderId].
  Set<String> activeTagsFor(String holderId) {
    final holderMap = _statuses[holderId];
    if (holderMap == null) return const {};
    final result = <String>{};
    for (final status in holderMap.values) {
      result.addAll(status.tags);
    }
    return result;
  }
}
