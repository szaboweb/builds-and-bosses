import 'package:flutter/material.dart';

/// Reusable gothic/RPG styled stat badge used across HUDs, Overlays and Cards.
/// Provides consistent padding, border styling and typography.
class RpgStatBadgeWidget extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final IconData? icon;
  final double fontSize;

  const RpgStatBadgeWidget({
    super.key,
    required this.label,
    required this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.icon,
    this.fontSize = 10,
  });

  /// Factory for Armor Class (AC) badges.
  factory RpgStatBadgeWidget.ac(int ac) {
    return RpgStatBadgeWidget(
      label: 'AC $ac',
      textColor: const Color(0xFF90CAF9),
      backgroundColor: const Color(0xFF1E293B),
      borderColor: const Color(0xFF475569),
    );
  }

  /// Factory for Action Points (AP / Mana) badges.
  factory RpgStatBadgeWidget.ap(int ap) {
    return RpgStatBadgeWidget(
      label: '$ap AP',
      textColor: const Color(0xFF80DEEA),
      backgroundColor: const Color(0xFF00363A),
      borderColor: const Color(0xFF00E5FF),
    );
  }

  /// Factory for Ability Score badges (e.g. STR, DEX).
  factory RpgStatBadgeWidget.attribute({
    required String name,
    required int score,
    required String extra,
    required Color color,
    Color? backgroundColor,
  }) {
    return RpgStatBadgeWidget(
      label: '$name $score ($extra)',
      textColor: color,
      backgroundColor: backgroundColor ?? color.withValues(alpha: 0.15),
      borderColor: color.withValues(alpha: 0.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? textColor.withValues(alpha: 0.15);
    final border = borderColor ?? textColor.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
