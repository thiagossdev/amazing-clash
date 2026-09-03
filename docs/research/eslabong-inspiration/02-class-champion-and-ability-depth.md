# 2. Class, Champion, and Ability Depth

[← Index](README.md)

This is the file that grounds the human owner's explicit ask for
"profundidade de criar personagens... caminhando pra um Path of Exile 2
no nível de customização": Eslabong is already, on its own terms, an
unusually content-dense arena game for a solo-developed Early Access
title, and its own content strategy is the seed this project's build
system grows from. The PoE2-specific half of that ask is developed
fully in the sibling folder
[docs/research/poe2-build-depth-inspiration/](../poe2-build-depth-inspiration/README.md);
this file stays inside what Eslabong itself ships.

## The declared scope

Per the [Steam store page](sources.md) and the developer's own Early
Access FAQ:

- **50 playable classes** (Halberdier, Hunter, Archmage, Chronomaster,
  Necromancer, Astralwing, Reaper Mage, Thunderclaw, and more, added
  incrementally patch over patch per the devlogs)
- **~100 champions**: specific named characters within those classes,
  each with base stats and, per the
  [Strategy Guide](sources.md), randomized personality, growth style,
  and starting skill kit, so class identity alone does not fully
  determine how a given champion should be built or played
- **500+ abilities and spells**, confirmed still growing (the July 2026
  devlog alone added 40+ in one patch)

## Two build-depth mechanisms already shipped

1. **Randomized ability rolls per champion instance.** The
   [Chronomaster devlog](sources.md) states this directly: "Since
   abilities are randomized in Eslabong, not every chronomaster will be
   the same." Two champions of the same class are not guaranteed to
   play the same; recruiting is itself a build decision, not just a
   roster-count decision.
2. **Ability Evolution/Specialization.** Also from the Chronomaster
   devlog: starting at level 20, and continuing at levels 10, 12, 14,
   16, 18, 20 per the follow-up search coverage, a fighter can either
   learn a new ability or power up one it already has (+10% potency,
   duration, and reduced cooldown per level), and at level 20 each of
   the game's near-400 (at time of writing) abilities gains a fork of
   two specialization choices, with the developer explicitly stating
   more choices are planned for full release.

This is Eslabong's own analog to a skill-gem-support-gem system: a
base ability that branches into meaningfully different versions rather
than just scaling numbers. It is a real precedent for going deeper, not
a hypothetical one, which is exactly why
[docs/research/poe2-build-depth-inspiration/](../poe2-build-depth-inspiration/README.md)
studies a system that took this same idea (a skill that branches and
scales) much further, to see how far it can go before it stops fitting
a fast real-time match.

## Stat model (the surface the ability layer sits on)

Per the Strategy Guide: HP, Attack, Defense, and Speed, each mapped to
a role (frontline anchor, damage dealer, tank/protector,
skirmisher/diver/escape). Investment (leveling, gear) is recommended to
reinforce a fighter's existing job rather than spread evenly, and skill
selection is evaluated against four questions: does it reinforce the
role, does it solve the team's last loss, does it combine with an
ally's kit, can the fighter use it without becoming exposed. That
decision framework — role-first, then matchup-fit — is worth carrying
forward regardless of what this project's own build system ends up
looking like structurally.

## In-game reference tooling

A later devlog (Codex and demo update) adds a Wiki/Codex accessible
in-client: every class and champion, their skills, and starting base
attributes, browsable without leaving the game. Worth noting as a
UX precedent given how large 50 classes × 500+ abilities gets for a
player to hold in their head; see
[docs/blueprint/04-mvp-scope.md](../../blueprint/04-mvp-scope.md) for
whether an in-client Codex belongs in this project's MVP or its
post-MVP backlog.
