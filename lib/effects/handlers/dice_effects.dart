import '../../models.dart';
import '../effect_types.dart';

EffectResult modifyRollEffect({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  final effValue = overrideValue ?? card.value;

  // With DieState, we can check specific die if index provided, or default to A then B?
  // User prompt didn't specify for modifyRoll, but usually it modifies A or B.
  // Existing logic tried to modify "available" dice.
  
  // Let's support dieIndex if provided, else auto-pick unused.
  DieState? die;
  if (dieIndex != null) {
      if (dieIndex == 0) die = gs.dice.a;
      else if (dieIndex == 1) die = gs.dice.b;
  } else {
      // Auto-pick: A if unused, else B if unused.
      if (gs.dice.a != null && !gs.dice.a!.used) die = gs.dice.a;
      else if (gs.dice.b != null && !gs.dice.b!.used) die = gs.dice.b;
  }
  
  if (die == null || die.used) return const EffectResult.fail("No valid die to modify");
  
  die.value = (die.value + effValue).clamp(1, 30);
  return const EffectResult.ok();
}

EffectResult doubleDieEffect({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  // Requires die choice
  if (dieIndex != 0 && dieIndex != 1) return const EffectResult.fail("Must choose a die");

  final die = (dieIndex == 0) ? gs.dice.a : gs.dice.b;
  if (die == null || die.used) return const EffectResult.fail("Die unavailable");

  die.value *= 2;
  die.doubled = true;
  die.multiplier = 2;
  return const EffectResult.ok();
}

EffectResult doubleBothEffect({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  final a = gs.dice.a;
  final b = gs.dice.b;
  
  if (a == null || b == null) return const EffectResult.fail("Dice not rolled");
  bool anyDoubled = false;

  if (!a.used) {
    a.value *= 2;
    a.doubled = true;
    a.multiplier = 2;
    anyDoubled = true;
  }
  if (!b.used) {
    b.value *= 2;
    b.doubled = true;
    b.multiplier = 2;
    anyDoubled = true;
  }

  if (!anyDoubled) return const EffectResult.fail("No unused dice to double");

  return const EffectResult.ok();
}

EffectResult rerollEffect({
  required LudoRpgGameState gs,
  required LudoRpgEngineApi api,
  required CardTemplate card,
  dynamic target,
  int? overrideValue,
  int? dieIndex,
}) {
  if (gs.dice.a == null || gs.dice.b == null) {
    return const EffectResult.fail("Roll dice first.");
  }

  // REROLL 2X (Both Dice)
  if (card.effectType == CardEffectType.reroll2x) {
      bool anyRerolled = false;
      if (!gs.dice.a!.used) {
          gs.dice.a = DieState(api.rollD6());
          anyRerolled = true;
      }
      if (!gs.dice.b!.used) {
          gs.dice.b = DieState(api.rollD6());
          anyRerolled = true;
      }
      
      if (!anyRerolled) return const EffectResult.fail("All dice used.");
      return const EffectResult.ok();
  }

  // REROLL (Single Die)
  // Requires selection
  if (dieIndex != 0 && dieIndex != 1) return const EffectResult.fail("Select a die.");
  
  final die = (dieIndex == 0) ? gs.dice.a : gs.dice.b;
  if (die == null || die.used) return const EffectResult.fail("Die unavailable.");
  
  die.value = api.rollD6();
  // We do NOT reset 'used' status usually, but for reroll.. 
  // If it was unused, it stays unused. If it was used, we probably shouldn't be able to reroll it?
  // Logic above checks `die.used`, so we are good.
  // New value is fresh.
  
  return const EffectResult.ok();
}
