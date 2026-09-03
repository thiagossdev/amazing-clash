extends Control
## First screen (project.godot's run/main_scene). See memory/plan.md's
## "Slices 7-10" for the full flow this kicks off: Main Menu ->
## Character Select -> Host/Join -> Room Config -> in-game.


func _ready() -> void:
	$PlayButton.pressed.connect(_on_play_pressed)
	if "--dev-autoplay" in OS.get_cmdline_user_args():
		# One-frame defer: this is the engine's own initial main-scene
		# _ready(), still mid-setup -- change_scene_to_file() here
		# synchronously hits a real (if non-fatal) "Parent node is busy
		# adding/removing children" engine error, confirmed live. A real
		# player's button click can't hit this (it always fires on a
		# later, already-idle frame); only this dev-only immediate
		# auto-advance can.
		await get_tree().process_frame
		_on_play_pressed()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/character_select/CharacterSelect.tscn")
