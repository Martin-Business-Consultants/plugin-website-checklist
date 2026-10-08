require_relative "../test_helper"

module WebsiteChecklist
  class ItemTest < ActiveSupport::TestCase
    setup do
      @site = Site.create!(client: clients(:acme), name: "Main")
      @item = @site.items.find_by!(key: "search:google")
    end

    test "confirming keeps the value as what was confirmed, by whom and when" do
      @item.confirm(by: users(:ted), value: "sc-domain:acme.example, 8 Oct", note: "Ted's account")

      assert_equal "confirmed", @item.state
      assert_equal "sc-domain:acme.example, 8 Oct", @item.confirmed_value
      assert_equal "Ted Owner", @item.confirmed_by_name
      assert @item.confirmed_at
    end

    test "a new value has to be confirmed again; a note alone doesn't" do
      @item.confirm(by: users(:ted), value: "sc-domain:acme.example")
      @item.revise(note: "Submitted by Sarah")
      assert_equal "confirmed", @item.reload.state

      @item.revise(value: "https://www.acme.example/")
      assert_equal "unconfirmed", @item.reload.state
      assert_equal "sc-domain:acme.example", @item.confirmed_value
    end

    test "not applicable, then reopened" do
      @item.mark_not_applicable(by: users(:sarah), note: "No Google account")
      assert @item.not_applicable?
      assert_equal "Sarah Staff", @item.confirmed_by_name

      @item.reopen
      assert_equal "unconfirmed", @item.state
      assert_nil @item.confirmed_by_name
    end

    test "a value the CMS fills can't be written by hand" do
      @site.update!(cms_url: "https://cms.example", cms_token: "tok")
      @item.detect(value: "from the CMS")
      @item.revise(value: "typed")
      @item.confirm(by: users(:ted), value: "typed too")

      assert_equal "from the CMS", @item.reload.value
      assert_equal "from the CMS", @item.confirmed_value
    end

    test "custom items go under Custom and only they can change their title" do
      custom = Item.add_custom(@site, title: "Cookie banner", value: "Cookiebot")
      assert_equal "Custom", custom.group
      assert custom.custom?

      custom.revise(title: "Cookie consent")
      @item.revise(title: "Something else")
      assert_equal "Cookie consent", custom.reload.title
      assert_equal "Sitemap submitted to Google Search Console", @item.reload.title
    end
  end
end
