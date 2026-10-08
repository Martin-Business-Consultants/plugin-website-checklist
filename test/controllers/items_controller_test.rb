require_relative "../test_helper"

module WebsiteChecklist
  class ItemsControllerTest < ActionDispatch::IntegrationTest
    setup do
      Setting.current.toggle_plugin!(:website_checklist, enabled: true)
      @site = Site.create!(client: clients(:acme), name: "Acme site")
      @item = @site.items.find_by!(key: "forms:any:notification")
      sign_in_as users(:sarah)
    end

    test "record a value, then confirm it" do
      get edit_website_checklist_site_item_path(@site, @item)
      assert_response :success

      patch website_checklist_site_item_path(@site, @item), params: { item: { value: "ann@acme.example; cc bob@acme.example", note: "As Ann asked" } }
      assert_redirected_to website_checklist_site_path(@site, anchor: "item_#{@item.id}")
      assert_equal "ann@acme.example; cc bob@acme.example", @item.reload.value

      post website_checklist_site_item_confirmation_path(@site, @item)
      @item.reload
      assert_equal "confirmed", @item.state
      assert_equal "Sarah Staff", @item.confirmed_by_name
      assert_equal "ann@acme.example; cc bob@acme.example", @item.confirmed_value
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
