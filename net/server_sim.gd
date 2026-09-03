class_name ServerSim
extends RefCounted
## Per-character server-side simulation bookkeeping: a small jitter buffer
## over InputBuffer, a stale-input fallback policy, and the snapshot
## broadcast cadence gate (60Hz tick downsampled to ~30Hz, per
## docs/blueprint/03-networking-and-match-modes.md's 20-30Hz replication
## target). Pure logic, no node/RPC dependency, unit-testable standalone.
## Pattern inherited from amazing-nauts' net/server_sim.gd.

const SNAPSHOT_EVERY_N_TICKS := 2
const STALE_INPUT_TIMEOUT_TICKS := 12  # ~0.2s @60Hz

var _buffer := InputBuffer.new()
var _last_input: InputBuffer.Sample
var _ticks_since_fresh_input: int = 0
var _tick_count: int = 0
var _last_processed_sequence: int = 0


func record_input(sample: InputBuffer.Sample) -> void:
	_buffer.push(sample)


## Consumes the oldest buffered input for this tick. Falls back to the
## last known input's move vector for a short window (packet loss
## shouldn't stop a character mid-stride), then to a neutral (no-input)
## sample once that window expires, so a sustained drop doesn't run the
## character forever.
func next_input(delta: float) -> InputBuffer.Sample:
	var sample := _buffer.pop_next()
	if sample:
		_last_input = sample
		_ticks_since_fresh_input = 0
		_last_processed_sequence = sample.sequence
		return sample

	_ticks_since_fresh_input += 1
	if _last_input and _ticks_since_fresh_input <= STALE_INPUT_TIMEOUT_TICKS:
		return _repeat_holding_move_only(_last_input, delta)
	return _neutral_sample(delta)


func should_broadcast_snapshot() -> bool:
	_tick_count += 1
	return _tick_count % SNAPSHOT_EVERY_N_TICKS == 0


func tick_count() -> int:
	return _tick_count


func last_processed_sequence() -> int:
	return _last_processed_sequence


func _neutral_sample(delta: float) -> InputBuffer.Sample:
	var sample := InputBuffer.Sample.new()
	sample.delta = delta
	return sample


## Repeats a stale sample's held move vector but never its edge-triggered
## dash press: replaying the same dash press across several fallback
## ticks would re-trigger the dash every tick instead of once.
func _repeat_holding_move_only(sample: InputBuffer.Sample, delta: float) -> InputBuffer.Sample:
	var repeated := InputBuffer.Sample.new()
	repeated.sequence = sample.sequence
	repeated.move_vector = sample.move_vector
	repeated.delta = delta
	return repeated
