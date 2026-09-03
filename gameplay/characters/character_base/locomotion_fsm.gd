class_name LocomotionFsm
extends RefCounted
## Top-down 2D locomotion: Idle, Walk, and a fixed-velocity Dash used as
## the "move and react" evasion tool the project's combat pitch needs
## (docs/blueprint/02-confirmed-mechanics.md). Pure logic, no node/RPC
## dependency, so it is unit-testable standalone (see
## tests/unit/test_locomotion_fsm.gd) and safely replayable during
## client-side reconciliation (see character_controller.gd).
##
## Deliberately smaller than amazing-nauts' own LocomotionStateMachine:
## no jump/fall/gravity/coyote-time here -- this is a top-down arena, not
## a platformer (docs/blueprint/05-open-questions.md, 2D confirmed
## 2026-09-02). Combat states (attack/hit-reaction) are a separate layer,
## added in Phase 2, not this one.

enum State { IDLE, WALK, DASHING }

const MOVE_SPEED := 260.0
const DASH_SPEED := 620.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 0.6

var state: State = State.IDLE
var velocity: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO


## dash_pressed is a one-shot edge trigger, never held. Mutates state/
## velocity in place; callers apply `velocity * delta` to actual position
## themselves (this class has no notion of a Node's transform).
##
## move_vector is clamped to unit length here, not trusted from the
## caller: on the server this value arrives over `_rpc_send_input` from
## whatever the remote peer's process sends, and a modified client could
## claim a move_vector far longer than 1.0 to move faster than
## MOVE_SPEED on the authoritative simulation itself -- exactly the
## class of cheat server authority exists to prevent (dash is already
## safe from this since dash_direction is normalized separately below;
## only the plain-walk branch multiplies move_vector directly).
func advance(raw_move_vector: Vector2, dash_pressed: bool, delta: float) -> void:
	var move_vector := raw_move_vector.limit_length(1.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

	if state == State.DASHING:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		if dash_timer <= 0.0:
			state = State.IDLE if move_vector.is_zero_approx() else State.WALK
		return

	if dash_pressed and dash_cooldown_timer <= 0.0 and not move_vector.is_zero_approx():
		state = State.DASHING
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		dash_direction = move_vector.normalized()
		velocity = dash_direction * DASH_SPEED
		return

	velocity = move_vector * MOVE_SPEED
	state = State.IDLE if move_vector.is_zero_approx() else State.WALK


func can_dash() -> bool:
	return dash_cooldown_timer <= 0.0 and state != State.DASHING
