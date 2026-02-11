import 'dart:math';
import 'dart:math';
import 'models.dart';
import 'effects/effect_registry.dart';
import 'effects/effect_types.dart';

// TurnPhase, DicePair, LudoRpgGameState moved to models/ludo_game_state.dart

class EngineResult {
  final bool success;
  final String? message;
  final List<String> events;
  final PendingChoice? choice;

  const EngineResult({required this.success, this.message, this.events = const [], this.choice});

  factory EngineResult.ok({List<String> events = const [], PendingChoice? choice}) => 
      EngineResult(success: true, events: events, choice: choice);
  
  factory EngineResult.fail(String message) => 
      EngineResult(success: false, message: message);
}



class LudoRpgEngine implements LudoRpgEngineApi {
  @override
  int get mainTrackLen => 52;
  static const int homeStart = 52;
  static const int homeEnd = 57;
  static const int goal = 99;

  final Random _rng;

  /// Star safe zones: ONLY the 4 start stars (one per color), per your rule.
  /// These are defined on the *absolute* main-track indices.
  static const Map<LudoColor, int> _startOffsetAbs = {
    LudoColor.red: 0,
    LudoColor.green: 13,
    LudoColor.yellow: 26,
    LudoColor.blue: 39,
  };

  LudoRpgEngine({Random? rng}) : _rng = rng ?? Random();

  // ---------- Dice ----------
  void rollDice(LudoRpgGameState gs) {
    if (gs.phase != TurnPhase.awaitRoll) return;

    gs.dice.a = DieState(_rng.nextInt(6) + 1);
    gs.dice.b = DieState(_rng.nextInt(6) + 1);

    gs.cardActionsRemaining = 2;
    gs.phase = TurnPhase.awaitAction;
  }

  // ---------- Safe tiles (stars) ----------
  bool isStarSafeAbsolute(int absMainIndex) {
    return _startOffsetAbs.values.contains(absMainIndex % mainTrackLen);
  }

  /// Convert a token's RELATIVE main position (0..51) into ABSOLUTE main index (0..51)
  int toAbsoluteMainIndexFromRelative(LudoToken t) {
    if (t.position < 0 || t.position >= mainTrackLen) {
        // Can happen if token is in Base or Home Stretch calling this.
        // But logic should prevent that.
        // Return 0 or handle error? For now, standard logic:
        return 0; 
    }
    final offset = _startOffsetAbs[t.color]!;
    final rel = t.position; // must be 0..51
    return (rel + offset) % mainTrackLen;
  }

  // ---------- Actions ----------
  /// Spawn: Move token from base (-1) to start (0).
  /// Voluntary/Free action. Does NOT consume dice.
  EngineResult spawnFromBase(LudoRpgGameState gs, LudoToken token) {
    // Allowed in awaitRoll OR awaitAction (as long as turn not ended)
    if (gs.phase == TurnPhase.ended) return EngineResult.fail("Turn ended");
    
    if (token.color != gs.currentPlayer.color) return EngineResult.fail("Not your token");
    if (token.isDead || token.isFinished) return EngineResult.fail("Token ineligible");
    if (!token.isInBase) return EngineResult.fail("Token not in base");

    // No dice requirement.
    
    token.position = 0; // start star (safe)
    
    _checkInvariants(gs);
    return EngineResult.ok(events: ["SPAWN", "TOKEN_MOVED"]);
  }

  /// Spend dice on movement:
  /// - useA: consume die A
  /// - useB: consume die B
  /// - allowCombined: if both selected, movement = a+b
  EngineResult moveToken({
    required LudoRpgGameState gs,
    required LudoToken token,
    required bool useA,
    required bool useB,
  }) {
    if (gs.phase != TurnPhase.awaitAction) return EngineResult.fail("Not in action phase");
    if (token.color != gs.currentPlayer.color) return EngineResult.fail("Not your token");
    if (token.isDead || token.isFinished) return EngineResult.fail("Token dead/finished");
    if (!gs.dice.rolled) return EngineResult.fail("Dice not rolled");

    // Validate dice availability - checking usage via DieState
    if (useA) {
        if (gs.dice.a == null || gs.dice.a!.used) return EngineResult.fail("Die A unavailable");
    }
    if (useB) {
        if (gs.dice.b == null || gs.dice.b!.used) return EngineResult.fail("Die B unavailable");
    }
    if (!useA && !useB) return EngineResult.fail("No dice selected");

    final steps = (useA ? gs.dice.a!.value : 0) + (useB ? gs.dice.b!.value : 0);

    // Can't move from base via moveToken (spawn is a separate free action)
    if (token.isInBase) return EngineResult.fail("Cannot move from base (Use Spawn)");

    // ... logic for next steps calculation ...
    // Calculate candidate position first
    int finalRelPos = -1;
    bool entersHomeStretch = false;

    if (token.isInHomeStretch) {
      final next = token.position + steps;
      if (next > homeEnd) return EngineResult.fail("Overshoots home");
      finalRelPos = next;
    } else if (token.isOnMain) {
      final nextRel = token.position + steps;
       if (nextRel >= homeStart) {
        final homePos = homeStart + (nextRel - homeStart);
        if (homePos > homeEnd) return EngineResult.fail("Overshoots home");
        finalRelPos = homePos;
        entersHomeStretch = true;
      } else {
        finalRelPos = nextRel % mainTrackLen;
      }
    } else {
      return EngineResult.fail("Invalid position");
    }
    
    // Check Collisions
    List<String> events = ["TOKEN_MOVED"];
    
    if (finalRelPos < homeStart) {
        // Calculate my absolute target
        final myAbs = (finalRelPos + _startOffsetAbs[token.color]!) % mainTrackLen;
        
        for (var p in gs.players) {
            if (p.color == token.color) continue; // Skip self
            
            for (var t in p.tokens) {
                if (t.isDead || t.isFinished || t.isInBase || t.isInHomeStretch) continue;
                
                // Compare absolute positions
                final tAbs = toAbsoluteMainIndexFromRelative(t);
                if (tAbs == myAbs) {
                    // Collision!
                    if (isTokenSafeFromAttack(t)) {
                        // Safe: stack
                    } else {
                        // Kill!
                        t.status = TokenStatus.dead;
                        t.position = -1; 
                        events.add("TOKEN_KILLED");
                    }
                }
            }
        }
    }

    // Apply Move
    token.position = finalRelPos;
    if (token.position == homeEnd) { // Check both 57 and goal
       token.position = goal;
       token.status = TokenStatus.finished;
       events.add("TOKEN_FINISHED");
    } else if (token.position == goal) {
       token.status = TokenStatus.finished;
       events.add("TOKEN_FINISHED");
    }

    // Mark dice used
    // Mark dice used (Atomic spend)
    if (useA) {
        gs.dice.a!.used = true;
        // Reset doubled state on spend
        gs.dice.a!.doubled = false;
        gs.dice.a!.multiplier = 1;
    }
    if (useB) {
        gs.dice.b!.used = true;
        gs.dice.b!.doubled = false;
        gs.dice.b!.multiplier = 1;
    }
    
    _checkInvariants(gs);
    
    // Check Win Condition
    if (_checkWinCondition(gs, token.color)) {
        events.add("GAME_WON");
    }
    
    return EngineResult.ok(events: events);
  }

  // --- API Implementation ---
  @override
  int rollD6() => _rng.nextInt(6) + 1;

  // ---------- Card System ----------

  /// Resets the game state completely.
  void resetGame(LudoRpgGameState gs) {
      gs.phase = TurnPhase.awaitRoll;
      gs.currentPlayerIndex = 0;
      gs.winner = null;
      gs.cardActionsRemaining = 2;
      gs.dice.reset();
      
      // Reset players
      for (var p in gs.players) {
          p.tokens.forEach((t) {
              t.position = -1;
              t.status = TokenStatus.alive;
              t.effects.clear();
          });
          p.effects.clear();
          gs.turnsCompleted[p.color] = 0;
      }
      
      initializeGame(gs);
  }

  /// Initializes the game with a full deck and deals initial hands.
  void initializeGame(LudoRpgGameState gs) {
    // 1. Generate Deck
    gs.sharedDrawPile.clear();
    gs.sharedDiscardPile.clear();
    
    // For now, let's say 2 copies of each card in library? 
    // Or just 1 as per current logic.
    // Let's go with 2 copies for a healthier deck size (approx 70 cards).
    for (var template in CardLibrary.allCards) {
      // 2 copies
      gs.sharedDrawPile.add("${template.id}_${_rng.nextInt(100000)}");
      gs.sharedDrawPile.add("${template.id}_${_rng.nextInt(100000)}");
    }
    
    gs.sharedDrawPile.shuffle(_rng);
    
    // 2. Deal Hands
    // Round-robin deal
    const int initialHandSize = 5;
    for (int i = 0; i < initialHandSize; i++) {
        for (var p in gs.players) {
            final cardId = _drawCardInternal(gs);
            if (cardId != null) {
                gs.hands[p.color]?.add(cardId);
            }
        }
    }
  }

  /// Internal helper to draw a card ID.
  /// Handles reshuffling discard if draw is empty.
  String? _drawCardInternal(LudoRpgGameState gs) {
      if (gs.sharedDrawPile.isEmpty) {
          if (gs.sharedDiscardPile.isEmpty) return null; // No cards left
          
          // Reshuffle
          gs.sharedDrawPile.addAll(gs.sharedDiscardPile);
          gs.sharedDiscardPile.clear();
          gs.sharedDrawPile.shuffle(_rng);
      }
      return gs.sharedDrawPile.removeLast();
  }
  
  /// Public API to draw a card for a player (e.g., end of turn)
  bool drawCard(LudoRpgGameState gs, LudoColor playerColor) {
      final hand = gs.hands[playerColor];
      if (hand == null) return false;
      if (hand.length >= 7) return false; // Hand limit hardcap?

      final cardId = _drawCardInternal(gs);
      if (cardId == null) return false;
      
      hand.add(cardId);
      return true;
  }
  
  /// Discards a card instance from a player's hand.
  bool discardCard(LudoRpgGameState gs, LudoColor playerColor, String cardInstanceId) {
      final hand = gs.hands[playerColor];
      if (hand == null) return false;
      
      final idx = hand.indexOf(cardInstanceId);
      if (idx == -1) return false;
      
      hand.removeAt(idx);
      gs.sharedDiscardPile.add(cardInstanceId);
      return true;
  }

  /// Validates and plays a card.
  /// If [target] is null but card requires one, returns false (or handles UI state elsewhere).
  /// [target] can be LudoToken, LudoPlayer, or tile index (int).
  EngineResult playCard({
    required LudoRpgGameState gs,
    required CardTemplate card,
    dynamic target,
    int? overrideValue, // For variable inputs (e.g. Teleport distance)
    int? dieIndex, // 0=A, 1=B
  }) {
    if (gs.cardActionsRemaining <= 0) return EngineResult.fail("No actions remaining");
    
    // 1. Validate Target
    if (card.targetType != TargetType.none && target == null) {
      return EngineResult.fail("Target required");
    }
    
    // Check restrictions
    if (card.effectType == CardEffectType.restartTurnNow && 
        gs.isFirstTurnFor(gs.currentPlayer.color)) {
         return EngineResult.fail("Cannot play ${card.name} on your first turn.");
    }
    
    final handler = effectRegistry[card.effectType];
    if (handler == null) {
        return EngineResult.fail("Effect ${card.effectType} not implemented yet");
    }
    
    print("PLAYCARD: ${card.id} / ${card.name} / ${card.effectType} handler? ${handler != null}");
    
    final res = handler(
        gs: gs,
        api: this, // LudoRpgEngine implements LudoRpgEngineApi
        card: card,
        target: target,
        overrideValue: overrideValue,
        dieIndex: dieIndex
    );
    
    if (res.ok) { // Using getter from EffectResult
        if (res.choice != null) {
            gs.pendingChoice = res.choice;
            return EngineResult.ok(choice: res.choice);
        }
        
        if (res.consumesAction) {
            gs.cardActionsRemaining--;
        }
        _checkInvariants(gs);
        
        // Also check win condition if card effect caused movement (teleport etc)
        // teleportToken handles it internally. 
        // Swap effect uses setTokenRelativeFromAbsolute, which currently does NOT check win.
        // We should add win check there too? 
        // Swap shouldn't usually cause a win unless swapping onto goal? 
        // Swapping requires Main Track, and goal is NOT main track. So swap is safe.
        
        return EngineResult.ok(); 
    } else {
        return EngineResult.fail(res.error ?? "Effect failed");
    }
  }
  
  // ---------- Dumpster Dive Logic ----------
  EffectResult playDumpsterDive(LudoRpgGameState gs) {
      if (gs.sharedDiscardPile.isEmpty) return const EffectResult.fail("Discard pile is empty.");
      
      final uniqueCards = gs.sharedDiscardPile.toSet().toList(); 
      final count = min(3, uniqueCards.length);
      final options = <String>[];
      final r = Random();
      
      List<String> pool = List.of(gs.sharedDiscardPile);
      pool.shuffle(r);
      options.addAll(pool.take(count));
      
      return EffectResult.needsChoice(
          PendingChoice(
              type: PendingChoiceType.dumpsterPickOne,
              options: options,
          )
      );
  }
  
  EngineResult resolveChoice(LudoRpgGameState gs, String choiceId) {
      final pending = gs.pendingChoice;
      if (pending == null) return EngineResult.fail("No pending choice.");
      
      if (!pending.options.contains(choiceId)) return EngineResult.fail("Invalid choice.");
      
      if (pending.type == PendingChoiceType.dumpsterPickOne) {
          if (!gs.sharedDiscardPile.contains(choiceId)) return EngineResult.fail("Card no longer in discard.");
          
          gs.sharedDiscardPile.remove(choiceId);
          gs.hands[gs.currentPlayer.color]?.add(choiceId);
          
          gs.pendingChoice = null;
          if (gs.cardActionsRemaining > 0) gs.cardActionsRemaining--;
          
          return EngineResult.ok(events: ["CARD_DRAWN"]);
      }
      
      return EngineResult.fail("Unknown choice type");
  }

  // teleportToken is implemented below (existing method matches interface)
  
  @override
  void teleportToken(LudoRpgGameState gs, LudoToken t, int steps) {
      if (t.isInBase) return; // Can't teleport out of base usually?
      
      // Handle wrapping for negative values or large positive values
      // If forward: normal logic.
      // If backward: need to handle wrapping around 0 -> 51.
      
      int newPos = t.position + steps;
      
      if (steps < 0) {
          // Backward teleport
          // If in Home Stretch (52..57), can we go back to Main?
          if (t.isInHomeStretch) {
              if (newPos < homeStart) {
                   // Exited home stretch back to main
                   newPos = homeStart - (homeStart - newPos); // e.g. 52 - 1 = 51?
                   // Actually: 52 + (-1) = 51. Correct.
              }
          } else if (t.isOnMain) {
              // Wrap around 0->51
              newPos = (newPos % mainTrackLen); 
              if (newPos < 0) newPos += mainTrackLen;
          }
      } else {
          // Forward teleport (standard Move logic but skip collision checks along path)
          if (t.isOnMain) {
              if (newPos >= homeStart) {
                  // Enter home stretch?
                  int overshoot = newPos - homeStart;
                  newPos = homeStart + overshoot;
              }
          }
      }
      
      // Clamp final
      if (newPos > goal) newPos = goal;
      
      t.position = newPos;
      if (t.position == 99 || t.position == 57) {
          t.position = 99;
          t.status = TokenStatus.finished;
      }
      
      _checkWinCondition(gs, t.color);
  }

  bool _checkWinCondition(LudoRpgGameState gs, LudoColor color) {
      final player = gs.players.firstWhere((p) => p.color == color);
      int finishedCount = player.tokens.where((t) => t.isFinished).length;
      
      if (finishedCount >= 2) {
          gs.winner = color;
          gs.phase = TurnPhase.gameOver;
          return true;
      }
      return false;
  }

  void setTokenRelativeFromAbsolute(LudoToken t, int abs) {
      // Reverse toggle: abs -> rel
      // rel = (abs - offset)
      int offset = _startOffsetAbs[t.color]!;
      int rel = (abs - offset) % mainTrackLen;
      if (rel < 0) rel += mainTrackLen;
      t.position = rel;
  }
  
  void _checkInvariants(LudoRpgGameState gs) {
    for (var p in gs.players) {
      for (var t in p.tokens) {
        if (t.isDead || t.isInBase) {
           assert(t.position == -1, "Invariant Failed: Base/Dead token ${t.id} has pos ${t.position}");
        } else if (t.isFinished) {
           // 99 or 57
           assert(t.position == 99, "Invariant Failed: Finished token ${t.id} has pos ${t.position} (Expected 99)");
        } else if (t.isInHomeStretch) {
           assert(t.position >= 52 && t.position <= 57, "Invariant Failed: HomeStretch token ${t.id} has pos ${t.position}");
        } else {
           // Main Track
           assert(t.position >= 0 && t.position < 52, "Invariant Failed: Main token ${t.id} has pos ${t.position}");
        }
      }
    }
  }
  
  // Update endTurn to handle ExtraTurn and SkipTurn
  void endTurn(LudoRpgGameState gs) {
    // 1. Increment turn counter (unless it was an extra turn, but extra turn doesn't call endTurn usually?
    // Actually, ExtraTurn effect usually just adds a flag. But "Restart Turn" effect resets state WITHOUT calling endTurn.
    // So if we are here, it's a normal end of turn.
    
    // Increment completed turns for current player
    gs.turnsCompleted[gs.currentPlayer.color] = (gs.turnsCompleted[gs.currentPlayer.color] ?? 0) + 1;

    // 2. Check for extra turn buff
    if (gs.currentPlayer.hasEffect("ExtraTurn")) {
       gs.currentPlayer.effects.removeWhere((e) => e.id == "ExtraTurn");
       // Same player keeps turn
       gs.dice.reset();
       gs.cardActionsRemaining = 2;
       gs.phase = TurnPhase.awaitRoll;
       return;
    }  
      // Rotate
      int attempts = 0;
      do {
          gs.currentPlayerIndex = (gs.currentPlayerIndex + 1) % gs.players.length;
          attempts++;
          
          if (gs.currentPlayer.hasEffect("SkipTurn")) {
              gs.currentPlayer.effects.removeWhere((e) => e.id == "SkipTurn");
              // Player was skipped/stunned. Continue loop to find next.
              // Note: If you want to notify UI "Player X Skipped!", we might need an event log later.
              continue; 
          }
          
          // Found a player who is NOT skipped.
          break; 
          
      } while (attempts < gs.players.length); // Prevent infinite loop if everyone is stunned
      
      gs.dice.reset();
      gs.cardActionsRemaining = 2;
      gs.phase = TurnPhase.awaitRoll;
  }

  // ---------- Combat hooks (no implementation yet) ----------
  /// Movement restriction you stated ("opponents cannot enter your home stretch")
  /// is inherently satisfied by the RELATIVE position model:
  /// tokens only ever have their OWN 52..57 stretch.
  ///
  /// Ranged attacks and "cannot be attacked on star tiles" will be applied in combat resolution.
  ///
  /// This helper will be used later in attack rules:
  bool isTokenSafeFromAttack(LudoToken token) {
    if (token.isDead || token.isFinished) return true;
    if (token.isInHomeStretch) return true; // unreachable by movement, and typically protected
    if (token.isOnMain) {
      final abs = toAbsoluteMainIndexFromRelative(token);
      return isStarSafeAbsolute(abs);
    }
    return token.isInBase; // base is effectively safe (and out of board interactions)
  }
}
