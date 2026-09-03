# 3. Networking and Match Modes

[← Index](README.md)

## Networking Model: Inherited from `amazing-nauts`

**Confirmed** by the human owner: this project's networking is
server-authoritative, following the model already designed and
documented in `amazing-nauts`'
[08-networking-flow.md](../../../amazing-nauts/docs/blueprint/08-networking-flow.md).
It is reproduced here in summary because it is foundational
architecture this project inherits rather than re-derives; read the
source file directly for the full justification.

```text
CLIENT (every local frame)
  1. Samples input, buffers it with a sequence number
  2. Immediately predicts its OWN character's movement/ability
     activation locally (instant visual response)
  3. Sends the input packet to the server

SERVER (fixed tick, 60Hz)
  1. Consumes buffered inputs per client (small jitter buffer)
  2. Runs the one real simulation; the server is the ONLY authority
     over damage, death, and match state
  3. Hit detection with lag compensation: rewinds hurtboxes to the
     timestamp the attacker actually saw (bounded compensation window)
  4. Sends a delta-compressed snapshot to every client (20-30Hz)

CLIENT (on receiving a snapshot)
  1. Own character: reconciles — discards confirmed inputs, replays
     unconfirmed ones on the authoritative state. Never predicts
     damage taken, only its own movement/activation.
  2. Remote entities: interpolated between the last two snapshots.

RECONNECTION: full (non-delta) snapshot resync.
```

**Why not Rollback**: same reasoning as `amazing-nauts` — Godot doesn't
guarantee the bit-perfect determinism rollback needs, and resimulation
cost scales with live entity count. Unlike `amazing-nauts`' continuous
droid waves, this project's entity count per match is small and
fixed (one fighter per player, plus their active abilities/projectiles)
— worth re-examining as a real option once the MVP's actual entity
count and match length are known, but not assumed here; see
[5. Open Questions](05-open-questions.md).

**Why not P2P**: identical reasoning to `amazing-nauts` — client-side
damage authority is the most basic cheat vector there is, incompatible
with a fair, competitive PvP game.

## Combat Architecture: Also Inherited

- **Frame data as a Resource** (`MoveDefinition`-equivalent): startup,
  active, recovery, and cancel windows live on data, not on animation
  length, so balance and art iterate independently. Same reasoning as
  `amazing-nauts`'
  [12. Architectural Decisions](../../../amazing-nauts/docs/blueprint/12-architectural-decisions.md).
- **Custom hit detection**, outside Godot's general `Area2D`/
  `body_entered` physics callbacks, for guaranteed deterministic
  same-frame hit resolution — required here even more than in
  `amazing-nauts`, since this project's combat is built on aimable
  skillshots where exact hit timing and origin matter for fairness.
- **Event Bus restricted to ownerless events** ("match ended," "score
  changed"); direct parent/child signals for anything with a natural
  owner, to avoid indirection exactly where frame precision matters
  most.

## Match Modes

- **Confirmed**: **Team mode** — multiple human players share a side
  (2v2/3v3/other sizes to be sized during MVP scoping, see
  [4. MVP Scope](04-mvp-scope.md)), each controlling their own fighter.
  Structurally Battlerite's model
  ([research/eslabong-inspiration/04](../research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md)),
  not Eslabong's one-human-many-NPCs model.
- **Confirmed**: **Free-for-all mode** — every fighter for themself,
  echoing Eslabong's own "Chaos Cup" format
  ([research/eslabong-inspiration/01](../research/eslabong-inspiration/01-arena-combat-and-club-management-loop.md)).
- **Confirmed**: **friendly-fire toggle**, per match. Team mode is
  where this matters; free-for-all has no "friendly" fire by
  definition. **Open**: whether the toggle applies to all
  damage/effects or only to area/splash abilities, and what the default
  is per mode — see [5. Open Questions](05-open-questions.md).

## Match State

Originally following `amazing-nauts`' pattern verbatim (`Lobby →
CharacterSelect → Loading → InProgress → PostGame`). **Superseded by
Phase 7** (`memory/plan.md`'s "Slices 7-10", designed via `/think`
2026-09-03): character selection turned out to belong entirely outside
networked match state — it's local and happens before ever connecting
(`ui/character_select/`), not a phase a server/client pair transitions
through together. The real `MatchState.Phase` enum (`core/
match_state.gd`) is `LOBBY → LOADING → IN_PROGRESS → POST_GAME`, with
`Reconnect` still a sub-state of `IN_PROGRESS`, not its own value.
`LOBBY` means "connected, in the Room Config waiting screen"
(`ui/lobby/`); `LOADING` is a real handshake, not a placeholder — the
host's Start button broadcasts it, every peer scene-changes to
`TestArena.tscn`, and the server only advances to `IN_PROGRESS` once
every currently-connected peer has confirmed its own tree finished
building (`net/loading_reporter.gd`). This closes a real race: an
RPC-driven scene change (unlike the old fixed main scene) can let one
peer receive gameplay replication before its own tree is ready to
receive it — confirmed live during Phase 7's implementation. Online
matches still should not pause, consistent with prioritizing the
competitive experience — same reasoning `amazing-nauts` applied.
