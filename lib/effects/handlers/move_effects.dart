import '../../models.dart';
import '../effect_types.dart';

EffectResult teleportEffect({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  if (target is! LudoToken) return const EffectResult.fail("Target must be a token.");
  
  // Strict Requirement: User must provide distance via UI dialog
  if (overrideValue == null) {
      return const EffectResult.fail("Distance required.");
  }
  
  // Validate Range (-6 to +6)
  if (overrideValue < -6 || overrideValue > 6) {
      return const EffectResult.fail("Invalid distance.");
  }
  
  // Teleport does NOT consume dice or change phase (handled by framework usually, but effect ensures logic)
  api.teleportToken(gs, target, overrideValue);
  
  return const EffectResult.ok();
}

EffectResult swapPosEffect({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  if (target is! List || target.length != 2) {
      return const EffectResult.fail("Swap requires two targets.");
  }
  
  final t1 = target[0];
  final t2 = target[1];
  
  if (t1 is! LudoToken || t2 is! LudoToken) {
      return const EffectResult.fail("Targets must be tokens.");
  }

  if (!t1.isOnMain || !t2.isOnMain) {
    return const EffectResult.fail("Both tokens must be on main track.");
  }

  final abs1 = api.toAbsoluteMainIndexFromRelative(t1);
  final abs2 = api.toAbsoluteMainIndexFromRelative(t2);

  api.setTokenRelativeFromAbsolute(t1, abs2);
  api.setTokenRelativeFromAbsolute(t2, abs1);

  return const EffectResult.ok();
}
