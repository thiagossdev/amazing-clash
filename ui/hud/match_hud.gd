extends CanvasLayer
## Minimal match-status display: live status during IN_PROGRESS, a
## terminal "TEAM X WINS"/"PLAYER X WINS"/"DRAW" banner once the match
## reaches POST_GAME. Reads only MatchState's already-client-visible
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

@onready var _status_label: Label = $StatusLabel
@onready var _banner_label: Label = $BannerLabel


func _ready() -> void:
	_banner_label.visible = false
	EventBus.match_state_changed.connect(_on_match_state_changed)
	EventBus.team_status_changed.connect(_on_team_status_changed)
	_refresh_status_label()


func _on_match_state_changed(_new_phase: int) -> void:
	if MatchState.current_phase == MatchState.Phase.POST_GAME:
		_show_banner()


func _on_team_status_changed(_alive_counts: Array[int]) -> void:
	_refresh_status_label()


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


func _show_banner() -> void:
	var winning := MatchState.winning_team
	if winning == WinCondition.DRAW:
		_banner_label.text = "DRAW"
	elif MatchState.match_mode == MatchState.MatchMode.FREE_FOR_ALL:
		_banner_label.text = "PLAYER %d WINS" % winning
	else:
		_banner_label.text = "TEAM %d WINS" % winning
	_banner_label.visible = true
