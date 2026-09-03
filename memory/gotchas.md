# Mistakes Log

After any correction from the human, log the pattern here. Review at
session start before starting new work. The goal is to drive the error
rate toward zero.

Format:

- **Date** — *mistake* → **rule**

---

- **2026-09-02** — `net/dev_bootstrap.gd`'s `--simulate-move` handling put
  `await get_tree().create_timer(...)` *before* the `NetworkManager.host()/
  join()` call in the same `_ready()`. Awaiting suspends only that node's
  own `_ready()` coroutine, but sibling nodes' `_ready()` calls (in this
  case `PlayerSpawner`, which checks `NetworkManager.is_server()` once,
  at ready time, and never re-checks) still ran immediately — so
  `PlayerSpawner` saw `is_server() == false` on both the server and
  client process and silently never wired up `peer_connected`/
  `peer_disconnected` or spawned anything. Surfaced only as a confusing
  downstream engine error ("RPC ... not allowed ... authority is 1") two
  layers removed from the real cause, in a live 2-process test — caught
  by tactile verification, not by reading the code. → **Rule**: never put
  an `await` before a same-`_ready()` call that another sibling node's
  own `_ready()` depends on having already happened; do the
  dependency-setting call synchronously first. More generally: root-cause
  a networking error from the actual first divergent state (add a
  `_ready()`-time print of the values the error implies, e.g. `is_server()`
  here), not from the error message's own surface location.

- **2026-09-02** — Copied `amazing-nauts`' debug-console test pattern
  (a synthetic `InputEventKey` with only `physical_keycode` set, no
  `keycode`) for an Escape-closes-the-console test, and it failed:
  `project.godot` had no explicit `ui_cancel` action, so it fell back
  to Godot's engine-default binding, which a `physical_keycode`-only
  synthetic event doesn't match the way this project's OWN actions
  (move/dash/debug toggles, all defined with `physical_keycode`) do.
  `amazing-nauts` never hit this because its `project.godot` already
  redefines `ui_cancel` explicitly with `physical_keycode`. → **Rule**:
  when copying a test that simulates a built-in Godot UI action
  (`ui_cancel`, `ui_accept`, etc.) via `physical_keycode`, also copy or
  add that action's explicit `physical_keycode`-based InputMap entry —
  don't assume the engine default matches this project's own input
  convention. Writing the behavioral test (not just the pure-logic
  `parse_command` one) is what caught this; a copy-and-trust-it pass
  would have shipped it silently broken.

<!--
Examples:

- **2026-04-15** — Assumed `USER_ID` env var was set; silently fell back
  to empty string. → **Rule**: No silent fallbacks on env vars. Hard-fail
  at startup if required vars are missing.

- **2026-04-18** — Renamed `getUserPrefs` via grep; missed a dynamic
  import in `src/lib/legacy.ts`. → **Rule**: On every rename, search
  separately for static calls, type references, string literals, dynamic
  imports, re-exports, test mocks.
-->
