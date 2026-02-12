import 'dart:math';
import 'dart:math';
import 'models.dart';
import 'effects/effect_registry.dart';
import 'effects/effect_types.dart';
import 'board_layout.dart';

// TurnPhase, DicePair, LudoRpgGameState moved to models/ludo_game_state.dart

class EngineResult {
  final bool success;
  final String? message;
  final List<String> events;
  final PendingInteraction? pending;

  const EngineResult({required this.success, this.message, this.events = const [], this.pending});

  factory EngineResult.ok({List<String> events = const [], PendingInteraction? pending}) => 
      EngineResult(success: true, events: events, pending: pending);
  factory EngineResult.needsInteraction(PendingInteraction pending) => 
      EngineResult(success: true, pending: pending);
  
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
  
  // ---------- Helper Functions ----------
  
  LudoToken? _findTokenById(LudoRpgGameState gs, String? id) {
      if (id == null) return null;
      for (final p in gs.players) {
          for (final t in p.tokens) {
              if (t.id == id) return t;
          }
      }
      return null;
  }
  
  // Compute grid cell (0..14, 0..14) for any token
  Point<int>? _tokenGridCell(LudoToken t) {
      if (t.isInBase || t.isFinished || t.isDead) return null;
      
      if (t.isOnMain) {
          final abs = toAbsoluteMainIndexFromRelative(t);
          final path = BoardLayout.getLegacyPath();
          if (abs >= path.length) return null;
          final norm = path[abs];
          final gx = (norm.dx * 15).floor().clamp(0, 14);
          final gy = (norm.dy * 15).floor().clamp(0, 14);
          return Point(gx, gy);
      }
      
      if (t.isInHomeStretch) {
          int stepsIn = t.position - 51; // 1..6
          if (stepsIn > 6) stepsIn = 6;
          
          int x=0, y=0;
          switch(t.color) {
              case LudoColor.red: x = stepsIn; y = 7; break;
              case LudoColor.green: x = 7; y = stepsIn; break;
              case LudoColor.yellow: x = 14 - stepsIn; y = 7; break;
              case LudoColor.blue: x = 7; y = 14 - stepsIn; break;
          }
          return Point(x.clamp(0, 14), y.clamp(0, 14));
      }
      return null;
  }






  

  
  // ---------- Helper Functions ----------
  

  
  // Compute grid cell (0..14, 0..14) for any token


  void _applyDamage(LudoRpgGameState gs, {required LudoToken target, required int amount, LudoToken? attacker, required bool isMelee, List<String>? events}) {
      if (target.isDead || target.isFinished) return;
      
      // 1. Check Negation Effects (Stink Bomb, Resist)
      if (target.hasEffect("StinkBomb")) {
          target.effects.removeWhere((e) => e.id == "StinkBomb");
          gs.toast("🤢 Stink Bomb distracted the attack!");
          return; // Negated
      }
      if (target.hasEffect("Resist")) {
           target.effects.removeWhere((e) => e.id == "Resist");
           gs.toast("🛡️ Resist canceled the action!");
           return; // Negated
      }
      
      // 2. Eel Armour Reflect (Melee only)
      if (isMelee && attacker != null && target.hasEffect("EelArmour")) {
          attacker.hp -= 1;
          if (attacker.hp <= 0) {
              attacker.hp = 0;
              attacker.status = TokenStatus.dead;
              attacker.position = -1;
              attacker.effects.clear();
              gs.toast("⚡ ${attacker.id} died to Eel Armour.");
              if (events != null) events.add("ATTACKER_DIED_EEL");
          }
      }
      
      // 3. Chainmail / Eel Armour Absorption
      // "Armour discards after first hit" -> logic handled by HP=2
      if (target.hasEffect("Chainmail") || target.hasEffect("EelArmour")) {
          target.effects.removeWhere((e) => e.id == "Chainmail" || e.id == "EelArmour");
          // HP drops from 2 to 1 automatically via damage below.
      }
      
      target.hp -= amount;
      
      if (target.hp <= 0) {
          target.hp = 0;
          target.status = TokenStatus.dead;
          target.position = -1;
          target.effects.clear();
          gs.toast("💀 ${target.id} died.");
          if (events != null) events.add("TOKEN_KILLED");
      }
      
      // 4. Astral Link Propagation
      // Check if target's player has an active Astral Link involving this token
      // Link is stored on the OWNER of the source token (usually).
      // Or we check all players for a link referencing this token?
      // Logic: Link A and B. Damage to A -> Damage to B? Or Damage to B -> Damage to A?
      // "Link your pawn to opponent". Usually bidirectional or "Source shares pain with Target".
      // Let's implement simpler: Check ANY active link referencing this token.
      
      for (var p in gs.players) {
          if (p.effects.any((e) => e.id == "AstralLink")) {
              final link = p.effects.firstWhere((e) => e.id == "AstralLink");
              final aId = link.data["aId"];
              final bId = link.data["bId"];
              
              if (target.id == aId || target.id == bId) {
                  // Propagate to the other!
                  final otherId = (target.id == aId) ? bId : aId;
                  final other = _findTokenById(gs, otherId);
                  
                  if (other != null && !other.isDead && !other.isInBase && other.hp > 0) {
                       // Avoid infinite loop: Is this a recursive call?
                       // Simple check: Don't recurse ifamount is 0 (unlikely)
                       // Better: Pass flag? Or just apply direct damage without calling _applyDamage again?
                       // Or call _applyDamage with 'isPropagation' flag?
                       
                       // Direct apply to avoid recursion for now, or ensure only 1 hop.
                       // User report says "not implemented", so basic impl is key.
                       
                       other.hp -= amount;
                       if (other.hp <= 0) {
                           other.hp = 0;
                           other.status = TokenStatus.dead;
                           other.position = -1;
                           gs.toast("🔗 ${other.id} died/hurt via Astral Link!");
                       } else {
                           gs.toast("🔗 ${other.id} hurt via Astral Link!");
                       }
                  }
              }
          }
      }
  }

  List<LudoToken> _tokensAtAbs(LudoRpgGameState gs, int abs) {
       final out = <LudoToken>[];
       for (final p in gs.players) {
           for (final t in p.tokens) {
               if (t.isDead || t.isFinished || t.isInBase || !t.isOnMain) continue;
               if (toAbsoluteMainIndexFromRelative(t) == abs) out.add(t);
           }
       }
       return out;
  }

  List<LudoToken> _targetsInRingRange({
      required LudoRpgGameState gs,
      required LudoToken attacker,
      required int range,
      required bool forward, // if true, look forward. else backward.
  }) {
      if (!attacker.isOnMain) return [];
      final aAbs = toAbsoluteMainIndexFromRelative(attacker);
      final out = <LudoToken>[];
      
      for (int i = 1; i <= range; i++) {
          final abs = forward ? (aAbs + i) % 52 : (aAbs - i + 52) % 52;
          
          for (final t in _tokensAtAbs(gs, abs)) {
              if (t.color == attacker.color) continue;
              if (isTokenSafeFromAttack(t)) continue;
              out.add(t);
          }
      }
      return out;
  }
  
  List<LudoToken> _targetsInGridAdjacency(LudoRpgGameState gs, LudoToken attacker) {
      final aCell = _tokenGridCell(attacker);
      if (aCell == null) return [];
      
      bool isAdj(Point<int> b) {
          final dx = (b.x - aCell.x).abs();
          final dy = (b.y - aCell.y).abs();
          return (dx + dy) == 1; // Manhattan distance 1
      }
      
      final out = <LudoToken>[];
      for (final p in gs.players) {
          for (final t in p.tokens) {
              if (t.isDead || t.isFinished || t.isInBase) continue;
              if (t.color == attacker.color) continue;
              
              final bCell = _tokenGridCell(t);
              if (bCell == null) continue;
              if (!isAdj(bCell)) continue;
              
              // Magic Spear: Pierce home stretch if horizontally adjacent
              bool canPierce = t.isInHomeStretch && (bCell.y == aCell.y) && ((bCell.x - aCell.x).abs() == 1);
              
              if (!canPierce && isTokenSafeFromAttack(t)) continue;
              
              out.add(t);
          }
      }
      return out;
  }

  LudoRpgEngine({Random? rng}) : _rng = rng ?? Random();

  // ---------- Dice ----------
  void rollDice(LudoRpgGameState gs) {
    if (gs.phase != TurnPhase.awaitRoll) return;

    gs.dice.a = DieState(_rng.nextInt(6) + 1);
    gs.dice.b = DieState(_rng.nextInt(6) + 1);

    // Apply SlowDice effect if present
    if (gs.currentPlayer.hasEffect("SlowDice")) {
        gs.dice.a!.value = (gs.dice.a!.value / 2).floor();
        if (gs.dice.a!.value < 1) gs.dice.a!.value = 1;
        
        gs.dice.b!.value = (gs.dice.b!.value / 2).floor();
        if (gs.dice.b!.value < 1) gs.dice.b!.value = 1;
        
        // Effect consumed? Usually yes for "next turn". Duration 1 handles auto-expire in endTurn.
    }

    gs.cardActionsRemaining = 2;
    gs.phase = TurnPhase.awaitAction;
  }

  // ---------- Safe tiles (stars) ----------
  bool isStarSafeAbsolute(int absMainIndex) {
    return _startOffsetAbs.values.contains(absMainIndex % mainTrackLen);
  }


  /// Convert a token's RELATIVE main position (0..51) into ABSOLUTE main index (0..51)

  

  



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

    // Use EFFECTIVE values (modifiers included)
    final steps = (useA ? gs.dice.aEff : 0) + (useB ? gs.dice.bEff : 0);

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
    
    // Check Path Collisions (Pandemic Spread) BEFORE moving
    if (token.isOnMain && !entersHomeStretch) { // Only Main track
        _handlePathCollisions(gs, token, token.position, steps);
    }
    
    // Apply Move
    token.position = finalRelPos;
    
    _handleCollisions(gs, token, events);
    if (token.position == homeEnd) { // Check both 57 and goal
       token.position = goal;
       token.status = TokenStatus.finished;
       events.add("TOKEN_FINISHED");
       token.status = TokenStatus.finished;
       events.add("TOKEN_FINISHED");
    }

    // Check Astral Link
    final link = gs.currentPlayer.effects.firstWhere(
        (e) => e.id == "AstralLink", 
        orElse: () => const ActiveEffect(id: "none", duration: 0)
    );
    if (link.id != "none") {
         // This player has an active link. Check if this token is the source (A).
         final aId = link.data?["aId"];
         final bId = link.data?["bId"];
         
         if (token.id == aId) {
             // Move B by same steps
             // B must be on main or compatible?
             // Simplification: Link works best on main track.
             if (bId != null) {
                 // specific logic later or basic implementation now
                 // Need to find token B
                 LudoToken? tokenB;
                 for(var p in gs.players) {
                     for (var t in p.tokens) {
                         if (t.id == bId) { tokenB = t; break; }
                     }
                 }
                 
                 if (tokenB != null && tokenB.isOnMain && token.isOnMain) {
                      // Move B same amount
                      final bAbs = toAbsoluteMainIndexFromRelative(tokenB);
                      final newBAbs = (bAbs + steps) % mainTrackLen;
                      setTokenRelativeFromAbsolute(tokenB, newBAbs);
                      gs.toast("Astral Link pulls ${tokenB.id}!");
                 }
             }
         }
    }

    // Mark dice used
    // Mark dice used (Atomic spend)
    if (useA) {
        gs.dice.a!.used = true;
        // Modifiers are cleared on reset(), but if you want single-use buffs, clear here.
        // For "Double It", it generally lasts for the move.
        // We'll leave them on until reset() for simplicity or visual consistency?
        // Actually specs say "dice is spent", usually means visual modifiers might want to clear or stay "spent".
        // Let's clear modifiers to prevent reuse bugs if somehow resurrected.
        gs.dice.a!.clearModifiers();
    }
    if (useB) {
        gs.dice.b!.used = true;
        gs.dice.b!.clearModifiers();
    }
    
    _checkInvariants(gs);
    
    // Check Win Condition
    if (_checkWinCondition(gs, token.color)) {
        events.add("GAME_WON");
    }
    
    return EngineResult.ok(events: events);
  }

  void _handleCollisions(LudoRpgGameState gs, LudoToken token, List<String> events) {
      if (token.position < homeStart && token.position >= 0) {
          final myAbs = toAbsoluteMainIndexFromRelative(token);
          
          for (var p in gs.players) {
              if (p.color == token.color) continue; // Skip self
              
              for (var t in p.tokens) {
                  if (t.isDead || t.isFinished || t.isInBase || t.isInHomeStretch) continue;
                  
                  // Compare absolute positions
                  final tAbs = toAbsoluteMainIndexFromRelative(t);
                  if (tAbs == myAbs) {
                      // Collision!
                      
                      // PANDEMIC SPREAD
                      bool infectionPresent = token.hasEffect("PandemicInfected") || token.hasEffect("PandemicCarrier") || 
                                              t.hasEffect("PandemicInfected") || t.hasEffect("PandemicCarrier");
                                              
                      if (infectionPresent) {
                          if (!token.hasEffect("PandemicInfected") && !token.hasEffect("PandemicCarrier")) {
                              token.effects.add(const ActiveEffect(id: "PandemicInfected", duration: 999));
                              events.add("Infection Spread to Attacker");
                              gs.toast("${token.id} infected!");
                          }
                          if (!t.hasEffect("PandemicInfected") && !t.hasEffect("PandemicCarrier")) {
                              t.effects.add(const ActiveEffect(id: "PandemicInfected", duration: 999));
                              events.add("Infection Spread to Defender");
                              gs.toast("${t.id} infected!");
                          }
                      }
                      
                      if (isTokenSafeFromAttack(t)) {
                          // Safe: stack
                      } else {
                          // Standard Kill = 1 Damage?
                           // Standard collisions deal 1 damage (based on plan)
                           _applyDamage(gs, target: t, amount: 1, attacker: token, isMelee: true, events: events);
                           
                           // If attacker was damaged by Eel, it's handled in applyDamage
                      }
                  }
              }
          }
      }
  }

  // ---------- Pandemic Logic ----------
  
  EngineResult rollPandemicSurvival(LudoRpgGameState gs) {
      if (gs.phase != TurnPhase.pandemicSurvival) return EngineResult.fail("Not in survival phase");
      
      final events = <String>[];
      bool anyDied = false;
      bool anyCured = false;
      
      for (final t in gs.currentPlayer.tokens) {
          if (!t.hasEffect("PandemicInfected")) continue;
          
          final roll = _rng.nextInt(6) + 1;
          if (roll < 3) {
              // Die
              gs.toast("${t.id} failed survival (Rolled $roll) -> DEAD 💀");
              events.add("PANDEMIC_DEATH");
              
              // Kill
              t.hp = 0;
              t.status = TokenStatus.dead;
              t.position = -1;
              t.effects.clear(); // Clears pandemic too
              anyDied = true;
          } else {
              // Cure
              gs.toast("${t.id} survived (Rolled $roll) -> CURED 💊");
              t.effects.removeWhere((e) => e.id == "PandemicInfected");
              events.add("PANDEMIC_CURED");
              anyCured = true;
          }
      }
      
      // Proceed to turn
      gs.phase = TurnPhase.awaitRoll;
      
      return EngineResult.ok(events: events);
  }
  
  void _handlePathCollisions(LudoRpgGameState gs, LudoToken mover, int startPos, int steps) {
      if (!mover.isOnMain) return; // Only main track logic for passing
      
      for (int i = 1; i < steps; i++) { // Exclude destination (steps) which is handled by _handleCollisions
          final abs = (toAbsoluteMainIndexFromRelative(mover, overridePos: startPos) + i) % 52;
          
          for (final p in gs.players) {
              for (final t in p.tokens) {
                  if (t == mover) continue;
                  if (t.isDead || t.isFinished || t.isInBase || !t.isOnMain) continue;
                  
                  if (toAbsoluteMainIndexFromRelative(t) == abs) {
                      // Collision along path
                      _checkPandemicSpread(gs, mover, t);
                  }
              }
          }
      }
  }
  
  void _checkPandemicSpread(LudoRpgGameState gs, LudoToken a, LudoToken b) {
      bool infectionPresent = a.hasEffect("PandemicInfected") || a.hasEffect("PandemicCarrier") || 
                              b.hasEffect("PandemicInfected") || b.hasEffect("PandemicCarrier");
                              
      if (infectionPresent) {
          if (!a.hasEffect("PandemicInfected") && !a.hasEffect("PandemicCarrier")) {
              a.effects.add(const ActiveEffect(id: "PandemicInfected", duration: 999));
              gs.toast("${a.id} infected by contact!");
          }
          if (!b.hasEffect("PandemicInfected") && !b.hasEffect("PandemicCarrier")) {
              b.effects.add(const ActiveEffect(id: "PandemicInfected", duration: 999));
              gs.toast("${b.id} infected by contact!");
          }
      }
  }

  // --- API Implementation ---
  @override
  int rollD6() => _rng.nextInt(6) + 1;

  /// Resets the game state completely.
  void nextTurn(LudoRpgGameState gs) {
    if (gs.phase == TurnPhase.gameOver) return;

    // Move to next player
    int nextIndex = (gs.currentPlayerIndex + 1) % gs.players.length;
    gs.currentPlayerIndex = nextIndex;
    LudoPlayer player = gs.players[nextIndex];
    
    gs.phase = TurnPhase.awaitRoll;
    gs.dice.reset();
    gs.activeCardId = null;
    gs.cardActionsRemaining = 2; // Reset actions
    gs.pending = null;
    
    // Decrement Player Effects
    player.effects.removeWhere((e) {
        // e.duration--; // Cannot modify final?
        // Logic for duration needed.
        // Assuming immutable ActiveEffect, we need to replace or not.
        // For now, assume simplified effect management or implement decrement later.
        return e.duration <= 0; // Remove expired
    });
    
    // Check Skip Turn
    if (player.hasEffect("SkipTurn")) {
        gs.toast("${player.color.name} Stunned! Skipping turn.");
        // Remove SkipTurn effect? usually consumes it.
        player.effects.removeWhere((e) => e.id == "SkipTurn");
        // Recursive next turn
        // But use Future to not stack overflow? or just simple call.
        // nextTurn(gs); 
        // Better: Return, let UI handle animation, then auto-trigger next?
        // Or just execute logic.
        // If I call nextTurn here, it's a loop if everyone is stunned.
        // Safe enough for 4 players.
        // But let's effectively end turn immediately.
        
        // PANDEMIC CHECK FOR SKIPPED PLAYER?
        // "Each token has to roll... on their player's turn".
        // If turn is skipped, do they roll? Unclear.
        // Assume YES, disease doesn't care about stun.
        _handlePandemicCheck(gs, player);
        
        nextTurn(gs);
        return;
    }
    
    // PANDEMIC CHECK
    _handlePandemicCheck(gs, player);
    
    gs.toast("${player.color.name}'s Turn");
  }

  void _handlePandemicCheck(LudoRpgGameState gs, LudoPlayer player) {
      for (var t in player.tokens) {
          if (t.hasEffect("Pandemic") && !t.isDead && !t.isFinished) {
              final roll = _rng.nextInt(6) + 1;
              if (roll >= 3) {
                  // Cured!
                  t.effects.removeWhere((e) => e.id == "Pandemic");
                  gs.toast("Token ${t.id} cured Pandemic! (Rolled $roll)");
              } else {
                  // Died!
                  t.hp = 0;
                  t.status = TokenStatus.dead;
                  t.position = -1;
                  t.effects.clear(); // Remove Pandemic and everything else
                  gs.toast("Token ${t.id} died from Pandemic! (Rolled $roll)");
              }
          }
      }
  }        
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
              t.hp = 1;
              t.maxHp = 1;
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
        if (res.pending != null) {
            gs.pending = res.pending;
            return EngineResult.ok(pending: res.pending);
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
  
  // ---------- Board Card Implementations ----------

  EngineResult playBoardCard(LudoRpgGameState gs, String boardId) {
    if (gs.phase == TurnPhase.ended) return EngineResult.fail("Turn ended");

    switch (boardId) {
      case "Board02": return _doubleIt(gs);
      case "Board01": return _doubleIt2x(gs);
      case "Board04": return _reroll(gs);
      case "Board03": return _reroll2x(gs);
      case "Board12": return _shuffle(gs);
      case "Board07": return _steal(gs);
      case "Board08": return _trade(gs);
      case "Board05": return _robbinHood(gs);
      case "Board11": return _stun(gs);
      case "Board09": return _dumpsterDive(gs);
      case "Board10": return _mimic(gs);
      // Movement cards that are implemented as 'Board' style actions (no direct target yet)
      case "Movement02": return _boots(gs);
      case "Movement03": return _dash(gs);
      case "Movement05": return _jump(gs);
      case "Movement06": return _slow(gs);
      case "Movement09": return _forcePull(gs);
      case "Movement04": return _forcePush(gs);
      case "Movement01": return _astralLink(gs);

      
      // Attack & Defence
      case "Defence01": return _chainmail(gs);
      case "Defence02": return _eelArmour(gs);
      case "Defence03": return _mirror(gs);
      case "Defence07": return _vaccine(gs);
      case "Defence04": return _resist(gs);
      case "Defence05": return _resurrect(gs);
      case "Defence06": return _stinkBomb(gs);
      case "Attack02": return _dagger(gs);
      case "Attack01": return _crossbow(gs);
      case "Attack04": return _longBow(gs);
      case "Attack05": return _magicSpear(gs);
      case "Attack03": return _laser(gs);
      case "Attack06": return _pandemic(gs);
      
      default: return EngineResult.fail("Unknown board card: $boardId");
    }
  }

  EngineResult resolvePending(LudoRpgGameState gs, Map<String, dynamic> input) {
    final p = gs.pending;
    if (p == null) return EngineResult.fail("No pending action.");

    EngineResult res = EngineResult.fail("Unhandled pending type");
    
    switch (p.type) {
      case PendingType.pickDieToDouble: res = _resolvePickDieToDouble(gs, input); break;
      case PendingType.pickDieToReroll: res = _resolvePickDieToReroll(gs, input); break;
      case PendingType.confirmRerollChoiceSingle: res = _resolveConfirmRerollSingle(gs, input); break;
      case PendingType.confirmRerollChoiceBoth: res = _resolveConfirmRerollBoth(gs, input); break;
      case PendingType.pickPlayer: res = _resolvePickPlayer(gs, input); break;
      case PendingType.pickCardFromOpponentHand: res = _resolvePickOpponentCard(gs, input); break;
      case PendingType.pickCardFromYourHand: res = _resolvePickYourCard(gs, input); break;
      case PendingType.robinPickCard: res = _resolveRobinPickCard(gs, input); break;
      case PendingType.robinPickRecipient: res = _resolveRobinPickRecipient(gs, input); break;
      case "DumpsterBrowsePick": 
      case PendingType.dumpsterBrowsePick: res = _resolveDumpsterPick(gs, input); break;
      
      case PendingType.pickToken1: res = _resolvePickToken1(gs, input); break;
      case PendingType.pickToken2: res = _resolvePickToken2(gs, input); break;
      case PendingType.selectResurrectTarget: res = _resolveResurrectTarget(gs, input); break;
      case PendingType.selectResurrectTarget: res = _resolveResurrectTarget(gs, input); break;
      case PendingType.pickAttackTarget: // Fallthrough
      case PendingType.selectAttackTarget: res = _resolveAttackTarget(gs, input); break;
      case PendingType.pickAttackDirection: res = _resolveAttackDirection(gs, input); break;
      
      default: res = EngineResult.fail("Unsupported pending action.");
    }
    
    // If resolution finished the pending interaction (pending became null) 
    // AND it wasn't just a transition to another pending state
    // AND it consumed an action (most board cards do), we might decrement here?
    // Actually simpler: let each resolver handle decrement if it marks 'complete'.
    // Or we assume playing the card *starts* the action chain, decrement then?
    // Board cards usually consume 1 action.
    // Let's stick to: playBoardCard decrements if immediate, or sets pending.
    // If pending, we wait. Final resolver decrements.
    
    return res;
  }
  
  // --- Individual Logic ---

  EngineResult _doubleIt(LudoRpgGameState gs) {
    if (gs.phase == TurnPhase.awaitRoll) return EngineResult.fail("Card cannot be played before dice is rolled");
    if (!gs.dice.rolled) return EngineResult.fail("Dice not rolled"); // Double check
    
    gs.pending = const PendingInteraction(
      type: PendingType.pickDieToDouble,
      sourceCardId: "Board02",
    );
    return EngineResult.needsInteraction(gs.pending!);
  }



  EngineResult _doubleIt2x(LudoRpgGameState gs) {
    if (gs.phase == TurnPhase.awaitRoll) return EngineResult.fail("Card cannot be played before dice is rolled");
    
    gs.dice.a?.multiplier = 2; gs.dice.a?.showD12 = true;
    gs.dice.b?.multiplier = 2; gs.dice.b?.showD12 = true;
    
    _completeCardAction(gs);
    return EngineResult.ok(events: ["DICE_DOUBLED"]);
  }

  EngineResult _reroll(LudoRpgGameState gs) {
    if (gs.phase == TurnPhase.awaitRoll) return EngineResult.fail("Card cannot be played before dice is rolled");
    gs.pending = const PendingInteraction(type: PendingType.pickDieToReroll, sourceCardId: "Board04");
    return EngineResult.needsInteraction(gs.pending!);
  }
  
  EngineResult _resolvePickDieToReroll(LudoRpgGameState gs, Map<String, dynamic> input) {
    final which = input["dieIndex"];
    int oldVal, newVal;
    
    if (which == 0) {
      oldVal = gs.dice.a!.value;
      newVal = _rng.nextInt(6) + 1;
      gs.dice.a!.prevValue = oldVal;
      gs.dice.a!.value = newVal; // tentatively set new, allow revert
    } else if (which == 1) {
        oldVal = gs.dice.b!.value;
        newVal = _rng.nextInt(6) + 1;
        gs.dice.b!.prevValue = oldVal;
        gs.dice.b!.value = newVal;
    } else {
        return EngineResult.fail("Invalid die.");
    }
    
    gs.pending = PendingInteraction(
        type: PendingType.confirmRerollChoiceSingle,
        sourceCardId: "Board04",
        data: {"dieIndex": which, "old": oldVal, "new": newVal}
    );
    return EngineResult.needsInteraction(gs.pending!);
  }
  
  EngineResult _resolveConfirmRerollSingle(LudoRpgGameState gs, Map<String, dynamic> input) {
      final keep = input["keep"]; // "old" or "new"
      final dieIdx = gs.pending!.data["dieIndex"];
      
      if (keep == "old") {
          final old = gs.pending!.data["old"];
          if (dieIdx == 0) gs.dice.a!.value = old;
          else gs.dice.b!.value = old;
      }
      // if "new", value is already set
      
      if (dieIdx == 0) gs.dice.a!.prevValue = null;
      else gs.dice.b!.prevValue = null;
      
      _completeCardAction(gs);
      return EngineResult.ok(events: ["REROLL_COMPLETE"]);
  }

  EngineResult _reroll2x(LudoRpgGameState gs) {
    if (gs.phase == TurnPhase.awaitRoll) return EngineResult.fail("Card cannot be played before dice is rolled");
    
    final oldA = gs.dice.a!.value;
    final oldB = gs.dice.b!.value;
    final newA = _rng.nextInt(6) + 1;
    final newB = _rng.nextInt(6) + 1;

    // Tentatively set
    gs.dice.a!.value = newA; gs.dice.a!.prevValue = oldA;
    gs.dice.b!.value = newB; gs.dice.b!.prevValue = oldB;
    
    gs.pending = PendingInteraction(
        type: PendingType.confirmRerollChoiceBoth,
        sourceCardId: "Board03",
        data: {"oldA": oldA, "oldB": oldB, "newA": newA, "newB": newB}
    );
    return EngineResult.needsInteraction(gs.pending!);
  }

  EngineResult _resolveConfirmRerollBoth(LudoRpgGameState gs, Map<String, dynamic> input) {
     if (input["keep"] == "old") {
         gs.dice.a!.value = gs.pending!.data["oldA"];
         gs.dice.b!.value = gs.pending!.data["oldB"];
     }
     gs.dice.a!.prevValue = null;
     gs.dice.b!.prevValue = null;
     _completeCardAction(gs);
     return EngineResult.ok(events: ["REROLL_COMPLETE"]);
  }

  EngineResult _shuffle(LudoRpgGameState gs) {
     // Rotate hands CCW: Current gets Next player's hand.
     // players are ordered 0..3 (Red, Green, Yellow, Blue typically).
     // "Player to their left" in a circle 0->1->2->3->0 means player 1 is left of 0?
     // Usually "Left" means "Next".
     
     final n = gs.players.length;
     // Snapshot current hands
     final oldHands = <LudoColor, List<String>>{};
     for (var p in gs.players) {
         oldHands[p.color] = List.from(gs.hands[p.color]!);
     }
     
     for (int i = 0; i < n; i++) {
         final current = gs.players[i];
         final next = gs.players[(i + 1) % n];
         // Current gets Next's hand
         gs.hands[current.color] = oldHands[next.color]!;
     }
     
     _completeCardAction(gs);
     return EngineResult.ok(events: ["HANDS_SHUFFLED"]);
  }

  EngineResult _steal(LudoRpgGameState gs) {
     gs.pending = const PendingInteraction(type: PendingType.pickPlayer, sourceCardId: "Board07");
     return EngineResult.needsInteraction(gs.pending!);
  }
  
  EngineResult _trade(LudoRpgGameState gs) {
     gs.pending = const PendingInteraction(type: PendingType.pickPlayer, sourceCardId: "Board08");
     return EngineResult.needsInteraction(gs.pending!);
  }
  
  EngineResult _robbinHood(LudoRpgGameState gs) {
     gs.pending = const PendingInteraction(type: PendingType.pickPlayer, sourceCardId: "Board05");
     return EngineResult.needsInteraction(gs.pending!);
  }
  
  EngineResult _stun(LudoRpgGameState gs) {
     gs.pending = const PendingInteraction(type: PendingType.pickPlayer, sourceCardId: "Board11");
     return EngineResult.needsInteraction(gs.pending!);
  }

  EngineResult _resolvePickPlayer(LudoRpgGameState gs, Map<String, dynamic> input) {
      final targetColorName = input["targetColor"]; // "red", "green"...
      if (targetColorName == null) return EngineResult.fail("No target color provided.");

      // parse color safely
      LudoColor? targetColor;
      try {
          targetColor = LudoColor.values.firstWhere((c) => c.toString().split('.').last == targetColorName);
      } catch (e) {
          return EngineResult.fail("Invalid target color: $targetColorName");
      }
      
      // Prevent picking self? Usually yes for harmful, maybe no for Trade?
      // Spec says "Pick a player to steal from" -> implies opponent.
      if (targetColor == gs.currentPlayer.color) return EngineResult.fail("Cannot target self.");
      
      final source = gs.pending!.sourceCardId;
      
      if (source == "Board11") { // Stun
          final targetPlayer = gs.players.firstWhere((p) => p.color == targetColor);
          targetPlayer.effects.add(ActiveEffect(id: "SkipTurn", duration: 1));
          _completeCardAction(gs);
          return EngineResult.ok(events: ["PLAYER_STUNNED"]);
      }

      if (source == "Movement06") { // Slow
          final targetPlayer = gs.players.firstWhere((p) => p.color == targetColor);
          targetPlayer.effects.add(const ActiveEffect(id: "SlowDice", duration: 1)); // 1 Turn
          _completeCardAction(gs);
          return EngineResult.ok(events: ["PLAYER_SLOWED"]);
      }
      
      if (source == "Board07" || source == "Board08") { // Steal or Trade
           // Next step: pick card from THEIR hand
           // Pass their hand as IDs? Or just the player color and UI resolves?
           // UI needs to know which player's hand to show.
           gs.pending = PendingInteraction(
               type: PendingType.pickCardFromOpponentHand,
               sourceCardId: source,
               data: {"targetColor": targetColorName}
           );
           return EngineResult.needsInteraction(gs.pending!);
      }
      
      if (source == "Board05") { // Robbin Hood
          // Take ENTIRE hand
          final targetHand = gs.hands[targetColor]!;
          final pool = List<String>.from(targetHand);
          targetHand.clear();
          
          if (pool.isEmpty) {
              _completeCardAction(gs);
              return EngineResult.ok(events: ["ROBBIN_HOOD_EMPTY"]);
          }
          
          // Next: Redistribute
          // Identify other players (excluding current and victim)
          // Actually spec says "redistribute among the other two players".
          // In 4 player game: Self, Victim, Other1, Other2.
          // Correct.
          
          gs.pending = PendingInteraction(
              type: PendingType.robinPickCard,
              sourceCardId: source,
              data: {
                  "pool": pool,
                  "victim": targetColorName
              }
          );
           return EngineResult.needsInteraction(gs.pending!);
      }

      return EngineResult.fail("Unknown source for pickPlayer");
  }

  EngineResult _resolvePickOpponentCard(LudoRpgGameState gs, Map<String, dynamic> input) {
      final targetColorName = gs.pending!.data["targetColor"];
      if (targetColorName == null) return EngineResult.fail("Lost target color.");
      
      LudoColor targetColor;
      try {
          targetColor = LudoColor.values.firstWhere((c) => c.toString().split('.').last == targetColorName);
      } catch (e) {
          return EngineResult.fail("Invalid target color: $targetColorName");
      }
      final cardId = input["cardId"] as String;
      
      final targetHand = gs.hands[targetColor]!;
      if (!targetHand.contains(cardId)) return EngineResult.fail("Card not in hand");
      
      targetHand.remove(cardId);
      gs.hands[gs.currentPlayer.color]!.add(cardId);
      
      if (gs.pending!.sourceCardId == "Board08") { // Trade
          // Now must give one back
          gs.pending = PendingInteraction(
              type: PendingType.pickCardFromYourHand,
              sourceCardId: "Board08",
              data: {
                  "newCard": cardId,
                  "targetColor": targetColorName // Preserve target
              }
          );
          return EngineResult.needsInteraction(gs.pending!);
      }
      
      _completeCardAction(gs);
      return EngineResult.ok(events: ["STEAL_COMPLETE"]);
  }
  
  EngineResult _resolvePickYourCard(LudoRpgGameState gs, Map<String, dynamic> input) {
     final cardId = input["cardId"] as String;
     final myHand = gs.hands[gs.currentPlayer.color]!;
     if (!myHand.contains(cardId)) return EngineResult.fail("Card not in your hand");
     
     // Prevent returning the SAME card we just got
     final justGot = gs.pending!.data["newCard"];
     if (cardId == justGot) return EngineResult.fail("Cannot return the card you just took!");
     
     // Target from previous step (stored in pending data)
      final targetColorName = gs.pending!.data["targetColor"];
      if (targetColorName == null) return EngineResult.fail("Lost trade target.");
      
      LudoColor targetColor;
      try {
          targetColor = LudoColor.values.firstWhere((c) => c.toString().split('.').last == targetColorName);
      } catch (e) {
          return EngineResult.fail("Invalid target color for trade: $targetColorName");
      }
     
     myHand.remove(cardId);
     gs.hands[targetColor]!.add(cardId);
     
     _completeCardAction(gs);
     return EngineResult.ok(events: ["TRADE_COMPLETE"]);
  }

  EngineResult _resolveRobinPickCard(LudoRpgGameState gs, Map<String, dynamic> input) {
      final cardIds = List<String>.from(input["cardIds"]); // List of selected IDs
      final pool = List<String>.from(gs.pending!.data["pool"]);
      
      // Validate all exist
      if (cardIds.any((c) => !pool.contains(c))) return EngineResult.fail("Card not in pool");
      
      // Move to next step: pick recipient
      gs.pending = PendingInteraction(
          type: PendingType.robinPickRecipient,
          sourceCardId: "Board05",
          data: {
              ...gs.pending!.data,
              "selectedCards": cardIds // Store LIST
          }
      );
      return EngineResult.needsInteraction(gs.pending!);
  }
      


  EngineResult _resolveRobinPickRecipient(LudoRpgGameState gs, Map<String, dynamic> input) {
      final recipientColorName = input["recipientColor"];
       // Validate: cannot be me, cannot be victim
      final me = gs.currentPlayer.color.toString().split('.').last;
      final victim = gs.pending!.data["victim"];
      
      if (recipientColorName == me || recipientColorName == victim) {
          return EngineResult.fail("Invalid recipient (must be 'other' player)");
      }
      
      final recipientColor = LudoColor.values.firstWhere((c) => c.toString().split('.').last == recipientColorName);

      final cardIds = List<String>.from(gs.pending!.data["selectedCards"]);
      final pool = List<String>.from(gs.pending!.data["pool"]);
      
      for (var cid in cardIds) {
          pool.remove(cid);
          gs.hands[recipientColor]!.add(cid);
      }
      
      if (pool.isEmpty) {
          _completeCardAction(gs);
          return EngineResult.ok(events: ["ROBBIN_HOOD_COMPLETE"]);
      } else {
          // Go back to pick card
           gs.pending = PendingInteraction(
              type: PendingType.robinPickCard,
              sourceCardId: "Board05",
              data: {
                  "pool": pool,
                  "victim": victim
              }
          );
          return EngineResult.needsInteraction(gs.pending!);
      }
  }

  EngineResult _dumpsterDive(LudoRpgGameState gs) {
    if (gs.sharedDiscardPile.isEmpty) return EngineResult.fail("Discard pile empty.");
    gs.pending = PendingInteraction(
        type: PendingType.dumpsterBrowsePick,
        sourceCardId: "Board09",
        data: {"snapshot": List<String>.from(gs.sharedDiscardPile)}
    );
    return EngineResult.needsInteraction(gs.pending!);
  }

  EngineResult _resolveDumpsterPick(LudoRpgGameState gs, Map<String, dynamic> input) {
      if (input["timeout"] == true) {
           _completeCardAction(gs); // Card wasted
           return EngineResult.ok(events: ["DUMPSTER_TIMEOUT"]);
      }
      
      final picked = input["cardId"];
      if (!gs.sharedDiscardPile.contains(picked)) return EngineResult.fail("Card gone.");
      
      gs.sharedDiscardPile.remove(picked);
      gs.hands[gs.currentPlayer.color]!.add(picked);
      
      _completeCardAction(gs);
      return EngineResult.ok(events: ["DUMPSTER_PICKED"]);
  }

  void _completeCardAction(LudoRpgGameState gs, {String? sourceCardId}) {
      if (gs.cardActionsRemaining > 0) gs.cardActionsRemaining--;
      
      // Track last card
      final cardId = sourceCardId ?? gs.pending?.sourceCardId ?? gs.activeCardId;
      if (cardId != null) {
          // Extract template ID if it's an instance ID (e.g. Board02_1234 -> Board02)
          final templateId = cardId.split('_')[0];
          gs.lastCardTemplateIdGlobal = templateId;
          gs.lastCardTemplateIdThisTurn = templateId;
          
          final name = CardLibrary.getById(templateId)?.name ?? templateId;
          gs.toast("$name played!");
      }
      
      gs.pending = null;
      gs.activeCardId = null;
  }
  
  // --- New Card Logic ---
  
  EngineResult _mimic(LudoRpgGameState gs) {
      final toCopy = gs.lastCardTemplateIdThisTurn ?? gs.lastCardTemplateIdGlobal;
      if (toCopy == null) return EngineResult.fail("Nothing to mimic.");
      if (toCopy == "Board10") return EngineResult.fail("Cannot mimic Mimic.");
      
      // Route logic
      // We need to re-invoke playBoardCard or playCard?
      // playBoardCard takes ID.
      // But what if it was a targeted card?
      // playBoardCard handles most now.
      // If it was a targeted card that ISN'T in playBoardCard (e.g. Teleport), we might need `effectRegistry`.
      
      // For now, assume most are routed via playBoardCard or we map templateId -> playBoardCard.
      // If `toCopy` is a movement card, `playBoardCard` covers it now (added above).
      // Except direct effect cards?
      // Actually `playCard` calls `effectRegistry`.
      // `playBoardCard` is just a convenience wrapper for specific IDs.
      
      // Best approach: Call `playBoardCard` with the template ID.
      // If it returns "Unknown", try explicit handler?
      // Updates to `playBoardCard` above include Movement cards now.
      
      gs.toast("Mimiking $toCopy...");
      return playBoardCard(gs, toCopy);
  }

  EngineResult _boots(LudoRpgGameState gs) {
      return _applyDiceBonus(gs, 4, "Movement02");
  }

  EngineResult _dash(LudoRpgGameState gs) {
      return _applyDiceBonus(gs, 6, "Movement03");
  }
  
  EngineResult _applyDiceBonus(LudoRpgGameState gs, int bonus, String sourceId) {
       gs.pending = PendingInteraction(
           type: PendingType.pickDieToDouble, 
           sourceCardId: sourceId
       );
       return EngineResult.needsInteraction(gs.pending!);
  }
  
  // Modified resolver for pickDieToDouble to handle Bonus sources
  EngineResult _resolvePickDieToDouble(LudoRpgGameState gs, Map<String, dynamic> input) {
    final which = input["dieIndex"]; // 0 or 1
    final source = gs.pending!.sourceCardId;
    
    // Bonus Logic
    if (source == "Movement02" || source == "Movement03") {
        final bonus = (source == "Movement02") ? 4 : 6;
        if (which == 0) gs.dice.a!.bonus += bonus;
        else gs.dice.b!.bonus += bonus;
        _completeCardAction(gs);
        return EngineResult.ok(events: ["DICE_BONUS"]);
    }

    // Default Double Logic
    if (which == 0) {
      gs.dice.a?.multiplier = 2;
      gs.dice.a?.showD12 = true;
    } else if (which == 1) {
      gs.dice.b?.multiplier = 2;
      gs.dice.b?.showD12 = true;
    } else {
      return EngineResult.fail("Invalid die selection.");
    }
    _completeCardAction(gs);
    return EngineResult.ok(events: ["DICE_DOUBLED"]);
  }

  EngineResult _jump(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Movement05");
      return EngineResult.needsInteraction(gs.pending!);
  }

  EngineResult _slow(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickPlayer, sourceCardId: "Movement06");
      return EngineResult.needsInteraction(gs.pending!);
  }
  
  // Add Slow logic to _resolvePickPlayer
  // (See below for manual merge or I can rely on existing if loop?
  // I need to update _resolvePickPlayer to handle 'Movement06')
  
  EngineResult _forcePull(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Movement09");
      return EngineResult.needsInteraction(gs.pending!);
  }

  EngineResult _forcePush(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Movement04");
      return EngineResult.needsInteraction(gs.pending!);
  }

  // --- Defence Cards ---

  EngineResult _chainmail(LudoRpgGameState gs) {
      // "on activation and token selection"
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Defence01");
      return EngineResult.needsInteraction(gs.pending!);
  }

  EngineResult _eelArmour(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Defence02");
      return EngineResult.needsInteraction(gs.pending!);
  }

  EngineResult _mirror(LudoRpgGameState gs) {
       gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Defence03");
       return EngineResult.needsInteraction(gs.pending!);
  }
  
  EngineResult _vaccine(LudoRpgGameState gs) {
       // "cures the Pandemic condition for all tokens of that player" -> Immediate?
       // "On activation, it cures..."
       // Doesn't say target token. Says "of that player".
       // So immediate effect.
       for (var t in gs.currentPlayer.tokens) {
           t.effects.removeWhere((e) => e.id == "Pandemic");
       }
       _completeCardAction(gs);
       return EngineResult.ok(events: ["VACCINE_APPLIED"]);
  }

  EngineResult _resurrect(LudoRpgGameState gs) {
      // Check if any dead tokens?
      if (!gs.currentPlayer.tokens.any((t) => t.isDead)) {
          return EngineResult.fail("No dead tokens to deflect...err... resurrect.");
      }
      gs.pending = const PendingInteraction(type: PendingType.selectResurrectTarget, sourceCardId: "Defence05");
      return EngineResult.needsInteraction(gs.pending!);
  }
  
  // --- Attack Cards (Declarations) ---
  // Step 1: Pick SOURCE token
  EngineResult _dagger(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Attack02");
      return EngineResult.needsInteraction(gs.pending!);
  }
  EngineResult _crossbow(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Attack01");
      return EngineResult.needsInteraction(gs.pending!);
  }
  EngineResult _longBow(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Attack04");
      return EngineResult.needsInteraction(gs.pending!);
  }
  EngineResult _magicSpear(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Attack05");
      return EngineResult.needsInteraction(gs.pending!);
  }
  
  EngineResult _stinkBomb(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Defence06");
      return EngineResult.needsInteraction(gs.pending!);
  }

  EngineResult _resist(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Defence04");
      return EngineResult.needsInteraction(gs.pending!);
  }
  EngineResult _laser(LudoRpgGameState gs) {
      // "Render a white beam... on activation from the token"
      // Needs to pick a source token first?
      // "emanating from the token on activation" ->Implies picking a token to fire it?
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Attack03");
      return EngineResult.needsInteraction(gs.pending!);
  }
  EngineResult _pandemic(LudoRpgGameState gs) {
      // "player token is infected" -> Pick own token?
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Attack06");
      return EngineResult.needsInteraction(gs.pending!);
  }

  
  EngineResult _astralLink(LudoRpgGameState gs) {
      gs.pending = const PendingInteraction(type: PendingType.pickToken1, sourceCardId: "Movement01");
      return EngineResult.needsInteraction(gs.pending!);
  }

  // --- Token Resolvers ---
  EngineResult _resolvePickToken1(LudoRpgGameState gs, Map<String, dynamic> input) {
      final tokenId = input["tokenId"];
      final source = gs.pending!.sourceCardId;
      
      // Jump: Pick own token, simple resolve
    if (source == "Movement05") {
        final token = _findTokenById(gs, tokenId);
        if (token == null) return EngineResult.fail("Invalid token");
        if (token.color != gs.currentPlayer.color) return EngineResult.fail("Pick your own token");
        if (token.isDead || token.isFinished || token.isInBase) return EngineResult.fail("Token ineligible");
        
        teleportToken(gs, token, 2); // +2 tiles
        _completeCardAction(gs);
        return EngineResult.ok(events: ["JUMPED"]);
    }
    
    // Defence Cards
    if (source == "Defence01" || source == "Defence02" || source == "Defence03") {
        final token = _findTokenById(gs, tokenId);
        if (token == null) return EngineResult.fail("Invalid token");
        if (token.color != gs.currentPlayer.color) return EngineResult.fail("Pick your own token");
        if (token.isDead || token.isFinished || token.isInBase) return EngineResult.fail("Token ineligible");
        
        String effectId;
        String event;
        if (source == "Defence01") { effectId = "Chainmail"; event = "CHAINMAIL_EQUIPPED"; token.hp = 2; } // HP+1
        else if (source == "Defence02") { effectId = "EelArmour"; event = "EEL_ARMOUR_EQUIPPED"; token.hp = 2; } // HP+1 + Thorns
        else if (source == "Defence06") { effectId = "StinkBomb"; event = "STINK_BOMB_READY"; } 
        else if (source == "Defence04") { effectId = "Resist"; event = "RESIST_READY"; }
        else { effectId = "Mirror"; event = "MIRROR_EQUIPPED"; } // Status Only
        
        token.effects.add(ActiveEffect(id: effectId, duration: 999)); // Permanent until damaged/used
        _completeCardAction(gs);
        return EngineResult.ok(events: [event]);
    }
    
    // Attack Source Selection (Laser / Pandemic / Spear / etc if they need source FIRST)
    // Attack03 = Laser, Attack06 = Pandemic
    // And now Attack02, Attack01, Attack04, Attack05
    if (source.startsWith("Attack")) {
         final token = _findTokenById(gs, tokenId);
         if (token == null) return EngineResult.fail("Invalid token");
         if (token.color != gs.currentPlayer.color) return EngineResult.fail("Pick your own token");
         if (token.isDead || token.isFinished || token.isInBase) return EngineResult.fail("Token ineligible (must be on board)");
         
         if (source == "Attack06") { // Pandemic
             token.effects.add(const ActiveEffect(id: "Pandemic", duration: 999)); // Until cured
             _completeCardAction(gs);
             return EngineResult.ok(events: ["PANDEMIC_INFECTED"]);
         } else if (source == "Attack03") { // Laser
             // Laser Rule: Choose Axis (Horizontal/Vertical)
             gs.pending = PendingInteraction(
                 type: PendingType.pickAttackDirection,
                 sourceCardId: source,
                 data: {"sourceId": tokenId}
             );
             return EngineResult.needsInteraction(gs.pending!);
         } else {
             // Weapon Attacks: Dagger, Crossbow, LongBow, Spear
             // Calculate valid targets first? or let UI do it?
             // Helper logic is now available.
             
             int range = 1;
             if (source == "Attack01") range = 3; // Crossbow
             if (source == "Attack04") range = 6; // LongBow
             // Magic Spear is Range 1 + Special Pierce
             
             gs.pending = PendingInteraction(
                  type: PendingType.pickAttackTarget, // Was selectAttackTarget, unifying names
                  sourceCardId: source,
                  data: {"sourceId": tokenId, "range": range}
             );
             return EngineResult.needsInteraction(gs.pending!);
         }
    }
    
    // For Pull/Push/Link: This was Token A. Now Pick Token B.
      gs.pending = PendingInteraction(
          type: PendingType.pickToken2,
          sourceCardId: source,
          data: {"aId": tokenId}
      );
      return EngineResult.needsInteraction(gs.pending!);
  }
  
  EngineResult _resolvePickToken2(LudoRpgGameState gs, Map<String, dynamic> input) {
       final bId = input["tokenId"];
       final aId = gs.pending!.data["aId"];
       final source = gs.pending!.sourceCardId;
       
       final a = _findTokenById(gs, aId);
       final b = _findTokenById(gs, bId);
       if (a == null || b == null) return EngineResult.fail("Invalid tokens");
       
       if (source == "Movement09" || source == "Movement04") {
           // Both must be on main for this math
           if (!a.isOnMain || !b.isOnMain) return EngineResult.fail("Both tokens must be on Main track");
           
           final aAbs = toAbsoluteMainIndexFromRelative(a);
           final bAbs = toAbsoluteMainIndexFromRelative(b);
           
           final cw = (aAbs - bAbs + 52) % 52;
           final ccw = (bAbs - aAbs + 52) % 52;
           
           bool towardA = cw <= ccw;
           if (source == "Movement04") towardA = !towardA; // Invert
           
           final step = 3;
           final newBAbs = towardA 
               ? (bAbs + step) % 52 
               : (bAbs - step + 52) % 52;
               
           setTokenRelativeFromAbsolute(b, newBAbs);
           _completeCardAction(gs);
           return EngineResult.ok(events: ["FORCE_MOVE"]);
       }
       
       if (source == "Movement01") { // Astral Link
           // Link A (source) to B (victim)
           // Add effect to Player A (owner of A)
           final playerA = gs.players.firstWhere((p) => p.color == a.color);
           playerA.effects.add(ActiveEffect(
               id: "AstralLink", 
               duration: 1, 
               data: {"aId": aId, "bId": bId}
           ));
           
           _completeCardAction(gs);
           return EngineResult.ok(events: ["LINK_ESTABLISHED"]);
       }
       
       return EngineResult.fail("Unknown logic");
  }
  
  // Duplicate _findTokenById removed.

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
      
      
      // Check for kills after teleport!
      _handleCollisions(gs, t, []);
      
      _checkWinCondition(gs, t.color);
  }

  EngineResult _resolveResurrectTarget(LudoRpgGameState gs, Map<String, dynamic> input) {
      final tokenId = input["tokenId"];
      final token = _findTokenById(gs, tokenId);
      
      if (token == null) return EngineResult.fail("Invalid token");
      if (token.color != gs.currentPlayer.color) return EngineResult.fail("Pick your own token");
      if (!token.isDead) return EngineResult.fail("Token is not dead");
      
      // Resurrect!
      token.status = TokenStatus.alive;
      token.position = -1; // Base
      token.hp = 1; // Reset HP
      token.effects.clear(); // Reset effects
      
      _completeCardAction(gs);
      return EngineResult.ok(events: ["TOKEN_RESURRECTED"]);
  }
  
  EngineResult _resolveAttackTarget(LudoRpgGameState gs, Map<String, dynamic> input) {
      final targetId = input["targetId"];
      final sourceId = gs.pending!.data["sourceId"];
      final range = gs.pending!.data["range"] as int;
      final sourceCard = gs.pending!.sourceCardId;
      
      final target = _findTokenById(gs, targetId);
      final source = _findTokenById(gs, sourceId);
      
      if (target == null || source == null) return EngineResult.fail("Invalid tokens");
      
      // Validate Logic based on Card Type
      bool isValid = false;
      
      if (sourceCard == "Attack05") {
          // Magic Spear: Check Grid Adjacency
          // Or Ring Range 1
          final ringTargets = _targetsInRingRange(gs: gs, attacker: source, range: 1, forward: true)
              ..addAll(_targetsInRingRange(gs: gs, attacker: source, range: 1, forward: false));
              
          if (ringTargets.any((t) => t.id == target.id)) {
              isValid = true;
          } else {
              // Check Grid Adjacency
              final gridTargets = _targetsInGridAdjacency(gs, source);
              if (gridTargets.any((t) => t.id == target.id)) isValid = true;
          }
      } else {
          // Dagger, Crossbow, LongBow
          // Ring Range Forward or Backward
          final fwd = _targetsInRingRange(gs: gs, attacker: source, range: range, forward: true);
          final bwd = _targetsInRingRange(gs: gs, attacker: source, range: range, forward: false);
          
          if (fwd.any((t) => t.id == target.id) || bwd.any((t) => t.id == target.id)) {
              isValid = true;
          }
      }
      
      if (!isValid) return EngineResult.fail("Target out of range or invalid.");
      
      // Valid Attack
      _applyDamage(gs, target: target, amount: 1, attacker: source, isMelee: (range==1), events: ["ATTACK_HIT"]);
      
      _completeCardAction(gs);
      return EngineResult.ok(events: ["ATTACK_COMPLETE"]);
  }
  
  EngineResult _resolveAttackDirection(LudoRpgGameState gs, Map<String, dynamic> input) {
      final axis = input["axis"]; // "horizontal" or "vertical"
      if (axis != "horizontal" && axis != "vertical") return EngineResult.fail("Invalid axis");
      
      final sourceId = gs.pending!.data["sourceId"];
      final source = _findTokenById(gs, sourceId);
      if (source == null) return EngineResult.fail("Invalid source");
      
      _fireLaserAxis(gs, source, axis == "horizontal");
      
      _completeCardAction(gs);
      return EngineResult.ok(events: ["LASER_FIRED"]); // UI should show beam
  }
  
  void _fireLaserAxis(LudoRpgGameState gs, LudoToken source, bool horizontal) {
       final aCell = _tokenGridCell(source);
       if (aCell == null) return;
       
       // Visual Effect
       gs.visualEffects.add(LaserVisualEffect(origin: aCell, horizontal: horizontal));
       
       // Collect tokens on same line
       final line = <(LudoToken, Point<int>)>[];
       for (final p in gs.players) {
           for (final t in p.tokens) {
               if (t.isDead || t.isFinished || t.isInBase) continue;
               if (t.color == source.color) continue; // No friendly fire
               
               final c = _tokenGridCell(t);
               if (c == null) continue;
               
               if (horizontal && c.y == aCell.y) line.add((t, c));
               if (!horizontal && c.x == aCell.x) line.add((t, c));
           }
       }
       
       // Sort by distance from source
       int dist(Point<int> c) => horizontal ? (c.x - aCell.x) : (c.y - aCell.y);
       
       // Positive Direction
       final positive = line.where((e) => dist(e.$2) > 0).toList()
           ..sort((a,b) => dist(a.$2).compareTo(dist(b.$2)));
           
       // Negative Direction
       final negative = line.where((e) => dist(e.$2) < 0).toList()
           ..sort((a,b) => dist(b.$2).compareTo(dist(a.$2))); // closest first (largest negative)
           
       void scan(List<(LudoToken, Point<int>)> ray) {
           for (final e in ray) {
               if (e.$1.hasEffect("Mirror")) {
                   gs.toast("Laser blocked by Mirror on ${e.$1.id}!");
                   return; // Stop ray
               }
               _applyDamage(gs, target: e.$1, amount: 1, attacker: source, isMelee: false, events: ["LASER_HIT"]);
           }
       }
       
       scan(positive);
       scan(negative);
  }
  
  void _fireLaser(LudoRpgGameState gs, LudoToken source) {
      // Replaced by _resolveAttackDirection and _fireLaserAxis
  }
  
  void _fireLaserRay(LudoRpgGameState gs, LudoToken source, int dir) {
      // Replaced by _fireLaserAxis
  }
  
  // Helper for checking absolute pos of a theoretical position (for Laser)
  int toAbsoluteMainIndexFromRelative(LudoToken t, {int? overridePos}) {
      final pos = overridePos ?? t.position;
      if (pos < 0 || pos >= 52) return -999; 
      // rel = (abs - offset) % 52
      // abs = (rel + offset) % 52
      final offset = _startOffsetAbs[t.color]!;
      return (pos + offset) % 52;
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
  // Helper to set token position from absolute main index (0..51)
  void setTokenRelativeFromAbsolute(LudoToken t, int abs) {
      final offset = _startOffsetAbs[t.color]!;
      // abs = (rel + offset) % 52
      // rel = (abs - offset) % 52
      // Handle negative modulo correctly in Dart: (a % n + n) % n
      final rel = (abs - offset + mainTrackLen) % mainTrackLen;
      t.position = rel;
  }

  void endTurn(LudoRpgGameState gs) {
    // New turn -> clear "this turn" card memory
    gs.lastCardTemplateIdThisTurn = null;
    
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
      
      // Rotate to next player
      gs.currentPlayerIndex = (gs.currentPlayerIndex + 1) % gs.players.length;
      
      // Removed auto-skip logic for Stunned players.
      // Stunned players now start their turn, but UI restricts them.
      // Stun duration should be decremented or effect removed when they END this turn.
      // But `rotateTurn` is called at END of previous player.
      
      // We don't remove SkipTurn here. We let them start turn.
      // We need to ensure SkipTurn is removed AFTER they acknowledge it (End Turn).
      
      gs.dice.reset();
      gs.cardActionsRemaining = 2;
      
      // Check for Pandemic Infection
      bool anyInfected = false;
      for (final t in gs.currentPlayer.tokens) {
          if (t.hasEffect("PandemicInfected")) {
              anyInfected = true;
              break;
          }
      }
      
      if (anyInfected) {
          gs.phase = TurnPhase.pandemicSurvival;
          gs.toast("⚠️ Survival Roll Needed!");
      } else {
          gs.phase = TurnPhase.awaitRoll;
      }
  }

   // ---------- Combat hooks (no implementation yet) ----------
  /// Movement restriction you stated ("opponents cannot enter your home stretch")
  /// is inherently satisfied by the RELATIVE position model:
  /// tokens only ever have their OWN 52..57 stretch.
  ///
  /// Ranged attacks and "cannot be attacked on star tiles" will be applied in combat resolution.
  ///
  /// This helper will be used later in attack rules:
  @override
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
