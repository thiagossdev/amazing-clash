# 3. Hybrid Approaches and the Rollback Terminology Trap

[← Index](README.md)

## The two things "rollback" can mean — and why conflating them matters

This research surfaced a genuine terminology collision worth flagging
explicitly, since it could otherwise make a future re-read of
"rollback" in some source look like it contradicts the confirmed
decision:

1. **Fighting-game rollback netcode (GGPO-style).** No single server
   holds ground truth. Every peer predicts *every other peer's* input,
   and re-simulates its *entire local world* — not just its own
   character — when a real input arrives that disagrees with the
   prediction. This requires bit-perfect determinism across all peers,
   because divergent simulation on different machines is exactly what
   causes a visible desync. This is the specific technique
   `docs/blueprint/03-networking-and-match-modes.md`'s "Why not
   Rollback" section, and this project's confirmed decision, are about.
2. **"Client rolls back and replays its own inputs."** Some netcode
   write-ups — including a third-party technical deep-dive on
   Overwatch's architecture used in this research (see
   [Sources](sources.md)) — use this phrase loosely to describe
   ordinary **server reconciliation**: a client corrects *its own*
   predicted state to match the server's authoritative snapshot, then
   replays only its own buffered unconfirmed inputs forward. This has
   nothing to do with peer-to-peer determinism or resimulating other
   players — it's the same mechanism already implemented in this
   project's `ClientPredictor`, and in Battlerite's
   ([2](02-battlerite-netcode-precedent.md)).

Only sense (1) is the thing being declined here. Sense (2) is already
built and staying.

## Documented hybrid patterns that stop short of full rollback

No source found in this research describes a shipped competitive action
game blending full peer-to-peer rollback with a server authority — the
two models are close to mutually exclusive by construction (rollback's
whole premise is *no* single authoritative simulation to defer to).
What does exist, and is directly relevant to a small-entity-count arena
game like this one, are hybrids **within** the server-authoritative
family:

- **Client-side hit registration with server-side validation.** An
  older, now largely abandoned pattern (early Counter-Strike-era
  titles) where the client itself judged whether a shot/attack hit and
  told the server, which mostly trusted it. This is a well-documented
  cheat vector (a modified client can simply lie about a hit), and is
  exactly why `docs/blueprint/03-networking-and-match-modes.md`'s "Why
  not P2P" section rejects client-side damage authority — this project
  already made the correct call here, matching where the industry
  converged (the server validates or fully owns hit resolution, never
  the client alone).
- **Selective prediction scope.** Overwatch's own architecture
  ([1](01-server-authoritative-lag-compensation.md)) predicts movement,
  ability activation, *and* projectile travel locally for feel, while
  still resolving the actual hit/damage server-side only — exactly this
  project's own current split (`ClientPredictor` predicts
  movement/action-FSM state locally; `CombatResolver`/`HitDetection`
  resolve hits server-only, and `Projectile` already advances
  deterministically client-side without per-tick sync, per
  `memory/plan.md`'s Slice 2b notes). This is the realistic "hybrid"
  available to a server-authoritative game: predict liberally for feel,
  never predict the outcome that matters (did this land, how much
  damage).
- **Lag compensation as the missing piece, not an alternative
  architecture.** Rather than a different model from
  server-authoritative prediction/reconciliation, lag compensation
  ([1](01-server-authoritative-lag-compensation.md)) is the piece that
  makes server-side hit *validation* fair under latency instead of
  unfair-by-default. It is additive to what this project already has,
  not a fork in the road.

## Comparison, for the record

| | Server-authoritative + prediction/reconciliation + lag comp (this project, Battlerite, Overwatch, Source engine) | Rollback (GGPO-style, fighting games) |
| --- | --- | --- |
| Ground truth | One server | None — every peer's local resimulation *is* the truth once inputs are known |
| Determinism requirement | Only the server needs to be internally consistent | Every peer must simulate bit-identically |
| Resimulation cost scales with | Nothing per-peer (server sim runs once) | Live entity count, on every peer, every rollback |
| Cheat resistance | High — damage/death decided by one trusted party | Lower by default (no single arbiter) unless one peer is also treated as authoritative |
| Best fit | Many-entity, hit-confirm-heavy games with a real dedicated server | Small, fixed entity count (typically 2 characters), latency-critical neutral-game timing, historically P2P |

This project's shape — a small but *not tiny* entity count (fighters
plus abilities plus projectiles, team sizes now confirmed configurable
up to 5v5, see `docs/blueprint/05-open-questions.md`), a real
dedicated/authoritative server already built and tested, and cheat
resistance already proven to matter in practice (the Phase 1 speed-hack
fix, `memory/gotchas.md`) — sits squarely in the left column, alongside
both of its own named inspirations.
