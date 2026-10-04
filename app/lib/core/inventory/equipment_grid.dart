import 'inventory.dart';
import 'equipment_slot.dart';

class EquipmentGrid {
  static const int rows = 3;
  static const int columns = 3;
  static const int capacity = rows * columns;

  final List<EquipmentItem?> _slots = List<EquipmentItem?>.filled(
    capacity,
    null,
  );

  EquipmentItem? itemAt(int index) {
    RangeError.checkValidIndex(index, _slots, 'index');
    return _slots[index];
  }

  int get occupiedCount => _slots.whereType<EquipmentItem>().length;

  EquipmentSlot slotAt(int index) {
    RangeError.checkValidIndex(index, _slots, 'index');
    return EquipmentSlot.values[index];
  }

  List<EquipmentItem?> get slots => List.unmodifiable(_slots);

  bool fits(int index, EquipmentItem item) =>
      item.equipmentSlot == slotAt(index);

  void replaceAll(List<EquipmentItem?> slots) {
    if (slots.length != capacity) {
      throw ArgumentError('Expected exactly $capacity equipment slots.');
    }
    for (var i = 0; i < capacity; i++) {
      if (slots[i] != null && !fits(i, slots[i]!)) {
        throw ArgumentError('Equipment does not fit ${slotAt(i).label}.');
      }
    }
    _slots.setAll(0, slots);
  }

  void place(int index, EquipmentItem item) {
    if (!fits(index, item)) {
      throw ArgumentError('Equipment does not fit ${slotAt(index).label}.');
    }
    if (itemAt(index) != null) {
      throw StateError('Equipment slot is occupied');
    }
    _slots[index] = item;
  }

  void move(int source, int destination) {
    final item = itemAt(source);
    final target = itemAt(destination);
    if (item == null) {
      throw StateError('Source equipment slot is empty');
    }
    if (source == destination) return;
    if (!fits(destination, item)) {
      throw ArgumentError(
        'Equipment does not fit ${slotAt(destination).label}.',
      );
    }
    if (target != null) {
      throw StateError('Destination equipment slot is occupied');
    }
    _slots[destination] = item;
    _slots[source] = null;
  }

  EquipmentItem remove(int index) {
    final item = itemAt(index);
    if (item == null) {
      throw StateError('Equipment slot is empty');
    }
    _slots[index] = null;
    return item;
  }
}
