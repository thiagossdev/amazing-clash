extends Node
## Placed as TestArena.tscn's last child (same ordering guarantee
## MatchRules already relies on) so this node's own _ready() only fires
## after every sibling -- PlayerSpawner included -- has finished
## building. Reports to MatchState once this peer's own TestArena tree
## genuinely exists, closing the same race net/dev_bootstrap.gd already
## hit once (memory/gotchas.md): an RPC-driven scene change could
## otherwise let a peer receive gameplay RPCs before its own tree is
## ready to handle them. See core/match_state.gd's Phase 7 doc comment.


## Only reports during a genuine LOADING transition (the Room Config ->
## TestArena flow always has this peer's own current_phase already set
## to LOADING by the time this fires, since that's what triggered the
## scene change in the first place). net/dev_bootstrap.gd's direct-
## connect flow never sets LOADING at all (its server calls
## enter_in_progress() immediately, its client's own current_phase is
## still the default LOBBY at this point) -- confirmed live that
## reporting unconditionally there raced the client's own not-yet-
## finished ENet handshake ("Trying to call an RPC via a multiplayer
## peer which is not connected"), harmless in practice (PlayerSpawner
## already handles the direct "already IN_PROGRESS" case on its own,
## see net/player_spawner.gd) but worth not doing at all.
func _ready() -> void:
	if MatchState.current_phase == MatchState.Phase.LOADING:
		MatchState.report_loaded()
