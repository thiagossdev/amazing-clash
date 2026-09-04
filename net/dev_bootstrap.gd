extends Node
## Dev-only bootstrap for manual 2-instance playtesting, headless-friendly
## so Phase 1's networking can be verified without a GUI.
##
## Phase 17: `project.godot`'s `run/main_scene` has been
## `res://ui/main_menu/MainMenu.tscn` since Phase 7 (Room Config
## replaced a fixed-TestArena-at-startup flow) -- this node only exists
## as a child of `res://maps/test_arena/TestArena.tscn`, so a bare
## `godot4 --headless -- --server` launches MainMenu and never reaches
## this file's own `_ready()` at all (no error, no output, nothing --
## a real gap found live during this phase's own verification, easy to
## mistake for the game silently failing to start). The scene must be
## passed explicitly: `godot4 --headless
## res://maps/test_arena/TestArena.tscn -- --server ...`.
##
## Reads args after "--": `-- --server` hosts, `-- --join` connects to 127.0.0.1,
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
## specific aim). `-- --simulate-ability-q` / `-- --simulate-ability-e` /
## `-- --simulate-ability-r` / `-- --simulate-ability-f` fire one press
## each ~1.6s/~1.8s/~2.0s/~2.2s in, same reasoning, to prove Phase 3's
## (and Phase 15's) independent ability slots. `-- --simulate-boot-
## active` fires one press ~2.4s in, same reasoning, for Phase 16's
## boot_active slot -- this peer never goes through Room Config here,
## so it always casts whichever ability the fallback boot (index 0)
## grants, not a specific boot pick (see ui/lobby/lobby.gd's own
## --dev-boot=<id> for testing an actual boot CHOICE instead of just
## the cast mechanic). `-- --dev-print-log-path` prints
## "GAME_LOG_PATH:<path>" once GameLog's file is open (Phase 18) --
## grep this line out of a headless run's stdout to find the real
## user://logs/ file to inspect. `-- --friendly-fire` sets
## MatchState.friendly_fire_enabled -- a per-match server setting
## decided at startup, not a live-togglable console command (who's
## allowed to change a match rule mid-game is a separate authority
## question, not opened here). `-- --simulate-self-eliminate` directly
## zeroes this peer's own character's health ~1s after EVERY
## Phase.IN_PROGRESS transition (not just the first -- Phase 17
## generalized this from a single one-shot timer to a repeating
## EventBus.match_state_changed listener, so the SAME flag can also
## force a full best-of-3 sequence: this peer "loses" every round until
## round_wins reaches ROUND_TARGET, all in one continuous live run,
## with no new flag needed) so Phase 5's elimination/win-condition/HUD
## chain, and Phase 17's own round transitions, can be exercised
## deterministically without depending on 2 characters actually
## connecting a hit. `-- --dev-auto-confirm-intermission` (Phase 17)
## watches EventBus.match_state_changed and presses Confirm the instant
## ROUND_INTERMISSION begins, so a live test doesn't have
## to simulate a real dropdown/button click to exercise the confirm-set
## countdown deterministically; combine with core/match_state.gd's own
## --dev-intermission-*= overrides to avoid eating the real 15s/5s/3s
## waits. `-- --dev-print-replay-path` (Phase 19) prints "REPLAY_PATH:
## <path>" once net/lobby_state.gd's own _start_match() has opened
## ReplayRecorder's file -- only meaningful through the real Room
## Config flow (this peer's own direct-connect path above never calls
## _start_match(), so this would always print an empty path there).
## `-- --dev-change-weapon-in-intermission=<id>` changes this peer's
## own weapon the instant ROUND_INTERMISSION begins, to exercise
## ReplayRecorder.record_loadout_change() live -- combine with
## --dev-auto-confirm-intermission to actually advance past the window
## afterward. `-- --dev-kick-after=<seconds>` (server
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

## Slice 13b: a successful reconnect reloads TestArena.tscn fresh (see
## net/reconnect_manager.gd's own _rpc_receive_reconnect_result()),
## which re-instantiates this same node and re-runs _ready() with the
## SAME --join/--server cmdline args still present -- found live, that
## re-ran NetworkManager.join() a 2nd time on an already-just-restored
## connection, tearing it down and forcing yet another reconnect cycle
## (observably: a 3rd distinct peer_id, orphaned duplicate character,
## repeating forever). _ran_once is a plain static var, not per-
## instance state, precisely because it must survive across that
## reload (a fresh instance's own field would reset to false and never
## catch this). Real players are unaffected -- host_join.gd's own
## normal launch never sets --join/--server, so every block below is
## already a no-op for them regardless of this guard.
static var _ran_once := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()

	if not _ran_once:
		_ran_once = true
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
				GameLog.error("dev_bootstrap_host_failed", {"error": err})
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
				GameLog.error("dev_bootstrap_join_failed", {"error": err})

		if "--dev-print-log-path" in args:
			print("GAME_LOG_PATH:%s" % GameLog.current_log_path())

		# Phase 19: unlike GameLog (already open by this point, thanks to
		# enter_in_progress()'s own GameLog.info() call above),
		# ReplayRecorder only ever opens once net/lobby_state.gd's
		# _start_match() runs -- this peer's own direct-connect flow
		# above never calls it at all (see net/replay_recorder.gd's own
		# start_recording() doc comment for why: no real Room Config
		# loadout choice exists to record for a peer that skipped Room
		# Config). Printing here would always be empty; wait for the
		# LOADING transition _start_match() itself triggers instead, the
		# same live-flow live testing already uses for weapon/boot
		# (Phase 16's own verify.md section).
		if "--dev-print-replay-path" in args:
			EventBus.match_state_changed.connect(
				func(new_phase: int):
					if new_phase == MatchState.Phase.LOADING:
						print("REPLAY_PATH:%s" % ReplayRecorder.current_replay_path())
			)

		# Phase 19 live-test hook: changes this peer's own weapon the
		# instant ROUND_INTERMISSION begins, so a live run can exercise
		# ReplayRecorder.record_loadout_change() deterministically --
		# combine with --dev-auto-confirm-intermission to actually
		# advance past the window afterward.
		for arg in args:
			if arg.begins_with("--dev-change-weapon-in-intermission="):
				var new_weapon_id := arg.trim_prefix("--dev-change-weapon-in-intermission=")
				EventBus.match_state_changed.connect(
					func(new_phase: int):
						if new_phase == MatchState.Phase.ROUND_INTERMISSION:
							LobbyState.set_local_weapon(new_weapon_id)
				)

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

		if "--simulate-ability-r" in args:
			await get_tree().create_timer(2.0).timeout
			Input.action_press(&"ability_r")

		if "--simulate-ability-f" in args:
			await get_tree().create_timer(2.2).timeout
			Input.action_press(&"ability_f")

		if "--simulate-boot-active" in args:
			await get_tree().create_timer(2.4).timeout
			Input.action_press(&"ability_t")

		# Slice 13b live-test hook: simulates a real mid-match drop
		# (server forcibly severing one client's ENet connection)
		# without killing either process -- the dropped client's own
		# ReconnectManager autoload survives (it's the process staying
		# alive that lets it hold the token and auto-retry), same as a
		# real WiFi blip. Only meaningful on --server; disconnects the
		# first non-host peer found.
		for arg in args:
			if arg.begins_with("--dev-kick-after="):
				var delay := arg.trim_prefix("--dev-kick-after=").to_float()
				await get_tree().create_timer(delay).timeout
				var peers := multiplayer.get_peers()
				if not peers.is_empty():
					multiplayer.multiplayer_peer.disconnect_peer(peers[0])

	# Phase 17: these 2 listeners must re-register on EVERY _ready()
	# call, including the scene reload a round transition causes --
	# unlike everything above (guarded by _ran_once, which must NOT
	# re-fire on reload, see this file's own Slice 13b doc comment),
	# these need a fresh connection each time since the OLD DevBootstrap
	# node (and its own previously-connected lambda) is freed by the
	# reload. Godot auto-disconnects a lambda Callable when its owning
	# script instance is freed, so the stale connection from the
	# previous instance cleans itself up on its own -- no manual
	# disconnect needed. Caught by reasoning through this file's own
	# Slice 13b history before ever running it, not by observing a live
	# failure first: registering these 2 listeners behind the same
	# _ran_once guard as everything else above would have made round 2
	# of a --simulate-self-eliminate live test never self-eliminate
	# again, since the listener that would have fired belonged to an
	# already-freed node from round 1's own DevBootstrap instance.
	if "--simulate-self-eliminate" in args:
		EventBus.match_state_changed.connect(
			func(new_phase: int):
				if new_phase != MatchState.Phase.IN_PROGRESS:
					return
				await get_tree().create_timer(1.0).timeout
				_dev_self_eliminate()
		)

	if "--dev-auto-confirm-intermission" in args:
		EventBus.match_state_changed.connect(
			func(new_phase: int):
				if new_phase == MatchState.Phase.ROUND_INTERMISSION:
					MatchState.set_local_loadout_confirmed(true)
		)


## Found live (Phase 17): CharacterController.take_damage() mutates
## current_health directly with no authority check or RPC -- it's meant
## to be called only from already-server-only code (CombatResolver's
## own hit application). Calling it directly on a non-host peer only
## ever touches that peer's own local PREDICTED copy (see Phase 9's own
## "MultiplayerSpawner replication creates separate node instances for
## the AUTHORITATIVE/PREDICTED/INTERPOLATED copies" lesson,
## memory/plan.md's Slice 9 block) -- the server's own authoritative
## character never changes, so MatchRules (server-only) never sees the
## elimination and the match never progresses. This was a pre-existing
## gap in --simulate-self-eliminate itself, invisible before Phase 17
## because every earlier phase that used this flag only ever ran it on
## the host. Routes through the server via RPC when this peer isn't
## the server; calls take_damage() directly (no RPC round-trip needed)
## when it already is.
func _dev_self_eliminate() -> void:
	if NetworkManager.is_server():
		_apply_dev_self_eliminate(multiplayer.get_unique_id())
	else:
		_rpc_dev_self_eliminate.rpc_id(1)


## any_peer, but never trusts a client-supplied peer id -- eliminates
## only the CALLER's own character, same trust reasoning every other
## any_peer RPC in this project already uses.
@rpc("any_peer", "reliable")
func _rpc_dev_self_eliminate() -> void:
	if not NetworkManager.is_server():
		return
	_apply_dev_self_eliminate(multiplayer.get_remote_sender_id())


func _apply_dev_self_eliminate(peer_id: int) -> void:
	var characters := get_node_or_null(^"../Characters")
	var character := characters.get_node_or_null(str(peer_id)) if characters else null
	if character:
		character.take_damage(9999.0)
