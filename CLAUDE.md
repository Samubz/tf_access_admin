# tf_access_admin — Development Guide

Project context (stack, domains, conventions) lives in `openspec/config.yaml` and is injected into OpenSpec artifact generation. Read it when you need product or domain background.

## Workflow

- Keep changes minimal and scoped.
- For non-trivial changes or when the user references an OpenSpec change, follow the OpenSpec workflow.
- Use skills lazily and only when they directly apply to the current task.
- Do not produce implementation summaries or change logs unless explicitly requested.

### Frontend Guidelines

When frontend implementation details are needed, read `frontend-guidelines.md`.

## Context & Token Efficiency

Prefer minimal, targeted context.

* Do not read broad directories or full files unless required.
* Prefer targeted search/grep before opening complete files.
* Do not reread the same section unless the previous read was insufficient or contradictory.
* Before making non-trivial edits, identify the smallest set of files needed.
* Avoid long terminal output. When commands fail, focus on the first relevant error.
* Run focused tests first. Do not run the full suite unless explicitly requested or required by the task.
* Do not produce implementation summaries, change logs, or long explanations unless explicitly requested.
* If more than 6 additional files seem necessary, pause and explain why before loading more context.
* Prefer `rg`/targeted search before opening complete files.
* When a match is found, read only the minimum surrounding range needed.

## Skills

Use skills lazily and only when they directly apply to the current task.
Available skills:
- `rails-expert`
- `vue`

Skill loading rules:

- Use `rails-expert` when modifying:
  - `app/models/**`
  - `app/controllers/**`
  - `app/policies/**`
  - `app/services/**`
  - `app/serializers/**`
  - `app/jobs/**`
  - `db/migrate/**`
  - `config/routes.rb`
  - Rails tests under `test/**`

- Use `vue` when modifying:
  - `app/javascript/pages/**`
  - `app/javascript/components/**`
  - `app/javascript/layouts/**`
  - `app/javascript/lib/**`
  - Vue components
  - TypeScript frontend code
  - Inertia props consumed by Vue pages
  - frontend i18n usage

- If a task touches both Rails props/serializers/controllers and Vue pages/components, use both `rails-expert` and `vue`.
- Do not load every available skill by default.
- If the task is small and the relevant convention is already clear from nearby code, prefer following existing patterns without loading extra skills.
- If a skill is loaded, use only the relevant section. Do not restate or summarize the skill in the final response.

## Forms

Every form must define client-side validation with **Zod** and **VeeValidate**.

* Define Zod schemas in `app/javascript/lib/schemas/`.
* Wire schemas to VeeValidate via `toTypedSchema` from `@vee-validate/zod`.
* Use `useForm` with the typed schema; bind fields with `Field as VeeField` from `vee-validate`.
* Display field errors with `FieldError` and translate Zod messages via `useTranslateErrors`.
* Merge Rails/server errors with `useServerFormErrors` when the form submits to the backend.
* Before creating a new form, inspect a similar existing form (e.g. `app/javascript/components/admin/organization/Form.vue`) and follow the same pattern.

## OpenSpec Workflow

Follow OpenSpec only for non-trivial changes or when the user references an OpenSpec change.

For OpenSpec implementation tasks:

* `tasks.md` defines scope.
* `specs/**/spec.md` defines business rules and acceptance scenarios.
* `design.md` defines technical strategy and implementation decisions.
* `proposal.md` defines motivation and should only be read when the scope or intent is unclear.

Reading rules:

* Read only the current numbered task section from `tasks.md`.
* Do not read full `tasks.md` unless dependencies are unclear.
* Read `specs/**/spec.md` with targeted search for Requirements/Scenarios directly related to the current task.
* Do not read full specs by default.
* Read `design.md` only for technical decisions related to the current task.
* Do not read `proposal.md` unless the goal, scope, or motivation is ambiguous.
* Before editing, produce a brief plan with:

  * current task items detected
  * business rules from related spec scenarios
  * technical decisions from design, if needed
  * maximum 6 files expected to be reviewed or modified
* Implement only the requested task section.
* Mark `- [ ]` → `- [x]` only for completed tasks in the requested section.
* If a requested item depends on incomplete prior work, report it instead of implementing out-of-scope work.

## graphify

This project has a knowledge graph at `graphify-out/` with god nodes, community structure, and cross-file relationships.

Use graphify selectively.

* Prefer grep/search/direct file lookup for simple file location or known symbols.
* Use graphify when relationships are unclear, impact spans multiple layers, or the task asks for architectural understanding.
* Do not run broad graphify queries by default.
* Prefer focused commands:

  * `graphify path "<A>" "<B>"` for relationships.
  * `graphify explain "<concept>"` for a focused concept.
  * `graphify query "<specific question>"` only when the question is narrow.
* Avoid graphify queries that return large subgraphs unless broad architecture review is explicitly needed.
* If `graphify-out/wiki/index.md` exists, use it for broad navigation before reading `GRAPH_REPORT.md`.
* Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review or when query/path/explain are insufficient.
* After modifying code, run `graphify update app` unless the user says not to.
* If `graphify update app` fails, report the error briefly. Do not debug graphify issues unless they were caused by the current changes.

## Validation

Use the cheapest validation that gives confidence.

* For Rails changes, prefer targeted Minitest files or line-based tests first.
* For Vue/TypeScript changes, prefer `npm run check` only when frontend types may be affected.
* For style/security, run RuboCop, Brakeman, bundler-audit, or full `bin/ci` only when explicitly requested or when the task requires it.
* Avoid repeated `git diff` calls. Use one final diff review before finishing, or after a major change when necessary.

## Final Response

Unless the user asks for a detailed summary, respond only with:

* Files modified.
* Tasks completed.
* Tests/validations executed.
* `graphify update app` result, when applicable.
* Pending risks or blockers.

Do not include long implementation summaries.
