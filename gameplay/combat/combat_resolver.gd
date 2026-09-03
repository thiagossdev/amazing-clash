extends Node
## Server-authoritative, per-tick hit resolution across every character
## and every live projectile. Wired as TestArena's LAST child so every
## character's _physics_process for this tick (and its action_fsm
## state) has already completed before this node's own _physics_process
## runs. Hit detection is explicitly server-only: the client never
## predicts damage taken. Projectile *position* advancement runs on
## every peer (deterministic, no per-tick sync needed -- see
## gameplay/projectiles/projectile.gd); only hit resolution is gated to
## the server. Pattern inherited from amazing-nauts'
## gameplay/combat/combat_resolver.gd. Melee, a single non-piercing
## skillshot, and 2 independent ability slots (Q/E), each melee- or
## projectile-style per its own AbilityResource.is_projectile (no
## armor/buffs/VFX/objectives/piercing -- none of that exists in this
## project's design yet). Phase 5: an eliminated attacker
## (current_health <= 0) can no longer land a hit, and a hit between
## same-team characters is skipped unless MatchState.friendly_fire_enabled
## is true.

const PROJECTILE_SCENE := preload("res://gameplay/projectiles/Projectile.tscn")
const PROJECTILE_SPEED := 700.0
const PROJECTILE_LIFETIME_FRAMES := 120  # 2s @ 60Hz

@export var characters_path: NodePath = ^"../Characters"
@export var projectiles_path: NodePath = ^"../Projectiles"

var _next_network_id: int = 0


func _physics_process(_delta: float) -> void:
	var characters := get_node_or_null(characters_path)
	var roster: Array = characters.get_children() if characters else []
	if NetworkManager.is_server():
		for attacker in roster:
			_resolve_attacker(attacker, roster)
	_advance_projectiles(roster)


func _resolve_attacker(attacker: Node, roster: Array) -> void:
	if not attacker is CharacterController or attacker.current_health <= 0.0:
		return
	_resolve_melee(attacker, roster, attacker.action_fsm, attacker.attack_move)
	_maybe_launch_projectile(
		attacker,
		attacker.action_fsm,
		attacker.skillshot_move,
		"skillshot",
		attacker.pending_skillshot_direction
	)
	_resolve_ability_slot(attacker, roster, attacker.ability_q, attacker.ability_q_fsm, "ability_q")
	_resolve_ability_slot(attacker, roster, attacker.ability_e, attacker.ability_e_fsm, "ability_e")


## Dispatches one ability slot to the melee or projectile resolution
## path per its own AbilityResource.is_projectile -- the 2 test
## abilities exercise one of each, but any future ability data (a
## melee Q reslotted as a projectile, etc.) needs no code change here.
func _resolve_ability_slot(
	attacker: CharacterController,
	roster: Array,
	resource: AbilityResource,
	slot_fsm: ActionFsm,
	slot_name: String
) -> void:
	if not resource:
		return
	if resource.is_projectile:
		var direction := (
			attacker.pending_ability_q_direction
			if slot_name == "ability_q"
			else attacker.pending_ability_e_direction
		)
		_maybe_launch_projectile(attacker, slot_fsm, resource.move, slot_name, direction)
	else:
		_resolve_melee(attacker, roster, slot_fsm, resource.move)


func _resolve_melee(
	attacker: CharacterController, roster: Array, slot_fsm: ActionFsm, move: MoveDefinition
) -> void:
	if not move or slot_fsm.current_move != move:
		return
	if not slot_fsm.is_hitbox_active():
		return
	for hit in move.hit_definitions:
		var hitbox := HitDetection.hitbox_rect(
			attacker.global_position, attacker.get_aim_direction(), hit
		)
		for defender in roster:
			if defender == attacker or not defender is CharacterController:
				continue
			if defender in slot_fsm.already_hit:
				continue
			if not MatchState.friendly_fire_enabled and defender.team == attacker.team:
				continue
			var hurtbox := HitDetection.hurtbox_rect(
				defender.global_position, defender.hurtbox_size
			)
			if HitDetection.query(hitbox, hurtbox):
				_apply_hit(attacker, defender, hit)
				slot_fsm.already_hit.append(defender)


## Fires exactly once per cast: the tick the given slot's ActionFsm
## first reaches ACTIVE (move_frame == startup_frames, the same
## boundary ActionFsm._phase_for_current_frame() itself transitions
## on). slot_name round-trips through the spawn RPC so
## _rpc_spawn_projectile can look the caster's move back up on every
## peer (see _get_move_for_slot()).
func _maybe_launch_projectile(
	attacker: CharacterController,
	slot_fsm: ActionFsm,
	move: MoveDefinition,
	slot_name: String,
	direction: Vector2
) -> void:
	if not move or slot_fsm.current_move != move:
		return
	if slot_fsm.state != ActionFsm.State.ACTIVE:
		return
	if slot_fsm.move_frame != move.startup_frames:
		return
	_next_network_id += 1
	_rpc_spawn_projectile.rpc(
		_next_network_id, str(attacker.name), attacker.global_position, direction, slot_name
	)


@rpc("authority", "reliable", "call_local")
func _rpc_spawn_projectile(
	network_id: int,
	caster_name: String,
	spawn_position: Vector2,
	direction: Vector2,
	slot_name: String
) -> void:
	var characters := get_node_or_null(characters_path)
	var projectiles := get_node_or_null(projectiles_path)
	if not characters or not projectiles:
		return
	var caster := characters.get_node_or_null(caster_name) as CharacterController
	if not caster:
		return
	var move := _get_move_for_slot(caster, slot_name)
	if not move or move.hit_definitions.is_empty():
		return
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectiles.add_child(projectile)
	projectile.configure(
		network_id,
		caster,
		spawn_position,
		direction,
		PROJECTILE_SPEED,
		PROJECTILE_LIFETIME_FRAMES,
		move.hit_definitions
	)


## Maps an RPC-carried slot name back to that caster's own
## MoveDefinition -- needed because Resource properties (unlike a node's
## replicated name) don't cross the network on their own; every peer
## looks its own local copy of the caster's exported ability/move data
## up by name instead.
func _get_move_for_slot(caster: CharacterController, slot_name: String) -> MoveDefinition:
	match slot_name:
		"skillshot":
			return caster.skillshot_move
		"ability_q":
			return caster.ability_q.move if caster.ability_q else null
		"ability_e":
			return caster.ability_e.move if caster.ability_e else null
		_:
			return null


## Advances every live projectile's position (every peer, deterministic
## -- see Projectile.advance_frame()), then resolves hits server-only.
## A confirmed hit ends the (non-piercing) instance immediately on the
## server; other peers' own decorative copies keep flying until their
## own lifetime_frames runs out -- a deliberate, minor visual-polish
## gap for this first pass (the hit itself is already server-authority-
## only and unaffected by it), not a correctness one.
func _advance_projectiles(roster: Array) -> void:
	var projectiles := get_node_or_null(projectiles_path)
	if not projectiles:
		return
	for node in projectiles.get_children():
		if not node is Projectile:
			continue
		var projectile := node as Projectile
		var alive := projectile.advance_frame(get_physics_process_delta_time())
		if alive and NetworkManager.is_server():
			alive = not _resolve_projectile_hit(projectile, roster)
		if not alive:
			projectile.queue_free()


func _resolve_projectile_hit(projectile: Projectile, roster: Array) -> bool:
	for defender in roster:
		if not defender is CharacterController or defender == projectile.caster:
			continue
		if defender in projectile.already_hit:
			continue
		if not MatchState.friendly_fire_enabled and defender.team == projectile.caster.team:
			continue
		var hurtbox := HitDetection.hurtbox_rect(defender.global_position, defender.hurtbox_size)
		for hit in projectile.hit_definitions:
			var hitbox := HitDetection.projectile_hitbox_rect(
				projectile.global_position, hit.hitbox_size
			)
			if HitDetection.query(hitbox, hurtbox):
				_apply_hit(projectile.caster, defender, hit)
				projectile.already_hit.append(defender)
				return true
	return false


func _apply_hit(
	attacker: CharacterController, defender: CharacterController, hit: HitDefinition
) -> void:
	defender.take_damage(DamagePipeline.compute(hit.damage))
	attacker.apply_lock(hit.hitstop_frames)
	defender.apply_lock(maxi(hit.hitstop_frames, hit.hitstun_frames))
