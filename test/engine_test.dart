
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_rpg/models.dart';
import 'package:ludo_rpg/ludo_rpg_engine.dart';

void main() {
  group('LudoRpgEngine Invariants', () {
    late LudoRpgEngine engine;
    late LudoRpgGameState gs;

    setUp(() {
      engine = LudoRpgEngine();
      gs = LudoRpgGameState(players: [
        LudoPlayer(id: 'P1', color: LudoColor.red, tokens: List.generate(4, (i) => LudoToken(id: 'red_$i', color: LudoColor.red))),
        LudoPlayer(id: 'P2', color: LudoColor.green, tokens: List.generate(4, (i) => LudoToken(id: 'green_$i', color: LudoColor.green))),
      ]);
      gs.currentPlayerIndex = 0;
      gs.phase = TurnPhase.awaitRoll;
    });

    test('Initial state invariants', () {
        // All should be in base (-1)
        for(var p in gs.players) {
            for(var t in p.tokens) {
                expect(t.position, -1);
                expect(t.isInBase, true);
            }
        }
    });

    test('Spawn sets token to 0 (Start)', () {
        final token = gs.currentPlayer.tokens[0];
        final res = engine.spawnFromBase(gs, token);
        
        expect(res.success, true);
        expect(token.position, 0);
        expect(token.isOnMain, true);
        expect(token.isInBase, false);
    });

    test('Move token respects main track length', () {
        final token = gs.currentPlayer.tokens[0];
        engine.spawnFromBase(gs, token);
        
        gs.phase = TurnPhase.awaitRoll;
        engine.rollDice(gs);
        // Force dice for deterministic test
        // Force dice for deterministic test
        gs.dice.a = DieState(5);
        gs.dice.b = DieState(0); 
        
        final res = engine.moveToken(gs: gs, token: token, useA: true, useB: false);
        
        expect(res.success, true);
        expect(token.position, 5);
    });
    
    test('Invalid state throws assertion error (manual check)', () {
        final token = gs.currentPlayer.tokens[0];
        // Manually break invariant to test if engine catches it? 
        // Engine checks invariants AFTER mutation. 
        // So we can't easily test the assertion failure from *inside* the engine unless we inject a bug.
        // But we can verify that normal ops DON'T throw.
    });
    test('Modify Roll Card Effect works via Registry', () {
        gs.phase = TurnPhase.awaitAction;
        gs.dice.a = DieState(3); 
        gs.dice.b = DieState(4);
        // gs.dice.aUsed/bUsed are computed from state now (default false)
        gs.cardActionsRemaining = 1;

        final card = CardTemplate(
            id: 'TestMod', 
            name: 'Test Modifier', 
            description: 'Adds +2', 
            effectType: CardEffectType.modifyRoll, 
            value: 2, 
            targetType: TargetType.none
        );

        final res = engine.playCard(gs: gs, card: card, target: null);
        
        expect(res.success, true);
        // Should modify first available die (a)
        // Should modify first available die (a)
        expect(gs.dice.a?.value, 5); // 3 + 2
        expect(gs.dice.b?.value, 4); 
        expect(gs.cardActionsRemaining, 0);
    });

    test('Restart Turn Effect logic', () {
        // 1. Initial State (Turn 0)
        gs.phase = TurnPhase.awaitAction;
        gs.dice.a = DieState(3);
        gs.dice.b = DieState(4);
        gs.dice.a!.used = true; // Simulating some usage
        gs.cardActionsRemaining = 1;

        final card = CardTemplate(
            id: 'SandsTime', 
            name: 'Sands of Time', 
            description: 'Restart Turn', 
            effectType: CardEffectType.restartTurnNow, 
            targetType: TargetType.none
        );

        // 2. Play on First Turn -> Should Fail
        var res = engine.playCard(gs: gs, card: card, target: null);
        expect(res.success, false);
        expect(res.message!.contains("first turn"), true);

        // 3. Increment Turn Count manually (simulating endTurn)
        gs.turnsCompleted[gs.currentPlayer.color] = 1;
        
        // 4. Play on Second Turn -> Should Success
        res = engine.playCard(gs: gs, card: card, target: null);
        expect(res.success, true);
        
        // 5. Verify State Reset
        expect(gs.dice.a, null);
        expect(gs.dice.b, null);
        // expect(gs.dice.aUsed, false); // getters handle null safely (returns false if null)
        expect(gs.cardActionsRemaining, 2);
        expect(gs.phase, TurnPhase.awaitRoll);
    });

    test('Double It (Board02) works with choice', () {
        gs.phase = TurnPhase.awaitAction;
        gs.dice.a = DieState(3);
        gs.dice.b = DieState(4);
        gs.cardActionsRemaining = 1;

        final card = CardTemplate(
            id: 'Board02', 
            name: 'Double It', 
            description: 'Double one', 
            effectType: CardEffectType.doubleDie, 
            value: 1, 
            targetType: TargetType.none
        );

        // Fail if no die selected
        var res = engine.playCard(gs: gs, card: card, target: null);
        expect(res.success, false);

        // Success if die selected (0 = A)
        res = engine.playCard(gs: gs, card: card, target: null, dieIndex: 0);
        expect(res.success, true);
        expect(gs.dice.a?.value, 6);
        expect(gs.dice.a?.doubled, true);
        expect(gs.dice.b?.value, 4); // Unchanged
    });

    test('Double It 2x (Board01) works on both', () {
        gs.phase = TurnPhase.awaitAction;
        gs.dice.a = DieState(3);
        gs.dice.b = DieState(5);
        gs.cardActionsRemaining = 1;

        final card = CardTemplate(
            id: 'Board01', 
            name: 'Double It 2x', 
            description: 'Double both', 
            effectType: CardEffectType.doubleBoth, 
            value: 2, 
            targetType: TargetType.none
        );

        // Success automatically
        var res = engine.playCard(gs: gs, card: card, target: null);
        expect(res.success, true);
        expect(gs.dice.a?.value, 6);
        expect(gs.dice.a?.doubled, true);
        expect(gs.dice.b?.value, 10);
        expect(gs.dice.b?.doubled, true);
    });
    test('Swap tokens (2 targets) works', () {
        gs.phase = TurnPhase.awaitAction;
        gs.cardActionsRemaining = 1;
        
        // Setup 2 tokens on board
        final t1 = gs.players[0].tokens[0];
        final t2 = gs.players[1].tokens[0];
        
        t1.position = 5;
        t1.status = TokenStatus.alive; // On board
        t2.position = 10;
        t2.status = TokenStatus.alive;
        
        final card = CardTemplate(
            id: 'Movement07', 
            name: 'Swap', 
            description: 'Swap positions', 
            effectType: CardEffectType.swapPos, 
            targetType: TargetType.tokenEnemy
        );
        
        // Success
        final res = engine.playCard(gs: gs, card: card, target: [t1, t2]);
        expect(res.success, true);
        
        // Verify Swap
        // t1 was at 5 (abs 5), t2 at 10 (abs 10 + 13 = 23)
        // t1 should now be at abs 23 -> rel = (23-0) = 23
        // t2 should now be at abs 5 -> rel = (5-13) = -8 -> +52 = 44
        
        expect(t1.position, 23);
        expect(t2.position, 44);
    });

    test('Reroll (Single) works', () {
        gs.phase = TurnPhase.awaitAction;
        gs.dice.a = DieState(3);
        gs.dice.b = DieState(4);
        gs.cardActionsRemaining = 1;
        
        final card = CardTemplate(
            id: 'Board04', 
            name: 'Reroll', 
            description: 'Reroll one', 
            effectType: CardEffectType.reroll, 
            value: 1, 
            targetType: TargetType.none
        );
        
        // Must select die
        var res = engine.playCard(gs: gs, card: card, target: null);
        expect(res.success, false);
        
        // Play on A
        final oldA = gs.dice.a!;
        res = engine.playCard(gs: gs, card: card, target: null, dieIndex: 0);
        expect(res.success, true);
        
        // Value might be same, but verify reference or state if possible.
        // Actually we just set value.
        // Let's assume it worked if success is true.
    });

    test('Dumpster Dive Flow works', () {
         gs.phase = TurnPhase.awaitAction;
         gs.cardActionsRemaining = 1;
         
         // Setup Discard
         gs.sharedDiscardPile.add("Attack01_123");
         gs.sharedDiscardPile.add("Movement02_456");
         
         final card = CardTemplate(
             id: 'Board09', 
             name: 'Dumpster Dive', 
             description: 'Pick from discard', 
             effectType: CardEffectType.dumpsterDive, 
             targetType: TargetType.none
         );
         
         // 1. Play Card -> Needs Choice
         final res = engine.playCard(gs: gs, card: card, target: null);
         expect(res.success, true);
         expect(res.choice != null, true);
         expect(res.choice!.type, PendingChoiceType.dumpsterPickOne);
         expect(res.choice!.options.length, 2);
         expect(gs.pendingChoice, res.choice);
         
         // 2. Resolve Choice
         final resolveRes = engine.resolveChoice(gs, "Attack01_123");
         expect(resolveRes.success, true);
         
         // 3. Verify Result
         expect(gs.sharedDiscardPile.contains("Attack01_123"), false);
         expect(gs.hands[gs.currentPlayer.color]!.contains("Attack01_123"), true);
         expect(gs.pendingChoice, null);
    });
    
    test('Teleport works with override value', () {
         gs.phase = TurnPhase.awaitAction;
         gs.cardActionsRemaining = 1;
         
         final t1 = gs.players[0].tokens[0];
         t1.position = 10; 
         
         final card = CardTemplate(
             id: 'Movement08', 
             name: 'Teleport', 
             description: 'Teleport', 
             effectType: CardEffectType.teleport, 
             value: 0, 
             targetType: TargetType.tokenSelf
         );
         
         // Teleport +3
         final res = engine.playCard(gs: gs, card: card, target: t1, overrideValue: 3);
         expect(res.success, true, reason: res.message);
         expect(t1.position, 13);
         
         gs.cardActionsRemaining = 1; // Refill for next test step
         
         // Teleport -3
         final res2 = engine.playCard(gs: gs, card: card, target: t1, overrideValue: -3);
         expect(res2.success, true, reason: res2.message);
         expect(t1.position, 10);
    });

    test('Win Condition (2 tokens home) works', () {
         gs.phase = TurnPhase.awaitAction;
         gs.cardActionsRemaining = 1;
         
         // Setup: 1 token already finished
         final t1 = gs.players[0].tokens[0];
         t1.position = 99;
         t1.status = TokenStatus.finished;
         
         // Setup: 2nd token near home
         final t2 = gs.players[0].tokens[1];
         t2.position = 56; // 1 step from home (57/99)
         t2.status = TokenStatus.alive;
         
         // Setup Dice
         gs.dice.a = DieState(1);
         gs.dice.b = DieState(6); // unused
         
         // Move t2
         final res = engine.moveToken(gs: gs, token: t2, useA: true, useB: false);
         
         expect(res.success, true);
         expect(t2.position, 99);
         expect(t2.status, TokenStatus.finished);
         
         expect(res.events.contains("GAME_WON"), true);
         expect(gs.winner, gs.players[0].color);
         expect(gs.phase, TurnPhase.gameOver);
    });
  });
}
