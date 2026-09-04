extends CanvasLayer
## Minimal match-status display: live status during IN_PROGRESS, a
## terminal "TEAM X WINS THE MATCH 2-1"/"DRAW" banner once the match
## reaches POST_GAME (Phase 17: round score included). Reads only
## MatchState's already-client-visible
## aggregate fields (team_alive_counts, winning_team, match_mode) --
## never a per-character team lookup, since individual characters' team
## assignments are never replicated to clients (see
## CharacterController.team's own doc comment). No lobby/character-
## select screen exists yet, so there is nothing to show before
## IN_PROGRESS; StatusLabel is simply blank until the first team-status
## update arrives.
##
## Phase 6: mode-aware, since free-for-all's team_alive_counts (one
## entry per player, not per side) isn't meaningful to show broken out
## the same way team mode's is -- a per-team-of-one list would just be
## a list of 0s and 1s.
##
## Phase 13a: GraceLabel shows a minimal "N player(s) disconnected"
## line whenever MatchState.players_in_grace_period is nonzero --
## aggregate count only, no per-player name (this project has no
## display-name system yet, same limitation team/class already have
## client-side). Deliberately does NOT say "reconnecting" -- Slice 13b
## (the only thing that would make that true) doesn't exist yet in
## this build; a disconnected player's character is vulnerable and
## either gets killed or times out as a forfeit, nothing reconnects it.
## /check caught an earlier draft that said "reconnecting..." here,
## which would have promised players a mechanism this build can't
## deliver.

@onready var _status_label: Label = $StatusLabel
@onready var _banner_label: Label = $BannerLabel
@onready var _grace_label: Label = $GraceLabel


func _ready() -> void:
	_banner_label.visible = false
	EventBus.match_state_changed.connect(_on_match_state_changed)
	EventBus.team_status_changed.connect(_on_team_status_changed)
	EventBus.grace_period_count_changed.connect(_on_grace_period_count_changed)
	_refresh_status_label()
	_refresh_grace_label()


func _on_match_state_changed(_new_phase: int) -> void:
	if MatchState.current_phase == MatchState.Phase.POST_GAME:
		_show_banner()


func _on_team_status_changed(_alive_counts: Array[int]) -> void:
	_refresh_status_label()


func _on_grace_period_count_changed(_count: int) -> void:
	_refresh_grace_label()


func _refresh_grace_label() -> void:
	var count := MatchState.players_in_grace_period
	if count <= 0:
		_grace_label.text = ""
	elif count == 1:
		_grace_label.text = "1 player disconnected"
	else:
		_grace_label.text = "%d players disconnected" % count


func _refresh_status_label() -> void:
	if MatchState.match_mode == MatchState.MatchMode.FREE_FOR_ALL:
		_status_label.text = "%d players alive" % _total_alive()
	else:
		_status_label.text = (
			"Team 0: %d alive | Team 1: %d alive" % [_alive_for_team(0), _alive_for_team(1)]
		)


func _total_alive() -> int:
	var total := 0
	for count in MatchState.team_alive_counts:
		total += count
	return total


func _alive_for_team(team_id: int) -> int:
	var counts := MatchState.team_alive_counts
	return counts[team_id] if team_id < counts.size() else 0


## Phase 17: also shows the final round score (e.g. "RED WINS THE
## MATCH 2-1") -- MatchState.round_wins is already caught up by the
## time POST_GAME's own EventBus.match_state_changed fires (see
## MatchState._rpc_enter_post_game()'s own round_wins parameter).
func _show_banner() -> void:
	var winning := MatchState.winning_team
	if winning == WinCondition.DRAW:
		_banner_label.text = "DRAW"
	elif MatchState.match_mode == MatchState.MatchMode.FREE_FOR_ALL:
		_banner_label.text = "PLAYER %d WINS THE MATCH %s" % [winning, _round_score_text()]
	else:
		_banner_label.text = (
			"%s WINS THE MATCH %s"
			% [LobbyState.team_label(winning).to_upper(), _round_score_text()]
		)
	_banner_label.visible = true


## "2-1" -- the winner's own round count first, then every other team/
## player's, in ascending key order (stable, deterministic display; the
## exact tie-break among non-winners doesn't matter for a 2-participant
## match, which is this HUD's only supported shape today).
func _round_score_text() -> String:
	var winning := MatchState.winning_team
	var wins := MatchState.round_wins
	var winner_score: int = wins.get(winning, 0)
	var other_scores: Array[int] = []
	for key in wins:
		if key != winning:
			other_scores.append(wins[key])
	other_scores.sort()
	if other_scores.is_empty():
		return "%d-0" % winner_score
	return "%d-%d" % [winner_score, other_scores[-1]]
