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

## Phase 17 (best-of-3 rounds): a round just ended without deciding the
## match. winner is WinCondition.DRAW for a drawn round (round_wins
## unchanged), otherwise the round's winning team_id/player index.
## completed_round is the round number that just ended.
signal round_ended(winner: int, wins: Dictionary, completed_round: int)
## Phase 17: seconds remaining in the current ROUND_INTERMISSION's
## final "round starting in..." countdown, or -1.0 when nothing is
## counting down (including during the silent 15s pick/confirm window
## itself) -- see core/match_state.gd's own INTERMISSION_* constants.
signal intermission_countdown_changed(seconds_remaining: float)
## Phase 17: peer_id -> confirmed-their-round-loadout flag, scoped to
## the current ROUND_INTERMISSION window.
signal loadout_confirmed_changed(confirmed: Dictionary)
