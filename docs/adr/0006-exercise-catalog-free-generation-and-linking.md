# Exercise catalog: free generation, async linking, global scope

The AI generates **Workouts** with free-text **Exercise names** *without* consulting any catalog — this preserves the variety that comes from the model's stochastic nature, which a catalog-constrained generator would lose (especially while the catalog is small). A separate asynchronous **Linking** pass then resolves each name to a canonical **Exercise**, minting a new **Unenriched** one when no match exists. We accept that generation and the catalog can drift; reconciliation is the linker's job, not a constraint on generation.

## Where links live

Links live in a side `Exercise::Alias` table keyed by a **Normalized key** (accent-stripped, lowercased, whitespace-collapsed — the same normalization `ExerciseLoad` already uses for weight history). The canonical `Exercise` id is **never** written back into **Block** JSON: version and training-session block snapshots are immutable, so mutating them to carry a link would violate that invariant. **Resolution** is therefore always `Exercise name → Normalized key → Alias → Exercise`, computed at read time. A `UNIQUE` constraint on the normalized key is the correctness backstop; the linker runs on a single worker so concurrent versions can't canonize the same movement twice and each run sees the prior run's new aliases.

## Bias to split, not merge

When the linker is unsure, it mints a new Exercise rather than attaching an alias to an existing one. A false split is a cheap, reversible duplicate (cleaned up later via the **Exercises admin**); a false merge silently shows the wrong media for a movement. v1 has no human review queue — confidence is recorded but not gated on.

## Global scope, no role (v1)

The catalog is **fully global** — never per-student or per-organization. v1 ships with **no admin/staff role and no organization scope**: the app is SteimFit-internal, so every trainer can curate the global catalog through the Exercises admin. Org-scoping and a dedicated internal-admin role are deferred until the product is sold to another organization.

## Why record this

- **Hard to reverse** — constraining generation to the catalog, or retrofitting organization scope / an admin role / links embedded in block snapshots, are schema migrations plus reworks.
- **Surprising without context** — a future reader will ask "why doesn't the AI generate against the catalog?", "why is the catalog global and editable by any trainer?", and "why isn't the canonical id just stored on the block?"
- **A real trade-off** — variety over consistency in generation; read-time resolution over denormalized links to protect snapshot immutability; internal-only simplicity over multi-tenant correctness.
