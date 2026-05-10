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
- **Casing across the Inertia boundary**: server keys are `snake_case`, client keys are `camelCase`. The `inertia-caseshift` Vite plugin (in `vite.config.ts`) handles the bidirectional conversion automatically — props, errors, flash, deferred/merge/scroll metadata, and form data. Always write Ruby/Rails props (`inertia_share`, `render inertia: {...}`, model attributes) in `snake_case` and TypeScript types/components (`SharedProps`, `usePage().props.someThing`) in `camelCase`. Don't manually convert in either direction.
- **Nested resources mirror their parent in the controller module**: when a route is nested under another resource, the child controller lives under a module named after the parent. Use `module:` on `resources` to make the controller path follow the URL path. Example:

    ```ruby
    namespace :organizations do
      resources :merchants do
        resources :invitations, only: :create, module: :merchants
      end
    end
    ```

  → `Organizations::Merchants::InvitationsController` at `app/controllers/organizations/merchants/invitations_controller.rb`. Don't flatten nested resources into the parent namespace (e.g. `Organizations::InvitationsController`); the module nesting must mirror the URL nesting.

- **RESTful controllers only — no custom action verbs**: every controller action is one of `index`, `new`, `create`, `show`, `edit`, `update`, `destroy`. State transitions, side-effecting operations, and "verbs" on a parent resource are modeled as their own sub-resources whose `#create` performs the action. This keeps controllers strictly CRUD, sidesteps Ruby keyword collisions (`def end`), and reads more clearly in the route table.

    ```ruby
    # Wrong: custom verbs as member actions on the parent
    resources :campaigns do
      member do
        post :activate
        post :end, action: :end_campaign  # `end` is reserved in Ruby
      end
    end
    ```

    ```ruby
    # Right: each transition is its own sub-resource
    resources :campaigns do
      resource :activation,  only: :create, module: :campaigns
      resource :termination, only: :create, module: :campaigns
    end
    ```

    → `Organizations::Campaigns::ActivationsController#create` and `Organizations::Campaigns::TerminationsController#create`. The "noun" for the resource is whatever the operation produces (an activation event, a termination event, an invitation, a redemption, etc.).

- **UUIDv7 primary keys** — every new table uses native PostgreSQL `uuid` PKs generated by `uuidv7()` (PostgreSQL 18+). Rails generators are configured to default `primary_key_type: :uuid` (see `config/application.rb`), but the `default:` expression has to be added per-migration:

    ```ruby
    create_table :foos, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :bar, type: :uuid, null: false, foreign_key: true
      ...
    end
    ```

  Foreign keys must specify `type: :uuid` (Rails won't infer it from the parent's PK type). UUIDv7 sorts by creation time, so `ORDER BY id` is roughly chronological — no need to introduce a separate `created_at` index for newest-first queries on small tables. Don't switch to `gen_random_uuid()` (UUIDv4); we want the time-ordering and Postgres 18 native UUIDv7 generation.

- **Vanilla Rails — no service objects**: domain logic lives on rich models, not in `app/services/`. Follow [Vanilla Rails is plenty](https://dev.37signals.com/vanilla-rails-is-plenty/) and [Good concerns](https://dev.37signals.com/good-concerns/). The point of an architectural decision is to make the next change easier; reaching for `Foo::Bar.call(...)` for every multi-step operation flattens the domain into procedures and produces anemic models.

    - **Controllers call model APIs directly.** Simple CRUD: `current_organization.campaigns.create!(params)`. Complex operations: `@campaign.activate!`, `@stamp.confirm_pending_for(merchant: …, code: …)`, `Visit.create_from_scan!(customer:, merchant:)`. The model owns orchestration; the controller is HTTP plumbing.

    - **Multi-step writes belong on the model.** Wrap in a transaction inside the model. Validation contexts (`validate :foo, on: :activation` then `valid?(:activation)`) are the right tool for state-transition guards. Use `accepts_nested_attributes_for` and `has_many :through` collection writers (`campaign.merchant_ids = [...]`) before reaching for anything custom.

    - **Concerns are good when they capture a real "acts as / has trait" axis** (`Sluggable`, `Activatable`, `Confirmable`, `Mergeable`). They're bad when used as arbitrary file-splits to "tidy up" a fat model — that's still procedural code, just relocated. A good concern reflects a domain concept; a bad one is a dumping ground.

    - **Concern placement depends on scope**:
      - **Cross-model concerns** (≥2 models share the trait) live at `app/models/concerns/<name>.rb` as a top-level constant: `Sluggable`. The Sluggable concern is shared by `Organization`, `Merchant`, and `Campaign`.
      - **Single-model concerns** (only one model uses it, but the behavior is cohesive enough to warrant its own file) live at `app/models/<model_name>/<name>.rb`, namespaced under the model: `OrganizationCampaign::Activatable` at `app/models/organization_campaign/activatable.rb`. Even when only one model uses it today, factoring a coherent slice (state-transition guards, redemption math, code generation) into its own concern improves readability, makes the model's surface area legible at a glance, and isolates the change footprint when that slice evolves. **Do not** dump single-model concerns into `app/models/concerns/` — the global namespace there is reserved for cross-model traits.
      - **A concern that gets reused later** moves out from under the model namespace into `app/models/concerns/`. Refactor when the second user appears, not before.

    - **PORO helpers under the model namespace are fine** when something genuinely warrants its own class but is internal to one model — e.g. `Stamp::CodeGenerator`, `Recording::Copier`. The public API stays on the model (`stamp.confirm_pending_for(...)`); the helper is a private collaborator. Never expose helpers as the call site.

    - **System-boundary integrations are jobs or `lib/` adapters**, not services. `WhatsAppDeliveryJob` over `WhatsAppDispatcher`. The job IS the boundary; a "dispatcher service" wrapping a job is one indirection too many.

    Don't introduce `app/services/`. If you find yourself drafting `Foo::Bar.call(...)`, rephrase as `foo.bar(...)` and put it on the model. Almost every "service" we've considered turned out to be a method that wanted to live on a model.

- **Guard preconditions in `before_action`, not inline early-returns** — when a controller action depends on a precondition (record state, presence of a parameter, scoping, etc.), express it as a `before_action` that redirects on failure. Rails halts the action whenever a filter renders or redirects, so the action body is reached only on the happy path. Load shared records into instance variables in their own filter and reference them with `@var`. Apply scoped filters with `only:` / `except:` when the controller has more than one action.

    ```ruby
    # Wrong: validation tangled into the action body
    def create
      student = current_organization.students.find(params[:student_id])
      recording = student.voice_recordings.find(params[:voice_recording_id])
      edited = params[:anamnesis_md].to_s

      if recording.status != "completed" || edited.strip.empty?
        redirect_to student_voice_recording_path(student, recording),
                    alert: edited.strip.empty? ? "A anamnese não pode ficar em branco." : "A geração da anamnese ainda não terminou."
        return
      end

      student.update!(anamnesis_md: edited)
      redirect_to student_path(student), notice: "Anamnese atualizada."
    end
    ```

    ```ruby
    # Right: load + guards live in before_action; the action is just the happy path
    before_action :load_student_and_recording
    before_action :ensure_recording_completed_and_value_present

    def create
      @student.update!(anamnesis_md: edited_anamnesis)
      redirect_to student_path(@student), notice: "Anamnese atualizada."
    end

    private
      def load_student_and_recording
        @student = current_organization.students.find(params[:student_id])
        @recording = @student.voice_recordings.find(params[:voice_recording_id])
      end

      def edited_anamnesis
        @edited_anamnesis ||= params[:anamnesis_md].to_s
      end

      def ensure_recording_completed_and_value_present
        return if @recording.status == "completed" && !edited_anamnesis.strip.empty?

        redirect_to student_voice_recording_path(@student, @recording),
                    alert: edited_anamnesis.strip.empty? ? "A anamnese não pode ficar em branco." : "A geração da anamnese ainda não terminou."
      end
    ```

    Name guard filters with an `ensure_` prefix so the precondition reads at the call site (`ensure_audio_present`, `ensure_version_editable`, `ensure_transcript_present`). When two actions need the same guard with different copy, prefer two narrow filters (`ensure_version_editable`, `ensure_version_destroyable`) over one filter that branches on `action_name`.
