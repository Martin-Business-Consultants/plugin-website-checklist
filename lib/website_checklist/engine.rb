module WebsiteChecklist
  # A Runwell plugin: it owns its tables (website_checklist_*), points at core records by id, and
  # reaches the core only through the plugin contract (docs/plugin-contract.md in Runwell). Remove
  # it and Runwell runs as before.
  class Engine < ::Rails::Engine
    # Routes join the app's route set (as website_checklist_*), so the core layout's helpers work
    # on the plugin's pages.
    initializer "website_checklist.routes" do |app|
      app.routes.append do
        scope module: "website_checklist", as: "website_checklist" do
          resources :sites, path: "websites" do
            resource :sync, only: :create
            resources :items, only: %i[create edit update destroy] do
              resource :confirmation, only: %i[create destroy], controller: "items/confirmations"
              resource :not_applicable, only: :create, controller: "items/not_applicables"
            end
          end
        end
      end
    end

    initializer "website_checklist.helpers" do
      ActiveSupport.on_load(:action_view) { include WebsiteChecklist::SitesHelper }
    end

    # A client's websites. Never a column on clients.
    initializer "website_checklist.models" do
      ActiveSupport.on_load(:runwell_client) do
        has_many :website_checklist_sites, class_name: "WebsiteChecklist::Site", dependent: :destroy
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :website_checklist, name: "Websites", version: WebsiteChecklist::VERSION,
        author: "Martin Business Consultants", enabled_by_default: false, requires: ">= 2.21.0",
        homepage: "https://github.com/Martin-Business-Consultants/runwell-website-checklist",
        description: "Every client's websites, each with a checklist of how it's set up (who form emails go to and " \
                     "come from, what the confirmation says, webhooks, the sitemap sent to search engines, sign-off), " \
                     "confirmed by a person. A site run by the CMS fills in what it can tell, and flags what changed."
      Runwell::Plugins.nav :website_checklist, "Websites", -> { website_checklist_sites_path }
      Runwell::Plugins.permission :website_checklist, :manage_websites, name: "Add, change and delete websites", roles: %w[owner manager]
      Runwell::Plugins.stylesheet :website_checklist, "website_checklist/website_checklist"
      Runwell::Plugins.slot :client_panel, :website_checklist, "website_checklist/slots/client_panel"
      Runwell::Plugins.nightly :website_checklist, -> { WebsiteChecklist::Site.sync_all_later }
      Runwell::Plugins.agent_workflow :website_checklist, "Checking a client's website", <<~STEPS
        1. `list_websites` (show: attention) for the sites with something to confirm, a change or a problem; `show_website` for one's checklist.
        2. `sync_website` on a site run by the CMS to read what it says now; items it fills can't be written by hand.
        3. `update_website_item` to record what's true (who the notification goes to, when the sitemap went to Google), then `confirm_website_item` once checked; `mark_website_item_not_applicable` for what the site doesn't need.
        4. A changed item means the CMS no longer matches what was confirmed: find out which is right, then confirm it again or fix the CMS.
      STEPS
    end
  end
end
