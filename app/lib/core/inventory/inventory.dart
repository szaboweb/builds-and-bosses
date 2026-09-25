import '../config/game_rules_config.dart';

enum EquipmentRole { frontline, ranged, divineCaster, arcaneCaster }

class EquipmentItem {
  final String id;
  final String name;
  final EquipmentRole role;
  final Map<String, double> modifiers;

  const EquipmentItem({
    required this.id,
    required this.name,
    required this.role,
    required this.modifiers,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    return EquipmentItem(
      id: json['id'] as String,
      name: json['name'] as String,
      role: EquipmentRole.values.byName(json['role'] as String),
      modifiers: (json['modifiers'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }
}

class EquipmentSet {
  final String id;
  final String name;
  final EquipmentRole role;
  final List<EquipmentItem> items;
  final Map<String, double> modifiers;

  const EquipmentSet({
    required this.id,
    required this.name,
    required this.role,
    required this.items,
    required this.modifiers,
  });

  factory EquipmentSet.fromJson(
    Map<String, dynamic> json,
    Map<String, EquipmentItem> itemDatabase,
  ) {
    final itemIds = (json['item_ids'] as List<dynamic>).cast<String>();
    return EquipmentSet(
      id: json['id'] as String,
      name: json['name'] as String,
      role: EquipmentRole.values.byName(json['role'] as String),
      items: itemIds.map((id) => itemDatabase[id]!).toList(),
      modifiers: (json['modifiers'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }
}

class InventoryState {
  final InventoryConfig config;
  final List<EquipmentItem> items;

  InventoryState({required this.config, List<EquipmentItem>? items})
    : items = List.unmodifiable(items ?? []);

  bool canAdd(EquipmentItem item) => items.length < config.maxInventorySlots;

  InventoryState add(EquipmentItem item) {
    if (!canAdd(item)) throw StateError('Inventory capacity reached');
    return InventoryState(config: config, items: [...items, item]);
  }
}

class ArmoryState {
  final InventoryConfig config;
  final List<EquipmentSet> sets;

  ArmoryState({required this.config, List<EquipmentSet>? sets})
    : sets = List.unmodifiable(sets ?? []);

  bool canEquip(EquipmentSet set) => sets.length < config.maxArmorySlots;

  ArmoryState equip(EquipmentSet set) {
    if (!canEquip(set)) throw StateError('Armory capacity reached');
    return ArmoryState(config: config, sets: [...sets, set]);
  }
}

class EquipmentDatabase {
  final List<EquipmentItem> items;
  final List<EquipmentSet> sets;

  EquipmentDatabase({required this.items, required this.sets});

  factory EquipmentDatabase.fromJson(
    Map<String, dynamic> json, {
    InventoryConfig config = const InventoryConfig(),
  }) {
    final itemList = (json['items'] as List<dynamic>)
        .map((item) => EquipmentItem.fromJson(item as Map<String, dynamic>))
        .toList();
    final itemMap = {for (final item in itemList) item.id: item};
    final setList = (json['sets'] as List<dynamic>)
        .map(
          (set) => EquipmentSet.fromJson(
            set as Map<String, dynamic>,
            itemMap,
          ),
        )
        .where((set) => set.items.length <= config.maxItemsPerEquipmentSet)
        .toList();
    return EquipmentDatabase(items: itemList, sets: setList);
  }

  List<EquipmentSet> setsFor(EquipmentRole role) =>
      sets.where((set) => set.role == role).toList();
}