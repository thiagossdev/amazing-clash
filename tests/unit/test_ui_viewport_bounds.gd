extends GutTest
## Every top-level UI scene's Control nodes fit inside the real
## viewport, generalizing the same regression guard `tests/unit/
## test_replay_player_scene.gd`'s own `test_every_control_fits_inside_
## the_real_viewport` established for ui/replay/ReplayPlayer.tscn (see
## that test's own doc comment for the full "off-screen row" bug this
## whole class of test exists to catch). 2026-09-04: every scene below
## was hand-converted from fixed absolute `offset_*` positioning to
## anchor-based positioning (mostly screen-centered, matching this
## project's own UI style) at the same time this project adopted an
## explicit design resolution (1920x1080, decoupled from the actual
## startup window via `window_width/height_override` = 1280x720,
## matching the pattern `amazing-dungeons` already validated) -- this
## test is the general-purpose guard that conversion was done correctly
## everywhere, not just in the one screen a human actually looked at.
##
## `maps/test_arena/TestArena.tscn` is included via its 3 UI-bearing
## CanvasLayers (NetworkStatsOverlay/MatchHud/RoundIntermissionOverlay)
## rather than the whole scene, since instantiating TestArena directly
## would also spin up networking/combat/spawner nodes this test has no
## business exercising.

const MAIN_MENU_SCENE := preload("res://ui/main_menu/MainMenu.tscn")
const CHARACTER_SELECT_SCENE := preload("res://ui/character_select/CharacterSelect.tscn")
const HOST_JOIN_SCENE := preload("res://ui/host_join/HostJoin.tscn")
const LOBBY_SCENE := preload("res://ui/lobby/Lobby.tscn")
const REPLAY_LIST_SCENE := preload("res://ui/replay/ReplayList.tscn")
const TEST_ARENA_SCENE := preload("res://maps/test_arena/TestArena.tscn")


## Godot's own Control anchor resolution uses get_viewport().
## get_visible_rect(), not the design values in ProjectSettings
## directly -- confirmed live 2026-09-04 that in --headless mode
## specifically, that rect comes back SQUARE (matching viewport_width
## for both axes), a real Godot headless-environment quirk, not a scene
## bug. Comparing against this same rect keeps the test meaningful in
## both environments.
func _assert_every_control_fits(root: Node) -> void:
	var viewport_size: Vector2 = root.get_viewport().get_visible_rect().size
	_assert_subtree_fits(root, viewport_size)


func _assert_subtree_fits(node: Node, viewport_size: Vector2) -> void:
	if node is Control:
		var control: Control = node
		assert_gte(
			control.position.x,
			0.0,
			(
				"%s's left edge (%s) must not sit before the viewport"
				% [control.get_path(), control.position.x]
			)
		)
		assert_gte(
			control.position.y,
			0.0,
			(
				"%s's top edge (%s) must not sit before the viewport"
				% [control.get_path(), control.position.y]
			)
		)
		assert_lte(
			control.position.x + control.size.x,
			viewport_size.x,
			(
				"%s's right edge (%s) must not exceed the viewport width (%s)"
				% [control.get_path(), control.position.x + control.size.x, viewport_size.x]
			)
		)
		assert_lte(
			control.position.y + control.size.y,
			viewport_size.y,
			(
				"%s's bottom edge (%s) must not exceed the viewport height (%s)"
				% [control.get_path(), control.position.y + control.size.y, viewport_size.y]
			)
		)
	for child in node.get_children():
		_assert_subtree_fits(child, viewport_size)


func test_main_menu_controls_fit_the_viewport() -> void:
	_assert_every_control_fits(add_child_autofree(MAIN_MENU_SCENE.instantiate()))


func test_character_select_controls_fit_the_viewport() -> void:
	_assert_every_control_fits(add_child_autofree(CHARACTER_SELECT_SCENE.instantiate()))


func test_host_join_controls_fit_the_viewport() -> void:
	_assert_every_control_fits(add_child_autofree(HOST_JOIN_SCENE.instantiate()))


func test_lobby_controls_fit_the_viewport() -> void:
	_assert_every_control_fits(add_child_autofree(LOBBY_SCENE.instantiate()))


func test_replay_list_controls_fit_the_viewport() -> void:
	_assert_every_control_fits(add_child_autofree(REPLAY_LIST_SCENE.instantiate()))


func test_network_stats_overlay_controls_fit_the_viewport() -> void:
	var arena: Node = add_child_autofree(TEST_ARENA_SCENE.instantiate())
	_assert_every_control_fits(arena.get_node("NetworkStatsOverlay"))


func test_match_hud_controls_fit_the_viewport() -> void:
	var arena: Node = add_child_autofree(TEST_ARENA_SCENE.instantiate())
	_assert_every_control_fits(arena.get_node("MatchHud"))


func test_round_intermission_overlay_controls_fit_the_viewport() -> void:
	var arena: Node = add_child_autofree(TEST_ARENA_SCENE.instantiate())
	_assert_every_control_fits(arena.get_node("RoundIntermissionOverlay"))
