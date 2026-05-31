# 0004 — Remove the Print queue and printed state; go fully digital

Date: 2026-05-31
Status: Accepted. Supersedes [ADR-0003](0003-print-queue-independent-from-dashboard-queue.md) (and, transitively, [ADR-0001](0001-print-queue-suppressed-by-dashboard-queue.md)).

## Context

ADR-0001 and ADR-0003 both reasoned about *where* the **Print queue** should sit relative to the **Dashboard queue**. Both took for granted that printing-and-handing-a-paper-sheet-to-the-student is a first-class step in the trainer's workflow, worth its own home-page card and its own one-way `printed_at` state.

That premise no longer holds. The product is going **fully digital**: the student gets their plan on a screen, not on paper. Printing stays available as a genuine last resort (open the chrome-free printable view and hit the browser's print dialog), but it is no longer a tracked workflow step the trainer is nudged to complete. With no "you still owe this student a printout" obligation, there is nothing for a Print queue to surface and nothing for a `printed_at` timestamp to record.

## Decision

- **Remove the Print queue entirely.** `Organization::PrintQueue` and its home-page "Imprimir" card are deleted. The home page now shows only the **Dashboard queue**.
- **Remove the printed state.** The `printed_at` column on `periodization_versions`, the `PeriodizationVersion::Printable` concern (`printed?` / `mark_printed!`), and the **Print confirmation** sub-resource (`POST …/versions/:id/print_confirmation`) are all deleted.
- **Keep the printable view.** `Students::Periodizations::PrintablesController#show` and its chrome-free React page stay. It auto-fires the browser print dialog on load; it no longer offers a "Marcar como impresso" action, because there is no print state to mark. The printable itself was also simplified to a single page (header + workouts) — see the workspace history.

## Consequences

- The home dashboard is a single cohort again. The independence argument from ADR-0003 is moot — there is only one card.
- `periodization_versions.printed_at` is dropped in a migration. Any historical "this version was printed" data is discarded; it has no consumer.
- "Printing is a clean-handoff task" (ADR-0001) and "the Print queue is independent" (ADR-0003) are both retired. The rest of [ADR-0002](0002-periodization-progress-on-the-dashboard.md) (per-Periodization clock, the `periodization_overdue` / `periodization_due` count-based tags, the `[0, 5)` threshold) is unaffected — those tags never depended on print state.
- Domain vocabulary changes: **Printed**, **Print confirmation**, and **Print queue** are removed from `CONTEXT.md`.
