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
- **Friendly fire is a per-match toggle**: **confirmed** as a concept;
  exact scope is still open, see below.

## Still open

- **2D or 3D presentation.** `project.godot` sets
  `3d/physics_engine="Jolt Physics"`, but that could be a Godot
  project-creation default rather than a deliberate choice, the same
  ambiguity `amazing-dungeons` flagged and later resolved explicitly
  (see
  [amazing-dungeons/docs/blueprint/01](../../../amazing-dungeons/docs/blueprint/01-executive-summary.md)).
  Eslabong itself is top-down 2D pixel art (per its Steam tags);
  Battlerite is fixed-camera 3D. Needs an explicit answer, not an
  inherited default.
- **Friendly-fire toggle scope.** Does it gate all damage between
  teammates, or only area/splash abilities (the specific interaction
  Eslabong's own AI already reasons about, per
  [research/eslabong-inspiration/01](../research/eslabong-inspiration/01-arena-combat-and-club-management-loop.md))?
  What is the default per mode?
- **Team size.** [4. MVP Scope](04-mvp-scope.md) proposes 2v2 as a
  starting point; not confirmed. Battlerite shipped both 2v2 and 3v3
  (per
  [research/eslabong-inspiration/04](../research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md));
  which size (or whether to support more than one) is open.
- **Persistent build-layer size and gating.** Node/tree size for the
  account-level layer proposed in
  [research/poe2-build-depth-inspiration/05](../research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md)
  is undetermined; PoE2's own ~1,500 nodes is explicitly not assumed to
  transfer. Whether unlocks are time-gated, currency-gated, both, or
  account-wide vs. per-champion is also undecided.
- **Loadout cadence.** Whether the pre-match loadout is locked for the
  whole match, or adjustable between rounds/rematches within a session
  (closer to Battlerite's per-round Rites) — see
  [research/poe2-build-depth-inspiration/05](../research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md)
  for why this is not a small detail: it changes how "opponent-legible"
  the build layer actually is mid-session.
- **Rollback netcode, reconsidered.** [3](03-networking-and-match-modes.md)
  inherits `amazing-nauts`' server-authoritative reasoning, but notes
  this project's per-match entity count (one fighter per player plus
  active abilities) is much smaller and more bounded than
  `amazing-nauts`' continuous-droid-wave scenario, the specific
  condition that made rollback a poor fit there. Worth an explicit
  revisit once real entity counts and target match length are known,
  rather than assuming the inherited answer transfers unexamined.
- **Setting and tone.** Eslabong's medieval fantasy is this blueprint's
  working reference, not a locked decision — no research or owner
  conversation has settled this the way `amazing-dungeons` settled its
  post-apocalyptic-salvage setting and comic tone.
- **Monetization**, noted for later per Battlerite's own cautionary
  history (Bloodline Champions' free-to-play champion-gating actively
  shrank an already content-thin game and drove early quits, per
  [research/eslabong-inspiration/04](../research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md)).
  Not a blocker for this blueprint or the MVP; flagged so it isn't
  rediscovered the hard way whenever it does come up.
