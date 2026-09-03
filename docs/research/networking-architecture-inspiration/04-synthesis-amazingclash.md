# 4. Synthesis: What This Confirms for AmazingClash

[← Index](README.md)

## The decision this folder exists to fortify, not reopen

The human owner confirmed (2026-09-03) that amazing-clash keeps the
server-authoritative networking model inherited from `amazing-nauts`,
rather than adopting rollback netcode. This folder was commissioned
specifically to ground that decision in outside sources, after the
design-lesson-only citation in
`docs/research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md`
turned out not to cover the actual technical question.

## What the research confirms

- **Every source examined — Valve/Source, Overwatch, and, most
  importantly, Battlerite itself ([2](02-battlerite-netcode-precedent.md))
  — uses the same family of architecture this project already has**:
  one authoritative server owning movement/ability/hit resolution,
  clients predicting their own actions locally and reconciling against
  server snapshots, remote entities interpolated. This is not a design
  accident inherited passively from `amazing-nauts`; it is the pattern
  every comparable shipped competitive game, including this project's
  own named live-PvP precedent, independently converged on.
- **Rollback netcode remains correctly rejected**, for the same reason
  `docs/blueprint/03-networking-and-match-modes.md` already gave
  (Godot doesn't guarantee bit-perfect cross-peer determinism;
  resimulation cost scales with live entity count) — reinforced here by
  [3](03-hybrid-approaches-and-rollback-comparison.md)'s finding that
  rollback and a real dedicated-server authority are close to
  structurally incompatible: rollback's entire premise is the
  *absence* of a single ground truth, which this project already has
  and depends on (server-only combat resolution, already caught one
  real speed-hack attempt in Phase 1 via that authority). Team size
  being confirmed configurable up to 5v5
  (`docs/blueprint/05-open-questions.md`) makes this more true, not
  less — more live entities per match is the direction that favors
  server-authoritative over rollback, not the other way around.
- **P2P/client-authoritative hit registration remains correctly
  rejected** — [3](03-hybrid-approaches-and-rollback-comparison.md)
  found this is a known, largely-abandoned cheat vector in the games
  that tried it historically, matching the reasoning
  `docs/blueprint/03-networking-and-match-modes.md`'s "Why not P2P"
  section already gives.

## A concrete, real implementation gap this research surfaced

`docs/blueprint/03-networking-and-match-modes.md` already *describes*
lag compensation ("Hit detection with lag compensation: rewinds
hurtboxes to the timestamp the attacker actually saw") as part of the
intended architecture. It is **not implemented in the current
codebase** — a direct check of `gameplay/combat/` and `net/` found no
position-history buffer, no rewind logic, and no timestamp-based
hurtbox reconstruction; `HitDetection` currently resolves hits against
each character's *current* server-tick position only.

This is a real, load-bearing gap for a game whose combat centers on
precise skillshot/melee timing, exactly like the genre this research
studied (Source-engine shooters, Overwatch). Without it, a
high-latency player's target will appear to be somewhere they've
already moved away from by the time the server processes the hit, and
low-latency players get an implicit, unacknowledged advantage instead
of the *documented, symmetrical* trade-off Valve and Gambetta describe
([1](01-server-authoritative-lag-compensation.md)).

**Suggested shape, not a spec** (implementation is out of scope for
this research pass):

1. Server keeps a short rolling history (Valve's own reference keeps
   ~1 second) of each character's hurtbox position, keyed by server
   tick/timestamp.
2. Each input packet from a client already carries, or should carry,
   the client's own view of "current time" — the tick it was acting on.
3. When `HitDetection`/`CombatResolver` resolves an attack, it looks up
   the *target's* hurtbox position from that history at the attacker's
   claimed timestamp (bounded to a max compensation window, to prevent
   a client claiming an arbitrarily old, favorable timestamp), not the
   target's live position.
4. This only changes *where* a hit is validated against, not the
   existing server-authoritative resolution flow — additive to
   `HitDetection`, not a replacement for it.

Tracked as a backlog item in `memory/progress.md`.

## Bottom line

The decision to stay server-authoritative was already correct before
this research; what this folder adds is that it is now grounded in
three independent, technically-detailed sources — one of them this
project's own named live-PvP precedent, in the developers' own words —
rather than one design-level postmortem citation. The one genuine
finding worth acting on is not "reconsider the architecture," it's
"finish implementing the lag-compensation piece the architecture
already calls for."
