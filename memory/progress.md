# Atomic Progress Log

Your temporal anchor. Tick atomic tasks as you complete them. Never mark a
task done unless `memory/verify.md` criteria are met.

The `state-enforcement.sh` hook blocks task completion if source files
changed but this file wasn't updated.

## In Progress

- [ ] <!-- current atomic task — only one at a time -->

## Completed (this session)

- [x] Copy GUT test infra from amazing-dungeons — `addons/gut/` (9.7.1),
  `.gutconfig.json`, `.gdlintrc`, `.markdownlint-cli2.jsonc`, real
  `agent-md.toml`, `memory/.gdignore`, empty `tests/unit/`; verified by
  running `godot4 --headless --import` then
  `godot4 --headless -s addons/gut/gut_cmdln.gd` (GUT loaded config, no
  tests found, no errors).
- [x] Mirror amazing-dungeons `.git/info/exclude` Claude-runtime ignore
  patterns into amazing-clash's local git config.
- [x] Fix pre-existing markdownlint failures surfaced by the newly-copied
  `.markdownlint-cli2.jsonc` (MD060 compact table style in `CLAUDE.md`/
  `AGENT.md` line 266, MD032 missing blank line in `memory/gotchas.md`).
- [x] Deep research (2026-09-02): built `docs/research/eslabong-inspiration/`
  (Eslabong, the human owner's named primary inspiration, plus Battlerite
  as the live-PvP precedent Eslabong itself doesn't ship) and
  `docs/research/poe2-build-depth-inspiration/` (Path of Exile 2's shared
  passive tree, skill-gem design, weapon-swap specialization,
  itemization), each with a numbered topic set, a synthesis file, a
  sources.md, and a README index — verified `npx markdownlint-cli2
  "docs/**/*.md"` clean and all relative cross-links (including the
  ones into `../../../amazing-nauts/` and `../../../../amazing-dungeons/`)
  resolve on disk.
- [x] Wrote `docs/blueprint/` (lean, 6 files + README, matching
  amazing-dungeons' pre-code pattern): executive summary, confirmed
  mechanics, networking/match-modes (server-authoritative model +
  frame-data-as-Resource + custom hit detection, all inherited from
  amazing-nauts), MVP scope, open questions, post-MVP backlog. Central
  proposal, not yet owner-confirmed: build depth split into a
  persistent account-level layer (PoE2-style tree/specialization) and a
  bounded pre-match loadout draft (Battlerite-style, opponent-legible),
  so PoE2-level customization doesn't break live-PvP fairness.
- [x] Confirmed 2D top-down presentation with the human owner; removed
  `3d/physics_engine="Jolt Physics"` template leftover from
  `project.godot`.
- [x] **Phase 1 (Slice 1) implemented and tactically verified**: core/
  (`EventBus`, `MatchState`), input/ (`InputManager`, `InputBuffer`),
  net/ (`NetworkManager`, `ServerSim`, `ClientPredictor`,
  `CharacterSnapshot`, `PlayerSpawner`, `DevBootstrap`),
  gameplay/characters/character_base/ (`LocomotionFsm`,
  `CharacterController` + `Character.tscn`), camera/ (`ArenaCamera`),
  ui/hud/ (`NetworkStatsOverlay`), maps/test_arena/ (`TestArena.tscn`),
  autoloads + WASD/dash input map registered in `project.godot`.
  Server-authoritative networking pattern (control modes, client
  prediction/reconciliation, snapshot interpolation) adapted from
  `amazing-nauts`' own working implementation, scoped down to Phase 1's
  locomotion-only surface (no combat/health/team/abilities yet).
  All `memory/verify.md` Slice 1 criteria met — see that file for the
  specific evidence per criterion (10/10 GUT tests; 4 separate live
  2-process headless test scenarios: walk, dash, 50ms artificial
  latency, disconnect/reconnect; one real bug found and fixed via that
  testing, see `memory/gotchas.md` 2026-09-02). `gdformat`/`gdlint`
  clean.
- [x] Reviewed the Phase 1 diff (`/waza:check`): found and fixed one
  real HIGH-severity issue — `LocomotionFsm.advance()` trusted an
  unclamped `move_vector` straight off the `any_peer` `_rpc_send_input`
  RPC, letting a modified client claim a vector longer than 1.0 and
  speed-hack past `MOVE_SPEED` on the authoritative simulation itself.
  Fixed with `.limit_length(1.0)`, covered by a regression test. Landed
  via 4 wave commits + `git merge --no-ff` into `main` (local only, not
  pushed).
- [x] Debug instrumentation, copied from `amazing-nauts`' own tooling
  and scoped to what Phase 1 actually has: F1 toggles a new
  `CollisionShapeViewer` (`ui/debug/`, draws each character's
  `CollisionShape2D` circle and the arena walls' rects — the honest
  Phase-1 analog of nauts' combat-focused Hitbox Viewer, to be
  expanded/renamed once Phase 2 ships real hit detection); "/" opens a
  typed command console on `NetworkStatsOverlay` (`/help`, `/latency
  <ms>`, `/collision`), console open/close/echo-safe input handling
  copied near-verbatim from nauts' own already-tested implementation.
  Caught and fixed one real bug while writing the behavioral tests
  (not just the parse-logic ones): `project.godot` had no explicit
  `ui_cancel` binding, so it fell back to Godot's engine default, which
  didn't match a `physical_keycode`-based synthetic test event the way
  every other action in this project's InputMap already does — added
  an explicit `ui_cancel` binding matching nauts' own. 22/22 GUT tests
  pass; live 2-process network smoke test still clean after all of the
  above.
- [x] **Phase 2a (melee combat core) implemented and tactically
  verified**: `gameplay/combat/` (`MoveDefinition`, `HitDefinition`,
  `HitDetection`, `DamagePipeline`, `state_machine/ActionFsm`,
  `CombatResolver`), `data/moves/debug_attack.tres` (one test move),
  `LocomotionFsm.facing_direction` (melee's aim source — real mouse-aim
  is Phase 2b's skillshot, not this). `CharacterController` gained
  `action_fsm`, health, `take_damage`/`apply_lock`; `ClientPredictor.
  Checkpoint` and the snapshot RPC grew to carry action-layer state and
  health, mirroring exactly where `amazing-nauts`' own Checkpoint/
  Snapshot grew at this same point in their history. Renamed
  `CollisionShapeViewer` → `HitboxViewer` now that it draws real
  combat hitboxes/hurtboxes, not just movement-collision shapes.
  22 new GUT tests (44 total project-wide), all passing; live
  2-process test confirmed a melee hit lands, applies damage/hitstop/
  hitstun, and replicates correctly to the other peer — see
  `memory/verify.md`'s Phase 2a section for the full evidence,
  including one real product bug found and fixed this way
  (`PlayerSpawner` spawning every peer at an identical position, see
  `memory/gotchas.md` 2026-09-02).
- [x] **Phase 2b (aimed skillshot/projectile combat) implemented and
  tactically verified**: `gameplay/projectiles/` (`Projectile`,
  deterministic `position += direction*speed*delta`, one spawn RPC, no
  per-tick sync), `HitDetection.projectile_hitbox_rect`,
  `InputManager.get_aim_direction()` (real mouse-aim via the viewport's
  canvas transform, since `InputManager` is a plain Node autoload, not
  a CanvasItem), `data/moves/debug_skillshot.tres`, a `skillshot` input
  action (right mouse button), `CombatResolver` extended to launch a
  projectile exactly once (the tick a skillshot cast reaches ACTIVE)
  and resolve projectile-vs-character hits server-only, `HitboxViewer`
  extended to draw projectile hitboxes. 8 new GUT tests (52 total
  project-wide), all passing. Live 2-process test's key finding: the
  server's and the client's own local Projectile instances tracked
  byte-for-byte identical positions at every checkpoint for the whole
  flight, with zero per-tick network sync — the deterministic-
  replication design holds. Did not force a live coincidental hit
  (headless has no real mouse to aim with); hit *application* is
  already proven live via Phase 2a's shared `_apply_hit` path, and hit
  *geometry* is proven by GUT — see `memory/verify.md`'s Phase 2b
  section for the full reasoning. One GDScript gotcha found and fixed:
  an `is Projectile` check doesn't narrow a loop variable's static
  type, so `var alive := node.advance_frame(...)` failed to import
  until an explicit `as Projectile` cast was added (`memory/gotchas.md`
  2026-09-02).

- [x] **Phase 3 (Ability Framework) implemented and tactically
  verified**: new `AbilityResource` (`gameplay/abilities/`) wrapping
  Phase 2's `MoveDefinition`/`HitDefinition` unchanged, 2 test
  abilities (`data/abilities/debug_ability_q.tres` "Power Strike"
  melee-style, `debug_ability_e.tres` "Fireball" projectile-style).
  `attack` rebound from J to the **left mouse button**;
  `ability_q`/`ability_e`/`ability_r`/`ability_f`/`ability_t` added on
  Q/E/R/F/T (Path of Exile 2's convention — R/F/T bound but unwired,
  intentionally deferred). `CharacterController` gained 2 fully
  independent ability slots (`ability_q_fsm`/`ability_e_fsm`, each its
  own `ActionFsm` and cooldown counter via the new
  `_advance_ability_slot()` helper); `InputBuffer.Sample`'s 4 press
  flags now travel over the network as one packed bitmask int
  (`pack_ability_flags`/`unpack_ability_flags`) instead of separate
  bool RPC params. `CombatResolver._resolve_attacker` generalized to
  dispatch either ability slot through the existing melee-hitbox path
  or the existing projectile-launch path (now `_maybe_launch_projectile`,
  parameterized by a `slot_name` round-tripped through
  `_rpc_spawn_projectile` so every peer looks the caster's own move up
  via `_get_move_for_slot()`) per that slot's own
  `AbilityResource.is_projectile`. `ClientPredictor.Checkpoint` grew 6
  fields to reconcile both ability slots' state/cooldowns. 6 new GUT
  tests (58 total project-wide), all passing; live 2-process test
  confirmed melee attack (10 dmg), ability_q/Power Strike (25 dmg
  melee), and ability_e/Fireball (projectile spawn) all resolve
  server-authoritatively, with the Fireball spawn RPC replicating
  identically to the client — see `memory/verify.md`'s Phase 3 section
  for full evidence, and `memory/plan.md`'s Slice 3 block for the
  deferred items (remote ability-slot visual replication,
  per-ability projectile speed/lifetime, unwired R/F/T).

- [x] **Phase 4 (first 2 real classes) implemented and tactically
  verified**: 2 orthogonal classes, **Vanguard** (melee frontline, 120
  HP: Quick Slash/Piercing Thrust/Heavy Slam/Bulwark Strike) and
  **Ranged Mage** (ranged skillshot dealer, 80 HP: Arcane Jab/Arcane
  Bolt/Frost Shard/Arcane Nova), each its own scene
  (`gameplay/characters/vanguard/`, `gameplay/characters/ranged_mage/`)
  reusing the unmodified `character_controller.gd`. `PlayerSpawner`
  alternates the 2 classes by connection order (no lobby yet -- Phase
  5's job); `TestArena.tscn`'s `MultiplayerSpawner` updated to the 2
  real scenes. `Character.tscn` kept as the generic GUT test fixture,
  no longer spawned in matches. Mechanical rename alongside this:
  `debug_attack_move`/`debug_skillshot_move` → `attack_move`/
  `skillshot_move` (7 files, no behavior change). 2 new GUT tests
  (`test_character_classes.gd`, 60 total project-wide), all passing;
  live 2-process test confirmed class alternation (server got
  Vanguard, client got Ranged Mage) and all 3 of Vanguard's kit moves
  landing with their exact authored damage values, server-
  authoritatively — see `memory/verify.md`'s Phase 4 section for full
  evidence, and `memory/plan.md`'s Slice 4 block for what's deferred
  (character-select UI, a 3rd class).

- [x] **Phase 5 (match modes) implemented and tactically verified**:
  `PlayerSpawner` assigns `team = index % 2` and clusters teammates 60
  units apart per side (4 spawn points, team 0 left / team 1 right).
  `MatchState.friendly_fire_enabled` (default off, `--friendly-fire`
  dev_bootstrap flag) gates `CombatResolver`'s 2 hit-resolution loops.
  An eliminated character (`current_health <= 0`) freezes permanently
  server-side and locally on the owning client. New `WinCondition`
  (pure, unit-tested) + `MatchRules` (server-only orchestrator, wired
  last after `CombatResolver`) resolve NONE/DRAW/a team win from each
  team's alive count, handling both the "match hasn't fully started"
  and "last teammate disconnected" edge cases correctly. `MatchState`
  is now genuinely client-visible for the first time (fixed a real
  latent gap: phase transitions never reached clients before this
  phase) via `@rpc` broadcasts plus a late-joiner catch-up handler. New
  `MatchHud` shows live team-alive counts and a win/draw banner. 5 new
  GUT tests (`test_win_condition.gd`, 65 total project-wide); live
  2-process test confirmed the elimination→win-condition→client-RPC
  chain end-to-end, and a live 3-process test confirmed the friendly-
  fire gate blocks a same-team hit by default and allows it with the
  flag (same geometry both times, ruling out a false positive). See
  `memory/verify.md`'s Phase 5 section and `memory/plan.md`'s Slice 5
  block for full evidence and deferred items (character-select UI, a
  real reconnect system).

- [x] **Phase 6 (3rd class + free-for-all) implemented and tactically
  verified — all 6 roadmap phases now complete (MVP per the roadmap's
  own criteria; see `memory/plan.md`'s new "MVP Status" section for
  what's genuinely done vs. what the fuller `docs/blueprint/`
  proposal still leaves open)**: `WinCondition.determine()`
  generalized from 2 fixed teams to N teams (team mode is the N=2
  case, not a separate path); `MatchRules` rewritten to a
  `Dictionary`-keyed, team-count-agnostic orchestrator. New
  `MatchState.match_mode` (`TEAM`/`FREE_FOR_ALL`, via a new
  `--free-for-all` dev_bootstrap flag) makes `PlayerSpawner` assign a
  unique team id per player in FFA instead of `index % 2` — no other
  code needed a mode branch, since a unique-per-player team id makes
  the existing friendly-fire/elimination logic correct for FFA with
  zero changes. `MatchHud` made mode-aware (team breakdown vs. a
  single alive-player count). New 3rd class **Warden**
  (support/control, 100 HP): the lowest-damage, highest-hitstun kit in
  the game, expressing "control" entirely through existing
  `HitDefinition` data (no new heal/shield/buff mechanic — none exists
  in `DamagePipeline` and adding one was out of scope). 5 new GUT
  tests (70 total project-wide); live testing across team mode (3
  classes, unaffected) and multiple free-for-all scenarios (2- and
  3-player, various elimination timings) confirmed team/class
  assignment, the "≥2 teams must have connected" guard, and the
  late-joiner catch-up path (built in Phase 5) all still correct under
  the generalized N-team model. See `memory/verify.md`'s Phase 6
  section and `memory/plan.md`'s Slice 6 block for full evidence and
  deferred items.
- [x] **Phase 7 (Main Menu -> Character Select -> Host/Join -> Lobby ->
  in-game) implemented and tactically verified**: real UI flow
  replacing `net/dev_bootstrap.gd`'s flag-only entry point (which
  itself is untouched and still works, confirmed live, now needs the
  scene passed explicitly since it's no longer `project.godot`'s main
  scene). New `ui/main_menu/`, `ui/character_select/` (local,
  pre-connection pick, no duplicate-class check), `ui/host_join/`
  (direct IP), `ui/lobby/` (waiting room, host-only Start). New
  server-authoritative `net/lobby_state.gd` (peer_id -> class_id
  registry, broadcast to all peers); `PlayerSpawner` reads it instead
  of auto-cycling, falling back to the old cycling for any
  unregistered peer. `MatchState.Phase` -> `{LOBBY, LOADING,
  IN_PROGRESS, POST_GAME}` (`CHARACTER_SELECT` dropped, never
  implemented; `LOADING` **restored** after the human owner caught the
  original `/think` plan trying to drop it too, mid-implementation --
  see `memory/plan.md`'s Slice 7 section for why a real handshake was
  needed) with a genuine `enter_loading()`/`report_loaded()` handshake
  (`net/loading_reporter.gd`, `TestArena.tscn`'s last child) gating
  `enter_in_progress()` on every connected peer's own tree actually
  being built. 2 real races found and fixed via live testing (not
  catchable by GUT, both needed 2 real processes): `PlayerSpawner`
  spawning before a remote peer's own `MultiplayerSpawner` existed yet
  ("Node not found"), and `LoadingReporter` reporting before
  `dev_bootstrap.gd`'s own client peer had finished its ENet handshake
  ("RPC via a multiplayer peer which is not connected") -- see
  `memory/gotchas.md` for both. 5 new GUT tests (75 total
  project-wide); live 2-process test confirmed the full flow end-to-end
  with each peer spawning as the class it actually chose, zero engine
  errors. See `memory/verify.md`'s Phase 7 section and
  `memory/plan.md`'s Slice 7 block for full evidence and deferred
  items (visual verification still has no solution in this project,
  same gap as every prior UI-adjacent phase).

## Backlog (next up)

- [ ] Review `docs/blueprint/05-open-questions.md` with the human owner
  — still genuinely open: team size beyond 2v2, persistent-tree
  size/gating, loadout cadence, rollback reconsideration, setting/tone.
  Friendly-fire toggle scope (Phase 5) and presentation (2D top-down)
  are resolved. The build-depth split in
  `docs/research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md`
  is the single highest-priority item to confirm — it's what the
  fuller MVP proposal in `docs/blueprint/04-mvp-scope.md` still needs
  beyond the roadmap's own now-complete 6 phases (see
  `memory/plan.md`'s "MVP Status").
- [ ] Decide how many ability slots a real class kit should have (R/F/T
  are reserved in the InputMap but unwired on all 3 classes) — a
  content/balance decision for whenever the roster grows past 3.
- [ ] Decide how (or whether) to replicate ability_q/e `ActionFsm`
  state to remote `INTERPOLATED` peers — the snapshot RPC is at a
  practical parameter-count limit; likely needs a packed-int
  restructure before a 4th+ ability slot makes this worse.
- [ ] Phases 8-10 (Room Config: mode/friendly-fire/manual team
  assignment/ready-check; 1 perk per player, visible to the room;
  LAN room discovery) — scope already designed via `/think`
  2026-09-03, see `memory/plan.md`'s "Slices 8-10" section. Phase 7
  (Main Menu/Character Select/Host-Join/Lobby) is done; this is what's
  left of the original combined "lobby" ask.
- [ ] A real reconnect/grace-period system — a mid-match disconnect
  currently resolves as an immediate forfeit for that team/player
  (Phase 5's elimination mechanism, generalized to N teams in Phase 6),
  matching "online matches should not pause," but the docs' own
  "Reconnect" sub-state is unbuilt.
- [ ] The full persistent build-investment layer (unlocks, node tree,
  respec economy) and a minimal pre-match loadout draft — the single
  biggest gap between "roadmap done" (this session) and the fuller MVP
  proposal in `docs/blueprint/04-mvp-scope.md`. Blocked on the
  build-depth-split confirmation above.

## Blocked

<!--
- [ ] <task> — waiting on: <reason or person>
-->
