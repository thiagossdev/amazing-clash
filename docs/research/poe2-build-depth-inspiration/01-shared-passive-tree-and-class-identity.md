# 1. Shared Passive Tree and Class Identity

[← Index](README.md)

Path of Exile 2's passive skill tree is the clearest existing example
of a design goal this project shares: a huge, shared build space that
still gives every class a distinct identity. Per the
[dving.net guide](sources.md):

- The tree radiates outward from a center; **every class starts in a
  different region**, thematically tied to attributes (Intelligence
  near Lightning/Spells, Dexterity near Cold/Projectiles, Strength near
  Fire/Melee), but **the entire tree becomes reachable from any class**
  once a player travels far enough from their starting area.
- Two classes share each attribute combination (e.g. the Sorceress
  starts elemental-focused, the Witch starts minion-focused, both from
  an Intelligence-adjacent start), so starting position differentiates
  early builds without hard-walling later ones.
- This is explicitly what lets an off-theme build exist at all: a
  melee-focused Sorceress is possible precisely because the tree is
  shared, not siloed per class.

## Node taxonomy

Four tiers, smallest to most build-defining:

1. **Travel nodes** — a binary/ternary choice of Strength, Dexterity,
   or Intelligence, mostly there to connect regions of the tree.
2. **Minor Passives** — small, generic modifiers (e.g. Fire Damage,
   Projectile Damage, Energy Shield).
3. **Notable Passives** — sit at the end of a sequence of minor
   passives, grant a meaningfully larger, sometimes conditional bonus
   (the guide's example: increased Spell Damage while Energy Shield is
   full).
4. **Keystones** — rare, build-defining, and often trade-off-shaped
   (the guide's example: Chaos Inoculation sets Life to 1 in exchange
   for total Chaos Damage immunity).

This taxonomy is a genuinely reusable idea independent of node count:
a small number of node *tiers* with escalating build-defining weight,
rather than either a flat list of bonuses or a fully bespoke tree per
class. Community guides outside this folder's directly-fetched sources
put the total tree size at roughly 1,500 nodes and 124 base passive
points (see [sources.md](sources.md) for why that figure is flagged as
unverified-by-direct-fetch rather than cited with full confidence).

## Respec is not punished

Passive allocation is not permanent: gold buys a respec. This matters
for how this project should treat its own build-investment system —
see [05. Synthesis](05-synthesis-amazingclash.md) and
[docs/research/eslabong-inspiration/03](../eslabong-inspiration/03-mercenary-club-as-meta-progression.md),
which notes Eslabong's own Time Chamber serves exactly this same
purpose.

## Why this doesn't transfer to AmazingClash unmodified

A 1,500-node tree assumes a play session measured in tens of hours per
character, with respec as an occasional, deliberate correction. A
fast, session-based PvP arena match cannot ask a player to navigate a
tree that size mid-match, and if the tree is entirely a pre-match,
persistent, out-of-match investment instead, then depth stops being
something the opponent can read or react to inside a single match,
which is a real difference from how Battlerite's Rites work (picked and
adjusted round to round, visible to the opponent as the match unfolds;
see
[docs/research/eslabong-inspiration/04](../eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md)).
[05. Synthesis](05-synthesis-amazingclash.md) proposes keeping the node
taxonomy and the persistent-investment model, scaled down, while
preserving a smaller in-match decision layer for the moment-to-moment
reactivity Battlerite's model provides and a size-1,500 tree cannot.
