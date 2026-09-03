# 4. A Precedent for Live PvP: Battlerite

[← Index](README.md)

Eslabong proves the content model (classes, champions, abilities,
seasons) can work. It does not prove the *live PvP* half of this
project's brief, because it doesn't ship live PvP: its Challenge Tower
is explicitly asynchronous (submit a roster, fight another player's
submitted roster offline, per the
[Async Multiplayer devlog](sources.md)). Battlerite (Stunlock Studios,
2016 Early Access, spiritual successor to Bloodline Champions) is the
project's second precedent, and it closes exactly that gap: real-time,
skillshot-based, one-fighter-per-player arena combat, played live
against other humans, with an in-match build-customization layer.
Front Mission 5's Survival Simulator played this same role in
`amazing-dungeons`' mecha-tactics research (a shipped mode already
validating a fusion this project is proposing); see
[docs/research/mecha-tactics-inspiration/05](../../../../amazing-dungeons/docs/research/mecha-tactics-inspiration/05-a-precedent-already-exists.md)
for that precedent, referenced here only because the pattern of citing
one is itself the established practice for this project's design
research.

## What Battlerite actually is

Per [Peter Ilves' own account](sources.md) (Battlerite's Game Director,
Stunlock Studios co-founder), Battlerite is "a mashup between World of
Warcraft Arena and a traditional fighting game," branded a "Team Arena
Brawler" because nothing else existing described it. 3v3 and 2v2
matches in a circular arena; per the
[MMOs.com review](sources.md), champions fall into melee/ranged/support
roles, nearly every ability including healing is a skillshot, and there
are explicitly **no items**: "there's nothing you can buy that gives
you an edge over your opponent." Build customization lives entirely in
**Rites**: at the start of each round, the player picks one of three
cards that modifies one of their abilities, re-picked round to round as
the matchup develops.

## Why this precedent matters here

This project's brief asks for real-time, aimable-skillshot, one-fighter
arena combat (matching Battlerite structurally) *and* Path-of-Exile-2
levels of build depth (exceeding what Battlerite's three-card Rites
system offers). Battlerite is proof the combat half works live, in
competitive PvP, at scale (250,000+ players within three weeks of Early
Access per Ilves' own account). It is not proof that PoE2-depth
build customization survives inside that same real-time, round-based
frame; nobody has shipped that combination yet. See
[docs/research/poe2-build-depth-inspiration/05](../poe2-build-depth-inspiration/05-synthesis-amazingclash.md)
and [05. Synthesis](05-synthesis-amazingclash.md) for how this project
proposes resolving that specific tension.

## Design lessons worth carrying forward as-is

- **Discipline over breadth.** Ilves is explicit that Battlerite's
  success over Bloodline Champions came from *not* experimenting with
  new game modes or champion types and instead iterating relentlessly
  on one clear pitch: "Focus on the Arena and the Champions, nothing
  else." Directly relevant to scoping this project's own MVP; see
  [docs/blueprint/04-mvp-scope.md](../../blueprint/04-mvp-scope.md).
- **Netcode and server infrastructure are not an afterthought for
  competitive PvP.** BLC's failure to support players outside
  Europe/US-East with viable latency was, in Ilves' own ranking, the
  second biggest reason Battlerite needed to exist as a rebuild rather
  than a patch. This project inherits `amazing-nauts`'
  server-authoritative model precisely to avoid repeating that mistake;
  see [docs/blueprint/03-networking-and-match-modes.md](../../blueprint/03-networking-and-match-modes.md).
- **Movement-during-abilities is what separates "brawler" from
  "MOBA with WASD."** Ilves calls out that BLC required standing still
  to use most abilities, and that Battlerite's biggest feel improvement
  was letting many attacks allow movement, with per-attack tunable
  slow/accel/decel and post-attack recovery windows. This maps directly
  onto `amazing-nauts`' `MoveDefinition` Resource (startup/active/
  recovery/cancel windows decoupled from animation); see
  [docs/blueprint/03-networking-and-match-modes.md](../../blueprint/03-networking-and-match-modes.md)
  for why that architecture is being inherited rather than re-derived.
- **A monetization/content-gating mistake is also a design lesson.**
  Bloodline Champions' free-to-play model rotated a small free champion
  pool, which Ilves says actively made an already content-thin game
  feel smaller and caused early quits. Not commercially in scope for
  this blueprint, but worth recording in
  [docs/blueprint/05-open-questions.md](../../blueprint/05-open-questions.md)
  so it isn't rediscovered the hard way if monetization is ever
  designed.

## A balance failure mode to design against

Battlerite's "no items, skill only" stance is a deliberate rejection of
exactly the kind of build-driven power variance this project is asking
for. That is not a reason to abandon build depth; it is a warning that
*unbounded* stat-stacking itemization is incompatible with what made
Battlerite's PvP read as fair and skill-determined. See
[docs/research/poe2-build-depth-inspiration/04](../poe2-build-depth-inspiration/04-itemization-uniques-vs-rares.md)
and [05. Synthesis](05-synthesis-amazingclash.md) for how this project
proposes keeping build depth about *expression* (playstyle variety)
rather than open-ended *power budget* growth.
