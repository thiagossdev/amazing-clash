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
