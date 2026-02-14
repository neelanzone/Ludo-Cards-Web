import 'package:ludo_rpg/models/cards.dart';

class CardLibrary {
  static const List<CardTemplate> allCards = [
    // --- BOARD / GLOBAL ---
    CardTemplate(
      id: 'Board02', 
      name: 'Double It', 
      description: 'Double any one of your dice rolls',
      effectType: CardEffectType.doubleDie, 
      value: 1, // 1 die
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board01', 
      name: 'Double It 2x', 
      description: 'Double both of your dice rolls',
      effectType: CardEffectType.doubleBoth, 
      value: 2, // both dice
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board04', 
      name: 'Reroll', 
      description: 'Reroll one dice and choose which roll to take',
      effectType: CardEffectType.reroll, 
      value: 1, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board03', 
      name: 'Reroll 2x', 
      description: 'Reroll both dice and choose which roll to take',
      effectType: CardEffectType.reroll, 
      value: 2, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board12', 
      name: 'Shuffle', 
      description: 'All players give their action card decks to the player on their left',
      effectType: CardEffectType.rotateDecks, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board07', 
      name: 'Steal', 
      description: 'Steal a card of your choice from a player',
      effectType: CardEffectType.stealCard, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board08', 
      name: 'Trade', 
      description: 'Exchange a card logic (To be imp.)', // Simplified for now
      effectType: CardEffectType.tradeCard, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board05', 
      name: "Robbin' Hood", 
      description: 'Steal a whole deck from a player',
      effectType: CardEffectType.stealDeck, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board11', 
      name: 'Stun', 
      description: 'A player of your choice is stunned and skips their turn',
      effectType: CardEffectType.skipTurn, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board09', 
      name: 'Dumpster Dive', 
      description: 'Pick one card from the discard pile',
      effectType: CardEffectType.dumpsterDive, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board06', 
      name: 'Sands of Time', 
      description: 'Take your next turn immediately',
      effectType: CardEffectType.restartTurnNow, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Board10', 
      name: 'Mimic', 
      description: 'Copy the last card played',
      effectType: CardEffectType.modifyRoll, // Routes through boardCardAdapter → _mimic
      targetType: TargetType.none,
    ),

    // --- MOVEMENT ---
    CardTemplate(
      id: 'Movement02', 
      name: 'Boots of Speed', 
      description: 'Add +4 to any one of your movement dice roll',
      effectType: CardEffectType.modifyRoll, 
      value: 4, 
      targetType: TargetType.none, 
    ),
    CardTemplate(
      id: 'Movement03', 
      name: 'Dash', 
      description: 'Add +6 to any one of your movement dice roll',
      effectType: CardEffectType.modifyRoll, 
      value: 6, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Movement08', 
      name: 'Teleport', 
      description: 'Teleport up to 6 tiles forward or backward',
      effectType: CardEffectType.teleport, 
      value: 6,
      targetType: TargetType.tokenSelf, // Target self pawn to teleport
    ),
    CardTemplate(
      id: 'Movement05', 
      name: 'Jump', 
      description: 'Jump over a tile',
      effectType: CardEffectType.jump, 
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Movement07', 
      name: 'Swap', 
      description: 'Swap any pawn on the board with any pawn of your choice',
      effectType: CardEffectType.swapPos, 
      targetType: TargetType.tokenEnemy, // Select Enemy, Swap with Self (simplification or 2-step)
    ),
    CardTemplate(
      id: 'Movement06', 
      name: 'Slow', 
      description: 'Reduce opponent movement by half',
      effectType: CardEffectType.modifyRoll, // Negative logic
      value: -50, // Flag for 50%
      targetType: TargetType.none,
      isReaction: true,
    ),
    CardTemplate(
      id: 'Movement09', 
      name: 'Force Pull', 
      description: 'Pull any pawn closer to your pawn by 3 tiles',
      effectType: CardEffectType.forceMove, 
      value: -3, // Negative distance = pull closer
      targetType: TargetType.none,
    ),
    CardTemplate(
      id: 'Movement01', 
      name: 'Astral Link', 
      description: 'Link your pawn to opponent',
      effectType: CardEffectType.astralLink, 
      targetType: TargetType.none,
       isReaction: true,
    ),
    CardTemplate(
      id: 'Movement04', 
      name: 'Force Push', 
      description: 'Push any pawn away from your pawn by 3 tiles',
      effectType: CardEffectType.forceMove, 
      value: 3, 
      targetType: TargetType.none,
    ),

    // --- ATTACK ---
    CardTemplate(
      id: 'Attack02', 
      name: 'Dagger', 
      description: 'Increases attack range up to 1 tile',
      effectType: CardEffectType.modifyAttackRange, 
      value: 1, 
      targetType: TargetType.none, // Targeting handled by pickToken1 pending
    ),
    CardTemplate(
      id: 'Attack01', 
      name: 'Crossbow', 
      description: 'Increases attack range up to 3 tiles',
      effectType: CardEffectType.modifyAttackRange, 
      value: 3, 
      targetType: TargetType.none, // Targeting handled by pickToken1 pending
    ),
    CardTemplate(
      id: 'Attack04', 
      name: 'Long Bow', 
      description: 'Increases attack range up to 6 tiles',
      effectType: CardEffectType.modifyAttackRange, 
      value: 6, 
      targetType: TargetType.none, // Targeting handled by pickToken1 pending
    ),
     CardTemplate(
      id: 'Attack05', 
      name: 'Magic Spear', 
      description: 'Increases attack range up to 2 tiles, through walls',
      effectType: CardEffectType.modifyAttackRange, 
      value: 2, 
      targetType: TargetType.none, // Targeting handled by pickToken1 pending
    ),
    CardTemplate(
      id: 'Attack03', 
      name: 'Laser', 
      description: 'Attacks all pawns in a single line',
      effectType: CardEffectType.laser, 
      targetType: TargetType.none, // Targeting handled by pickToken1 pending
    ),
    CardTemplate(
      id: 'Attack06', 
      name: 'Pandemic', 
      description: 'Infects the pawn',
      effectType: CardEffectType.infect, 
      targetType: TargetType.none, // Targeting handled by pickToken1 pending
    ),

    // --- DEFENSE ---
    CardTemplate(
      id: 'Defence07', 
      name: 'Vaccine', 
      description: 'Cures any infections',
      effectType: CardEffectType.cure, 
      targetType: TargetType.tokenSelf,
      isReaction: true,
    ),
    CardTemplate(
      id: 'Defence05', 
      name: 'Resurrect', 
      description: 'Bring a pawn back on the board',
      effectType: CardEffectType.resurrect, 
      targetType: TargetType.none, // Dead token selection handled by selectResurrectTarget pending
    ),
    CardTemplate(
      id: 'Defence06', 
      name: 'Stink Bomb', 
      description: 'Distract an attack on you',
      effectType: CardEffectType.applyResist, 
      targetType: TargetType.tokenSelf,
      isReaction: true,
    ),
    CardTemplate(
      id: 'Defence01', 
      name: 'Chainmail', 
      description: 'Defends against any attack except Laser',
      effectType: CardEffectType.applyShield, 
      targetType: TargetType.tokenSelf,
      isReaction: true,
    ),
     CardTemplate(
      id: 'Defence02', 
      name: 'Eel Armour', 
      description: 'Defends + Damage attacker',
      effectType: CardEffectType.applyShield, // + Thorn logic
      value: 1,
      targetType: TargetType.tokenSelf,
      isReaction: true,
    ),
    CardTemplate(
      id: 'Defence03', 
      name: 'Mirror', 
      description: 'Deflects laser',
      effectType: CardEffectType.applyMirror, 
      targetType: TargetType.tokenSelf,
      isReaction: true,
    ),
    CardTemplate(
      id: 'Defence04', 
      name: 'Resist', 
      description: 'Cancel a pawn’s action against you',
      effectType: CardEffectType.applyResist, 
      targetType: TargetType.tokenSelf,
      isReaction: true,
    ),
  ];
  
  static CardTemplate? getById(String id) {
     try {
       return allCards.firstWhere((c) => c.id == id);
     } catch (e) {
       return null;
     }
  }
}
