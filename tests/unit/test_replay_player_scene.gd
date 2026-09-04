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


## Found live via /hunt's own scope-blast sweep 2026-09-04, while
## investigating the human owner's separate "problema de interpolação"
## report: CharacterController._physics_process() is ALSO a normal
## engine-driven once-per-real-frame callback, same shape as the
## CombatResolver bug above. Left enabled during replay, it fires in
## ADDITION to ReplayDriver._apply_tick()'s own explicit per-tick
## replay_step_authoritative() call -- and since that call already
## pushes then immediately pops its one Sample from ServerSim's buffer,
## the engine's own extra automatic call finds an empty buffer and
## falls into ServerSim.next_input()'s stale-input fallback, silently
## repeating the last move direction for one uncommanded phantom tick
## EVERY real frame, at any playback speed (not just high speed --
## confirmed by reading net/server_sim.gd's own next_input()
## directly, not guessed). Fixed in ReplayDriver._spawn_characters():
## disables each spawned character's automatic physics processing, the
## same way CombatResolver's is disabled in _ready().
func test_replayed_characters_do_not_auto_tick_via_the_engine() -> void:
	var path := _write_replay(
		"no_double_step.replay",
		[
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
	)
	var player: Node2D = add_child_autofree(REPLAY_PLAYER_SCENE.instantiate())
	var driver: ReplayDriver = player.get_node("ReplayDriver")
	assert_true(driver.load_replay(path))
	var characters := player.get_node("Characters")
	assert_eq(characters.get_child_count(), 1)
	var character := characters.get_child(0)
	assert_false(
		character.is_physics_processing(),
		"a replayed character must be driven only by ReplayDriver's own per-tick calls"
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
## playback tick-by-tick (ReplayDriver._physics_process(), which itself
## drives CombatResolver once per simulated tick internally -- see
## ReplayDriver._ready()'s own doc comment) with a held skillshot input,
## past iron_sword's own debug_skillshot.tres startup_frames (8), and
## confirms a real Projectile gets spawned into the Projectiles
## container -- proof replayed combat resolution isn't just wired in,
## it fires.
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
	var projectiles := player.get_node("Projectiles")

	assert_true(driver.load_replay(path))
	driver.play()
	for _i in range(12):
		driver._physics_process(1.0 / 60.0)

	assert_gt(
		projectiles.get_child_count(),
		0,
		"a held skillshot past its move's startup_frames must spawn a real Projectile"
	)


func _sample_dict(sequence: int, skillshot_pressed: bool) -> Dictionary:
	var sample := _skillshot_sample_dict(sequence)
	sample["skillshot_pressed"] = skillshot_pressed
	return sample


## Found live via /hunt 2026-09-04 (human owner: "ao aumentar a
## velocidade, tem problema de interpolação... no 8X os projeteis não
## são disparados"). Root cause: ReplayDriver._physics_process() applies
## `playback_speed` recorded ticks per REAL physics frame (a for loop
## calling _apply_next_tick_record() N times), but CombatResolver --
## the ONLY place _maybe_launch_projectile()'s exact `slot_fsm.move_
## frame == move.startup_frames` check lives -- used to rely on the
## ENGINE's own automatic _physics_process() callback, which only fires
## once per real frame, never once per simulated tick. At
## playback_speed 1 this coincided (1 tick == 1 real frame); at higher
## speeds, N ticks' worth of ability-FSM advancement happened before
## CombatResolver ever inspected the state, silently skipping the
## single-tick-wide activation window whenever it didn't land on the
## very last tick of a batch -- exactly the human owner's own "só ta
## reproduzindo os frames que executam" description. Fixed in
## ReplayDriver._ready()/_apply_tick(): CombatResolver's automatic
## engine callback is disabled and it's driven explicitly, once per
## SIMULATED tick, from inside _apply_tick() instead -- this test now
## exercises exactly that path through the normal driver API, no manual
## CombatResolver call needed. The skillshot starts 3 idle ticks in
## (not tick 0) specifically so the activation frame (idle 3 +
## debug_skillshot.tres's own startup_frames 8 == absolute tick 11)
## would have landed mid-batch at speed 8 under the OLD bug (batches:
## 0-7, 8-15, ...), not coincidentally on a batch boundary.
func test_high_speed_playback_still_spawns_a_projectile() -> void:
	var samples: Array = []
	for i in range(24):
		samples.append({"peer_id": 1, "sample": _sample_dict(i, i >= 3)})
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
	for i in range(24):
		lines.append({"type": "tick", "tick": i, "samples": [samples[i]]})
	var path := _write_replay("skillshot_fast.replay", lines)

	var player: Node2D = add_child_autofree(REPLAY_PLAYER_SCENE.instantiate())
	var driver: ReplayDriver = player.get_node("ReplayDriver")
	var projectiles := player.get_node("Projectiles")

	assert_true(driver.load_replay(path))
	driver.playback_speed = 8
	driver.play()
	# 3 real frames * 8 ticks/frame = 24 ticks.
	for _i in range(3):
		driver._physics_process(1.0 / 60.0)

	assert_gt(
		projectiles.get_child_count(),
		0,
		"a skillshot cast mid-batch at 8x speed must still spawn a Projectile, not be skipped"
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
