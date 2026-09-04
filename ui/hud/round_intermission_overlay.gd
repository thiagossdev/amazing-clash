extends CanvasLayer
## Phase 17: shown between rounds of a best-of-3 match, while every
## peer is still inside the just-ended round's own TestArena scene --
## no reload happens until the countdown below actually fires. Lets
## each peer freely re-pick weapon/boot/perk (never team/class, which
## stay fixed for the whole match -- the human owner's own confirmed
## scope) via the same self-service LobbyState setters Room Config
## itself uses, then press Confirm. MatchState owns the actual
## confirm-set/countdown timing (see core/match_state.gd's own
## INTERMISSION_* constants) -- this overlay only displays it and
## forwards button presses, same "server decides, this just draws it"
## split every other UI screen in this project already follows.
##
## Also the trigger for the NEXT round's own scene reload:
## MatchState.enter_loading() fires the same Phase.LOADING transition
## Room Config's own original "Start" caused, but this time it happens
## while TestArena.tscn -- not Lobby.tscn -- is the active scene, so
## THIS script (ui/lobby/lobby.gd isn't even loaded right now) has to
## be the one reloading it, mirroring lobby.gd's own
## _on_match_state_changed() exactly.

@onready var _result_label: Label = $ResultLabel
@onready var _countdown_label: Label = $CountdownLabel
@onready var _loadout_container: VBoxContainer = $LoadoutContainer


func _ready() -> void:
	visible = false
	EventBus.match_state_changed.connect(_on_match_state_changed)
	EventBus.round_ended.connect(_on_round_ended)
	EventBus.intermission_countdown_changed.connect(_on_intermission_countdown_changed)


func _on_match_state_changed(new_phase: int) -> void:
	if new_phase == MatchState.Phase.ROUND_INTERMISSION:
		_open()
	elif new_phase == MatchState.Phase.LOADING:
		if visible:
			get_tree().change_scene_to_file("res://maps/test_arena/TestArena.tscn")
	else:
		visible = false


func _open() -> void:
	visible = true
	_countdown_label.text = ""
	for child in _loadout_container.get_children():
		child.queue_free()
	_loadout_container.add_child(_build_weapon_option())
	_loadout_container.add_child(_build_boot_option())
	_loadout_container.add_child(_build_perk_option())
	_loadout_container.add_child(_build_confirm_button())


## winner is WinCondition.DRAW for a drawn round -- see EventBus.
## round_ended's own doc comment. completed_round is the round that
## JUST ended, never the upcoming one.
func _on_round_ended(winner: int, wins: Dictionary, completed_round: int) -> void:
	var score := _format_score(wins)
	if winner == WinCondition.DRAW:
		_result_label.text = "Round %d drawn! Playing again. %s" % [completed_round, score]
	elif MatchState.match_mode == MatchState.MatchMode.FREE_FOR_ALL:
		_result_label.text = "Player %d wins round %d! %s" % [winner, completed_round, score]
	else:
		_result_label.text = (
			"%s wins round %d! %s" % [LobbyState.team_label(winner), completed_round, score]
		)


func _on_intermission_countdown_changed(seconds_remaining: float) -> void:
	if seconds_remaining <= 0.0:
		_countdown_label.text = ""
	else:
		_countdown_label.text = "Round starting in %ds" % int(ceil(seconds_remaining))


## "(Red: 1, Blue: 0)" in team mode, "(0: 1, 1: 0)" in free-for-all
## (no per-player display-name system exists yet, same limitation
## ui/hud/match_hud.gd's own GraceLabel already documents).
func _format_score(wins: Dictionary) -> String:
	var team_mode := MatchState.match_mode == MatchState.MatchMode.TEAM
	var parts: Array[String] = []
	for key in wins:
		var label: String = LobbyState.team_label(key) if team_mode else str(key)
		parts.append("%s: %d" % [label, wins[key]])
	return "(%s)" % ", ".join(parts)


func _build_weapon_option() -> OptionButton:
	var option := OptionButton.new()
	for weapon in LobbyState.WEAPON_RESOURCES:
		option.add_item(weapon.weapon_name)
	option.selected = LobbyState.WEAPON_IDS.find(
		LobbyState.get_weapon_id(multiplayer.get_unique_id(), LobbyState.WEAPON_IDS[0])
	)
	option.item_selected.connect(
		func(index: int): LobbyState.set_local_weapon(LobbyState.WEAPON_IDS[index])
	)
	return option


func _build_boot_option() -> OptionButton:
	var option := OptionButton.new()
	for boot in LobbyState.BOOT_RESOURCES:
		option.add_item(boot.boot_name)
	option.selected = LobbyState.BOOT_IDS.find(
		LobbyState.get_boot_id(multiplayer.get_unique_id(), LobbyState.BOOT_IDS[0])
	)
	option.item_selected.connect(
		func(index: int): LobbyState.set_local_boot(LobbyState.BOOT_IDS[index])
	)
	return option


func _build_perk_option() -> OptionButton:
	var option := OptionButton.new()
	for perk_id in LobbyState.PERK_IDS:
		option.add_item(perk_id.capitalize())
	option.selected = LobbyState.PERK_IDS.find(
		LobbyState.get_perk_id(multiplayer.get_unique_id(), LobbyState.PERK_IDS[0])
	)
	option.item_selected.connect(
		func(index: int): LobbyState.set_local_perk(LobbyState.PERK_IDS[index])
	)
	return option


func _build_confirm_button() -> Button:
	var button := Button.new()
	button.text = "Confirm"
	button.toggle_mode = true
	button.button_pressed = MatchState.player_loadout_confirmed.get(
		multiplayer.get_unique_id(), false
	)
	button.toggled.connect(MatchState.set_local_loadout_confirmed)
	return button
