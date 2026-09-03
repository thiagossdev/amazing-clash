# 5. Synthesis: What This Means for AmazingClash

[← Index](README.md)

Read this alongside
[eslabong-inspiration/05-synthesis-amazingclash.md](../eslabong-inspiration/05-synthesis-amazingclash.md).
That file resolves *what kind of game* this is (live PvP, one fighter
per player). This file resolves the harder question underneath the
human owner's brief: how does "Path of Exile 2 level of build depth"
fit inside a fast, real-time, competitively-fair PvP match, when the
two things this research found that get closest to each half of that
ask — PoE2 itself, and Battlerite — sit at opposite extremes and
neither has shipped the combination. Everything below is this
document's own proposed synthesis, not confirmed by the human owner,
and it is the single highest-priority item for review before
[docs/blueprint/](../../blueprint/README.md) is treated as locked.

## The core problem, stated plainly

- PoE2's depth (a ~1,500-node tree, gem/support-gem branching, uniques
  vs. rares) assumes tens of hours per character and an out-of-combat
  pace to navigate it. ([01](01-shared-passive-tree-and-class-identity.md), [04](04-itemization-uniques-vs-rares.md))
- Battlerite's live-PvP fairness (three Rites cards per round, no
  items, "skill only") assumes build depth is deliberately shallow so
  that skill, not build, decides matches. ([docs/research/eslabong-inspiration/04](../eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md))
- The human owner wants both: PoE2-level character-building depth, in a
  real-time PvP arena game.

## Proposed resolution: split depth by timescale, not by removing it

Two separate build-investment layers, matching where PoE2's own two
best-transferring mechanics already sit on a fast/slow spectrum:

1. **Persistent, account-level build investment (slow layer, out of
   match).** A player builds up a given class/champion over many
   matches: unlocking classes and champions (echoing Eslabong's
   roster-as-progression, per
   [eslabong-inspiration/03](../eslabong-inspiration/03-mercenary-club-as-meta-progression.md)),
   investing in a shared, PoE2-style node tree
   ([01](01-shared-passive-tree-and-class-identity.md)) with the same
   Travel/Minor/Notable/Keystone taxonomy, and unlocking Ability
   Evolution/Specialization branches per ability
   ([eslabong-inspiration/02](../eslabong-inspiration/02-class-champion-and-ability-depth.md)).
   This is where "Path of Exile 2 depth" actually lives: wide,
   deliberate, respec-able (per PoE2's own gold-respec precedent,
   [01](01-shared-passive-tree-and-class-identity.md)), and read by the
   *player* between matches, not by an opponent mid-fight.
2. **A bounded in-match loadout, drafted from what's unlocked (fast
   layer, inside a match).** Before a match starts, a player selects
   from their unlocked pool: which specialization branch is active per
   ability, which weapon-linked passive set(s) are equipped (per the
   dual-specialization pattern in
   [03](03-weapon-swap-dual-specialization.md)), and which
   identity-defining equipment pieces are slotted, inside a **fixed
   slot count and/or a point budget**, not open-ended stacking. This is
   the layer an opponent can scout, read, and counter-pick against —
   structurally Battlerite's Rites moment, but drawing from a much
   deeper unlocked pool than Battlerite's fixed three cards.

## Why this specific split, and not a different one

- It reuses two mechanisms both research pillars already validated
  independently (PoE2's respec-able persistent tree; Battlerite's
  pre-round, opponent-visible pick) instead of inventing a third
  unproven pattern.
- It answers [02](02-skill-gem-simplification-vs-depth.md) directly:
  GGG's own lesson is that *scaffolding friction* (socket colors) can
  be removed without removing *underlying depth* (support-gem
  branching). Here, the scaffolding being removed is asking a player to
  navigate 1,500 nodes' worth of decisions in the two minutes before a
  match starts; the underlying depth (having made those choices at all,
  over dozens of matches) is preserved.
- It answers the itemization tension in
  [04](04-itemization-uniques-vs-rares.md): identity-defining equipment
  stays a *build-diversity* lever bounded by the match's own slot/point
  budget, never an open-ended *power* lever, which is the specific
  thing Battlerite's "no items" stance protects and this project cannot
  discard without breaking PvP fairness.

## What this proposal deliberately leaves open

- **Exact tree size and node count** for the persistent layer. PoE2's
  ~1,500 nodes fits a 60+ hour ARPG; this project's equivalent number
  is undetermined and belongs in
  [docs/blueprint/05-open-questions.md](../../blueprint/05-open-questions.md),
  not assumed here.
- **Whether loadout selection happens once per match, or (like
  Battlerite's Rites) can be adjusted between rounds/rematches within a
  session.** Round-adjustable is more reactive and closer to
  Battlerite; match-locked is simpler to implement and to balance
  first. Also tracked as an open question.
- **Whether unlocking classes/champions/tree nodes is time-gated,
  currency-gated, both, or account-wide vs. per-champion.** This is a
  progression-economy design decision this research does not attempt
  to make; flagged in
  [docs/blueprint/05-open-questions.md](../../blueprint/05-open-questions.md).

## The one thing this proposal treats as non-negotiable

Whatever the exact numbers end up being, the split itself — persistent
depth lives outside the match, in-match selection stays bounded and
opponent-legible — is this document's strongest recommendation,
because it is the only design in either research pillar that lets "PoE2
depth" and "fair live PvP" both be true at once instead of trading one
for the other.
