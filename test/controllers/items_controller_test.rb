require_relative "../test_helper"

module WebsiteChecklist
  class ItemsControllerTest < ActionDispatch::IntegrationTest
    setup do
      Setting.current.toggle_plugin!(:website_checklist, enabled: true)
      @site = Site.create!(client: clients(:acme), name: "Acme site")
      @item = @site.items.find_by!(key: "forms:any:notification")
      sign_in_as users(:sarah)
    end

    test "saving a value confirms it as the saver's; emptying it is to confirm again" do
      get edit_website_checklist_site_item_path(@site, @item)
      assert_response :success

      patch website_checklist_site_item_path(@site, @item), params: { item: { value: "ann@acme.example; cc bob@acme.example" } }
      assert_redirected_to website_checklist_site_path(@site, anchor: "website_checklist_item_#{@item.id}")
      @item.reload
      assert_equal "confirmed", @item.state
      assert_equal "Sarah Staff", @item.confirmed_by_name
      assert_equal "ann@acme.example; cc bob@acme.example", @item.confirmed_value

      patch website_checklist_site_item_path(@site, @item), params: { item: { value: "" } }
      assert_equal "unconfirmed", @item.reload.state
      assert_nil @item.confirmed_value
    end

    test "the value edits in its frame, and saving sends the whole item back" do
      get edit_website_checklist_site_item_path(@site, @item), headers: { "Turbo-Frame" => "value_website_checklist_item_#{@item.id}" }
      assert_response :success
      assert_select "turbo-frame#value_website_checklist_item_#{@item.id} input[name='item[value]']"
      assert_select "input[name='item[note]']", count: 0

      patch website_checklist_site_item_path(@site, @item), params: { item: { value: "ann@acme.example" } }, as: :turbo_stream
      assert_response :success
      assert_match %(<turbo-stream action="replace" target="website_checklist_item_#{@item.id}">), response.body
      assert_match "Confirmed", response.body
      assert_match %(target="group_forms_website_checklist_site_#{@site.id}"), response.body
      assert_match "1 of 4 confirmed", response.body
      assert_match %(<turbo-stream action="replace" target="checklist_summary_website_checklist_site_#{@site.id}">), response.body
      assert_match "13 to confirm", response.body
      assert_match "ann@acme.example", response.body
    end

    test "a note alone saves without confirming" do
      patch website_checklist_site_item_path(@site, @item), params: { item: { note: "As Ann asked" } }, as: :turbo_stream
      assert_response :success
      assert_equal "As Ann asked", @item.reload.note
      assert_equal "unconfirmed", @item.state
    end

    test "confirm with a value in one go, then reopen" do
      post website_checklist_site_item_confirmation_path(@site, @item), params: { item: { value: "ann@acme.example" } }
      assert_equal "ann@acme.example", @item.reload.confirmed_value

      delete website_checklist_site_item_confirmation_path(@site, @item)
      assert_equal "unconfirmed", @item.reload.state
    end

    test "not applicable" do
      post website_checklist_site_item_not_applicable_path(@site, @item), params: { item: { note: "No forms" } }
      assert_equal "not_applicable", @item.reload.state
      assert_equal "No forms", @item.note
    end

    test "custom items are added and removed; standard ones can't be removed" do
      post website_checklist_site_items_path(@site), params: { item: { title: "Cookie banner", value: "Cookiebot" } }
      custom = @site.items.find_by!(title: "Cookie banner")
      assert_equal "Custom", custom.group

      delete website_checklist_site_item_path(@site, @item)
      assert @site.items.exists?(@item.id)
      assert_match "not applicable", flash[:alert]

      delete website_checklist_site_item_path(@site, custom)
      assert_not @site.items.exists?(custom.id)
    end

    test "an item that belongs to another site is not found" do
      other = Site.create!(client: clients(:globex), name: "Other")

      post website_checklist_site_item_confirmation_path(other, @item)
      assert_response :not_found
    end
  end
end
