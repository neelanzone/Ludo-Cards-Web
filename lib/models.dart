import 'package:flutter/material.dart';

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

class LudoToken {
  final String id;
  final LudoColor color;
  /// -1: Base, 0-51: Main Track, 52-57: Home Stretch, 99: Home/Goal
  int position; 
  
  LudoToken({
    required this.id,
    required this.color,
    this.position = -1,
  });
}

class LudoPlayer {
  final String id;
  final LudoColor color;
  final List<LudoToken> tokens;

  LudoPlayer({
    required this.id,
    required this.color,
    required this.tokens,
  });
}

