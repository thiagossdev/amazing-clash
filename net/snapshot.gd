class_name CharacterSnapshot
extends RefCounted
## One character's authoritative state as broadcast by the server:
## position, locomotion FSM state, and the input sequence the server had
## processed for its owner as of this tick (used for reconciliation to
## trim the client's unacked input buffer). interpolate() renders a
## remote character between the last two received snapshots -- no
## prediction, there's nothing to predict about something already in the
## past by the time it arrives. Pattern inherited from amazing-nauts'
## net/snapshot.gd, scoped down to Phase 1 (no health/team/action-state
## fields yet -- those arrive with Phase 2+).
## See docs/blueprint/03-networking-and-match-modes.md.

var tick: int = 0
var position: Vector2 = Vector2.ZERO
var fsm_state: int = 0
var last_acked_sequence: int = 0


static func make(
	tick: int, position: Vector2, fsm_state: int, last_acked_sequence: int
) -> CharacterSnapshot:
	var snapshot := CharacterSnapshot.new()
	snapshot.tick = tick
	snapshot.position = position
	snapshot.fsm_state = fsm_state
	snapshot.last_acked_sequence = last_acked_sequence
	return snapshot


## Renders a position between two known snapshots, driven by the client's
## own local clock rather than any server/client clock sync (out of scope
## for Phase 1): elapsed_since_latest is how long ago "latest" arrived,
## previous_interval is how long "previous" and "latest" were apart when
## they arrived. Clamped at t=1 (holds at latest, never extrapolates past
## it) so a late or dropped next snapshot can't overshoot.
static func interpolate(
	previous: CharacterSnapshot,
	latest: CharacterSnapshot,
	elapsed_since_latest: float,
	previous_interval: float
) -> Vector2:
	if previous_interval <= 0.0:
		return latest.position
	var t := clampf(elapsed_since_latest / previous_interval, 0.0, 1.0)
	return previous.position.lerp(latest.position, t)
