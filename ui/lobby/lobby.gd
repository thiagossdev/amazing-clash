extends Control
## Minimal Phase 7 waiting room: shows who's connected and their
## chosen class (from LobbyState), host-only Start button. Game mode,
## friendly fire, manual team assignment, ready-check, and perks are
## Slice 8/9's job, not this screen's yet (see memory/plan.md's
## "Slices 7-10").

@onready var _player_list_label: Label = $PlayerListLabel
@onready var _start_button: Button = $StartButton
@onready var _waiting_label: Label = $WaitingLabel


func _ready() -> void:
	var is_host := NetworkManager.is_server()
	_start_button.visible = is_host
	_waiting_label.visible = not is_host
	_start_button.pressed.connect(_on_start_pressed)
	LobbyState.registry_changed.connect(_refresh_player_list)
	EventBus.match_state_changed.connect(_on_match_state_changed)
	_refresh_player_list()
	_maybe_dev_autostart(is_host)


func _on_start_pressed() -> void:
	MatchState.enter_loading()


## LOADING (not IN_PROGRESS) is the scene-change trigger -- every peer
## switches to TestArena.tscn here, then net/loading_reporter.gd
## reports back once that peer's own tree is actually ready. The
## server only calls enter_in_progress() once everyone has reported,
## by which point every peer is already inside TestArena -- no further
## scene change needed for that transition. See core/match_state.gd's
## Phase 7 doc comment.
func _on_match_state_changed(_new_phase: int) -> void:
	if MatchState.current_phase == MatchState.Phase.LOADING:
		get_tree().change_scene_to_file("res://maps/test_arena/TestArena.tscn")


func _refresh_player_list() -> void:
	var lines: Array[String] = []
	for peer_id in LobbyState.player_class_ids:
		lines.append("Peer %s: %s" % [peer_id, LobbyState.player_class_ids[peer_id]])
	_player_list_label.text = "\n".join(lines)


## Headless dev testing hook -- polls (rather than a fixed delay, which
## proved unreliable: 2 independent OS processes launched from 2
## separate tool calls have no shared clock, and Godot's own headless
## cold-start time varies) for a 2nd player to register in LobbyState
## before auto-starting, up to a bounded wait so a genuinely solo run
## doesn't hang forever either.
func _maybe_dev_autostart(is_host: bool) -> void:
	if not is_host:
		return
	if not ("--dev-autostart" in OS.get_cmdline_user_args()):
		return
	var max_wait_ticks := 20
	for _i in max_wait_ticks:
		if LobbyState.player_class_ids.size() >= 2:
			break
		await get_tree().create_timer(0.5).timeout
	_on_start_pressed()
