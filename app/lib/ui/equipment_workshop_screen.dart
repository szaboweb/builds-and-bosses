import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/inventory/equipment_grid.dart';
import '../core/inventory/godot_sample_equipment.dart';
import '../core/inventory/inventory.dart';
import '../core/combat/combat_logger.dart';

class _EquipmentDrag {
  final EquipmentItem item;
  final int? source;

  const _EquipmentDrag(this.item, {this.source});
}

class EquipmentWorkshopScreen extends StatefulWidget {
  final EquipmentGrid grid;
  final List<EquipmentSet> sets;
  final Future<void> Function(List<EquipmentItem>)? onEquipmentChanged;
  final VoidCallback? onCancelEquipmentUpdate;
  final Duration operationTimeout;

  const EquipmentWorkshopScreen({
    super.key,
    required this.grid,
    this.sets = godotSampleEquipmentSets,
    this.onEquipmentChanged,
    this.onCancelEquipmentUpdate,
    this.operationTimeout = const Duration(seconds: 12),
  });

  @override
  State<EquipmentWorkshopScreen> createState() =>
      _EquipmentWorkshopScreenState();
}

class _EquipmentWorkshopScreenState extends State<EquipmentWorkshopScreen> {
  int? _selected;
  bool _updating = false;
  int _setIndex = 0;
  EquipmentItem? _armorySelection;
  int _operation = 0;

  @override
  void dispose() {
    _operation++;
    widget.onCancelEquipmentUpdate?.call();
    super.dispose();
  }

  void _validateSets() {
    for (final set in widget.sets) {
      if (set.items.length > EquipmentGrid.capacity) {
        throw ArgumentError(
          'Armory set ${set.id} exceeds the 9-slot capacity.',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _validateSets();
  }

  @override
  void didUpdateWidget(covariant EquipmentWorkshopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sets != widget.sets) {
      _validateSets();
      _setIndex = 0;
      _armorySelection = null;
    }
    if (oldWidget.grid != widget.grid) {
      _selected = null;
    }
  }

  void _changeSet(int delta) {
    if (_updating || widget.sets.length < 2) return;
    setState(() {
      _setIndex = (_setIndex + delta) % widget.sets.length;
      _armorySelection = null;
    });
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _occupiedError() {
    _notify('Ez a felszereléshely már foglalt.');
  }

  bool _canDrop(_EquipmentDrag drag, int index) {
    if (_updating) return false;
    if (!widget.grid.fits(index, drag.item)) {
      _notify(
        '${drag.item.name} csak a(z) '
        '${drag.item.equipmentSlot?.label ?? 'ismeretlen'} helyre illik, '
        'nem ide: ${widget.grid.slotAt(index).label}.',
      );
      return false;
    }
    if (widget.grid.itemAt(index) != null && drag.source != index) {
      _occupiedError();
      return false;
    }
    return true;
  }

  Future<void> _apply(List<EquipmentItem?> next, int index) async {
    final operation = ++_operation;
    setState(() => _updating = true);
    try {
      await (widget.onEquipmentChanged?.call(
                next.whereType<EquipmentItem>().toList(),
              ) ??
              Future<void>.value())
          .timeout(widget.operationTimeout);
      if (!mounted || operation != _operation) return;
      widget.grid.replaceAll(next);
      if (!mounted) return;
      setState(() {
        _selected = index;
        _armorySelection = null;
      });
    } on TimeoutException catch (error) {
      widget.onCancelEquipmentUpdate?.call();
      _operation++;
      _applyError(error);
    } on StateError catch (error) {
      _applyError(error);
    } on ArgumentError catch (error) {
      _applyError(error);
    } on FlutterError catch (error) {
      _applyError(error);
    } on Exception catch (error) {
      _applyError(error);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _applyError(Object error) {
    CombatLogger.instance.logWarning(
      'EQUIPMENT',
      'Unable to apply equipment: $error',
    );
    if (mounted) _notify('A felszerelés nem alkalmazható: $error');
  }

  void _drop(_EquipmentDrag drag, int index) {
    if (!_canDrop(drag, index)) return;
    if (drag.source == index) return;
    final next = widget.grid.slots.toList();
    if (drag.source != null) next[drag.source!] = null;
    next[index] = drag.item;
    unawaited(_apply(next, index));
  }

  Widget _itemVisual(EquipmentItem item) {
    final path = item.iconAssetPath;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (path != null)
          Image.asset(
            path,
            width: 56,
            height: 56,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          )
        else
          const Icon(Icons.inventory_2_outlined),
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _draggable(_EquipmentDrag drag, Widget child) {
    return Draggable<_EquipmentDrag>(
      data: drag,
      feedback: Material(
        color: const Color(0xFF174957),
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(width: 96, height: 96, child: _itemVisual(drag.item)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }

  Widget _armory() {
    final sets = widget.sets;
    final current = sets.isEmpty ? null : sets[_setIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('armory-previous'),
              tooltip: 'Előző set',
              onPressed: sets.length > 1 ? () => _changeSet(-1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                'Armory • ${sets.isEmpty ? 0 : _setIndex + 1}/${sets.length}',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              key: const ValueKey('armory-next'),
              tooltip: 'Következő set',
              onPressed: sets.length > 1 ? () => _changeSet(1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Text(
          current?.name ?? 'Nincs felszerelésset',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        GridView.builder(
          key: const ValueKey('armory-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: EquipmentGrid.capacity,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: EquipmentGrid.columns,
            mainAxisExtent: 96,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final items = current?.items ?? const <EquipmentItem>[];
            final item = index < items.length ? items[index] : null;
            final tile = Material(
              color: item != null && _armorySelection == item
                  ? const Color(0xFF174957)
                  : const Color(0xFF1B1727),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Colors.white24),
              ),
              child: item == null
                  ? const Center(child: Text('—'))
                  : InkWell(
                      key: ValueKey('armory-item-${item.id}'),
                      onTap: () => setState(() {
                        _armorySelection = item;
                      }),
                      child: Semantics(
                        label: 'Armory: ${item.name}',
                        child: _itemVisual(item),
                      ),
                    ),
            );
            return item == null ? tile : _draggable(_EquipmentDrag(item), tile);
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Húzd át a mintát a hozzá illő üres felszereléshelyre. '
          'Kattintással is választhatsz, majd kattints a célhelyre. '
          'Az armory mintái megmaradnak, nem fogyó tárgykészlet.',
        ),
      ],
    );
  }

  void _select(int index) {
    final armoryItem = _armorySelection;
    if (armoryItem != null) {
      _drop(_EquipmentDrag(armoryItem), index);
      return;
    }
    setState(() {
      _selected = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final item = selected == null ? null : widget.grid.itemAt(selected);
    return Scaffold(
      appBar: AppBar(title: const Text('Felszerelés workshop')),
      body: AbsorbPointer(
        absorbing: _updating,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _changeSet(-1),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _changeSet(1),
          },
          child: Focus(
            autofocus: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '3 × 3 felszereléshely • ${widget.grid.occupiedCount}/'
                        '${EquipmentGrid.capacity} foglalt',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A Godot-próba felszereléseit az armory-ból behúzhatod '
                        'a megfelelő testrész helyére: a felszerelés a '
                        'játékbeli fighteren is megjelenik. '
                        'Set-váltás: a nyílgombokkal vagy a billentyűzet ← / → '
                        'gombjaival. Ez a felület nem generál képeket.',
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: constraints.maxWidth
                                .clamp(660, 1000)
                                .toDouble(),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(
                                        height: 76,
                                        child: Center(
                                          child: Text('Workshop • 3 × 3'),
                                        ),
                                      ),
                                      GridView.builder(
                                        key: const ValueKey('workshop-grid'),
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: EquipmentGrid.capacity,
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount:
                                                  EquipmentGrid.columns,
                                              mainAxisExtent: 96,
                                              crossAxisSpacing: 4,
                                              mainAxisSpacing: 4,
                                            ),
                                        itemBuilder: (context, index) {
                                          final equipment = widget.grid.itemAt(
                                            index,
                                          );
                                          final row =
                                              index ~/ EquipmentGrid.columns +
                                              1;
                                          final column =
                                              index % EquipmentGrid.columns + 1;
                                          final label =
                                              'Felszereléshely $row, $column: '
                                              '${widget.grid.slotAt(index).label} • '
                                              '${equipment?.name ?? 'üres'}';
                                          return DragTarget<_EquipmentDrag>(
                                            onWillAcceptWithDetails: (
                                              details,
                                            ) => _canDrop(details.data, index),
                                            onAcceptWithDetails: (details) =>
                                                _drop(details.data, index),
                                            builder: (context, candidates, rejected) {
                                              final tile = Semantics(
                                                label: label,
                                                button: true,
                                                selected: selected == index,
                                                child: Tooltip(
                                                  message: label,
                                                  child: Material(
                                                    color:
                                                        selected == index ||
                                                            candidates
                                                                .isNotEmpty
                                                        ? const Color(
                                                            0xFF174957,
                                                          )
                                                        : const Color(
                                                            0xFF1B1727,
                                                          ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      side: BorderSide(
                                                        color: selected == index
                                                            ? const Color(
                                                                0xFF00E5FF,
                                                              )
                                                            : Colors.white24,
                                                      ),
                                                    ),
                                                    child: InkWell(
                                                      key: ValueKey(
                                                        'equipment-slot-$index',
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      onTap: () =>
                                                          _select(index),
                                                      child: Center(
                                                        child: equipment == null
                                                            ? Text(
                                                                widget.grid
                                                                    .slotAt(
                                                                      index,
                                                                    )
                                                                    .label,
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white38,
                                                                  fontSize: 11,
                                                                ),
                                                              )
                                                            : _itemVisual(
                                                                equipment,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                              return equipment == null
                                                  ? tile
                                                  : _draggable(
                                                      _EquipmentDrag(
                                                        equipment,
                                                        source: index,
                                                      ),
                                                      tile,
                                                    );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(child: _armory()),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_armorySelection != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_armorySelection!.name}: válassz üres célhelyet.',
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _armorySelection = null),
                              child: const Text('Kijelölés törlése'),
                            ),
                          ],
                        ),
                      if (selected == null)
                        const Text('Válassz egy felszereléshelyet.')
                      else ...[
                        Text(
                          '${widget.grid.slotAt(selected).label}: ${item?.name ?? 'üres'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (item != null) ...[
                          Text('Azonosító: ${item.id}'),
                          for (final modifier in item.modifiers.entries)
                            Text('${modifier.key}: ${modifier.value}'),
                          Wrap(
                            spacing: 12,
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  final next = widget.grid.slots.toList();
                                  next[selected] = null;
                                  unawaited(_apply(next, selected));
                                },
                                child: const Text('Felszerelés levétele'),
                              ),
                            ],
                          ),
                        ],
                      ],
                      if (_updating) const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text(
                        'A rács a jelenlegi játékmenetben megmarad a workshop '
                        'bezárásakor. Lemezre mentés még nincs.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
