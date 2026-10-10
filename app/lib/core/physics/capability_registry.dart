/// Primary character attributes governing physical capabilities.
enum PrimaryStat {
  strength,
  dexterity,
  constitution,
  intelligence,
  wisdom,
  charisma,
}

/// Physical capabilities governed by exactly one primary stat.
enum Capability {
  jumpHeight,
  pushLimit,
  windResistance,
  groundSpeed,
  flySpeed,
  slideBraking,
  fallResilience,
  flatDamageReduction,
}

/// Registry enforcing the "one capability, one owner stat" rule per PHYSICS_HANDOFF.
class CapabilityRegistry {
  final Map<Capability, PrimaryStat> _capabilityOwners;

  CapabilityRegistry._internal(this._capabilityOwners);

  static final CapabilityRegistry instance = _createDefault();

  static CapabilityRegistry _createDefault() {
    final registry = CapabilityRegistry.custom({});
    registry.register(Capability.jumpHeight, PrimaryStat.strength);
    registry.register(Capability.pushLimit, PrimaryStat.strength);
    registry.register(Capability.windResistance, PrimaryStat.strength);
    registry.register(Capability.groundSpeed, PrimaryStat.dexterity);
    registry.register(Capability.flySpeed, PrimaryStat.dexterity);
    registry.register(Capability.slideBraking, PrimaryStat.dexterity);
    registry.register(Capability.fallResilience, PrimaryStat.dexterity);
    registry.register(Capability.flatDamageReduction, PrimaryStat.constitution);
    return registry;
  }

  factory CapabilityRegistry.custom(Map<Capability, PrimaryStat> initial) {
    return CapabilityRegistry._internal(Map.of(initial));
  }

  /// Registers a capability with its owning primary stat.
  /// Throws a [StateError] if the capability is already registered with a different owner.
  void register(Capability capability, PrimaryStat owner) {
    final existing = _capabilityOwners[capability];
    if (existing != null && existing != owner) {
      throw StateError(
        'Capability $capability already registered to $existing, cannot reassign to $owner',
      );
    }
    _capabilityOwners[capability] = owner;
  }

  /// Returns the single owning stat for [capability].
  PrimaryStat ownerOf(Capability capability) {
    final owner = _capabilityOwners[capability];
    if (owner == null) {
      throw StateError('Capability $capability has no registered owner stat');
    }
    return owner;
  }

  /// Returns all capabilities owned by [stat].
  List<Capability> capabilitiesOf(PrimaryStat stat) {
    return _capabilityOwners.entries
        .where((entry) => entry.value == stat)
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  /// Verifies that every capability in [Capability.values] has exactly one owner stat.
  bool validateCompleteness() {
    for (final cap in Capability.values) {
      if (!_capabilityOwners.containsKey(cap)) return false;
    }
    return true;
  }
}
