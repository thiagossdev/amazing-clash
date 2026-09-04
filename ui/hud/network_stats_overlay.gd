extends CanvasLayer
## This client's ping to the server (ENet's own per-peer round-trip-time
## stat), how often this client's own predicted character receives an
## authoritative snapshot, and a minimal typed command console (`/help`,
## `/latency <ms>`, `/hitbox`). Richer console commands (slowmo,
## godmode, spawn, replay) arrive with later phases, once there's a
## system for them to act on.
## Pattern inherited from amazing-nauts' ui/hud/network_stats_overlay.gd.

@export var characters_path: NodePath = ^"../Characters"
@export var update_interval: float = 0.5

var _snapshot_count_this_window: int = 0
var _time_since_update: float = 0.0
var _tracked_character: CharacterController
var _returning_to_menu: bool = false

@onready var _label: Label = $Label
@onready var _console_input: LineEdit = $ConsoleInput
@onready var _console_output: Label = $ConsoleOutput


func _ready() -> void:
	_console_input.visible = false
	_console_output.visible = false
	_console_input.text_submitted.connect(_on_console_submitted)


## Safety net: if this overlay is torn down while the console happened
## to be open, gameplay input must not stay suppressed forever for
## whatever scene comes next.
func _exit_tree() -> void:
	InputManager.suppress_gameplay_input = false


## Bug found live via /waza:hunt (2026-09-03, see memory/gotchas.md):
## a real disconnect (WiFi drop, host closing) left the peer null
## forever, and this method called multiplayer.get_unique_id()
## unconditionally every tick with no guard -- a real engine error
## ("No multiplayer peer is assigned"), spammed every frame, with no
## way back to the menu. Slice 13b's net/reconnect_manager.gd now owns
## the actual recovery (auto-retry using the held token, within the
## same grace window net/player_spawner.gd's disconnected peer sits
## in); this overlay just surfaces its status text while that's
## happening, and returns to MainMenu once it gives up.
func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		_label.text = ReconnectManager.status_text()
		if ReconnectManager.has_given_up():
			_return_to_main_menu_once()
		return
	_ensure_tracking_own_character()
	_time_since_update += delta
	if _time_since_update < update_interval:
		return
	var rate := _snapshot_count_this_window / _time_since_update
	_label.text = "Ping: %dms | Snapshots/s: %.1f" % [_ping_ms(), rate]
	_snapshot_count_this_window = 0
	_time_since_update = 0.0


func _return_to_main_menu_once() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	get_tree().change_scene_to_file("res://ui/main_menu/MainMenu.tscn")


## Bound to "/" (matching the console's own command syntax), not
## backtick: backtick is a dead/accent-composing key on several real
## keyboard layouts (e.g. Brazilian ABNT2), a real bug found live in
## amazing-nauts' own console. Only OPENS the console -- while it's
## already open, "/" must type normally (the user needs to type it as
## part of "/help" etc.), so this never toggles closed; only
## _on_console_submitted() (Enter) closes it. Handled in _input(), which
## fires before Godot's own GUI dispatch: once the LineEdit gains focus
## this same frame, an OS key-repeat ("echo") event for the SAME
## physical key arrives on a later frame and would otherwise leak
## straight into the now-focused field. Consuming the event here
## (allow_echo=true, then set_input_as_handled()) stops that -- the real
## press still opens the console; any repeat of the same key is
## swallowed silently instead of leaking a character in.
func _input(event: InputEvent) -> void:
	if _console_input.visible:
		if event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_console()
		return
	if not event.is_action_pressed(&"debug_toggle_console", true):
		return
	get_viewport().set_input_as_handled()
	if event.is_echo():
		return
	_open_console()


func _open_console() -> void:
	_console_input.visible = true
	_console_output.visible = true
	InputManager.suppress_gameplay_input = true
	_console_input.grab_focus()
	_console_input.clear()


func _close_console() -> void:
	_console_input.visible = false
	_console_output.visible = false
	InputManager.suppress_gameplay_input = false


func _on_console_submitted(text: String) -> void:
	_execute_command(text)
	_console_input.clear()
	_close_console()


## Parses one console line into {"command": String, "args": Array} --
## blank/whitespace-only input yields command "". A single leading "/"
## is stripped if present (so commands read as "/help") but not
## required -- "help" alone still parses the same way. Pure, no
## execution (see _execute_command), so it's testable without a live
## LineEdit.
static func parse_command(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed.begins_with("/"):
		trimmed = trimmed.substr(1)
	if trimmed.is_empty():
		return {"command": "", "args": []}
	var parts := trimmed.split(" ", false)
	return {"command": parts[0], "args": Array(parts.slice(1))}


func _execute_command(text: String) -> void:
	var parsed := parse_command(text)
	match parsed["command"]:
		"":
			pass
		"help":
			_console_output.text = "Commands: /help | /latency <ms> | /hitbox"
		"latency":
			if parsed["args"].size() >= 1 and (parsed["args"][0] as String).is_valid_int():
				NetworkManager.artificial_latency_ms = int(parsed["args"][0])
				_console_output.text = "latency set to %s ms" % parsed["args"][0]
			else:
				_console_output.text = "usage: /latency <ms>"
		"hitbox":
			var viewer := get_tree().get_first_node_in_group(&"hitbox_viewer")
			if viewer:
				viewer.visible = not viewer.visible
				_console_output.text = "hitbox viewer toggled"
			else:
				_console_output.text = "no hitbox viewer in this scene"
		_:
			_console_output.text = "unknown command: /%s" % parsed["command"]


## Slice 13b: matches via CharacterController.is_owned_by_me()
## (controlling_peer_id), not a node-name lookup keyed by this peer's
## own multiplayer.get_unique_id() -- after a reconnect, "my" character
## node is still named str(the ORIGINAL peer_id), which no longer
## equals my own (new) unique_id, so a name-based lookup would silently
## never find it again post-reconnect.
func _ensure_tracking_own_character() -> void:
	if is_instance_valid(_tracked_character):
		return
	var characters := get_node_or_null(characters_path)
	if not characters:
		return
	for child in characters.get_children():
		if child is CharacterController and (child as CharacterController).is_owned_by_me():
			_tracked_character = child
			_tracked_character.snapshot_received.connect(func(): _snapshot_count_this_window += 1)
			return


func _ping_ms() -> int:
	if NetworkManager.is_server():
		return 0
	return NetworkManager.get_peer_rtt_ms(1)
