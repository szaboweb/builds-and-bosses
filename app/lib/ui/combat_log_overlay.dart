import 'dart:async';

import 'package:flutter/material.dart';

import '../core/combat/combat_logger.dart';
import '../game/tactical_game.dart';

class CombatLogOverlay extends StatefulWidget {
  final TacticalModeGame game;

  const CombatLogOverlay({super.key, required this.game});

  @override
  State<CombatLogOverlay> createState() => _CombatLogOverlayState();
}

class _CombatLogOverlayState extends State<CombatLogOverlay> {
  Timer? _fadeTimer;
  double _opacity = 0;

  TacticalModeGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    CombatLogger.instance.lastEntryNotifier.addListener(_onNewEntry);
  }

  void _onNewEntry() {
    if (!mounted) return;
    _fadeTimer?.cancel();
    setState(() => _opacity = 1);
    _fadeTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _opacity = 0);
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    CombatLogger.instance.lastEntryNotifier.removeListener(_onNewEntry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 88,
      width: 460,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 1500),
        child: IgnorePointer(
          ignoring: _opacity == 0,
          child: Material(
            color: Colors.transparent,
            child: Container(
            height: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10131E).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.7),
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 16),
              ],
            ),
            child: ValueListenableBuilder<CombatLogEntry?>(
              valueListenable: CombatLogger.instance.lastEntryNotifier,
              builder: (context, lastEntry, _) {
                final entries = CombatLogger.instance.history
                    .where((entry) => entry.level == LogLevel.combat)
                    .toList()
                    .reversed
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.menu_book,
                          color: Color(0xFFFFD54F),
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'COMBAT LOG',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: entries.isEmpty
                          ? const Text(
                              'No combat rolls yet.',
                              style: TextStyle(color: Colors.white54),
                            )
                          : ListView.builder(
                              reverse: false,
                              itemCount: entries.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  entries[index].message,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
            ),
          ),
        ),
      ),
    );
  }
}
