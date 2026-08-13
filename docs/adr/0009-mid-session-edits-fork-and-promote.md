# 0009 — Mid-session workout edits fork and promote a Periodization version

Date: 2026-08-13
Status: Accepted.

## Context

A trainer running a live **Training session** on the board needs to change the prescription mid-workout: the leg press is occupied, the student's shoulder hurts today, an extra finisher is warranted. Today the board can toggle blocks, record loads, **Swap** the whole Workout for a sibling, or finish — but it cannot touch the blocks themselves.

`TrainingSession` carries `blocks_snapshot`, a frozen copy of the Workout's blocks taken at start, expressly so that later plan edits don't rewrite history. The obvious move is therefore to let the trainer edit that snapshot and leave the plan alone. We deliberately chose the opposite.

The complication: the Workout a live session runs from belongs to the **promoted** version, and `PeriodizationVersion#read_only?` is true for any promoted or superseded version. The plan a student is training from is, by construction, locked.

## Decision

A **Mid-session edit** changes the plan, not just today's performance. One save, in one transaction:

1. Fork a new version from the **Current version** (`fork_with!` — the `:clone`/`:workout` machinery already used by `Periodizations::InlineEditsController`), carrying every other Workout forward byte-identically and replacing the target Workout's blocks.
2. Promote it (`periodization.set_current_version!`).
3. Re-point the live session at the new version and its corresponding Workout, re-snapshot `blocks_snapshot`, and **remap `progress`**.

The endpoint is `PATCH /training_sessions/:id/workout` (`TrainingSessions::WorkoutsController#update`), whose payload matches `PeriodizationVersions::WorkoutsController#update` so one extracted editor serves both.

Rationale: a mid-session change is nearly always a *correction to the prescription* — this student cannot do that movement, or should be doing this other one — and the trainer expects it to hold next time. A session-local edit would mean the same fix has to be re-made every single week, silently, with no trace in the plan.

## Considered options

- **Edit `blocks_snapshot` only.** Simplest, fits the "session is a snapshot" framing, and the promoted version stays untouched. Rejected: the fix evaporates at the next session and the plan drifts permanently out of sync with what the student actually trains.
- **Ask each time** ("Só hoje" vs "Salvar no plano"). Rejected: both mechanisms would have to exist and be tested, to add a decision to a hurried, one-handed interaction on a gym floor.
- **Relax `read_only?` while a session owns the version** (edit the promoted version in place, one version per session instead of per save). Rejected: `read_only?` is the invariant the entire version model rests on; a conditional hole in it would have to be reasoned about everywhere versions are written.

## Consequences

- **One promoted version per editing burst.** The editor stages surgical changes locally and commits the whole blocks array once, so a session normally produces zero or one version — but a trainer who saves three times gets three versions, three promotions, and three superseded parents.
- **Linking runs on each.** Every version reaching `:completed` enqueues `LinkExercisesJob`, so exercise names typed mid-session flow into the global catalog for free. That is a benefit, not an accident.
- **The fork re-points a live session**, which is why a **Detached session** — `workout_id`/`periodization_version_id` null, or no longer pointing at the Current version — is blocked from editing. Forking from the Current version and re-pointing would splice the student onto a plan they did not start. Finished sessions are blocked for the same class of reason.
- **`progress` is index-based**, so the editor sends the origin index of every surviving block and the server rewrites `progress` accordingly. Ticks survive reorders and renames; removed blocks drop out; new blocks start undone. This is the opposite of **Swap**, which resets progress outright.
- **A staleness check guards the save**: the PATCH carries a digest of the `blocks_snapshot` the editor loaded, and a mismatch is refused rather than remapped against the wrong array.
- **Sessions remaining is unaffected** — it counts finished sessions across *all* versions of a Periodization, so mid-session forks do not reset a student's clock.
- Reversing this later means deciding what to do with the mid-session versions already promoted into every affected Periodization's history.
