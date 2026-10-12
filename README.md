# Website checklist for Runwell

Every client's websites, each with a step-by-step checklist to take it live: the place to gather
and record everything a launch needs, in the order to get it. Access comes first (the domain
registrar, DNS, the domain's email, the current site, Google Search Console, Google Analytics,
the Business Profile, Bing), then forms and email, the launch itself, and what follows it.

A Runwell plugin (Runwell's `docs/plugins.md`): a Rails engine that owns its `website_checklist_*`
tables, reaches clients by id, and extends the core only through the plugin contract. Needs
Runwell 2.24 or newer.

## Install

Settings › Plugins › Install, with `Martin-Business-Consultants/plugin-website-checklist`, or from
the shell:

    bin/rails "plugins:install[Martin-Business-Consultants/plugin-website-checklist]"

Then switch it on in Settings › Plugins. Remove deletes its code and keeps its tables.

## What it does

- **Websites**, in the nav: every client's sites, those with steps still to do first, and a
  **Websites** tab on each client.
- **The go-live checklist**, numbered, in the order to work through it:
  1. Access: domain registrar, DNS, the domain's email, the current website, Google Search
     Console, Google Analytics, Google Business Profile, Bing Webmaster Tools
  2. Forms and email: who gets form notifications, the name and address they come from, SPF,
     DKIM and DMARC, the notification's wording, the confirmation approved by the client, and
     webhooks
  3. Launch: old addresses redirected, DNS switched, domain and HTTPS, email still arriving, a
     test submission received, client sign-off
  4. After launch: sitemap URL, sitemap submitted to Google and Bing, analytics receiving data,
     the Business Profile's website link
  5. Custom: anything else the team adds.
- **A list and the step beside it**: the steps on the left, each with a dot for its state; pick
  one and it opens on the right with what it's for, how to do it, and an example of what to
  record. Saving a value confirms it as yours (your name and the time are kept), and emptying it
  puts it back to do. A step the site doesn't need is marked so, and Next goes on to the
  following step. The page opens on the first step still to do.
- **Webhooks** are recorded one by one, each folding open: its name, its URL, and the keys and
  values it's set up with (add and remove rows as you go).
- **Files** on every step, beside its note, in a drop box: drop files on it or choose them (an
  export, a screenshot, the sitemap).
- **Work** from the website's page: the button opens a sheet on the right to add a todo on one of
  the client's open engagements, about the step on screen (or the site as a whole), with a lead,
  a due date and details (with @mentions). It's linked back to the step, which lists its work.
- **AI audit** (with the AI plugin on, 1.2 or newer): a sheet two-thirds of the window wide that
  takes the site's domain and finds out what it can from outside, without logging in anywhere:
  the registrar and when the domain renews (the registry's RDAP record), who hosts its DNS and
  email, SPF and DMARC, Google and Bing verifications, how its addresses answer, the Analytics and
  Tag Manager IDs on its home page, where its forms post, and its robots.txt and sitemap (kept as a
  file). The install's AI turns that into a recommendation per step, listed on the sheet's left;
  the one picked shows on its right, to approve as it is, change and approve, or reject. Approving
  records it on the step as yours (in the history) and attaches any file it brought. Only public
  addresses are fetched.
- Never a password or secret: record where it's kept.
- **History**: every change to a website, its steps and its webhooks is kept, with who made it
  (a person, or their agent and the app it came through), when, and each field's before and
  after. For all websites (History on the Websites page), one website (History on its page) or one
  step and its webhooks (History beside the step), and as a CSV download. Deleting a website
  keeps its history.

## Permissions

Everyone on staff sees websites and records, confirms and reopens items. Adding, changing and
deleting websites takes "Add, change and delete websites" (owners and managers).

## Agents

Every page has its tool: `list_websites`, `show_website` (each step with how to do it, and the
next step), `create_website`, `update_website`, `delete_website`, `add_website_item`,
`update_website_item` (`webhooks_attributes` for the Webhooks step), `delete_website_item`,
`confirm_website_item`, `reopen_website_item`, `mark_website_item_not_applicable`,
`add_website_item_file`, `remove_website_item_file`, `add_website_work`, `audit_website_with_ai`,
`show_website_ai_audit`, `approve_website_recommendation`, `reject_website_recommendation` and
`website_history`. "Taking a
client's website live" is offered to agents as a workflow.

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
