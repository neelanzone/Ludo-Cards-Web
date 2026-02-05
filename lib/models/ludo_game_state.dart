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
  ended,
}

class DicePair {
  int? a;
  int? b;
  bool aUsed = false;
  bool bUsed = false;

  bool get rolled => a != null && b != null;
  bool get bothUnused => rolled && !aUsed && !bUsed;
  bool get anyUnused => rolled && (!aUsed || !bUsed);

  void reset() {
    a = null;
    b = null;
    aUsed = false;
    bUsed = false;
  }
}

class LudoRpgGameState {
  final List<LudoPlayer> players;

  int currentPlayerIndex = 0;
  TurnPhase phase = TurnPhase.awaitRoll;

  // Two dice
  final DicePair dice = DicePair();

  // Each turn: 2 card actions
  int cardActionsRemaining = 2;
  
  // Card System State
  String? activeCardId; // The card currently waiting for a target

  LudoRpgGameState({required this.players});

  LudoPlayer get currentPlayer => players[currentPlayerIndex];
}
