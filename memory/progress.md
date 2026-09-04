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
- [x] Designed Slices 7-10 (lobby → character-select → room-config →
  perks → LAN discovery) via `/think` (2026-09-03) — see
  `memory/plan.md`'s "Slices 7-10"/Slice 7 sections for the full
  decided scope. Wrote `.claude/skills/ship-phase/SKILL.md`, a reusable
  skill generalizing this project's existing per-phase pattern (branch
  → implement in waves → verify → `/check` → `git merge --no-ff` →
  document), so future phases (these 4 and beyond) can run the same
  way, including unattended via `/loop`.
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
- [x] **Phase 8 (Room Config: mode, friendly fire, manual teams,
  ready, Start) implemented and tactically verified**: evolves Phase
  7's minimal `ui/lobby/` waiting room into the full Room Config
  screen -- host-only mode dropdown (Team/FFA) and friendly-fire
  checkbox, a per-row "Switch Team" button (Team mode only,
  self-service -- corrected mid-Phase-9 from an original host-only
  design, see the Phase 9 entry below), a ready checkbox per non-host
  player, host-only Start gated on
  `LobbyState.all_non_host_ready()`. `net/lobby_state.gd` grew
  `player_team_ids`/`player_ready`/`room_match_mode`/`room_friendly_
  fire` in place (its `registry_changed` signal renamed to `room_state_
  changed` to match); `PlayerSpawner._resolve_team_id()` now prefers a
  peer's manually-assigned team, falling back to the original
  `index % 2` for unregistered (headless) peers. `/check` found and
  fixed 2 real bugs before merge (see `memory/gotchas.md`
  2026-09-03): `MatchState.match_mode` wasn't replicated to clients
  (a client's own MatchHud would show Team-mode text/banners during an
  actual FFA match -- fixed by carrying `mode` through
  `enter_loading()`/`enter_in_progress()`/`enter_post_game()` and their
  RPCs, confirmed live on the client's own process); and manual team
  assignment could soft-lock a Team-mode match by putting every peer
  on one team (`WinCondition` never resolves a winner with <2 teams
  ever populated) -- fixed with new `LobbyState.has_valid_team_split()`
  gating Start. 9 new GUT tests (86 total project-wide); 4 real
  2-process live scenarios confirmed default team alternation, a
  host-issued manual switch, ready-gating on Start, host-chosen
  FFA+friendly-fire reaching the real match, and the match_mode fix
  specifically on the client's own process. See `memory/verify.md`'s
  Phase 8 section and `memory/plan.md`'s Slice 8 block for full
  evidence and deferred items (same visual-verification gap as every
  prior UI phase; the disabled Start button doesn't yet explain why).
- [x] **Phase 9 (1 self-service perk per player, visible to the room)
  implemented and tactically verified**: `gameplay/perks/perk_resource.gd`
  plus 4 `data/perks/*.tres` (Vitality, Swift, Adept, Balanced), `net/
  lobby_state.gd` grew `player_perk_ids`, Room Config gained a
  per-player perk dropdown (self-service from the start, unlike team's
  mid-Phase-8 correction). **Correction applied on this branch**:
  team switching, shipped host-only in Phase 8, was caught by the human
  owner as a real authority error and fixed to be self-service too --
  each peer's own row only, server RPC keyed off
  `multiplayer.get_remote_sender_id()` (see `memory/plan.md`'s updated
  Slice 8 block, `memory/gotchas.md` 2026-09-03). **Real bug found by
  `/check` and fixed before merge**: the perk multiplier was applied in
  `PlayerSpawner` (server-side spawn only), never reaching a peer's own
  PREDICTED/INTERPOLATED copy of any character (separate node
  instances from `MultiplayerSpawner`'s own replication, which never
  runs `PlayerSpawner`'s code) -- silently made perks do nothing for
  movement speed/cooldown outside the server's own simulation. Fixed by
  moving application into
  `CharacterController._apply_perk_from_lobby_state()`, called from
  every peer's own `_ready()`. Also deduped `resolve_class_id()`/
  `resolve_perk_id()`'s identical validation logic and fixed a stale
  doc comment, both flagged by the same `/check` pass. 103 total GUT
  tests project-wide (was 86); live 2-process test (Vanguard+Vitality
  host, Ranged Mage+Swift client) confirmed correct math (120 base HP
  x 1.15 = 138) with **identical values logged on both the server's and
  the client's own process** for both characters -- direct proof the
  per-peer fix holds across a real network boundary. See
  `memory/verify.md`'s Phase 9 section and `memory/plan.md`'s Slice 9
  block for full evidence.
- [x] **Phase 10 (LAN room discovery) implemented and tactically
  verified -- the roadmap's original Slices 7-10 "lobby" ask is now
  fully complete**: new autoload `net/lan_discovery.gd` (`LanDiscovery`),
  a UDP broadcast beacon/listener entirely separate from
  `net/network_manager.gd`'s ENet gameplay connection (its own fixed
  port, 7778, never gameplay data). Host broadcasts
  `{player_count, max_players}` every 1s; client listens, tracks
  discovered rooms keyed by the sender's real IP
  (`PacketPeerUDP.get_packet_ip()`, never trusted from the payload),
  prunes anything not re-announced within 3s. `ui/host_join/`'s
  `HostJoin.tscn` gained a double-click-to-join room list; manual IP
  entry is unchanged and always available as the guaranteed fallback.
  `/check` found and fixed 3 real issues before merge (see
  `memory/gotchas.md` 2026-09-03): a same-machine socket-bind race
  between 2 headless test processes (Godot's `PacketPeerUDP` has no
  `SO_REUSEPORT`, mitigated by releasing the host's own listen-bind
  first, documented as a narrow test-only limitation -- never affects
  2 real players on separate machines); a silent timeout in the
  headless discovery-join dev hook (now sets a status label, per
  `CLAUDE.md`'s no-silent-fallbacks rule); and an inconsistent
  socket-close pattern. 8 new GUT tests (111 total project-wide); live
  2-process test confirmed the full discovery pipeline twice (before
  and after the `/check` fixes) -- host broadcasts, client discovers
  and joins via the *discovered* IP, zero engine errors. The one real
  environment risk flagged going in (whether broadcast crosses this
  dev environment's WSL2 network path at all) did not materialize --
  it worked -- though a real multi-machine LAN (physical router,
  actual Wi-Fi) was never tested, out of this environment's reach. See
  `memory/verify.md`'s Phase 10 section and `memory/plan.md`'s Slice 10
  block for full evidence.
- [x] Fixed a real gap the human owner caught during manual play-testing
  after Fases 7-10: a hit projectile only ever `queue_free()`'d on the
  server -- every other peer's own decorative copy kept flying until
  its `remaining_lifetime_frames` ran out, instead of disappearing the
  moment it actually hit. Known and explicitly documented as deferred
  since Phase 2b's own code comment ("a deliberate, minor visual-
  polish gap for this first pass"), not a regression from Fases 7-10.
  Fixed with a new `CombatResolver._rpc_despawn_projectile(network_id)`
  broadcast (`@rpc("authority", "reliable", "call_local")`, same shape
  as the existing `_rpc_spawn_projectile`), fired the instant the
  server confirms a hit; `Projectile`'s node is now named `str(
  network_id)` (same "look it up by a replicated id" convention
  `PlayerSpawner` already uses for characters) so the RPC can find the
  exact instance on every peer. Natural lifetime expiry is unaffected
  -- still needs no RPC, already deterministic on every peer.
  **Verification note**: forcing a genuine coincidental live hit is
  impractical in this headless environment for the same reason Phase
  2b's own testing already established -- confirmed empirically this
  session (a fired skillshot's default no-real-mouse aim direction
  points away from where the other peer spawns, not toward it), not
  assumed. Verified instead by: full GUT suite still green (111/111,
  no regression), a live 2-process regression run confirming the
  changed spawn/advance code path still works with zero engine errors,
  and structural review -- the new RPC mirrors `_rpc_spawn_projectile`
  exactly, which live testing has already proven correct across every
  phase that's used it. `gdformat`/`gdlint` clean.
- [x] Decoupled melee aim from movement, per the human owner's own
  play-testing feedback ("mirar e andar deveriam ser independentes,
  mesmo para melee"). Melee's hitbox aim (`CharacterController.
  get_aim_direction()`) read `LocomotionFsm.facing_direction` (last
  movement direction) since Phase 2a -- a real coupling bug, not a
  cosmetic one: a player standing still after moving left, then trying
  to melee-attack something to their right, would swing left instead.
  Fixed with a new `current_aim_direction` field, refreshed every tick
  in `apply_input()` from `sample.aim_direction` -- the same real
  mouse-aim value already sampled every tick for the skillshot/ability
  slots (`InputManager.get_aim_direction()`, network-safe the same way
  `pending_skillshot_direction` already is: the server reads the
  submitting peer's own transmitted sample, never a live local mouse
  read for someone else's character). `LocomotionFsm.facing_direction`
  itself is untouched -- still tracks movement for whatever eventually
  needs it (a future sprite-facing system), just no longer feeds
  combat aim. Replaced the one existing test that asserted the old
  (coincidental-at-zero-input) coupling with
  `test_get_aim_direction_is_independent_of_movement`, which moves one
  way and aims another and asserts the hitbox follows the aim. 111
  total GUT tests (unchanged count, one replaced). **Known follow-up,
  not a regression**: `net/player_spawner.gd`'s spawn-position comment
  documented a live-verified guarantee that an un-aimed headless
  `--simulate-attack` lands a hit, which depended on melee's old
  default-facing-right behavior -- no longer holds now that melee
  inherits the same "no real mouse in headless" caveat
  `--simulate-skillshot` already had (confirmed empirically: the
  default headless aim direction points away from where a teammate
  spawns, not toward it). A real player's mouse-aimed swing is
  unaffected -- this is the fix actually working, not a gap in it.
  Comment corrected in place; a future headless melee-hit test would
  need an explicit fake-aim dev flag, not a coincidental default,
  mirroring how class/perk already get one.
- [x] Holding attack/skillshot/ability_q/ability_e now auto-repeats
  the instant that slot's own move+recovery (or ability cooldown)
  ends, instead of requiring a fresh press each time -- the human
  owner's own request while play-testing. New
  `InputManager.is_action_pressed()` (held state, mirroring the
  existing `is_action_just_pressed()`), swapped in for all 4 of
  `_sample_local_input()`'s attack/skillshot/ability_q/ability_e reads.
  `dash` deliberately left edge-triggered (`is_action_just_pressed`,
  unchanged) -- auto-repeating an evasive burst on hold is a separate
  balance question, not asked for here. The actual repeat gating is
  unchanged (`apply_input()`'s existing `can_start_move`/cooldown-
  remaining checks), so "respects cooldown" was already correct by
  construction, not new logic. New GUT test
  `test_holding_attack_auto_repeats_once_the_move_ends` locks the
  `apply_input()`-level contract (112 total tests, was 111); the
  `_sample_local_input()` half isn't unit-testable (depends on the
  real `Input` singleton), so verified live instead: `net/
  dev_bootstrap.gd`'s existing `--simulate-attack` flag already never
  releases the key it presses, so under the old edge-triggered
  behavior it fired exactly once by design -- under the new held-state
  behavior the same unmodified flag produced 9 full attack cycles
  (20 frames each) in a ~4.8s window, temporary trace confirmed then
  removed. `gdformat`/`gdlint` clean, no regressions.
- [x] Added cosmetic swing-pulse + hit-flash feedback, human-owner
  requested while play-testing ("todos as skill precisa de feedback
  visual, além do fato de acertar"): new
  `CharacterController._update_visual_feedback()`, called every tick
  from `_physics_process` on every control mode (AUTHORITATIVE,
  PREDICTED, INTERPOLATED alike -- so you see it on remote characters
  too, not just your own). A hit flashes the defender's `Visual`
  `Polygon2D` to an overbright white-ish `modulate` for
  `HIT_FLASH_FRAMES` (6, ~0.1s) the tick `current_health` is observed
  to drop -- no new replication needed, `current_health` is already
  correct on every peer via existing snapshot/reconciliation. A swing
  pulses a subtler highlight whenever any of the 3 melee-hitbox-
  capable FSMs (`action_fsm`, `ability_q_fsm`, `ability_e_fsm`) is
  ACTIVE; a hit flash always wins over a swing pulse when both would
  otherwise apply. 5 new GUT tests (117 total project-wide, was 112).
  **Known, pre-existing gap this inherits, not new**: `ability_q_fsm`/
  `ability_e_fsm` state still isn't replicated to remote INTERPOLATED
  peers (the Phase 3 gap, `memory/plan.md`'s Deferred section) -- a
  remote peer won't see someone else's Q/E swing pulse yet, same as
  they already don't see the swing itself.
- [x] Found and fixed a real bug while investigating why the human
  owner saw nothing in the F1 `HitboxViewer` for Vanguard: `_draw_
  hitbox_if_active()` only ever checked the base `action_fsm`/
  `attack_move` pair -- it was never updated when Phase 3 gave
  ability_q/ability_e their own independent FSMs, so a melee-style
  ability (Vanguard's Heavy Slam/Bulwark Strike) never drew a debug
  hitbox, even though `CombatResolver._resolve_ability_slot()` already
  correctly resolves real damage for them (confirmed by reading that
  code path, not assumed). Debug-visual-only bug, not a combat one --
  reasonably misread as "the hit isn't landing" from the missing
  visual alone. Fixed by generalizing `_draw_hitbox_if_active()` to
  also draw `ability_q`/`ability_e`'s own hitbox whenever that slot is
  melee-style (`not is_projectile`), mirroring `CombatResolver`'s own
  existing generalization exactly. No new test added -- this file's
  existing tests only cover F1 toggle/group behavior, never the
  `_draw()` logic itself (nothing in this project unit-tests draw
  calls, consistent with the long-standing "no way to screenshot
  Godot's renderer here" limitation); verified by code-path comparison
  against the already-correct `CombatResolver` logic instead.
- [x] **Phase 12 (spawn layout generalized for 2v2 through 5v5 + FFA)
  implemented and tactically verified**: `net/player_spawner.gd`'s
  hardcoded 4-point `SPAWN_POSITIONS` replaced by `_spawn_position_for
  (team_id)` -- team mode stacks a team's members vertically around
  arena-center height (unbounded, comfortably inside the arena for
  every confirmed team size); free-for-all places each uniquely-teamed
  player on a fixed circle around the arena center, cycling past 8
  slots rather than erroring. `_resolve_team_id()`/class assignment
  untouched. TDD: new `tests/unit/test_player_spawner.gd` (4 tests,
  written and confirmed failing -- a real parse error, the method
  didn't exist yet -- before implementing) -- 121 total GUT tests
  project-wide (was 117). 2 live 3-process runs (team mode + FFA), zero
  engine errors on either. See `memory/verify.md`'s Phase 12 section
  and `memory/plan.md`'s Slice 12 block for full evidence.
- [x] **Phase 11 (lag compensation in `HitDetection`) implemented and
  tactically verified**: new per-character `_position_history` ring
  buffer (24 entries, ~400ms @60Hz) on `CharacterController`, recorded
  every authoritative physics tick; new pure `HitDetection.
  position_at_or_before()`; new `CombatResolver.
  _compensated_defender_position()` used by both `_resolve_melee` and
  `_resolve_projectile_hit` in place of `defender.global_position`,
  bounded to 12 ticks (~200ms) of compensation via `NetworkManager.
  get_peer_rtt_ms()`. TDD: 6 new tests across `test_hit_detection.gd`
  and `test_character_controller_combat.gd`, confirmed failing (real
  parse errors) before implementing -- 127 total GUT tests
  project-wide (was 121). Live 2-process regression (melee, skillshot,
  and ability_q, one peer moving) clean, zero engine errors. **Honestly
  scoped**: this environment's loopback RTT measures ~0ms, so the
  compensation math is mathematically a no-op here (confirmed by
  `CombatResolver`'s own last-child tick ordering, not just assumed) --
  a genuine non-zero-latency demonstration isn't practical to force
  (no way to inflate real measured ENet RTT in this environment,
  distinct from `NetworkManager.artificial_latency_ms`, which only
  delays local side-effects). See `memory/verify.md`'s Phase 11
  section and `memory/plan.md`'s Slice 11 block for full evidence.
- [x] **Phase 13a (grace-period delay before disconnect forfeit)
  implemented and tactically verified**: `net/player_spawner.gd` no
  longer despawns immediately on `peer_disconnected` -- starts a 30s
  grace timer instead (`--dev-grace-period=` override for testing,
  validated with `is_valid_float()`/`push_error()` rather than
  silently becoming 0), despawning only if unclaimed. No new freeze
  mechanism needed -- `ServerSim`'s existing stale-input fallback
  already stops the character. New `MatchState.players_in_grace_period`
  (aggregate) drives a minimal `MatchHud` "N player(s) disconnected"
  line. TDD: 4 new `PlayerSpawner` tests, confirmed failing before
  implementing -- 131 total GUT tests project-wide (was 127). `/check`
  (high) found and fixed 5 real issues: a stale `MatchRules` comment
  claiming instant-forfeit still happens, a `MatchHud` label
  overpromising "reconnecting..." (Slice 13b doesn't exist yet), the
  malformed-flag-silently-becomes-0 bug, a missing `.uid` for the
  Phase-12 test file (pre-existing, caught here), and documenting (not
  fixing) the edge case of a new peer joining mid-grace-period. Live
  2-process test (`--dev-grace-period=3`) confirmed the delay and
  expiry timing via a temporary trace; vulnerability during the grace
  period was verified by code-path reading (no exclusion exists
  anywhere in `CombatResolver`), not forced live -- same aim-in-
  headless limitation every phase since the melee-aim fix has had.
  See `memory/verify.md`'s Phase 13a section and `memory/plan.md`'s
  Slice 13a block for full evidence. **Slice 13b (token-based
  reconnect) is a separate, larger, not-yet-started phase** -- see
  `memory/plan.md`'s Slice 13b block; needs its own `/think` before
  implementing, per the human owner's own explicit instruction not to
  start it here.
- [x] **Slice 13b (token-based reconnect) implemented and live-verified,
  branch built but not yet merged**: `net/reconnect_manager.gd` (new
  autoload) holds a server-issued token client-side, auto-retries
  joining the last address every second on disconnect for up to 30s,
  and drives `ui/hud/network_stats_overlay.gd`'s status text/eventual
  return to `MainMenu`. `CharacterController.controlling_peer_id` +
  `PlayerSpawner.try_reclaim()` implement reconnect exactly as
  `memory/plan.md`'s Slice 13b block originally designed, no `/think`
  deviation needed. **3 real bugs found live via 2-process testing
  (`net/dev_bootstrap.gd`'s new `--dev-kick-after=` flag) that the
  design didn't anticipate**, all fixed and re-verified: (1) a
  reconnecting peer's own `peer_connected` always spawns a throwaway
  duplicate character before its reconnect token can arrive --
  `try_reclaim()` now despawns it, but only after a live-calibrated
  1s delay (freeing it instantly raced `MultiplayerSpawner`'s own
  replication and produced real engine errors) -- **a known,
  intentionally-not-fully-closed ~1s dual-control window remains, see
  `memory/plan.md`'s Slice 13b block and `memory/gotchas.md`**; (2)
  the original design's post-reconnect scene reload corrupted
  `MultiplayerSpawner`'s replication caches -- removed, reconnection
  now resumes the client's already-frozen scene in place; (3) `net/
  dev_bootstrap.gd`'s dev-only `--join`/`--server` flags were
  re-executing on the scene reload from bug #2 -- guarded regardless.
  TDD: 139 total GUT tests project-wide (was 138), all passing.
  `gdformat`/`gdlint` clean. `/check` run inline by the implementing
  fork; findings fixed and re-verified live rather than deferred.
  **Merged into `main`** (commit `4d47c96`): the implementing fork ran
  in an isolated `.claude/worktrees/` checkout and the sandbox refused
  any git operation targeting the shared primary checkout from inside
  it (not a "main is busy" conflict -- a hard tool-level boundary), so
  the merge was done from the primary checkout instead, followed by
  `godot4 --headless --import` and a full re-verification (140/140 GUT,
  lint clean) on the current engine build. See `memory/verify.md`'s
  Phase 13b section and `memory/plan.md`'s Slice 13b block for full
  evidence.
- [x] **Reconnect token reissue fix (2026-09-03, post-merge)**: the
  token was single-use with no replacement ever issued, so a peer that
  reconnected once had nothing left to survive a 2nd disconnect in the
  same match. `PlayerSpawner.try_reclaim()` now calls
  `_issue_reconnect_token(new_peer_id)` on a successful reclaim; its
  remote RPC dispatch is now guarded behind
  `multiplayer.get_peers().has(peer_id)` so unit-testing `try_reclaim()`
  directly (a fabricated peer_id, no real `ENetMultiplayerPeer`)
  doesn't explode. New regression test in `tests/unit/
  test_player_spawner.gd`, confirmed red before the fix, green after.
  140/140 GUT passing, `gdformat`/`gdlint` clean. See
  `memory/gotchas.md` and `memory/plan.md`'s Slice 13b block.
- [x] **Phase 14 (Room Config UX) implemented, live-verified, on
  `feature/phase14-room-config-ux`**: `LobbyState.all_ready()` (host
  included) replaces `all_non_host_ready()`; a server-only countdown
  (`is_room_ready_to_start()` gate, 2s silent pre-delay + broadcast 5s
  visible countdown, cancel-and-restart on any ready-set change)
  auto-triggers the match with no more host-only Start button. Room
  Config's UI: a Ready/Not Ready toggle button on every row (Switch
  Team nested below it on the local row), Red/Blue team labels, and a
  new Leave Room button returning to Main Menu. `/check` (high
  severity) found 2 real bugs -- stale `LobbyState` registries surviving
  a Leave Room -> re-host cycle, and no guard against the countdown
  re-triggering mid-match -- both fixed (`reset_room()`,
  `_countdown_still_valid()`) and re-verified. 9 new GUT tests (149
  total, was 140). Live 2-process test: both peers ready -> auto-starts
  with zero engine errors; only one ready -> never starts; re-verified
  after the `/check` fixes. See `memory/plan.md`'s Slice 14 block and
  `memory/verify.md`'s Phase 14 section for full evidence, including
  the 2 gaps left deliberately unverified (the Leave Room button's own
  click path, and the exact mid-countdown-cancel race) and why.
- [x] **Phase 15 (Ability framework Q/E/R/F) implemented, live-verified,
  on `feature/phase15-ability-rf`**: each of the 3 classes gains 2 new
  abilities on R/F, mirroring the existing Q/E slot pattern exactly
  (own FSM, own cooldown, independent of every other slot). 8 new
  ability+move pairs authored (Vanguard: Shoulder Charge/Execute;
  Ranged Mage: Mana Spike/Meteor; Warden: Restraining Web/Guardian's
  Grasp), calibrated against each class's existing Q/E numbers, a first
  pass subject to rebalancing. Found and fixed 2 real bugs: (1) a
  reconciliation crash, latent for Q/E since Phase 3 -- `ClientPredictor.
  Checkpoint` never restored an ability slot's `current_move`, only
  `.state`/`.move_frame`, so a replay landing on a restored active slot
  dereferenced a null move; (2) the F1 debug hitbox viewer only drew
  Q/E's melee hitboxes, the exact same gap the human owner already
  caught once for Q/E itself during Phase 3 -- found via self-review
  before it could repeat for R/F. 158/158 GUT tests passing (was 149).
  Live 2-process test: server (Vanguard) cast Shoulder Charge/Execute,
  client (Ranged Mage) cast Mana Spike/Meteor, zero engine errors after
  the reconciliation fix. `/check`'s async background dispatch had no
  way to retrieve a result from inside this isolated worker fork (no
  task-list/task-output access available to it) -- fell back to an
  inline adversarial self-review, same convention Phase 13b's fork used
  when no specialist sub-agents were available. See `memory/plan.md`'s
  Slice 15 block, `memory/gotchas.md`, and `memory/verify.md`'s Phase 15
  section for full evidence.
- [x] **Phase 16 (Loadout: Weapon + Boot) implemented, live-verified, on
  `feature/phase16-weapon-boot-loadout`**: a shared pool of 3 weapons
  (Iron Sword, Twin Daggers, Warhammer) and 3 boots (Swift Boots,
  Warded Greaves, Tumbling Boots) -- any class can equip any of them.
  `CharacterController.attack_move`/`skillshot_move` stopped being
  fixed per-class `@export` values, now resolved every `_ready()` from
  the player's weapon pick (same "every peer's own instance, never
  `PlayerSpawner`" pattern as Phase 9's perk). `boot_active` is a new
  5th ability-like slot on T, dispatched through the existing generic
  ability-slot machinery unchanged. `LobbyState` gained
  `player_weapon_ids`/`player_boot_ids` mirroring `player_perk_ids`
  exactly -- class + weapon + boot + perk are 4 fully independent
  choices, perk untouched. Removed 6 now-orphaned per-class attack/
  skillshot move files (verified unreferenced first). Found and fixed
  1 gap via self-review: `net/dev_bootstrap.gd` had no
  `--simulate-boot-active` flag alongside its existing R/F ones. 24
  new GUT tests (182 total, was 158). Live 2-process test through the
  REAL Room Config flow (not `dev_bootstrap.gd`'s direct-connect,
  which would race the same way Phase 13b did): both peers' resolved
  weapon/boot/move names matched identically on BOTH the server's and
  the client's own process, zero engine errors. See `memory/plan.md`'s
  Slice 16 block and `memory/verify.md`'s Phase 16 section for full
  evidence.
- [x] **Phase 17 (Rounds: Best of 3) implemented, live-verified, on
  `feature/phase17-best-of-3-rounds`**: `MatchState` gains a new
  `ROUND_INTERMISSION` phase, `round_wins`/`current_round`, and
  `resolve_round_result()` (now called by `MatchRules` instead of
  `enter_post_game()` directly). A new `RoundIntermissionOverlay`
  (`ui/hud/round_intermission_overlay.gd`, a `TestArena.tscn` sibling
  of `MatchHud`) lets each peer re-pick weapon/boot/perk between
  rounds via the same self-service `LobbyState` setters Room Config
  uses, with the confirmed 15s/13s/5s/3s timing. Starting the next
  round reuses `enter_loading()` outright -- a full, already-proven
  reset via `TestArena.tscn`'s own fresh scene load, no new "reset
  stats in place" path needed. `MatchHud`'s final banner now shows the
  round score too. **2 real bugs found live**: (1) a server-side crash
  in `CharacterController._rpc_send_input()` -- nothing previously
  stopped a client from sending input for its old character all
  through the intermission, and an in-flight packet could arrive after
  a round-transition reload had already detached that node; fixed with
  2 guards (an `IN_PROGRESS`-only send gate, plus an `is_inside_tree()`
  belt-and-suspenders check on receive), confirmed fixed across 3
  repeated live runs. (2) A separate, confirmed-non-fatal engine-level
  despawn-ordering warning (`ERR_UNAUTHORIZED` from
  `MultiplayerSpawner`) reproduces consistently but never once affected
  the correct round-2/final-score outcome across 3 live runs -- a real
  fix would mean redesigning the round-transition sequencing, deferred
  as bigger than this phase's own scope. 10 new GUT tests (192 total,
  was 182). Live 2-process test (through the real headless flow --
  found and fixed a real doc gap: `godot4 --headless -- --server` no
  longer reaches `net/dev_bootstrap.gd` at all since Phase 7 changed
  the main scene, the scene must be passed explicitly): a full 2-round
  best-of-3 sequence completed correctly end-to-end 3 times in a row,
  identical results on both peers each time. See `memory/plan.md`'s
  Slice 17 block, `memory/gotchas.md`, and `memory/verify.md`'s Phase
  17 section for full evidence.
- [x] **Phase 18 (Match Log: `GameLog`) implemented, live-verified, on
  `feature/phase18-game-log`**: a new `GameLog` autoload --
  `info()`/`warn()`/`error()`, one JSON line per call to
  `user://logs/<timestamp>_pid<N>_<counter>.jsonl`, server-only (a
  silent no-op on a client). Found and fixed a real robustness gap
  before it could ever bite: the filename's 1-second timestamp
  granularity meant 2 server processes started in the same wall-clock
  second (a real risk in this project's own 2-headless-process dev
  testing) would silently clobber each other's log file -- fixed by
  folding the process id and an open-count into the filename. Wired at
  every event boundary the roadmap item specified: peer connect/
  disconnect and every match phase transition (`core/match_state.gd`),
  each registered peer's final loadout choice logged once at match
  start (`net/lobby_state.gd`), and the reconnect grace-period/reclaim
  flow (`net/player_spawner.gd`); every pre-existing `push_error()`/
  `push_warning()` call site in the project got a paired
  `GameLog.error()`/`.warn()` call alongside it. 9 new GUT tests (201
  total, was 192). **2 separate live 2-process tests**: a direct-
  connect run confirmed event ordering and the server-only gate under
  real networking; a real-disconnect run (killed the client process
  outright) confirmed the FULL event chain end-to-end in the server's
  actual on-disk file -- connect → disconnect → grace period started →
  grace period expired (forfeit) → round ended → intermission started,
  all 7 lines in order, zero engine errors, client wrote no log file.
  See `memory/plan.md`'s Slice 18 block and `memory/verify.md`'s Phase
  18 section for full evidence.
- [x] **Phase 19 (Replay Recording: `ReplayRecorder`) implemented and
  live-verified, on `feature/phase19-replay-recording`**: a new
  autoload, separate file/system from `GameLog` per the human owner's
  own request. Writes `user://replays/<timestamp>_pid<N>_<counter>.replay`
  (JSONL) -- a `header` (mode, friendly-fire, round target, a reserved
  `sim_seed`, each peer's initial loadout), `loadout_change` records
  (a mid-match re-pick during `ROUND_INTERMISSION` only -- Room
  Config's own initial pick is already in the header), `tick` records
  (every authoritative character's raw `InputBuffer.Sample`, batched
  per tick -- no calculated/derived value ever stored), `round_end`
  (every round, including the match-ending one), and a final
  `match_end`. A real design risk avoided during implementation:
  `ServerSim.tick_count()` is per-character and resets on a round-
  transition respawn, so `Engine.get_physics_frames()` (a single
  monotonic per-process counter) is the shared tick key instead --
  confirmed strictly increasing with zero collisions across a real
  round transition in this phase's own live test. 16 new GUT tests
  (217 total, was 201). **Live 2-process test through the real Room
  Config flow**: a full best-of-3 sequence (client self-eliminating
  each round), a real mid-intermission weapon change via a new
  `--dev-change-weapon-in-intermission=<id>` dev flag, then inspected
  the server's actual on-disk file -- correct header, 184 real tick
  records, the 1 loadout change, both round_end records (including the
  match-ending round), exactly 1 match_end. Client wrote no file. See
  `memory/plan.md`'s Slice 19 block and `memory/verify.md`'s Phase 19
  section for full evidence.
- [x] **Phase 20 (Replay Playback: `ReplayDriver`) implemented and
  live-verified, on `feature/phase20-replay-playback` -- closes the
  ENTIRE Phases 14-20 batch**: reconstructs a `.replay` file by
  reusing the real simulation (every replayed character resolves
  `ControlMode.AUTHORITATIVE`; a new `CharacterController.replay_
  step_authoritative(sample)` pushes a recorded sample and runs the
  exact per-tick step a live server tick already runs), not a
  reimplementation. `controlling_peer_id` is offset by 1,000,000 so
  `is_owned_by_me()` never fires the live-input double-record path.
  Seeking always re-simulates from tick 0 (confirmed MVP tradeoff, no
  checkpoint cache). UI: a "Replays" button on Main Menu, a list
  screen, a player screen with Play/Pause/Skip Back/Skip Forward/a
  scrubber. 1 real bug found via live verification (recorded a real
  best-of-3 match, then played that exact file back and compared final
  state against it): `_spawn_characters()` used deferred `queue_free()`
  instead of immediate `free()`, so 2 calls in the same frame raced a
  node-name collision, silently breaking every `str(name).to_int()`-
  keyed lookup for the mis-renamed character. 14 new GUT tests (231
  total, was 217). Live verification: reconstructed a real recorded
  362-tick, 2-round, host-wins-2-0 match byte-for-byte -- final
  `ticks_processed`/`is_finished`/`final_winner`/`round_wins` all
  matched the recording's own file content exactly, mid-match state
  (health, position) plausible with no phantom characters after the
  fix. See `memory/plan.md`'s Slice 20 block and `memory/verify.md`'s
  Phase 20 section for full evidence.
- [x] **Follow-up fix (2026-09-04, `/hunt`): replayed matches never
  actually resolved combat.** `ui/replay/ReplayPlayer.tscn` was missing
  the `CombatResolver`/`Projectiles` nodes `TestArena.tscn` uses for
  ALL projectile spawning and hit resolution -- ticks/rounds/winner
  still reconstructed correctly (copied from the file's own recorded
  structural data), which is why Phase 20's own live verification
  missed it, but no projectile ever spawned and no damage ever applied
  during playback. Fixed by adding those 2 nodes, plus an adjacent bug
  in the same code path (`replay_driver.gd` parsed the header's
  `friendly_fire` field but never applied it to `MatchState`). Also
  added the F1 debug hitbox viewer to replay playback, per request.
  5 new regression tests, confirmed red then green. 236/236 GUT
  passing. See `memory/plan.md`'s Slice 20 follow-up note,
  `memory/verify.md`'s Phase 20 follow-up section, and
  `memory/gotchas.md` for full evidence.
- [x] **Replay camera control + playback speed (2026-09-04, human
  owner's own request).** Tab cycles the camera through replayed
  characters; arrow keys (new `replay_camera_left/right/up/down`
  actions) decouple into a freely-moved camera, Tab re-couples; number
  keys `1`/`2`/`3`/`4` (new `replay_speed_1x/2x/4x/8x` actions) set
  `ReplayDriver.playback_speed` (1x/2x/4x/8x). Also bumped
  `ArenaCamera`'s zoom in `ReplayPlayer.tscn` from 1.0 to 1.4 --
  confirmed the arena's own `Walls` extend past the default viewport at
  zoom 1.0, exactly matching the human owner's own suspicion about why
  F1's hitbox debug view looked empty during replay. 10 new tests
  (`tests/unit/test_replay_player.gd`, new file, +2 in
  `test_replay_driver.gd`). 246/246 GUT passing. See `memory/plan.md`'s
  Slice 20 2nd follow-up note and `memory/verify.md`'s Phase 20 section
  for full evidence.
- [x] **Fixed: the entire replay VCR control row was off-screen
  (2026-09-04, found live -- "enter/space deu certo. Mas não vi esse
  botão").** `ui/replay/ReplayPlayer.tscn`'s bottom `Controls` row
  (PlayPauseButton/SkipBack/SkipForward/Scrubber/BackButton) sat at
  y:740-780, past this project's own default viewport height (648) --
  genuinely invisible since Phase 20's original build; keyboard
  activation (Enter/Space on a focused button) still worked because
  Godot's focus system doesn't require on-screen visibility, which is
  exactly why this shipped unnoticed. Moved the whole row to y:590-630
  and fixed `BackButton`'s right edge (was also past the viewport
  width). New regression test
  (`test_every_control_fits_inside_the_real_viewport`) checks every
  Control under a replay screen's root against the real configured
  viewport size -- confirmed red (6 failures matching every affected
  control) before the fix, green after. 249/249 GUT passing. See
  `memory/gotchas.md` for the full mechanism.
- [x] ~~"Back to List" once a replay finishes~~ -- built, then
  reverted the same day (`git revert 5d89ebb`) once the real cause of
  "não vi esse botão" turned out to be the off-screen-row bug above,
  not a missing affordance: the plain `BackButton` was ALWAYS present
  and working, just as invisible as everything else in that row until
  the viewport fix. Once that's fixed, `BackButton` alone already
  covers "get back to the list at any time, including once finished" --
  repurposing Play/Pause into a 2nd copy of the same action is
  redundant. Human owner's own call: "esse back to list, fica
  irrelevante, já que tem o back sempre."

## Backlog (next up)

- [ ] **Decide whether to close Phase 17's `ERR_UNAUTHORIZED` despawn-
  ordering race** (confirmed non-fatal across 3 live runs -- round-2/
  final-score results were always correct -- but reproduces every
  round transition) by redesigning the round-transition sequencing so
  the server's own despawn-and-acknowledge completes before any client
  is told to reload, or accept the current confirmed-harmless warning
  as good enough for now. See `memory/plan.md`'s Slice 17 block and
  `memory/gotchas.md` for the full mechanism.
- [ ] Phase 17's early-vs-late intermission countdown does not let an
  un-confirm CANCEL an already-started early countdown once the
  confirm-set completes -- a deliberate reading of the human owner's
  own spec (which only describes cancel/restart for Slice 14's
  original ready-countdown, not this one), not re-litigated during
  this phase. Revisit if it turns out to matter in practice.
- [ ] **Internet play without manual port-forwarding** (confirmed
  future direction, 2026-09-04, not yet scheduled as a roadmap phase)
  — migrate `net/network_manager.gd`'s transport from
  `ENetMultiplayerPeer` to `WebRTCMultiplayerPeer` for its NAT
  traversal (transport-only change, server stays fully authoritative).
  Full write-up in `docs/blueprint/03-networking-and-match-modes.md`'s
  "Future: Internet Play Without Manual Port-Forwarding" section and
  `memory/plan.md`'s "Deferred / Out of Scope" — confirmed by code
  audit that every ENet-specific call in the project lives in that one
  file, but a signaling service (WebRTC can't connect without one) and
  a STUN/TURN server don't exist in this project yet, and need their
  own hosting/provider decisions via a future `/think` before this is
  scheduled.
- [ ] **`/check`'s background-dispatch mechanism doesn't work from
  inside an isolated worker fork -- confirmed recurring, not a one-off**
  (Phase 15, then Phase 16 skipped even attempting it, going straight
  to inline self-review per Phase 15's own documented finding): no
  task-id is returned, and no `TaskList`/`TaskOutput` access is
  available to retrieve a result even if one existed. Not a blocker
  (inline adversarial self-review is an accepted fallback, same as
  Phase 13b, and has caught real issues both times), but worth the
  human owner's attention: Phases 17-20 will all be doing self-review
  instead of the dedicated multi-persona `/check` pass unless this gets
  fixed.
- [ ] LAN discovery: Linux still can't discover a Windows-hosted room
  even after confirming `ufw allow 7777/udp` + `7778/udp` (the 7777
  fix DID resolve the separate "join hangs forever" symptom -- this is
  what's left). Paused mid-investigation, no Linux machine access this
  session -- see `net/lan_discovery.gd`'s own comment and
  `memory/gotchas.md` for the full history and the exact next
  commands to run (`sudo iptables -L -n -v` for Docker interference,
  `ip addr` vs `ipconfig` for a subnet mismatch).
- [x] ~~Slice 13b (token-based reconnect)~~ -- implemented,
  live-verified, merged into `main` (`4d47c96`), and the single-use
  token gap fixed post-merge -- see the "Completed (this session)"
  entries above and `memory/plan.md`'s Slice 13b block. 1 item remains
  from it:
- [ ] **Decide whether to close Slice 13b's ~1s dual-control window**
  (a reconnecting peer briefly predicts/drives both its reclaimed
  original character and a throwaway duplicate before the duplicate
  is despawned -- see `memory/plan.md`'s Slice 13b block and
  `memory/gotchas.md` for the full mechanism) by adopting Godot's
  `SceneMultiplayer` peer-authentication API, or accept the current
  live-verified 1s mitigation as good enough for now.
- [ ] A new peer joining mid-grace-period (Phase 13a) can transiently
  make more characters "alive" than there are connected peers --
  doesn't corrupt the win condition (every character is counted
  honestly, grace-period-frozen or not) or crash anything, just an
  unusual transient team-size state Phase 13a didn't design for.
  Found by `/check`. See `gameplay/match/match_rules.gd`'s own doc
  comment for the mechanism.
- [ ] `docs/blueprint/05-open-questions.md` is now fully resolved except
  **monetization**, deliberately deferred (2026-09-03) — revisit once
  the core loop is proven fun, not before. All other items (presentation,
  friendly-fire scope, team size, rollback netcode, loadout cadence,
  persistent build-layer scope, setting/tone) are confirmed — see
  `docs/blueprint/05-open-questions.md` and `memory/plan.md`'s "Open
  Questions" section for the decisions and their backlog follow-ups
  below.
- [x] ~~Implement real lag compensation in `HitDetection`~~ — resolved
  by Phase 11, see the Phase 11 entry above.
- [x] ~~Generalize `PlayerSpawner`'s team assignment~~ — resolved by
  Phase 8 (manual team placement in Room Config) and Phase 12 (spawn
  *positions* generalized beyond the old 4 hardcoded points) together.
- [x] ~~Decide how many ability slots a real class kit should have~~ —
  resolved by Phase 15 (Q/E/R/F, 4 class-owned slots) and Phase 16 (T
  is boot_active, a 5th slot owned by the player's boot pick, not the
  class). All 5 previously-reserved InputMap actions are now wired.
- [ ] Decide how (or whether) to replicate ability_q/e/r/f `ActionFsm`
  state to remote `INTERPOLATED` peers — the snapshot RPC is at a
  practical parameter-count limit; likely needs a packed-int
  restructure before a 4th+ ability slot makes this worse.
- [x] ~~Phase 10 (LAN room discovery)~~ — done, see the Phase 10 entry
  above. The roadmap's original Slices 7-10 "lobby" ask is fully
  complete.
- [ ] Broadcast reliability across a real multi-machine LAN (a
  physical router, actual Wi-Fi with possible AP isolation) was never
  tested — out of this dev environment's reach; only same-machine
  2-process headless testing was possible. Manual IP entry
  (`ui/host_join/`) is the guaranteed fallback if it doesn't work on
  the human owner's actual network.
- [x] ~~Give the Room Config Start button an explanation of why it's
  disabled~~ — moot: Phase 14 replaced the host-only Start button
  entirely with a symmetric ready/unready toggle + automatic countdown
  for every player, so this specific control no longer exists in the
  form this item described.
- [x] ~~A real reconnect/grace-period system~~ — resolved by Slices
  13a+13b (grace-period freeze + token-based reconnect), see the
  Completed entries above. This line was stale, left over from before
  those slices shipped.
- [x] ~~A minimal pre-match loadout draft~~ — resolved by Phase 16
  (weapon + boot + perk, a shared 3+3 pool, class + all 3 independently
  pickable). **Still open**: the full PERSISTENT, account-level
  build-investment layer (unlocks, respec economy, currency-gated —
  confirmed scope 2026-09-03: small, per-character, not PoE2's
  ~1,500-node scale) — Phase 16 built the bounded in-match draft the
  persistent layer would eventually feed, not the persistent layer
  itself. Still the single biggest gap between "roadmap done" and the
  fuller MVP proposal in `docs/blueprint/04-mvp-scope.md`.
- [x] ~~A "round" structure for matches~~ — resolved by Phase 17
  (best-of-3, with the confirmed loadout-cadence decision built in: a
  timed inter-round window lets every player re-pick weapon/boot/perk,
  Battlerite Rites-style, before the next round auto-starts).

## Blocked

<!--
- [ ] <task> — waiting on: <reason or person>
-->
