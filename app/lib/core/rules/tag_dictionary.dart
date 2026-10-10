/// Represents a boolean condition evaluated against a set of active tags.
abstract class TagCondition {
  const TagCondition();

  /// Evaluates whether the [activeTags] satisfy this condition.
  bool matches(Set<String> activeTags);

  /// Always matches regardless of active tags.
  const factory TagCondition.always() = _AlwaysCondition;

  /// Matches only if [tags] are all present in active tags (AND).
  const factory TagCondition.requireAll(Set<String> tags) =
      _RequireAllCondition;

  /// Matches if at least one of [tags] is present in active tags (OR).
  const factory TagCondition.requireAny(Set<String> tags) =
      _RequireAnyCondition;

  /// Matches only if none of [tags] are present in active tags (NOT).
  const factory TagCondition.forbidAll(Set<String> tags) = _ForbidAllCondition;

  /// Matches if all [require] tags are present and none of [forbid] tags are present.
  const factory TagCondition.composite({
    Set<String> require,
    Set<String> forbid,
  }) = _CompositeCondition;
}

class _AlwaysCondition extends TagCondition {
  const _AlwaysCondition();

  @override
  bool matches(Set<String> activeTags) => true;
}

class _RequireAllCondition extends TagCondition {
  final Set<String> tags;

  const _RequireAllCondition(this.tags);

  @override
  bool matches(Set<String> activeTags) => activeTags.containsAll(tags);
}

class _RequireAnyCondition extends TagCondition {
  final Set<String> tags;

  const _RequireAnyCondition(this.tags);

  @override
  bool matches(Set<String> activeTags) {
    for (final tag in tags) {
      if (activeTags.contains(tag)) return true;
    }
    return false;
  }
}

class _ForbidAllCondition extends TagCondition {
  final Set<String> tags;

  const _ForbidAllCondition(this.tags);

  @override
  bool matches(Set<String> activeTags) {
    for (final tag in tags) {
      if (activeTags.contains(tag)) return false;
    }
    return true;
  }
}

class _CompositeCondition extends TagCondition {
  final Set<String> require;
  final Set<String> forbid;

  const _CompositeCondition({this.require = const {}, this.forbid = const {}});

  @override
  bool matches(Set<String> activeTags) {
    if (!activeTags.containsAll(require)) return false;
    for (final tag in forbid) {
      if (activeTags.contains(tag)) return false;
    }
    return true;
  }
}

/// Catalog and validator of known game tags.
class TagDictionary {
  final Set<String> _validTags;

  TagDictionary(Set<String> validTags) : _validTags = Set.of(validTags);

  factory TagDictionary.defaultDictionary() => TagDictionary({
    'airborne',
    'spiked',
    'fragile',
    'heavy',
    'flammable',
    'pit',
    'water',
    'falling',
    'speed_boost',
    'safe_fall',
    'magic',
    'bludgeoning',
    'piercing',
  });

  bool isValid(String tag) => _validTags.contains(tag);

  void registerTag(String tag) {
    _validTags.add(tag);
  }

  Set<String> get validTags => Set.unmodifiable(_validTags);
}
