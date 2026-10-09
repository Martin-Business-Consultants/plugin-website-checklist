require_relative "../test_helper"

module WebsiteChecklist
  class SitesControllerTest < ActionDispatch::IntegrationTest
    include CmsStandIn, ActiveJob::TestHelper

    setup do
      Setting.current.toggle_plugin!(:website_checklist, enabled: true)
      @site = Site.create!(client: clients(:acme), name: "Acme site", url: "https://acme.example")
      sign_in_as users(:sarah)
    end

    test "404 while the plugin is off" do
      Setting.current.toggle_plugin!(:website_checklist, enabled: false)

      get website_checklist_sites_path
      assert_response :not_found
    end

    test "the index shows what needs attention, and all" do
      done = Site.create!(client: clients(:globex), name: "Globex site")
      done.items.each { it.confirm(by: users(:ted), value: "yes") }

      get website_checklist_sites_path
      assert_response :success
      assert_includes response.body, "Acme site"
      assert_not_includes response.body, "Globex site"

      get website_checklist_sites_path(show: "all")
      assert_includes response.body, "Globex site"
    end

    test "the index as JSON, for agents" do
      get website_checklist_sites_path(format: :json, show: "all")

      body = response.parsed_body
      assert_equal "1 website", body["summary"]
      assert_equal "Acme site", body["websites"].first["name"]
      assert_equal 0, body["websites"].first["checklist"]["confirmed"]
      assert_equal "Acme Co", body["websites"].first["client"]["display_name"]
    end

    test "a website's checklist, page and JSON" do
      get website_checklist_site_path(@site)
      assert_response :success
      assert_includes response.body, "Sitemap submitted to Google Search Console"
      assert_includes response.body, "Admin notification goes to (to and CCs)"
      assert_select "details.website-checklist-group", count: response.body.scan("website-checklist-group ").size
      assert_select "details.website-checklist-group[open]", 1
      assert_select "a[href=?][title='Open all']", website_checklist_site_path(@site, open: "all")
      assert_select "turbo-frame[id^='value_website_checklist_item_'] a.website-checklist-editable"
      assert_select "dialog textarea[name='item[note]']"
      assert_select "form[action$='/confirmation']", count: 0
      assert_select "form[action$='/not_applicable']", count: 0

      get website_checklist_site_path(@site, open: "all")
      assert_select "details.website-checklist-group:not([open])", 0

      get website_checklist_site_path(@site, format: :json)
      body = response.parsed_body
      assert_match "Acme site: 0 of #{Site::Defaults::ITEMS.size} confirmed", body["summary"]
      assert_equal Site::Defaults::ITEMS.size, body["items"].size
      assert_equal "WebsiteChecklist::Site", body["type"]
    end

    test "adding a website with a CMS reads it" do
      assert_enqueued_jobs 1, only: Site::SyncJob do
        post website_checklist_sites_path, params: { site: { client_id: clients(:globex).id, name: "Globex", url: "https://globex.example",
          cms_url: "https://cms.globex.example", cms_token: "tok" } }
      end
      site = Site.find_by!(name: "Globex")
      assert_redirected_to website_checklist_site_path(site)
      assert_equal clients(:globex), site.client
    end

    test "the form and its errors" do
      get new_website_checklist_site_path(client_id: clients(:acme).id)
      assert_response :success

      post website_checklist_sites_path, params: { site: { client_id: clients(:acme).id, name: "" } }
      assert_response :unprocessable_entity
    end

    test "editing and deleting" do
      get edit_website_checklist_site_path(@site)
      assert_response :success

      patch website_checklist_site_path(@site), params: { site: { name: "Acme main site" } }
      assert_equal "Acme main site", @site.reload.name

      delete website_checklist_site_path(@site)
      assert_redirected_to website_checklist_sites_path
      assert_not Site.exists?(@site.id)
    end

    test "only owners and managers add, change and delete websites" do
      member = User.create!(email_address: "member@example.com", name: "Mo Member", role: "member", password: "password")
      sign_in_as member

      get website_checklist_site_path(@site)
      assert_response :success
      delete website_checklist_site_path(@site)
      assert Site.exists?(@site.id)
    end

    test "Read the CMS queues a sync, or says there's no CMS" do
      post website_checklist_site_sync_path(@site)
      assert_redirected_to website_checklist_site_path(@site)
      assert_match "no CMS", flash[:alert]

      @site.update!(cms_url: "https://cms.example", cms_token: "tok")
      stand_in_cms(full_cms)
      perform_enqueued_jobs { post website_checklist_site_sync_path(@site) }
      assert_equal "Acme", @site.items.find_by!(key: "sender:from_name").value

      get website_checklist_site_path(@site)
      assert_includes response.body, "Open in the CMS"
      assert_includes response.body, "ann@acme.example, bob@acme.example"
    end

    test "the client's Websites tab" do
      get client_path(clients(:acme), tab: "plugin-website_checklist")
      assert_response :success
      assert_includes response.body, "Acme site"
      assert_includes response.body, new_website_checklist_site_path(client_id: clients(:acme).id)
    end
  end
end
