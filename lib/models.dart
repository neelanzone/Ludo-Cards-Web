import 'package:flutter/material.dart';

export 'models/core.dart';
export 'models/ludo_game_state.dart';
export 'models/cards.dart';
export 'data/card_library.dart';
// export 'models/ludo_game_state.dart'; // Avoid cycle if ludo_game_state imports this?
// Actually, ludo_game_state imports core.dart now.
// If models.dart exports ludo_game_state.dart, and ludo_game_state imports core.dart (available via models.dart if we import models.dart).

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
