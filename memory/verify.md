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
