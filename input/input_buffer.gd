class_name InputBuffer
extends RefCounted
## Sequenced input sampling + a small FIFO. Two uses: the server's
## per-character jitter buffer (drained via pop_next) and the client's own
## unacked-prediction buffer (trimmed via discard_acked, replayed via
## pending). Pattern inherited from amazing-nauts'
## input/input_buffer.gd, scoped down to Phase 2a (no block/ability
## fields yet -- those arrive with later phases).


class Sample:
	var sequence: int = 0
	var move_vector: Vector2 = Vector2.ZERO
	var dash_pressed: bool = false
	var attack_pressed: bool = false
	var delta: float = 0.0


var _samples: Array[Sample] = []


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
