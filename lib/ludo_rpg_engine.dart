import 'dart:math';
import 'models.dart';

// TurnPhase, DicePair, LudoRpgGameState moved to models/ludo_game_state.dart

class LudoRpgEngine {
  static const int mainTrackLen = 52;
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

    gs.dice.a = _rng.nextInt(6) + 1;
    gs.dice.b = _rng.nextInt(6) + 1;
    gs.dice.aUsed = false;
    gs.dice.bUsed = false;

    gs.cardActionsRemaining = 2;
    gs.phase = TurnPhase.awaitAction;
  }

  // ---------- Safe tiles (stars) ----------
  bool isStarSafeAbsolute(int absMainIndex) {
    return _startOffsetAbs.values.contains(absMainIndex % mainTrackLen);
  }

  /// Convert a token's RELATIVE main position (0..51) into ABSOLUTE main index (0..51)
  int toAbsoluteMainIndex(LudoToken t) {
    final offset = _startOffsetAbs[t.color]!;
    final rel = t.position; // must be 0..51
    return (rel + offset) % mainTrackLen;
  }

  // ---------- Actions ----------
  /// Spawn: Move token from base (-1) to start (0).
  /// Voluntary/Free action. Does NOT consume dice.
  bool spawnFromBase(LudoRpgGameState gs, LudoToken token) {
    // Allowed in awaitRoll OR awaitAction (as long as turn not ended)
    if (gs.phase == TurnPhase.ended) return false;
    
    if (token.color != gs.currentPlayer.color) return false;
    if (token.isDead || token.isFinished) return false;
    if (!token.isInBase) return false;

    // No dice requirement.
    
    token.position = 0; // start star (safe)
    return true;
  }

  /// Spend dice on movement:
  /// - useA: consume die A
  /// - useB: consume die B
  /// - allowCombined: if both selected, movement = a+b
  bool moveToken({
    required LudoRpgGameState gs,
    required LudoToken token,
    required bool useA,
    required bool useB,
  }) {
    if (gs.phase != TurnPhase.awaitAction) return false;
    if (token.color != gs.currentPlayer.color) return false;
    if (token.isDead || token.isFinished) return false;
    if (!gs.dice.rolled) return false;

    // Validate dice availability
    if (useA && gs.dice.aUsed) return false;
    if (useB && gs.dice.bUsed) return false;
    if (!useA && !useB) return false;

    final steps = (useA ? gs.dice.a! : 0) + (useB ? gs.dice.b! : 0);

    // Can't move from base via moveToken (spawn is a separate free action)
    if (token.isInBase) return false;

    // ... logic for next steps calculation ...
    // Calculate candidate position first
    int finalRelPos = -1;
    bool entersHomeStretch = false;

    if (token.isInHomeStretch) {
      final next = token.position + steps;
      if (next > homeEnd) return false;
      finalRelPos = next;
    } else if (token.isOnMain) {
      final nextRel = token.position + steps;
       if (nextRel >= homeStart) {
        final homePos = homeStart + (nextRel - homeStart);
        if (homePos > homeEnd) return false;
        finalRelPos = homePos;
        entersHomeStretch = true;
      } else {
        finalRelPos = nextRel % mainTrackLen;
      }
    } else {
      return false;
    }
    
    // Check Collisions if on Main Track (Home stretch is private/safe from collision usually, or at least from opponents)
    // Opponents are only on Main Track relative to me.
    // If I am entering home stretch, no opponent collision possible there.
    // So only check if !entersHomeStretch && !token.isInHomeStretch (i.e. finalRelPos < homeStart)
    
    if (finalRelPos < homeStart) {
        // Calculate my absolute target
        final myAbs = (finalRelPos + _startOffsetAbs[token.color]!) % mainTrackLen;
        
        for (var p in gs.players) {
            if (p.color == token.color) continue; // Skip self
            
            for (var t in p.tokens) {
                if (t.isDead || t.isFinished || t.isInBase || t.isInHomeStretch) continue;
                
                // Compare absolute positions
                final tAbs = toAbsoluteMainIndex(t);
                if (tAbs == myAbs) {
                    // Collision!
                    if (isTokenSafeFromAttack(t)) {
                        // Safe: allow stacking usually. Or bounce?
                        // "cannot be attacked". Implies nothing happens to them.
                        // So we just co-exist.
                    } else {
                        // Kill!
                        t.status = TokenStatus.dead;
                        t.position = -1; // Reset pos (though dead status overrides)
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
    } else if (token.position == goal) {
       token.status = TokenStatus.finished;
    }

    // Mark dice used
    if (useA) gs.dice.aUsed = true;
    if (useB) gs.dice.bUsed = true;

    return true;
  }

  // ---------- Card System ----------
  
  /// Validates and plays a card.
  /// If [target] is null but card requires one, returns false (or handles UI state elsewhere).
  /// [target] can be LudoToken, LudoPlayer, or tile index (int).
  bool playCard({
    required LudoRpgGameState gs,
    required CardTemplate card,
    dynamic target,
    int? overrideValue, // For variable inputs (e.g. Teleport distance)
  }) {
    if (gs.cardActionsRemaining <= 0) return false;
    
    // 1. Validate Target
    if (card.targetType != TargetType.none && target == null) {
      return false; // Target required
    }
    
    // Use override if present, else card default
    final int effValue = overrideValue ?? card.value;

    bool success = false;

    switch (card.effectType) {
      // --- Dice ---
      case CardEffectType.modifyRoll:
        if (gs.dice.a != null && !gs.dice.aUsed) {
           gs.dice.a = (gs.dice.a! + effValue).clamp(1, 30);
           success = true;
        } else if (gs.dice.b != null && !gs.dice.bUsed) {
           gs.dice.b = (gs.dice.b! + effValue).clamp(1, 30);
           success = true;
        }
        break;
        
      case CardEffectType.doubleRoll:
        if (effValue == 1) {
            if (gs.dice.a != null && !gs.dice.aUsed) {
                gs.dice.a = gs.dice.a! * 2;
                success = true;
            } else if (gs.dice.b != null && !gs.dice.bUsed) {
                gs.dice.b = gs.dice.b! * 2;
                success = true;
            }
        } else {
            if (gs.dice.a != null) gs.dice.a = gs.dice.a! * 2;
            if (gs.dice.b != null) gs.dice.b = gs.dice.b! * 2;
            success = true;
        }
        break;

      case CardEffectType.reroll:
         if (effValue == 1) {
             if (gs.dice.a != null && !gs.dice.aUsed) {
                 gs.dice.a = _rng.nextInt(6) + 1;
                 success = true;
             }
         } else {
             gs.dice.a = _rng.nextInt(6) + 1;
             gs.dice.b = _rng.nextInt(6) + 1;
             success = true;
         }
         break;

      // --- Turn ---
      case CardEffectType.extraTurn:
         gs.currentPlayer.effects.add(const ActiveEffect(id: "ExtraTurn", duration: 1));
         success = true;
         break;

      case CardEffectType.skipTurn:
         if (target is LudoPlayer) {
             target.effects.add(const ActiveEffect(id: "SkipTurn", duration: 1));
             success = true;
         }
         break;

      // --- Movement ---
      case CardEffectType.teleport:
         if (target is LudoToken) {
             _teleportToken(target, effValue); 
             success = true;
         }
         break;
         
      case CardEffectType.swapPos:
          if (target is LudoToken) {
              LudoToken? selfToken = gs.currentPlayer.tokens.firstWhere((t) => t.isOnMain, orElse: () => gs.currentPlayer.tokens.first);
              if (selfToken.isOnMain && target.isOnMain) {
                   int selfAbs = toAbsoluteMainIndex(selfToken);
                   int targetAbs = toAbsoluteMainIndex(target);
                   _setTokenToAbsolute(selfToken, targetAbs);
                   _setTokenToAbsolute(target, selfAbs);
                   success = true;
              }
          }
          break;

      default:
        print("Effect ${card.effectType} not yet implemented");
        success = true; 
        break;
    }

    if (success) {
        gs.cardActionsRemaining--;
    }
    return success;
  }
  
  // (Full Body implementation below for Replace)
  void _teleportToken(LudoToken t, int steps) {
      if (t.isInBase) return; // Can't teleport out of base usually?
      
      // Handle wrapping for negative values or large positive values
      // If forward: normal logic.
      // If backward: need to handle wrapping around 0 -> 51.
      
      // Simple logic: convert to absolute, add steps, wrap 52, convert back?
      // No, because Home Stretch entrance depends on relative pos.
      
      // Teleport usually ignores physics (walls), but let's respect the track loop.
      // If steps < 0: 
      //    newPos = (pos + steps) % 52. 
      //    (But dart % can be negative).
      
      int newPos = t.position + steps;
      
      if (steps < 0) {
          // Backward teleport
          // If in Home Stretch (52..57), can we go back to Main?
          if (t.isInHomeStretch) {
              if (newPos < homeStart) {
                   // Exited home stretch back to main
                   newPos = homeStart - (homeStart - newPos); // e.g. 52 - 1 = 51?
                   // Actually: 52 + (-1) = 51. Correct.
                   // Ensure it wraps correctly if huge negative?
                   // No, just simple addition works if we treat 0..51 as ring.
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
  }

  void _setTokenToAbsolute(LudoToken t, int abs) {
      // Reverse toggle: abs -> rel
      // rel = (abs - offset)
      int offset = _startOffsetAbs[t.color]!;
      int rel = (abs - offset) % mainTrackLen;
      if (rel < 0) rel += mainTrackLen;
      t.position = rel;
  }
  
  // Update endTurn to handle ExtraTurn and SkipTurn
  void endTurn(LudoRpgGameState gs) {
      // Check Extra Turn
      bool extra = gs.currentPlayer.hasEffect("ExtraTurn");
      if (extra) {
          gs.currentPlayer.effects.removeWhere((e) => e.id == "ExtraTurn");
          // Same player goes again.
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
      final abs = toAbsoluteMainIndex(token);
      return isStarSafeAbsolute(abs);
    }
    return token.isInBase; // base is effectively safe (and out of board interactions)
  }
}
