# 0002 — Periodization progress on the dashboard

Date: 2026-05-27
Status: Accepted

## Context

The trainer designs a **Periodization** as a fixed dose: e.g. "8 weeks at 3 sessions/week = 24 sessions." When the student has trained through that dose, the trainer needs to plan the next Periodization. Today the dashboard surfaces nothing about how close a student is to finishing their current Periodization — the trainer has to remember.

We want to surface, for each student, how many sessions remain until their current Periodization is "spent", and prioritise students who are close to the end or have already overshot.

Two prior facts shape the decision:

- The dose has two inputs the trainer already controls: how long the block runs (in weeks) and how often the student trains per week (`students.weekly_frequency`, already on the schema).
- The block length is something the LLM picks during generation as part of the periodization prose — but only as free text. It is not currently a structured value the app can read.

There is also an existing **`inactive`** Dashboard tag that flags students whose last finished session is older than a frequency-adaptive cutoff. It catches "the student stopped showing up," not "the prescribed dose is spent."

## Decision

1. **The LLM returns a structured `periodization_length_weeks` alongside the version body.** New column on `periodization_versions`, nullable, required once the version reaches `:completed`. The version is the home of the length, not the periodization.

2. **The Periodization is the clock; the Current version is the target.** "Sessions remaining" = `current_version.periodization_length_weeks × student.weekly_frequency − count(finished training sessions across all versions of the Active periodization)`. Sessions on superseded versions still count against the same Periodization.

3. **The dashboard signal is count-based, not calendar-based.** Two new tags:
   - `periodization_overdue` — `sessions_remaining < 0`.
   - `periodization_due` — `sessions_remaining ∈ [0, 5)`.
   They cluster directly under `plan_needs_action`, above `inactive`. Both suppress the Print queue, same as every other Dashboard tag.

4. **Students without a `periodization_length_weeks` on the current version, or without `weekly_frequency`, are silently excluded from both tags.** They surface via existing tags (`anamnesis_pending`, `plan_needs_action`, etc.).

## Trade-offs considered

### Where does `periodization_length_weeks` live — `Periodization` or `PeriodizationVersion`?

Putting it on `Periodization` reads more naturally (the "length of the Periodization" sounds like a property of the Periodization). But the trainer can ask the LLM to extend the block mid-flight ("make it 12 weeks instead of 8"), which produces a new `PeriodizationVersion`. If the field lived on `Periodization`, an extension would have to *update* the parent record — losing the historical truth of what each version committed to.

Putting it on `PeriodizationVersion` keeps each version honest about its own contract and makes the audit trail (`versions` history) self-describing. The cost is the slightly awkward name: `periodization_versions.periodization_length_weeks` reads as "the version stores the length of its parent." Worth it.

### Clock per-Periodization or per-Version?

Resetting `sessions_remaining` on every promotion makes the math simpler but breaks the "extend the block" intent: an extension would look identical to a fresh restart, and the student's accumulated sessions would silently zero out. Carrying sessions across versions within a Periodization preserves "extending means moving the goalpost," which is what the trainer actually means. The escape valve when a real restart is needed is `Student#start_periodization!`, which archives the Periodization and starts a new clock.

### Count-based vs calendar-based "due/overdue"

A calendar reading (`expected_end_date = current_version.created_at + length_weeks`; overdue past that date) was tempting because it overlaps with how `inactive` works. We rejected it for two reasons:

1. The dose the trainer prescribed is in *sessions*, not in *calendar time*. "24 sessions" is the contract; whether the student takes 7 weeks or 10 weeks doesn't change the trainer's next action.
2. A calendar-based "overdue" would heavily overlap `inactive` (which already covers "student isn't training enough"). Keeping the new tag count-based gives it a non-redundant job: "the dose is spent, design the next one."

### The threshold for `periodization_due` is a flat 5 sessions

We considered making the threshold proportional to `weekly_frequency` (e.g. "1.5 weeks of warning"). The flat-sessions framing won because the trainer's planning work is itself measured in sessions, not in days: "I have 5 sessions of runway to sketch the next block" is a more honest read of the trainer's bandwidth than "I have 1.5 calendar weeks."

The cost: a 5×/week student gets ~1 calendar week of warning; a 2×/week student gets ~2.5 weeks. Both are plenty.

### Cluster slotted under `plan_needs_action`, not above it

`plan_needs_action` is a 30-second task (review a draft already on the desk). `periodization_overdue` is heavier (design the next block). Letting trainers clear cheap wins first matches the bottleneck-first ergonomics of the queue — the new tags go just under `plan_needs_action` rather than above it.

### Suppress the Print queue on both new tags

`periodization_overdue` clearly should suppress — the sheet they'd print is stale. `periodization_due` is more ambiguous: the current sheet is still valid for a few more sessions. We chose to suppress both, to preserve the simpler invariant from ADR 0001 ("any Dashboard tag suppresses the Print queue"). The cost is at most a week of not printing for students about to roll over.

## Consequences

- **Schema**: new column `periodization_versions.periodization_length_weeks :integer`, nullable in storage, required on `:completed` via a Rails validation.
- **LLM tool contract**: the periodization-generation tool gains a required structured argument `periodization_length_weeks`. Versions cannot complete without it.
- **`Student` scopes**: two new scopes (`periodization_overdue`, `periodization_due`) and two corresponding `_sort_value` methods (mirror `plan_needs_action_sort_value` / `inactive_sort_value`).
- **Dashboard view**: rows in the queue display a `sessions_remaining` badge for any student tagged with either new tag.
- **ADR 0001 is preserved unchanged** — the Print queue continues to be suppressed by any Dashboard tag.
- **No data backfill**: the app is pre-production. Existing periodizations/versions/training_sessions are truncated when this ships. Going forward every completed version has a length.
