import '../models.dart';
import 'effect_types.dart';
import 'handlers/dice_effects.dart';
import 'handlers/turn_effects.dart';
import 'handlers/move_effects.dart';
import 'handlers/deck_effects.dart';

final Map<CardEffectType, EffectHandler> effectRegistry = {
  // Dice
  CardEffectType.modifyRoll: modifyRollEffect,
  CardEffectType.doubleDie: doubleDieEffect,
  CardEffectType.doubleBoth: doubleBothEffect,
  CardEffectType.reroll: rerollEffect,

  // Turn
  CardEffectType.extraTurn: extraTurnEffect,
  CardEffectType.skipTurn: skipTurnEffect,
  CardEffectType.restartTurnNow: restartTurnNowEffect,

  // Movement
  CardEffectType.teleport: teleportEffect,
  CardEffectType.swapPos: swapPosEffect,
  
  // Deck
  CardEffectType.dumpsterDive: dumpsterDiveHandler,
};
