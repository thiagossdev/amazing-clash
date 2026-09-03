# 3. Weapon Swap and Dual Specialization

[← Index](README.md)

Per the [dving.net guide](sources.md), Path of Exile 2's Weapon
Specialisation system adds a second, smaller passive layer tied to
which of two equipped weapon sets is active:

- A portion of a character's passive points can be allocated as
  **Weapon Set I** nodes, **Weapon Set II** nodes, or **globally
  allocated** nodes that apply regardless of active weapon.
- Search-corroborated coverage (unverified by direct fetch, see
  [sources.md](sources.md)) describes this as extending to full
  passive-tree auto-swap: a character can carry one passive
  configuration tuned for fire damage and another tuned for cold
  damage, with the game automatically switching both the equipped
  weapon and the active passive configuration when the player casts a
  skill bound to that set.
- The guide frames this explicitly as **beginner-friendly with
  veteran min-max headroom**: a player uninterested in managing two
  weapon sets can leave the points as ordinary global passives instead,
  making the system optional depth rather than mandatory complexity.

## Why this is relevant to a real-time arena fighter

A single fighter with two weapon-linked build configurations, swapped
automatically based on which ability is used, is a mechanic that
translates cleanly into a fast, reactive combat loop: it rewards
planning (which two loadouts complement each other) without asking for
slow, deliberate menu navigation mid-fight, since the swap itself is
automatic and tied to input already being pressed for its ability
effect. This is a meaningfully better fit for this project's real-time
constraint than the base passive tree in
[01](01-shared-passive-tree-and-class-identity.md), which assumes
between-fights allocation, not a mid-fight decision.

See [05. Synthesis](05-synthesis-amazingclash.md) for how this maps
onto a proposed loadout-slot structure for AmazingClash.
