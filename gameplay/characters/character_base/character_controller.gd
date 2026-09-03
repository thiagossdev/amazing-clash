class_name CharacterController
extends CharacterBody2D
## Phase 3: adds 2 independent ability slots (Q/E, each its own ActionFsm
## and cooldown, castable independently of melee/skillshot and of each
## other) on top of Phase 2's melee test move and mouse-aimed skillshot.
## All input goes through InputManager, never Input directly. Networking
## pattern (control modes, prediction/reconciliation, interpolation)
## adapted from amazing-nauts' character_controller.gd, scoped down: no
## full hero roster yet (Phase 4).
##
## Networked in one of 3 roles decided by _resolve_control_mode():
## AUTHORITATIVE (server, every character, fed by ServerSim's per-client
## jitter buffer), PREDICTED (client, its own character, applied
## immediately and sent to the server), INTERPOLATED (client, everyone
## else's; rendered from received snapshots).

## Fired whenever this instance receives an authoritative snapshot
## (PREDICTED or INTERPOLATED only). The debug overlay counts these for
## the snapshot-rate stat.
signal snapshot_received

enum ControlMode { AUTHORITATIVE, PREDICTED, INTERPOLATED }

## Continuous per-second decay rate for _visual_position_error, not a
## fixed duration -- frequent corrections settle to a steady offset
## instead of restarting a fixed window. RATE=20 decays ~95% of any
## error within 0.15s.
const RECONCILIATION_SMOOTHING_RATE_PER_SECOND := 20.0
const MAX_VISUAL_POSITION_ERROR := 48.0

## Which child node's local `position` absorbs the reconciliation-
## smoothing offset.
@export var visual_path: NodePath = ^"Visual"
## The character's melee move (LMB). Character.tscn (the generic GUT
## test fixture) assigns placeholder debug data; Phase 4's real class
## scenes (Vanguard.tscn, RangedMage.tscn) assign their own kit move.
@export var attack_move: MoveDefinition
## The character's skillshot move (RMB) -- always fires a Projectile in
## pending_skillshot_direction (real mouse-aim, captured at cast time),
## unlike the ability slots below, which pick melee or projectile per
## their own AbilityResource.is_projectile.
@export var skillshot_move: MoveDefinition
## Phase 3's 2 independent test ability slots -- Q and E, each its own
## cooldown, castable while melee/skillshot are on cooldown or vice
## versa. R/F/T InputMap actions already exist for Phase 4+ content;
## these 2 slots are enough to prove the framework, not a full 5-slot
## roster yet.
@export var ability_q: AbilityResource
@export var ability_e: AbilityResource
## Own hurtbox for combat, decoupled from the CharacterBody2D collision
## shape used for world collision.
@export var hurtbox_size: Vector2 = Vector2(40.0, 40.0)
## Inline setter so current_health always tracks max_health on a
## scene's per-instance override too.
@export var max_health: float = 100.0:
	set(value):
		max_health = value
		current_health = value

var fsm := LocomotionFsm.new()
var action_fsm := ActionFsm.new()
## Independent of action_fsm and of each other: pressing Q doesn't lock
## out melee/skillshot or E, only Q's own cooldown gates it again. A
## deliberate Phase 3 simplification -- whether a real ability should
## also lock movement/other slots is a per-ability design question for
## Phase 4's real classes, not decided here.
var ability_q_fsm := ActionFsm.new()
var ability_e_fsm := ActionFsm.new()
var control_mode: ControlMode = ControlMode.PREDICTED
## Never predicted -- the server is sole authority over damage taken,
## set directly from CharacterSnapshot.health on receipt, same category
## as current_health.
var current_health: float = 100.0
## Server-only: the mouse-aim direction captured at the exact tick the
## skillshot cast started, read by CombatResolver when the cast reaches
## ACTIVE to launch the Projectile. Not part of ClientPredictor.
## Checkpoint: it only ever matters on the AUTHORITATIVE instance (only
## the server spawns the real projectile), same category as
## action_fsm.already_hit.
var pending_skillshot_direction: Vector2 = Vector2.RIGHT
## Same capture-at-cast-time treatment, one per ability slot -- only
## meaningful (and only ever set) when that slot's own AbilityResource.
## is_projectile is true; a melee-style slot like the debug Q ability
## never reads it (CombatResolver rotates its hitbox with
## get_aim_direction() instead, same as the base melee move).
var pending_ability_q_direction: Vector2 = Vector2.RIGHT
var pending_ability_e_direction: Vector2 = Vector2.RIGHT
## Server-only: set by PlayerSpawner right after instantiate, before
## add_child (same pattern as `position`) -- 0 or 1, read by
## CombatResolver's friendly-fire check and MatchRules' alive-per-team
## count. Never replicated to clients: no per-character team indicator
## exists yet, only MatchState's aggregate team_alive_counts (the
## minimal HUD's own scope), so this stays a plain, unsynced var like
## action_fsm.already_hit.
var team: int = 0
## Set once at spawn (net/player_spawner.gd) from the peer's chosen
## Room Config perk (Phase 9) -- 1.0 (no-op) for anyone without one.
## Scales the cooldown a Q/E ability slot re-arms at in
## _advance_ability_slot() below; attack_move/skillshot_move have no
## explicit cooldown field to scale (their recovery frames already act
## as one via action_fsm's own state machine).
var cooldown_multiplier: float = 1.0

var _local_sequence: int = 0
var _server_sim: ServerSim
var _client_predictor: ClientPredictor
var _previous_remote_snapshot: CharacterSnapshot
var _latest_remote_snapshot: CharacterSnapshot
var _previous_remote_snapshot_time: float = 0.0
var _latest_remote_snapshot_time: float = 0.0
## PREDICTED-only: how far the rendered visual still needs to glide back
## toward global_position after a reconciliation correction. Only the
## visible child lags -- global_position (and therefore collision) is
## always corrected immediately.
var _visual_position_error: Vector2 = Vector2.ZERO
## Server-only: frames remaining where this character's own simulation
## step is entirely frozen (both movement and the action layer) --
## applied to both attacker and defender on a confirmed hit (see
## apply_lock()). Never predicted, same category as current_health:
## it only ever originates from a server-confirmed hit, which the
## client already doesn't predict.
var _lock_frames: int = 0
## Frame-counted (decremented once per apply_input() call, matching the
## project's existing frame-data convention), not part of
## ClientPredictor.Checkpoint's health-taking exemption -- these ARE
## predicted, unlike _lock_frames, because starting/cooling down an
## ability is the local player's own input timing, not a server-only
## reaction to a confirmed hit. Correctness during reconciliation replay
## comes from Checkpoint carrying them, restored before replay.
var _ability_q_cooldown_frames: int = 0
var _ability_e_cooldown_frames: int = 0


func _ready() -> void:
	var is_owner := is_owned_by_me()
	control_mode = _resolve_control_mode(NetworkManager.is_server(), is_owner)
	if control_mode == ControlMode.AUTHORITATIVE:
		_server_sim = ServerSim.new()
	elif control_mode == ControlMode.PREDICTED:
		_client_predictor = ClientPredictor.new()
	if is_owner:
		var camera := get_tree().get_first_node_in_group(&"local_camera")
		if camera:
			camera.target = self
	_apply_perk_from_lobby_state()


## Runs on EVERY peer's own local instance of this character -- the
## server's AUTHORITATIVE copy, the owning client's PREDICTED copy, AND
## every other client's INTERPOLATED copy -- not just the server.
## Deliberately NOT done in net/player_spawner.gd (server-only): a
## perk's move_speed_multiplier/cooldown_multiplier are read during
## client-side PREDICTION (apply_input(), the exact same code path
## AUTHORITATIVE uses), so a client whose own local mirror never got the
## multiplier would visibly mispredict its own movement/ability timing
## against the server's every snapshot -- unlike `team`, which only
## ever matters to server-only logic and can safely stay unreplicated.
## LobbyState.player_perk_ids is already fully replicated to every peer
## by spawn time (perks are picked and broadcast live during Room
## Config, well before LOADING), so no new replication is needed here --
## just read what every peer already has, keyed by this node's own name
## (the same str(peer_id) convention is_owned_by_me() already relies
## on). A peer with no registered perk (net/dev_bootstrap.gd's headless
## test peers) is a no-op: every PerkResource multiplier defaults to 1.0.
func _apply_perk_from_lobby_state() -> void:
	var perk_id := LobbyState.get_perk_id(str(name).to_int(), "")
	var registered_index := LobbyState.PERK_IDS.find(perk_id)
	if registered_index == -1:
		return
	var perk := LobbyState.PERK_RESOURCES[registered_index]
	max_health *= perk.max_health_multiplier
	fsm.move_speed_multiplier = perk.move_speed_multiplier
	cooldown_multiplier = perk.cooldown_multiplier


func _physics_process(delta: float) -> void:
	match control_mode:
		ControlMode.AUTHORITATIVE:
			_physics_step_authoritative(delta)
		ControlMode.PREDICTED:
			_physics_step_predicted(delta)
		ControlMode.INTERPOLATED:
			_render_interpolated_position()


## Which of the 3 network roles this instance plays on THIS peer.
## AUTHORITATIVE always wins: the server is the sole simulation authority
## for every character, including its own listen-server player. Among
## clients, a character is PREDICTED only for the peer that owns it,
## INTERPOLATED for everyone else's.
func _resolve_control_mode(is_server: bool, is_owner: bool) -> ControlMode:
	if is_server:
		return ControlMode.AUTHORITATIVE
	return ControlMode.PREDICTED if is_owner else ControlMode.INTERPOLATED


## Derived from the node's own name (PlayerSpawner names every character
## str(peer_id)), because MultiplayerSpawner replicates a node's name to
## every peer but not arbitrary script properties.
func is_owned_by_me() -> bool:
	return str(name) == str(multiplayer.get_unique_id())


func _physics_step_predicted(delta: float) -> void:
	var sample := _sample_local_input(delta)
	if current_health > 0.0:
		apply_input(sample)
		move_and_slide()
	_client_predictor.record_predicted_input(sample, _capture_predicted_state(sample.sequence))
	_decay_visual_position_error(delta)
	if multiplayer.has_multiplayer_peer():
		NetworkManager.with_artificial_latency(
			func():
				_rpc_send_input.rpc_id(
					1,
					sample.sequence,
					sample.move_vector,
					sample.dash_pressed,
					sample.aim_direction,
					InputBuffer.pack_ability_flags(sample),
					sample.delta
				)
		)


## The server is authoritative for every character, including its own
## listen-server player. A locked character (hitstop/hitstun from a
## confirmed hit) still consumes buffered input so it doesn't back up,
## but doesn't act on it -- and still broadcasts a snapshot, so clients
## see the frozen/health-changed state promptly. An eliminated
## character (current_health <= 0) freezes in place permanently, same
## reasoning as the lock but never expiring -- MatchRules reads this
## same current_health to resolve the match's win condition.
func _physics_step_authoritative(delta: float) -> void:
	if is_owned_by_me():
		_server_sim.record_input(_sample_local_input(delta))
	var sample := _server_sim.next_input(delta)
	if _lock_frames > 0:
		_lock_frames -= 1
	elif current_health > 0.0:
		apply_input(sample)
		move_and_slide()
	if _server_sim.should_broadcast_snapshot():
		_rpc_receive_snapshot.rpc(
			_server_sim.tick_count(),
			global_position,
			fsm.state,
			_server_sim.last_processed_sequence(),
			current_health,
			action_fsm.state,
			action_fsm.move_frame
		)


func _sample_local_input(delta: float) -> InputBuffer.Sample:
	var sample := InputBuffer.Sample.new()
	_local_sequence += 1
	sample.sequence = _local_sequence
	sample.move_vector = InputManager.get_move_vector()
	sample.dash_pressed = InputManager.is_action_just_pressed(&"dash")
	sample.attack_pressed = InputManager.is_action_just_pressed(&"attack")
	sample.aim_direction = InputManager.get_aim_direction(global_position)
	sample.skillshot_pressed = InputManager.is_action_just_pressed(&"skillshot")
	sample.ability_q_pressed = InputManager.is_action_just_pressed(&"ability_q")
	sample.ability_e_pressed = InputManager.is_action_just_pressed(&"ability_e")
	sample.delta = delta
	return sample


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _rpc_send_input(
	sequence: int,
	move_vector: Vector2,
	dash_pressed: bool,
	aim_direction: Vector2,
	ability_flags: int,
	delta: float
) -> void:
	if not NetworkManager.is_server():
		return
	if str(name) != str(multiplayer.get_remote_sender_id()):
		return
	var sample := InputBuffer.Sample.new()
	sample.sequence = sequence
	sample.move_vector = move_vector
	sample.dash_pressed = dash_pressed
	sample.aim_direction = aim_direction
	InputBuffer.unpack_ability_flags(sample, ability_flags)
	sample.delta = delta
	_server_sim.record_input(sample)


## snapshot_received fires on receipt (the debug overlay's snapshot-rate
## stat); the effect below is what artificial latency delays, so a
## configured latency is felt on both legs of the round trip.
@rpc("authority", "unreliable_ordered", "call_remote")
func _rpc_receive_snapshot(
	tick: int,
	position: Vector2,
	fsm_state: int,
	last_acked_sequence: int,
	health: float,
	action_state: int,
	action_move_frame: int
) -> void:
	snapshot_received.emit()
	NetworkManager.with_artificial_latency(
		func():
			_apply_snapshot(
				tick,
				position,
				fsm_state,
				last_acked_sequence,
				health,
				action_state,
				action_move_frame
			)
	)


## PREDICTED: reconciles -- rolls back to the checkpoint recorded right
## after the last acked input, snaps to the authoritative position, then
## replays whatever inputs the server hasn't confirmed yet on top, so a
## small divergence never reads as a visible teleport (the visual child
## eases back separately, see _decay_visual_position_error). health is
## never predicted, applied directly on every control mode -- the
## client never predicts damage taken, only its own movement/action.
## INTERPOLATED: no local physics, just buffers the snapshot for
## _render_interpolated_position(). Ability Q/E state is NOT replicated
## to a remote INTERPOLATED character in Phase 3 (the snapshot RPC's own
## param count is already at its practical limit) -- a remote player's Q/
## E cast won't visually show as active on other clients yet, a
## deliberate, documented gap; hit resolution itself is unaffected since
## it's already server-only regardless of what a remote peer renders.
## AUTHORITATIVE never receives this.
func _apply_snapshot(
	tick: int,
	position: Vector2,
	fsm_state: int,
	last_acked_sequence: int,
	health: float,
	action_state: int,
	action_move_frame: int
) -> void:
	current_health = health
	match control_mode:
		ControlMode.PREDICTED:
			var pre_correction_position := global_position
			var checkpoint := _client_predictor.state_at(last_acked_sequence)
			if checkpoint:
				_restore_predicted_state(checkpoint)
			global_position = position
			for sample in _client_predictor.reconcile(last_acked_sequence):
				apply_input(sample)
				move_and_slide()
			_begin_visual_correction_smoothing(pre_correction_position)
		ControlMode.INTERPOLATED:
			_previous_remote_snapshot = _latest_remote_snapshot
			_previous_remote_snapshot_time = _latest_remote_snapshot_time
			_latest_remote_snapshot = CharacterSnapshot.make(
				tick, position, fsm_state, last_acked_sequence
			)
			_latest_remote_snapshot_time = Time.get_ticks_msec() / 1000.0
			fsm.state = fsm_state as LocomotionFsm.State
			action_fsm.state = action_state as ActionFsm.State
			action_fsm.move_frame = action_move_frame
		ControlMode.AUTHORITATIVE:
			pass


func _capture_predicted_state(sequence: int) -> ClientPredictor.Checkpoint:
	var checkpoint := ClientPredictor.Checkpoint.new()
	checkpoint.sequence = sequence
	checkpoint.dash_timer = fsm.dash_timer
	checkpoint.dash_cooldown_timer = fsm.dash_cooldown_timer
	checkpoint.dash_direction = fsm.dash_direction
	checkpoint.facing_direction = fsm.facing_direction
	checkpoint.fsm_state = fsm.state
	checkpoint.action_state = action_fsm.state
	checkpoint.action_move = action_fsm.current_move
	checkpoint.action_move_frame = action_fsm.move_frame
	checkpoint.ability_q_state = ability_q_fsm.state
	checkpoint.ability_q_move_frame = ability_q_fsm.move_frame
	checkpoint.ability_q_cooldown_frames = _ability_q_cooldown_frames
	checkpoint.ability_e_state = ability_e_fsm.state
	checkpoint.ability_e_move_frame = ability_e_fsm.move_frame
	checkpoint.ability_e_cooldown_frames = _ability_e_cooldown_frames
	return checkpoint


func _restore_predicted_state(checkpoint: ClientPredictor.Checkpoint) -> void:
	fsm.dash_timer = checkpoint.dash_timer
	fsm.dash_cooldown_timer = checkpoint.dash_cooldown_timer
	fsm.dash_direction = checkpoint.dash_direction
	fsm.facing_direction = checkpoint.facing_direction
	fsm.state = checkpoint.fsm_state as LocomotionFsm.State
	action_fsm.state = checkpoint.action_state as ActionFsm.State
	action_fsm.current_move = checkpoint.action_move
	action_fsm.move_frame = checkpoint.action_move_frame
	ability_q_fsm.state = checkpoint.ability_q_state as ActionFsm.State
	ability_q_fsm.move_frame = checkpoint.ability_q_move_frame
	_ability_q_cooldown_frames = checkpoint.ability_q_cooldown_frames
	ability_e_fsm.state = checkpoint.ability_e_state as ActionFsm.State
	ability_e_fsm.move_frame = checkpoint.ability_e_move_frame
	_ability_e_cooldown_frames = checkpoint.ability_e_cooldown_frames


func _begin_visual_correction_smoothing(pre_correction_position: Vector2) -> void:
	_visual_position_error += pre_correction_position - global_position
	_visual_position_error = _visual_position_error.limit_length(MAX_VISUAL_POSITION_ERROR)


func _decay_visual_position_error(delta: float) -> void:
	if _visual_position_error == Vector2.ZERO:
		return
	_visual_position_error *= exp(-RECONCILIATION_SMOOTHING_RATE_PER_SECOND * delta)
	if _visual_position_error.length_squared() < 1.0:
		_visual_position_error = Vector2.ZERO
	var visual := get_node_or_null(visual_path)
	if visual:
		visual.position = _visual_position_error


## No physics for a remote character -- just plays back between the last
## two received snapshots, driven by the local clock. Snaps straight to
## the first snapshot ever received: with only one known point there's
## nothing to interpolate between yet.
func _render_interpolated_position() -> void:
	if not _latest_remote_snapshot:
		return
	if not _previous_remote_snapshot:
		global_position = _latest_remote_snapshot.position
		return
	var now := Time.get_ticks_msec() / 1000.0
	global_position = CharacterSnapshot.interpolate(
		_previous_remote_snapshot,
		_latest_remote_snapshot,
		now - _latest_remote_snapshot_time,
		_latest_remote_snapshot_time - _previous_remote_snapshot_time
	)


## Starts the test attack or skillshot if one was pressed and the shared
## action layer is free (attack takes priority if both are somehow
## pressed the same tick), otherwise just advances whatever move is
## already in progress. Then independently advances each ability slot
## (Q, E), which don't share the action layer or each other's cooldown.
func apply_input(sample: InputBuffer.Sample) -> void:
	fsm.advance(sample.move_vector, sample.dash_pressed, sample.delta)
	velocity = fsm.velocity
	var can_start_move := action_fsm.state == ActionFsm.State.NEUTRAL
	if sample.attack_pressed and can_start_move and attack_move:
		action_fsm.start_move(attack_move)
	elif sample.skillshot_pressed and can_start_move and skillshot_move:
		pending_skillshot_direction = _normalized_aim(sample.aim_direction)
		action_fsm.start_move(skillshot_move)
	else:
		action_fsm.advance_frame()
	var q_result := _advance_ability_slot(
		ability_q_fsm, ability_q, sample.ability_q_pressed, _ability_q_cooldown_frames
	)
	_ability_q_cooldown_frames = q_result.cooldown_frames
	if q_result.started and ability_q and ability_q.is_projectile:
		pending_ability_q_direction = _normalized_aim(sample.aim_direction)
	var e_result := _advance_ability_slot(
		ability_e_fsm, ability_e, sample.ability_e_pressed, _ability_e_cooldown_frames
	)
	_ability_e_cooldown_frames = e_result.cooldown_frames
	if e_result.started and ability_e and ability_e.is_projectile:
		pending_ability_e_direction = _normalized_aim(sample.aim_direction)


## Starts `resource`'s move if pressed, NEUTRAL, and off cooldown;
## otherwise just advances the slot's own frame counter. Returns both
## the cooldown to store back into the caller's own field (GDScript has
## no by-reference int params, hence the return-and-reassign pattern at
## each call site) and whether the move started this call, so the
## caller can capture a fresh aim direction exactly on the cast tick
## (see pending_ability_q_direction/pending_ability_e_direction) without
## duplicating this method's own start-gating condition.
func _advance_ability_slot(
	slot_fsm: ActionFsm, resource: AbilityResource, pressed: bool, cooldown_frames: int
) -> Dictionary:
	var remaining := maxi(cooldown_frames - 1, 0)
	var started := false
	if pressed and slot_fsm.state == ActionFsm.State.NEUTRAL and resource and remaining <= 0:
		slot_fsm.start_move(resource.move)
		remaining = int(resource.cooldown_frames * cooldown_multiplier)
		started = true
	else:
		slot_fsm.advance_frame()
	return {"cooldown_frames": remaining, "started": started}


## Not trusted verbatim from the network -- see locomotion_fsm.gd's
## move_vector clamp for the same class of concern; a raw or oversized
## vector here can't cause harm on its own (Projectile.configure()
## normalizes again before use), but normalizing at the point of capture
## keeps every stored direction well-formed.
func _normalized_aim(aim_direction: Vector2) -> Vector2:
	return aim_direction.normalized() if not aim_direction.is_zero_approx() else Vector2.RIGHT


## Current aim direction for this character's melee hitbox -- Phase 2a
## uses last movement direction (LocomotionFsm.facing_direction); real
## mouse-aim arrives with Phase 2b's skillshot.
func get_aim_direction() -> Vector2:
	return fsm.facing_direction


## Server-only: freezes this character's own simulation step (movement
## and the action layer both) for `frames` ticks. Never shortens an
## existing longer freeze -- a second hit landing mid-lock shouldn't cut
## the first one's freeze short.
func apply_lock(frames: int) -> void:
	_lock_frames = maxi(_lock_frames, frames)


## Server-only: applies damage_pipeline-computed damage, clamped at 0 --
## no death/respawn handling yet (not part of Phase 2's scope).
func take_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)
