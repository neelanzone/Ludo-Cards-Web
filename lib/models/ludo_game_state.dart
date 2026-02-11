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
  gameOver,
  ended, // Maybe merge with gameOver? 'ended' was used for... turn ended? 
         // Actually 'ended' isn't explicitly used much in my code except _handleTokenTap check.
         // Let's keep 'ended' for turn end and add 'gameOver' for match end.
}

enum PendingChoiceType {
  none,
  dumpsterPickOne,
}

class PendingChoice {
  final PendingChoiceType type;
  final String sourceCardId; // the card being played, e.g. "DumpsterDive"
  final List<String> options; // e.g. 5 discard card instance IDs
  const PendingChoice({
    required this.type,
    this.sourceCardId = "", // Default empty string or make optional in test
    required this.options,
  });
}

class DieState {
  int value;
  bool used;

  // UI/Rules metadata
  bool doubled;     // show 2× badge (or d12)
  int multiplier;   // 1 or 2 (future-proof)

  DieState(this.value)
      : used = false,
        doubled = false,
        multiplier = 1;
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
  
  PendingChoice? pendingChoice;

  LudoRpgGameState({required this.players}) {
     for (var p in players) {
         hands[p.color] = [];
     }
  }

  LudoPlayer get currentPlayer => players[currentPlayerIndex];
}
