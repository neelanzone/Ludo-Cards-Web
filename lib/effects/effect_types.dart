import '../models.dart';

class EffectResult {
  final bool ok;
  final String? error;
  final bool consumesAction;
  final PendingInteraction? pending;

  const EffectResult._(this.ok, this.error, this.consumesAction, this.pending);
  
  const EffectResult.ok({bool consumesAction = true, PendingInteraction? pending}) 
      : this._(true, null, consumesAction, pending);
      
  const EffectResult.fail(String msg) 
      : this._(false, msg, false, null);
      
  factory EffectResult.needsInteraction(PendingInteraction pending) =>
      EffectResult.ok(consumesAction: false, pending: pending);
}

/// Standard handler signature for all effects.
typedef EffectHandler = EffectResult Function({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
});

/// Minimal API surface the effects need from the engine.
abstract class LudoRpgEngineApi {
  int get mainTrackLen;
  int toAbsoluteMainIndexFromRelative(LudoToken t);
  bool isTokenSafeFromAttack(LudoToken t);
  void teleportToken(LudoRpgGameState gs, LudoToken t, int steps);
  void setTokenRelativeFromAbsolute(LudoToken t, int absIndex);
  int rollD6(); 
}
