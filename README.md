# Website checklist for Runwell

Every client's websites, each with a checklist of how it's set up — who form emails go to and
come from, what the confirmation says, where submissions are posted, whether the sitemap went to
the search engines, who signed off — recorded and confirmed by a person, so there is one
accurate source of truth per site.

A Runwell plugin (Runwell's `docs/plugins.md`): a Rails engine that owns its `website_checklist_*`
tables, reaches clients by id, and extends the core only through the plugin contract. Needs
Runwell 2.21 or newer.

## Install

Settings › Plugins › Install, with `Martin-Business-Consultants/plugin-website-checklist`, or from
the shell:

    bin/rails "plugins:install[Martin-Business-Consultants/plugin-website-checklist]"

Then switch it on in Settings › Plugins. Remove deletes its code and keeps its tables.

## What it does

- **Websites**, in the nav: every client's sites, those needing attention first (something to
  confirm, changed since it was confirmed, a problem, or a CMS that couldn't be read), and a
  **Websites** tab on each client.
- **The checklist**: every site starts with the standard one —
  - Email sender: from name, from email, SPF/DKIM/DMARC for the sender's domain
  - Forms: who the admin notification goes to (to and CCs), its wording, the confirmation
    email's wording approved by the client, a test submission received
  - Webhooks: where submissions go besides email
  - Search: sitemap URL, sitemap submitted to Google Search Console and to Bing, analytics
    receiving data
  - Launch: domain and HTTPS, client sign-off
  - Custom: anything else the team adds.
- **Confirming**: record a value and a note, then Confirm (your name and the time are kept, with
  the value as confirmed), mark Not applicable, or Reopen. A new value has to be confirmed again;
  the old one shows as "was confirmed as".
- **Read from the CMS** (optional): give a site its LibrePublish CMS address and an API token,
  and "Read the CMS" (and a nightly run) fills in what the CMS can tell: the from name and email,
  each published form's notification recipients, notification and confirmation wording (subject
  and a content fingerprint), where each form posts, the CMS's webhooks, the sitemap and the
  domain. Every value can still be edited: until someone does, it follows the CMS; after, it's
  what the site should be, and a CMS that says otherwise is flagged (editing doesn't change the CMS). A confirmed value
  the CMS no longer matches shows as **Changed**, and problems the CMS shows (a notification
  switched off, a sender off the site's domain, a failing webhook, no HTTPS) are flagged. Each
  item links to where it's set in the CMS.

  It reads these endpoints, with the token's own permissions; whatever it can't read is listed
  on the site and the checklist keeps working:

  | Endpoint | Needs | For |
  | --- | --- | --- |
  | `GET /api/settings/general` | `settings:read` | the site base URL |
  | `GET /api/settings/forms_settings` | `settings:read` | from name, from email |
  | `GET /api/sitemap` | a token | sitemap URL and size |
  | `GET /api/forms?status=published` | `forms:read` (Forms plugin) | the published forms |
  | `GET /api/forms/:slug/emails` | `forms:read` | each form's notification and confirmation |
  | `GET /api/webhooks` | `webhooks:read` | the CMS's webhooks |

## Permissions

Everyone on staff sees websites and records, confirms and reopens items. Adding, changing and
deleting websites takes "Add, change and delete websites" (owners and managers).

## Agents

Every page has its tool: `list_websites`, `show_website`, `create_website`, `update_website`,
`delete_website`, `sync_website`, `add_website_item`, `update_website_item`,
`delete_website_item`, `confirm_website_item`, `reopen_website_item` and
`mark_website_item_not_applicable`. "Checking a client's website" is offered to agents as a
workflow.

## Developing

Clone it beside a Runwell checkout, then from Runwell:

    bin/rails "plugins:link[../plugin-website-checklist]"
    bin/rails db:migrate
    bin/dev

Its tests run from the Runwell checkout (Runwell's own suite doesn't load plugins; the plugin's
`test/test_helper.rb` loads it and adds its tables to the test database):

    bin/rails test ../plugin-website-checklist/test

`bin/rails agent:coverage`, `bundle exec herb lint ../plugin-website-checklist/app/views` and
`bin/rubocop ../plugin-website-checklist` should all be clean.

## Releasing

Bump `lib/website_checklist/version.rb`, commit, and push a matching `vX.Y.Z` tag: the release
workflow publishes it, and installs see it as an update in Settings › Plugins.
