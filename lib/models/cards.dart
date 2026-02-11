import 'package:flutter/material.dart';

enum TargetType {
  none,       // Global effect (e.g. Double Roll, Shuffle)
  self,       // Self player (often implicit, but good for clarity)
  opponent,   // Target an opponent player (e.g. Steal Card)
  tokenSelf,  // Target one of my tokens (e.g. Boost, Jump)
  tokenEnemy, // Target an enemy token (e.g. Swap, Push, Laser start)
  tokenAny,   // Any token (e.g. Swap typically takes two, but we might simplify)
  tile,       // Target a specific tile (e.g. Teleport)
}

enum CardEffectType {
  // --- Dice Modifiers ---
  modifyRoll,       // +X to roll
  setRoll,          // Force roll to X (or max)
  doubleDie,        // Double single die (requires choice)
  doubleBoth,       // Double both dice
  reroll,           // Rolling again (Single)
  reroll2x,         // Rolling again (Both)

  // --- Board / Hand Ops ---
  stealCard, 
  tradeCard, 
  stealDeck, 
  rotateDecks,      // Shuffle
  dumpsterDive,     // Draw from discard

  // --- Turn Ops ---
  skipTurn,         // Stun/Skip target
  extraTurn,        // Sands of Time
  restartTurnNow,   // Immediate turn restart

  // --- Movement ---
  teleport,         // Move to specific tile (0-51) or relative
  jump,             // Hop over
  swapPos,          // Swap positions with target
  forceMove,        // Push/Pull (value = distance, + away, - close)
  astralLink,       // Sync movement (status)

  // --- Combat ---
  modifyAttackRange, // Buff for turn
  laser,            // AoE Line attack
  infect,           // Status effect
  
  // --- Defense / Status ---
  cure,             // Remove statuses
  resurrect,        // Spawn dead token
  applyShield,      // Chainmail
  applyMirror,      // Reflect damage
  applyResist,      // Cancel action
}

class CardTemplate {
  final String id;
  final String name;
  final String description;
  final CardEffectType effectType;
  final int value;          // Generic magnitude (Range +2, Move +4, Distance 3)
  final TargetType targetType;
  final bool isReaction;    // If true, played as interrupt (or buff in MVP)
  
  const CardTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.effectType,
    this.value = 0,
    required this.targetType,
    this.isReaction = false,
  });
}
