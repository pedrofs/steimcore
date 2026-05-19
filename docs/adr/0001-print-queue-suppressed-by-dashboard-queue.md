# Print queue is suppressed by the Dashboard queue

The home page surfaces two cohorts of students needing trainer action: the **Dashboard queue** (attention signals — `plan_needs_action`, `inactive`, `no_plan`, `anamnesis_pending`) and the new **Print queue** (active periodizations whose `current_version` is completed but unprinted). We deliberately exclude any student in the Dashboard queue from the Print queue, even when their current version is unprinted, because printing is a clean-handoff task and shouldn't compete for attention with broken plans, lapsed students, or missing anamneses.

## Considered options

- **Show all unprinted current versions in the Print queue.** Rejected — a single row in two cards is visual noise, and "print Ana's plan" is the wrong next action when Ana also has `plan_needs_action` (the plan is going to change before it's printed) or `inactive` (call her first).
- **Add `needs_printing` as a 5th tag inside the Dashboard queue.** Rejected — mixes a workflow task ("print this sheet") with attention signals about the student, and the existing tag machinery is bottleneck-first; printing isn't a bottleneck.

## Consequences

The Print queue's row count will not match `current_versions.where(printed_at: nil).count` taken naively — it will be smaller, sometimes much smaller. A reader who treats the SQL count as the truth will assume the UI is buggy. `Organization::PrintQueue` must consult the same student scopes used by `Organization::DashboardQueue::TAGS` to compute the exclusion; the two cohorts are coupled by this rule and tests on either side must cover the overlap.
