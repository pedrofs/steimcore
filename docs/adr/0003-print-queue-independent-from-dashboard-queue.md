# 0003 — Print queue is independent from the Dashboard queue

Date: 2026-05-28
Status: Accepted. Supersedes [ADR-0001](0001-print-queue-suppressed-by-dashboard-queue.md) and overrides one trade-off in [ADR-0002](0002-periodization-progress-on-the-dashboard.md) ("Suppress the Print queue on both new tags").

## Context

ADR-0001 ruled that the **Print queue** would exclude any **Student** already surfaced by the **Dashboard queue**, framing printing as a "clean-handoff task" that shouldn't compete with attention signals.

ADR-0002 then added two count-based attention tags — `periodization_overdue` and `periodization_due` — and reused the same suppression rule.

In practice, the rule combined with ADR-0002 §"Clock per-Periodization or per-Version" hides exactly the rows the trainer wants to see. When the trainer creates a new **Periodization version** of an ongoing **Periodization** (an extension, or a hand-edited revision via the inline editor) and **promotes** it, the prior finished sessions still count against the new version's `periodization_length_weeks × weekly_frequency` — by design. The student stays tagged `periodization_due` (or `…_overdue`) the instant promotion completes, and the freshly-promoted, unprinted plan is silently filtered out of the **Print queue**. The trainer just did the work to revise the plan, but the "Imprimir" card stays empty.

The same hide-the-row dynamic shows up for any Dashboard tag that doesn't actually invalidate the printed sheet: a student with `anamnesis_pending` may still need their (already-promoted) plan on paper; a student flagged `plan_needs_action` because of an *older* failed draft still has a valid current version to print; etc.

## Decision

**The Print queue is computed independently from the Dashboard queue.** A **Periodization version** belongs to the Print queue iff:

- it is the **Current version** of an unarchived **Periodization**,
- its `status = "completed"`, and
- its `printed_at IS NULL`.

No suppression based on Dashboard tags. A student can appear in both cards at the same time.

## Consequences

- `Organization::PrintQueue#eligible_versions` no longer consults `Organization::DashboardQueue`. The `DashboardQueue.tagged_student_ids` class method is removed (it had no other caller).
- The two cards on home are now visually independent. The same student name can appear in both — the trainer reads the print card as "sheets to hand out" and the dashboard card as "people to act on", and acts on each one on its own terms.
- ADR-0002's "Suppress the Print queue on both new tags" trade-off is reversed: `periodization_overdue` and `periodization_due` no longer hide the print row. The rest of ADR-0002 (per-Periodization clock, count-based tags, the [0, 5) threshold) stands.
- Tests in `test/models/organization/print_queue_test.rb` were rewritten: every "excludes students flagged in X" case became an "includes" case, except the two that exercise the basic "no current version" filter (`no_plan`, multi-tag with no plan).
