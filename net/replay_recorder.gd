extends Node
## Server-only structured replay recording -- see memory/plan.md's
## roadmap item 19. Writes user://replays/<timestamp>.replay (JSONL,
## matching net/game_log.gd's own established format for this
## project), one line per record: a "header" (mode, friendly-fire,
## round target, sim_seed, initial loadouts), "loadout_change" records
## (round-intermission re-picks only -- Room Config's own initial pick
## is already in the header), "tick" records (every currently-
## authoritative character's raw InputBuffer.Sample for that tick --
## no calculated/derived value, position, health, or damage result is
## ever stored), "round_end" records, and a final "match_end" record.
##
## Separate file/system from net/game_log.gd's own human-readable
## debug log, per the human owner's own explicit request to keep them
## split -- they serve different readers (a developer debugging an
## incident vs. a deterministic reconstruction for playback, Phase 20).
##
## sim_seed is reserved, unused today: confirmed 2026-09-04 the
## simulation has zero RNG in any gameplay-affecting code outside the
## reconnect token (net/player_spawner.gd's own token string, which
## never affects gameplay state) -- recorded now anyway since
## retrofitting it into an already-shipped replay format later would
## cost far more than reserving one int field now.
##
## Lifecycle differs from GameLog's own simple "open on first call,
## append for the process lifetime": a replay genuinely has a start
## (the header, only meaningful once, at match start) and an end (a
## flush of any still-pending tick record, then close) -- start_
## recording()/record_match_end() are that lifecycle's real bookends.
## _recording being false is therefore the single source of truth for
## "am I allowed to write" everywhere below except start_recording()
## itself (which is the only place that ever sets it true, itself
## gated on NetworkManager.is_server()) -- every other record_*()
## function trusts that gate instead of re-checking is_server() itself.

var _file: FileAccess = null
var _replay_path: String = ""
var _replay_dir: String = "user://replays"
var _files_opened: int = 0
var _recording: bool = false

## Batches every connected peer's Sample for the CURRENT tick, flushed
## as one combined record the moment a later tick's first sample
## arrives (see record_tick_sample()'s own doc comment for why the key
## is Engine.get_physics_frames(), not any per-character counter).
var _pending_tick: int = -1
var _pending_samples: Array = []


## Called once per match, at the moment Room Config's countdown
## actually starts it (net/lobby_state.gd's own _start_match(), the
## same hook net/game_log.gd's _log_final_loadouts() already uses) --
## a peer that never goes through Room Config (net/dev_bootstrap.gd's
## direct-connect flow) never calls this, so it never gets a replay:
## there is no real "loadout choice" to record for it in the first
## place (PlayerSpawner's own index-0 fallback applies instead), which
## matches the human owner's own framing of this feature as recording
## "as escolhas dos jogadores."
func start_recording(mode: String, friendly_fire: bool, round_target: int, loadouts: Array) -> void:
	if not NetworkManager.is_server():
		return
	_ensure_file_open()
	if not _file:
		return
	_recording = true
	_pending_tick = -1
	_pending_samples.clear()
	_write_line(
		{
			"type": "header",
			"mode": mode,
			"friendly_fire": friendly_fire,
			"round_target": round_target,
			"sim_seed": randi(),
			"loadouts": loadouts,
		}
	)


## Called from net/lobby_state.gd's _apply_weapon()/_apply_boot()/
## _apply_perk() ONLY while MatchState.current_phase ==
## ROUND_INTERMISSION -- Room Config's own initial pick is already
## captured in the header's own "loadouts" array, so logging every
## Room Config dropdown change too would be redundant noise (same
## "final pick only" reasoning GameLog's own _log_final_loadouts()
## already uses).
func record_loadout_change(
	peer_id: int, weapon_id: String, boot_id: String, perk_id: String
) -> void:
	if not _recording:
		return
	_write_line(
		{
			"type": "loadout_change",
			"peer_id": peer_id,
			"weapon": weapon_id,
			"boot": boot_id,
			"perk": perk_id
		}
	)


## Called from CharacterController._physics_step_authoritative(),
## once per currently-authoritative character, every physics tick --
## the exact point the server already consumes that character's own
## next buffered Sample. `tick` must be Engine.get_physics_frames(), a
## single monotonic counter for the whole process, NOT ServerSim.
## tick_count() -- that counter is PER-CHARACTER and resets to 0 for a
## character freshly spawned by a round transition (Phase 17's own
## reload-based round reset), so 2 different rounds' characters would
## otherwise report colliding tick numbers. Every character's own
## _physics_process() call happens within the same physics frame, so
## Engine.get_physics_frames() is identical across all of them on any
## given tick -- that's what makes the batching below correct.
func record_tick_sample(tick: int, peer_id: int, sample: InputBuffer.Sample) -> void:
	if not _recording:
		return
	if tick != _pending_tick:
		_flush_pending_tick()
		_pending_tick = tick
	_pending_samples.append({"peer_id": peer_id, "sample": sample_to_dict(sample)})


func record_round_end(
	completed_round: int, winner: int, is_draw: bool, round_wins: Dictionary
) -> void:
	if not _recording:
		return
	_write_line(
		{
			"type": "round_end",
			"completed_round": completed_round,
			"winner": winner,
			"is_draw": is_draw,
			"round_wins": round_wins,
		}
	)


## The definitive "this match is truly over" point -- flushes any
## still-pending tick record, writes the final line, then closes the
## file. Idempotent past the first call (mirrors core/match_state.gd's
## own enter_post_game() no-op-once-POST_GAME guarantee, which is what
## calls this): _recording is false after the first call, so every
## record_*() call reached afterward (including a repeated
## record_match_end() itself) is silently a no-op.
func record_match_end(winner: int, round_wins: Dictionary) -> void:
	if not _recording:
		return
	_flush_pending_tick()
	_write_line({"type": "match_end", "winner": winner, "round_wins": round_wins})
	_recording = false
	if _file:
		_file.close()
	_file = null


func current_replay_path() -> String:
	return _replay_path


## Pure, no I/O -- directly unit-testable. Vector2 fields become
## [x, y] arrays since Godot's JSON.stringify() has no native Vector2
## representation.
static func sample_to_dict(sample: InputBuffer.Sample) -> Dictionary:
	return {
		"sequence": sample.sequence,
		"move_vector": [sample.move_vector.x, sample.move_vector.y],
		"dash_pressed": sample.dash_pressed,
		"attack_pressed": sample.attack_pressed,
		"aim_direction": [sample.aim_direction.x, sample.aim_direction.y],
		"skillshot_pressed": sample.skillshot_pressed,
		"ability_q_pressed": sample.ability_q_pressed,
		"ability_e_pressed": sample.ability_e_pressed,
		"ability_r_pressed": sample.ability_r_pressed,
		"ability_f_pressed": sample.ability_f_pressed,
		"boot_active_pressed": sample.boot_active_pressed,
		"delta": sample.delta,
	}


## Test-only: closes any open file and points future writes at a fresh
## file under replay_dir (a scratch directory in tests, never the real
## user://replays/ default), mirroring net/game_log.gd's own reset_
## for_testing() exactly.
func reset_for_testing(replay_dir: String = "user://replays") -> void:
	if _file:
		_file.close()
	_file = null
	_replay_path = ""
	_replay_dir = replay_dir
	_recording = false
	_pending_tick = -1
	_pending_samples.clear()


func _flush_pending_tick() -> void:
	if _pending_tick < 0 or _pending_samples.is_empty():
		_pending_tick = -1
		_pending_samples.clear()
		return
	_write_line({"type": "tick", "tick": _pending_tick, "samples": _pending_samples})
	_pending_tick = -1
	_pending_samples.clear()


func _write_line(data: Dictionary) -> void:
	if not _file:
		return
	_file.store_line(JSON.stringify(data))
	_file.flush()


func _ensure_file_open() -> void:
	if _file:
		return
	DirAccess.make_dir_recursive_absolute(_replay_dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_replay_path = (
		"%s/%s_pid%d_%d.replay" % [_replay_dir, stamp, OS.get_process_id(), _files_opened]
	)
	_files_opened += 1
	_file = FileAccess.open(_replay_path, FileAccess.WRITE)
