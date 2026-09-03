class_name ActionFsm
extends RefCounted
## Action layer: a separate state machine from LocomotionFsm, driven
## alongside it by CharacterController. Pure transition logic, no
## physics/node dependency, so it's unit-testable standalone and safely
## replayable during client-side reconciliation. Frame-counted
## (move_frame), not delta-scaled, matching every other authored
## frame-data field on MoveDefinition. Pattern inherited from
## amazing-nauts' gameplay/combat/state_machine/action_state_machine.gd,
## scoped down to Phase 2: no cancel_options/armor windows -- this
## project's combat has no cancel-chains or armor mechanic in its
## confirmed design.

enum State { NEUTRAL, STARTUP, ACTIVE, RECOVERY }

var state: State = State.NEUTRAL
var current_move: MoveDefinition
## Frames elapsed since start_move(), cumulative across the whole move.
var move_frame: int = 0
## Defenders this move's hitbox already connected with since
## start_move() -- reset on every fresh activation, so a single swing
## with a multi-frame active window can't hit the same target once per
## tick it stays active. Server-only bookkeeping (CombatResolver),
## never part of ClientPredictor.Checkpoint.
var already_hit: Array = []


## Enters the phase implied by the move's frame data at frame 0 -- a
## move with 0 startup_frames is immediately ACTIVE, not STARTUP for a
## phantom frame; a fully 0-length move ends on the spot.
func start_move(move: MoveDefinition) -> void:
	current_move = move
	move_frame = 0
	already_hit.clear()
	if move_frame >= _recovery_end():
		_end_move()
	else:
		state = _phase_for_current_frame()


## Advances the FSM by one physics frame. A no-op while NEUTRAL with no
## move active.
func advance_frame() -> void:
	if state == State.NEUTRAL:
		return
	move_frame += 1
	if move_frame >= _recovery_end():
		_end_move()
	else:
		state = _phase_for_current_frame()


func is_hitbox_active() -> bool:
	return state == State.ACTIVE


func _phase_for_current_frame() -> State:
	if move_frame >= _active_end():
		return State.RECOVERY
	if move_frame >= current_move.startup_frames:
		return State.ACTIVE
	return State.STARTUP


func _active_end() -> int:
	return current_move.startup_frames + current_move.active_frames


func _recovery_end() -> int:
	return _active_end() + current_move.recovery_frames


func _end_move() -> void:
	current_move = null
	move_frame = 0
	already_hit.clear()
	state = State.NEUTRAL
