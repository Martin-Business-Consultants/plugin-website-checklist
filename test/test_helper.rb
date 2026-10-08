# The plugin's tests run inside a Runwell checkout, whose own tests don't load plugins. From
# Runwell's directory, with this plugin linked (bin/rails "plugins:link[path]"):
#
#   bin/rails test path/to/website_checklist/test
#
# This loads the plugin before Runwell boots, runs Runwell's test setup (fixtures, sign_in_as),
# then adds the plugin's tables to the test database.
ENV["RAILS_ENV"] = "test"
ENV["PARALLEL_WORKERS"] ||= "1"
runwell = ENV.fetch("RUNWELL", Dir.pwd)

require File.join(runwell, "config/boot")
require "rails"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "website_checklist"
require File.join(runwell, "test/test_helper")

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.connection_pool.then do |pool|
  ActiveRecord::MigrationContext.new([ File.expand_path("../db/migrate", __dir__) ], pool.schema_migration, pool.internal_metadata).migrate
end

module WebsiteChecklist
  # A CMS that answers from a hash of path => [status, body] (or body, meaning 200), recording
  # what was asked. Anything not listed is a 404.
  module CmsStandIn
    def stand_in_cms(responses)
      requests = []
      WebsiteChecklist::Cms.transport = ->(uri, token) {
        path = uri.request_uri
        requests << [ path, token ]
        status, body = responses.fetch(path) { [ 404, { error: "not_found" } ] }.then { it.is_a?(Array) ? it : [ 200, it ] }
        [ status, body.is_a?(String) ? body : body.to_json ]
      }
      requests
    end

    REAL_TRANSPORT = WebsiteChecklist::Cms.transport

    def self.included(base)
      base.teardown { WebsiteChecklist::Cms.transport = REAL_TRANSPORT }
    end

    # Everything a fully set-up CMS says.
    def full_cms
      {
        "/api/settings/general" => { setting: { key: "general", data: { site_base_url: "https://acme.example" } } },
        "/api/settings/forms_settings" => { setting: { key: "forms_settings", data: { from_name: "Acme", from_email: "hello@acme.example" } } },
        "/api/sitemap" => { site_base_url: "https://acme.example", count: 12, entries: [] },
        "/api/forms?status=published" => { forms: [ { slug: "contact", title: "Contact", status: "published", notify_webhook_url: "https://hooks.example/crm" } ] },
        "/api/forms/contact/emails" => { emails: [
          { kind: "notification", enabled: true, subject: "New enquiry", recipients: "ann@acme.example, bob@acme.example", content_digest: "aaaa" },
          { kind: "confirmation", enabled: true, subject: "Thanks for writing", recipients: nil, content_digest: "bbbb" }
        ] },
        "/api/webhooks" => { webhooks: [ { name: "Zapier", url: "https://hooks.zapier.com/x", active: true, events: [ "submission.created" ], last_status: "success" } ] }
      }
    end
  end
end
