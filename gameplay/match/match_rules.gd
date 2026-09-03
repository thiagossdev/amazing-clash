class_name MatchRules
extends Node
## Server-only win-condition orchestrator: counts each team's alive
## members every tick, broadcasts the aggregate to MatchState only on
## change (alive counts change rarely compared to the 60Hz tick rate,
## so no throttle is needed beyond "only send on an actual change"),
## and delegates the win/draw/no-result decision to WinCondition.
## Wired as TestArena's LAST child, after CombatResolver, so a hit this
## same tick has already applied before this node reads current_health.
##
## _team0_ever_present/_team1_ever_present latch true the first time a
## team is observed with >=1 character and never reset. This is what
## lets a mid-match disconnect of a team's last member resolve as a
## loss for that team -- PlayerSpawner.queue_free()s a disconnecting
## peer's character, dropping that team's *current* count to 0 exactly
## like an elimination would -- while still correctly not declaring a
## winner during the brief startup window before both teams' first
## players have even connected yet (both counts start at 0, which
## would otherwise look identical to a loss). A real reconnect/grace-
## period system is out of scope here; see memory/plan.md.

@export var characters_path: NodePath = ^"../Characters"

var _team0_ever_present: bool = false
var _team1_ever_present: bool = false
var _last_team0_alive: int = -1
var _last_team1_alive: int = -1


func _physics_process(_delta: float) -> void:
	if not NetworkManager.is_server():
		return
	if MatchState.current_phase != MatchState.Phase.IN_PROGRESS:
		return
	var characters := get_node_or_null(characters_path)
	if not characters:
		return
	var team0_total := 0
	var team1_total := 0
	var team0_alive := 0
	var team1_alive := 0
	for node in characters.get_children():
		if not node is CharacterController:
			continue
		var character := node as CharacterController
		if character.team == 0:
			team0_total += 1
			if character.current_health > 0.0:
				team0_alive += 1
		else:
			team1_total += 1
			if character.current_health > 0.0:
				team1_alive += 1
	_team0_ever_present = _team0_ever_present or team0_total > 0
	_team1_ever_present = _team1_ever_present or team1_total > 0
	if team0_alive != _last_team0_alive or team1_alive != _last_team1_alive:
		_last_team0_alive = team0_alive
		_last_team1_alive = team1_alive
		MatchState.broadcast_team_status(team0_alive, team1_alive)
	var result := WinCondition.determine(
		team0_alive, team1_alive, _team0_ever_present, _team1_ever_present
	)
	if result != WinCondition.NONE:
		MatchState.enter_post_game(result)
