
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_rpg/models.dart';
import 'package:ludo_rpg/models/ludo_game_state.dart';
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
    test('Boots of Speed (+4) works via playBoardCard', () {
        gs.phase = TurnPhase.awaitAction;
        gs.dice.a = DieState(3); 
        gs.dice.b = DieState(4);
        gs.cardActionsRemaining = 1;

        // 1. Play Boots -> should set pending pickDieToDouble
        final res = engine.playBoardCard(gs, 'Movement02');
        expect(res.success, true);
        expect(gs.pending != null, true);
        expect(gs.pending!.sourceCardId, 'Movement02');

        // 2. Resolve: pick die A (index 0)
        final resolveRes = engine.resolvePending(gs, {"dieIndex": 0});
        expect(resolveRes.success, true);
        
        // Should add +4 bonus to die A
        expect(gs.dice.a?.bonus, 4);
        expect(gs.dice.b?.value, 4); // Unchanged
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

    test('Double It (Board02) works with pending choice', () {
        gs.phase = TurnPhase.awaitAction;
        gs.dice.a = DieState(3);
        gs.dice.b = DieState(4);
        gs.cardActionsRemaining = 1;

        // 1. Play -> should create pending
        var res = engine.playBoardCard(gs, 'Board02');
        expect(res.success, true);
        expect(gs.pending != null, true);
        expect(gs.pending!.type, PendingType.pickDieToDouble);

        // 2. Resolve: double die A
        final resolveRes = engine.resolvePending(gs, {"dieIndex": 0});
        expect(resolveRes.success, true);
        expect(gs.dice.a?.multiplier, 2);
        expect(gs.dice.a?.doubled, true);
        expect(gs.dice.b?.value, 4); // Unchanged
    });

    test('Double It 2x (Board01) works on both', () {
        gs.phase = TurnPhase.awaitAction;
        gs.dice.a = DieState(3);
        gs.dice.b = DieState(5);
        gs.cardActionsRemaining = 1;

        // Instant effect - no pending
        var res = engine.playBoardCard(gs, 'Board01');
        expect(res.success, true);
        expect(gs.dice.a?.multiplier, 2);
        expect(gs.dice.a?.doubled, true);
        expect(gs.dice.b?.multiplier, 2);
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

    test('Reroll (Single) works via pending', () {
        gs.phase = TurnPhase.awaitAction;
        gs.dice.a = DieState(3);
        gs.dice.b = DieState(4);
        gs.cardActionsRemaining = 1;
        
        // 1. Play -> should create pending
        var res = engine.playBoardCard(gs, 'Board04');
        expect(res.success, true);
        expect(gs.pending != null, true);
        expect(gs.pending!.type, PendingType.pickDieToReroll);
        
        // 2. Resolve: pick die A (index 0)
        final step2 = engine.resolvePending(gs, {"dieIndex": 0});
        expect(step2.success, true);
        expect(gs.pending!.type, PendingType.confirmRerollChoiceSingle);
        
        // 3. Confirm: keep new value
        final step3 = engine.resolvePending(gs, {"keep": "new"});
        expect(step3.success, true);
        expect(gs.pending, null);
    });

    test('Dumpster Dive Flow works', () {
         gs.phase = TurnPhase.awaitAction;
         gs.cardActionsRemaining = 1;
         
         // Setup Discard
         gs.sharedDiscardPile.add("Attack01_123");
         gs.sharedDiscardPile.add("Movement02_456");
         
         // 1. Play via playBoardCard -> should set pending
         final res = engine.playBoardCard(gs, "Board09");
         expect(res.success, true);
         expect(gs.pending != null, true);
         expect(gs.pending!.type, PendingType.dumpsterBrowsePick);
         
         // 2. Resolve pending: pick a card
         final resolveRes = engine.resolvePending(gs, {"cardId": "Attack01_123"});
         expect(resolveRes.success, true);
         
         // 3. Verify Result
         expect(gs.sharedDiscardPile.contains("Attack01_123"), false);
         expect(gs.hands[gs.currentPlayer.color]!.contains("Attack01_123"), true);
         expect(gs.pending, null);
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
