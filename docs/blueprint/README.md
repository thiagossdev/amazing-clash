# AmazingClash Blueprint

The design blueprint, built from `docs/research/eslabong-inspiration/`
and `docs/research/poe2-build-depth-inspiration/`, plus the networking
and combat architecture inherited directly from `amazing-nauts`. This
is deliberately a lean blueprint rather than a full production
blueprint (compare `amazing-nauts`' 15-file `docs/blueprint/`): this
project has no code yet, so a detailed roadmap and module diagrams
would be speculative. Expand this folder once an MVP slice exists to
design against — the same approach `amazing-dungeons` took for the same
reason.

Most of this blueprint is **proposed**, not yet reviewed with the human
owner in a dedicated design pass the way `amazing-dungeons`' blueprint
was; see [2. Confirmed Mechanics](02-confirmed-mechanics.md) for exactly
which decisions are locked in versus still open, and
[5. Open Questions](05-open-questions.md) for the review agenda this
blueprint proposes.

## Contents

1. [Executive Summary](01-executive-summary.md)
2. [Confirmed Mechanics](02-confirmed-mechanics.md) (the canonical
   reference: confirmed vs. proposed, with every mechanic linked back
   to its grounding research)
3. [Networking and Match Modes](03-networking-and-match-modes.md)
   (the `amazing-nauts`-inherited server-authoritative model; team,
   free-for-all, and friendly-fire toggle)
4. [MVP Scope](04-mvp-scope.md) (proposed, not yet approved)
5. [Open Questions](05-open-questions.md) (this blueprint's review
   agenda — most items here are still genuinely open)
6. [Post-MVP Backlog](06-post-mvp-backlog.md) (destinations for what
   the MVP deliberately cuts, not yet playtest-informed)

## Relationship to the research folders

This blueprint does not re-derive design reasoning already established
in the research. Every mechanic in
[2](02-confirmed-mechanics.md) links back to the research file that
grounds it; read the research if you need the reasoning, read this
blueprint if you need the current, consolidated state of the design.
The single most important open item in the whole blueprint is the
build-depth proposal in
[research/poe2-build-depth-inspiration/05](../research/poe2-build-depth-inspiration/05-synthesis-amazingclash.md):
review that before treating anything downstream of it as settled.
