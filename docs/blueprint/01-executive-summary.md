# 1. Executive Summary

[← Index](README.md)

## The Pitch

AmazingClash is a real-time, one-fighter-per-player PvP arena combat
game: each player directly controls a single fighter with aimable
skillshot abilities, competing live against other human players through
positioning, timing, and reaction, in either team or free-for-all
matches with a per-match friendly-fire toggle. Character depth is the
project's differentiator: classes, champions, equipment, and a
persistent, respec-able build-investment layer aimed at Path of Exile
2's level of customization, drafted into a fixed, opponent-legible
loadout before each match so that build depth never comes at the cost
of live PvP fairness.

The design is the direct fusion of two deep-research pillars, plus one
architectural inheritance from a sibling project:

- `docs/research/eslabong-inspiration/`: Eslabong (the game the human
  owner named directly, and the source of this project's own core
  pitch, quoted verbatim in
  [research/eslabong-inspiration/01](../research/eslabong-inspiration/01-arena-combat-and-club-management-loop.md)),
  plus Battlerite as the precedent for the live-PvP half of the brief
  Eslabong itself does not ship.
- `docs/research/poe2-build-depth-inspiration/`: Path of Exile 2's
  shared passive tree, skill-gem design, weapon-swap specialization,
  and itemization philosophy, studied specifically for what survives
  the transition from a slow ARPG to a fast PvP arena match.
- `amazing-nauts`' server-authoritative networking and real-time combat
  architecture (frame data as a Resource, custom hit detection, the
  Event Bus discipline), inherited rather than re-researched because it
  is this studio's own validated prior art for exactly this kind of
  real-time competitive combat in Godot. See
  [3. Networking and Match Modes](03-networking-and-match-modes.md).

Both research folders' synthesis documents
([eslabong-inspiration/05](../research/eslabong-inspiration/05-synthesis-amazingclash.md),
[poe2-build-depth-inspiration/05](../research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md))
converge on the project's central design proposal, not yet confirmed by
the human owner: split build depth by timescale. Persistent,
PoE2-depth build investment happens between matches; a bounded,
Battlerite-scale loadout is drafted from that investment before each
match and is what an opponent actually sees and can counter-play. This
is the resolution to a real tension neither Eslabong nor Battlerite nor
Path of Exile 2 has had to solve on its own, because none of them
combine live PvP fairness with this level of build ambition at the same
time.

## Engine and Platform

Godot 4.8, Forward Plus rendering, per `project.godot`.
`3d/physics_engine="Jolt Physics"` is set, but whether presentation is
2D (matching Eslabong's own top-down pixel-art presentation) or 3D
(matching Battlerite's fixed-camera 3D arenas) is not yet decided; see
[5. Open Questions](05-open-questions.md). Networking targets Godot's
high-level multiplayer API on top of the server-authoritative model
described in [3](03-networking-and-match-modes.md), matching
`amazing-nauts`' own stack.

## What "Confirmed" Means in This Blueprint

[2. Confirmed Mechanics](02-confirmed-mechanics.md) distinguishes
decisions the human owner explicitly stated (PvP multiplayer, an
authoritative server following `amazing-nauts`' model, team and
free-for-all modes, a friendly-fire toggle, "control one fighter") from
decisions this blueprint proposes as reasoned defaults, still awaiting
sign-off (most notably the entire build-depth split above). Do not
treat a mechanic as settled because it appears in this document; check
its confirmation status in file 2 directly.
