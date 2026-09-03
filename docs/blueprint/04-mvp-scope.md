# 4. MVP Scope (Proposed)

[← Index](README.md)

Proposed, not yet approved by the human owner. Sized against Battlerite
Game Director Peter Ilves' own account of what made Battlerite succeed
where Bloodline Champions didn't: "Focus on the Arena and the
Champions, nothing else," per
[research/eslabong-inspiration/04](../research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md).
This is the smallest playable slice that exercises every confirmed
mechanic from [2. Confirmed Mechanics](02-confirmed-mechanics.md); it
is the baseline for the atomic task breakdown in `memory/progress.md`.

## In scope for the first playable slice

- **One arena map.** Enough to prove combat feel and networking; map
  variety is a content problem to solve once the core loop is proven,
  not a systems one.
- **Small vertical slice of classes/champions, not the full ambition.**
  3 to 5 classes/champions with orthogonal archetypes (a melee
  frontline, a ranged skillshot damage dealer, a support/control
  fighter), echoing `amazing-nauts`' own confirmed reasoning for
  picking orthogonal launch heroes over an arbitrary or similar set
  (see
  [amazing-nauts/docs/blueprint/12](../../../amazing-nauts/docs/blueprint/12-architectural-decisions.md)).
  Eslabong's 50/100/500+ scale (see
  [research/eslabong-inspiration/02](../research/eslabong-inspiration/02-class-champion-and-ability-depth.md))
  is the project's long-term content ambition, not the MVP's.
- **One match mode to start.** Team mode (smallest viable team size,
  e.g. 2v2) is proposed over free-for-all first, since it validates
  friendly fire as a real mechanic; free-for-all is a straightforward
  mode-rules variant on the same combat core once team mode works, not
  a separate system.
- **Friendly-fire toggle implemented from the start**, not deferred: it
  is a rules flag on the same damage pipeline the MVP needs anyway, and
  deferring it risks discovering the damage pipeline wasn't built to
  support it.
- **The bounded, pre-match loadout system, in a minimal form.** A fixed
  small number of loadout slots (fewer than the eventual target),
  populated from a small hand-authored pool per class rather than a
  fully unlocked persistent-progression system. This is what proves the
  "split depth by timescale" proposal
  ([research/poe2-build-depth-inspiration/05](../research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md))
  is actually buildable, without requiring the full persistent-layer
  economy (unlocks, respec cost, a full node tree) to exist yet.
- **Server-authoritative networking, fully implemented per
  [3](03-networking-and-match-modes.md).** Not deferrable: retrofitting
  netcode onto combat built without it is far more expensive than
  building it in from the start, the same lesson `amazing-nauts` states
  directly.

## Explicitly out of scope for the first slice

- The full persistent, account-level build-investment layer (unlocks,
  a shared node tree, respec economy) — the MVP's loadout draws from a
  small fixed pool instead. Proposed in
  [2](02-confirmed-mechanics.md#build-depth); the full system is a
  post-MVP objective, see [6. Post-MVP Backlog](06-post-mvp-backlog.md).
- Eslabong's full content scale (50 classes, 100 champions, 500+
  abilities) — a content-production problem once the core loop and
  loadout system are proven, not an MVP blocker.
- Free-for-all mode, if team mode is built first (see above); trivial
  to add once the damage/mode-rules pipeline exists, not worth building
  twice in parallel.
- An in-client Codex/wiki (per
  [research/eslabong-inspiration/02](../research/eslabong-inspiration/02-class-champion-and-ability-depth.md)) —
  useful at content scale, not needed to validate 3-5 classes.
- Rollback netcode reconsideration (per
  [3](03-networking-and-match-modes.md)) — server-authoritative ships
  first; revisit only if playtesting surfaces a specific latency-feel
  problem it would solve.
- Any club-management meta-layer structure (market, roster facilities,
  seasons) — the MVP validates combat and the loadout draft; the
  Eslabong-derived meta-layer retention mechanic
  ([research/eslabong-inspiration/03](../research/eslabong-inspiration/03-mercenary-club-as-meta-progression.md))
  is a post-MVP objective.

## What "done" looks like for this slice

Two players (or two clients on one machine, for local verification) can
join a match, each pick a loadout for one of 3-5 classes, fight live in
one arena with server-authoritative hit resolution, toggle friendly
fire between matches and observe the damage rule actually change, and
reach a clear win condition. That loop, played with two different
loadouts on the same class producing visibly different fights, is the
slice's actual verification criterion, not a feature checklist.
