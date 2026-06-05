# 0008 — Periodization templates as a separate model, not a nullable-student Periodization

Date: 2026-06-05
Status: Accepted.

## Context

The team wants to reuse standard periodizations across students without starting each plan from the AI: pick a pre-built blueprint, clone it into a student, tweak. The blueprint must carry the same *content* a plan carries — `body_md`, `periodization_length_weeks`, and ordered workouts (`name`/`position`/`blocks`) — but belong to no student.

`Periodization` is the obvious thing to reuse, and `PeriodizationVersion`/`Workout` already hold exactly that content with a `:clone` fork scope (byte-identical, no LLM, born `:completed`). The temptation is to make `Periodization.student_id` nullable and add a `template` flag, or to make `Workout` polymorphic so it can hang off either a version or a template. The question was whether to reuse those hierarchies or build a parallel one.

## Decision

Model a template as its own pair of tables, structurally isolated from the live-plan hierarchy:

- **`PeriodizationTemplate`** — `belongs_to :organization` (org-scoped, not global like the Exercise catalog); `name` (required), `description` (optional), `body_md`, `periodization_length_weeks`. Mutable in place (no versioning, no promotion, no history), retired by hard `destroy`.
- **`PeriodizationTemplate::Workout`** — a parallel table to `workouts` (`name`, `position`, `blocks` JSONB, the same `Blocks` schema validation, extracted into a shared validator), with **no** `relink` callback.

Cloning is `Student#start_periodization_from_template!(template, trainer:)`: in one transaction it archives the active periodization (same at-most-one invariant as `start_periodization!`), creates a `Periodization`, builds one `PeriodizationVersion` populated from the template, transitions it straight to `:completed`, and promotes it. Completion auto-triggers exercise **Linking** through the existing version path. Save-as-template snapshots a version's content into a new template — a copy, independent of the source thereafter.

## Considered options

- **Nullable `Periodization.student_id` + a `template` flag.** Rejected. The Student-coupling on `Periodization` is load-bearing and pervasive: `Student#active_periodization`, the dashboard queue, medals, frequency views, training sessions, and progress math all assume a periodization has a student. A nullable student would force a "and it's not a template" guard into every one of those paths, leaking template-awareness into code that has no domain reason to know templates exist. A template is a different concept (a library blueprint), not a `Periodization` missing a field.
- **Polymorphic `Workout` (`workoutable`: version *or* template).** Rejected. `Workout` is entangled with `training_sessions`, a version-specific `relink` callback, and a `belongs_to :periodization_version` default scope. A parallel table keeps the template's workouts byte-shaped like a version's (so `BlocksRenderer`, the inline editor, and clone all reuse existing paths) without dragging template branches through that machinery.
- **Storing template content as a single JSONB blob** on the template row. Rejected: the inline block editor, `Blocks` validation, and `position`-ordered rendering all speak "Workout rows"; a blob would force the editor to special-case templates with manual array surgery.

## Consequences

- Two parallel hierarchies exist for plan content (version/workout and template/template-workout). The `Blocks` schema validation is shared via a small concern; the rest is deliberate duplication to keep the live-plan paths free of template branches.
- A template is a frozen snapshot: editing the source version later does not change a template saved from it, and editing a template does not change plans already cloned from it. Each clone copies content row-for-row.
- The clone produces a normal `:completed`, promoted version, so everything downstream (Linking, the student Treinos tab, progress, printing) works unchanged — a cloned plan is indistinguishable from an AI-generated one once created.
- Reversing this (collapsing templates back into `Periodization`) would require a data migration, but the blast radius is contained to the template tables — nothing in the live-plan hierarchy references a template.
- Out of scope (future): from-scratch blank-canvas template authoring (v1 only creates templates by snapshotting a real version), and template categories/tags/filtering.
