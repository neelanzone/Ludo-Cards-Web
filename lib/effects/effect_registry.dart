import '../models.dart';
import 'effect_types.dart';
import 'handlers/dice_effects.dart';
import 'handlers/turn_effects.dart';
import 'handlers/move_effects.dart';
import 'handlers/move_effects.dart';
import 'handlers/deck_effects.dart';
import 'handlers/board_handler_adapter.dart';

final Map<CardEffectType, EffectHandler> effectRegistry = {
  // Dice (Board Cards)
  // Dice (Board Cards)
  CardEffectType.modifyRoll: boardCardAdapter, // Boots, Dash, Slow -> Managed by Engine
  CardEffectType.doubleDie: boardCardAdapter,
  CardEffectType.doubleBoth: boardCardAdapter,
  CardEffectType.reroll: boardCardAdapter,
  CardEffectType.reroll2x: boardCardAdapter,

  // Board / Interaction
  CardEffectType.rotateDecks: boardCardAdapter,
  CardEffectType.stealCard: boardCardAdapter,
  CardEffectType.tradeCard: boardCardAdapter,
  CardEffectType.stealDeck: boardCardAdapter,
  
  // Turn
  CardEffectType.extraTurn: extraTurnEffect,
  CardEffectType.skipTurn: boardCardAdapter, // Stun
  CardEffectType.restartTurnNow: restartTurnNowEffect,

  // Movement
  CardEffectType.teleport: teleportEffect,
  CardEffectType.teleport: teleportEffect,
  CardEffectType.jump: boardCardAdapter,
  CardEffectType.swapPos: swapPosEffect,
  CardEffectType.forceMove: boardCardAdapter, 
  CardEffectType.astralLink: boardCardAdapter,
  
  
  // Deck
  CardEffectType.dumpsterDive: boardCardAdapter,
};
