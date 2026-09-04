extends Node2D
## Phase 20: hosts a ReplayDriver + a static top-down view of the arena
## (Walls duplicated from maps/test_arena/TestArena.tscn's own fixed
## geometry) and VCR-style controls (Play/Pause, Skip Back/Forward, a
## scrubber). Camera control added 2026-09-04 per the human owner's own
## request: Tab cycles ArenaCamera's target through Characters.get_
## children() (never is_owned_by_me() during replay, see ReplayDriver's
## own CONTROLLING_PEER_ID_OFFSET doc comment -- character_controller.gd's
## normal auto-claim on spawn never fires here, so this script owns
## camera positioning entirely, deliberately never touching ArenaCamera.
## target itself, which would go stale across a round transition's
## _spawn_characters() free()-then-recreate cycle); arrow keys
## (project.godot's own replay_camera_left/right/up/down actions, NOT
## Godot's built-in ui_left/right/up/down -- confirmed live 2026-09-04
## that a synthetic InputEventKey testing this project's own custom
## actions matches reliably via physical_keycode, the same convention
## every other action in this file uses, but the built-ins' own default
## bindings did not match a synthetic event the same way, same class of
## mismatch as memory/gotchas.md's 2026-09-02 ui_cancel entry) decouple
## into a freely-moved camera, Tab re-couples.
## Starts decoupled (ARENA_CENTER, matching this scene's own pre-Tab
## parked position) so the very first frame still shows the whole arena,
## not an arbitrary player. `ArenaCamera`'s own zoom in `ReplayPlayer.
## tscn` was bumped from the default 1.0 to 1.4 at the same time: at 1.0
## and this project's default ~1152x648 viewport, the arena's own
## 1200x800 Walls extend past every edge of the visible area -- the
## human owner's own suspicion ("senti falta do colision debug da
## arena... mas pode ter sido só falta de enquadramento da câmera") was
## exactly right, confirmed by the arena/viewport math, not just the
## missing HitboxViewer node fixed separately the same day.
##
## Once the replay finishes, Play/Pause has nothing left to do
## (ReplayDriver.play() is already a no-op past the end) -- repurposed
## into a "Back to List" button and given keyboard focus instead of
## leaving a dead-looking control on screen, per the human owner's own
## follow-up request for an obvious way back at that point.
##
## The replay's own path arrives via SceneTree meta (set by ui/replay/
## replay_list.gd right before change_scene_to_file(), the same
## "read one meta key back out of the tree" hand-off this project has
## no existing precedent for -- simpler than a new autoload just to
## carry one String across a single scene change).

const SKIP_SECONDS := 5.0
const FREE_CAMERA_SPEED := 600.0
const SPEED_ACTIONS := {
	&"replay_speed_1x": 1,
	&"replay_speed_2x": 2,
	&"replay_speed_4x": 4,
	&"replay_speed_8x": 8,
}

@export var driver_path: NodePath = ^"ReplayDriver"
@export var camera_path: NodePath = ^"ArenaCamera"
@export var characters_path: NodePath = ^"Characters"
@export var play_pause_button_path: NodePath = ^"Controls/PlayPauseButton"
@export var skip_back_button_path: NodePath = ^"Controls/SkipBackButton"
@export var skip_forward_button_path: NodePath = ^"Controls/SkipForwardButton"
@export var scrubber_path: NodePath = ^"Controls/Scrubber"
@export var status_label_path: NodePath = ^"Controls/StatusLabel"
@export var back_button_path: NodePath = ^"Controls/BackButton"

var _driver: ReplayDriver
var _camera: Camera2D
var _dragging_scrubber: bool = false
## -1 means the camera is free (arrow-key controlled); otherwise an
## index into characters_path's children, wrapped every Tab press.
var _camera_target_index: int = -1
## Tracks whether _refresh_ui() already handled the finished-state
## transition (button text swap + focus grab) -- re-armed the moment
## is_finished() goes false again (seeking backward past the end),
## so re-reaching the end via a later seek grabs focus again too, not
## just the very first time ever.
var _finish_ui_shown: bool = false


func _ready() -> void:
	_driver = get_node(driver_path)
	_camera = get_node(camera_path)
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


func _process(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	if _camera_target_index < 0:
		var move := Vector2(
			Input.get_axis(&"replay_camera_left", &"replay_camera_right"),
			Input.get_axis(&"replay_camera_up", &"replay_camera_down")
		)
		_camera.global_position += move * FREE_CAMERA_SPEED * delta
		return
	var target := _character_at(_camera_target_index)
	if target:
		_camera.global_position = target.global_position


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"replay_cycle_camera"):
		get_viewport().set_input_as_handled()
		_cycle_camera_target()
		_refresh_ui()
		return
	for action in SPEED_ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_driver.playback_speed = SPEED_ACTIONS[action]
			_refresh_ui()
			return
	if _camera_target_index >= 0 and _is_free_camera_move_pressed(event):
		_camera_target_index = -1
		_refresh_ui()


func _is_free_camera_move_pressed(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"replay_camera_left")
		or event.is_action_pressed(&"replay_camera_right")
		or event.is_action_pressed(&"replay_camera_up")
		or event.is_action_pressed(&"replay_camera_down")
	)


## Wraps -1 (free camera) into 0 the same as any other index, so Tab
## from free camera both re-couples AND lands on a real player -- one
## rule instead of a special case for "was free" vs "was already
## coupled".
func _cycle_camera_target() -> void:
	var characters := get_node_or_null(characters_path)
	var count := characters.get_child_count() if characters else 0
	if count == 0:
		return
	_camera_target_index = (_camera_target_index + 1) % count


func _character_at(index: int) -> Node2D:
	var characters := get_node_or_null(characters_path)
	if not characters or characters.get_child_count() == 0:
		return null
	return characters.get_child(index % characters.get_child_count()) as Node2D


## Once the replay is finished, Play/Pause has nothing left to do
## (ReplayDriver.play() is already a no-op past the end) -- repurposed
## into a "Back to List" button instead of leaving a dead-looking
## control on screen, per the human owner's own request for an obvious
## way back once playback reaches the end.
func _on_play_pause_pressed() -> void:
	if _driver.is_finished():
		_on_back_pressed()
		return
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
	var play_pause_button: Button = get_node(play_pause_button_path)
	if _driver.is_finished():
		play_pause_button.text = "Back to List"
		if not _finish_ui_shown:
			_finish_ui_shown = true
			play_pause_button.grab_focus()
	else:
		_finish_ui_shown = false
		play_pause_button.text = "Pause" if _driver.is_playing() else "Play"
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
	status += " | Cam: %s | Speed: %dx" % [_camera_status_text(), _driver.playback_speed]
	_show_status(status)


func _camera_status_text() -> String:
	return "Free" if _camera_target_index < 0 else "Player %d" % (_camera_target_index + 1)


func _format_round_wins(round_wins: Dictionary) -> String:
	var parts: Array[String] = []
	for key in round_wins:
		parts.append("%s: %d" % [key, round_wins[key]])
	return ", ".join(parts) if not parts.is_empty() else "0-0"


func _show_status(text: String) -> void:
	get_node(status_label_path).text = text
