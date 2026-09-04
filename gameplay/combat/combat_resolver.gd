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
## skillshot, and 4 independent ability slots (Q/E/R/F, Phase 15 grew
## this from 2), each melee- or projectile-style per its own
## AbilityResource.is_projectile (no armor/buffs/VFX/objectives/piercing
## -- none of that exists in this project's design yet). Phase 5: an
## eliminated attacker
## (current_health <= 0) can no longer land a hit, and a hit between
## same-team characters is skipped unless MatchState.friendly_fire_enabled
## is true.

const PROJECTILE_SCENE := preload("res://gameplay/projectiles/Projectile.tscn")
const PROJECTILE_SPEED := 700.0
const PROJECTILE_LIFETIME_FRAMES := 120  # 2s @ 60Hz

## Phase 11 (lag compensation): a hit resolves against the defender's
## position at the attacker's estimated one-way-latency timestamp, not
## the defender's live current position -- so an attacker who visually
## saw the defender in range (on their own screen, some ms ago) isn't
## penalized by round-trip delay for something that was true when they
## acted. Bounded to MAX_COMPENSATION_TICKS (~200ms) so a very
## high-latency attacker can't reach arbitrarily far into the past;
## see docs/research/networking-architecture-inspiration/ for the
## industry precedent (Valve/Source, Overwatch) this follows.
const MS_PER_TICK := 1000.0 / 60.0
const MAX_COMPENSATION_TICKS := 12

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
	_resolve_ability_slot(attacker, roster, attacker.ability_r, attacker.ability_r_fsm, "ability_r")
	_resolve_ability_slot(attacker, roster, attacker.ability_f, attacker.ability_f_fsm, "ability_f")


## Dispatches one ability slot to the melee or projectile resolution
## path per its own AbilityResource.is_projectile -- the test abilities
## exercise one of each, but any future ability data (a melee Q
## reslotted as a projectile, etc.) needs no code change here.
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
		var direction := _pending_direction_for_slot(attacker, slot_name)
		_maybe_launch_projectile(attacker, slot_fsm, resource.move, slot_name, direction)
	else:
		_resolve_melee(attacker, roster, slot_fsm, resource.move)


## Phase 15: 4 ability slots (was 2 in Phase 3) made the original
## inline 2-way ternary here unreadable -- a proper lookup instead of
## growing it into a 4-way chain.
func _pending_direction_for_slot(attacker: CharacterController, slot_name: String) -> Vector2:
	match slot_name:
		"ability_q":
			return attacker.pending_ability_q_direction
		"ability_e":
			return attacker.pending_ability_e_direction
		"ability_r":
			return attacker.pending_ability_r_direction
		"ability_f":
			return attacker.pending_ability_f_direction
		_:
			return Vector2.RIGHT


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
				_compensated_defender_position(attacker, defender), defender.hurtbox_size
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
	# Named by network_id (same "look it up by a replicated identifier"
	# convention PlayerSpawner uses for characters, keyed by peer_id) so
	# _rpc_despawn_projectile can find this exact instance on every peer.
	projectile.name = str(network_id)
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
		"ability_r":
			return caster.ability_r.move if caster.ability_r else null
		"ability_f":
			return caster.ability_f.move if caster.ability_f else null
		_:
			return null


## Advances every live projectile's position (every peer, deterministic
## -- see Projectile.advance_frame()), then resolves hits server-only.
## A confirmed hit broadcasts a despawn RPC so every peer's own copy
## (not just the server's) disappears immediately, instead of the
## decorative remote copies flying on until their own lifetime_frames
## runs out. Natural lifetime expiry needs no RPC -- it's already
## identical on every peer without one.
func _advance_projectiles(roster: Array) -> void:
	var projectiles := get_node_or_null(projectiles_path)
	if not projectiles:
		return
	for node in projectiles.get_children():
		if not node is Projectile:
			continue
		var projectile := node as Projectile
		var alive := projectile.advance_frame(get_physics_process_delta_time())
		if alive and NetworkManager.is_server() and _resolve_projectile_hit(projectile, roster):
			_rpc_despawn_projectile.rpc(projectile.network_id)
			continue
		if not alive:
			projectile.queue_free()


## Server-only broadcast (see _advance_projectiles) so a hit despawns
## the projectile on every peer, not just the one that resolved it.
## A no-op if the node is already gone -- e.g. this peer's own copy
## expired by lifetime the same tick the hit was confirmed elsewhere,
## a benign race between 2 independent despawn causes, not a bug.
@rpc("authority", "reliable", "call_local")
func _rpc_despawn_projectile(network_id: int) -> void:
	var projectiles := get_node_or_null(projectiles_path)
	if not projectiles:
		return
	var projectile := projectiles.get_node_or_null(str(network_id))
	if projectile:
		projectile.queue_free()


func _resolve_projectile_hit(projectile: Projectile, roster: Array) -> bool:
	for defender in roster:
		if not defender is CharacterController or defender == projectile.caster:
			continue
		if defender in projectile.already_hit:
			continue
		if not MatchState.friendly_fire_enabled and defender.team == projectile.caster.team:
			continue
		var hurtbox := HitDetection.hurtbox_rect(
			_compensated_defender_position(projectile.caster, defender), defender.hurtbox_size
		)
		for hit in projectile.hit_definitions:
			var hitbox := HitDetection.projectile_hitbox_rect(
				projectile.global_position, hit.hitbox_size
			)
			if HitDetection.query(hitbox, hurtbox):
				_apply_hit(projectile.caster, defender, hit)
				projectile.already_hit.append(defender)
				return true
	return false


## The defender's position rewound to the attacker's estimated
## one-way-latency timestamp (half the attacker's own measured RTT,
## converted to ticks at 60Hz, bounded to MAX_COMPENSATION_TICKS).
## NetworkManager.get_peer_rtt_ms() already returns 0 for a peer id
## that isn't a connected remote peer -- correctly zero-compensating
## the server's own listen-server player, who has no real network hop
## to account for.
func _compensated_defender_position(
	attacker: CharacterController, defender: CharacterController
) -> Vector2:
	var one_way_ms := NetworkManager.get_peer_rtt_ms(attacker.name.to_int()) / 2.0
	var compensation_ticks := mini(int(round(one_way_ms / MS_PER_TICK)), MAX_COMPENSATION_TICKS)
	return defender.position_at_tick(defender.current_tick() - compensation_ticks)


func _apply_hit(
	attacker: CharacterController, defender: CharacterController, hit: HitDefinition
) -> void:
	defender.take_damage(DamagePipeline.compute(hit.damage))
	attacker.apply_lock(hit.hitstop_frames)
	defender.apply_lock(maxi(hit.hitstop_frames, hit.hitstun_frames))
