extends Node
## Server-authoritative, per-tick hit resolution across every character.
## Wired as TestArena's LAST child so every character's _physics_process
## for this tick (and its action_fsm state) has already completed before
## this node's own _physics_process runs. Hit detection is explicitly
## server-only: the client never predicts damage taken. Pattern
## inherited from amazing-nauts' gameplay/combat/combat_resolver.gd,
## scoped down to Phase 2a: melee only (no armor/buffs/VFX/objectives --
## none of that exists in this project's design yet).

@export var characters_path: NodePath = ^"../Characters"


func _physics_process(_delta: float) -> void:
	if not NetworkManager.is_server():
		return
	var characters := get_node_or_null(characters_path)
	if not characters:
		return
	var roster := characters.get_children()
	for attacker in roster:
		_resolve_attacker(attacker, roster)


func _resolve_attacker(attacker: Node, roster: Array) -> void:
	if not attacker is CharacterController:
		return
	if not attacker.action_fsm.is_hitbox_active() or not attacker.debug_attack_move:
		return
	for hit in attacker.debug_attack_move.hit_definitions:
		var hitbox := HitDetection.hitbox_rect(
			attacker.global_position, attacker.get_aim_direction(), hit
		)
		for defender in roster:
			if defender == attacker or not defender is CharacterController:
				continue
			if defender in attacker.action_fsm.already_hit:
				continue
			var hurtbox := HitDetection.hurtbox_rect(
				defender.global_position, defender.hurtbox_size
			)
			if HitDetection.query(hitbox, hurtbox):
				_apply_hit(attacker, defender, hit)
				attacker.action_fsm.already_hit.append(defender)


func _apply_hit(
	attacker: CharacterController, defender: CharacterController, hit: HitDefinition
) -> void:
	defender.take_damage(DamagePipeline.compute(hit.damage))
	attacker.apply_lock(hit.hitstop_frames)
	defender.apply_lock(maxi(hit.hitstop_frames, hit.hitstun_frames))
