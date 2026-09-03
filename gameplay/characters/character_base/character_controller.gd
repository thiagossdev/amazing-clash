class_name CharacterController
extends CharacterBody2D
## Phase 1 locomotion: top-down movement + a fixed-velocity dash, driven by
## LocomotionFsm. All input goes through InputManager, never Input
## directly. Networking pattern (control modes, prediction/reconciliation,
## interpolation) inherited from amazing-nauts'
## gameplay/characters/character_base/character_controller.gd, scoped
## down to Phase 1: no combat/health/team/abilities yet (Phase 2/3+).
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

var fsm := LocomotionFsm.new()
var control_mode: ControlMode = ControlMode.PREDICTED

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
	apply_input(sample)
	move_and_slide()
	_client_predictor.record_predicted_input(sample, _capture_predicted_state(sample.sequence))
	_decay_visual_position_error(delta)
	if multiplayer.has_multiplayer_peer():
		NetworkManager.with_artificial_latency(
			func():
				_rpc_send_input.rpc_id(
					1, sample.sequence, sample.move_vector, sample.dash_pressed, sample.delta
				)
		)


## The server is authoritative for every character, including its own
## listen-server player.
func _physics_step_authoritative(delta: float) -> void:
	if is_owned_by_me():
		_server_sim.record_input(_sample_local_input(delta))
	var sample := _server_sim.next_input(delta)
	apply_input(sample)
	move_and_slide()
	if _server_sim.should_broadcast_snapshot():
		_rpc_receive_snapshot.rpc(
			_server_sim.tick_count(),
			global_position,
			fsm.state,
			_server_sim.last_processed_sequence()
		)


func _sample_local_input(delta: float) -> InputBuffer.Sample:
	var sample := InputBuffer.Sample.new()
	_local_sequence += 1
	sample.sequence = _local_sequence
	sample.move_vector = InputManager.get_move_vector()
	sample.dash_pressed = InputManager.is_action_just_pressed(&"dash")
	sample.delta = delta
	return sample


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _rpc_send_input(sequence: int, move_vector: Vector2, dash_pressed: bool, delta: float) -> void:
	if not NetworkManager.is_server():
		return
	if str(name) != str(multiplayer.get_remote_sender_id()):
		return
	var sample := InputBuffer.Sample.new()
	sample.sequence = sequence
	sample.move_vector = move_vector
	sample.dash_pressed = dash_pressed
	sample.delta = delta
	_server_sim.record_input(sample)


## snapshot_received fires on receipt (the debug overlay's snapshot-rate
## stat); the effect below is what artificial latency delays, so a
## configured latency is felt on both legs of the round trip.
@rpc("authority", "unreliable_ordered", "call_remote")
func _rpc_receive_snapshot(
	tick: int, position: Vector2, fsm_state: int, last_acked_sequence: int
) -> void:
	snapshot_received.emit()
	NetworkManager.with_artificial_latency(
		func(): _apply_snapshot(tick, position, fsm_state, last_acked_sequence)
	)


## PREDICTED: reconciles -- rolls back to the checkpoint recorded right
## after the last acked input, snaps to the authoritative position, then
## replays whatever inputs the server hasn't confirmed yet on top, so a
## small divergence never reads as a visible teleport (the visual child
## eases back separately, see _decay_visual_position_error).
## INTERPOLATED: no local physics, just buffers the snapshot for
## _render_interpolated_position(). AUTHORITATIVE never receives this.
func _apply_snapshot(
	tick: int, position: Vector2, fsm_state: int, last_acked_sequence: int
) -> void:
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
		ControlMode.AUTHORITATIVE:
			pass


func _capture_predicted_state(sequence: int) -> ClientPredictor.Checkpoint:
	var checkpoint := ClientPredictor.Checkpoint.new()
	checkpoint.sequence = sequence
	checkpoint.dash_timer = fsm.dash_timer
	checkpoint.dash_cooldown_timer = fsm.dash_cooldown_timer
	checkpoint.dash_direction = fsm.dash_direction
	checkpoint.fsm_state = fsm.state
	return checkpoint


func _restore_predicted_state(checkpoint: ClientPredictor.Checkpoint) -> void:
	fsm.dash_timer = checkpoint.dash_timer
	fsm.dash_cooldown_timer = checkpoint.dash_cooldown_timer
	fsm.dash_direction = checkpoint.dash_direction
	fsm.state = checkpoint.fsm_state as LocomotionFsm.State


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


func apply_input(sample: InputBuffer.Sample) -> void:
	fsm.advance(sample.move_vector, sample.dash_pressed, sample.delta)
	velocity = fsm.velocity
