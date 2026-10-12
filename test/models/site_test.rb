require_relative "../test_helper"

module WebsiteChecklist
  class SiteTest < ActiveSupport::TestCase
    setup { @client = clients(:acme) }

    test "a new site starts with the standard checklist, once" do
      site = Site.create!(client: @client, name: "Main site", url: "https://acme.example/")

      assert_equal Site::Defaults::ITEMS.size, site.items.count
      assert_equal "https://acme.example", site.url
      assert site.items.all? { it.state == "unconfirmed" }
      assert_equal "access:registrar", site.next_item.key
      site.apply_standard_checklist
      assert_equal Site::Defaults::ITEMS.size, site.items.count
      assert_equal site, @client.website_checklist_sites.first
    end

    test "addresses need a scheme" do
      site = Site.new(client: @client, name: "Main", url: "acme.example")

      assert_not site.valid?
      assert site.errors[:url].any?
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
  end
end
