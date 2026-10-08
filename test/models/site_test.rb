require_relative "../test_helper"

module WebsiteChecklist
  class SiteTest < ActiveSupport::TestCase
    include CmsStandIn, ActiveJob::TestHelper

    setup { @client = clients(:acme) }

    test "a new site starts with the standard checklist, once" do
      site = Site.create!(client: @client, name: "Main site", url: "https://acme.example/")

      assert_equal Site::Defaults::ITEMS.size, site.items.count
      assert_equal "https://acme.example", site.url
      assert site.items.all? { it.state == "unconfirmed" && it.kind == "recorded" }
      site.add_default_items
      assert_equal Site::Defaults::ITEMS.size, site.items.count
      assert_equal site, @client.website_checklist_sites.first
    end

    test "a CMS needs its token, and addresses need a scheme" do
      site = Site.new(client: @client, name: "Main", url: "acme.example", cms_url: "https://cms.example")

      assert_not site.valid?
      assert site.errors[:url].any?
      assert site.errors[:cms_token].any?
    end

    test "the token is stored encrypted, and a blank one keeps it" do
      site = Site.create!(client: @client, name: "Main", cms_url: "https://cms.example", cms_token: "secret-token")

      assert_not_includes Site.connection.select_value("SELECT cms_token FROM website_checklist_sites WHERE id = #{site.id}"), "secret-token"
      site.revise(name: "Main site", cms_url: "https://cms.example", cms_token: "")
      assert_equal "secret-token", site.reload.cms_token
    end

    test "the summary counts what applies and is ready when all of it is confirmed without problems" do
      site = Site.create!(client: @client, name: "Main")
      ted = users(:ted)

      assert_not site.summary.ready?
      site.items.each { it.key == "search:bing" ? it.mark_not_applicable(by: ted) : it.confirm(by: ted, value: "yes") }
      summary = site.reload.summary

      assert_equal Site::Defaults::ITEMS.size - 1, summary.total
      assert_equal 1, summary.not_applicable
      assert summary.ready?
      assert_not site.needs_attention?
    end

    test "syncing fills in what the CMS says, item by item, and per form" do
      requests = stand_in_cms(full_cms)
      site = Site.create!(client: @client, name: "Main", cms_url: "https://cms.example", cms_token: "tok")

      assert site.sync_now
      assert_nil site.sync_error
      assert_equal "tok", requests.first.last

      item = ->(key) { site.items.find_by!(key: key) }
      assert_equal "Acme", item.("sender:from_name").value
      assert_equal "detected", item.("sender:from_name").kind
      assert_nil item.("sender:from_email").problem
      assert_equal "https://acme.example", item.("launch:domain").value
      assert_equal "https://acme.example/sitemap.xml (12 addresses)", item.("search:sitemap_url").value
      assert_equal "ann@acme.example, bob@acme.example", item.("forms:contact:notification").value
      assert_equal "Contact", item.("forms:contact:notification").subject
      assert_equal "On: “Thanks for writing” (content bbbb)", item.("forms:contact:confirmation").value
      assert_equal "https://cms.example/forms/contact/emails/confirmation/edit", item.("forms:contact:confirmation").href
      assert_equal "https://hooks.example/crm", item.("forms:contact:webhook").value
      assert_equal "recorded", item.("forms:contact:test").kind
      assert_match "Zapier → https://hooks.zapier.com/x", item.("webhooks:cms").value
      assert_not site.items.exists?(key: "forms:any:notification"), "the CMS's forms stand in for the standard ones"
    end

    test "a confirmed value the CMS no longer matches is changed, and back again is confirmed" do
      responses = full_cms
      stand_in_cms(responses)
      site = Site.create!(client: @client, name: "Main", cms_url: "https://cms.example", cms_token: "tok")
      site.sync_now
      recipients = site.items.find_by!(key: "forms:contact:notification")
      recipients.confirm(by: users(:ted))

      responses["/api/forms/contact/emails"][:emails][0][:recipients] = "ann@acme.example"
      site.sync_now
      assert_equal "changed", recipients.reload.state
      assert_equal "ann@acme.example", recipients.value
      assert_equal "ann@acme.example, bob@acme.example", recipients.confirmed_value
      assert site.needs_attention?

      responses["/api/forms/contact/emails"][:emails][0][:recipients] = "ann@acme.example, bob@acme.example"
      site.sync_now
      assert_equal "confirmed", recipients.reload.state
    end

    test "problems the CMS shows are flagged" do
      responses = full_cms
      responses["/api/settings/forms_settings"] = { setting: { key: "forms_settings", data: { from_name: "", from_email: "noreply@other.example" } } }
      responses["/api/forms/contact/emails"][:emails][0][:enabled] = false
      responses["/api/webhooks"][:webhooks][0][:last_status] = "failure"
      stand_in_cms(responses)
      site = Site.create!(client: @client, name: "Main", cms_url: "https://cms.example", cms_token: "tok")
      site.sync_now

      assert_match "Not set", site.items.find_by!(key: "sender:from_name").problem
      assert_match "acme.example", site.items.find_by!(key: "sender:from_email").problem
      assert_equal "Off", site.items.find_by!(key: "forms:contact:notification").value
      assert_match "nobody is told", site.items.find_by!(key: "forms:contact:notification").problem
      assert_match "Zapier", site.items.find_by!(key: "webhooks:cms").problem
    end

    test "what the token can't read is said, and the rest still syncs" do
      responses = full_cms
      responses["/api/webhooks"] = [ 403, { error: "forbidden" } ]
      responses.delete("/api/forms?status=published")
      responses.delete("/api/settings/forms_settings")
      stand_in_cms(responses)
      site = Site.create!(client: @client, name: "Main", cms_url: "https://cms.example", cms_token: "tok")

      assert_not site.sync_now
      assert_includes site.sync_error, "Webhooks: the token isn't allowed to read it"
      assert_includes site.sync_error, "Forms: the CMS has no forms"
      assert_not_includes site.sync_error, "Form email settings", "a setting never saved reads as empty"
      assert_match "Not set", site.items.find_by!(key: "sender:from_email").value
      assert site.items.exists?(key: "forms:any:notification"), "the standard Forms items stay"
      assert_equal "https://acme.example", site.items.find_by!(key: "launch:domain").value
    end

    test "a CMS that can't be reached never raises" do
      WebsiteChecklist::Cms.transport = ->(*) { raise Errno::ECONNREFUSED }
      site = Site.create!(client: @client, name: "Main", cms_url: "https://cms.example", cms_token: "tok")

      assert_not site.sync_now
      assert_match "couldn't reach https://cms.example", site.sync_error
      assert_equal Site::Defaults::ITEMS.size, site.items.count
    end

    test "a form no longer published says so" do
      responses = full_cms
      stand_in_cms(responses)
      site = Site.create!(client: @client, name: "Main", cms_url: "https://cms.example", cms_token: "tok")
      site.sync_now
      responses["/api/forms?status=published"] = { forms: [] }
      site.sync_now

      assert_match "No longer a published form", site.items.find_by!(key: "forms:contact:notification").problem
    end

    test "the nightly run queues a sync for each site the CMS runs" do
      Site.create!(client: @client, name: "By hand")
      Site.create!(client: @client, name: "CMS", cms_url: "https://cms.example", cms_token: "tok")

      assert_enqueued_jobs 1, only: Site::SyncJob do
        Site.sync_all_later
      end
    end
  end
end
