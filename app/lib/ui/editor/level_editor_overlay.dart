import 'package:flutter/material.dart';

import '../../core/arena/arena_layout_blueprint.dart';
import '../../game/editor/arena_editor_controller.dart';
import 'level_editor_drawer_widget.dart';

/// Full-screen overlay providing controls, status readouts, and a collapsible
/// palette drawer for editing arena levels in real time.
class LevelEditorOverlay extends StatefulWidget {
  final ArenaEditorController controller;
  final VoidCallback? onPlayTest;
  final VoidCallback? onSave;
  final VoidCallback? onClose;

  const LevelEditorOverlay({
    super.key,
    required this.controller,
    this.onPlayTest,
    this.onSave,
    this.onClose,
  });

  @override
  State<LevelEditorOverlay> createState() => _LevelEditorOverlayState();
}

class _LevelEditorOverlayState extends State<LevelEditorOverlay> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Stack(
          children: [
            // Top Editor Bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _buildTopBar(context),
            ),

            // Bottom Palette Drawer
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: LevelEditorDrawerWidget(controller: widget.controller),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final selected = widget.controller.selectedPlatform;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10131E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF263238), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.architecture, color: Color(0xFFFFD54F), size: 20),
            const SizedBox(width: 8),
            Text(
              widget.controller.blueprint.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            _buildChip('${widget.controller.platformCount} db platform'),
            const SizedBox(width: 12),
            _buildGridToggleButton(),
            const SizedBox(width: 24),
            if (selected != null) ...[
              _buildSelectionCluster(selected),
              const SizedBox(width: 10),
            ],
            _buildPlayActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildGridToggleButton() {
    final active = widget.controller.snapToGrid;
    final color = active ? const Color(0xFF00E5FF) : Colors.white54;
    return OutlinedButton.icon(
      key: const Key('editor_grid_toggle_button'),
      onPressed: () {
        setState(() {
          widget.controller.snapToGrid = !widget.controller.snapToGrid;
        });
      },
      icon: Icon(
        active ? Icons.grid_on : Icons.grid_off,
        size: 16,
        color: color,
      ),
      label: Text(
        active ? 'Rács: 16px' : 'Rács: KI',
        style: TextStyle(fontSize: 11, color: color),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: BorderSide(
          color: active ? color.withValues(alpha: 0.5) : Colors.white24,
        ),
      ),
    );
  }

  Widget _buildPlayActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          key: const Key('editor_play_test_button'),
          onPressed: widget.onPlayTest,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text(
            'PLAY / TESZT',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
        if (widget.onSave != null) ...[
          const SizedBox(width: 8),
          IconButton(
            key: const Key('editor_save_button'),
            tooltip: 'Mentés',
            onPressed: widget.onSave,
            icon: const Icon(Icons.save, color: Color(0xFFFFD54F), size: 20),
          ),
        ],
        if (widget.onClose != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Bezárás',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectionCluster(PlatformBlueprint selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2638),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${selected.width.toInt()}×${selected.height.toInt()}',
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const Key('editor_motion_toggle_button'),
            tooltip: selected.isMoving
                ? 'Mozgás kikapcsolása'
                : 'Mozgás bekapcsolása',
            onPressed: widget.controller.toggleSelectedPlatformMotion,
            icon: Icon(
              Icons.swap_horiz,
              size: 16,
              color: selected.isMoving
                  ? const Color(0xFFFF9100)
                  : Colors.white38,
            ),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            key: const Key('editor_duplicate_button'),
            tooltip: 'Másolás',
            onPressed: widget.controller.duplicateSelectedPlatform,
            icon: const Icon(
              Icons.content_copy,
              size: 16,
              color: Colors.white70,
            ),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            key: const Key('editor_delete_button'),
            tooltip: 'Törlés',
            onPressed: widget.controller.removeSelectedPlatform,
            icon: const Icon(
              Icons.delete_outline,
              size: 16,
              color: Colors.redAccent,
            ),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2638),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}
