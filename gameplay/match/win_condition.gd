class_name WinCondition
extends RefCounted
## Pure elimination win-condition logic, extracted from MatchRules so
## it's unit-testable without a live scene tree/multiplayer setup --
## same separation this project already applies to ActionFsm/
## HitDetection/DamagePipeline vs their Node-based orchestrators
## (CombatResolver). A team loses once none of its characters have
## current_health > 0; both teams reaching 0 simultaneously (a mutual
## kill in the same tick) is a draw, not silently ignored.

## No winner decided yet, and no reason to declare one.
const NONE := -2
## Both teams simultaneously reached 0 alive members.
const DRAW := -1


## Returns NONE, DRAW, or a team index (0 or 1) for the winner.
## team0_ever_present/team1_ever_present must both be true before any
## result is returned -- otherwise the brief startup window before
## both teams' first players have even connected yet (both alive
## counts legitimately 0, but for "nobody's here" reasons, not "this
## team lost") would look identical to a loss.
static func determine(
	team0_alive: int, team1_alive: int, team0_ever_present: bool, team1_ever_present: bool
) -> int:
	if not (team0_ever_present and team1_ever_present):
		return NONE
	if team0_alive == 0 and team1_alive == 0:
		return DRAW
	if team0_alive == 0:
		return 1
	if team1_alive == 0:
		return 0
	return NONE
