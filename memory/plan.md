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
`memory/verify.md`'s Phase 4 section). **Phase 5 (match modes) — done
and tactically verified 2026-09-03** (see `memory/verify.md`'s Phase 5
section). **Phase 6 (3rd class + free-for-all) — done and tactically
verified 2026-09-03** (see `memory/verify.md`'s Phase 6 section). **All
6 roadmap phases are now complete -- this is the MVP per
`docs/blueprint/04-mvp-scope.md`'s roadmap-level criteria** (see
"MVP Status" below for what's genuinely done vs. what the fuller
`docs/blueprint/` MVP proposal still leaves open). Full design is in
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
   condition, minimal lobby/HUD/match flow. **Done** — see Slice 5 below.
6. 3rd class (support/control archetype) + free-for-all mode —
   completes `docs/blueprint/04-mvp-scope.md`'s MVP criteria. **Done**
   — see Slice 6 below.
7. Main Menu + offline character select (no duplicate-class check) +
   direct-IP host/join, replacing `dev_bootstrap.gd`'s flag-only entry
   point with a real UI flow (dev_bootstrap itself stays, unchanged,
   for headless testing). **Done** — see Slice 7 below.
8. Room Config screen: game-mode select (Team/FFA), friendly-fire
   toggle, manual per-player team assignment (no numeric team-size
   selector — size is emergent from how players are placed), ready-
   check, host-only Start. Replaces `PlayerSpawner`'s automatic
   `index % N` class/team cycling with explicit per-peer assignment.
   **Done** — see Slice 8 below.
9. Perk selection inside Room Config: 1 perk per player from a small
   fixed pool (same pool for every class), visible live to the rest of
   the room, applied as a flat stat multiplier at spawn (no
   `DamagePipeline`/`HitDefinition` changes). **Done** — see Slice 9
   below.
10. LAN room discovery: UDP broadcast beacon (host) + listener
    (client), surfaced as a live room list on Slice 7's Join screen,
    manual-IP fallback always available. Isolated as its own slice
    because of real environment risk (WSL2 → LAN broadcast reliability
    was unverified going in). **Done** — see Slice 10 below. The
    roadmap's original Slices 7-10 ("lobby") ask is now fully complete.
11. Lag compensation in `HitDetection`: a short per-character
    position-history buffer (server-only), so a hit resolves against
    where the defender was at the attacker's estimated one-way-latency
    timestamp (from `NetworkManager.get_peer_rtt_ms()`), not their
    live current position, bounded to a max compensation window.
    Closes the gap `docs/research/networking-architecture-inspiration/`
    flagged. **Not started** — scope below.
12. Spawn layout generalized beyond the 4 hardcoded `SPAWN_POSITIONS`
    points to a computed `(team_id, index_within_team, team_count)`
    layout, so a real 5v5 (or any confirmed team-size combination)
    gets a sane arrangement instead of cycling through 4 points.
    **Done** — see Slice 12 below.
13. Reconnect/grace-period system: a mid-match disconnect freezes the
    character in place (vulnerable, not invulnerable -- disconnecting
    has a real cost) for 30s instead of an immediate forfeit; a
    reconnect within that window is authenticated by a per-player
    secret token (issued once, held in the client's own memory, not
    IP-matched) and resumes the same character under the new peer_id.
    Expiring the window falls back to today's behavior (forfeit via
    despawn). **Not started** — scope below.

Post-MVP backlog: `docs/blueprint/06-post-mvp-backlog.md`, not started
until Phase 6 ships (still true for the backlog itself; Phases 7-10
above are pre-existing `memory/progress.md` backlog items now promoted
to scoped roadmap phases, not new post-MVP scope).

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

### Slice 5 (Phase 5): 2v2 team mode, friendly fire, elimination win condition, minimal HUD — DONE

- **Team assignment**: `PlayerSpawner` assigns `team = index % 2`
  (unchanged class-cycling formula alongside it, so the already-
  verified 2-player case is untouched in spirit -- server and the
  first client still land on different teams). `SPAWN_POSITIONS` grew
  from 2 to 4 points: team 0 clusters near x=300, team 1 near x=900,
  teammates 60 units apart on the same y (the 2nd-spawned teammate at
  a *lower* x than the 1st, so a fresh spawn's default rightward
  facing reaches the 1st teammate -- confirmed live, see Verify below).
  Accepted, documented side effect: the base 2-peer test's 2 characters
  (different teams) now start 600 units apart instead of adjacent,
  since enemy teams cluster on opposite sides -- intentional for a
  real 2v2 layout, not a regression (the underlying hit-resolution
  code is unchanged and independently reconfirmed by the friendly-fire
  test below).
- **Friendly fire**: `MatchState.friendly_fire_enabled` (default
  `false`), read every tick by `CombatResolver`'s 2 hit-resolution
  loops (`_resolve_melee`, `_resolve_projectile_hit`) -- a same-team
  hit is skipped unless the flag is true. Decided as a per-match
  server-startup setting (new `net/dev_bootstrap.gd` `--friendly-fire`
  flag), not a live-togglable console command -- who's allowed to
  change a match rule mid-game is a separate authority question, not
  opened here. Resolves `docs/blueprint/05-open-questions.md`'s
  "does the toggle gate all damage or only splash?" question by
  necessity: no splash/AoE ability type exists in this codebase at
  all, so "all damage" is the only mechanically possible reading right
  now.
- **Elimination**: `CharacterController` freezes in place (both
  server-authoritatively and on the owning client, so a dead local
  player doesn't see their own input "work" only to be snapped back)
  once `current_health <= 0`. `CombatResolver._resolve_attacker` also
  refuses to let an eliminated character land a hit.
- **Win condition**: new `gameplay/match/win_condition.gd`
  (`WinCondition`, a pure `RefCounted` static function, unit-tested the
  same way `ActionFsm`/`HitDetection` are) determines NONE/DRAW/a team
  index from each team's alive count and whether both teams have ever
  been observed present (guards against a false "team lost" reading
  during the brief startup window before both teams' first players
  have even connected). New `gameplay/match/match_rules.gd`
  (`MatchRules`, server-only, wired as `TestArena`'s new last child
  after `CombatResolver`) is the thin Node orchestrator: counts each
  team's alive members every tick, calls `WinCondition.determine()`,
  and calls `MatchState.enter_post_game()` on a result. A mid-match
  disconnect of a team's last member resolves as a loss for that team
  (the same "alive count dropped to 0" mechanism as an elimination) --
  intentional, not accidental; a real reconnect/grace-period system is
  out of scope (see Deferred below).
- **Match-state client visibility**: `MatchState` previously never
  reached clients at all (`enter_in_progress()` set a local var with no
  RPC, and nothing client-side read `current_phase` before this phase)
  -- a real, previously-latent gap this phase had to fix to make the
  HUD possible. Both phase-transition methods now broadcast via
  `@rpc`, and a peer connecting after a transition already fired is
  caught up in a new `_on_peer_connected()` handler (mirroring
  `PlayerSpawner`'s own "catch up a late joiner" pattern). New
  `EventBus.team_status_changed` signal + `MatchState.
  team_alive_counts`/`winning_team` are the only client-visible match
  data -- individual characters' `team` assignment is deliberately
  never replicated (server-only, read by `CombatResolver`/`MatchRules`
  alone), keeping the new replication surface to one small aggregate,
  matching the docs' own "Event Bus restricted to ownerless events"
  convention.
- **HUD**: new `ui/hud/match_hud.gd` (a `CanvasLayer`, wired inline in
  `TestArena.tscn` like `NetworkStatsOverlay`, no separate `.tscn`)
  shows live team-alive counts and a "TEAM X WINS"/"DRAW" banner on
  `POST_GAME`, reading only `MatchState`'s new aggregate fields.
- **Tests**: `tests/unit/test_win_condition.gd` (5 tests, pure logic)
  — 65 total (was 60).
- **Verify**: live 2-process test confirmed the full elimination →
  win-condition → RPC broadcast chain reaches the client (`--simulate-
  self-eliminate`, a new permanent dev-testing flag that zeroes a
  peer's own health directly, bypassing hit geometry, so this chain is
  testable deterministically); a live 3-process test confirmed the
  friendly-fire gate correctly blocks a same-team hit by default and
  allows it with `--friendly-fire` (same geometry, only the flag
  differs, ruling out a false-positive from a missed/out-of-range
  attack). See `memory/verify.md`'s Phase 5 section for full evidence.

### Slice 6 (Phase 6): 3rd class (Warden) + free-for-all mode — DONE

- **WinCondition generalized from 2 fixed teams to N teams**: the core
  architectural fact this phase turned on. `determine()`'s signature
  changed from `(team0_alive, team1_alive, team0_ever, team1_ever)` to
  `(alive_team_ids: Array, teams_ever_present: int)` -- team mode is
  now just the N=2 case of "how many distinct teams still have someone
  alive," not a separate code path from free-for-all's N>2 case.
  Re-verified every prior 2-team test case still holds under the new
  signature before adding the N>2 cases (8 tests total, was 5).
  `MatchRules` rewritten from 2 hardcoded locals to a `Dictionary`
  keyed by team id -- same tick-by-tick, change-only-broadcast
  behavior, now team-count-agnostic.
- **Free-for-all mode "just works" once team assignment generalizes**:
  new `MatchState.match_mode` (`TEAM`/`FREE_FOR_ALL`, default `TEAM`,
  set via a new `--free-for-all` `dev_bootstrap` flag, same
  server-startup-only pattern as `--friendly-fire`). `PlayerSpawner`
  assigns `team = index` (unique per player) in FFA instead of
  `index % 2` -- no other code needed a mode branch: `CombatResolver`'s
  friendly-fire check and `MatchRules`/`WinCondition`'s elimination
  logic are completely unchanged and correct under FFA purely because
  every FFA player's team id is unique (a same-team hit can now only
  ever be a self-hit, already excluded upstream).
- **MatchHud made mode-aware**: `team_alive_counts` grew from a fixed
  2-element array to a variable-length one indexed by team id (dense,
  0-filled for any team id with no current members). The HUD reads
  `MatchState.match_mode` to decide whether to show "Team 0: X | Team
  1: Y" or "N players alive," and "TEAM X WINS" vs "PLAYER X WINS."
- **Warden** (support/control, `max_health` 100, between Vanguard's
  120 and Ranged Mage's 80): Guard Poke (LMB, 6 dmg, weak self-defense
  melee), Binding Bolt (RMB skillshot, 8 dmg projectile but 35-frame
  hitstun -- more than 2x Ranged Mage's Arcane Bolt), Stagger Strike
  (Q, melee, 10 dmg, 30-frame hitstun, 80f cooldown -- a frequent CC
  poke), Overwhelm (E, projectile, 15 dmg, 50-frame hitstun -- the
  longest in the game -- 200f cooldown, the longest cooldown in the
  game). Deliberately the lowest-damage class: "control" is expressed
  entirely as an oversized hitstun-to-damage ratio using the existing
  `HitDefinition` vocabulary unchanged -- no heal/shield/buff mechanic
  exists in `DamagePipeline`/`HitDefinition`, and adding one was
  explicitly out of scope for "one more orthogonal class." Third entry
  in `PlayerSpawner.CLASS_SCENES`; the 2-vs-3 modulus mismatch with
  team assignment's own `index % 2` is intentional (team composition
  varies instead of every team getting an identical class pairing).
- **Tests**: `test_win_condition.gd` regenerated for the new signature
  plus 3 new FFA cases (8 total, was 5); 2 new tests in
  `test_character_classes.gd` (Warden's kit wiring, and an explicit
  assertion that Warden's E has strictly more hitstun than either
  other class's E, so a future balance pass can't silently erode the
  archetype's reason to exist) -- 70 total project-wide (was 65).
- **Verify**: live 3-process team-mode test confirmed team (index % 2)
  and class (index % 3) assignment remain independently correct with
  a 3rd class scene added. Multiple live free-for-all scenarios (2 and
  3 real connections, various elimination orders) confirmed unique
  per-player team assignment, correct "must have >=2 teams ever
  connected" gating interacting correctly with an elimination that
  happens before the 2nd player even joins, and the win RPC reaching
  a client that joined after the match had already ended (the Phase 5
  late-joiner catch-up path, confirmed still correct here). See
  `memory/verify.md`'s Phase 6 section for full evidence.

### Slice 7 (Phase 7): Main Menu -> Character Select -> Host/Join -> Lobby -> in-game — DONE

- **Flow order** (deliberately different from `docs/blueprint/03`'s
  original Lobby→CharacterSelect ordering, now corrected there too):
  Main Menu → Character Select (**local, pre-connection, no
  duplicate-class check** — two players may pick the same class) →
  Host (direct IP) or Join (direct IP; LAN room list is Slice 10) →
  Lobby (waiting room: connected players + their chosen class,
  host-only Start) → in-game.
- **Scenes/scripts**: `ui/main_menu/`, `ui/character_select/`,
  `ui/host_join/`, `ui/lobby/` — each a thin `Control` root, no
  separate scene-flow autoload (each screen calls
  `get_tree().change_scene_to_file()` directly). New
  `net/lobby_state.gd` (server-authoritative `Dictionary` keyed by
  `peer_id` → `class_id`, broadcast to all peers on every change, same
  RPC pattern as `MatchState.team_alive_counts`); `PlayerSpawner` reads
  this instead of auto-cycling `index % N`, falling back to the old
  cycling behavior for any unregistered peer (keeps
  `net/dev_bootstrap.gd`'s headless peers, which never register,
  working unchanged). `project.godot`'s `run/main_scene` is now
  `MainMenu.tscn` (was `TestArena.tscn`).
- **`MatchState.Phase` change, corrected mid-implementation**: the
  original `/think` plan dropped both `CHARACTER_SELECT` and `LOADING`
  down to `{LOBBY, IN_PROGRESS, POST_GAME}`. The human owner caught
  this before merge and had `LOADING` restored (`CHARACTER_SELECT`
  stays dropped — that part of the reasoning held): a real handshake
  was needed, not a placeholder. Final enum: `{LOBBY, LOADING,
  IN_PROGRESS, POST_GAME}`. `enter_loading()` broadcasts LOADING; every
  peer scene-changes to `TestArena.tscn`; each peer's own
  `net/loading_reporter.gd` (TestArena's last child, same _ready()-
  ordering guarantee `MatchRules` already relies on) reports back once
  its own tree is genuinely built; the server only calls
  `enter_in_progress()` once every currently-connected peer has
  reported.
- **2 real races found and fixed live**, not caught by GUT (both
  require 2 real processes to reproduce):
  1. `PlayerSpawner` used to spawn unconditionally at `_ready()`. A
     scene change is asynchronous per-peer with no cross-process
     synchronization, so the server's own tree could finish (and start
     replicating spawned characters) before a remote peer's own
     `TestArena/MultiplayerSpawner` existed yet — "Node not found:
     TestArena/MultiplayerSpawner" on the client, confirmed live. Fixed
     by gating all spawning on `MatchState.current_phase ==
     IN_PROGRESS` (which the LOADING handshake above only reaches once
     safe), except when it's already `IN_PROGRESS` at `_ready()` time
     (dev_bootstrap's direct-connect flow, unaffected).
  2. `net/loading_reporter.gd` reporting unconditionally raced
     `dev_bootstrap.gd`'s own client flow: its `--join` peer's
     `LoadingReporter._ready()` could fire before that peer's own ENet
     handshake had actually finished, producing "Trying to call an RPC
     via a multiplayer peer which is not connected." Fixed by only
     reporting when `current_phase == LOADING` (always true for the
     real Lobby-driven flow by causality; never true for
     dev_bootstrap's flow, which skips LOADING entirely).
  3. (Test-harness only, not a product bug) The live 2-process test's
     first `--dev-autostart` attempt used a fixed 1s timer, which
     proved unreliable across 2 independently-launched OS processes
     with no shared clock — fixed by polling `LobbyState.player_class_
     ids.size() >= 2` (bounded to ~10s) instead of guessing a delay.
- **Tests**: `tests/unit/test_lobby_state.gd` (5 tests, pure
  `resolve_class_id()`/`get_class_id()` logic — the Node/RPC parts are
  tactically verified instead, matching this project's own convention)
  — 75 total project-wide (was 70).
- **Verify**: live 2-process test confirmed the full Main Menu →
  Character Select → Host/Join → Lobby → in-game flow end-to-end with
  each peer spawning as the class it actually chose (not the old
  auto-alternation), zero engine errors on either peer. Live-reran
  `dev_bootstrap.gd`'s own pre-existing headless flow (now needs the
  scene passed explicitly: `godot4 --headless --path .
  res://maps/test_arena/TestArena.tscn -- --server ...`, since it's no
  longer the main scene) and confirmed it's still clean and unchanged
  in behavior. See `memory/verify.md`'s Phase 7 section for full
  evidence.
- **Known gaps, deferred on purpose, not silently dropped**:
  - **Visual verification**: this project has never had a way to
    screenshot Godot's actual renderer (`memory/verify.md` flags this
    at every UI-adjacent phase so far — `playwright-capture.sh` is
    web-only). Slice 7 adds the project's first real menu screens with
    no way to visually confirm them beyond live functional testing +
    code reading. Not solved here; carried forward as an explicit gap,
    same as every prior phase.
  - A peer connecting mid-LOADING (rather than already being in the
    Lobby when Start is pressed) has no explicit catch-up RPC for
    LOADING itself — unlikely in this project's direct-connect,
    small-player-count flow, not worth the extra bookkeeping yet.
  - Double-clicking "Join" while a previous attempt is still pending
    isn't guarded against — an untested edge case, not a known bug.

### Slice 8 (Phase 8): Room Config — mode, friendly fire, manual teams, ready, Start — DONE

- **Scope built as designed, with one correction applied mid-Phase-9**:
  host-only mode dropdown (Team/FFA) and friendly-fire checkbox in
  `ui/lobby/` (evolved from Phase 7's minimal waiting room, not a
  competing new screen); a per-row "Switch Team" button (Team mode
  only) rather than 2 drag-target columns — same outcome ("everyone
  sees who's on which team"), far less UI machinery; a ready checkbox
  per non-host player; a host-only Start button. No numeric team-size
  selector, as planned — size is just how many players ended up in
  each team. **Correction (2026-09-03, applied on the Phase 9
  branch)**: "Switch Team" originally shipped host-only (the host
  clicking any row's button moved *that* player) — the human owner
  caught this as a real authority error partway through Phase 9. Team
  choice is self-service: each peer's button only appears/works on
  their own row, and the server-side RPC operates on
  `multiplayer.get_remote_sender_id()` (never a client-supplied peer
  id), the same trust pattern `_rpc_register` already used for class
  choice — removes the need for a host-authority check on this RPC
  entirely rather than adding one. See `memory/gotchas.md` 2026-09-03.
- **`net/lobby_state.gd` grew in place** (not a parallel registry, as
  planned): `player_team_ids`, `player_ready`, `room_match_mode`,
  `room_friendly_fire` added alongside the existing `player_class_ids`;
  the old `registry_changed` signal/`_rpc_receive_registry` RPC were
  renamed to `room_state_changed`/`_rpc_receive_room_state` to match
  what the node now actually holds (one full-state broadcast, not
  delta, same reasoning as Phase 7's class registry). `perk_id` is
  deliberately not added yet — that's Slice 9's job.
- **`PlayerSpawner._resolve_team_id()`**: Team mode now prefers a
  peer's manually-assigned `LobbyState` team, falling back to the
  original `index % 2` for an unregistered (headless
  `dev_bootstrap.gd`) peer, mirroring Phase 7's own class-registry
  fallback pattern exactly. FFA is untouched.
- **2 real bugs found by `/check` and fixed before merge** (not
  theoretical — see `memory/gotchas.md` 2026-09-03 for both):
  1. `MatchState.match_mode` was never replicated to clients, only
     ever implicitly agreeing across peers because every process used
     to derive it from the same static `dev_bootstrap.gd` CLI flag
     before anyone connected. Room Config broke that hidden
     assumption (only the host's own copy got set when Start was
     pressed). Fixed by carrying `mode` explicitly through
     `enter_loading()`/`enter_in_progress()`/`enter_post_game()` and
     their RPCs, including the existing late-joiner catch-up path.
     Confirmed live: a client's own local `match_mode` now matches an
     FFA match the host chose (previously stuck at the `TEAM`
     default).
  2. The new manual "Switch Team" control let every connected peer
     land on the same team, permanently soft-locking a Team-mode match
     (`WinCondition`'s `teams_ever_present >= 2` guard never resolves
     a winner otherwise — the match hangs in `IN_PROGRESS` forever).
     New `LobbyState.has_valid_team_split()` (pure, GUT-tested) blocks
     Start in that configuration; trivially true under 2 players, so
     it never blocks the pre-existing solo-host testing convenience.
  3. (Test-harness only) `--dev-switch-team=<id>` assumed a small,
     predictable ENet peer id; ids are effectively random 32-bit
     values. Changed to `--dev-switch-team` (no id): polls for the
     first registered non-host peer and flips it, same bounded-wait
     shape the existing autostart hook already uses.
- **Tests**: 9 new GUT tests in `test_lobby_state.gd` (team/ready pure
  logic, `has_valid_team_split()`) — 86 total project-wide (was 77).
- **Verify**: 3 real 2-process live scenarios (temporary `FileAccess`
  trace instrumentation, removed before the final commit): default
  team alternation + a host-issued manual switch (both peers correctly
  ended on the same team); Start correctly disabled while a non-host
  peer isn't ready, enabled once it is; host-chosen FFA mode +
  friendly-fire both reaching the real match and the real spawn. A
  4th live run specifically re-confirmed the `match_mode`-replication
  fix on the client's own process (not just the host's). See
  `memory/verify.md`'s Phase 8 section for the full trace evidence.
  `has_valid_team_split()`'s integration into the Start button's
  gating was verified by code inspection + its own GUT coverage, not a
  fresh live run — simple enough host-side boolean wiring on top of
  already-tested pure logic that a 5th live cycle wasn't worth the
  time, unlike the `match_mode` fix, which specifically needed a real
  2nd process to prove (a client's own local state, not observable
  from the host's side at all).
- **Known gaps, deferred on purpose**: same visual-verification gap as
  every prior UI-adjacent phase (still no way to screenshot Godot's
  real renderer in this environment). The disabled Start button gives
  the host no explanation of *why* it's disabled (not-ready vs.
  invalid team split) — a label/tooltip would be a small, cheap
  follow-up, not done here since it wasn't asked for and doesn't block
  correctness.

### Slice 9 (Phase 9): 1 self-service perk per player, visible to the room — DONE

- **Scope built exactly as designed**: `gameplay/perks/perk_resource.gd`
  (`Resource`: `perk_name`, `max_health_multiplier`,
  `move_speed_multiplier`, `cooldown_multiplier`, all default `1.0`) +
  4 `.tres` files in `data/perks/` with the confirmed starting values
  (Vitality +15% max health, Swift +10% move speed, Adept -10% all
  ability cooldowns, Balanced +7% max health/+5% move speed).
  `net/lobby_state.gd` grew `player_perk_ids` + `PERK_IDS`/
  `PERK_RESOURCES` alongside the existing per-peer fields, same
  broadcast-the-whole-registry shape as class/team. Perk pick in
  `ui/lobby/`'s Room Config is self-service from the start (unlike
  team, which needed a mid-phase correction — see Slice 8 above): a
  dropdown per player, each peer's own row only, visible to everyone.
- **Where the multiplier actually applies, and why it moved**: not
  `PlayerSpawner` (where it was first written) — a real bug, caught by
  `/check`, moved it to
  `CharacterController._apply_perk_from_lobby_state()`, called from
  every peer's own `_ready()`. `PlayerSpawner`'s server-side spawn call
  only ever produces the AUTHORITATIVE copy of a character; each
  client's own PREDICTED/INTERPOLATED copies are separate node
  instances spawned by `MultiplayerSpawner`'s own replication, which
  never runs `PlayerSpawner`'s code at all. A multiplier set only in
  `PlayerSpawner` therefore silently never reached the very peer who
  picked the perk (or any remote observer) — it would have looked like
  perks did nothing for movement speed or cooldown outside the host's
  own server-side simulation. Reading `LobbyState` directly from
  `CharacterController._ready()` (already-replicated data, no new RPC
  needed) fixes this structurally: every peer computes the same
  multiplier from the same source, independent of which node spawned
  it.
- **Tests**: `test_apply_perk_from_lobby_state_scales_stats_on_ready`
  (regression test for the bug above) plus pure `resolve_perk_id()`/
  `get_perk_id()` coverage in `test_lobby_state.gd` and a
  `move_speed_multiplier` case in `test_locomotion_fsm.gd` — 103 total
  project-wide (was 86).
- **Post-review cleanup**: `resolve_class_id()`/`resolve_perk_id()`
  shared identical validate-or-default logic — extracted into a shared
  private `_resolve_id()` helper so a future validation-rule change
  only needs to happen once. `locomotion_fsm.gd`'s
  `move_speed_multiplier` doc comment still pointed at
  `net/player_spawner.gd` after the fix above moved application
  elsewhere; corrected.
- **Verify**: live 2-process test (temporary `print()` trace, removed
  before the final commit, same convention as Phase 8's own): host
  (Vanguard + Vitality) and client (Ranged Mage + Swift) both connect,
  pick their perk, ready up, host starts. Confirmed correct math (120
  base HP × 1.15 = 138) and, critically, **identical values logged on
  both the server's and the client's own process** for both
  characters — proof the fix (apply per-peer, not per-spawn-call)
  actually holds across a real network boundary, not just in a single
  process. See `memory/verify.md`'s Phase 9 section for the full
  trace.
- **Known gaps, deferred on purpose**: same visual-verification gap as
  every prior UI-adjacent phase (still no way to screenshot Godot's
  real renderer in this environment).

### Slice 10 (Phase 10): LAN room discovery — DONE

- **Scope built exactly as designed**: new autoload `net/lan_discovery.gd`
  (`LanDiscovery`), entirely separate from `net/network_manager.gd`'s
  ENet gameplay connection (port 7777) -- its own fixed UDP broadcast
  port (7778), never carrying gameplay data. Host side
  (`start_advertising()`) sends `{player_count, max_players}` every 1s
  via `PacketPeerUDP.set_broadcast_enabled(true)`/
  `set_dest_address("255.255.255.255", 7778)`; client side
  (`start_listening()`) binds 7778, tracks `discovered_rooms` keyed by
  the sender's actual IP (`PacketPeerUDP.get_packet_ip()`, never
  trusted from the payload), prunes any room not re-announced within
  3s. `ui/host_join/`'s `HostJoin.tscn` gained a `LanRoomsList`
  (double-click to join, real IP stored as item metadata); listening
  starts on `_ready()`, stops once the player commits to hosting or
  joining; advertising starts right after a successful `host()`, stops
  the moment Room Config's host presses Start
  (`ui/lobby/lobby.gd`'s `_on_start_pressed()`) -- a room nobody can
  join anymore has no reason to keep broadcasting. Manual IP entry is
  completely unchanged and always available.
- **The real environment risk flagged going in did not materialize**:
  UDP broadcast reliability inside this dev environment's WSL2 network
  path was the one unverified assumption in the original design pass.
  Live testing confirmed broadcast traffic *does* cross between 2
  separate OS processes here -- not guaranteed to hold on every real
  router/Wi-Fi configuration a player might actually be on (AP
  isolation, some other WSL2↔Windows-host setups), which is exactly
  why manual IP entry was never removed as the guaranteed fallback.
- **3 real issues found by `/check` and fixed before merge** (see
  `memory/gotchas.md` 2026-09-03 for the first):
  1. `PacketPeerUDP.bind()` has no `SO_REUSEPORT` option in Godot's
     GDScript API, so 2 processes on the *same machine* (this
     project's own local-verification convention, see
     `memory/verify.md`) both calling `start_listening()` could
     genuinely race for `DISCOVERY_PORT` -- never a concern for 2 real
     players, always on separate machines with separate network
     stacks. Mitigated (not eliminated -- the API has no clean fix) by
     releasing the host's own listen-bind as the very first action in
     `_on_host_pressed()`, before anything else, minimizing the window
     to effectively zero for realistic test timing. Documented as a
     known, narrow, test-environment-only limitation rather than
     engineered away.
  2. `_await_and_join_discovered_room()` (the headless dev-test hook)
     silently returned on timeout with no status update, unlike every
     other failure path in the same file -- fixed with a status label
     message, per `CLAUDE.md`'s "no silent fallbacks" rule.
  3. `stop_advertising()` nulled its socket without calling `.close()`
     first, inconsistent with `stop_listening()`'s already-explicit
     close -- fixed for deterministic release.
- **Tests**: `test_lan_discovery.gd` (8 new GUT tests) covers
  `parse_announcement()` (well-formed payload, non-Dictionary, missing
  fields, wrong field types, garbage bytes -- untrusted network input,
  not just a malformed edge case) and `prune_stale_rooms()` (keeps
  recent, drops expired, mixed) purely, with no real socket needed --
  111 total project-wide (was 103).
- **Verify**: live 2-process test (`--dev-autoplay --dev-class=<id>
  --dev-host --dev-autostart` / `--dev-autoplay --dev-class=<id>
  --dev-join-discovered --dev-ready`, temporary `print()` trace
  removed before the final commit) confirmed the full pipeline twice
  (once before the `/check` fixes, once after, to prove they didn't
  regress it): host broadcasts, client receives and parses a
  well-formed announcement, client joins via the *discovered* IP (not
  a hardcoded one), zero engine errors either run. `--dev-join=<ip>`
  (direct IP, unaffected by this phase) continues to work exactly as
  Phase 7 left it. See `memory/verify.md`'s Phase 10 section for the
  full trace.
- **Known gaps, deferred on purpose**: same visual-verification gap as
  every prior UI-adjacent phase. Broadcast reliability across a real
  multi-machine LAN (a physical router, real Wi-Fi) was never tested
  -- out of reach of this environment; only same-machine 2-process
  headless testing was possible, which is a real but narrower proof
  than "works on the human owner's actual network." No room name/
  naming UI exists (not asked for) -- rooms are listed by IP and
  player count only.
- Same visual-verification gap as Slices 7-9 above.

### Slice 11 (Lag Compensation) — NOT STARTED

Confirmed by the human owner 2026-09-03 (no real fork of approach --
the single reasonable shape, already researched in
`docs/research/networking-architecture-inspiration/`):

- Server-only, per-character position-history ring buffer (~20 ticks,
  ~333ms @60Hz), appended every `_physics_step_authoritative` tick.
- `HitDetection` gains a pure lookup function: given a history buffer
  and a target tick, return the position at-or-before that tick (GUT-
  testable without a live character/network).
- `CombatResolver._resolve_melee`/`_resolve_projectile_hit` resolve
  against the defender's *compensated* position (rewound by the
  attacker's estimated one-way latency, `NetworkManager.
  get_peer_rtt_ms(attacker_peer_id) / 2`, converted to a tick count),
  not `defender.global_position` live -- bounded to a max compensation
  window (~200ms / 12 ticks) so a very high-latency attacker can't
  reach arbitrarily far into the past.
- No client-visible change: this only affects what the server accepts
  as a hit, not movement/prediction.

### Slice 12 (Spawn Layout Generalization) — DONE

- **Built exactly as scoped**: `net/player_spawner.gd`'s hardcoded
  4-point `SPAWN_POSITIONS` replaced by `_spawn_position_for(team_id)`.
  Team mode: team 0 clusters at x=300, team 1 at x=900 (unchanged x
  values from the original layout), members stacked vertically
  `TEAM_MEMBER_SPACING` (60) apart around arena-center height via a
  new per-team counter (`_next_index_for_team`, keyed by team id) --
  unbounded in code, comfortably inside the arena's safe interior for
  every confirmed team size (2v2 through 5v5). Free-for-all: each
  uniquely-teamed player placed on a fixed circle
  (`FFA_SPAWN_RADIUS` 300 around `ARENA_CENTER`), `FFA_SPAWN_SLOTS` (8)
  evenly-spaced angles, cycling for a 9th+ player rather than erroring
  -- same "never error" guarantee the original 4-point layout had.
  `_resolve_team_id()`/class assignment untouched, as scoped.
- **Tests**: new `tests/unit/test_player_spawner.gd` (4 tests) --
  `PlayerSpawner` is a `Node` but `_spawn_position_for()` and its 2
  helpers touch no scene tree, only the `MatchState` autoload, so it's
  instantiated directly via `.new()` + `autofree()` (same "pure logic
  gets a GUT test" convention as `WinCondition`/`LobbyState`), with
  `MatchState.match_mode` saved/restored around the FFA-mode tests so
  they can't leak into any other test file. 121 total GUT tests
  project-wide (was 117). Written TDD-first: confirmed the tests
  failed with a real parse error (`_spawn_position_for()` didn't exist
  yet) before implementing.
- **Verify**: `gdformat`/`gdlint` clean. 2 live multi-process headless
  runs (3 processes each): team mode (2 on team 0 via the default
  `index % 2` alternation, 1 on team 1 -- exercises the new per-team
  stacking) and free-for-all (`--free-for-all`), both zero engine
  errors on every process.

### Slice 13 (Reconnect / Grace-Period) — NOT STARTED

Confirmed by the human owner 2026-09-03 (3 real forks resolved):

- **Identity across a peer_id change**: a per-player secret token,
  issued once (at `LobbyState` registration / Room Config time) and
  held only in that client's own memory (lost on a full quit, not
  IP-matched) -- not a persistent account system, scoped to "the same
  running client instance reconnecting after a network drop."
- **Vulnerability during the grace period**: the disconnected
  character freezes in place but stays **vulnerable** -- disconnecting
  has a real cost, it is not a safe refuge. Same freeze mechanism
  `apply_lock()`-adjacent code already uses for hitstop/elimination.
- **Grace period**: 30 seconds. Expiring it without a matching
  reconnect falls back to today's behavior exactly (`PlayerSpawner.
  _despawn_for_peer()`, read by `MatchRules` as that team's alive
  count dropping, per its own already-correct `_ever_present_teams`
  logic -- unchanged).
- `core/match_state.gd` gains the `Reconnect` sub-state the original
  blueprint (`docs/blueprint/03-networking-and-match-modes.md`)
  described but never built, now finally motivated by a real
  mechanism instead of a placeholder enum value.
- `PlayerSpawner` no longer despawns immediately on `peer_disconnected`
  -- it starts a 30s grace timer for that peer's character instead,
  despawning only if it elapses unclaimed. A reconnecting peer
  presents its token via a new RPC before/during Host-Join; if it
  matches an active grace-period slot, that character is rebound to
  the new peer_id (name change + control handoff) instead of a fresh
  spawn through the normal Room Config flow.
- `MatchHud`/Room Config need some minimal "player X disconnected,
  reconnecting..." indicator -- exact presentation not specified
  further than that it must exist, implementation detail for the
  phase itself to decide.

## MVP Status

All 10 roadmap phases are complete. Phases 1-6 (networking skeleton,
melee + skillshot combat core, the ability framework, 2 real classes,
2v2 team mode with a friendly-fire toggle and an elimination win
condition, and a 3rd class + free-for-all mode) shipped 2026-09-03
morning. Phases 7-10 (Main Menu, offline character select, direct-IP
and LAN-discovered host/join, a full Room Config screen with manual
team assignment/friendly-fire/mode select/ready-check, 1 self-service
perk per player, and LAN room discovery) shipped the same day,
designed via `/think` and executed via the `ship-phase` skill
(`.claude/skills/ship-phase/SKILL.md`). A real player (or 2+ headless
processes for local verification) now goes Main Menu → pick a
character → host or discover-and-join a room → configure team/mode/
friendly-fire/perk in Room Config → fight, with server-authoritative
hit resolution in either team or free-for-all mode, reaching a clear
win/draw result reflected in a minimal HUD.

This satisfies the roadmap's own phase-by-phase criteria in full,
including the lobby/character-select flow the original 6-phase MVP
status note above used to flag as missing. What's still narrower than
the fuller MVP proposal in `docs/blueprint/04-mvp-scope.md`: the
persistent, respec-able build-investment layer (Phase 3 only seeded
the data schema) and the bounded pre-match loadout draft it would
feed -- confirmed in scope (small, per-character, currency-gated, see
`docs/blueprint/05-open-questions.md`) but not built. This is now the
single biggest gap between "roadmap done" and the fuller MVP proposal.

## Deferred / Out of Scope

- Matchmaking/dedicated-server infrastructure — Phase 1 targets direct
  local-network connect only.
- The full persistent build-investment layer (unlocks, node tree,
  respec economy) — Phase 3 only seeds the data schema. This is the
  single biggest gap between "roadmap done" and the fuller MVP
  proposal in `docs/blueprint/04-mvp-scope.md` (see MVP Status above).
- Per-team-of-one HUD breakdown for free-for-all — `MatchHud` shows a
  single "N players alive" line instead; a per-player list (names,
  individual health bars) needs a display-name system that doesn't
  exist yet.
- A reconnect/grace-period system for a mid-match disconnect — a
  disconnect currently resolves as an immediate forfeit for that
  team (see Slice 5 above), matching the docs' own "online matches
  should not pause" principle, but a real reconnect window (per
  `docs/blueprint/03-networking-and-match-modes.md`'s own "Reconnect"
  sub-state) is unbuilt.
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

Tracked in full at `docs/blueprint/05-open-questions.md`. Still
genuinely open: **monetization** (deliberately deferred, not decided).
Resolved this session (2026-09-03): presentation is 2D top-down;
friendly-fire toggle scope (gates all damage, since no splash/AoE
ability type exists to distinguish); team size is **configurable, 2v2
through 5v5** (not fixed at 2v2 — generalizing `PlayerSpawner`'s
current fixed `index % 2` split is a backlog item, see
`memory/progress.md`); rollback netcode — **confirmed staying
server-authoritative**, grounded in deeper research (see
`docs/research/networking-architecture-inspiration/`); loadout cadence
— **confirmed adjustable between rounds/rematches** (Battlerite
Rites-style), which needs a "round" concept this project doesn't have
yet (backlog item); persistent build-layer — **confirmed small in
scope, per-character, currency-gated** (not PoE2 scale) (backlog item);
setting/tone — **confirmed medieval fantasy, Eslabong-style**.
