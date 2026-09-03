# 1. Arena Combat and Club-Management Loop

[← Index](README.md)

Eslabong's own pitch, verbatim from its
[Steam "About This Game" text](https://store.steampowered.com/app/4560660/Eslabong/):

> Control one fighter in fast-paced arena battles. Aim abilities, move,
> and react in real time to outplay your opponents through positioning
> and timing. Or step back, set tactics, and watch your team fight.

This is also, nearly word for word, the human owner's own brief for
this project. That is not a coincidence to paper over: it means
Eslabong is the correct primary source to study closely, and it means
every place this project's design must diverge from Eslabong needs to
be named explicitly, not left implicit. See
[05. Synthesis](05-synthesis-amazingclash.md) for the full list of
divergences; this file and the next two describe what Eslabong actually
does, as shipped.

## Two control modes, one match

Eslabong lets the player either directly pilot one "captain" fighter
(aimable skillshots, real-time movement and positioning, per the Steam
FAQ's "two main playstyles: control your captain directly or
autobattle") or hand the whole active roster to AI tactics and watch.
Both modes exist inside the same single-player match against AI- or
ghost-controlled opposition; nothing about Eslabong's shipped combat is
live player-versus-player (see
[eslabong-inspiration/02](02-class-champion-and-ability-depth.md) for
what the fighter is capable of, and
[03](03-mercenary-club-as-meta-progression.md) for the roster this
fighter is drawn from).

## The loop, end to end

1. **Recruit** from a rotating [mercenary market](03-mercenary-club-as-meta-progression.md),
   filling role gaps (frontline, ranged, support, mobile disruptor,
   reserve) rather than chasing the strongest-looking name, per the
   [Eslabong Strategy Guide](sources.md).
2. **Fight** in structured leagues, cups (including free-for-all "Chaos
   Cup" and "Allstar" formats per the Steam FAQ), and the PvE co-op
   dungeon "Defend the Iron Gate," a rotating-floor wave mode.
3. **Review** the post-match scoreboard: damage dealt/received, kills,
   deaths, assists, crowd control, healing, friendly-fire damage, and an
   aggregate Impact rating, per the Strategy Guide. This is the game's
   own mechanism for turning a loss into legible information instead of
   just a result.
4. **Reinvest** gold and renown into the roster (training, respec via
   the Time Chamber, medical recovery, scouting) and repeat next season.

## Where "friendly fire" already exists as a concept

The [Two new classes devlog](sources.md) confirms Eslabong's AI is
explicitly tuned to avoid friendly fire from area-effect abilities like
Grenades. Friendly fire is already part of Eslabong's combat math (area
abilities can hit allies); what does not exist yet, because there is no
live PvP, is a *player-facing toggle* for it. That gap, and why this
project needs the toggle where Eslabong does not, is addressed directly
in [05. Synthesis](05-synthesis-amazingclash.md).

## What this file is not

This file describes the shipped structure of Eslabong's match loop, not
this project's own combat resolution model. The combat feel (skillshot
aiming, hit confirm, frame-level responsiveness) is closer to
Battlerite's shipped implementation of a similar pitch; see
[04. A Precedent for Live PvP: Battlerite](04-a-precedent-for-live-pvp-battlerite.md).
