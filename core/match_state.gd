extends Node
## Orchestrator autoload -- source of truth for the match phase.
## See docs/blueprint/03-networking-and-match-modes.md.
##
## Phase 1 has no Lobby/CharacterSelect UI yet (that's Phase 5): TestArena
## is the main scene and enters IN_PROGRESS directly once networking is up.
## RECONNECT is a sub-state of IN_PROGRESS conceptually, not its own Phase
## value here -- Phase 1 has no per-peer state worth tracking through a
## reconnect (no health/team yet), so a (re)connecting peer just gets a
## fresh character from PlayerSpawner; nothing in this file needs to know
## the difference yet.

enum Phase { LOBBY, CHARACTER_SELECT, LOADING, IN_PROGRESS, POST_GAME }

var current_phase: Phase = Phase.LOBBY


func enter_in_progress() -> void:
	current_phase = Phase.IN_PROGRESS
	EventBus.match_state_changed.emit(current_phase)


func is_in_progress() -> bool:
	return current_phase == Phase.IN_PROGRESS
