# 2. Confirmed Mechanics

[← Index](README.md)

The canonical reference. Every mechanic below links back to the
research file that grounds it. **Confirmed** means the human owner
explicitly stated it during this design pass; anything else is this
blueprint's proposed default, awaiting sign-off, marked **proposed**.

## Core Loop

- **Confirmed**: each player controls exactly one fighter, for the
  whole match, in real time — movement, positioning, and aimable
  skillshot abilities. Not a squad-of-five roster-management game. Per
  the human owner's own brief, quoted in
  [research/eslabong-inspiration/01](../research/eslabong-inspiration/01-arena-combat-and-club-management-loop.md)
  and resolved in
  [research/eslabong-inspiration/05](../research/eslabong-inspiration/05-synthesis-amazingclash.md).
- **Confirmed**: this is live PvP against other human players, not
  Eslabong's asynchronous, roster-vs-ghost-roster Challenge Tower model.
  Per
  [research/eslabong-inspiration/05](../research/eslabong-inspiration/05-synthesis-amazingclash.md).

## Networking

- **Confirmed**: server-authoritative architecture, following
  `amazing-nauts`' model (client prediction/reconciliation on the
  player's own character, lag-compensated hit detection, snapshot
  interpolation for remote entities). Full detail in
  [3. Networking and Match Modes](03-networking-and-match-modes.md).

## Match Modes

- **Confirmed**: both a team-based mode and a free-for-all
  (every-fighter-for-themself) mode are supported.
- **Confirmed**: friendly fire is a per-match toggle, not a fixed rule.
  Extends a damage interaction Eslabong's own AI already reasons about
  (avoiding friendly-fire splash from area abilities), per
  [research/eslabong-inspiration/01](../research/eslabong-inspiration/01-arena-combat-and-club-management-loop.md).
  Exact scope (all damage vs. area-abilities-only; per-mode default) is
  **open**, see [5. Open Questions](05-open-questions.md).

## Build Depth

- **Proposed**: two build-investment layers split by timescale.
  1. A **persistent, account-level layer** (out of match): unlocking
     classes/champions, a shared node tree with a Travel/Minor/Notable/
     Keystone taxonomy, and per-ability Evolution/Specialization
     branches, respec-able for a cost. Grounded in
     [research/poe2-build-depth-inspiration/01](../research/poe2-build-depth-inspiration/01-shared-passive-tree-and-class-identity.md)
     and
     [research/eslabong-inspiration/02](../research/eslabong-inspiration/02-class-champion-and-ability-depth.md).
  2. A **bounded, pre-match loadout** (in match): drafted from the
     unlocked pool above under a fixed slot count and/or point budget,
     visible to and counter-playable by the opponent. Grounded in
     [research/eslabong-inspiration/04](../research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md)
     (Battlerite's Rites) and
     [research/poe2-build-depth-inspiration/03](../research/poe2-build-depth-inspiration/03-weapon-swap-dual-specialization.md).
  Full reasoning and open sub-questions in
  [research/poe2-build-depth-inspiration/05](../research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md).
- **Proposed**: identity-defining equipment is a build-*diversity*
  lever bounded by the loadout budget above, never an open-ended
  *power* lever. Grounded in
  [research/poe2-build-depth-inspiration/04](../research/poe2-build-depth-inspiration/04-itemization-uniques-vs-rares.md)
  and the fairness lesson in
  [research/eslabong-inspiration/04](../research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md).

## Combat Feel

- **Proposed**: frame data (startup/active/recovery/cancel windows)
  lives on a Resource, decoupled from animation, and hit detection is
  custom rather than relying on Godot's general physics callbacks — the
  same architectural decisions `amazing-nauts` made for the same reason
  (deterministic same-frame hit resolution). Full detail in
  [3. Networking and Match Modes](03-networking-and-match-modes.md).
- **Proposed**: abilities allow movement during use, tunable per-move
  (slow/accelerate/decelerate/recovery), rather than Bloodline
  Champions' stand-still-to-cast model. Grounded in
  [research/eslabong-inspiration/04](../research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md).

## Explicitly Rejected

- Fielding a roster of five fighters per match (Eslabong's structure).
- Auto-battle as a way to play a live match (no fair meaning against a
  human opponent; an AI bot-practice mode is a separate, post-MVP idea,
  see [6. Post-MVP Backlog](06-post-mvp-backlog.md)).
- Unbounded, open-ended item power growth (breaks PvP fairness; see
  [research/eslabong-inspiration/04](../research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md)).
