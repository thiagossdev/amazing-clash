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
## observe the edge would silently waste the press. `-- --simulate-attack`
## fires one attack press ~1.2s in, same reasoning; `-- --simulate-
## skillshot` fires one skillshot press ~1.4s in (headless has no real
## mouse either, so InputManager.get_aim_direction() resolves off
## whatever the headless viewport's mouse position defaults to -- fine
## for proving the projectile spawns/travels/expires, not for testing a
## specific aim). `-- --simulate-ability-q` / `-- --simulate-ability-e`
## fire one press each ~1.6s/~1.8s in, same reasoning, to prove Phase
## 3's independent ability slots. `-- --friendly-fire` sets
## MatchState.friendly_fire_enabled -- a per-match server setting
## decided at startup, not a live-togglable console command (who's
## allowed to change a match rule mid-game is a separate authority
## question, not opened here). `-- --simulate-self-eliminate` directly
## zeroes this peer's own character's health ~1s in (bypassing hit
## geometry entirely) so Phase 5's elimination/win-condition/HUD chain
## can be exercised deterministically without depending on 2 characters
## actually connecting a hit. `-- --dev-kick-after=<seconds>` (server
## only, Slice 13b) force-disconnects the first connected client after
## the delay, simulating a real mid-match drop for live reconnect
## testing -- see this function's own trailing block. `-- --free-for-all` sets
## MatchState.match_mode to FREE_FOR_ALL -- must be set before
## PlayerSpawner._ready() reads it to decide team assignment, so this
## is parsed alongside --friendly-fire, before host()/join(), same
## ordering reasoning as the paragraph below. No flags leaves this a
## no-op. Pattern inherited from amazing-nauts' net/dev_bootstrap.gd.
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
	if "--friendly-fire" in args:
		MatchState.friendly_fire_enabled = true
	if "--free-for-all" in args:
		MatchState.match_mode = MatchState.MatchMode.FREE_FOR_ALL

	if "--server" in args:
		var err := NetworkManager.host()
		if err != OK:
			push_error("dev_bootstrap: failed to host (%s)" % err)
		else:
			MatchState.enter_in_progress()
	elif "--join" in args:
		# Slice 13b: mirrors ui/host_join/host_join.gd's own
		# remember_join_target() call -- without it, this headless
		# dev-join path would have no address to auto-reconnect to.
		ReconnectManager.remember_join_target("127.0.0.1", NetworkManager.DEFAULT_PORT)
		var err := NetworkManager.join()
		if err != OK:
			push_error("dev_bootstrap: failed to join (%s)" % err)

	if "--simulate-move" in args:
		Input.action_press(&"move_right")
		await get_tree().create_timer(1.0).timeout
		Input.action_press(&"dash")

	if "--simulate-attack" in args:
		await get_tree().create_timer(1.2).timeout
		Input.action_press(&"attack")

	if "--simulate-skillshot" in args:
		await get_tree().create_timer(1.4).timeout
		Input.action_press(&"skillshot")

	if "--simulate-ability-q" in args:
		await get_tree().create_timer(1.6).timeout
		Input.action_press(&"ability_q")

	if "--simulate-ability-e" in args:
		await get_tree().create_timer(1.8).timeout
		Input.action_press(&"ability_e")

	if "--simulate-self-eliminate" in args:
		await get_tree().create_timer(1.0).timeout
		var characters := get_node_or_null(^"../Characters")
		var own_character := (
			characters.get_node_or_null(str(multiplayer.get_unique_id())) if characters else null
		)
		if own_character:
			own_character.take_damage(9999.0)

	# Slice 13b live-test hook: simulates a real mid-match drop (server
	# forcibly severing one client's ENet connection) without killing
	# either process -- the dropped client's own ReconnectManager
	# autoload survives (it's the process staying alive that lets it
	# hold the token and auto-retry), same as a real WiFi blip. Only
	# meaningful on --server; disconnects the first non-host peer found.
	for arg in args:
		if arg.begins_with("--dev-kick-after="):
			var delay := arg.trim_prefix("--dev-kick-after=").to_float()
			await get_tree().create_timer(delay).timeout
			var peers := multiplayer.get_peers()
			if not peers.is_empty():
				multiplayer.multiplayer_peer.disconnect_peer(peers[0])
