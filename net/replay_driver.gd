class_name ReplayDriver
extends Node
## Phase 20: offline, non-networked reconstruction of a net/
## replay_recorder.gd `.replay` file (JSONL: header, loadout_change,
## tick, round_end, match_end -- see that file's own doc comment for
## the exact record shapes). Not an autoload -- owned by ui/replay/
## ReplayPlayer.tscn, one instance per playback session.
##
## Reuses the REAL simulation, not a reimplementation: every spawned
## character resolves ControlMode.AUTHORITATIVE (NetworkManager.
## is_server() is true by default with no real MultiplayerPeer
## assigned, confirmed live 2026-09-04), and each tick record is
## replayed by pushing its recorded Sample into that character's own
## ServerSim buffer and calling its own _physics_step_authoritative()
## -- the exact method a live server tick already calls. Feeding the
## same inputs through the same deterministic code (confirmed zero RNG
## in gameplay-affecting logic outside the reconnect token, which never
## touches simulation state) reproduces the match exactly.
##
## controlling_peer_id is deliberately NOT the raw recorded peer_id --
## offset by CONTROLLING_PEER_ID_OFFSET so it can never equal
## multiplayer.get_unique_id() (1 by default). Without this,
## is_owned_by_me() would be true for whichever replayed character
## happens to carry peer_id 1 (the original host, in most real
## matches), and _physics_step_authoritative()'s own `if
## is_owned_by_me(): _server_sim.record_input(_sample_local_input(...))`
## would push a SECOND, bogus, real-OS-input-derived Sample into that
## character's buffer for the same tick, right alongside the correct
## recorded one this driver pushes -- corrupting the exact 1:1
## tick-to-Sample correspondence replay fidelity depends on. The node's
## own `name` (used by CharacterController._apply_*_from_lobby_state()'s
## own str(name).to_int() lookups against the pre-populated LobbyState
## below) stays the real peer_id -- only controlling_peer_id is offset.
signal state_changed

const CONTROLLING_PEER_ID_OFFSET := 1_000_000

@export var characters_path: NodePath = ^"../Characters"

var _header: Dictionary = {}
var _records: Array = []
var _tick_record_count: int = 0
var _roster: Array = []
var _current_loadouts: Dictionary = {}

var _record_cursor: int = 0
var _ticks_processed: int = 0
var _is_playing: bool = false
var _current_round: int = 1
var _round_wins: Dictionary = {}
var _is_finished: bool = false
var _final_winner: int = -1
var _load_error: String = ""


func _physics_process(_delta: float) -> void:
	if not _is_playing or _is_finished:
		return
	_apply_next_tick_record()
	state_changed.emit()


## Parses the whole file into memory up front (small enough for this
## project's own match lengths -- a checkpoint cache would matter at a
## much larger scale, deferred per memory/plan.md's roadmap item 20).
## Returns false (and load_error() explains why) on a missing/empty/
## header-less file -- callers should show that to the player rather
## than silently failing.
func load_replay(path: String) -> bool:
	_load_error = ""
	if not FileAccess.file_exists(path):
		_load_error = "Replay file not found: %s" % path
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_load_error = "Could not open replay file: %s" % path
		return false
	_records.clear()
	_tick_record_count = 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		var record := parse_line(line)
		if record.is_empty():
			continue
		_records.append(record)
		if record["type"] == "tick":
			_tick_record_count += 1
	file.close()
	if _records.is_empty() or _records[0]["type"] != "header":
		_load_error = "Replay file has no header record: %s" % path
		return false
	_header = _records[0]
	_roster = _header["loadouts"]
	_reset_playback_state()
	return true


func load_error() -> String:
	return _load_error


func total_ticks() -> int:
	return _tick_record_count


func ticks_processed() -> int:
	return _ticks_processed


func is_playing() -> bool:
	return _is_playing


func is_finished() -> bool:
	return _is_finished


func current_round() -> int:
	return _current_round


func round_wins() -> Dictionary:
	return _round_wins


func final_winner() -> int:
	return _final_winner


func play() -> void:
	if not _is_finished:
		_is_playing = true


func pause() -> void:
	_is_playing = false


## Re-simulates from tick 0 up to target_frame (a dense index into the
## recorded tick sequence, 0..total_ticks()-1 -- NOT the raw `tick`
## field, which is Engine.get_physics_frames() and neither starts at 0
## nor increments by exactly 1 every record, see net/replay_recorder.gd's
## own doc comment). No render/real-time wait during the fast-forward --
## a deliberate MVP tradeoff, no checkpoint cache (memory/plan.md's
## roadmap item 20).
func seek_to_frame(target_frame: int) -> void:
	var was_playing := _is_playing
	_is_playing = false
	_reset_playback_state()
	var clamped_target := clampi(target_frame, 0, _tick_record_count)
	# A target at or past the last recorded tick also consumes any
	# trailing non-tick records (round_end/match_end) rather than
	# stopping the instant the tick count is reached -- otherwise
	# seeking to "the end" would leave is_finished() false forever,
	# since match_end is itself a non-tick record one step past the
	# last tick.
	var play_to_end := target_frame >= _tick_record_count
	while not _is_finished and _record_cursor < _records.size():
		if not play_to_end and _ticks_processed >= clamped_target:
			break
		_apply_next_tick_record()
	_is_playing = was_playing and not _is_finished
	state_changed.emit()


## Skips by real seconds, converted at this project's fixed 60Hz
## physics tick rate (docs/blueprint/03-networking-and-match-modes.md).
func skip_seconds(seconds: float) -> void:
	var delta_frames := int(seconds * Engine.physics_ticks_per_second)
	seek_to_frame(_ticks_processed + delta_frames)


## Pure -- one JSONL line to a typed Dictionary, with every numeric
## field explicitly cast back from JSON.parse_string()'s own "every
## number is a float" behavior (confirmed live by Phase 19's own fork,
## see memory/gotchas.md 2026-09-04). A malformed/unparseable line
## returns {} rather than raising -- callers skip it, matching this
## project's own "fail loudly on real bugs, not on ordinary user-data
## noise" boundary (a corrupt replay file is user-supplied data, not a
## code invariant).
static func parse_line(line: String) -> Dictionary:
	# The instance API (not the static JSON.parse_string() convenience
	# wrapper) is deliberate: JSON.parse_string() prints a real engine
	# error on malformed input even though it also returns null
	# gracefully -- noisy for a boundary that's expected to sometimes
	# see a corrupt/truncated line (a crash mid-write), found live via
	# this file's own test_parse_line_malformed_json_returns_empty_dict.
	var json := JSON.new()
	if json.parse(line) != OK:
		return {}
	var parsed: Variant = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("type"):
		return {}
	var data: Dictionary = parsed
	match data["type"]:
		"header":
			return {
				"type": "header",
				"mode": int(data.get("mode", 0)),
				"friendly_fire": bool(data.get("friendly_fire", false)),
				"round_target": int(data.get("round_target", 1)),
				"sim_seed": int(data.get("sim_seed", 0)),
				"loadouts": _typed_loadouts(data.get("loadouts", [])),
			}
		"loadout_change":
			return {
				"type": "loadout_change",
				"peer_id": int(data.get("peer_id", 0)),
				"weapon": String(data.get("weapon", "")),
				"boot": String(data.get("boot", "")),
				"perk": String(data.get("perk", "")),
			}
		"tick":
			return {
				"type": "tick",
				"tick": int(data.get("tick", 0)),
				"samples": _typed_tick_samples(data.get("samples", [])),
			}
		"round_end":
			return {
				"type": "round_end",
				"completed_round": int(data.get("completed_round", 0)),
				"winner": int(data.get("winner", -1)),
				"is_draw": bool(data.get("is_draw", false)),
				"round_wins": _typed_int_dict(data.get("round_wins", {})),
			}
		"match_end":
			return {
				"type": "match_end",
				"winner": int(data.get("winner", -1)),
				"round_wins": _typed_int_dict(data.get("round_wins", {})),
			}
		_:
			return {}


## Inverse of net/replay_recorder.gd's own sample_to_dict() -- pure, no
## I/O, directly unit-testable.
static func sample_from_dict(data: Dictionary) -> InputBuffer.Sample:
	var sample := InputBuffer.Sample.new()
	sample.sequence = int(data.get("sequence", 0))
	sample.move_vector = _vector2_from_array(data.get("move_vector", [0.0, 0.0]))
	sample.dash_pressed = bool(data.get("dash_pressed", false))
	sample.attack_pressed = bool(data.get("attack_pressed", false))
	sample.aim_direction = _vector2_from_array(data.get("aim_direction", [1.0, 0.0]))
	sample.skillshot_pressed = bool(data.get("skillshot_pressed", false))
	sample.ability_q_pressed = bool(data.get("ability_q_pressed", false))
	sample.ability_e_pressed = bool(data.get("ability_e_pressed", false))
	sample.ability_r_pressed = bool(data.get("ability_r_pressed", false))
	sample.ability_f_pressed = bool(data.get("ability_f_pressed", false))
	sample.boot_active_pressed = bool(data.get("boot_active_pressed", false))
	sample.delta = float(data.get("delta", 0.0))
	return sample


static func _typed_loadouts(raw: Array) -> Array:
	var result := []
	for entry in raw:
		(
			result
			. append(
				{
					"peer_id": int(entry.get("peer_id", 0)),
					"class": String(entry.get("class", "")),
					"team": int(entry.get("team", -1)),
					"weapon": String(entry.get("weapon", "")),
					"boot": String(entry.get("boot", "")),
					"perk": String(entry.get("perk", "")),
				}
			)
		)
	return result


static func _typed_tick_samples(raw: Array) -> Array:
	var result := []
	for entry in raw:
		result.append({"peer_id": int(entry.get("peer_id", 0)), "sample": entry.get("sample", {})})
	return result


static func _typed_int_dict(raw: Dictionary) -> Dictionary:
	var result := {}
	for key in raw:
		result[int(key) if String(key).is_valid_int() else key] = int(raw[key])
	return result


static func _vector2_from_array(raw) -> Vector2:
	if typeof(raw) != TYPE_ARRAY or raw.size() < 2:
		return Vector2.ZERO
	return Vector2(float(raw[0]), float(raw[1]))


## Frees every spawned character and respawns the full roster from
## _current_loadouts (reset to the header's own initial loadouts),
## rewinding all playback bookkeeping to tick 0 / round 1. Shared by
## load_replay() (first spawn) and seek_to_frame() (every seek
## re-simulates from scratch, see that function's own doc comment).
func _reset_playback_state() -> void:
	_record_cursor = 1  # skip the header record itself, already consumed
	_ticks_processed = 0
	_current_round = 1
	_round_wins = {}
	_is_finished = false
	_final_winner = -1
	_current_loadouts.clear()
	for entry in _roster:
		_current_loadouts[entry["peer_id"]] = entry
	_spawn_characters()


func _apply_next_tick_record() -> void:
	while _record_cursor < _records.size():
		var record: Dictionary = _records[_record_cursor]
		_record_cursor += 1
		match record["type"]:
			"loadout_change":
				_apply_loadout_change(record)
			"tick":
				_apply_tick(record)
				_ticks_processed += 1
				return
			"round_end":
				_apply_round_end(record)
			"match_end":
				_final_winner = record["winner"]
				_round_wins = record["round_wins"]
				_is_finished = true
				_is_playing = false
				return
	_is_finished = true
	_is_playing = false


func _apply_loadout_change(record: Dictionary) -> void:
	var peer_id: int = record["peer_id"]
	if not _current_loadouts.has(peer_id):
		return
	var loadout: Dictionary = _current_loadouts[peer_id]
	loadout["weapon"] = record["weapon"]
	loadout["boot"] = record["boot"]
	loadout["perk"] = record["perk"]


func _apply_round_end(record: Dictionary) -> void:
	_current_round = record["completed_round"] + 1
	_round_wins = record["round_wins"]
	_spawn_characters()


func _apply_tick(record: Dictionary) -> void:
	var characters := get_node(characters_path)
	for entry in record["samples"]:
		var peer_id: int = entry["peer_id"]
		var character := characters.get_node_or_null(str(peer_id)) as CharacterController
		if not character:
			continue
		var sample := sample_from_dict(entry["sample"])
		character.replay_step_authoritative(sample)


## Rebuilds every roster member's character node from _current_loadouts
## -- called once at tick 0 and again after every round_end, mirroring
## the real match's own reload-based round reset (Phase 17) with the
## same full stat/position/cooldown reset that gives it, minus the
## actual scene reload (unnecessary here -- see net/reconnect_manager.gd's
## own doc comment on why a live scene reload is otherwise risky;
## freeing and re-instantiating character nodes directly, without
## touching MultiplayerSpawner/replication, carries none of that risk).
##
## Spawn positions reuse the real net/player_spawner.gd formula (a
## throwaway, never-added-to-tree PlayerSpawner instance -- its
## position math touches no tree/self-node state, confirmed by reading
## it before reuse) rather than reimplementing it. KNOWN LIMITATION,
## documented not solved (position is a calculated value, deliberately
## never recorded to the replay file per this project's own "no
## calculated values" design): the exact original spawn order this
## reproduces is _roster's own stored order (LobbyState.player_class_ids'
## Dictionary insertion order at record time, i.e. registration order),
## which matches the real match's own connection order for the common
## host-then-clients case this project's small match sizes always have,
## but isn't a value this driver can verify against the file itself.
func _spawn_characters() -> void:
	var characters := get_node(characters_path)
	for child in characters.get_children():
		child.queue_free()
	MatchState.match_mode = _header["mode"] as MatchState.MatchMode
	var position_calculator := PlayerSpawner.new()
	for entry in _roster:
		var peer_id: int = entry["peer_id"]
		var loadout: Dictionary = _current_loadouts.get(peer_id, entry)
		LobbyState.player_weapon_ids[peer_id] = loadout["weapon"]
		LobbyState.player_boot_ids[peer_id] = loadout["boot"]
		LobbyState.player_perk_ids[peer_id] = loadout["perk"]
		var class_index := LobbyState.CLASS_IDS.find(loadout.get("class", entry["class"]))
		var class_scene: PackedScene = PlayerSpawner.CLASS_SCENES[maxi(class_index, 0)]
		var character: CharacterController = class_scene.instantiate()
		character.name = str(peer_id)
		character.controlling_peer_id = peer_id + CONTROLLING_PEER_ID_OFFSET
		character.team = entry["team"]
		character.position = position_calculator._spawn_position_for(entry["team"])
		characters.add_child(character)
	position_calculator.free()
