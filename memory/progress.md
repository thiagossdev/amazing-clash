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

## Backlog (next up)

- [ ] Phase 2: combat core (melee **and** aimed-skillshot/projectile
  hit detection, damage pipeline, frame data as a `Resource`, state
  machine) + Hitbox/Projectile Viewer + Debug Overlay additions, pulled
  forward per `memory/plan.md`'s roadmap — see that file for the full
  6-phase sequence.
- [ ] Review `docs/blueprint/05-open-questions.md` with the human owner
  — most items are still genuinely open (friendly-fire toggle scope,
  team size, persistent-tree size/gating, loadout cadence, rollback
  reconsideration, setting/tone). The build-depth split in
  `docs/research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md`
  is the single highest-priority item to confirm before Phase 3
  (Ability Framework) needs a real answer.

## Blocked

<!--
- [ ] <task> — waiting on: <reason or person>
-->
