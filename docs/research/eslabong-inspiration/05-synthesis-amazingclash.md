# 5. Synthesis: What This Means for AmazingClash

[← Index](README.md)

Read this section first if you only read one page of this folder, and
read
[poe2-build-depth-inspiration/05-synthesis-amazingclash.md](../poe2-build-depth-inspiration/05-synthesis-amazingclash.md)
alongside it; this is where the two research pillars combine. Most of
what follows is a proposed resolution for the human owner to confirm,
in the same spirit as `amazing-dungeons`' blueprint: some forks are
already resolved by the owner's own brief and are marked **confirmed**,
the rest are this document's reasoned synthesis, not yet signed off.

## The fork that matters most: club-of-five vs. one fighter, live

Eslabong is, structurally, a single-player squad-management game: you
own and field five mercenaries, control one as captain, and let AI
(or an asynchronous ghost of another player's roster) fight the rest.
**Confirmed by the human owner's own brief**, quoted directly from
Eslabong's own "About This Game" text in
[01](01-arena-combat-and-club-management-loop.md): "control one fighter
in fast-paced arena battles." AmazingClash is not a club-of-five
management game. Each player controls exactly one fighter, for the
whole match, against other live human players — structurally closer to
Battlerite's one-champion-per-player model
([04](04-a-precedent-for-live-pvp-battlerite.md)) or a MOBA/hero
shooter than to Eslabong's own roster-management loop. "Team mode"
therefore means multiple human players sharing a side, not one human
commanding several AI-controlled teammates.

## Confirmed: live PvP, not asynchronous Challenge-Tower-style PvP

Per the human owner's direction, this project is PvP multiplayer with
an **authoritative server**, following the same model already validated
in `amazing-nauts`. Eslabong's Challenge Tower — submit a roster, fight
another player's *offline, previously-submitted* team, no live
interaction — is explicitly not the model. See
[docs/blueprint/03-networking-and-match-modes.md](../../blueprint/03-networking-and-match-modes.md)
for the inherited server-authoritative + prediction/reconciliation + lag
compensation model, which comes from `amazing-nauts`'
[08-networking-flow.md](../../../../amazing-nauts/docs/blueprint/08-networking-flow.md),
not from either game studied in this folder.

## Confirmed: team mode and free-for-all, with a friendly-fire toggle

Per the human owner's direction: match structure supports both a
team-based mode and a free-for-all (every fighter for themself) mode,
and friendly fire is a per-match toggle rather than a fixed rule. This
is a natural extension of something Eslabong already has half-built:
its AI is already tuned to avoid friendly-fire damage from area
abilities ([01](01-arena-combat-and-club-management-loop.md)); this
project makes that damage interaction a first-class, player-facing
setting instead of something only the AI reasons about. Exact toggle
scope (all damage, or area abilities only; per-mode default) is tracked
in [docs/blueprint/03-networking-and-match-modes.md](../../blueprint/03-networking-and-match-modes.md).

## What carries over from Eslabong as-is

- The **combat register**: real-time movement, aimable skillshot
  abilities, positioning and timing as the skill expression, per
  [01](01-arena-combat-and-club-management-loop.md).
- The **content ambition**: many classes, many named champions per
  class, hundreds of abilities, as the content strategy, per
  [02](02-class-champion-and-ability-depth.md). Scope for an MVP slice
  of this is not the full 50/100/500+; see
  [docs/blueprint/04-mvp-scope.md](../../blueprint/04-mvp-scope.md).
- **Ability Evolution/Specialization**, per [02](02-class-champion-and-ability-depth.md),
  as the shape this project's own ability-branching system should start
  from: a base ability that forks into meaningfully different versions,
  not just a bigger number.
- The **seasonal ladder and market-driven meta-layer**, per
  [03](03-mercenary-club-as-meta-progression.md), reframed around one
  owned/built-up champion (or a small owned roster of champions you
  pick from match to match, MOBA-style) rather than a fielded squad of
  five.
- **Medieval fantasy setting and tone**, as a starting-point reference,
  not a locked decision; see
  [docs/blueprint/05-open-questions.md](../../blueprint/05-open-questions.md).

## What does not carry over

- **Fielding a roster of five per match.** Rejected per the "one
  fighter" confirmation above.
- **Auto-battle as a way to play a live match.** Auto-battle exists in
  Eslabong because the opposition is AI or an offline ghost; it has no
  fair meaning against a live human opponent controlling their own
  fighter. An AI-controlled bot-match mode for practice is a reasonable
  post-MVP idea (see
  [docs/blueprint/06-post-mvp-backlog.md](../../blueprint/06-post-mvp-backlog.md)),
  but it is not the same feature and should not be described as one.
- **The asynchronous Challenge Tower model**, superseded by live,
  server-authoritative PvP per the confirmation above.

## The open tension this folder cannot resolve alone

Eslabong's Ability Evolution/Specialization system is real build depth,
but it is nowhere near Path of Exile 2's depth, and PoE2's actual depth
mechanisms (a 1,500+-node shared passive tree, weapon-swap dual
specialization, uniques vs. rares) were built for a slow-paced,
long-session ARPG, not a fast real-time PvP arena match. Battlerite's
own answer to "how much build depth fits in a live arena match" was
deliberately shallow (three cards, no items, "skill only") specifically
to keep PvP fair. This project is asking for something between those
two poles that, as far as this research found, nobody has shipped yet.
[docs/research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md](../poe2-build-depth-inspiration/05-synthesis-amazingclash.md)
proposes a specific resolution (persistent, account-level build
investment drafted into fast matches, bounded to expression rather than
raw power); treat it as this project's most important pending
confirmation, more important than any single class or ability design.
