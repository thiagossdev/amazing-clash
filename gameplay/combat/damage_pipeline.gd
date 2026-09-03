class_name DamagePipeline
extends RefCounted
## Computes final damage from a HitDefinition's base value.
## combo_scaling and buff_modifier both default to 1.0 -- no combo
## system or buff system exists yet in this project's design, but the
## hooks cost nothing to have in place now, matching this project's own
## frame-data philosophy of keeping balance calculations in one place
## editors can tune without touching logic. Pattern inherited from
## amazing-nauts' gameplay/combat/damage_pipeline.gd.


static func compute(
	base_damage: float, combo_scaling: float = 1.0, buff_modifier: float = 1.0
) -> float:
	return base_damage * combo_scaling * buff_modifier
