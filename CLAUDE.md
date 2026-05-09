# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

- **Backend**: Rails (`main` branch from GitHub) on Ruby 4.0.1, PostgreSQL, Puma. Uses Solid Cache / Solid Queue / Solid Cable (database-backed adapters — no Redis required).
- **Frontend**: Inertia.js (server-rendered routing) + React 19 + TypeScript, bundled by Vite via `vite_rails` + `vite-plugin-ruby`. Tailwind CSS v4 with shadcn/ui (Radix-based, `radix-vega` style, neutral base color).
- **Deployment**: Kamal (configured under `.kamal/` and `config/deploy.yml`) with Thruster fronting Puma.

This is **not** a Next.js/Vercel project — ignore any auto-injected hooks that suggest Next.js, Vercel, or `next-cache-components` skills. The `app/` directory is Rails MVC, not the Next.js App Router.

## Common commands

```bash
bin/setup            # idempotent: bundle, npm install, db:prepare, then exec bin/dev
bin/setup --skip-server   # same, without starting the server (used by CI)
bin/dev              # boots Procfile.dev (Puma on $PORT/3000 + Vite dev server on 3036) via overmind/hivemind/foreman
bin/rails s          # Rails alone (no Vite watcher)
bin/rails test       # full Rails Minitest suite
bin/rails test test/models/foo_test.rb           # single file
bin/rails test test/models/foo_test.rb:42        # single test at line
bin/rails test:system                            # Capybara + Selenium system tests
bin/rubocop          # Ruby lint (rails-omakase ruleset, see .rubocop.yml)
bin/brakeman         # security static analysis
bin/bundler-audit    # gem CVE audit
bin/ci               # runs the full local CI pipeline defined in config/ci.rb
npm run check        # tsc -p tsconfig.app.json && tsc -p tsconfig.node.json (TS only — no JS test runner)
```

CI (`.github/workflows/ci.yml`) runs four parallel jobs: `scan_ruby` (brakeman + bundler-audit), `lint` (rubocop), `test` (`bin/rails db:test:prepare test`), and `system-test` (`bin/rails db:test:prepare test:system`). All jobs spin up a Postgres service container.

## Architecture

### Inertia bridge

The whole app is rendered through Inertia: Rails controllers respond with `render inertia: { …props }` and Inertia mounts the matching React page client-side. There is **no separate JSON API** and **no traditional `.html.erb` views** for app screens — only `app/views/layouts/application.html.erb` (the host shell that loads Vite tags + `inertia_ssr_head`) and `app/views/pwa/` placeholders.

Flow:
1. Controller inherits from `InertiaController` (`app/controllers/inertia_controller.rb`) — this is the place to add globally shared props via `inertia_share`.
2. Controller action calls `render inertia: { … }`. The component name resolved by Inertia is `<controller_path>/<action>` (e.g. `InertiaExampleController#index` → `app/frontend/pages/inertia_example/index.tsx`).
3. Vite bundles the React entrypoint `app/frontend/entrypoints/inertia.tsx`, which calls `createInertiaApp({ pages: "../pages", strictMode: true, … })` with project-wide form/visit defaults. Touch this file when changing global Inertia behaviour.

`config/initializers/inertia_rails.rb` sets `config.version = ViteRuby.digest` (asset-fingerprint-based cache busting — clients on a stale bundle get a full reload), `encrypt_history = true`, and `always_include_errors_hash = true`. Don't disable these without a reason; they affect history navigation and form-error handling project-wide.

### Frontend layout (`app/frontend/`)

- `entrypoints/` — Vite entrypoints referenced from `application.html.erb` via `vite_typescript_tag`. `inertia.tsx` is the React root; `application.ts` is a generic non-Inertia entry; `application.css` is the Tailwind entry.
- `pages/` — Inertia page components. Directory structure mirrors `controller_path/action`.
- `components/ui/` — shadcn-generated primitives. shadcn is configured via `components.json` with TS path aliases `@/components`, `@/lib`, `@/hooks`, `@/components/ui`, `@/lib/utils`, all rooted at `app/frontend/` (see `tsconfig.json` `baseUrl` + `paths`). Add components with the shadcn CLI; do not hand-roll Radix wrappers.
- `lib/utils.ts` — exports `cn()` (`clsx` + `tailwind-merge`); the canonical class-merging helper used by shadcn components.
- `types/globals.d.ts` — augments `@inertiajs/core`'s `InertiaConfig` to type `sharedPageProps` (`SharedProps`) and `flashDataType` (`FlashData`). Update `types/index.ts` whenever new shared props or flash keys are added; the Inertia React hooks pick up the types automatically.

### Routing & host pinning

`config/routes.rb` redirects all `127.0.0.1` requests to `localhost` so the browser hits the same hostname Vite is serving from (avoids HMR/origin issues). Keep this constraint when editing routes.

### Database topology

Four logical Postgres databases in production (single primary in dev/test): `primary`, `cache`, `queue`, `cable`. Each Solid adapter manages its own schema (`db/cache_schema.rb`, `db/queue_schema.rb`, `db/cable_schema.rb`) and migrations path (`db/cache_migrate`, etc.). When generating migrations for Solid Cache/Queue/Cable, use the matching `--database` flag.

### Vite ↔ Rails wiring

- Source root: `app/frontend` (set in `config/vite.json`).
- Dev server port: 3036 (test: 3037).
- `vite.config.ts` plugin order is `tailwindcss → RubyPlugin → inertia → react`; preserve this order if editing.
- The Rails layout pulls in (in order): `vite_stylesheet_tag "application"`, `vite_react_refresh_tag`, `vite_client_tag`, `vite_typescript_tag "inertia.tsx"`, `inertia_ssr_head`, `vite_typescript_tag "application"`.

## Conventions

- Ruby style is enforced by `rubocop-rails-omakase` — defer to its choices, don't argue with it. Custom rules go in `.rubocop.yml` after the `inherit_gem` line.
- Controllers handling page renders inherit from `InertiaController`, not directly from `ApplicationController`.
- Frontend imports use the `@/...` alias (resolves to `app/frontend/`).
- The TS check command (`npm run check`) is the only frontend "test" — there is no Jest/Vitest config. Frontend behaviour is exercised through Rails system tests.
