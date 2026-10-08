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

- `WebsiteChecklist::Site` (a client's website) has `Item`s. `Site::Defaults` is the standard
  checklist, made once per site; item keys are fixed once used (`sender:from_email`,
  `forms:<slug>:notification`, `custom:<hex>`).
- `Item` holds the verbs: `confirm`, `mark_not_applicable`, `reopen`, `revise` (a person's
  change; a new value is to confirm again) and `detect` (the CMS's value; a confirmed value it no
  longer matches becomes `changed`, and back again `confirmed`). State is one of `unconfirmed`,
  `confirmed`, `changed`, `not_applicable`; `confirmed_value` is what was confirmed.
- `Site::Syncable#sync_now` reads the CMS (`Site::CmsReading`, over `WebsiteChecklist::Cms`, a
  read-only Net::HTTP client with timeouts) and never raises: what failed goes in `sync_error`.
  Only read CMS endpoints that exist in the CMS's source; the list is in the README and at the
  top of `Site::CmsReading`. Tests stand in for the CMS through `Cms.transport`.
- `Site::SyncJob` is shallow; the nightly task queues one per CMS-linked site.
