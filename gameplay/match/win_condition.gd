class_name WinCondition
extends RefCounted
## Pure elimination win-condition logic, extracted from MatchRules so
## it's unit-testable without a live scene tree/multiplayer setup --
## same separation this project already applies to ActionFsm/
## HitDetection/DamagePipeline vs their Node-based orchestrators
## (CombatResolver). A team loses once none of its characters have
## current_health > 0; every team reaching 0 simultaneously (a mutual
## kill in the same tick) is a draw, not silently ignored.
##
## Team-count-agnostic since Phase 6: 2v2 team mode and free-for-all
## (where PlayerSpawner assigns each player their own unique team id)
## are both just "how many distinct teams still have someone alive" --
## team mode is the N=2 case, not a separate code path.

## No winner decided yet, and no reason to declare one.
const NONE := -2
## Every team simultaneously reached 0 alive members.
const DRAW := -1


## alive_team_ids: the distinct team ids that currently have >=1
## character with current_health > 0 (order and duplicates don't
## matter -- only emptiness/size/the single remaining value do).
## teams_ever_present: how many distinct team ids have been observed
## with >=1 character at any point so far (latched, never decreases).
## Must be >= 2 before any result is returned -- otherwise the brief
## startup window before at least 2 teams' first players have even
## connected yet (alive_team_ids legitimately small or empty, but for
## "nobody's here" reasons, not "eliminated") would look identical to
## a loss or draw. Returns NONE, DRAW, or the surviving team's id.
static func determine(alive_team_ids: Array, teams_ever_present: int) -> int:
	if teams_ever_present < 2:
		return NONE
	if alive_team_ids.is_empty():
		return DRAW
	if alive_team_ids.size() == 1:
		return alive_team_ids[0]
	return NONE
