# 2. Battlerite's Actual Netcode: A Direct, Developer-Authored Precedent

[← Index](README.md)

`docs/research/eslabong-inspiration/04-a-precedent-for-live-pvp-battlerite.md`
already established Battlerite (Stunlock Studios) as this project's
closest live-PvP precedent, but only captured a design *lesson*
(netcode/server investment mattered to their success) from Peter Ilves'
postmortem, not the actual technical architecture. Stunlock's own
developer blog closes that gap directly.

## Confirmed: server-authoritative, the same shape this project already has

Stunlock's "Dev Blog #8 – Networking Movement"
(`blog.stunlock.com/dev-blog-008/`), a primary developer-authored
source, states plainly that the server is the authority of the actions
the player performs, meaning all the actions (Movement, Ability Cast,
Projectile Collisions etc.) are fully controlled by the server.

This is not a passing mention — Stunlock explicitly names movement,
ability casts, *and* projectile collisions (i.e. hit detection) as
server-controlled, which is the exact same three-part surface
(`CombatResolver`, `HitDetection`, `Projectile`) this project's server
already owns.

## Confirmed: client-side prediction, corrected against the server

The same post describes the client side of the model in terms that map
almost one-to-one onto this project's `ClientPredictor`: the client
simulates its movement visually and sends all simulated movement
commands to the server; when the server disagrees, the client modifies
its simulation so it matches the expected position on the server.

That is: predict locally for responsiveness, reconcile against the
server's authoritative answer when it disagrees — prediction and
reconciliation, not rollback, not full client authority.

## Confirmed: they explicitly chose to hide latency, not eliminate it

One line from the same post is worth carrying forward as a design
principle, not just a technical note: "you don't remove the latency,
you just decide where to hide it." Stunlock states they targeted
robustness up to ~150ms latency by choosing *where* the delay is
visually absorbed (client-side prediction on your own actions) rather
than pretending it doesn't exist. This is the same trade this project's
own `ClientPredictor`/interpolation split already makes.

## An honest gap: they acknowledge lag artifacts around hit detection

The same post attributes some player complaints about "invalid
hitboxes" (especially projectile collisions, in their own top-down
perspective — the same presentation this project uses) directly to
latency, not bugs: "a lot of the times it is an issue with the latency
to the server." Stunlock does not, in this specific post, describe a
fully solved lag-compensation system for hit validation the way
Valve/Overwatch's public documentation does — this is exactly the kind
of gap lag compensation (rewinding hurtboxes to the attacker's observed
timestamp, see [1](01-server-authoritative-lag-compensation.md)) is
designed to close, and is exactly the piece this project's own
blueprint describes as intended but has not yet implemented (see
[4. Synthesis](04-synthesis-amazingclash.md)).

## What this closes from the earlier research gap

`docs/research/eslabong-inspiration/04` only had Ilves' postmortem,
which discusses netcode importance at the business/design level, not
the architecture. This dev blog is a **primary, developer-authored,
architecture-level source** — the strongest possible confirmation
available that Battlerite, this project's own named live-PvP precedent,
uses the identical server-authoritative-plus-client-prediction model
this project already inherited from `amazing-nauts`, independently of
that inheritance chain. No GDC talk, postmortem, or technical interview
specifically detailing Battlerite's rollback-vs-authoritative decision
process (i.e. *why* they picked this over alternatives) was found
during this research; the dev blog documents *what* they built, not the
deliberation behind it — see [Sources](sources.md) for the full
breakdown of what could and couldn't be confirmed.
