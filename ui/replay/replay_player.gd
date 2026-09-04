extends Node2D
## Phase 20: hosts a ReplayDriver + a static top-down view of the arena
## (Walls duplicated from maps/test_arena/TestArena.tscn's own fixed
## geometry, ArenaCamera parked at ARENA_CENTER instead of following a
## character -- no replayed character ever claims the camera, since
## none of them are ever is_owned_by_me(), see ReplayDriver's own
## CONTROLLING_PEER_ID_OFFSET doc comment; a static spectator view over
## the whole arena is the correct behavior here anyway, not a gap) and
## VCR-style controls (Play/Pause, Skip Back/Forward, a scrubber).
##
## The replay's own path arrives via SceneTree meta (set by ui/replay/
## replay_list.gd right before change_scene_to_file(), the same
## "read one meta key back out of the tree" hand-off this project has
## no existing precedent for -- simpler than a new autoload just to
## carry one String across a single scene change).

const SKIP_SECONDS := 5.0

@export var driver_path: NodePath = ^"ReplayDriver"
@export var play_pause_button_path: NodePath = ^"Controls/PlayPauseButton"
@export var skip_back_button_path: NodePath = ^"Controls/SkipBackButton"
@export var skip_forward_button_path: NodePath = ^"Controls/SkipForwardButton"
@export var scrubber_path: NodePath = ^"Controls/Scrubber"
@export var status_label_path: NodePath = ^"Controls/StatusLabel"
@export var back_button_path: NodePath = ^"Controls/BackButton"

var _driver: ReplayDriver
var _dragging_scrubber: bool = false


func _ready() -> void:
	_driver = get_node(driver_path)
	_driver.state_changed.connect(_refresh_ui)

	var path: String = get_tree().get_meta("replay_path_to_play", "")
	if path.is_empty():
		_show_status("No replay selected.")
		return
	if not _driver.load_replay(path):
		_show_status(_driver.load_error())
		return

	get_node(play_pause_button_path).pressed.connect(_on_play_pause_pressed)
	get_node(skip_back_button_path).pressed.connect(func(): _driver.skip_seconds(-SKIP_SECONDS))
	get_node(skip_forward_button_path).pressed.connect(func(): _driver.skip_seconds(SKIP_SECONDS))
	get_node(back_button_path).pressed.connect(_on_back_pressed)

	var scrubber: HSlider = get_node(scrubber_path)
	scrubber.min_value = 0
	scrubber.max_value = maxi(_driver.total_ticks(), 1)
	scrubber.drag_started.connect(func(): _dragging_scrubber = true)
	# HSlider's own drag_ended(value_changed) fires on mouse release --
	# seeking only then (not on every value_changed during the drag
	# itself) is deliberate: seek_to_frame() re-simulates from tick 0
	# every call (no checkpoint cache, this phase's own confirmed MVP
	# tradeoff), so seeking on every intermediate drag frame would
	# re-simulate the whole match dozens of times per second while
	# dragging.
	scrubber.drag_ended.connect(_on_scrubber_drag_ended)

	_driver.play()
	_refresh_ui()


func _on_play_pause_pressed() -> void:
	if _driver.is_playing():
		_driver.pause()
	else:
		_driver.play()
	_refresh_ui()


func _on_scrubber_drag_ended(_value_changed: bool) -> void:
	_dragging_scrubber = false
	var scrubber: HSlider = get_node(scrubber_path)
	_driver.seek_to_frame(int(scrubber.value))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/replay/ReplayList.tscn")


func _refresh_ui() -> void:
	if not is_instance_valid(_driver):
		return
	get_node(play_pause_button_path).text = "Pause" if _driver.is_playing() else "Play"
	if not _dragging_scrubber:
		get_node(scrubber_path).value = _driver.ticks_processed()
	var round_wins := _driver.round_wins()
	var status: String
	if _driver.is_finished():
		var winner := _driver.final_winner()
		status = (
			"Match over -- winner: %s" % ("Team/Player %d" % winner if winner != -1 else "Draw")
		)
	else:
		status = "Round %d -- %s" % [_driver.current_round(), _format_round_wins(round_wins)]
	_show_status(status)


func _format_round_wins(round_wins: Dictionary) -> String:
	var parts: Array[String] = []
	for key in round_wins:
		parts.append("%s: %d" % [key, round_wins[key]])
	return ", ".join(parts) if not parts.is_empty() else "0-0"


func _show_status(text: String) -> void:
	get_node(status_label_path).text = text
