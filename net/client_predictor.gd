class_name ClientPredictor
extends RefCounted
## Client-side unacked-input bookkeeping for the locally predicted
## character: every input applied locally before the server confirms it
## goes into this buffer, so a later correction can discard whatever the
## server already processed and replay only what's left. Pure logic, no
## node/RPC dependency. Pattern inherited from amazing-nauts'
## net/client_predictor.gd. See docs/blueprint/03-networking-and-match-modes.md.


## Everything apply_input() reads or mutates besides position: the dash
## timers and FSM state. Recorded alongside each predicted input so
## reconcile() can roll the character back to exactly how it looked right
## after the last acked input was applied, not whatever these have
## drifted to since -- replaying a sample against un-rewound timer/FSM
## state could re-trigger a one-shot action like dash that already fired.
class Checkpoint:
	var sequence: int = 0
	var dash_timer: float = 0.0
	var dash_cooldown_timer: float = 0.0
	var dash_direction: Vector2 = Vector2.ZERO
	var facing_direction: Vector2 = Vector2.RIGHT
	var fsm_state: int = 0
	## Phase 2a's action layer is exactly as reconciliation-sensitive as
	## the locomotion fields above -- move activation is a one-shot,
	## state-gated trigger like dash.
	var action_state: int = 0
	var action_move: MoveDefinition
	var action_move_frame: int = 0
	## Phase 3's independent ability slots -- each has its own ActionFsm
	## and cooldown, exactly as reconciliation-sensitive as the shared
	## action layer above for the same reason (activation is a one-shot,
	## cooldown-gated trigger). *_move mirrors action_move above -- found
	## missing live during Phase 15 (see memory/gotchas.md): without it,
	## restoring a checkpoint left current_move at whatever it happened
	## to already be (often null), and ActionFsm.advance_frame()
	## dereferences current_move unconditionally once state isn't
	## NEUTRAL, crashing on replay. Latent for Q/E since Phase 3; R/F's
	## own live test is what first hit the exact reconciliation timing
	## that triggers it.
	var ability_q_state: int = 0
	var ability_q_move_frame: int = 0
	var ability_q_cooldown_frames: int = 0
	var ability_q_move: MoveDefinition
	var ability_e_state: int = 0
	var ability_e_move_frame: int = 0
	var ability_e_cooldown_frames: int = 0
	var ability_e_move: MoveDefinition
	## Phase 15's 2 new class ability slots -- same reconciliation
	## treatment as Q/E above.
	var ability_r_state: int = 0
	var ability_r_move_frame: int = 0
	var ability_r_cooldown_frames: int = 0
	var ability_r_move: MoveDefinition
	var ability_f_state: int = 0
	var ability_f_move_frame: int = 0
	var ability_f_cooldown_frames: int = 0
	var ability_f_move: MoveDefinition
	## Phase 16: the boot's own T-bound active slot -- same
	## reconciliation treatment as every ability slot above, including
	## *_move (see this class's own doc comment on why that field is
	## required, not optional).
	var boot_active_state: int = 0
	var boot_active_move_frame: int = 0
	var boot_active_cooldown_frames: int = 0
	var boot_active_move: MoveDefinition


var _buffer := InputBuffer.new()
var _checkpoints: Array[Checkpoint] = []


func record_predicted_input(sample: InputBuffer.Sample, checkpoint: Checkpoint) -> void:
	_buffer.push(sample)
	_checkpoints.append(checkpoint)


## The checkpoint recorded right after the input with this sequence was
## applied, or null if none was recorded. Does not mutate any bookkeeping
## -- call before reconcile(), which discards it.
func state_at(sequence: int) -> Checkpoint:
	for checkpoint in _checkpoints:
		if checkpoint.sequence == sequence:
			return checkpoint
	return null


## Trims every input the server has already confirmed and returns
## whatever's left to replay on top of the just-received authoritative
## state, restoring "now" after the snap back to "server's last known".
func reconcile(last_acked_sequence: int) -> Array[InputBuffer.Sample]:
	_buffer.discard_acked(last_acked_sequence)
	while not _checkpoints.is_empty() and _checkpoints[0].sequence <= last_acked_sequence:
		_checkpoints.pop_front()
	return _buffer.pending()
