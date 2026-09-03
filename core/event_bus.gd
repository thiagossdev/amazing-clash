extends Node
## Global signals for match events with no single natural owner. Never
## used for combat-to-combat or character-to-character communication --
## that must be a direct signal or call. See docs/blueprint/03-networking-and-match-modes.md.

signal match_state_changed(new_phase: int)
signal team_status_changed(alive_counts: Array[int])
## Phase 13a: how many currently-connected match slots are mid-grace-
## period after a disconnect (net/player_spawner.gd). Aggregate only,
## same "no per-player identity" convention team_status_changed above
## already uses.
signal grace_period_count_changed(count: int)
