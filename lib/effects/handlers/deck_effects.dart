import '../../models.dart';
import '../../ludo_rpg_engine.dart';
import '../effect_types.dart';

EffectResult dumpsterDiveHandler({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  if (api is LudoRpgEngine) {
      return api.playDumpsterDive(gs);
  }
  return const EffectResult.fail("Engine not compatible");
}
