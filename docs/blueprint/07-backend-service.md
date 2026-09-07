# 7. Backend Service: Accounts, Rooms, Matchmaking, Signaling

[← Index](README.md)

**Status (2026-09-05): proposed direction, human owner's own decision,
not yet implemented on either side.** This is the first design for the
persistent-account/matchmaking layer this project has never had —
today every peer is just an ephemeral `peer_id` for the lifetime of one
`NetworkManager` connection, with no login, no account, no match
history anywhere. It also answers part of
[3. Networking and Match Modes](03-networking-and-match-modes.md)'s
"Future: Internet Play" section, which left signaling/TURN hosting and
matchmaking explicitly **not yet decided** — see that section's own
note.

**Confirmed sequencing (human owner's own explicit instruction,
2026-09-05): the Rails service is built and proven out standalone
first** (accounts, login, rooms, matchmaking, working against its own
test suite) **before any Godot-side integration work starts.** The
Godot client only starts talking to this API once it actually exists
and is reachable. Nothing in this file is scheduled as an amazing-clash
roadmap phase yet; treat it as the reference to build the Rails side
against, and to `/think` from once the API is live and it's time to
wire Godot to it.

## What this service owns

- Accounts: username/password login. First time this project has any
  persistent player identity at all.
- Rooms: a room's existence, its code, its host, its lifecycle state
  (`waiting` / `in_progress` / `finished`) — bookkeeping, not the live
  `MatchState.Phase` state machine itself.
- Matches: one row per played match — mode, settings, final result.
  Written from **events**, not polled from live state.
- Matchmaking / room listing over the internet (`net/lan_discovery.gd`
  is LAN-only UDP broadcast and stays exactly as it is; this is the
  separate internet-facing equivalent `03`'s own doc comment already
  flags as needed).
- WebRTC signaling (SDP offer/answer + ICE candidate exchange) via
  Action Cable, so `WebRTCMultiplayerPeer` connections can be
  established over the internet without manual port-forwarding.
- Rating: a single `users.rating` column (simple Elo/Glicko-style),
  updated once per finished match. **Not** a separately maintained
  "leaderboard" table — a stored ranking table drifts out of sync with
  the source data; a leaderboard is a query (`ORDER BY rating`) over
  `users`, not its own persisted state.

## What this service never owns

Same rule this project already enforces for `net/game_log.gd` and
`net/replay_recorder.gd`, both of which write to local files on the
host's own machine, never a database: **no per-tick simulation state
ever reaches this service.** Never position, velocity, aim direction,
raw input, or physics. Only persistent, occasional events: `match
created`, `match started`, `match finished`, `player joined`, `player
left`, `result submitted`. The moment anything resembling per-frame
data would touch this backend, that's a sign the design has drifted —
stop and reconsider before adding the column/call.

The match's own live simulation stays exactly as
[3](03-networking-and-match-modes.md) already describes: server-
authoritative, with the HOST peer as that authority. Swapping
`ENetMultiplayerPeer` for `WebRTCMultiplayerPeer` (already scoped in
that file, isolated to `net/network_manager.gd`) only changes how the
HOST and CLIENT peers find and connect to each other through NAT — it
is explicitly **not** a move to a symmetric P2P trust model. The
connection *topology* between the 2 Godot processes is peer-to-peer
(no relay in the data path once WebRTC negotiation completes); match
*authority* stays entirely on the HOST, unchanged from how ENet works
today.

## Architecture

```text
                    ┌──────────────────────┐
                    │      Rails 8.1       │
                    │                      │
                    │ SQLite               │
                    │                      │
                    │ users                │
                    │ rooms                │
                    │ matches              │
                    │ match_players        │
                    │                      │
                    │ Action Cable         │
                    │ Signaling            │
                    └──────────┬───────────┘
                               │
                               │ signaling (SDP/ICE)
                               │
                        ┌──────┴──────┐
                        │             │
                   ┌────▼────┐   ┌────▼────┐
                   │  STUN   │   │  TURN   │
                   └────┬────┘   └────┬────┘
                        │  NAT        │ fallback (symmetric
                        │  traversal  │ NAT, STUN alone fails)
                        └──────┬──────┘
                  ┌────────────┴────────────┐
                  │                         │
             ┌────▼─────┐             ┌────▼─────┐
             │ Godot A  │             │ Godot B  │
             │   HOST   │             │  CLIENT  │
             │(authority)│            │          │
             └────┬─────┘             └────┬─────┘
                  │                         │
                  └══ P2P (transport) ══════┘
                    gameplay, authority on HOST
```

TURN is drawn as a real fallback path, not an optional extra: STUN
alone cannot punch through symmetric NAT, and this project's own
open-questions note already flags TURN as likely necessary, not a
maybe.

## Datastore: SQLite, deliberately

SQLite is enough for this stage — a single Rails process, one
VPS/machine, no concurrent-writer scale problem yet:

```text
VPS
├── Rails
├── SQLite
└── Action Cable
```

Redis/Sidekiq are not required to start, depending on how the
WebSocket/Active Job stack ends up configured. When (not if, should
this project grow that far) multiple Rails instances are needed behind
a load balancer, that's the natural point to move off SQLite to
PostgreSQL — not before, and not "because it's production". Keep the
ActiveRecord layer clean (no raw SQLite-specific SQL in application
code) so that migration stays mechanical when it actually happens.

```text
             Load Balancer
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
    Rails #1             Rails #2
        │                   │
        └─────────┬─────────┘
                  │
               PostgreSQL
```

## Schema

```ruby
# db/schema.rb

create_table "users" do |t|
  t.string :username, null: false
  t.string :password_digest, null: false
  t.integer :rating, null: false, default: 1000
  t.timestamps
end

create_table "rooms" do |t|
  t.string :code, null: false
  t.references :host, null: false, foreign_key: { to_table: :users }
  t.string :status, null: false # waiting | in_progress | finished
  t.timestamps
end

create_table "matches" do |t|
  t.references :room, null: false
  t.string :status, null: false # loading | in_progress | round_intermission | finished
  t.string :match_mode, null: false # team | free_for_all
  t.boolean :friendly_fire, null: false, default: false
  t.integer :round_target, null: false, default: 2 # best-of-3 today, see core/match_state.gd's ROUND_TARGET
  t.integer :winning_team # null until decided
  t.boolean :is_draw, null: false, default: false
  t.datetime :started_at
  t.datetime :finished_at
  t.timestamps
end

create_table "match_players" do |t|
  t.references :match, null: false
  t.references :user, null: false
  t.integer :team_id # null in free_for_all
  t.string :class_id, null: false   # vanguard | ranged_mage | warden
  t.string :weapon_id, null: false  # iron_sword | twin_daggers | warhammer
  t.string :boot_id, null: false
  t.string :perk_id, null: false
  t.integer :round_wins, null: false, default: 0
  t.timestamps
end
```

`match_players`'s 4 loadout columns (`class_id`/`weapon_id`/`boot_id`/
`perk_id`) mirror the 4 fully independent loadout axes
`net/lobby_state.gd` already tracks in-match (Phase 16 — see
`docs/blueprint/02-confirmed-mechanics.md`). `round_target`/
`round_wins` exist because a match is already best-of-N
(`core/match_state.gd`'s `ROUND_TARGET`), not first-to-one-win — a
schema that only stored a single winner with no round count would lose
real match history. `winning_team`/`is_draw` mirror `MatchState.
winning_team`/`WinCondition.DRAW`'s own existing semantics
(`gameplay/match/`), rather than inventing a different shape for the
same concept.

Indexes:

```text
rooms.code
rooms.status
matches.room_id
matches.status
match_players.match_id
match_players.user_id
users.username
```

## The integration surface Godot needs to grow later

Not built yet, and not implied for free by the signaling channel
above: the Godot **HOST** process needs an HTTP client reporting
persistent events to the Rails API. The natural call sites are the
exact same hooks that already call `GameLog.info()` today —
`MatchState.enter_in_progress()`, `resolve_round_result()`,
`enter_post_game()` — since those are already this project's own
"something persistence-worthy just happened" boundary. This is real,
net-new work on the Godot side, not a side effect of adding signaling;
name it explicitly when scoping the integration phase rather than
assuming it comes bundled.

## Still open

Carried over from [3](03-networking-and-match-modes.md)'s own "not yet
decided" note, now narrower:

- Where the signaling/TURN service is hosted, and who pays for it.
- Which STUN/TURN provider to use.
- Whether login is required to play a match at all, or a guest-without-
  account path stays available (this project has never required
  identity to play before now).
- Rating algorithm specifics (Elo vs. Glicko vs. something simpler) —
  `users.rating`'s existence is proposed here, its update formula is
  not.
- Whether matchmaking (auto-pairing players) ships alongside this, or
  room codes stay the only way to form a room for longer, mirroring
  `03`'s own still-open framing of that question.

Once these settle, record the decisions back into
[5. Open Questions](05-open-questions.md) the same way every other
architecture decision in this blueprint is tracked — don't let them
live only in this file's own "still open" list once they're actually
answered.
