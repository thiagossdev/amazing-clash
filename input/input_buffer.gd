class_name InputBuffer
extends RefCounted
## Sequenced input sampling + a small FIFO. Two uses: the server's
## per-character jitter buffer (drained via pop_next) and the client's own
## unacked-prediction buffer (trimmed via discard_acked, replayed via
## pending). Pattern inherited from amazing-nauts'
## input/input_buffer.gd, scoped down to Phase 3 (no block yet -- that
## arrives with a later phase).


class Sample:
	var sequence: int = 0
	var move_vector: Vector2 = Vector2.ZERO
	var dash_pressed: bool = false
	var attack_pressed: bool = false
	## Skillshot's real mouse-aim direction, sampled every tick regardless
	## of whether skillshot_pressed is true this tick -- captured at the
	## exact tick the cast starts (see character_controller.gd), not
	## read live later, so a moved mouse during windup doesn't retarget
	## an already-cast skillshot.
	var aim_direction: Vector2 = Vector2.RIGHT
	var skillshot_pressed: bool = false
	var ability_q_pressed: bool = false
	var ability_e_pressed: bool = false
	var delta: float = 0.0


var _samples: Array[Sample] = []


## Packs this Sample's 4 ability press flags into one bitmask int --
## individual bool RPC params would have pushed
## CharacterController._rpc_send_input() past gdlint's function-arg cap,
## same reasoning amazing-nauts' own pack_ability_flags() documents.
## Bit order: attack, skillshot, ability_q, ability_e. Pure, testable
## without an RPC round trip.
static func pack_ability_flags(sample: Sample) -> int:
	var flags := 0
	if sample.attack_pressed:
		flags |= 1 << 0
	if sample.skillshot_pressed:
		flags |= 1 << 1
	if sample.ability_q_pressed:
		flags |= 1 << 2
	if sample.ability_e_pressed:
		flags |= 1 << 3
	return flags


## Inverse of pack_ability_flags() -- mutates `sample` in place.
static func unpack_ability_flags(sample: Sample, flags: int) -> void:
	sample.attack_pressed = flags & (1 << 0) != 0
	sample.skillshot_pressed = flags & (1 << 1) != 0
	sample.ability_q_pressed = flags & (1 << 2) != 0
	sample.ability_e_pressed = flags & (1 << 3) != 0


func push(sample: Sample) -> void:
	_samples.append(sample)


func pop_next() -> Sample:
	return _samples.pop_front() if not _samples.is_empty() else null


func is_empty() -> bool:
	return _samples.is_empty()


func size() -> int:
	return _samples.size()


## Drops every buffered sample the server has already confirmed
## (sequence <= last_acked_sequence). Reconciliation only needs to replay
## whatever is left.
func discard_acked(last_acked_sequence: int) -> void:
	while not _samples.is_empty() and _samples[0].sequence <= last_acked_sequence:
		_samples.pop_front()


func pending() -> Array[Sample]:
	return _samples.duplicate()
