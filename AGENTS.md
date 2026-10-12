# Website checklist, a Runwell plugin — guide for AI agents

This repository is a plugin for Runwell (a Rails 8.1 engine loaded into a Runwell install). It is
not an app on its own: run it from a Runwell checkout with `bin/rails "plugins:link[path]"`.

Read first, in Runwell's repository:
- `docs/plugin-contract.md`: everything a plugin may rely on, with versions. Use nothing else of
  the core's. Raise `requires:` in the manifest to the newest version you use.
- `AGENTS.md`: the core's conventions, which plugin code follows too.

## Rules

- Own your tables, prefixed with the key (`website_checklist_*`), pointing at core records by id.
  Never add columns to core tables or write core rows except through core model verbs.
- Register everything in `config.to_prepare`, keyed by the plugin's key. Controllers inherit
  `WebsiteChecklist::ApplicationController` (404 while switched off).
- Every controller action declares an authorization rule (`allow_staff`, `require_permission`)
  and an `agent_tool` or `agent_exempt`. Reads get a `.json.jbuilder` view with `agent_ref` and a
  `summary`. Write notices an AI can act on.
- Views follow the core's ReActionView rules: strict locals on every partial's first line,
  `<%# herb:key %>` before each loop row, no inline CSS, no partials inside `form_with`. Use the
  core's helpers and shared partials (listed in the contract) and `term()` for the core's nouns.
- CSS uses Runwell's design tokens (`docs/theming.md`), in `@layer components`.
- Migrations are safe on a live install: add in one release, remove only in a later one.
- Use only gems Runwell bundles: plugins load outside Bundler.
- The core's request and job N+1 detection (Prosopite) runs in tests: no query per item in a loop.

## Layout

- `lib/website_checklist/engine.rb`: routes, the client hook, registrations
- `app/`: models, controllers, views, stylesheet under `website_checklist/`
- `db/migrate/`: the plugin's tables
- `test/`: Minitest, run from a Runwell checkout (`bin/rails test path/to/this/test`)

## This plugin

- `WebsiteChecklist::Site` (a client's website) has `Item`s: the steps to take it live.
  `Site::Defaults` is the standard checklist, in order (access first), with each step's `how` and
  `example`, read from code rather than stored. `Site#apply_standard_checklist` adds missing steps
  and brings order and wording up to date (on create, and in a migration when the list changes).
  Item keys are fixed once used (`access:dns`, `custom:<hex>`).
- `Item` holds the verbs: `confirm`, `mark_not_applicable`, `reopen`, `revise` (a person's
  change; a new value is to confirm again) and `record` (save and confirm). State is one of
  `unconfirmed`, `confirmed`, `not_applicable`; `confirmed_value` is what was confirmed.
- The Webhooks step (`Item#webhooks?`) records `Webhook`s (name, url, `pairs` of keys and values)
  through nested attributes; its value is them written out. The form is a repeater over the
  core's `repeater` Stimulus controller, built in `SitesHelper` (partials can't render in a form).
- Every change is audited (`Audited`, included in `Site`, `Item` and `Webhook`): an `Audit` per
  create, update and delete with the changed fields' before and after as people read them, who
  (`Current.user`, `Current.source`, the token's name) and the site, written in the save's
  transaction. Bulk writes that skip callbacks (`insert!`, `delete_all`) aren't audited: keep
  them to system work (`apply_standard_checklist`, a site's deletion, which is audited itself). A
  verb should save once so a change is one entry (`Item#record`). `AuditsController` shows them.
- Steps keep files (`Item#files`, Active Storage; `add_file` / `remove_file` audit them).
- The AI audit: `Scan` (a site's domain) runs in `ScanJob`: `Site::Probe` gathers facts from
  outside (DNS through Resolv, RDAP through rdap.org, the pages over Net::HTTP with timeouts, size
  caps and a refusal of private addresses; every part fails on its own) and keeps files (the
  sitemap); then the AI plugin's `Ai.structured` (1.2.0; checked with `Scan.ai_available_for?`,
  so this plugin works without it) answers a strict schema of recommendations, one per step key.
  `Recommendation#approve!` records through `Item#record` as the approver and attaches the file;
  `reject!` leaves the step alone. The sheet is `scans/index` in a lazy frame inside a modal on
  the site's page; its Done link reloads the page.
- Work from a site's page (`TodosController`): a core `Todo` made on one of the client's open
  engagements through the model (`todo.created` recorded as the core does), linked by `TodoLink`
  (site, optional step, todo id) and listed on the step; a todo deleted in the core drops out.
- There is no CMS integration (removed in 0.3). The old CMS columns are ignored
  (`ignored_columns`) and dropped in a later release.
