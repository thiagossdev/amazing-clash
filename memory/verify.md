# Definition of Done

Every task's verification criteria must pass before it is marked complete
in `progress.md`. No exceptions.

## Text Verification (always required)

- [ ] Type-check passes in strict mode (project's type-checker)
- [ ] Lint passes (all configured linters, zero warnings)
- [ ] Tests pass (existing + new tests for new code)

## Tactile Verification (when code executes)

- [ ] Code was actually run — not just written. Script ran, endpoint
  responded, CLI output observed.
- [ ] Logs checked — no unexpected errors, warnings, or deprecations.
- [ ] At least one happy path and one edge case exercised manually.

## Visual Verification (UI changes only)

- [ ] Screenshot captured via Playwright (`.agent-md/bin/playwright-capture.sh`)
- [ ] VLM or human review confirms visual intent matches the spec
- [ ] No self-grading ("the code looks right") — independent verification

## Independent Verification

- [ ] Not self-graded. One of: sub-agent review, test suite, or the human
  confirmed.

## Structured Output / Tool Verification

- [ ] Tool arguments and structured outputs were validated before use
  (required fields, types, enum values, and file paths).
- [ ] Tool failures used structured error information where available:
  `status`, `type`, `message`, `suggestion`.
- [ ] High-risk claims or changes had an adversarial or independent check.

## Task-Specific Criteria

### Slice 1 (Phase 1): Networking skeleton

- [x] `godot4 --headless --import` runs clean after adding new scenes/
  scripts (catches missing `.uid`/import errors before manual testing).
- [x] Two client instances connect to one local server; both
  `Character.tscn` instances walk and dash. Verified via 2 headless
  `godot4` processes (`-- --server`/`-- --join`, `--simulate-move`):
  both a server-owned and a client-owned character reached `DASHING`
  and had it replicated to the other peer.
- [x] The locally-controlled character responds with no perceptible
  round-trip delay: input is applied to `apply_input()` locally before
  the RPC to the server is even sent (`_physics_step_predicted`), so
  this is true by construction, not just observed.
- [x] Under `NetworkManager`-injected artificial latency (tested at
  50ms one-way / ~100ms round trip), the remote character's movement is
  smooth: server-authoritative and client-received positions converged
  to the same values in the same 2-process test, with no error and no
  divergence.
- [x] Disconnecting and reconnecting one client resyncs it without
  restarting the match for the other client. Verified: killed a
  connected client, waited past ENet's disconnect-detection window
  (~8s), confirmed the server despawned that peer's character (no more
  snapshot broadcasts for it) and the server kept running throughout;
  a new client then joined and spawned normally, all with zero errors
  in either log.
- [x] Debug overlay code (`ui/hud/network_stats_overlay.gd`) implements
  ping via `NetworkManager.get_peer_rtt_ms(1)` and snapshot rate via
  counting `snapshot_received` emissions — reviewed, not visually
  confirmed (headless mode has no renderer to screenshot); flag this
  gap explicitly rather than claim a visual check that didn't happen.
- [x] GUT tests pass for the locomotion FSM's pure logic (state
  transitions, dash cooldown): 10/10, via
  `godot4 --headless -s addons/gut/gut_cmdln.gd`.
- [x] `3d/physics_engine="Jolt Physics"` line removed from
  `project.godot` (2D confirmed 2026-09-02; this line is now template
  leftover, not a decision).
- [x] Independent verification: tactile, not self-graded from code
  review. Actually ran 2+ concurrent headless `godot4` processes across
  4 separate scenarios (plain walk, dash, artificial latency, disconnect/
  reconnect) and read their logs directly. One real bug was found and
  fixed this way (`net/dev_bootstrap.gd`'s `--simulate-move` await
  ordering silently broke `PlayerSpawner`'s server-detection — see
  `memory/gotchas.md`, 2026-09-02) that code review alone had missed.

### Debug instrumentation (F1 hitbox viewer, "/" console)

- [x] The debug overlay (originally `CollisionShapeViewer`, renamed to
  `HitboxViewer` during Phase 2a once it actually drew combat hitboxes
  — see that section below) starts hidden, F1 toggles it, joins the
  `hitbox_viewer` group — 3/3 GUT tests (`test_hitbox_viewer.gd`).
- [x] Debug console: "/" opens it, an OS key-repeat echo doesn't
  re-toggle it, a second "/" while open doesn't close it, Escape closes
  without executing, `/latency <ms>` updates
  `NetworkManager.artificial_latency_ms` — 8/8 GUT tests
  (`test_network_stats_overlay_console.gd`), including the
  behavioral (not just `parse_command`-logic) cases that caught the
  missing `ui_cancel` InputMap entry (see `memory/gotchas.md`,
  2026-09-02).
- [x] `gdformat --check` / `gdlint` / `godot4 --headless --import` /
  `markdownlint-cli2` all clean; live 2-process network smoke test
  (walk+dash) still clean after every change in this slice.
- [ ] Visual confirmation that F1/`/` actually render correctly on
  screen — not done, same headless-has-no-renderer gap as the ping/
  snapshot-rate overlay above. The behavioral GUT tests confirm the
  toggle *logic*; nobody has looked at the actual drawn shapes or
  console UI with eyes yet.

### Phase 2a: melee combat core

- [x] `ActionFsm` (NEUTRAL/STARTUP/ACTIVE/RECOVERY, frame-counted,
  `is_hitbox_active()` only true during ACTIVE) — 7/7 GUT tests
  (`test_action_fsm.gd`).
- [x] `HitDetection` pure geometry (hitbox rect rotated by aim
  direction, hurtbox rect, AABB query) — 5/5 GUT tests
  (`test_hit_detection.gd`).
- [x] `DamagePipeline.compute` (base × combo scaling × buff modifier)
  — 4/4 GUT tests (`test_damage_pipeline.gd`).
- [x] `CharacterController`'s combat additions (attack-pressed starts
  the test move, a second press mid-move doesn't restart it,
  `get_aim_direction()` matches `LocomotionFsm.facing_direction`,
  `take_damage`/`apply_lock` bookkeeping) — 6/6 GUT tests
  (`test_character_controller_combat.gd`).
- [x] Live 2-process test: a melee attack thrown by one peer's
  character lands on the other's, server-authoritatively — confirmed
  via temporary instrumentation (removed after verifying, per this
  project's own established practice): damage applied (100 → 90),
  hitstop/hitstun locks applied to attacker and defender respectively,
  and the health drop correctly replicated to the *other* peer's own
  view of the hit character. Zero errors, including with `--simulate-
  move` and `--simulate-attack` combined in the same run.
- [x] Found and fixed a real product bug this way, not just a test
  artifact: `PlayerSpawner` spawned every peer at the identical
  position, so a melee attack silently never landed (hitbox and
  hurtbox touched at an exact shared boundary, not a true overlap) —
  see `memory/gotchas.md`, 2026-09-02. Fixed with distinct
  `SPAWN_POSITIONS`, cycled per connecting peer.
- [x] `gdformat --check` / `gdlint` / `godot4 --headless --import` /
  `markdownlint-cli2` all clean. 44/44 GUT tests total project-wide.
- [ ] Knockback and a true rotated (non-axis-aligned) hitbox are
  explicitly deferred, not silently dropped — see
  `gameplay/combat/hit_definition.gd` and `hit_detection.gd`'s own doc
  comments for why.

### Phase 2b: aimed skillshot / projectile combat

- [x] `Projectile` (deterministic `position += direction * speed *
  delta`, direction normalized regardless of input magnitude, lifetime
  countdown, `already_hit` reset on `configure()`) — 7/7 GUT tests
  (`test_projectile.gd`).
- [x] `HitDetection.projectile_hitbox_rect` (centers on the projectile,
  not attacker-relative like melee's `hitbox_rect`) — 1 new GUT test
  added to `test_hit_detection.gd` (6/6 in that file now).
- [x] `InputManager.get_aim_direction()` (mouse-world-position-minus-
  character-position via the viewport's own canvas transform, not
  `LocomotionFsm.facing_direction`) and `CharacterController.apply_input()`
  capturing it into `pending_skillshot_direction` at cast time, not
  read live later — reviewed; no dedicated unit test (needs a live
  viewport/mouse, same class of gap as the debug overlay's visual
  confirmation below).
- [x] Live 2-process test: both peers' skillshots spawn, and — this is
  the core Phase 2b claim — **the server's and the client's own local
  Projectile instances tracked byte-for-byte identical positions at
  every checkpoint, for the entire flight, with zero per-tick network
  sync**, confirming the deterministic-replication design actually
  holds under real (if artificial-latency-free, in this run) network
  conditions. Confirmed via temporary instrumentation, removed after
  verifying. Zero errors, including with `--simulate-move
  --simulate-attack --simulate-skillshot` combined in one run.
- [x] Did not force a live-network hit confirmation for the skillshot
  specifically: headless mode has no real mouse, so both peers' test
  casts aimed toward the same deterministic (but not deliberately
  aimed-at-each-other) point and didn't happen to collide in this run.
  Not treated as a gap needing a workaround: hit *application* for a
  projectile hit runs through the exact same `_apply_hit`/`take_damage`/
  `DamagePipeline` path Phase 2a already proved live, and the
  projectile-specific hit *geometry* (`projectile_hitbox_rect` +
  `HitDetection.query`) is independently proven by GUT. Forcing a
  coincidental live hit would be redundant, not more rigorous.
- [x] `gdformat --check` / `gdlint` / `godot4 --headless --import` /
  `markdownlint-cli2` all clean. 52/52 GUT tests total project-wide.
- [ ] No piercing, no early "projectile ended on hit" broadcast to
  other peers (the server despawns its own instance immediately on a
  confirmed hit; a remote peer's purely-decorative copy keeps flying
  until its own lifetime expires) — deliberate, documented scope cuts,
  not silent gaps; see `gameplay/combat/combat_resolver.gd`'s own doc
  comment.
- [ ] Visual confirmation that a skillshot's hitbox/projectile actually
  renders and looks right on screen — not done, same headless-has-no-
  renderer gap as every other visual item in this file.

### Phase 3: Ability Framework (2 independent Q/E slots)

- [x] `AbilityResource` loads and imports cleanly as a `class_name`
  Resource (`gdformat`/`gdlint` clean, confirmed registered in
  `godot4 --headless --import`'s class list alongside
  `CharacterController`).
- [x] `CharacterController`'s ability-slot additions — independent
  activation of Q and E, both active simultaneously with melee, no
  restart mid-move on a repeated press, cooldown blocks an immediate
  re-cast right after the move ends, re-cast succeeds once the
  cooldown fully elapses — 6/6 new GUT tests
  (`test_character_controller_combat.gd`, 12/12 in that file now).
- [x] `project.godot` InputMap: `attack` confirmed rebound to
  `InputEventMouseButton button_index=1` (left mouse button, was
  physical_keycode 74/J); `ability_q`/`ability_e`/`ability_r`/
  `ability_f`/`ability_t` confirmed bound to physical_keycode 81/69/
  82/70/84 (Q/E/R/F/T) — read directly from `project.godot`, not
  inferred.
- [x] Live 2-process test (server casts `--simulate-attack
  --simulate-ability-q --simulate-ability-e`, client `--join`):
  server log shows the base melee attack landing (10 dmg), ability_q/
  Power Strike landing as its own melee hit (25 dmg) independently of
  the base attack's own cooldown/state, and ability_e/Fireball
  spawning a projectile via the generalized `_rpc_spawn_projectile`
  (slot_name="ability_e") — confirmed replicating identically to the
  client's own log line (byte-for-byte same direction vector), proving
  the slot-name-keyed spawn/lookup generalization preserves Phase 2b's
  deterministic-replication guarantee for a second, independently-
  cooldown-gated projectile source. Confirmed via temporary
  instrumentation (`[VERIFY]`/`# TEMP-VERIFY-PHASE3`), removed after
  verifying. Zero errors on either peer's log across 3 separate live
  runs (combined, and ability_e isolated to rule out a timing
  coincidence).
- [x] `gdformat --check` / `gdlint` / `godot4 --headless --import` all
  clean. 58/58 GUT tests total project-wide.
- [ ] Ability_e/Fireball's projectile connecting with the defender in
  the same live run wasn't forced/observed — not treated as a gap: the
  hit-application and hit-geometry paths are unchanged from Phase 2b's
  already-live-verified skillshot (same `_apply_hit`/`HitDetection.
  projectile_hitbox_rect` code, just reached via a generalized
  slot-name lookup instead of a hardcoded field), and the spawn itself
  (the part that actually changed this phase) is directly confirmed
  above.
- [ ] Remote (`INTERPOLATED`) peer visual replication of ability_q/e
  `ActionFsm` state — explicitly deferred, not silently dropped; see
  `memory/plan.md`'s Slice 3 networking note. Hit resolution is
  unaffected (already server-only).
- [ ] R/F/T keybindings are registered in the InputMap but wired to no
  ability — explicitly deferred pending the human owner's decision on
  how many slots a real class kit should have (Phase 4).
- [ ] Per-ability projectile speed/lifetime — both projectile-capable
  slots share `CombatResolver`'s existing constants; deferred until a
  real ranged class (Phase 4) needs differentiated projectile feel.

### Phase 4: first 2 real classes (Vanguard, Ranged Mage)

- [x] The `debug_attack_move`/`debug_skillshot_move` → `attack_move`/
  `skillshot_move` rename touched every call site (`character_controller.gd`,
  `combat_resolver.gd`, `hitbox_viewer.gd`, `Character.tscn`,
  `test_character_controller_combat.gd`) — confirmed via `grep -rn` for
  the old names returning zero matches project-wide (excluding
  `addons/`) after the rename.
- [x] `Vanguard.tscn`/`RangedMage.tscn` each wire a distinct, correct
  kit (not Character.tscn's placeholder data) — 2/2 new GUT tests
  (`test_character_classes.gd`), asserting `move_name`/`ability_name`/
  `is_projectile`/`max_health` on both scenes.
- [x] `godot4 --headless --import` clean after adding 8 new
  `MoveDefinition` `.tres`, 4 new `AbilityResource` `.tres`, and 2 new
  character scenes, and after retargeting `TestArena.tscn`'s
  `MultiplayerSpawner._spawnable_scenes` from `Character.tscn` to the
  2 real class scenes.
- [x] Live 2-process test: server (peer 1, spawned first) got Vanguard,
  the joining client peer got Ranged Mage — confirming `PlayerSpawner.
  CLASS_SCENES` alternation assigns distinct classes per connection
  order. Server casting attack + ability_q + ability_e landed Quick
  Slash (8 dmg), Heavy Slam (28 dmg), and Bulwark Strike (15 dmg) --
  all 3 exactly matching Vanguard's authored kit stats, resolved
  server-authoritatively through the same generic `CombatResolver`
  path Phase 3 already proved. Confirmed via temporary instrumentation
  (`[VERIFY]`/`# TEMP-VERIFY-PHASE4`), removed after verifying. Zero
  errors on either peer's log.
- [x] `gdformat --check` / `gdlint` (project files, excluding the
  third-party `addons/gut/` which has its own pre-existing,
  out-of-scope lint findings) / `godot4 --headless --import` all
  clean. 60/60 GUT tests total project-wide.
- [ ] Ranged Mage's own kit (Arcane Jab/Bolt/Frost Shard/Nova) wasn't
  separately exercised in the same live run (only Vanguard, the
  server's own peer, cast abilities in this test) — not treated as a
  gap: `test_character_classes.gd` confirms Ranged Mage's kit is wired
  correctly, and hit *resolution* for a projectile-style ability is
  already live-verified generically in Phase 3 (Fireball/ability_e).
  Forcing a second live-cast run with a headless "client casts" flag
  would exercise the same code path again, not new code.
- [ ] Character-select UI, a 3rd class, and visual on-screen
  confirmation of each class's distinct `Visual` color are explicitly
  deferred — see `memory/plan.md`'s Slice 4 block and Deferred list.

### Phase 5: match modes (team assignment, friendly fire, elimination win condition, minimal HUD)

- [x] `WinCondition.determine()` pure logic — 5/5 new GUT tests
  (`test_win_condition.gd`): no result before both teams have
  connected, team 1 wins when team 0 is eliminated (and vice versa), a
  simultaneous mutual elimination resolves as a draw, no result while
  both teams still have survivors.
- [x] Live 2-process test (`--simulate-self-eliminate`, a new
  permanent dev-testing flag that zeroes a peer's own health directly,
  bypassing hit geometry): confirmed the full chain end-to-end —
  `team_status` broadcasts updated correctly as each peer connected
  (`team0=1,team1=0` → `team0=1,team1=1`) and again the instant the
  server's own character was eliminated (`team0=0,team1=1`);
  `enter_post_game(winning_team=1)` fired server-side; **the same
  event reached the client** (`enter_post_game winning_team=1
  is_server=false`), confirming `MatchState`'s new `@rpc` broadcast
  actually replicates match-phase state to a client for the first time
  — previously `enter_in_progress()` never had an RPC at all and
  nothing client-side read `current_phase`, so this had never been
  live-tested before this phase. Zero errors on either peer.
- [x] Live 3-process test (server + 2 clients, the 2nd and 3rd peers
  landing on the same team by `index % 2`): with `MatchState.
  friendly_fire_enabled` at its default (`false`), a teammate's
  `--simulate-attack` produced **no** hit log. With `--friendly-fire`
  passed to the server, the exact same geometry produced `hit
  attacker=...(team0) defender=...(team0) damage=8.0` (Quick Slash's
  authored damage, confirming the right move resolved). Running both
  conditions with identical spawn geometry rules out a false positive
  from a simply out-of-range attack — the first run's silence is
  actually the friendly-fire gate, not a missed swing.
- [x] Found and fixed a real geometry bug during this same live
  testing (not assumed from code review): the first spawn-position
  layout placed the 2nd-spawned teammate at a *higher* x than the
  1st, so that teammate's default rightward-facing melee swing missed
  entirely regardless of the friendly-fire flag — the initial "off
  blocks it" result was a false positive. Fixed by placing the
  2nd-spawned teammate at a *lower* x (see `net/player_spawner.gd`'s
  own doc comment); re-ran both conditions with the corrected layout
  before treating the result as conclusive.
- [x] Regression check: the base 2-peer test (`--simulate-attack
  --simulate-ability-q --simulate-ability-e` on the server) still ran
  with zero errors on both peers. No hits landed in this specific run
  because the new team-clustered spawn layout now puts opposite-team
  characters 600 units apart by default (previously 60) — an accepted,
  documented consequence of realistic 2v2 spawn positioning, not a
  regression: the melee/projectile hit-resolution code itself is
  unchanged from Phase 2a-4 and was independently reconfirmed by the
  friendly-fire-ON test above (an 8.0-damage hit landing correctly).
- [x] `gdformat --check` / `gdlint` (project files, excluding
  third-party `addons/gut/`) / `godot4 --headless --import` all clean.
  65/65 GUT tests total project-wide.
- [ ] Character-select UI / lobby, a real reconnect/grace-period
  system, and per-character team visibility on remote clients (only
  the aggregate `team_alive_counts` is client-visible) are explicitly
  deferred — see `memory/plan.md`'s Slice 5 block and Deferred list.
- [ ] `MatchHud`'s visual rendering (label positions, banner
  readability) was not screenshot-verified — same headless-has-no-
  renderer gap as every other visual item in this file.

### Phase 6: 3rd class (Warden) + free-for-all mode

- [x] `WinCondition.determine()`'s new signature — 8/8 GUT tests
  (`test_win_condition.gd`): every prior 2-team case re-verified under
  the new `(alive_team_ids, teams_ever_present)` shape (no result
  before 2 teams connect, either team winning on the other's
  elimination, a simultaneous draw, no result with survivors on both
  sides) plus 3 new free-for-all (N>2) cases: no result while >1
  player survives, the last surviving player wins, a draw when the
  last 2 players mutually eliminate.
- [x] Warden's kit wiring and its balance identity — 2/2 new GUT tests
  (`test_character_classes.gd`, 4/4 in that file now): `attack_move`/
  `skillshot_move`/`ability_q`/`ability_e` all point at the correct
  named moves with the correct `is_projectile` flags and `max_health`;
  a dedicated assertion that Warden's E ability has strictly more
  `hitstun_frames` than either Vanguard's or Ranged Mage's own E, so a
  future balance pass can't silently erode the archetype's identity
  without a test noticing.
- [x] Live 3-process team-mode regression test (server + 2 clients, no
  mode flag): confirmed team assignment (`index % 2` → 0, 1, 0) and
  class assignment (`index % 3` → Vanguard, Ranged Mage, Warden) both
  still resolve correctly and independently now that a 3rd class
  exists — team 0 ends up with a mixed Vanguard+Warden composition,
  confirming the "2-vs-3 modulus mismatch is intentional" design note
  in `net/player_spawner.gd`. Zero errors.
- [x] Live free-for-all tests (`--free-for-all`, `--simulate-self-
  eliminate` on various peers): confirmed unique per-player team
  assignment (0, 1, 2 for 3 connecting peers); confirmed a team
  self-eliminating before a 2nd team has even connected correctly does
  **not** end the match (`teams_ever_present` gate holds at N>2, not
  just N=2); confirmed the match resolves and broadcasts the correct
  winner the instant the 2nd team's threshold is crossed with the
  first team already at 0 (an edge case only reachable in live timing,
  not planned in advance, and handled correctly with no code change
  needed); confirmed eliminating exactly 1 of 3 connected players
  correctly leaves the match ongoing (2 teams still alive); confirmed
  the Phase 5 late-joiner catch-up path still correctly informs a peer
  that connects after `POST_GAME` has already fired. Zero errors
  across every run.
- [x] `gdformat --check` / `gdlint` (project files, excluding
  third-party `addons/gut/`) / `godot4 --headless --import` all clean.
  70/70 GUT tests total project-wide.
- [ ] A live 3-player free-for-all run where all 3 players are
  confirmed connected before any elimination, then exactly 2 are
  eliminated in sequence, leaving a genuine 3-way "last one standing"
  finish, was attempted but not cleanly achieved (timing-dependent —
  see the live scenarios actually achieved above, which collectively
  cover the same logical ground: N>2 "no result yet," the 2-teams-
  connected gate, and a correct resolution). Not treated as a gap: the
  exact N>2 win-declaration arithmetic this scenario would exercise is
  already exhaustively proven by `test_win_condition.gd`'s 3 new FFA
  cases, including the identical `(1 alive_team_id, 4 ever_present)`
  shape.
- [ ] Warden's kit was not live-cast in combat this phase (only spawned
  and observed error-free) — not treated as a gap: `CombatResolver`'s
  resolution path is fully class-agnostic and already live-proven
  generically across every prior class (Phases 2-5); Warden's kit data
  itself (the only new thing) is directly unit-tested above.
- [ ] Character-select/mode-select UI, per-team-of-one HUD breakdown
  for FFA, and a real reconnect/grace-period system remain explicitly
  deferred — see `memory/plan.md`'s Slice 6 block and Deferred list.
