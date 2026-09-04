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
## Phase 17: a decided result is handed to MatchState.
## resolve_round_result() instead of enter_post_game() directly -- a
## single WinCondition.determine() result might mean "this round is
## over" (best-of-3 not yet decided) rather than "the match is over,"
## and MatchState is what knows which. This file's own job (count alive
## members, decide win/draw/none) is unaware of round/match distinction
## by design -- that branching lives entirely on the MatchState side.
##
## Team-count-agnostic since Phase 6 (a Dictionary keyed by team id,
## not 2 hardcoded locals): 2v2 team mode and free-for-all (where
## PlayerSpawner assigns each player their own unique team id) are the
## same code path here, differing only in how many distinct team ids
## show up in the roster.
##
## _ever_present_teams latches every team id ever observed with >=1
## character and never forgets one. This is what lets a mid-match
## disconnect of a team's last member eventually resolve as a loss for
## that team -- while still correctly not declaring a winner during the
## brief startup window before at least 2 teams' first players have
## even connected yet (WinCondition needs >=2 teams ever present, which
## would otherwise look identical to a loss/draw).
##
## Phase 13a, corrected: a disconnect no longer drops a team's alive
## count to 0 immediately. net/player_spawner.gd now starts a 30s
## grace-period timer instead of despawning right away -- the
## disconnected character stays in the tree, current_health > 0, still
## fully vulnerable (this node's own alive-counting treats it exactly
## like any other living character, on purpose: no exclusion was added
## here). A 1v1 disconnect now only resolves once the grace period
## expires unclaimed (net/player_spawner.gd's own despawn) or the
## opponent kills the now-defenseless character directly -- not
## instantly, as this comment used to (incorrectly, after 13a) claim.
## Token-based reconnect (Slice 13b) is a separate, not-yet-built
## phase; see memory/plan.md.
##
## Known edge case, not solved here: a NEW peer can join mid-match
## (PlayerSpawner._spawn_for_peer() has no phase gating) while another
## peer's character is still mid-grace-period -- briefly, more
## "currently alive" characters can exist than actually-connected
## peers. This doesn't corrupt the win condition (every character here
## is counted the same, honestly, whether fresh or grace-period-frozen)
## or crash anything; it's just an unusual transient team-size state
## this phase didn't design for. Flagged in memory/progress.md's
## Backlog, not fixed here -- out of Phase 13a's own scope.

@export var characters_path: NodePath = ^"../Characters"

var _ever_present_teams: Dictionary = {}
var _last_alive_by_team: Dictionary = {}


func _physics_process(_delta: float) -> void:
	if not NetworkManager.is_server():
		return
	if MatchState.current_phase != MatchState.Phase.IN_PROGRESS:
		return
	var characters := get_node_or_null(characters_path)
	if not characters:
		return
	var alive_by_team: Dictionary = {}
	for node in characters.get_children():
		if not node is CharacterController:
			continue
		var character := node as CharacterController
		_ever_present_teams[character.team] = true
		if character.current_health > 0.0:
			alive_by_team[character.team] = alive_by_team.get(character.team, 0) + 1
	if alive_by_team != _last_alive_by_team:
		_last_alive_by_team = alive_by_team.duplicate()
		MatchState.broadcast_team_status(_counts_array(alive_by_team))
	var result := WinCondition.determine(alive_by_team.keys(), _ever_present_teams.size())
	if result != WinCondition.NONE:
		MatchState.resolve_round_result(result)


## Converts the sparse alive_by_team Dictionary into a dense array
## indexed by team id (0 for any team id in _ever_present_teams that
## currently has no alive members), the shape MatchState/MatchHud read.
func _counts_array(alive_by_team: Dictionary) -> Array[int]:
	var max_team_id := 0
	for team_id in _ever_present_teams:
		max_team_id = maxi(max_team_id, team_id)
	var counts: Array[int] = []
	counts.resize(max_team_id + 1)
	counts.fill(0)
	for team_id in alive_by_team:
		counts[team_id] = alive_by_team[team_id]
	return counts
