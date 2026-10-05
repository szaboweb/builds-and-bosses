import 'package:flutter/material.dart';

/// State and callbacks for an attribute stepper row.
class AttributeStepperState {
  final int score;
  final bool canIncrement;
  final bool canDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const AttributeStepperState({
    required this.score,
    required this.canIncrement,
    required this.canDecrement,
    required this.onIncrement,
    required this.onDecrement,
  });
}

/// Stepper widget for a single D&D ability score with ASI highlight.
class AttributeStepperWidget extends StatelessWidget {
  final String attributeKey;
  final String label;
  final String effectDescription;
  final AttributeStepperState state;

  const AttributeStepperWidget({
    super.key,
    required this.attributeKey,
    required this.label,
    required this.effectDescription,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final mod = ((state.score - 10) / 2).floor();
    final modString = mod >= 0 ? '+$mod' : '$mod';
    final isAsiLevel = state.score > 15;
    final isMax = state.score >= 20;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMax
              ? const Color(0xFFFFD54F)
              : isAsiLevel
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.6)
              : const Color(0xFF312844),
        ),
      ),
      child: Row(
        children: [
          _buildLabelColumn(isAsiLevel, isMax),
          Expanded(
            child: Text(
              effectDescription,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildModifierBadge(mod, modString),
          const SizedBox(width: 8),
          _buildStepperControls(isMax),
        ],
      ),
    );
  }

  Widget _buildLabelColumn(bool isAsiLevel, bool isMax) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isMax ? const Color(0xFFFFD54F) : const Color(0xFFE0E0E0),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            isAsiLevel ? (isMax ? 'MAX (20)' : 'ASI +') : 'Alap',
            style: TextStyle(
              color: isMax
                  ? const Color(0xFFFFD54F)
                  : isAsiLevel
                  ? const Color(0xFFB388FF)
                  : Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModifierBadge(int mod, String modString) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: mod >= 0 ? const Color(0xFF1B2E24) : const Color(0xFF3E1B1B),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        modString,
        style: TextStyle(
          color: mod >= 0 ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildStepperControls(bool isMax) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          color: state.canDecrement ? const Color(0xFFFF8A80) : Colors.white24,
          onPressed: state.canDecrement ? state.onDecrement : null,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        Container(
          width: 32,
          alignment: Alignment.center,
          child: Text(
            '${state.score}',
            style: TextStyle(
              color: isMax ? const Color(0xFFFFD54F) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          color: state.canIncrement ? const Color(0xFF00E5FF) : Colors.white24,
          onPressed: state.canIncrement ? state.onIncrement : null,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}
