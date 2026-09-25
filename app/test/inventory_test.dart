import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/config/game_rules_config.dart';
import 'package:builds_and_bosses_flame/core/inventory/inventory.dart';

void main() {
  test('equipment database supports four class role loadouts', () {
    const config = InventoryConfig(maxArmorySlots: 4);
    final items = [
      const EquipmentItem(
        id: 'frontline',
        name: 'Frontline',
        role: EquipmentRole.frontline,
        modifiers: {},
      ),
      const EquipmentItem(
        id: 'ranged',
        name: 'Ranged',
        role: EquipmentRole.ranged,
        modifiers: {},
      ),
      const EquipmentItem(
        id: 'divine',
        name: 'Divine',
        role: EquipmentRole.divineCaster,
        modifiers: {},
      ),
      const EquipmentItem(
        id: 'arcane',
        name: 'Arcane',
        role: EquipmentRole.arcaneCaster,
        modifiers: {},
      ),
    ];
    var armory = ArmoryState(config: config);
    for (final item in items) {
      armory = armory.equip(
        EquipmentSet(
          id: item.id,
          name: item.name,
          role: item.role,
          items: [item],
          modifiers: {},
        ),
      );
    }
    expect(armory.sets, hasLength(4));
    expect(() => armory.equip(
      const EquipmentSet(
        id: 'overflow',
        name: 'Overflow',
        role: EquipmentRole.frontline,
        items: [],
        modifiers: {},
      ),
    ), throwsStateError);
  });
}