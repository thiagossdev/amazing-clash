# 6. Post-MVP Backlog

[← Index](README.md)

Unlike `amazing-dungeons`' equivalent file, this list is not drawn from
playtest feedback on a working build — there is no code yet. It exists
so the deliberate MVP cuts in [4. MVP Scope](04-mvp-scope.md) have a
recorded destination instead of silently disappearing. Expand or
reorder this list once the MVP slice is real and playtested; treat it
as a starting backlog, not a committed roadmap.

## The full persistent build-investment layer

The MVP's small fixed loadout pool ([4](04-mvp-scope.md)) is a
deliberate stand-in for the full system proposed in
[research/poe2-build-depth-inspiration/05](../research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md):
class/champion unlocks, a shared Travel/Minor/Notable/Keystone node
tree, per-ability Evolution/Specialization branches, and a respec
economy. This is the single largest post-MVP objective and the one most
worth prototyping early (even in a rough form) once the MVP proves the
core combat and loadout-draft loop, since it is this project's stated
differentiator.

## Content scale toward Eslabong's own ambition

Growing from the MVP's 3-5 classes toward Eslabong's shipped scale (50
classes, ~100 champions, 500+ abilities, per
[research/eslabong-inspiration/02](../research/eslabong-inspiration/02-class-champion-and-ability-depth.md))
is a content-production track, not a systems one, and should scale
incrementally rather than being treated as a single milestone.

## Club/meta-layer retention structure

Eslabong's season/ladder/market loop
([research/eslabong-inspiration/03](../research/eslabong-inspiration/03-mercenary-club-as-meta-progression.md))
is the validated reason players return to the same account over weeks;
this project's own version (reframed around one built-up champion or a
small owned roster, per
[research/eslabong-inspiration/05](../research/eslabong-inspiration/05-synthesis-amazingclash.md),
not a fielded five) belongs here, after the core PvP loop is proven fun
on its own.

## AI bot-practice mode

Not the same feature as Eslabong's auto-battle (which has no fair
meaning against a live opponent, per
[2. Confirmed Mechanics](02-confirmed-mechanics.md)), but a genuinely
useful post-MVP addition: practice matches against AI-controlled
fighters, for onboarding and for testing loadouts/classes without
needing a second live player.

## In-client Codex

Once class/champion/ability count grows past what a player can hold in
their head, an in-client reference browser (Eslabong's own precedent,
per
[research/eslabong-inspiration/02](../research/eslabong-inspiration/02-class-champion-and-ability-depth.md))
becomes worth building. Not needed at MVP's 3-5-class scale.

## Additional match modes and team sizes

Free-for-all (if team mode ships first per [4](04-mvp-scope.md)),
additional team sizes beyond the MVP's proposed 2v2, and any
PvE/co-op content in the spirit of Eslabong's "Defend the Iron Gate"
(per
[research/eslabong-inspiration/01](../research/eslabong-inspiration/01-arena-combat-and-club-management-loop.md))
are all straightforward extensions of an MVP-proven combat core, not
core-system risk.

## Rollback netcode re-evaluation

Tracked in [5. Open Questions](05-open-questions.md); revisit once real
entity counts and target match length from the MVP are known, rather
than deciding it in advance.
