import 'package:flutter/material.dart';

export 'models/ludo_game_state.dart';
export 'models/cards.dart';
export 'data/card_library.dart';

// Legacy CardModel (Will replace later)
enum CardType {
  attack,
  defense,
  movement,
  manipulation,
}

class CardModel {
  final String id;
  final String title;
  final CardType type;
  final Color color;
  final int value;

  const CardModel({
    required this.id,
    required this.title,
    required this.type,
    required this.color,
    required this.value,
  });

  static Color getColorForType(CardType type) {
    switch (type) {
      case CardType.attack:
        return Colors.redAccent;
      case CardType.defense:
        return Colors.blueAccent;
      case CardType.movement:
        return Colors.greenAccent;
      case CardType.manipulation:
        return Colors.purpleAccent;
    }
  }
}

enum LudoColor {
  red,
  green,
  yellow,
  blue,
}

enum TokenStatus { alive, dead, finished }

class ActiveEffect {
  final String id; // e.g. "Shield", "Stun"
  final int duration; // Turns remaining
  final int value; // e.g. +4 range, or boolean equivalent
  
  const ActiveEffect({required this.id, required this.duration, this.value = 0});
}

class LudoToken {
  final String id;
  final LudoColor color;

  /// **STRICT RELATIVE POSITIONING**
  /// -1: Base (Safe)
  /// 0..51: Main Track (Relative to THIS token's start color)
  /// 52..57: Home Stretch (Relative, 0th step is 52)
  /// 99: Goal/Finished
  int position;
  TokenStatus status;
  
  // Active Buffs/Debuffs (Shield, Poison, etc.)
  List<ActiveEffect> effects;

  LudoToken({
    required this.id,
    required this.color,
    this.position = -1,
    this.status = TokenStatus.alive,
    List<ActiveEffect>? effects,
  }) : effects = effects ?? [];

  bool get isInBase => position == -1;
  bool get isOnMain => position >= 0 && position < 52;
  bool get isInHomeStretch => position >= 52 && position <= 57;
  bool get isFinished => status == TokenStatus.finished || position == 99;
  bool get isDead => status == TokenStatus.dead;
  
  bool hasEffect(String effectId) => effects.any((e) => e.id == effectId);
}

class LudoPlayer {
  final String id;
  final LudoColor color;
  final List<LudoToken> tokens;
  
  // Player-level effects (Stunned/Skipped, Extra Turn, etc.)
  List<ActiveEffect> effects; 

  LudoPlayer({
    required this.id,
    required this.color,
    required this.tokens,
    List<ActiveEffect>? effects,
  }) : effects = effects ?? [];
  
  bool hasEffect(String effectId) => effects.any((e) => e.id == effectId);
}

