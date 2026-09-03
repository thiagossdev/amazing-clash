extends CanvasLayer
## Minimal match-status display: live team-alive counts during
## IN_PROGRESS, a terminal "TEAM X WINS"/"DRAW" banner once the match
## reaches POST_GAME. Reads only MatchState's already-client-visible
## aggregate fields (team_alive_counts, winning_team) -- never a
## per-character team lookup, since individual characters' team
## assignments are never replicated to clients (see
## CharacterController.team's own doc comment). No lobby/character-
## select screen exists yet, so there is nothing to show before
## IN_PROGRESS; StatusLabel is simply blank until the first team-status
## update arrives.

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


func _on_team_status_changed(_team0_alive: int, _team1_alive: int) -> void:
	_refresh_status_label()


func _refresh_status_label() -> void:
	var counts := MatchState.team_alive_counts
	_status_label.text = "Team 0: %d alive | Team 1: %d alive" % [counts[0], counts[1]]


func _show_banner() -> void:
	var winning := MatchState.winning_team
	_banner_label.text = "DRAW" if winning == WinCondition.DRAW else "TEAM %d WINS" % winning
	_banner_label.visible = true
