# Networking Architecture Research

Deep-research reference grounding this project's confirmed decision
(2026-09-03, by the human owner) to keep the server-authoritative
networking model inherited from `amazing-nauts`, rather than adopt
rollback netcode. Gathered after the human owner asked, in-session, how
amazing-clash's two named inspirations — Eslabong and Battlerite —
actually solve real-time PvP netcode, and asked for that answer to be
fortified with outside sources rather than resting on the design-level
lesson already captured in
`docs/research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md`.

This folder is narrower than the other two research pillars
(`docs/research/eslabong-inspiration/`,
`docs/research/poe2-build-depth-inspiration/`): it exists to answer one
specific, already-decided question thoroughly, not to open new design
space.

## Contents

1. [Server-Authoritative Model with Lag Compensation: The Industry-Canonical Pattern](01-server-authoritative-lag-compensation.md)
2. [Battlerite's Actual Netcode: A Direct, Developer-Authored Precedent](02-battlerite-netcode-precedent.md)
3. [Hybrid Approaches and the Rollback Terminology Trap](03-hybrid-approaches-and-rollback-comparison.md)
4. [Synthesis: What This Confirms for AmazingClash](04-synthesis-amazingclash.md)
   (start here if short on time)
5. [Sources](sources.md)

## Confidence Notes

The standout finding is a primary, developer-authored source: Stunlock
Studios' own dev blog on Battlerite's networking, fetched directly (see
[2](02-battlerite-netcode-precedent.md)) — a stronger citation than the
design-postmortem-only source the earlier Eslabong-pillar research had
for this same game. Valve's own Lag Compensation wiki page blocked a
direct fetch (HTTP 403); its content is cited via search-indexed
excerpts instead, flagged explicitly where used. The GDC Vault
recording of Tim Ford's Overwatch netcode talk is access-gated and was
not fetched directly; its content is corroborated through an
independent third-party technical deep-dive that appears to draw on it.
See [Sources](sources.md) for the full breakdown of what was fetched
directly versus cited secondhand, and for one genuine gap this research
could not close (Stunlock's own deliberation between rollback and
server-authoritative for Battlerite specifically was not found
anywhere public).
