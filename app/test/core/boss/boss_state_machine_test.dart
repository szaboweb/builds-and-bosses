import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/boss/boss_state_machine.dart';

void main() {
  group('BossStateMachine Headless Tests', () {
    late BossStateMachine fsm;

    setUp(() {
      fsm = BossStateMachine(
        initialState: BossState.patrol,
        windupDuration: 0.2,
        attackDuration: 0.1,
        recoveryDuration: 0.15,
      );
    });

    test('Initial state is patrol, facing right, canMove is true', () {
      expect(fsm.state, equals(BossState.patrol));
      expect(fsm.canMove, isTrue);
      expect(fsm.isAttacking, isFalse);
      expect(fsm.isFacingLeft, isFalse);
      expect(fsm.patrolDirection, equals(1.0));
    });

    test('reversePatrol inverts direction and sets facingLeft', () {
      fsm.reversePatrol();
      expect(fsm.patrolDirection, equals(-1.0));
      expect(fsm.isFacingLeft, isTrue);

      fsm.reversePatrol();
      expect(fsm.patrolDirection, equals(1.0));
      expect(fsm.isFacingLeft, isFalse);
    });

    test(
      'Attack sequence progresses: windup -> attack -> recovery -> patrol',
      () {
        expect(fsm.initiateAttack(), isTrue);
        expect(fsm.state, equals(BossState.windup));
        expect(fsm.canMove, isFalse);
        expect(fsm.isAttacking, isTrue);

        // Advance by windupDuration (0.2s)
        fsm.update(0.2);
        expect(fsm.state, equals(BossState.attack));
        expect(fsm.canMove, isFalse);
        expect(fsm.isAttacking, isTrue);

        // Advance by attackDuration (0.1s)
        fsm.update(0.1);
        expect(fsm.state, equals(BossState.recovering));
        expect(fsm.canMove, isFalse);
        expect(fsm.isAttacking, isTrue);

        // Advance by recoveryDuration (0.15s)
        fsm.update(0.15);
        expect(fsm.state, equals(BossState.patrol));
        expect(fsm.canMove, isTrue);
        expect(fsm.isAttacking, isFalse);
      },
    );

    test('Stagger interrupts attack and requires recoverFromStagger', () {
      fsm.initiateAttack();
      expect(fsm.state, equals(BossState.windup));

      fsm.triggerStagger(0.5);
      expect(fsm.state, equals(BossState.stagger));
      expect(fsm.canMove, isFalse);

      fsm.recoverFromStagger();
      expect(fsm.state, equals(BossState.patrol));
      expect(fsm.canMove, isTrue);
    });

    test('Death locks state machine', () {
      fsm.triggerDeath();
      expect(fsm.state, equals(BossState.dead));
      expect(fsm.canMove, isFalse);
      expect(fsm.isAttacking, isFalse);

      fsm.update(1.0);
      expect(fsm.state, equals(BossState.dead));
    });
  });
}
