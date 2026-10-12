require_relative "../test_helper"

module WebsiteChecklist
  class SitesControllerTest < ActionDispatch::IntegrationTest
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
      assert_includes response.body, "Google Search Console"
      assert_includes response.body, "Who gets form notifications"
      assert_select "#website_checklist_detail", 1
      assert_select "aside.settings__panel--side", 0
      assert_select "nav.scope-nav a[aria-current='page']", 1
      assert_select "#website_checklist_detail input[name='item[value]']"
      assert_select "#website_checklist_detail textarea[name='item[note]']"
      assert_select "form[action$='/confirmation']", count: 0
      assert_select "form[action$='/not_applicable']", 1

      item = @site.items.find_by!(key: "forms:any:notification")
      get website_checklist_site_path(@site, item: item.id)
      assert_select "a#link_website_checklist_item_#{item.id}[aria-current='page']"
      assert_select "#website_checklist_detail h2", item.title

      get website_checklist_site_path(@site, format: :json)
      body = response.parsed_body
      assert_match "Acme site: 0 of #{Site::Defaults::ITEMS.size} confirmed", body["summary"]
      assert_equal Site::Defaults::ITEMS.size, body["items"].size
      assert_equal "WebsiteChecklist::Site", body["type"]
    end

    test "adding a website" do
      post website_checklist_sites_path, params: { site: { client_id: clients(:globex).id, name: "Globex", url: "https://globex.example" } }
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

    test "the client's Websites tab" do
      get client_path(clients(:acme), tab: "plugin-website_checklist")
      assert_response :success
      assert_includes response.body, "Acme site"
      assert_includes response.body, new_website_checklist_site_path(client_id: clients(:acme).id)
    end
  end
end
