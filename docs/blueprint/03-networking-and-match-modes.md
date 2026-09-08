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
cost scales with live entity count. **Confirmed by the human owner
(2026-09-03): staying server-authoritative, not moving to rollback.**
This is grounded in dedicated research, not just the inherited
reasoning above — see
[docs/research/networking-architecture-inspiration/](../research/networking-architecture-inspiration/README.md),
which found this project's own named live-PvP precedent, Battlerite,
uses this identical model (developer-authored confirmation, not just a
design-level lesson), and that rollback and a real dedicated-server
authority are close to structurally incompatible regardless of entity
count. See [5. Open Questions](05-open-questions.md) for the resolved
entry.

**Why not P2P**: identical reasoning to `amazing-nauts` — client-side
damage authority is the most basic cheat vector there is, incompatible
with a fair, competitive PvP game.

**Lag compensation**: implemented (Phase 11, 2026-09-03) — `HitDetection`
now rewinds hurtboxes to the timestamp the attacker actually saw, via a
bounded server-side position-history buffer. See `memory/plan.md`'s
Slice 11 block for the shipped implementation.

## Future: Internet Play Without Manual Port-Forwarding

**Confirmed direction (2026-09-04), not yet scheduled as a roadmap
phase**: the human owner wants players to be able to host/join over
the real internet without manually configuring port-forwarding on
their router — the current direct-connect flow (`net/network_manager.gd`,
`ENetMultiplayerPeer` over raw UDP) works on a LAN or once a port is
already open, but a typical home NAT blocks an unsolicited inbound
connection otherwise.

**Chosen path: swap the transport from ENet to `WebRTCMultiplayerPeer`**,
using WebRTC's built-in NAT traversal (STUN, with TURN as a fallback
for symmetric NAT where STUN alone can't punch through). This is a
**transport-layer change only** — it does not revisit "Why not P2P"
above: the server stays fully authoritative over damage/death/match
state exactly as today; WebRTC here just carries the same
server-authoritative traffic through NAT, it is not a move to a P2P
trust model.

**Confirmed 2026-09-04 by direct code audit: this project's ENet usage
is already isolated to a single file.** Every other file (`@rpc`
methods, `MultiplayerSpawner`, `multiplayer.get_unique_id()`/
`get_peers()`, `multiplayer.server_disconnected`, etc.) is built on
Godot's transport-agnostic `MultiplayerPeer`/`SceneMultiplayer` layer
and needs zero changes. The only real touchpoints are in
`net/network_manager.gd`:

- `host()`/`join()` create an `ENetMultiplayerPeer` directly — would
  become a `WebRTCMultiplayerPeer` wrapping one `WebRTCPeerConnection`/
  `WebRTCDataChannel` pair per remote peer.
- `get_peer_rtt_ms()` reads `ENetPacketPeer.PEER_ROUND_TRIP_TIME`, an
  ENet-only stat — WebRTC has no equivalent built-in, so this needs a
  small custom ping/pong RPC instead.

**What the swap doesn't cover, and this project doesn't have yet**:
WebRTC cannot establish a connection on its own — it needs an
out-of-band **signaling channel** to exchange SDP offer/answer and ICE
candidates before any P2P link exists, which has no equivalent in
ENet's direct-connect model. This project has no signaling service
today (even a minimal one, e.g. a small WebSocket relay). It also
needs a **STUN server** (several free public ones exist) and likely a
**TURN server** as a fallback for peers behind symmetric NAT (TURN
relays traffic instead of punching through, and typically isn't free
to run at scale, unlike STUN). `net/lan_discovery.gd`'s own UDP-
broadcast room discovery is unrelated (it never touches the transport
peer) but is itself LAN-only — internet play needs a separate
room-listing mechanism (a lobby/matchmaking service), tracked
separately as still out of scope, see `memory/plan.md`'s "Deferred /
Out of Scope" section.

**Not yet decided, needs its own `/think` when this is picked up**:
where the signaling (and TURN, if needed) service is hosted and who
pays for it, which STUN/TURN provider to use, and whether a
room-listing/matchmaking service ships alongside this or stays a
separate, later effort.

**Signaling/accounts/matchmaking: built and live (2026-09-08, updated
from the 2026-09-05 proposal)** — see [7. Backend Service](07-backend-service.md).
A Rails + SQLite service (Action Cable for signaling), deployed
standalone and proven out before any Godot-side integration, per the
confirmed sequencing above. Godot-side integration itself (the HTTP
client, the actual `WebRTCMultiplayerPeer` swap) has not started yet.
Still not decided: TURN provider/hosting, real Steam credentials — see
that file's own "Still open" section.

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
