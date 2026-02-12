import '../../models.dart';
import '../../ludo_rpg_engine.dart';
import '../effect_types.dart';

EffectResult boardCardAdapter({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  if (api is LudoRpgEngine) {
      final res = api.playBoardCard(gs, card.id);
      if (res.success) {
          return EffectResult.ok(pending: res.pending, consumesAction: false); // pending handles action consumption or waits
      } else {
          return EffectResult.fail(res.message ?? "Failed");
      }
  }
  return const EffectResult.fail("Engine not compatible");
}
