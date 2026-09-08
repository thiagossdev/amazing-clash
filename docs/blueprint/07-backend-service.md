# 7. Backend Service: Accounts, Rooms, Matchmaking, Signaling

[← Index](README.md)

**Status (2026-09-08): implemented, deployed, and live — code-complete
on the Rails side.** This supersedes the 2026-09-05 proposal this file
used to contain: every decision below is either shipped code or an
explicit, still-open infra item, not a design sketch. **Godot-side
integration has not started** — that is the next piece of work this
file exists to brief, per the human owner's own confirmed sequencing
(build the Rails service standalone and prove it out first, then wire
Godot to it — see [3](03-networking-and-match-modes.md#future-internet-play-without-manual-port-forwarding)).

The service lives in a **separate repo**, `amazing-clash-backend`
(local path `amazing-clash-app` — the GitHub repo was renamed after the
local directory was created; `amazing-clash-app` is legacy, not a
different project), deployed at **`https://clash.amazing.thi.dev.br`**.
Its own docs — the authoritative, code-verified reference, deeper than
this summary — live at `docs/backend/*.md` in that repo:
`01-overview.md`, `02-schema.md`, `03-accounts-and-auth.md`,
`04-characters.md`, `05-rooms-and-matchmaking.md`,
`06-matches-and-rating.md`, `07-signaling.md`, `08-api-reference.md`.
Read this file for the Godot-integration briefing; read those for
backend implementation detail (why a column/validation/lock exists).

It was **not** a blank slate: that repo already shipped a full
email+password + TOTP MFA + WebAuthn passkey account system (personal
starter template) before any of this was built. Everything below is
new on top of that, not a replacement for it.

## What this service owns

- **Accounts.** Email+password login, or Steam login (session-ticket
  verification, no browser popup), or both linked to one account.
- **Characters.** A player's roster of named, class-based characters
  with an editable loadout (weapon/boot/perk). **Created and edited
  only in-game** — the backend's own web UI can only view them,
  permanently, by design.
- **Rooms.** A room's existence, code, host, and lifecycle
  (`waiting → in_progress → finished`) plus lobby membership
  (`room_players`) — bookkeeping, not `MatchState.Phase` itself.
- **Matches.** One row per played match — mode, settings, final result
  — written from **events the Godot HOST client reports**, never
  polled from live state.
- **Matchmaking / room listing over the internet.** `net/lan_discovery.gd`
  stays exactly as it is (LAN-only UDP broadcast); this is the separate
  internet-facing equivalent: room codes + a public listing of
  `waiting` rooms. **No auto-pairing queue in v1.**
- **WebRTC signaling** (SDP offer/answer + ICE candidate exchange) via
  Action Cable, so `WebRTCMultiplayerPeer` connections can be
  established over the internet without manual port-forwarding.
- **Rating.** `users.rating` (Elo, K=32), updated once per finished
  match. Not a separate leaderboard table — a leaderboard is a query
  (`ORDER BY rating`) over `users`.

## What this service never owns

**No per-tick simulation state ever reaches this service.** Never
position, velocity, aim direction, raw input, or physics — only
persistent, occasional events (match created/started/finished, player
joined/left). The connection *topology* is a star (every CLIENT
connects only to the HOST, mirroring ENet today); match *authority*
stays entirely on the HOST. WebRTC only changes how the HOST and
CLIENT peers find and connect through NAT — not a move to a P2P trust
model. **The website never gains a gameplay affordance** — character
creation/editing, matchmaking, and gameplay stay game-only.

## Architecture

```text
                    ┌──────────────────────┐
                    │   Rails 8.1 + SQLite  │
                    │  amazing-clash-backend│
                    │                       │
                    │ users / steam_identities
                    │ characters            │
                    │ rooms / room_players   │
                    │ matches / match_players│
                    │                       │
                    │ Action Cable Signaling │
                    └──────────┬────────────┘
                               │ signaling (SDP/ICE)
                        ┌──────┴──────┐
                   ┌────▼────┐   ┌────▼────┐
                   │  STUN   │   │  TURN   │  ← not hosted yet, see
                   └────┬────┘   └────┬────┘    "Still open" below
                        │  NAT        │ fallback (symmetric NAT)
                        └──────┬──────┘
                  ┌────────────┴────────────┐
             ┌────▼─────┐             ┌────▼─────┐
             │ Godot A  │             │ Godot B  │
             │   HOST   │◄═══ P2P ═══►│  CLIENT  │
             │(authority)│  transport │          │
             └──────────┘             └──────────┘
```

## Datastore and hosting

SQLite (Solid Queue/Cache/Cable, no Redis) — a single Rails process on
one server. Deployed via Kamal to `thi.dev.br`, sharing that host with
the `42arks` project behind an external reverse proxy (not managed in
either repo). `STEAM_AUTH_MODE=mock` **in production right now** — see
"Still open."

## Auth: bearer token, no expiry

The game client authenticates with `Authorization: Bearer <token>`
(never a cookie — that's the website's own, separate flow). The token
is a 64-char hex secret returned **once**, at login (`POST
/api/v1/sessions` or `/api/v1/steam_sessions`), and does **not
expire** — it's valid until an explicit `DELETE /api/v1/sessions`
(logout) or the account is deactivated. Store it securely client-side;
there is no refresh flow to build against.

- `POST /api/v1/sessions` `{email_address, password}` → `201
  {token, user: {id, username, rating}}`. Rate-limited (10/3min →
  `429 rate_limited`). Errors: `invalid_credentials` (401),
  `account_deactivated` / `email_unconfirmed` / `mfa_required` (403 —
  an admin account without MFA satisfied can't log in via the game
  client at all; not expected to matter for real players).
- `DELETE /api/v1/sessions` (bearer) → `204`.
- `POST /api/v1/steam_sessions` `{app_id, ticket}` → `201 {token,
  user}`, find-or-create automatically (no separate Steam signup).
  **Mocked today** (`STEAM_AUTH_MODE=mock`): the backend expects a
  literal ticket string `"mock:<steam_id>:<persona_name>"`, not a real
  Steamworks call — the real HTTP verifier exists and is tested but
  isn't wired to a live App ID/Web API key yet. Errors: `invalid_ticket`
  (401), `registration_conflict` (409, rare).
- `POST /api/v1/steam_links` (bearer) `{app_id, ticket}` — links Steam
  to the current account (email+password and Steam can coexist).
- `POST /api/v1/email_credentials` (bearer) `{email_address,
  password}` — lets a Steam-only account add email/password later
  (sends confirmation, doesn't require it to keep playing via Steam).

**Email/password *registration* is web-only** — the game client never
calls it.

## Characters

```
GET    /api/v1/characters
POST   /api/v1/characters   {name, class_id, weapon_id, boot_id, perk_id}
PATCH  /api/v1/characters/:id
DELETE /api/v1/characters/:id
```
All bearer, scoped to the caller's own roster. Character JSON:
`{id, name, class_id, weapon_id, boot_id, perk_id}`.

**Enumerated ids — verified identical to `net/lobby_state.gd` right
now (2026-09-08), but not synced automatically:**
- `class_id`: `vanguard`, `ranged_mage`, `warden`
- `weapon_id`: `iron_sword`, `twin_daggers`, `warhammer`
- `boot_id`: `swift_boots`, `warded_greaves`, `tumbling_boots`
- `perk_id`: `vitality`, `swift`, `adept`, `balanced`

Any class accepts any weapon/boot/perk (no compatibility table) — this
matches `net/lobby_state.gd`'s own "4 fully independent axes" model
exactly. **Adding/renaming a class, weapon, boot, or perk on the Godot
side requires updating `Character::{CLASS,WEAPON,BOOT,PERK}_IDS` in the
Rails app in lockstep** — there is no shared source of truth between
the two repos for this today. A character created with an unrecognized
id would fail to spawn in a match.

Slot cap: `422 slot_limit_reached` past `character_slot_limit` (default
5/account). Deleting a character seated in a live lobby → `422
character_in_use`.

## Rooms (matchmaking v1: room codes + public browse, no queue)

```
POST   /api/v1/rooms                      {match_mode, character_id, max_players?, friendly_fire?, round_target?}
GET    /api/v1/rooms?page=1               → {page, rooms: [{code, match_mode, max_players, player_count, friendly_fire, round_target, host_username}, ...]}
GET    /api/v1/rooms/:code                → full lobby JSON (initial fetch; live updates come via Action Cable, see below)
POST   /api/v1/rooms/:code/join           {character_id}
DELETE /api/v1/rooms/:code/leave          (host leaving cancels the whole room — no host migration in v1)
PATCH  /api/v1/rooms/:code/players/me     {character_id?, team_id?}
POST   /api/v1/rooms/:code/start          (host-only → creates the match, see below)
```

`match_mode`/`character_id` are the only required `create` fields;
`max_players` (8), `friendly_fire` (false), `round_target` (2) default
server-side. `:code` is case-insensitive. Browse pagination is 20/page
with **no `total`/`has_more` field** — stop once a page returns fewer
than 20 rows.

Lobby JSON:
```json
{
  "code": "AB12CD", "status": "waiting", "match_mode": "team",
  "max_players": 8, "friendly_fire": false, "round_target": 2,
  "host_id": 1,
  "players": [
    {"user_id": 1, "username": "...", "team_id": 0,
     "character": {"id": 1, "name": "...", "class_id": "...", "weapon_id": "...", "boot_id": "...", "perk_id": "..."}}
  ]
}
```

Team assignment on join with no explicit `team_id`: smaller team, ties
→ team 0 (team mode only; `team_id` stays null in free-for-all).

**Structured error `type`s:** `character_not_found`, `invalid`,
`code_generation_failed`, `not_found`, `room_not_waiting`,
`already_in_room`, `room_full`, `not_in_room`, `not_host`,
`not_enough_players` (min 2), `teams_unbalanced` (team mode needs both
teams non-empty).

## Matches — the real Godot-side work

**This is the actual net-new integration work**: the HOST process
needs an HTTP client reporting events at exactly the hooks that already
call `GameLog.info()` today:

| Godot call site | Event to report |
|---|---|
| `MatchState.enter_in_progress()` | `POST /api/v1/matches/:id/events {event:"started"}` |
| `resolve_round_result()` | `{event:"round_finished", round_wins:{"<user_id>":<count>, ...}}` |
| `enter_post_game()` | `{event:"finished", winning_team:<0\|1\|null>, is_draw:<bool>}` |

The `:id` comes from `POST /api/v1/rooms/:code/start`'s response (the
match is created there, not by the first event) — that call must
happen when the host presses Start, i.e. where `LOADING`'s handshake
begins (`net/loading_reporter.gd`), not at `enter_in_progress()` itself.

Every call is bearer + **host-only** (`403 not_host` otherwise) and
returns the full match JSON:
```json
{
  "id": 1, "room_code": "AB12CD", "status": "finished",
  "match_mode": "team", "friendly_fire": false, "round_target": 2,
  "winning_team": 0, "is_draw": false,
  "started_at": "...", "finished_at": "...",
  "players": [
    {"user_id": 1, "username": "...", "user_deleted": false,
     "team_id": 0, "character_id": 1,
     "class_id": "...", "weapon_id": "...", "boot_id": "...", "perk_id": "...",
     "round_wins": 2, "rating": 1016}
  ]
}
```
`username` is already tombstone-safe (frozen at account deletion) —
always read it from here, never assume a live user lookup.

`status` can come back **`abandoned`** — backend-only bookkeeping (an
hourly reaper job closes out a match where every participant's
connection has looked inactive for 30+ minutes) that the Godot client
never reports itself but can receive if the host reconnects after the
job already closed it out. Treat it as terminal, same as `finished`,
with no winner. Once `finished`/`abandoned`, **every further event is
a no-op 200** — safe to retry blindly on a flaky connection.
`unknown_event` (422) for anything outside `started`/`round_finished`/
`finished`.

Rating: Elo K=32, team-average or FFA-pairwise-by-`round_wins`,
applied automatically inside `finished`. Not tuned against real match
data yet.

## WebRTC signaling (Action Cable)

Connect: `wss://clash.amazing.thi.dev.br/cable?token=<bearer_token>`.
Subscribe to `RoomSignalingChannel` with `{room_code:}` (case-
insensitive) — rejected unless the connection's user has a seat in
that room.

Send (`perform "receive"`):
```json
{"type": "offer" | "answer" | "ice_candidate", "to_user_id": 2, "payload": {...}}
```
Receive (broadcast):
```json
{"type": "offer" | "answer" | "ice_candidate", "from_user_id": 1, "payload": {...}}
```
Note the key changes from `to_user_id` (send) to `from_user_id`
(receive) — this is a per-recipient relay, not an echo. An
unrecognized `type`, a missing `to_user_id`, or a `to_user_id` that
isn't a member of the same room is silently dropped, no error. Rails
never interprets the SDP/ICE payload.

Topology is the star this project already uses with ENet — no
mesh, no change to who talks to whom, only how they find each other.

```
GET /api/v1/ice_servers (bearer)
→ {"ice_servers": [{"urls":"stun:stun.l.google.com:19302"}, {"urls":"turn:...","username":"...","credential":"..."}]}
```
STUN (public, free) always present. **TURN entry only appears once
Rails credentials configure it — not done yet** (see "Still open"):
without it, players behind symmetric NAT can't connect over the real
internet, only STUN-reachable NATs.

## The `net/network_manager.gd` transport swap (unchanged from before)

Still exactly as scoped in
[3](03-networking-and-match-modes.md#future-internet-play-without-manual-port-forwarding):
`host()`/`join()` swap `ENetMultiplayerPeer` for a
`WebRTCMultiplayerPeer` wrapping one `WebRTCPeerConnection`/
`WebRTCDataChannel` pair per remote peer, fed by the signaling above;
`get_peer_rtt_ms()` needs a small custom ping/pong RPC (WebRTC has no
`ENetPacketPeer.PEER_ROUND_TRIP_TIME` equivalent). Every other file
(`@rpc`, `MultiplayerSpawner`, `multiplayer.get_unique_id()`/
`get_peers()`) needs zero changes — confirmed by code audit,
2026-09-04.

## Still open (infra, not code — doesn't block starting integration)

- **TURN**: no provider hosted/configured yet. Blocks real internet
  play for players behind symmetric NAT; doesn't block building and
  testing the integration itself (STUN-only covers most home NATs).
- **Real Steam credentials**: `STEAM_AUTH_MODE=mock` in production —
  the real `Steam::HttpTicketVerifier` exists and is tested but has no
  live App ID/Web API key. Steam login won't work for real players
  until this is set.
- **Elo K-factor**: not tuned against real match data.
- **Where TURN is hosted and who pays** — same open question `3`'s own
  "Future: Internet Play" section already carried, now narrowed to
  "which provider," not "whether to have one."

Once these settle, record them in [5. Open Questions](05-open-questions.md)
— don't let them live only in this file.
