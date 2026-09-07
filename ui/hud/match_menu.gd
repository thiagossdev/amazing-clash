extends CanvasLayer
## ESC in-match menu (human owner's own 2026-09-04 request: "Implementar
## um menu in game, ao apertar ESC, com opção de abandonar a partida e
## voltar ao main menu"). "Resume" just closes it; "Abandon Match" uses
## the exact same clean-disconnect path ui/lobby/lobby.gd's own Leave
## Room button already uses (LanDiscovery.stop_advertising() +
## NetworkManager.close(), then back to MainMenu.tscn) -- leaving mid-
## match is otherwise indistinguishable from any other disconnect
## (network drop, crash), so the existing grace-period/reconnect system
## (Slices 13a/13b) already handles what every OTHER peer sees, no new
## server-side logic needed here.
##
## Toggled by `ui_cancel` (project.godot redefines it with
## physical_keycode, per memory/gotchas.md's 2026-09-02 entry -- the
## engine default wouldn't match a synthetic physical_keycode test
## event the way this project's own actions do). ui/hud/
## network_stats_overlay.gd's debug console is the other `ui_cancel`
## consumer in this scene; InputManager.suppress_gameplay_input
## doubles as their interlock for the common direction: this menu
## refuses to OPEN while it's already true (console open), and the
## console's own _input() only ever reads ui_cancel while ITS OWN
## console is visible, so neither steals the other's ESC press when
## only one of them is open. Known narrow gap, not handled: opening
## the console (`/`) WHILE this menu is already open is not guarded on
## either side (`_open_console()` has no suppress_gameplay_input check)
## -- both would end up open at once, and a single ESC then closes
## only whichever one's `_input()` the engine dispatches first that
## frame. Low-severity (the console is a dev-only tool bound to `/`,
## not a path a normal player takes while paused) and left unfixed
## rather than expanding this change to also gate a file outside its
## own scope.

@onready var _resume_button: Button = $ResumeButton
@onready var _abandon_button: Button = $AbandonMatchButton


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(_close_menu)
	_abandon_button.pressed.connect(_on_abandon_pressed)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if visible:
		get_viewport().set_input_as_handled()
		_close_menu()
	elif not InputManager.suppress_gameplay_input:
		get_viewport().set_input_as_handled()
		_open_menu()


func _open_menu() -> void:
	visible = true
	InputManager.suppress_gameplay_input = true


func _close_menu() -> void:
	visible = false
	InputManager.suppress_gameplay_input = false


func _on_abandon_pressed() -> void:
	LanDiscovery.stop_advertising()
	NetworkManager.close()
	get_tree().change_scene_to_file("res://ui/main_menu/MainMenu.tscn")
