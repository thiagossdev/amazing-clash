extends Node
## Dev-only bootstrap for manual 2-instance playtesting, headless-friendly
## so Phase 1's networking can be verified without a GUI. Reads args after
## "--": `-- --server` hosts, `-- --join` connects to 127.0.0.1,
## `-- --latency=50` sets NetworkManager.artificial_latency_ms so latency
## can be dialed in without editing code mid-test. `-- --simulate-move`
## holds move_right and fires one dash press ~1s in, since headless mode
## has no real keyboard to test locomotion replication with otherwise --
## the delay gives this peer's own character time to actually spawn and
## start sampling input first; dash is a one-shot edge trigger
## (is_action_just_pressed), so firing it before the character exists to
## observe the edge would silently waste the press. No flags leaves this
## a no-op. Pattern inherited from amazing-nauts' net/dev_bootstrap.gd.
##
## host()/join() run first and synchronously, before anything that
## awaits: PlayerSpawner._ready() (a sibling node under the same
## TestArena.tscn root) checks NetworkManager.is_server() once, at
## scene-ready time, and never re-checks it later. An awaiting statement
## earlier in this function would let PlayerSpawner's _ready() run before
## host()/join() ever executed, so it would see is_server() as false and
## silently never spawn or wire up peer_connected/peer_disconnected at
## all -- a real bug this project hit once, root-caused via the "authority
## RPC not allowed" engine error it produced.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--latency="):
			NetworkManager.artificial_latency_ms = arg.trim_prefix("--latency=").to_int()

	if "--server" in args:
		var err := NetworkManager.host()
		if err != OK:
			push_error("dev_bootstrap: failed to host (%s)" % err)
		else:
			MatchState.enter_in_progress()
	elif "--join" in args:
		var err := NetworkManager.join()
		if err != OK:
			push_error("dev_bootstrap: failed to join (%s)" % err)

	if "--simulate-move" in args:
		Input.action_press(&"move_right")
		await get_tree().create_timer(1.0).timeout
		Input.action_press(&"dash")
