# 4. Itemization: Uniques vs. Rares

[← Index](README.md)

Per the [PCGamesN interview with Jonathan Rogers](sources.md), Path of
Exile 2's own team is still actively re-deriving what a Unique item is
*for*: "Even the question of, 'What is a unique in Path of Exile 2?'
We got that wrong initially." The resolved-for-1.0 answer Rogers
describes is a specific tension, held on purpose rather than resolved
away: early-game Uniques should be strong enough to matter *for a
while*, with some designed to combo into continued relevance at
endgame, while ordinary Rare items are expected to "fuel most of the
build" over the long run. In his words: "there's always a tension,
because we want Rares to still matter."

## Why this tension is directly relevant here

This project cannot import PoE2's itemization pacing wholesale — a
loot-drop power curve across a 60+ hour ARPG campaign has no equivalent
in a session-based PvP arena match, and unbounded item power would
directly contradict the fairness lesson in
[docs/research/eslabong-inspiration/04](../eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md)
(Battlerite's "no items, skill only" stance, and its reviewer's own
observation: "there's nothing you can buy that gives you an edge over
your opponent"). What *is* transferable is the underlying design
question Rogers is answering: items (or, for this project, equipment/
gear choices) should be allowed to define a build's *identity and
playstyle* strongly, while a separate, broader layer (Rares, for
PoE2; this project's shared passive/ability layer, per
[01](01-shared-passive-tree-and-class-identity.md)) carries the bulk of
long-run power growth. Applied to a PvP arena game where raw power
cannot be allowed to diverge between opponents, the resolution changes
shape: identity-defining items become a *build-diversity* lever inside
a power budget bounded by the match's own rules (a draft, a point
budget, or a fixed loadout-slot count), not a *power* lever at all. See
[05. Synthesis](05-synthesis-amazingclash.md) for the specific proposal.
