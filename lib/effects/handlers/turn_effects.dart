import '../../models.dart';
import '../effect_types.dart';

EffectResult extraTurnEffect({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  gs.currentPlayer.effects.add(const ActiveEffect(id: "ExtraTurn", duration: 1));
  return const EffectResult.ok();
}

EffectResult skipTurnEffect({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  if (target is! LudoPlayer) return const EffectResult.fail("Target must be a player.");
  target.effects.add(const ActiveEffect(id: "SkipTurn", duration: 1));
  return const EffectResult.ok();
}

EffectResult restartTurnNowEffect({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  // Immediate turn restart
  gs.dice.reset();
  gs.cardActionsRemaining = 2;
  gs.phase = TurnPhase.awaitRoll;

  return const EffectResult.ok(consumesAction: false);
}
