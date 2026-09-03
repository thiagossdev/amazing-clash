# Macro Plan

The architectural design. Updated when direction changes. Vertical slices
only — build full-stack features end-to-end, not horizontal layers
(all DBs, then all APIs, then all UIs).

## Current Phase

**Phase 1: Core + Input + 2D Character Controller + Camera + Networking
skeleton — done and tactically verified 2026-09-02** (see
`memory/verify.md` Slice 1 criteria and `memory/progress.md`).
**Phase 2a (melee combat core) — done and tactically verified
2026-09-02** (see `memory/verify.md`'s Phase 2a section).
**Phase 2b (aimed skillshot/projectile) — done and tactically verified
2026-09-02** (see `memory/verify.md`'s Phase 2b section). **Phase 3
(Ability Framework) is next.** Full design is in
`docs/blueprint/` (start at
`docs/blueprint/README.md`), grounded in
`docs/research/eslabong-inspiration/` and
`docs/research/poe2-build-depth-inspiration/`.

**The pitch**: real-time, one-fighter-per-player PvP arena combat
(aimable skillshots, live positioning/timing), team and free-for-all
modes with a friendly-fire toggle, server-authoritative networking and
combat architecture inherited directly from `amazing-nauts`. The
differentiator is character-build depth aimed at Path of Exile 2's
level of customization, reconciled with live-PvP fairness by splitting
depth by timescale: a persistent, respec-able, account-level
build-investment layer (out of match) feeding a bounded, opponent-
legible loadout draft (in match) — see
`docs/research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md`
for the full reasoning. Not yet confirmed by the human owner; see
`docs/blueprint/05-open-questions.md`. Does not block Phase 1-2, which
exercise networking/combat core with a placeholder character, not the
build-depth system.

**Confirmed 2026-09-02**: presentation is **2D top-down**. The
`3d/physics_engine="Jolt Physics"` line in `project.godot` was template
leftover, not a decision — removed in this phase (see Slice 1 below).

**Roadmap** (6 phases, mirroring `amazing-nauts`' own phase
decomposition for the same server-authoritative architecture — each
phase independently playable/demoable even if the next never lands):

1. Core + Input + 2D Character Controller + Camera + Networking
   skeleton — **done**, detailed in Slice 1 below.
2. Combat core (hit detection — melee **and** aimed skillshot/
   projectile queries — damage pipeline, frame data as Resource, state
   machine) + Hitbox/Projectile Viewer + Debug Overlay pulled forward.
   Split into two independently-mergeable slices: **2a (melee) — done**,
   **2b (aimed skillshot/projectile) — done**.
3. Ability Framework: 2-3 abilities on the placeholder character,
   100% data-driven via Resource; schema leaves room for Eslabong-style
   Evolution/Specialization branches and a minimal loadout-slot model
   without implementing either yet. **Next.**
4. First 2 real classes (melee + ranged skillshot archetypes) replace
   the placeholder character.
5. Match modes: team mode (2v2 default), friendly-fire toggle, win
   condition, minimal lobby/HUD/match flow.
6. 3rd class (support/control archetype) + free-for-all mode —
   completes `docs/blueprint/04-mvp-scope.md`'s MVP criteria.

Post-MVP backlog: `docs/blueprint/06-post-mvp-backlog.md`, not started
until Phase 6 ships.

## Vertical Slices

### Slice 1 (Phase 1): Two clients see each other move in a test arena — DONE

- **Scenes**: `TestArena.tscn` (2D, bounded room with collision,
  top-down), `Character.tscn` (base, no real class yet — a
  `CharacterBody2D` with a placeholder visual), `ArenaCamera.tscn`
  (fixed top-down `Camera2D`, no shake/zoom yet).
- **Autoloads**: `EventBus` (ownerless events only — "match started,"
  not per-entity signals), `MatchState` (`Lobby → CharacterSelect →
  Loading → InProgress → PostGame`, `Reconnect` as an `InProgress`
  sub-state, per `docs/blueprint/03-networking-and-match-modes.md`),
  `NetworkManager` (server-authoritative loop, 60Hz fixed tick, direct
  local-network connect — no matchmaking), `InputManager` (Input
  Abstraction Layer, keyboard/mouse first).
- **Behavior**: minimal locomotion FSM (`Idle`, `Walk`, `Dash` as the
  evasive-movement tool the "move and react" pitch needs); client
  prediction + reconciliation for the local character; interpolation
  for the remote character; a debug overlay showing ping/snapshot rate.
- **Data**: none yet (no Resources needed until Phase 2's frame data).
- **Tests**: GUT coverage for the locomotion FSM's pure logic (state
  transitions, dash cooldown) — the networking loop itself is verified
  tactilely (below), not unit-tested, since it requires 2 real clients.
- **Verify**: 2 clients connect to a local server, both characters
  walk/dash, the local player's movement responds instantly (no
  round-trip wait), the remote player's movement is smooth (no
  perceptible stutter) under up to 100ms artificial latency, and
  reconnecting after a dropped connection works without restarting the
  match. All met — see `memory/verify.md` Task-Specific Criteria,
  Slice 1, for the specific evidence per criterion.

### Slice 2a (Phase 2a): One character lands a melee hit on another — DONE

- **Data**: `data/moves/debug_attack.tres` (`MoveDefinition` +
  `HitDefinition`: startup 6 / active 4 / recovery 10 frames, 10
  damage, 12 hitstun frames, 4 hitstop frames).
- **Behavior**: `ActionFsm` (NEUTRAL/STARTUP/ACTIVE/RECOVERY,
  frame-counted); `HitDetection` (pure hitbox/hurtbox rect geometry,
  outside Godot physics); `DamagePipeline.compute`; `CombatResolver`
  (server-only, per-tick, wired as `TestArena`'s last child so it runs
  after every character's own `_physics_process`); melee aim comes
  from `LocomotionFsm.facing_direction` (last movement direction, not
  mouse-aim — that's Phase 2b's skillshot).
- **Networking**: `ClientPredictor.Checkpoint` and the snapshot
  RPC/`_apply_snapshot` grew to carry action-layer state and health,
  same fields `amazing-nauts`' own Checkpoint/Snapshot grew at this
  exact point in their history.
- **Tests**: `test_action_fsm.gd`, `test_hit_detection.gd`,
  `test_damage_pipeline.gd`, `test_character_controller_combat.gd` —
  22 new GUT tests (44 total).
- **Verify**: a melee attack thrown by one peer lands on the other's
  character, server-authoritatively, applies damage/hitstop/hitstun,
  and replicates the health change to the other peer. All met — see
  `memory/verify.md`'s Phase 2a section for the specific evidence,
  including one real product bug found and fixed this way
  (`PlayerSpawner` spawn-position overlap, `memory/gotchas.md`
  2026-09-02).

### Slice 2b (Phase 2b): One character's skillshot travels and replicates identically to another peer — DONE

- **Data**: `data/moves/debug_skillshot.tres` (`MoveDefinition` +
  `HitDefinition`: startup 8 / active 1 / recovery 14 frames, 15
  damage, 10 hitstun frames, 3 hitstop frames, 20×20 hitbox).
- **Behavior**: `gameplay/projectiles/Projectile` (deterministic
  `position += direction*speed*delta`, 700px/s, 120-frame/2s lifetime,
  non-piercing); `InputManager.get_aim_direction()` (real mouse-aim via
  the viewport's canvas transform); `CombatResolver` launches the
  projectile exactly once, the tick the skillshot cast reaches ACTIVE,
  via one `@rpc("authority","reliable","call_local")` spawn broadcast
  — no per-tick position sync needed since every peer's own local
  instance advances identically.
- **Tests**: `test_projectile.gd` (7 tests), 1 new test in
  `test_hit_detection.gd` for `projectile_hitbox_rect` — 8 new GUT
  tests (52 total).
- **Verify**: server's and client's own local Projectile instances
  tracked identical positions at every checkpoint for the whole flight
  — the deterministic-replication design confirmed live, not just in
  isolated unit tests. All met — see `memory/verify.md`'s Phase 2b
  section for the specific evidence, including why a live coincidental
  hit wasn't forced (redundant given Phase 2a's shared hit-application
  path and GUT's hit-geometry coverage) and one GDScript gotcha found
  and fixed (`memory/gotchas.md` 2026-09-02: `is Type` doesn't narrow a
  loop variable's static type).

## Deferred / Out of Scope

- Matchmaking/dedicated-server infrastructure — Phase 1 targets direct
  local-network connect only.
- The full persistent build-investment layer (unlocks, node tree,
  respec economy) — Phase 3 only seeds the data schema.
- Rollback netcode reconsideration — deferred until Phase 2's real
  entity counts exist to evaluate against.
- Any class/ability content — Phases 1-3 use one placeholder character
  only; real classes start at Phase 4.

## Open Questions

Tracked in full at `docs/blueprint/05-open-questions.md`. Still open,
not blocking Phase 1: exact friendly-fire toggle scope, loadout
cadence, persistent-tree size/gating, setting/tone, monetization.
Resolved this session: presentation is 2D top-down (see above).
