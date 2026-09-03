extends Node
## Global signals for match events with no single natural owner. Never
## used for combat-to-combat or character-to-character communication --
## that must be a direct signal or call. See docs/blueprint/03-networking-and-match-modes.md.

signal match_state_changed(new_phase: int)
signal team_status_changed(team0_alive: int, team1_alive: int)
