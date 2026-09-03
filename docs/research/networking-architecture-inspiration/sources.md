# Sources

[← Index](README.md)

## Fetched and cited directly

- [Dev Blog #8 – Networking Movement, Stunlock Blog](https://blog.stunlock.com/dev-blog-008/):
  primary, developer-authored source on Battlerite's actual network
  architecture. The single most load-bearing citation in this folder —
  see [2](02-battlerite-netcode-precedent.md). Confirms
  server-authoritative movement/ability/projectile-collision
  resolution, client-side prediction with server correction, and the
  "you don't remove the latency, you just decide where to hide it"
  design principle.
- [Fast-Paced Multiplayer (Part III): Client-Side Prediction and Server Reconciliation, Gabriel Gambetta](https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html):
  independent, widely-cited technical reference, not tied to a single
  shipped game. Fetched directly; used for the general
  prediction/reconciliation/interpolation mechanism description in
  [1](01-server-authoritative-lag-compensation.md) and
  [3](03-hybrid-approaches-and-rollback-comparison.md).
- [Fast-Paced Multiplayer (Part IV): Lag Compensation, Gabriel Gambetta](https://www.gabrielgambetta.com/lag-compensation.html):
  fetched directly. Primary source for the timestamped-shot /
  server-reconstructs-the-past mechanism and the "favor the shooter"
  trade-off in [1](01-server-authoritative-lag-compensation.md).
- [Game Backend Deep Dive: Overwatch, Edgegap](https://edgegap.com/blog/game-backend-deep-dive-overwatch-2016-netcode-architecture-rollback):
  third-party technical deep-dive, fetched directly. Source for
  Overwatch's ECS-based server-authoritative architecture, its
  aggressive default-prediction stance, and the explicit contrast with
  peer-to-peer rollback (used in
  [1](01-server-authoritative-lag-compensation.md) and to identify the
  rollback-terminology overlap flagged in
  [3](03-hybrid-approaches-and-rollback-comparison.md)).

## Cited via search-indexed excerpts (direct fetch blocked)

- [Lag Compensation, Valve Developer Community](https://developer.valvesoftware.com/wiki/Lag_compensation):
  direct fetch returned HTTP 403 during this research (likely
  bot-blocking on Valve's wiki). Quotes used in
  [1](01-server-authoritative-lag-compensation.md) ("rewind time when
  processing a usercmd", "history of all recent player positions for
  one second") come from the search engine's indexed excerpt of this
  exact page, not a direct fetch — flagged here per this project's own
  sourcing convention (see
  [eslabong-inspiration/sources.md](../eslabong-inspiration/sources.md)'s
  note on its own failed fetch). Treated as reliable given it is
  Valve's own developer wiki being excerpted, not a secondary
  paraphrase, but not independently re-verified by this research.
- ["Overwatch" Gameplay Architecture and Netcode, Tim Ford, GDC 2017](https://www.gdcvault.com/play/1024001/-Overwatch-Gameplay-Architecture-and):
  the primary developer-authored talk this whole subfield of research
  cites; the GDC Vault recording itself is paywalled/access-gated and
  was not fetched directly. Description used in
  [1](01-server-authoritative-lag-compensation.md) is sourced from
  search-indexed summaries of the talk, corroborated independently by
  the Edgegap deep-dive above (which does appear to draw on the talk's
  actual content). Treated as directionally reliable, not
  verbatim-quoted.

## Not found / genuine gap

- No public source (GDC talk, dev blog, postmortem, or technical
  interview) was found describing Stunlock Studios' own *deliberation*
  between rollback and server-authoritative netcode for Battlerite
  specifically, or a fully-specified lag-compensation system for their
  hit detection — see the "honest gap" note in
  [2](02-battlerite-netcode-precedent.md). This research documents what
  they built (confirmed, developer-authored), not why they didn't build
  the alternative.

## Cross-referenced from prior research

- Peter Ilves' Battlerite postmortem and the Bloodline Champions
  netcode-failure lesson are already cited in
  [docs/research/eslabong-inspiration/sources.md](../eslabong-inspiration/sources.md);
  not re-fetched or re-listed here to avoid duplication.
