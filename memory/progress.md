# Atomic Progress Log

Your temporal anchor. Tick atomic tasks as you complete them. Never mark a
task done unless `memory/verify.md` criteria are met.

The `state-enforcement.sh` hook blocks task completion if source files
changed but this file wasn't updated.

## In Progress

- [ ] <!-- current atomic task — only one at a time -->

## Completed (this session)

- [x] Copy GUT test infra from amazing-dungeons — `addons/gut/` (9.7.1),
  `.gutconfig.json`, `.gdlintrc`, `.markdownlint-cli2.jsonc`, real
  `agent-md.toml`, `memory/.gdignore`, empty `tests/unit/`; verified by
  running `godot4 --headless --import` then
  `godot4 --headless -s addons/gut/gut_cmdln.gd` (GUT loaded config, no
  tests found, no errors).
- [x] Mirror amazing-dungeons `.git/info/exclude` Claude-runtime ignore
  patterns into amazing-clash's local git config.
- [x] Fix pre-existing markdownlint failures surfaced by the newly-copied
  `.markdownlint-cli2.jsonc` (MD060 compact table style in `CLAUDE.md`/
  `AGENT.md` line 266, MD032 missing blank line in `memory/gotchas.md`).

## Backlog (next up)

<!--
- [ ] <task>
-->

## Blocked

<!--
- [ ] <task> — waiting on: <reason or person>
-->
