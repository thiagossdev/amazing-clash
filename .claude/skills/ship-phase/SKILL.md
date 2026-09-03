---
name: ship-phase
description: "Design, implement, verify, review, and merge one roadmap phase from memory/plan.md end-to-end on its own branch, then document what's left for the human owner. Use when asked to finish/ship/complete/advance a phase (or a range of phases), including inside /loop. Not for a single small fix with no memory/plan.md phase entry -- use the project's normal execution flow for that."
when_to_use: "finalizar a fase, terminar a fase, ship phase, complete phase, avançar as fases, finish phase N, próxima fase do roadmap, /loop finalizar fases"
---

# Ship Phase

Codifies a pattern this project has already been running informally
since Phase 1 (see `git log`: one `feature/phaseN-*` branch per phase,
several wave commits, `git merge --no-ff` into `main`) so it can be
repeated deliberately -- by a human invoking it once, or by `/loop`
driving it across several phases unattended.

This skill assumes `CLAUDE.md`'s directives are already in effect
(role, persistent state in `memory/`, planning discipline, TDD,
verification, edit safety, self-correction). It does not repeat them;
it sequences them for one phase.

## Input

One phase, identified by its number/name in `memory/plan.md`'s
Roadmap list. The phase must already have a scope -- either an
existing `### Slice N (...)` block, or (for a phase only sketched at
roadmap-list granularity, like Slices 7-10 were before this skill
existed) enough decided context in `memory/plan.md` for `/think`'s
Step 1 below to produce a concrete plan without re-litigating design
questions the human owner already answered. If the phase has no scope
at all yet (not even a roadmap-list one-liner), stop and ask for one
-- this skill executes a scoped phase, it does not invent scope.

## Procedure

1. **Think.** Run `/think` scoped to just this phase. If
   `memory/plan.md` already has a decided scope for it (a durable
   summary written by a prior `/think` session, e.g. the "Slices 7-10"
   block), treat that as ground truth and refine it into an
   implementation-ready plan rather than re-deriving it from zero --
   re-asking the human owner questions they already answered in a
   prior session is a real failure mode, not just wasted time. If the
   phase is genuinely undecided (no such block exists), run `/think`
   in full and stop for approval before continuing to step 2, exactly
   as `/think` itself requires -- this skill does not bypass that gate
   for a phase nobody has designed yet, even inside an autonomous
   `/loop`.
2. **Branch.** `git checkout -b feature/phaseN-<slug>` off the current
   `main` tip (fetch/pull first only if the human owner has an active
   remote workflow -- this project's convention so far is local-only
   branches, never pushed unless asked).
3. **Implement in waves.** Several small, independently-reviewable
   commits, not one giant diff -- mirrors every phase since Phase 1
   (see `memory/progress.md`'s own "4 wave commits" note). A natural
   wave split for a typical phase: (a) data/Resource scaffolding, (b)
   core logic + its unit tests (TDD: write/observe the failing test
   before the implementation that turns it green, per `CLAUDE.md`
   Section 7), (c) networking/wiring into the existing
   `NetworkManager`/`PlayerSpawner`/`MatchState` surface, (d) UI or
   integration + updated `net/dev_bootstrap.gd` simulate-flags if the
   phase needs a new one for headless testing. Re-read a file before
   editing it and after, per `CLAUDE.md` Section 9; on any rename or
   signature change, grep separately for calls, references, string
   literals, and test mocks before deleting the old name.
4. **Verify**, tactically, the same way every phase before this one
   was verified (see `memory/verify.md`'s per-phase sections for the
   evidence bar to match):
   - `gdformat`/`gdlint` clean.
   - Full GUT suite passes (`godot4 --headless -s
     addons/gut/gut_cmdln.gd`), including new tests for this phase's
     pure logic.
   - Live multi-process headless functional test via
     `net/dev_bootstrap.gd` flags (add a new `--simulate-*` flag if
     the phase needs one to exercise deterministically, following the
     existing flags' pattern) -- confirms the actual networked
     behavior, not just unit-level logic.
   - **Known project-wide gap, not this skill's to solve**: there is
     no established way to screenshot Godot's real renderer in this
     environment (`playwright-capture.sh` is web-only;
     `memory/verify.md` flags this explicitly at every UI-adjacent
     phase so far). If this phase touches UI, say so plainly in
     `memory/verify.md` as an explicit, named gap -- do not claim a
     visual check that didn't happen, and do not silently skip
     mentioning it either.
   - If a fix fails twice on the same issue, stop and re-read the
     relevant code top-down before a third attempt, per `CLAUDE.md`
     Section 13 -- do not keep guessing.
5. **Review.** Run the `code-review` skill (`/check`) against the
   branch's diff at high effort (no live human reviewer in an
   autonomous run, so the bar is adversarial self-review, not a quick
   pass). Fix what it finds, re-run until clean or until remaining
   findings are explicitly deferred with a reason (see step 7).
6. **Merge.** `git merge --no-ff` the phase branch into `main`, local
   only -- never push unless the human owner explicitly asks, per
   `CLAUDE.md` Section 3 and the system-level git safety rules. Do not
   delete the phase branch; leave it as history, matching this
   project's existing branches (`feature/phase1-*` through
   `feature/phase6-*` are all still present).
7. **Document.** Every phase gets all of:
   - `memory/plan.md`: mark the phase's roadmap-list entry **Done**,
     replace/complete its `### Slice N` block with what was actually
     built (not just what was planned -- note any deviation).
   - `memory/progress.md`: a "Completed (this session)" entry in the
     same voice/detail level as Phases 1-6's own entries (what was
     built, what tests exist, what the live verification showed,
     cross-referenced to `memory/gotchas.md` for any real bug found
     along the way); update the Backlog section (remove what this
     phase resolved, add what it newly surfaced).
   - `memory/verify.md`: a new "Phase N" section with the specific
     evidence per criterion, matching every prior phase's format.
   - `docs/blueprint/`: update if this phase changed confirmed
     architecture or resolved/created an open question (mirror how
     Phase 5/6 updated `03-networking-and-match-modes.md` and
     `05-open-questions.md`).
   - **A running, explicit list of what's left for the human owner**:
     genuine product/design decisions this phase's `/think` did not
     already resolve, and anything deferred out of this phase's scope
     on purpose. Write this even (especially) when running
     unattended -- it's the thing the human owner reads first when
     they come back. Do not bury it inside a commit message; put it
     in `memory/progress.md`'s Backlog section where it's already the
     convention to look.
8. **Continue or stop.** If invoked for a single phase, stop here. If
   invoked across a range (typically via `/loop`), proceed to the next
   phase's step 1 only if: the merge in step 6 was clean (no
   conflicts), review in step 5 found nothing left unresolved without
   an explicit documented reason, and the next phase's `/think` (step
   1) does not surface a genuine undecided product question. Any of
   those three failing is a stop condition -- pause, document exactly
   where things stand per step 7, and surface the open question rather
   than guessing past it. This mirrors `CLAUDE.md`'s role directive
   (Section 1): do not silently make architectural or product
   decisions on the human owner's behalf, autonomous loop or not.

## What this skill does not do

- Does not push to any remote.
- Does not skip `/think`'s approval gate for a phase that isn't
  already scoped.
- Does not invent a screenshot/visual-verification capability this
  project doesn't have -- it names the gap instead.
- Does not silently reduce a phase's scope to make it fit inside one
  sitting; if a phase is too large, say so and propose splitting it
  into two roadmap entries before implementing, the same way Slice 2
  was split into 2a/2b and Slices 7-10 were split out of an originally
  single "lobby" idea.
