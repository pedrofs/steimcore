# 0005 — Medals are peak achievements, evaluated live and never revoked

Date: 2026-06-02
Status: Accepted

## Context

The **Medalhas** feature awards a **Student** medals across four **Families** (`workouts`, `weekly_streak`, `full_weeks`, `periodizations`). Streaks break, `weekly_frequency` changes, sessions get reopened (`reopen!`) or backdated (`log_past!`) — so "what does a medal mean, and when does it change?" needs a firm answer before any of the metric or UI work makes sense.

Two prior facts shape the decision:

- **Sessions remaining** / **Periodization target** already exist (see [ADR-0002](0002-periodization-progress-on-the-dashboard.md)): `current_version.periodization_length_weeks × weekly_frequency − finished sessions across all versions`.
- The app already takes two opposite stances on a missing cadence: the periodization show page falls back to 5 sessions/week; the **Dashboard queue** refuses the fallback and requires an explicit `weekly_frequency > 0`.

## Decision

1. **Peak, never revoked.** A Medal commemorates a threshold the student *once reached*. Evaluation only ever **inserts** `StudentMedal` rows — never deletes. A broken streak, a `reopen!`, or a later cadence change can lower the *current* metric, but an earned Medal stays forever. Tier unlocks track the **peak metric ever**, so the detail sheet shows best-ever and current as two distinct numbers.

2. **Evaluated live against current state, no history.** There is no per-week `weekly_frequency` history; every week and block is re-judged against today's cadence. The three cadence-dependent families require an explicit `weekly_frequency > 0` (no fallback-of-5 — matching the Dashboard, not the show page); with no cadence those Medals stay locked.

3. **Completion reuses existing math.** A periodization is "completed" for the `periodizations` family when its **Sessions remaining ≤ 0** (the full prescribed dose was trained), counting both the **Active periodization** and archived ones, excluding blocks archived before the dose was delivered and blocks whose **Current version** has no `periodization_length_weeks`.

4. **`earned_at = Time.current`, no reconstruction.** Medals are stamped when evaluation records them, not when the threshold was historically crossed. The launch **backfill stamps `seen_at`** so pre-existing achievements appear in the grid without triggering a celebration storm; celebrations are reserved for post-launch earns.

5. **Triggers.** A single `TrainingSession` after-commit hook fires when `finished_at` becomes present — covering both `finish!` and `log_past!`, and naturally skipping `reopen!`. A `Student` after-update hook fires on `weekly_frequency` change (lowering a cadence can retroactively unlock Medals). `start_periodization!` and block-shrink are deliberately **not** triggers — they award nothing new, or self-heal on the student's next finished session.

## Trade-offs considered

### Peak/never-revoke vs. current-state badges

Current-state badges (the ×12 medal drops when the streak breaks) are simpler to reason about as "what's true now," but revocable achievements are punitive and demotivating — the entire genre treats earned badges as permanent. Insert-only evaluation is also immune to `reopen!`, backdating, and cadence churn, which removes a whole class of edge cases. The cost is that a Medal means "best ever," not "right now," which the detail sheet has to make explicit.

### Live judging vs. a `weekly_frequency_history` table

Storing the cadence in effect for each past week would make Full-week judgments historically exact. We rejected it: cadence changes are rare, never-revoke absorbs the downside (a raised cadence only lowers the *current* metric, never an earned Medal), and a history table is real schema and write-path complexity for a rare event.

### `earned_at` reconstruction

Reconstructing the true crossing date is cheap for `workouts` (the Nth session's `created_at`) but means replaying streak history for the cadence-dependent families. The date is decorative, so we stamp `Time.current` uniformly rather than special-casing one family.

## Consequences

- **Schema**: new `student_medals` table — `student_id`, `family`, `tier`, `value_snapshot`, `earned_at`, `seen_at` — with a unique index on `[student_id, family, tier]` making evaluation idempotent.
- **Backfill required**: real student/session data exists (truncate-on-ship from ADR-0002 no longer applies). A one-off idempotent `Student.find_each(&:evaluate_medals!)` awards pre-existing achievements with `seen_at` set.
- **Celebration**: the Medalhas page plays unseen Medals sequentially in `earned_at` order, marking each seen as it finishes; the trainer profile view is passive and never marks seen.
