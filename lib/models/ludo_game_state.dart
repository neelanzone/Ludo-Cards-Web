import 'package:flutter/material.dart'; // For LudoColor if needed, or import models?
// Actually simpler to keep dependencies minimal.
// We need LudoPlayer, TurnPhase. 

import '../models.dart'; // Circular? No, models exports this. 
// But we need LudoPlayer definition. 
// LudoPlayer is in models.dart (user defined earlier).
// Actually models.dart usually defines LudoPlayer but I saw it in `models.dart` view earlier.

enum TurnPhase {
  awaitRoll,
  awaitAction, // move/spawn
  selectingTarget, // <--- NEW: Card targeting
  resolvingChoice, // <--- NEW: Generic choice resolution (Dumpster Dive etc)
  pandemicSurvival, // <--- NEW: Survival roll phase
  gameOver,
  ended, // Maybe merge with gameOver? 'ended' was used for... turn ended? 
         // Actually 'ended' isn't explicitly used much in my code except _handleTokenTap check.
         // Let's keep 'ended' for turn end and add 'gameOver' for match end.
}

enum PendingType {
  none,

  // Dice
  pickDieToDouble,
  pickDieToReroll,
  confirmRerollChoiceSingle,
  confirmRerollChoiceBoth,

  // Player selection
  pickPlayer,

  // Hand selection
  pickCardFromOpponentHand,
  pickCardFromYourHand,

  // Robin Hood redistribution
  robinPickCard,        // select a card from stolen pool
  robinPickRecipient,   // select recipient color

  // Dumpster Dive
  dumpsterBrowsePick,   // choose card before timer ends

  // Token selection
  pickToken1,
  pickToken2,

  // Attack/Defence
  selectResurrectTarget,
  pickAttackerToken,
  pickAttackDirection,
  pickAttackTarget,
  selectAttackTarget, // Alias for pickAttackTarget (legacy/refactor mixup fix)
  


}

class PendingInteraction {
  final PendingType type;
  final String sourceCardId; // e.g. "Board02"
  final Map<String, dynamic> data; // payload
  const PendingInteraction({
    required this.type,
    required this.sourceCardId,
    this.data = const {},
  });
}

class DieState {
  int value;
  bool used;

  // UI/Rules metadata
  bool doubled;     // show 2× badge (or d12)
  int multiplier;   // 1 or 2 (future-proof)
  bool showD12;     // UI flag for d12 display
  int? prevValue;   // For reroll "keep old/new" logic
  int bonus;        // +4 / +6 etc

  DieState(this.value)
      : used = false,
        doubled = false,
        multiplier = 1,
        showD12 = false,
        bonus = 0;

  int get effectiveValue => (value * multiplier) + bonus;
        
  // Reset modifiers
  void clearModifiers() {
      doubled = false;
      multiplier = 1;
      showD12 = false;
      prevValue = null;
      bonus = 0;
  }
}

class DicePair {
  DieState? a;
  DieState? b;

  bool get rolled => a != null && b != null;
  
  // Helpers to check usage
  bool get aUsed => a?.used ?? false;
  bool get bUsed => b?.used ?? false;
  
  bool get bothUnused => rolled && !aUsed && !bUsed;
  bool get anyUnused => rolled && (!aUsed || !bUsed);

  // Effective values
  int get aEff => a?.effectiveValue ?? 0;
  int get bEff => b?.effectiveValue ?? 0;

  void reset() {
    a = null;
    b = null;
  }
}

class LudoRpgGameState {
  final List<LudoPlayer> players;

  int currentPlayerIndex = 0;
  TurnPhase phase = TurnPhase.awaitRoll;
  LudoColor? winner;


  // Two dice
  final DicePair dice = DicePair();

  // Each turn: 2 card actions
  int cardActionsRemaining = 2;

  final Map<LudoColor, int> turnsCompleted = {
    for (final c in LudoColor.values) c: 0,
  };

  bool isFirstTurnFor(LudoColor c) => (turnsCompleted[c] ?? 0) == 0;
  
  // Card System State
  String? activeCardId; // The card currently waiting for a target
  
  // Shared Deck State (Engine Authoritative)
  // These store Card Instance IDs (strings)
  final List<String> sharedDrawPile = [];
  final List<String> sharedDiscardPile = [];
  final Map<LudoColor, List<String>> hands = {}; 
  
  PendingInteraction? pending; // <--- The new pending system
  
  // Toast / Notification System
  final List<String> toastQueue = [];
  void toast(String msg) => toastQueue.add(msg);
  
  // Mimic State
  String? lastCardTemplateIdGlobal;
  String? lastCardTemplateIdThisTurn;

  LudoRpgGameState({required this.players}) {
     for (var p in players) {
         hands[p.color] = [];
     }
  }

  LudoPlayer get currentPlayer => players[currentPlayerIndex];

  // Visual Effects Queue
  final List<VisualEffect> visualEffects = [];
  
  void cleanupExpiredEffects() {
      visualEffects.removeWhere((e) => e.isExpired);
  }
}
