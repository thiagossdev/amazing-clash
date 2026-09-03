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
(Ability Framework) — done and tactically verified 2026-09-03** (see
`memory/verify.md`'s Phase 3 section). **Phase 4 (first 2 real
classes) — done and tactically verified 2026-09-03** (see
`memory/verify.md`'s Phase 4 section). **Phase 5 (match modes) is
next.** Full design is in
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
   without implementing either yet. **Done** — see Slice 3 below.
4. First 2 real classes (melee + ranged skillshot archetypes) replace
   the placeholder character. **Done** — see Slice 4 below.
5. Match modes: team mode (2v2 default), friendly-fire toggle, win
   condition, minimal lobby/HUD/match flow. **Next.**
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

### Slice 3 (Phase 3): Two independent, cooldown-gated ability slots (Q/E) on the placeholder character — DONE

- **Data**: new `AbilityResource` (`gameplay/abilities/ability_resource.gd`
  — `ability_name`, `move: MoveDefinition`, `cooldown_frames`,
  `is_projectile`), a thin wrapper reusing Phase 2's
  `MoveDefinition`/`HitDefinition` unchanged. Two test abilities:
  `data/abilities/debug_ability_q.tres` ("Power Strike", melee-style,
  90-frame cooldown, 25 damage) and `debug_ability_e.tres` ("Fireball",
  projectile-style, 150-frame cooldown, 20 damage).
- **Input**: `attack` rebound from J to the **left mouse button**;
  `ability_q`/`ability_e`/`ability_r`/`ability_f`/`ability_t` added on
  Q/E/R/F/T (Path of Exile 2's convention) — **R/F/T are bound in the
  InputMap but not wired to any ability yet**, intentionally (2-3
  abilities was this phase's scope, not 5). `InputBuffer.Sample` grew
  `ability_q_pressed`/`ability_e_pressed`; the 4 press flags (attack,
  skillshot, ability_q, ability_e) now travel over `_rpc_send_input` as
  one packed bitmask int (`InputBuffer.pack_ability_flags`/
  `unpack_ability_flags`) instead of separate bool params, to stay
  under gdlint's function-argument-count cap as slots were added.
- **Behavior**: `CharacterController` gained `ability_q_fsm`/
  `ability_e_fsm` — each its **own** `ActionFsm` instance and **own**
  frame-counted cooldown counter, fully decoupled from the shared
  melee/skillshot `action_fsm` and from each other (pressing Q doesn't
  lock out melee, E, or vice versa; only that slot's own cooldown gates
  it). `_advance_ability_slot()` is the shared cooldown-gating helper
  both slots call through `apply_input()`. Aim direction for a
  projectile-style ability slot (Fireball/E) is captured at the exact
  cast tick via `pending_ability_q_direction`/
  `pending_ability_e_direction`, mirroring `pending_skillshot_direction`'s
  existing anti-retarget-during-windup design.
- **Combat resolution**: `CombatResolver._resolve_attacker` now
  dispatches both ability slots through `_resolve_ability_slot()`,
  which routes to the existing `_resolve_melee()` path (generalized to
  take any `ActionFsm`+`MoveDefinition` pair, not just the base attack)
  or the existing skillshot-launch path (generalized to
  `_maybe_launch_projectile()`, parameterized by a `slot_name` string
  round-tripped through `_rpc_spawn_projectile` so every peer can look
  the caster's own move back up via `_get_move_for_slot()`). No new
  per-slot projectile speed/lifetime — both projectile-capable slots
  (skillshot, and Fireball/E) share `CombatResolver`'s existing
  `PROJECTILE_SPEED`/`PROJECTILE_LIFETIME_FRAMES` constants.
- **Networking**: `ClientPredictor.Checkpoint` grew 6 fields
  (`ability_q_state`/`ability_q_move_frame`/`ability_q_cooldown_frames`,
  same 3 for `ability_e`), captured/restored by
  `_capture_predicted_state`/`_restore_predicted_state` exactly like
  the existing `action_state`/`action_move`/`action_move_frame` fields.
  **Deferred, documented gap**: a remote `INTERPOLATED` peer's Q/E
  `ActionFsm` state is **not** replicated via the snapshot RPC (its
  param count is already at a practical limit) — a remote player's Q/E
  cast won't visually animate on other clients yet. Hit resolution is
  unaffected (already server-only); this is a visual-only gap for a
  later phase to close if/when the snapshot RPC is restructured (e.g.
  a single packed action-state int instead of 3 separate params per
  slot).
- **Tests**: 6 new tests in `test_character_controller_combat.gd`
  (independent-slot activation, no-restart-mid-move, cooldown gating,
  cooldown-elapsed re-cast) — 58 total (was 52).
- **Verify**: live 2-process headless test — server casts melee attack
  (10 dmg), ability_q/Power Strike (25 dmg melee), and ability_e/
  Fireball (projectile spawn), all server-authoritative; the Fireball
  spawn RPC replicated identically to the client (confirming the
  generalized `slot_name`-keyed spawn/lookup mechanism works the same
  way the original hardcoded skillshot path did). See
  `memory/verify.md`'s Phase 3 section for full evidence.

### Slice 4 (Phase 4): Two real, orthogonal classes fight each other in a live match — DONE

- **Data**: 8 new `MoveDefinition` `.tres` files (4 per class) +
  4 new `AbilityResource` `.tres` files (Q/E per class), all authored
  with final, concrete stats (no placeholders):
  - **Vanguard** (melee frontline, `max_health` 120): Quick Slash (LMB,
    8 dmg), Piercing Thrust (RMB skillshot, 12 dmg projectile), Heavy
    Slam (Q, melee, 28 dmg, 150f cooldown), Bulwark Strike (E, melee,
    15 dmg, 100f cooldown) — an all-melee kit plus one projectile poke.
  - **Ranged Mage** (ranged skillshot dealer, `max_health` 80): Arcane
    Jab (LMB, 5 dmg, weak self-defense melee), Arcane Bolt (RMB
    skillshot, 22 dmg projectile, main nuke), Frost Shard (Q,
    projectile, 10 dmg, 70f cooldown, fast poke), Arcane Nova (E,
    projectile, 30 dmg, 180f cooldown, payoff spell) — an all-projectile
    kit past its one melee panic button.
  - Both classes reuse `CombatResolver`'s shared projectile speed/
    lifetime constants (already-documented Phase 3 deferral, not a new
    gap).
- **Scenes**: `gameplay/characters/vanguard/Vanguard.tscn`,
  `gameplay/characters/ranged_mage/RangedMage.tscn` — both instance
  the same unmodified `character_controller.gd`, differing only in
  which move/ability resources and `max_health` they assign, plus a
  distinct `Visual` color for basic on-screen distinguishability.
  `Character.tscn` (the placeholder) is kept, unchanged in role: it's
  now purely the generic GUT test fixture for framework-level tests
  (`test_character_controller_combat.gd`), never spawned in an actual
  match.
- **Behavior/wiring**: `PlayerSpawner.CLASS_SCENES` alternates Vanguard/
  RangedMage by connection order (the same array-cycling pattern
  `SPAWN_POSITIONS` already used) — no lobby or character-select UI;
  that's Phase 5's job. `TestArena.tscn`'s `MultiplayerSpawner.
  _spawnable_scenes` updated to the 2 real class scenes (was
  `Character.tscn`). Mechanical rename alongside this phase's own
  deliverable: `CharacterController.debug_attack_move`/
  `debug_skillshot_move` → `attack_move`/`skillshot_move` (7 files) --
  assigning real class data to a field named "debug_" was actively
  misleading.
- **Tests**: new `test_character_classes.gd` (2 tests) confirms each
  scene's kit is wired correctly (guards against an `ExtResource`
  pointing at the wrong move/ability, not a duplicate of the generic
  cooldown-gating coverage already in `test_character_controller_combat.gd`)
  — 60 total (was 58).
- **Verify**: live 2-process test confirmed peer 1 (server, spawned
  first) got Vanguard and the client peer got Ranged Mage (alternation
  works); Vanguard's Quick Slash (8), Heavy Slam (28), and Bulwark
  Strike (15) all landed with their exact authored damage values,
  server-authoritatively. See `memory/verify.md`'s Phase 4 section.

## Deferred / Out of Scope

- Matchmaking/dedicated-server infrastructure — Phase 1 targets direct
  local-network connect only.
- The full persistent build-investment layer (unlocks, node tree,
  respec economy) — Phase 3 only seeds the data schema.
- Rollback netcode reconsideration — deferred until Phase 2's real
  entity counts exist to evaluate against.
- A 3rd class (support/control archetype) — Phase 6, alongside
  free-for-all mode. Only 2 classes exist after Phase 4 (Vanguard,
  Ranged Mage), both damage-dealer archetypes; no support/control kit
  exists yet.
- Character-select UI / lobby — Phase 4 alternates class by connection
  order only; a real pick screen is Phase 5's "minimal lobby/HUD/match
  flow" item.
- R/F/T keybindings exist in the InputMap (Phase 3) but are not wired
  to any ability — deferred to whichever later phase adds a 3rd+
  ability slot (needs the human owner's decision on how many slots a
  real class kit should have; not decided this session).
- Remote (`INTERPOLATED`) peer visual replication of ability_q/e
  `ActionFsm` state — see Slice 3's networking note above. Needs a
  decision on how to restructure the snapshot RPC (packed state int
  vs. a different sync strategy) before more ability slots make this
  worse.
- Per-ability projectile speed/lifetime — both projectile-capable
  slots currently share one hardcoded speed/lifetime in
  `CombatResolver`; revisit once a real ranged class (Phase 4) needs
  differentiated projectile feel.

## Open Questions

Tracked in full at `docs/blueprint/05-open-questions.md`. Still open,
not blocking Phase 1: exact friendly-fire toggle scope, loadout
cadence, persistent-tree size/gating, setting/tone, monetization.
Resolved this session: presentation is 2D top-down (see above).
