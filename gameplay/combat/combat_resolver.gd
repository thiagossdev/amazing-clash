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
## gameplay/combat/combat_resolver.gd, scoped down to Phase 2b: melee +
## a single non-piercing skillshot (no armor/buffs/VFX/objectives/
## piercing -- none of that exists in this project's design yet).

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
	if not attacker is CharacterController:
		return
	_resolve_melee(attacker, roster)
	_maybe_launch_skillshot(attacker)


func _resolve_melee(attacker: CharacterController, roster: Array) -> void:
	if attacker.action_fsm.current_move != attacker.debug_attack_move:
		return
	if not attacker.action_fsm.is_hitbox_active():
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


## Fires exactly once: the tick the skillshot cast's ActionFsm first
## reaches ACTIVE (move_frame == startup_frames, the same boundary
## ActionFsm._phase_for_current_frame() itself transitions on).
func _maybe_launch_skillshot(attacker: CharacterController) -> void:
	if (
		attacker.action_fsm.current_move != attacker.debug_skillshot_move
		or not attacker.debug_skillshot_move
	):
		return
	if attacker.action_fsm.state != ActionFsm.State.ACTIVE:
		return
	if attacker.action_fsm.move_frame != attacker.debug_skillshot_move.startup_frames:
		return
	_next_network_id += 1
	_rpc_spawn_projectile.rpc(
		_next_network_id,
		str(attacker.name),
		attacker.global_position,
		attacker.pending_skillshot_direction
	)


@rpc("authority", "reliable", "call_local")
func _rpc_spawn_projectile(
	network_id: int, caster_name: String, spawn_position: Vector2, direction: Vector2
) -> void:
	var characters := get_node_or_null(characters_path)
	var projectiles := get_node_or_null(projectiles_path)
	if not characters or not projectiles:
		return
	var caster := characters.get_node_or_null(caster_name) as CharacterController
	if not caster or not caster.debug_skillshot_move:
		return
	if caster.debug_skillshot_move.hit_definitions.is_empty():
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
		caster.debug_skillshot_move.hit_definitions
	)


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
