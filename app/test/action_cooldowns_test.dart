import 'package:flutter_test/flutter_test.dart';
import 'package:flame/extensions.dart';
import 'package:builds_and_bosses_flame/core/actions/action_cooldowns.dart';
import 'package:builds_and_bosses_flame/core/actions/game_action.dart';
import 'package:builds_and_bosses_flame/core/config/game_rules_config.dart';

void main() {
  test('Action cooldown blocks and then releases Slash', () {
    const config = GameRulesConfig(
      cooldowns: CooldownConfig(slashCooldown: 0.8),
    );
    final cooldowns = ActionCooldowns();
    final slash = SlashAction(targetPosition: Vector2.zero());

    expect(cooldowns.canUse(slash), isTrue);
    cooldowns.start(slash, config.cooldowns.slashCooldown);
    expect(cooldowns.canUse(slash), isFalse);

    cooldowns.update(0.79);
    expect(cooldowns.canUse(slash), isFalse);
    cooldowns.update(0.01);
    expect(cooldowns.canUse(slash), isTrue);
  });
}
