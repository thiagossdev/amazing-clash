extends GutTest
## ReplayPlayer.tscn: confirms the scene wires in the same combat-
## resolution nodes `maps/test_arena/TestArena.tscn` uses (`CombatResolver`,
## `Projectiles`) and the F1 debug overlay (`HitboxViewer`) -- found live
## 2026-09-04 (see `memory/gotchas.md`): `CharacterController.
## replay_step_authoritative()` only advances a character's own
## movement/ability-FSM state; ALL projectile spawning/advancement and
## melee/ability hit resolution live in `CombatResolver`, a sibling of
## `Characters`/`Projectiles` in every real match's scene tree -- absent
## from `ReplayPlayer.tscn`, replayed combat silently never happened (no
## projectiles ever spawned, no damage ever applied), even though
## playback itself "worked" (ticks/rounds/winner all reconstruct
## correctly from the recorded structural data alone, which is what the
## Phase 20 fork's own live verification actually checked).

const REPLAY_PLAYER_SCENE := preload("res://ui/replay/ReplayPlayer.tscn")
const TEST_REPLAY_DIR := "user://test_replay_player_scene"


func after_each() -> void:
	var dir := DirAccess.open(TEST_REPLAY_DIR)
	if dir:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(TEST_REPLAY_DIR)


func _write_replay(filename: String, lines: Array) -> String:
	DirAccess.make_dir_recursive_absolute(TEST_REPLAY_DIR)
	var path := "%s/%s" % [TEST_REPLAY_DIR, filename]
	var file := FileAccess.open(path, FileAccess.WRITE)
	for line in lines:
		file.store_line(JSON.stringify(line))
	file.close()
	return path


func test_scene_has_a_combat_resolver_sibling_of_characters() -> void:
	var player: Node2D = add_child_autofree(REPLAY_PLAYER_SCENE.instantiate())
	var resolver := player.get_node_or_null("CombatResolver")
	assert_not_null(
		resolver, "replayed combat needs the same CombatResolver TestArena.tscn wires in"
	)
	if resolver:
		assert_true(resolver.get_script().resource_path.ends_with("combat_resolver.gd"))


func test_scene_has_a_projectiles_container() -> void:
	var player: Node2D = add_child_autofree(REPLAY_PLAYER_SCENE.instantiate())
	assert_not_null(
		player.get_node_or_null("Projectiles"),
		"CombatResolver's default projectiles_path (../Projectiles) needs this sibling to exist"
	)


func test_scene_has_the_f1_hitbox_viewer() -> void:
	var player: Node2D = add_child_autofree(REPLAY_PLAYER_SCENE.instantiate())
	assert_not_null(
		player.get_node_or_null("HitboxViewer"),
		"F1 debug overlay, requested for replay playback too"
	)


func _skillshot_sample_dict(sequence: int) -> Dictionary:
	return {
		"sequence": sequence,
		"move_vector": [0.0, 0.0],
		"dash_pressed": false,
		"attack_pressed": false,
		"aim_direction": [1.0, 0.0],
		"skillshot_pressed": true,
		"ability_q_pressed": false,
		"ability_e_pressed": false,
		"ability_r_pressed": false,
		"ability_f_pressed": false,
		"boot_active_pressed": false,
		"delta": 1.0 / 60.0,
	}


## Direct regression check for the bug above: not just "the node exists"
## (the 3 tests above) but "combat actually happens" -- drives real
## playback tick-by-tick (ReplayDriver._physics_process(), then
## CombatResolver._physics_process(), exactly the order and pairing the
## real engine's own per-frame loop produces once both are siblings in
## the tree) with a held skillshot input, past iron_sword's own
## debug_skillshot.tres startup_frames (8), and confirms a real
## Projectile gets spawned into the Projectiles container -- proof
## replayed combat resolution isn't just wired in, it fires.
func test_a_held_skillshot_actually_spawns_a_projectile_during_playback() -> void:
	var samples: Array = []
	for i in range(12):
		samples.append({"peer_id": 1, "sample": _skillshot_sample_dict(i)})
	var lines: Array = [
		{
			"type": "header",
			"mode": 0,
			"friendly_fire": false,
			"round_target": 2,
			"sim_seed": 1,
			"loadouts":
			[
				{
					"peer_id": 1,
					"class": "vanguard",
					"team": 0,
					"weapon": "iron_sword",
					"boot": "swift_boots",
					"perk": "vitality",
				}
			],
		}
	]
	for i in range(12):
		lines.append({"type": "tick", "tick": i, "samples": [samples[i]]})
	var path := _write_replay("skillshot.replay", lines)

	var player: Node2D = add_child_autofree(REPLAY_PLAYER_SCENE.instantiate())
	var driver: ReplayDriver = player.get_node("ReplayDriver")
	var combat_resolver: Node = player.get_node("CombatResolver")
	var projectiles := player.get_node("Projectiles")

	assert_true(driver.load_replay(path))
	driver.play()
	for _i in range(12):
		driver._physics_process(1.0 / 60.0)
		combat_resolver._physics_process(1.0 / 60.0)

	assert_gt(
		projectiles.get_child_count(),
		0,
		"a held skillshot past its move's startup_frames must spawn a real Projectile"
	)


## Found live 2026-09-04 (human owner: "enter/space deu certo. Mas não
## vi esse botão"): the entire bottom Controls row (PlayPauseButton/
## SkipBackButton/SkipForwardButton/Scrubber/BackButton) was positioned
## at y:740-780, past this project's own default viewport height (648,
## `display/window/size/viewport_height`) -- genuinely off-screen since
## Phase 20's original build, undetected because this environment has
## no way to screenshot Godot's real renderer (every prior UI phase's
## own flagged gap). Keyboard activation (grab_focus() + Enter/Space)
## still worked regardless -- Godot's focus/action system doesn't
## require on-screen visibility -- which is exactly why this shipped
## unnoticed until real hands-on play-testing caught it. This test
## checks every Control under Controls fits within the real viewport
## rect, so any FUTURE control added off-screen by mistake fails loudly
## here instead of silently shipping invisible again.
func test_every_control_fits_inside_the_real_viewport() -> void:
	var player: Node2D = add_child_autofree(REPLAY_PLAYER_SCENE.instantiate())
	var viewport_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	var controls := player.get_node("Controls")
	for control in controls.get_children():
		if control is not Control:
			continue
		var rect: Control = control
		assert_lte(
			rect.offset_right,
			viewport_size.x,
			(
				"%s's right edge (%s) must not exceed the viewport width (%s)"
				% [control.name, rect.offset_right, viewport_size.x]
			)
		)
		assert_lte(
			rect.offset_bottom,
			viewport_size.y,
			(
				"%s's bottom edge (%s) must not exceed the viewport height (%s)"
				% [control.name, rect.offset_bottom, viewport_size.y]
			)
		)
