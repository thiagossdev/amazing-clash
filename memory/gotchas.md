# Mistakes Log

After any correction from the human, log the pattern here. Review at
session start before starting new work. The goal is to drive the error
rate toward zero.

Format:

- **Date** — *mistake* → **rule**

---

- **2026-09-02** — `net/dev_bootstrap.gd`'s `--simulate-move` handling put
  `await get_tree().create_timer(...)` *before* the `NetworkManager.host()/
  join()` call in the same `_ready()`. Awaiting suspends only that node's
  own `_ready()` coroutine, but sibling nodes' `_ready()` calls (in this
  case `PlayerSpawner`, which checks `NetworkManager.is_server()` once,
  at ready time, and never re-checks) still ran immediately — so
  `PlayerSpawner` saw `is_server() == false` on both the server and
  client process and silently never wired up `peer_connected`/
  `peer_disconnected` or spawned anything. Surfaced only as a confusing
  downstream engine error ("RPC ... not allowed ... authority is 1") two
  layers removed from the real cause, in a live 2-process test — caught
  by tactile verification, not by reading the code. → **Rule**: never put
  an `await` before a same-`_ready()` call that another sibling node's
  own `_ready()` depends on having already happened; do the
  dependency-setting call synchronously first. More generally: root-cause
  a networking error from the actual first divergent state (add a
  `_ready()`-time print of the values the error implies, e.g. `is_server()`
  here), not from the error message's own surface location.

- **2026-09-02** — Copied `amazing-nauts`' debug-console test pattern
  (a synthetic `InputEventKey` with only `physical_keycode` set, no
  `keycode`) for an Escape-closes-the-console test, and it failed:
  `project.godot` had no explicit `ui_cancel` action, so it fell back
  to Godot's engine-default binding, which a `physical_keycode`-only
  synthetic event doesn't match the way this project's OWN actions
  (move/dash/debug toggles, all defined with `physical_keycode`) do.
  `amazing-nauts` never hit this because its `project.godot` already
  redefines `ui_cancel` explicitly with `physical_keycode`. → **Rule**:
  when copying a test that simulates a built-in Godot UI action
  (`ui_cancel`, `ui_accept`, etc.) via `physical_keycode`, also copy or
  add that action's explicit `physical_keycode`-based InputMap entry —
  don't assume the engine default matches this project's own input
  convention. Writing the behavioral test (not just the pure-logic
  `parse_command` one) is what caught this; a copy-and-trust-it pass
  would have shipped it silently broken.

- **2026-09-02** — `PlayerSpawner` spawned every connecting peer at the
  exact same `SPAWN_POSITION` constant. Live-tested a melee attack
  between two characters spawned on top of each other and it silently
  never landed: with both at the identical position, the attacker's
  hitbox rect and the defender's hurtbox rect met at an EXACT shared
  boundary (not a real overlap), and `Rect2.intersects()` doesn't treat
  edge-touching as intersecting. No error, no crash -- just a hit that
  never registers, easy to misdiagnose as a combat-resolver bug rather
  than a spawn-placement one. → **Rule**: never spawn two players (or
  any two things meant to interact via AABB overlap) at an identical
  coordinate, even for a throwaway test setup -- it's also a real
  product bug (two players should never start a match stacked on each
  other) and it produces exactly this class of silent, boundary-exact
  non-intersection. Fixed with `PlayerSpawner.SPAWN_POSITIONS` (plural,
  distinct points, cycled per connecting peer) instead of one shared
  constant.

- **2026-09-02** — `for node in projectiles.get_children(): if not node
  is Projectile: continue; var alive := node.advance_frame(...)` failed
  to import: "Cannot infer the type of 'alive' variable because the
  value doesn't have a set type." An `is` check followed by `continue`
  does not narrow the loop variable's static type in GDScript --
  `node` (typed `Node` from `get_children()`) is still `Node` afterward,
  so calling a `Projectile`-only method on it is a dynamic/duck-typed
  call returning an untyped Variant, which `:=` can't infer. → **Rule**:
  after an `is` type-check on a loop/generic variable, assign an
  explicit `var typed_thing := node as Type` before calling
  type-specific methods on it — don't rely on the `is` check itself to
  narrow the type for later statements.

- **2026-09-03** — Added `pack_ability_flags`/`unpack_ability_flags`
  static functions to `input/input_buffer.gd` between the `Sample`
  inner class and the `_samples` var declaration; `gdlint` failed with
  `Error: Definition out of order in global scope
  (class-definitions-order)`. → **Rule**: gdlint enforces a strict
  top-level ordering (inner classes, then var declarations, then
  functions/static functions) — a static helper function can't appear
  before a class-level `var`, even one unrelated to it. When adding a
  new static function to a script that already has top-level `var`s,
  place it after all of them, not next to the class/data it logically
  operates on.

- **2026-09-03** — Testing the Phase 5 friendly-fire gate: placed a
  2nd-spawned teammate at a *higher* x than the 1st, then had it
  `--simulate-attack` the 1st. Got "no hit" with friendly fire off and
  assumed that proved the gate worked -- it didn't. Melee's default
  facing is `Vector2.RIGHT` (no move input yet), so the attacker's
  swing went toward higher x, away from its target; the hit would have
  missed regardless of the friendly-fire flag. Only caught by also
  running the SAME test with friendly fire ON and getting the SAME "no
  hit" result -- if the flag genuinely gated it, ON should have shown a
  hit. → **Rule**: when a live test's "expected: blocked" result could
  also be explained by "the attack never had a chance to land" (wrong
  facing direction, out of range, wrong timing), always run the
  positive control too (the same setup with the gate open) before
  treating a negative result as confirmation. A single "nothing
  happened" run proves nothing on its own.

- **2026-09-03** — Phase 7: `PlayerSpawner` spawned unconditionally at
  `_ready()`, same as every prior phase. That was safe when TestArena
  was the fixed main scene (every peer's tree already existed by the
  time anyone connected), but Phase 7 made Lobby → TestArena a real
  per-peer `change_scene_to_file()` with no cross-process
  synchronization -- the server's own tree could finish (and start
  replicating spawned characters) before a remote peer's own
  `TestArena/MultiplayerSpawner` node existed yet, producing "Node not
  found: TestArena/MultiplayerSpawner" only on the client, silently
  never explained by anything server-side (the server's own log showed
  nothing wrong). → **Rule**: an RPC-driven scene change changes the
  risk profile of *any* code that assumes "my tree exists, therefore
  every other connected peer's does too" -- re-audit every `_ready()`
  that spawns/replicates something the instant a fixed main scene
  becomes a dynamically-loaded one, don't assume prior-phase-safe code
  stays safe.

- **2026-09-03** — Phase 7's live 2-process verification: a dev-only
  `--dev-autostart` hook fired the host's Start button after a fixed
  1-second `create_timer` delay, mirroring `dev_bootstrap.gd`'s own
  `--simulate-*` pattern. It looked broken (host started solo,
  `multiplayer.get_peers()` was empty) even though the client process
  *had* been launched. Root cause: 2 independent OS processes launched
  from 2 separate tool calls have no shared clock and no synchronized
  start time -- `Time.get_ticks_msec()` on one process says nothing
  about the other's progress, and Godot's own headless cold-start time
  (first-run import, resource loading) varies enough that a
  same-machine sibling process isn't a safe timing assumption either.
  → **Rule**: a dev-only auto-advance hook driving a *multi-process*
  live test should poll real, observable state (here:
  `LobbyState.player_class_ids.size() >= 2`) instead of a fixed delay,
  even when the single-process precedent (`dev_bootstrap.gd`'s own
  simulate-input timers) uses one safely -- those only wait on *that
  same process's* own connection to complete, not on a sibling
  process's independent progress.

- **2026-09-03** — Phase 8's live 2-process test used
  `--dev-switch-team=<id>`, assuming a connecting client would get a
  small, predictable ENet peer id (like the descriptive "peer 2" used
  in earlier phases' verification prose). It got id `1625438661` --
  ENet peer ids are effectively random 32-bit values, not sequential
  small ints. The flag silently targeted a peer that didn't exist (a
  harmless no-op registration), so the "manual team switch" it was
  supposed to prove never actually happened, and the test's own log
  looked identical whether the feature worked or not -- no error, no
  crash, just a passing-looking run that proved nothing. → **Rule**:
  never assume a headless dev-test flag can target a remote peer by a
  literal numeric id; poll for "the first/only currently-registered
  non-host peer" instead (see `ui/lobby/lobby.gd`'s
  `_await_and_switch_first_client_team()`). Only the LOCAL peer's own
  id/input is safe to hardcode a flag around (see every existing
  `--simulate-*` flag in `net/dev_bootstrap.gd`, which only ever
  affects that same process's own character).

- **2026-09-03** — `/check` on the Phase 8 diff found `MatchState.
  match_mode` was never replicated to clients, even though Room Config
  (this phase) now lets the host choose it dynamically after clients
  have already connected. Before this phase, `match_mode` was only
  ever set via `net/dev_bootstrap.gd`'s `--free-for-all` flag, read
  identically by both processes before either one connected -- so
  every peer's own copy happened to already agree, masking that
  nothing was actually keeping them in sync. Phase 8's Room Config
  broke that hidden assumption: only the *server's* `MatchState.
  match_mode` got set when the host pressed Start, so every non-host
  client's `MatchHud` would silently render Team-mode text/banners
  during an actual FFA match. → **Rule**: a field that "happens to
  agree across peers" because every process independently derives it
  from the same static input (a CLI flag, a hardcoded default) is not
  actually replicated -- the moment one peer can change that value at
  runtime (a UI control, a host decision), it needs an explicit RPC,
  not an assumption that the old bootstrapping coincidence still
  holds. Re-audit every "read-only, server-only" doc comment on a
  shared field when the thing that used to set it identically
  everywhere gets a live UI control instead.

- **2026-09-03** — Also from `/check`: the new host-only "Switch Team"
  control in Room Config had no guard against moving every connected
  peer onto the same team. `gameplay/match/win_condition.gd`'s
  `teams_ever_present >= 2` guard (added Phase 5, generalized Phase 6)
  never resolves NONE/DRAW/a winner with only 1 team ever populated --
  a match started that way hangs in `IN_PROGRESS` forever, undetected
  by anything (no error, no crash, just a match that never ends).
  Before Phase 8, automatic `index % 2` team assignment made this
  configuration structurally impossible with 2+ players; manual
  assignment removed that implicit safety net without anything
  replacing it. → **Rule**: when replacing an automatic invariant
  (here: "team assignment always produces >=2 populated teams") with a
  manual control, explicitly check whether anything downstream was
  silently relying on that invariant holding -- it usually is, and the
  fix is almost always cheaper before shipping (one pure validation
  function, `LobbyState.has_valid_team_split()`) than after.

- **2026-09-03** — The human owner caught a real authority error in
  Phase 8's shipped "Switch Team" control mid-Phase-9: it was
  host-only (the host clicking any player's row moved *that* player),
  but the intended model is self-service -- each player controls only
  their own team. → **Rule**: when a manual per-player control lets
  one privileged actor (the host) mutate another peer's own state,
  default to asking "should this actually be self-service instead?"
  before shipping -- host-only felt natural to build (it's the same
  authority level as the mode/friendly-fire/Start controls right next
  to it in the UI) but wasn't actually the right model for *this*
  specific field. Fixed by keying the server-side RPC off
  `multiplayer.get_remote_sender_id()` (never a client-supplied peer
  id) instead of checking "is the sender the host" -- the same trust
  pattern `_rpc_register` (class choice) already used, which
  structurally removes the need for a host-authority check on this RPC
  at all rather than adding one.

- **2026-09-03** — Phase 9's perk multiplier was first written into
  `net/player_spawner.gd`, right next to where class/team get applied
  at spawn -- looked consistent with the existing pattern, but
  `PlayerSpawner` only ever runs on the *server*, producing the one
  AUTHORITATIVE copy of each character. Every other peer's own local
  copy of that same character (PREDICTED for its owner, INTERPOLATED
  for everyone else) is a separate node instance spawned by
  `MultiplayerSpawner`'s own replication machinery, which never calls
  `PlayerSpawner`'s code. A stat multiplier set only in `PlayerSpawner`
  therefore never reached the very peer who picked the perk, for
  anything read locally (movement speed, cooldown timers) -- it would
  have looked like the perk silently did nothing outside the server's
  own internal simulation, and a single-process live test can't catch
  this at all (it only ever observes the server's own copy). → **Rule**:
  any per-character value that a *remote* peer needs to see/feel
  locally (not just something the server resolves in combat) must be
  computed on every peer's own `_ready()`/spawn path from already-
  replicated data, not written once by whichever code path happens to
  run server-side only. `CharacterController._apply_perk_from_lobby_
  state()` is the fix -- reads `LobbyState` directly, runs identically
  on every peer, no new RPC needed since the source data was already
  replicated.

- **2026-09-03** — Phase 10's `LanDiscovery.start_listening()` binds a
  fixed UDP port (`DISCOVERY_PORT`) so a client can receive room
  broadcasts. `HostJoin._ready()` called this unconditionally for
  *every* peer landing on the Host/Join screen -- including one about
  to become the host, since a real player should get to browse rooms
  before deciding to host or join. This project's own local-
  verification convention (`memory/plan.md`: "2+ headless processes
  for local verification") runs host and joiner as 2 separate OS
  processes on the *same machine*, so both processes' `_ready()` tried
  to bind the identical port -- a real race, not just a theoretical
  one. Godot's `PacketPeerUDP.bind()` has no `SO_REUSEPORT`/address-
  reuse option exposed in the GDScript API, so there's no clean way to
  let 2 sockets share the port the way some other engines' networking
  APIs allow. → **Rule**: when a headless dev-test convention runs
  multiple processes on one machine to simulate multiple players, any
  new fixed-port `bind()` (not `connect()`/outbound-only) needs to be
  released as early and deterministically as possible on the path that
  doesn't need it anymore -- here, `_on_host_pressed()` now calls
  `LanDiscovery.stop_listening()` as its very first line, before
  `NetworkManager.host()` even runs, minimizing the bind-hold window
  to effectively zero. This is a genuine, if narrow, test-environment-
  only limitation -- 2 real players are always on separate machines
  with separate network stacks and can never hit this.

- **2026-09-03** — `/check` on the Phase 13a diff found `gameplay/
  match/match_rules.gd`'s own header comment still claimed a
  disconnect drops a team's alive count to 0 *immediately*, even
  though the diff it was reviewing changed exactly that -- Phase 13a
  touched `net/player_spawner.gd` and `core/match_state.gd` but never
  re-read `match_rules.gd`'s own doc comment, which described the
  *old* behavior it depended on, not the code it lived next to. →
  **Rule**: when a change alters a documented behavioral guarantee
  (here: "a disconnect resolves instantly"), grep for every comment
  elsewhere in the codebase that describes or depends on that
  guarantee -- not just the file being edited -- before considering
  the change complete. A comment describing someone else's code is
  still a claim that needs to stay true.

- **2026-09-03** — Also from `/check`: `net/player_spawner.gd`'s new
  `--dev-grace-period=<seconds>` flag parsed the value with plain
  `String.to_float()`, which returns `0.0` on any parse failure with
  no error -- a typo like `--dev-grace-period=abc` would have silently
  set the grace period to 0 seconds (every disconnect despawning
  instantly, the *opposite* of the flag's purpose) with nothing in the
  logs to explain why. → **Rule**: `to_float()`/`to_int()` on
  string input from outside the program (CLI args, RPC payloads, file
  contents) needs an explicit `is_valid_float()`/`is_valid_int()`
  check first, or a parse failure silently becomes a plausible-looking
  wrong value instead of a loud error -- this project's own "no silent
  fallbacks" rule (`CLAUDE.md`) applies just as much to a dev-only
  debug flag as to production input.

- **2026-09-03** — Found via `/waza:hunt` during real cross-machine
  play-testing (Linux host, Windows client): turning the client's WiFi
  off then back on left it staring at a frozen `TestArena` forever,
  spamming `ERROR: No multiplayer peer is assigned. Unable to get
  unique ID.` (`modules/multiplayer/scene_multiplayer.cpp:531`, from
  `ui/hud/network_stats_overlay.gd:140`'s `_ensure_tracking_own_
  character()`). Root cause, confirmed by reproducing the exact error
  in a GUT test (not just read from the backtrace): `net/
  network_manager.gd`'s `close()` -- the handler for both `multiplayer.
  server_disconnected` and `.connection_failed` -- only ever nulls
  `multiplayer.multiplayer_peer`, it never changes scene. `TestArena`
  (and `NetworkStatsOverlay` inside it) keeps running regardless, and
  `_ensure_tracking_own_character()` calls `multiplayer.get_unique_id()`
  unconditionally every `_process()` tick with no guard. → **Rule**:
  Godot's `SceneTree.multiplayer` has an implicit default peer-like
  state (`has_multiplayer_peer()` reads `true`) until something
  *explicitly* nulls it -- confirmed directly (see the fix attempt's
  own throwaway check), not assumed. A GUT test asserting "no peer" as
  the default/never-touched state is wrong; the test must explicitly
  set `multiplayer.multiplayer_peer = null` first to reproduce a real
  post-disconnect condition (and restore the original value after, so
  the shared singleton doesn't leak into other test files).
  **Deliberately not fixed here** -- the human owner correctly pointed
  out that just bouncing the player to `MainMenu` on disconnect isn't
  a real fix without Slice 13b's token-based reconnect (not built
  yet): today there is *no* way to resume the same character after a
  disconnect regardless of which screen the player lands on, so
  "return to menu" alone would just be a smaller trap, not a solution.
  Folded into Slice 13b's own scope instead (`memory/plan.md`) --
  fixing this crash properly is part of designing what a disconnected
  client's own screen should actually do, not a standalone patch.

- **2026-09-03** — Diagnosed the LAN-discovery asymmetry/hung-join
  report (see the entry above) as caused by WSL2 NAT, and wrote that
  into `net/lan_discovery.gd`'s own doc comment as if confirmed --
  based on running `wslinfo --networking-mode` in *this* Claude Code
  session's own dev environment (which does run under WSL2) and
  quietly assuming that was the human owner's test setup too. It
  wasn't: the human owner tested on 2 real separate physical machines
  (Linux + Windows) on real Wi-Fi, an exported build carried over by
  hand -- no WSL2 involved at all. Caught only because the human owner
  happened to mention the setup explicitly; nothing about the original
  report itself contradicted the wrong assumption. → **Rule**: never
  infer a bug reporter's environment from the agent's own dev
  environment, even when a detail (Linux, WSL, a specific IP range)
  coincidentally matches -- ask, or find explicit evidence of their
  actual setup, before writing a root cause into permanent
  documentation. This is a specific case of this project's own
  "Reporter reproduces, local machine is fine" gotcha: verify the
  reporter's actual configuration, don't substitute the agent's own.

- **2026-09-03** — Real root cause of the LAN-discovery report above,
  confirmed (not guessed) via the human owner's own `sudo ufw status
  verbose`: `ufw` active on the Linux machine, default incoming policy
  `deny`, no rule for either 7777 (ENet gameplay) or 7778 (discovery
  beacon). `ufw`'s default drop is silent (no RST/ICMP), which is
  exactly why a blocked join hangs forever instead of failing cleanly
  -- explains every symptom in the original report at once (see
  `net/lan_discovery.gd`'s own updated comment for the full mapping).
  One extra trap along the way: a "direct IP connects instantly" test
  looked like it contradicted a "connecting hangs forever" test on the
  same machine, until it came out that the 2 tests had opposite host/
  client roles -- the working one only ever needed the Linux machine's
  *outbound* access, never touching the blocked inbound rules at all.
  → **Rule**: when 2 tests against the same machine give conflicting
  results, check whether they actually exercised the same direction of
  connection (who dialed whom) before treating the contradiction as
  evidence against a firewall/NAT/inbound-blocking hypothesis --
  outbound-only tests can't rule out an inbound-only block.

- **2026-09-03** — Follow-up on the same investigation: the `ufw`
  diagnosis above was only partially right. After the human owner
  applied both `ufw allow` rules, joining a Linux-hosted room started
  working (confirming the 7777/udp piece was correct and complete),
  but Linux still can't discover a Windows-hosted room, even with
  7778/udp confirmed present in `ufw status verbose`. → **Rule**: a
  confirmed root cause that explains every symptom at diagnosis time
  can still be incomplete -- verify the fix against EACH original
  symptom individually once applied, not just "did the overall report
  go away," since a multi-symptom report can have more than one
  contributing cause that happen to look identical from the outside.
  Session ended before the human owner could test further (no machine
  access) -- 2 leads recorded in `net/lan_discovery.gd`'s own comment
  for whoever picks this up: Docker's own iptables rules (confirmed
  installed on that machine via `ufw status`'s `allow-docker-dns`
  entry) can override what `ufw status` reports as allowed; and the
  2 machines' actual subnets were never directly compared.

- **2026-09-03** — Slice 13b (token-based reconnect): a reconnecting
  peer's raw ENet connection always fires `multiplayer.peer_connected`
  (and the ordinary `PlayerSpawner._spawn_for_peer()` it triggers)
  *before* its own reconnect-token RPC can possibly arrive -- that RPC
  is itself a round trip over the connection `peer_connected` just
  reported established, so the server-side ordering can't be won.
  Left unhandled, this spawned a permanent throwaway duplicate
  character answering to the same `controlling_peer_id` as the
  reclaimed original, so the reconnecting client fully predicted and
  drove both from 1 set of inputs. → **Rule**: when a design lets 2
  independent code paths (a generic "new connection" handler and a
  specific "this connection is actually a resume" handler) both react
  to the same underlying event, expect the generic one to fire first
  and unconditionally -- design the specific handler to clean up after
  it, not to preempt it.

- **2026-09-03** — Same investigation: the first fix for the bug above
  (`queue_free()` the duplicate character immediately inside
  `try_reclaim()`) was live-verified to be WORSE than the original
  bug -- it raced `MultiplayerSpawner`'s own initial replication burst
  to the just-connected peer and produced real cascading engine errors
  ("Node not found", "Invalid packet received", "ERR_UNAUTHORIZED" on
  the client's own despawn-receive path), not just noisy logs. A 1-
  second defer before freeing resolved it cleanly across every trial
  run. → **Rule**: freeing a `MultiplayerSpawner`-replicated node in
  the same tick it was spawned is unsafe regardless of how correct the
  *decision* to remove it is -- the replication protocol needs time to
  actually reach every peer first. Don't assume `queue_free()` is a
  safe, timing-independent operation on a networked node just because
  it is on a local one; and when you can't reproduce a subtle network
  race in a genuinely correct way (no exposed "replication settled"
  signal existed here), a documented bounded delay is a legitimate,
  honestly-flagged interim mitigation -- shipping it with a clear "not
  a real fix, here's what the real fix needs" note beats either
  leaving the worse bug in place or silently pretending the delay is
  bulletproof.

- **2026-09-03** — Same investigation: the original Slice 13b design
  reloaded `TestArena.tscn` (`get_tree().change_scene_to_file()`) on a
  successful reconnect, reasoning it would hand the client a clean
  scene instead of the disconnect-frozen one. Live-confirmed this
  reload itself corrupted `MultiplayerSpawner`'s replication caches on
  both ends -- the same class of cascading engine errors as the
  duplicate-despawn bug above, since the reload yanks the entire local
  scene tree out from under an still-active multiplayer connection
  without the replication layer ever being told. → **Rule**: don't
  reload the scene a live multiplayer connection's nodes live in as a
  way to "reset" client state; if a node's state is already correct
  and already replicated (as the reclaimed character's was, having
  never actually despawned during the grace period), leave it in place
  and let the existing replicated RPCs update it instead.

- **2026-09-03** — Also found while chasing the reload bug above: `net/
  dev_bootstrap.gd`'s `--join`/`--server` cmdline flags were being
  re-read (and `NetworkManager.join()` re-executed) every time the
  reload above re-ran its `_ready()`, tearing down an already-just-
  restored connection and forcing another reconnect cycle -- observed
  as a 3rd distinct peer_id and another orphaned duplicate character.
  Fixed with a `static var _ran_once` guard regardless of the reload
  fix, since any future scene reload would otherwise repeat the same
  mistake. → **Rule**: a dev/test-only bootstrap script that reads
  `OS.get_cmdline_user_args()` in `_ready()` needs to guard against
  running more than once per process if ANYTHING in the app can cause
  its own node to be re-instantiated (scene reload, respawn) -- the
  cmdline args don't go away just because the node did.

- **2026-09-03** — Same investigation, found after shipping (asked by
  the human owner, not caught by any test at merge time): the
  reconnect token was single-use by design (`try_reclaim()` erases it
  on success) but nothing ever issued a replacement, so a peer that
  successfully reconnected once had no valid token left to survive a
  *second* disconnect in the same match -- `net/reconnect_manager.gd`
  would still hold the now-dead token, present it, and the server
  would reject it outright, sending that peer to the main menu instead
  of recovering. → **Rule**: any "consume on success" token/nonce
  design needs an explicit answer for "what happens on the *next*
  attempt" before shipping -- single-use is a correct security
  property in isolation, but silently becomes single-use-per-match
  wide unless the success path also reissues. Fixed in
  `net/player_spawner.gd`'s `try_reclaim()` by calling
  `_issue_reconnect_token(new_peer_id)` right after a successful
  reclaim. Surfaced a 2nd, adjacent issue: `_issue_reconnect_token()`
  unconditionally called `.rpc_id()` on its remote branch, which is
  fine for every real caller (always an actually-connected peer) but
  explodes with a real engine error ("Method/function failed") the
  moment a unit test calls `try_reclaim()` directly with a fabricated
  peer_id and no live `ENetMultiplayerPeer` behind it --
  `multiplayer.get_peers()` guard added so the RPC dispatch only fires
  for a peer_id Godot's own multiplayer layer actually knows about.
  → **Rule**: a helper written for one call site's guarantees (always
  a real connected peer) can silently violate a *different* call
  site's environment (a pure-logic unit test) once it's reused --
  re-check every existing caller's assumptions before adding a 2nd one,
  not just the new caller's own correctness.

- **2026-09-04** — Phase 14: added a new `signal`/`const` block placed
  right next to the code that logically discusses it (a countdown's
  signal and its tuning constants, added inline where the countdown
  logic itself was being written) instead of grouped with the file's
  existing signal/const declarations at the top. `gdlint` failed with
  `class-definitions-order` -- it enforces one strict category order
  (signals, then enums, then constants, then exported vars, then public
  vars, then private vars) across the WHOLE file, not just "don't
  interleave inside one section." → **Rule**: in this project's
  GDScript files, always add a new signal/const/var next to the file's
  EXISTING declarations of that same category, never inline near the
  function that uses it, however locally logical that placement feels
  -- run `gdlint` immediately after adding any new top-level
  declaration, before writing the functions that use it, to catch this
  in one small diff instead of a larger reshuffle later.

- **2026-09-04** — The stop hook's lint check (`agent-md.toml`'s
  `[verify].lint`) kept failing on files inside
  `.claude/worktrees/agent-.../` -- a background fork's own
  in-progress, not-yet-formatted worktree, nothing wrong in the
  primary checkout. Root cause: `.gdlintrc`'s `excluded_directories`
  listed the combined path `.claude/worktrees`, but gdtoolkit's own
  exclusion logic (`gdtoolkit/common/utils.py`) filters `os.walk()`'s
  `dirnames` one path SEGMENT at a time (`d not in
  excluded_directories`) -- a multi-segment string like
  `.claude/worktrees` never equals any single segment (`.claude` and
  `worktrees` show up as separate walk steps), so the entry was a
  silent no-op the whole time; `gdformat` was never affected only
  because its own invocation in `agent-md.toml` builds an explicit
  pre-pruned file list (`find ... -path ./.claude/worktrees -prune`)
  instead of relying on `.gdlintrc` at all. → **Rule**: any tool whose
  "excluded directories" config matches by walking segment-by-segment
  (check the tool's own source, don't assume) needs bare directory
  NAMES, not multi-segment paths -- `.git`/`addons` worked here only
  because they're already single segments; test an exclusion by
  actually triggering the tool against a matching path, don't just
  trust that adding an entry that "looks right" worked. Fixed by
  changing the entry to the bare segment `worktrees`.

- **2026-09-04** — Phase 15 (ability_r/ability_f): `ClientPredictor.
  Checkpoint` restored an ability slot's `.state`/`.move_frame` on
  reconciliation but never `.current_move` -- only the SHARED
  `action_fsm`'s checkpoint field (`action_move`) ever had this right,
  since Phase 3 wrote `ability_q`/`ability_e`'s checkpoint fields as a
  visually-similar-looking but incomplete copy of it.
  `ActionFsm.advance_frame()` dereferences `current_move`
  unconditionally the moment `state` isn't `NEUTRAL` -- a
  reconciliation replay landing on a restored non-`NEUTRAL` slot with
  `current_move` still null (or stale from a previous cast) crashed the
  CLIENT ONLY with a real engine error ("Invalid access to property or
  key 'startup_frames' on a base object of type 'Nil'"), never the
  server (which never reconciles). Latent for Q/E since Phase 3 --
  their own live tests never happened to hit the exact reconciliation
  timing that triggers it; R/F's own live test (heavier, held-input
  cast pressure from `Input.action_press` firing every tick) is what
  first exposed it. → **Rule**: when a "capture into a Checkpoint,
  restore from it" pattern already exists correctly for one field
  (`action_move`) and you're copying its shape for a sibling field
  (`ability_q`'s own equivalent), diff the copy against the original
  line-by-line rather than pattern-matching by eye -- a plausible-
  looking partial copy that's missing one field compiles fine, passes
  every existing test (nothing exercised the missing field's absence),
  and only crashes under a specific runtime timing nobody happened to
  trigger yet. Fixed once, for all 4 slots (Q/E/R/F) at the same time,
  not just the 2 new ones.

- **2026-09-04** — Same phase, found via self-review before it could
  repeat itself: `ui/debug/hitbox_viewer.gd`'s F1 overlay draws
  `action_fsm`/each ability slot's melee hitbox by an explicit
  if-check per named slot (`if character.ability_q and not
  character.ability_q.is_projectile: ...`), NOT generically like
  `CombatResolver._resolve_ability_slot()` does -- so adding a new
  ability slot to `CharacterController` silently does not extend this
  file, even though it looks like it should from the pattern. This is
  the exact same class of bug the human owner already caught once for
  Q/E during Phase 3 play-testing (documented in that file's own doc
  comment) -- R/F would have repeated it verbatim had self-review not
  caught it first. → **Rule**: when a file's own doc comment already
  says "the human owner caught this exact mistake once before," treat
  that as a standing checklist item for every future change that adds
  the same kind of thing (here: a new ability slot) -- grep for every
  OTHER file that pattern-matches on a slot by name (not just the 2
  files a phase's own scope says to touch) before considering the
  phase done.

- **2026-09-04** — Phase 17 (best-of-3 rounds): `Node.multiplayer`
  only resolves once a node is actually inside the `SceneTree` -- a
  freshly `.new()`-ed `MatchStateScript` (never `add_child()`-ed) has
  `multiplayer == null`, not the default `SceneMultiplayer` a fresh
  `MatchState`-shaped test would expect. Every prior test in this
  project that touched `multiplayer` from a manually-instantiated,
  non-autoload copy (`LobbyStateScript.new()`, `PlayerSpawner.new()`)
  happened to only ever touch it through `NetworkManager.is_server()`
  or via server-vs-client branches that resolved without ever calling
  a bare `multiplayer.X` on the off-tree instance itself -- this
  phase's `all_loadout_confirmed()` was the first method in the
  project to call `multiplayer.has_multiplayer_peer()`/
  `multiplayer.get_unique_id()` directly on such an instance, and it
  crashed immediately. → **Rule**: before writing a unit test that
  calls `multiplayer.X` on a manually-instantiated (not-autoload) Node,
  add it to the tree first via GUT's `add_child_autofree()` -- it still
  shares the same default `SceneMultiplayer` every other node
  (including the real autoload) resolves to, giving a properly
  isolated instance (separate own-Dictionary state) that doesn't crash
  on `multiplayer` access. Don't assume an existing project convention
  covers a new touch-point just because it "looks similar" to code that
  already works off-tree -- check what that existing code ACTUALLY
  touches, not just its overall shape.

- **2026-09-04** — Same phase: nothing gated
  `CharacterController._physics_step_predicted()`'s own
  `_rpc_send_input` sends on match phase, so a client kept sending
  input for its about-to-be-replaced character all through the new
  `ROUND_INTERMISSION` window. The very first live 2-process test of a
  round transition crashed the SERVER with "Cannot call method
  'get_remote_sender_id' on a null value" the instant an already-in-
  flight input packet arrived after the round-transition reload had
  already detached the receiving character node (`multiplayer`
  resolves to `null` on a detached node, same underlying fact as the
  test gotcha above, this time hit by REAL network traffic instead of
  a test). → **Rule**: introducing a new match-phase transition that
  tears down/replaces already-live networked nodes (a round reload, a
  scene change) needs an explicit audit of every OTHER system that
  keeps sending/processing RPCs against those nodes based on ITS OWN
  local trigger (here: "every physics tick," unrelated to match phase)
  -- don't assume an existing send loop will naturally stop just
  because the nodes it targets are about to go away; gate the SEND
  side on the new phase explicitly, and add a receive-side
  `is_inside_tree()` guard as defense against whatever's already
  in-flight when you do.

- **2026-09-04** — Phase 18's fork committed `net/game_log.gd` but not
  its companion `net/game_log.gd.uid` -- not caught by `gdformat`/
  `gdlint`/GUT (none of them care whether a `.uid` file exists), only
  surfaced when the orchestrating session's post-merge `godot4
  --headless --import` silently generated a fresh one, which then
  showed up as an untracked file. → **Rule**: after merging a
  fork-built phase, `git status --short` right after the mandatory
  `--import` pass -- a `??` on a `.uid` file means the fork's own `git
  add` missed it (easy to do, since a `.uid` is easy to forget
  alongside its `.gd`/`.tscn`/`.tres` and produces no lint/test
  failure on its own) -- add and commit it immediately rather than
  leaving it untracked.

- **2026-09-04** — Phase 20: `net/replay_driver.gd`'s `_spawn_
  characters()` used `child.queue_free()` (deferred -- actual removal
  happens at end-of-frame) instead of `child.free()` (immediate).
  Calling `_spawn_characters()` twice in the same frame -- `load_
  replay()` immediately followed by `seek_to_frame()`, or a `round_end`
  record followed by the new round's own first tick within the SAME
  `_apply_next_tick_record()` call -- meant the OLD character node
  still held the name `str(peer_id)` at the moment the NEW one was
  `add_child()`ed with that same name. Godot silently auto-renamed the
  new node to a generic fallback (`@CharacterBody2D@14`, etc.) rather
  than erroring, so every `str(name).to_int()`-keyed lookup for it
  (`_ready()`'s own `LobbyState` application, `_apply_tick()`'s own
  character lookup) silently found nothing. Found only via a live
  record-then-playback comparison (a mid-match seek showed 4
  characters, 2 of them ghosts, instead of 2) -- no unit test caught it,
  since none of them called `_spawn_characters()` twice in the same
  frame the way real usage does. → **Rule**: when the SAME container's
  children get freed and immediately re-populated (a respawn, a reset,
  a rebuild) more than once within a single call chain, `queue_free()`
  is unsafe if the replacement reuses the same node NAME -- prefer
  immediate `free()` (or `remove_child()` first) so the name is
  actually free before the collision can occur. A unit test that adds
  children and asserts on their names/state after 2 back-to-back
  resets would have caught this without needing a live run; worth
  adding if this class of bug recurs.

- **2026-09-04** — Phase 20's own live-verification setup: a bare
  `godot4 --headless -s <custom_script.gd extends SceneTree>` does NOT
  get `project.godot`'s configured autoload singletons
  (`NetworkManager`, `MatchState`, `LobbyState`, etc.) registered as
  global script identifiers the way a normal scene launch (or GUT's own
  `addons/gut/gut_cmdln.gd`, itself also a custom `SceneTree` script)
  does -- `SCRIPT ERROR: Compile Error: Identifier not found:
  NetworkManager`, and the process then hung rather than exiting
  cleanly. → **Rule**: don't write a throwaway custom `SceneTree`
  script to manually verify something that touches this project's
  autoloads -- write a temporary GUT test instead (removed before the
  final commit if it's not meant to be permanent, same convention as
  every other phase's own temporary live-test instrumentation) since
  GUT's own runner already solves this bootstrapping problem correctly.

- **2026-09-04** — Found live via `/hunt` (human owner: "reproduzir
  replay não renderiza os projéteis"): `ui/replay/ReplayPlayer.tscn`
  (Phase 20) never instantiated a `CombatResolver` node or a
  `Projectiles` container, both present as siblings of `Characters` in
  every real match's scene (`maps/test_arena/TestArena.tscn`).
  `CharacterController.replay_step_authoritative()` only advances a
  character's own movement/ability-FSM state -- ALL projectile
  spawning (`_maybe_launch_projectile()`), projectile advancement, and
  melee/ability hit-damage resolution live entirely in `CombatResolver`
  (`gameplay/combat/combat_resolver.gd`'s own doc comment: "wired as
  TestArena's LAST child"), a structurally separate system. Since
  Phase 20's own live verification only compared `ticks_processed`/
  `is_finished`/`final_winner`/`round_wins` (all copied straight from
  the replay file's own recorded `round_end`/`match_end` records, not
  derived from live combat resolution during playback), it never
  actually observed that no combat was happening during reconstruction
  -- a real gap in that phase's own test coverage that only surfaced
  once someone watched a replay expecting to actually SEE a fight.
  → **Rule**: when reconstructing a scene/subsystem in a NEW context
  (a replay driver, a test harness, a preview mode), diff its node
  composition against the REAL scene it's meant to reproduce, not just
  its script/data layer -- a missing sibling node is invisible to any
  test that only checks recorded/structural outcomes (round count,
  winner) rather than actually exercising the live subsystem the new
  context is supposed to run. A second, adjacent bug found the same
  way: `net/replay_driver.gd`'s `load_replay()` parsed the header's own
  `friendly_fire` field but never applied it to
  `MatchState.friendly_fire_enabled` (which `CombatResolver` reads
  directly) -- same root pattern, a header field that looked wired in
  because it was PARSED, but was never actually APPLIED anywhere.

- **2026-09-04** — Found live via real hands-on testing (human owner:
  "enter/space deu certo. Mas não vi esse botão"): `ui/replay/
  ReplayPlayer.tscn`'s entire bottom `Controls` row (`PlayPauseButton`/
  `SkipBackButton`/`SkipForwardButton`/`Scrubber`/`BackButton`) was
  positioned at `offset_top/bottom = 740/780`, past this project's own
  default viewport height (648, `display/window/size/viewport_height`
  in `project.godot`) -- `BackButton`'s right edge (1180) was also past
  the viewport width (1152). The whole row had been genuinely
  off-screen since Phase 20's original build. Keyboard activation
  (`grab_focus()` + Enter/Space, added this same day for the "Back to
  List" button) still worked perfectly despite this -- Godot's
  focus/action-triggering system doesn't require a Control to be
  visually on-screen, only that it holds focus -- which is exactly why
  a real, fully-invisible layout bug produced a working keyboard
  interaction and no visible symptom to a text-only/headless
  verification pass. → **Rule**: a Control positioned by fixed
  `offset_*` values (not anchors) needs its own numbers checked against
  the project's REAL configured viewport size
  (`ProjectSettings.get_setting("display/window/size/viewport_width
  /height")`), not just "looks reasonable" -- this project's own "no
  way to screenshot Godot's real renderer" gap (flagged on every
  UI-adjacent phase since Phase 7) makes this exact class of bug
  invisible to every verification method available except a real human
  looking at a real running window. Added a regression test
  (`test_every_control_fits_inside_the_real_viewport` in
  `tests/unit/test_replay_player_scene.gd`) that checks every Control
  under a screen's root against the actual configured viewport
  dimensions, specifically because this bug class has no other
  automated way to be caught in this environment.

- **2026-09-04** — Found live via `/hunt` (human owner: "no 8X os
  projeteis não são disparados", plus a vaguer "problema de
  interpolação" that led to a Scope Blast sweep). Root cause:
  `net/replay_driver.gd`'s `_physics_process()` applies `playback_speed`
  recorded ticks per REAL physics frame (a loop calling
  `_apply_next_tick_record()` N times), but `CombatResolver` --
  the only place `_maybe_launch_projectile()`'s exact
  `slot_fsm.move_frame == move.startup_frames` check lives -- is a
  sibling node whose own `_physics_process()` the Godot ENGINE still
  calls exactly once per real frame, never once per simulated tick. At
  `playback_speed` 1 this coincides (1 tick == 1 real frame, matching a
  live server tick exactly); at higher speeds, N ticks' worth of
  ability-FSM advancement happen before `CombatResolver` ever inspects
  the state, so the single-tick-wide activation window is invisible
  unless it happens to land on the very last tick of a batch. → **Rule**:
  a node whose own logic depends on catching an EXACT single-tick state
  transition (not "has this become true", but "did this become true ON
  THIS tick") cannot rely on the engine's own once-per-real-frame
  callback once anything else in the scene can advance MULTIPLE
  simulated ticks within one real frame -- it must be driven explicitly,
  once per tick, by whatever owns that multi-tick loop. Fixed:
  `ReplayDriver._ready()` disables `CombatResolver`'s own automatic
  engine callback (`set_physics_process(false)`) and `_apply_tick()`
  calls it explicitly, once per simulated tick, instead.
  **Scope Blast swept this exact pattern and found a 2nd, more
  fundamental match**: `CharacterController._physics_process()` is ALSO
  a normal engine-driven once-per-real-frame callback -- left enabled
  during replay, it fired IN ADDITION to `ReplayDriver._apply_tick()`'s
  own explicit per-tick `replay_step_authoritative()` call, at EVERY
  playback speed including 1x. Since that explicit call already
  pushes-then-immediately-pops its one `Sample` from `ServerSim`'s
  buffer, the engine's own extra automatic call found an empty buffer
  and fell into `ServerSim.next_input()`'s own stale-input fallback --
  silently repeating the character's last move direction for one
  uncommanded phantom tick, every single real frame, compounding over
  the whole replay. This is very likely the actual mechanism behind the
  human owner's own vaguer "problema de interpolação" report -- verified
  by reading `net/server_sim.gd`'s `next_input()` directly, not
  guessed. Fixed the same way: `ReplayDriver._spawn_characters()` now
  calls `character.set_physics_process(false)` on every spawned
  character. Checked every other node with per-frame logic in
  `ReplayPlayer.tscn` (`Projectile` -- no processing of its own, driven
  entirely by the now-fixed `CombatResolver`; `HitboxViewer`/
  `ArenaCamera` -- correctly want once-per-real-frame, pure visual
  redraw/positioning, not state mutation) -- no further matches. 3 new
  regression tests, confirmed red (all 3 -- stashing the whole fixed
  file together reverted both bugs at once) then green.

- **2026-09-04** — Direct regression from the fix immediately above:
  disabling `CharacterController`'s automatic `_physics_process()`
  during replay (to stop the phantom-tick bug) silently disabled
  `_update_visual_feedback()` (hit flash, swing pulse) too --
  `replay_step_authoritative()` calls `_physics_step_authoritative()`
  but never called `_update_visual_feedback()` on its own; that was
  only ever reachable through the real `_physics_process()` override's
  own trailing call, one line after the control-mode `match`. Found
  live (human owner: "Antes eu estava vendo os flash de damage hit e
  agora não mais") immediately after the previous fix shipped.
  → **Rule**: when disabling a node's automatic per-frame callback and
  replacing it with an explicit call to "the same underlying step,"
  read the ENTIRE original callback, not just the branch that looks
  like the interesting part -- a trailing call after a `match`/`if` is
  easy to mentally treat as separate from "the real logic" and leave
  behind. `character_controller.gd:290-298`'s own shape (a `match` on
  `control_mode`, then one more unconditional call) is exactly this
  trap. Fixed by adding the same `_update_visual_feedback()` call to
  `replay_step_authoritative()`.

- **2026-09-04** — Adopting an explicit design resolution (1920x1080,
  matching `amazing-dungeons`' own already-validated pattern) and
  converting `ui/main_menu/MainMenu.tscn`/`ui/character_select/
  CharacterSelect.tscn`/`ui/host_join/HostJoin.tscn`/`ui/lobby/
  Lobby.tscn`/`ui/replay/ReplayList.tscn`'s children to anchor-based
  (mostly screen-centered) positioning, a new regression test
  (`tests/unit/test_ui_viewport_bounds.gd`) immediately caught a 2nd,
  more fundamental gap in the same 5 scenes: each one's own ROOT node
  is itself a `Control` (`anchors_preset = 0`, no explicit anchor/
  offset values), which defaults to Godot's own zero-size `Control` --
  a CHILD's percentage-based anchor (0.5 = "50% of the parent") resolves
  against THAT zero-sized parent, not the real viewport, when the
  parent Control itself was never told to fill the screen. Every
  centered child came back at a large NEGATIVE screen position (its raw
  offset value, unchanged, since 50% of 0 is still 0). `ui/replay/
  ReplayPlayer.tscn` never hit this because its Controls live under a
  `CanvasLayer`, which has no "size" of its own for children to anchor
  against -- their anchors resolve straight against the viewport. →
  **Rule**: when a scene's own top-level node is a plain `Control`
  (not a `CanvasLayer`), that root Control must ALSO be anchored to
  fill the screen (Godot's "Full Rect" preset: `anchors_preset = 15`,
  `anchor_right`/`anchor_bottom = 1.0`, `grow_horizontal`/
  `grow_vertical = 2`) before ANY percentage-based anchor on its
  children means anything real -- converting children to anchors
  without first checking the root's own sizing is an incomplete fix
  that LOOKS correct (percentages, sensible-looking offset math) while
  still being just as broken as fixed pixel coordinates were. Caught
  entirely by the new automated test, not by inspection -- this is
  exactly the kind of bug this project's "no way to screenshot Godot's
  real renderer" gap makes invisible any other way.

<!--
Examples:

- **2026-04-15** — Assumed `USER_ID` env var was set; silently fell back
  to empty string. → **Rule**: No silent fallbacks on env vars. Hard-fail
  at startup if required vars are missing.

- **2026-04-18** — Renamed `getUserPrefs` via grep; missed a dynamic
  import in `src/lib/legacy.ts`. → **Rule**: On every rename, search
  separately for static calls, type references, string literals, dynamic
  imports, re-exports, test mocks.
-->
