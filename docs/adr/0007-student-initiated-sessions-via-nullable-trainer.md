# 0007 — Student-initiated training sessions via a nullable trainer

Date: 2026-06-02
Status: Accepted.

## Context

`TrainingSession` started life as a trainer-driven concept: a trainer opens the live-sessions board, picks a student, and `TrainingSession.start!(trainer:, student:)` snapshots the auto-picked workout and creates the active session. `trainer_id` was `NOT NULL` and `belongs_to :trainer` was required — every session had an owning trainer, surfaced on the board by name/avatar.

We now want a student to start their own session from their home screen — choose the suggested (or another planned) workout, train through it, finish or cancel — **with no trainer associated**. The question was how to model "a session nobody on staff started."

## Decision

Overload the existing `TrainingSession` rather than introduce a separate concept. A **Student-initiated** session is just a `TrainingSession` with **`trainer_id` null**; a **Trainer-initiated** session has it set. Concretely:

- Drop `NOT NULL` on `training_sessions.trainer_id`; `belongs_to :trainer` becomes `optional: true`.
- Generalize the single start path: `TrainingSession.start!(student:, trainer: nil, workout: nil)` — `workout` defaults to `next_workout_for(student)`, `trainer` may be absent. The student entry point is `Student#start_training_session!(workout:)`, which calls it with no trainer and carries the rest-day (weekend) guard.
- The presence/absence of `trainer_id` is the sole encoding of *who started it*. Same record, same lifecycle (blocks, progress, finish), same one-active-per-student unique index.

## Considered options

- **A separate model** (`CheckIn` / self-serve session) that later spawns or mirrors a `TrainingSession`. Rejected: it splits one domain concept — "a live workout in progress" — into two and duplicates the entire lifecycle (snapshotting, block progress, finish, the one-active constraint). The two would have to be kept in lockstep for the board, the calendar, and progress math.
- **A polymorphic `initiator`** (trainer User *or* student). Rejected as over-engineered for a binary distinction that "is `trainer_id` present?" already answers; it would complicate every query for no current benefit.

## Consequences

- A reader seeing `belongs_to :trainer, optional: true` on a *training session* will reasonably ask "how can a session have no trainer?" — this ADR is the answer: it was started by the student.
- The trainer board must tolerate a null trainer: `training_session_props` guards `session.trainer&.…`, and student-initiated sessions render with a **self-serve marker** ("Iniciado pelo aluno") instead of a trainer name. They appear only under the **"Todos"** (org-wide) scope, never a trainer's own ("Meus") scope, since that scope filters by `trainer_id`.
- Authorization splits on the same field: a student may **cancel** (hard-delete) only sessions they started (`trainer_id IS NULL`), though they may **finish** and toggle blocks on a trainer-led one too.
- This is deliberately *not* reversible for free: "null trainer = student-initiated" becomes load-bearing across scopes, the board, and queries. Re-splitting into a distinct model later would require a data migration.
- Out of scope (future PR): letting a trainer assign herself to a student-initiated session — i.e. backfilling `trainer_id` after the fact.
