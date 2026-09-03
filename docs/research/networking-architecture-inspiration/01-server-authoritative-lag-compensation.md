# 1. Server-Authoritative Model with Lag Compensation: The Industry-Canonical Pattern

[← Index](README.md)

This project's inherited networking model — the server runs the one
real simulation, clients predict their own input, remote entities are
interpolated — is not a novel choice; it is the industry-standard
architecture for competitive multiplayer games that have a real
dedicated/authoritative server available. Two primary references anchor
this, spanning nearly two decades of shipped, competitive,
hit-detection-heavy games.

## Valve's Source engine: the original widely-documented reference

Valve's own developer wiki (`developer.valvesoftware.com/wiki/Lag_compensation`)
is the most-cited public reference for this pattern, used since
Half-Life/Counter-Strike-era Source engine games. Per the documentation
(cited via search-indexed excerpt; direct fetch returned HTTP 403
during this research, see [Sources](sources.md)):

- Lag compensation is "the notion of the server using a player's
  latency to rewind time when processing a usercmd, in order to see
  what the player saw when the command was sent."
- The server keeps "a history of all recent player positions for one
  second" specifically to support this rewind.
- Combined with client prediction, this "can help to combat network
  latency to the point of almost eliminating it from the perspective of
  an attacker" — the attacker doesn't have to lead their aim to
  compensate for the interpolation delay other clients render at.

Gabriel Gambetta's "Fast-Paced Multiplayer" series (a widely-cited
independent technical reference, not tied to any one shipped game)
explains the mechanism in terms directly transferable to this project:
when a client fires/casts, it sends the server the exact timestamp of
the action; "the server can authoritatively reconstruct the world at
any instant in the past" from its own kept history, and resolves the
hit against that reconstructed past state — not the server's live-tick
state at the moment the packet arrives.

## The known trade-off: favor-the-shooter

This technique is not free. It deliberately privileges the attacker's
perceived reality over the target's: a player who ducks behind cover
can still be hit "a fraction of a second later, when they thought they
were safe," because the server validates the shot against where the
target *was* at the shooter's timestamp, not where the target is *now*.
Both Valve's own docs and independent analysis describe this as an
accepted, symmetrical unfairness (every player is sometimes the
shooter and sometimes the target) rather than a bug — "it would be much
worse to miss an unmissable shot."

## Overwatch (Blizzard): the closest genre precedent

Tim Ford's GDC 2017 talk "'Overwatch' Gameplay Architecture and
Netcode" is the most-cited modern reference for exactly this project's
genre shape: a roster of characters with individual kits of
abilities/projectiles, played competitively, server-authoritative. Per
an independent technical deep-dive that appears to draw on the talk's
actual content (Edgegap, see [Sources](sources.md)):

- Overwatch runs a **dedicated, authoritative server** holding ground
  truth; clients predict aggressively — "movement, abilities, and
  projectiles" all predict locally by default, rather than waiting for
  server confirmation, specifically to keep the game feeling
  responsive.
- When a client's own prediction diverges from the server's
  authoritative snapshot, the client corrects to the server's state and
  replays its own unconfirmed inputs forward — the same
  prediction/reconciliation shape this project's `ClientPredictor`
  already implements.
- This is explicitly *not* rollback netcode in the fighting-game sense
  (see [3](03-hybrid-approaches-and-rollback-comparison.md) for why
  that distinction matters) — the source material frames rollback as
  requiring a true dedicated server as ground truth, which
  peer-to-peer rollback implementations by definition don't have.

## Why this fits a hit-detection-heavy game specifically

Both references are, like amazing-clash, games where the central skill
expression is *did this precise, fast action land on another player* —
bullets in Source/Overwatch's case, melee swings and skillshots in this
project's case. Lag compensation exists specifically to make that
judgment fair under real network latency without requiring every peer
to simulate a bit-perfect copy of everyone else's world, which is the
deterministic-simulation requirement rollback imposes (see
[3](03-hybrid-approaches-and-rollback-comparison.md)).
