# 5. Open Questions

[← Index](README.md)

Ambiguities that need an answer from the human owner before the
relevant part of the design counts as settled. Nothing here is resolved
silently. This blueprint is freshly synthesized from one research pass;
unlike `amazing-dungeons`' equivalent file, most items below have not
yet been through a design-review conversation with the human owner and
should be treated as a starting agenda for one, not a historical record.

## Resolved

Recorded here only to avoid drifting out of sync with
[2. Confirmed Mechanics](02-confirmed-mechanics.md), where the full
detail lives:

- Player controls exactly **one fighter**, not a squad: **confirmed**.
- Live PvP with an **authoritative server**, following `amazing-nauts`:
  **confirmed**.
- **Team mode and free-for-all mode**, both supported: **confirmed**.
- **Friendly fire is a per-match toggle**: **confirmed**, and its scope
  is now also confirmed (2026-09-03): it gates **all damage** between
  teammates, not just area/splash abilities. This is also the only
  mechanically possible reading today, since no AoE/splash ability type
  exists in this codebase (`docs/blueprint/03-networking-and-match-modes.md`'s
  `friendly_fire_enabled` gate already implements this).
- **Team size**: **confirmed** (2026-09-03) as **configurable, not
  fixed at 2v2** — the mode must support 2v2, 3v3, 4v4, and 5v5.
  Implemented today only as the fixed `index % 2` split (Phase 5/6);
  generalizing spawn points, HUD, and match-start gating to an
  arbitrary, chosen team size is tracked as a backlog item (see
  `memory/progress.md`).
- **Loadout cadence**: **confirmed** (2026-09-03) as **adjustable
  between rounds/rematches**, Battlerite Rites-style, not locked for
  the whole match. This requires a "round" concept this project does
  not have yet (current matches run once to a single win condition,
  Phase 5/6) — building that structure is tracked as a backlog item
  (see `memory/progress.md`).
- **Persistent build-layer size and gating**: **confirmed** (2026-09-03)
  as **small in scope, per-character, and currency-gated** — explicitly
  not PoE2's ~1,500-node scale. Design/implementation of this layer is
  tracked as a backlog item (see `memory/progress.md`); the account-
  level vs. per-champion split in
  [research/poe2-build-depth-inspiration/05](../research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md)
  is now resolved toward per-character.
- **Setting and tone**: **confirmed** (2026-09-03) as **medieval
  fantasy, Eslabong-style** — the working reference in
  [docs/research/eslabong-inspiration/](../research/eslabong-inspiration/)
  is now the settled direction, not just a placeholder.
- **Monetization**: **deliberately deferred** (2026-09-03), not decided
  now — see Still open below for the reasoning that still applies.
- **2D or 3D presentation**: **confirmed 2D top-down** (2026-09-02,
  per `memory/plan.md`) — the `3d/physics_engine="Jolt Physics"` line
  in `project.godot` was Godot project-creation template leftover, not
  a deliberate choice, and was removed in Phase 1. This bullet was
  never synced back to this file when that was confirmed; correcting
  the drift now rather than leaving it listed as open.
- **Rollback netcode, reconsidered**: **confirmed** (2026-09-03) —
  staying server-authoritative, not moving to rollback. Grounded in
  dedicated research (not just the inherited `amazing-nauts` reasoning
  in [3](03-networking-and-match-modes.md)): this project's own named
  live-PvP precedent, Battlerite, was confirmed via a primary
  developer source to use this identical model, and rollback was found
  to be close to structurally incompatible with having a real
  dedicated-server authority at all, independent of entity count — see
  [docs/research/networking-architecture-inspiration/](../research/networking-architecture-inspiration/README.md).
  One real gap the research surfaced: lag compensation (rewinding
  hurtboxes to the attacker's observed timestamp) is described in
  [3](03-networking-and-match-modes.md) as intended architecture but is
  not yet implemented — tracked as a backlog item in
  `memory/progress.md`.
- **Persistent accounts, rooms, matchmaking, and WebRTC signaling
  backend**: **confirmed built and live** (2026-09-08) — a separate
  Rails 8.1 + SQLite app (`amazing-clash-backend`, local path
  `amazing-clash-app`), deployed at `https://clash.amazing.thi.dev.br`.
  Answers [3](03-networking-and-match-modes.md)'s "Future: Internet
  Play" question in full on the backend side: accounts (email/password
  + Steam), room codes + public browse (no auto-pairing queue in v1),
  match history + Elo rating (K=32, untuned), and Action Cable
  signaling for the eventual `WebRTCMultiplayerPeer` swap. See
  [7. Backend Service](07-backend-service.md) for the full API contract
  — **Godot-side integration itself (the HTTP client at the
  `GameLog.info()` call sites, the actual transport swap) has not
  started**, per the human owner's own confirmed sequencing (build the
  Rails side standalone first).

## Still open

- **Monetization**, noted for later per Battlerite's own cautionary
  history (Bloodline Champions' free-to-play champion-gating actively
  shrank an already content-thin game and drove early quits, per
  [research/eslabong-inspiration/04](../research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md)).
  Not a blocker for this blueprint or the MVP; flagged so it isn't
  rediscovered the hard way whenever it does come up.
- **TURN hosting/provider** for the backend's WebRTC signaling — not
  chosen or configured yet. Blocks real internet play for players
  behind symmetric NAT specifically, not the Godot-side integration
  work itself (STUN alone covers most home NATs). See
  [7](07-backend-service.md)'s "Still open."
- **Real Steam credentials** (App ID + Steamworks partner Web API key)
  for the backend's Steam login — it runs in mock mode in production
  today. See [7](07-backend-service.md)'s "Still open."
- **Elo K-factor tuning** — the backend ships a concrete K=32 default,
  not yet tuned against real match data. See
  [7](07-backend-service.md)'s "Still open."
