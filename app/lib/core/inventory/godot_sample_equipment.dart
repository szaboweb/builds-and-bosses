import 'inventory.dart';
import 'equipment_slot.dart';

const godotSampleEquipmentSets = <EquipmentSet>[
  EquipmentSet(
    id: 'godot-fighter-sample',
    name: 'Godot fighter mintaset',
    role: EquipmentRole.frontline,
    modifiers: {},
    items: [
      EquipmentItem(
        id: 'godot-sample-helmet',
        name: 'Mintasisak',
        role: EquipmentRole.frontline,
        modifiers: {},
        iconAssetPath: 'assets/images/equipment/godot_sample/helmet.png',
        equipmentSlot: EquipmentSlot.head,
        fighterLayerPath: 'equipment/godot_sample/helmet_walk13.png',
      ),
      EquipmentItem(
        id: 'godot-sample-chest',
        name: 'Minta mellvért',
        role: EquipmentRole.frontline,
        modifiers: {},
        iconAssetPath: 'assets/images/equipment/godot_sample/chest.png',
        equipmentSlot: EquipmentSlot.chest,
        fighterLayerPath: 'equipment/godot_sample/chest_walk13.png',
      ),
      EquipmentItem(
        id: 'godot-sample-sword',
        name: 'Mintakard',
        role: EquipmentRole.frontline,
        modifiers: {},
        iconAssetPath: 'assets/images/equipment/godot_sample/sword.png',
        equipmentSlot: EquipmentSlot.mainHand,
        fighterLayerPath: 'equipment/godot_sample/sword_walk13.png',
      ),
    ],
  ),
];
