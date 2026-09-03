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

### Debug instrumentation (F1 collision viewer, "/" console)

- [x] `CollisionShapeViewer` starts hidden, F1 toggles it, joins the
  `collision_viewer` group — 3/3 GUT tests
  (`test_collision_shape_viewer.gd`).
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
