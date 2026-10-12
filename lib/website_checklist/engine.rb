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
          resources :audits, only: :index, path: "websites/history"
          resources :sites, path: "websites" do
            resources :scans, only: %i[index create]
            resources :todos, only: :create
            resources :recommendations, only: [] do
              resource :approval, only: :create, controller: "recommendations/approvals"
              resource :rejection, only: :create, controller: "recommendations/rejections"
            end
            resources :items, only: %i[create edit update destroy] do
              resources :files, only: %i[create destroy], controller: "items/files"
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
        author: "Martin Business Consultants", enabled_by_default: false, requires: ">= 2.24.0",
        homepage: "https://github.com/Martin-Business-Consultants/plugin-website-checklist",
        description: "Every client's websites, each with a step-by-step checklist to take it live: access to the " \
                     "domain, DNS, Search Console and Analytics first, then forms and email, launch and after launch, " \
                     "each recorded and confirmed by a person."
      # icon: arrived in Runwell 2.25; an older core would refuse it and fail to boot.
      nav_icon = Runwell::Plugins.method(:nav).parameters.any? { |_, name| name == :icon } ? { icon: "world" } : {}
      Runwell::Plugins.nav :website_checklist, "Websites", -> { website_checklist_sites_path }, **nav_icon
      Runwell::Plugins.permission :website_checklist, :manage_websites, name: "Add, change and delete websites", roles: %w[owner manager]
      Runwell::Plugins.stylesheet :website_checklist, "website_checklist/website_checklist"
      Runwell::Plugins.slot :client_panel, :website_checklist, "website_checklist/slots/client_panel"
      Runwell::Plugins.agent_workflow :website_checklist, "Taking a client's website live", <<~STEPS
        1. `list_websites` (show: attention) for the sites with steps still to do; `show_website` for one's checklist, in order, with how to do each step and its next_step.
        2. Work down the steps in order: access first (registrar, DNS, the domain's email, the current site, Search Console, Analytics, Business Profile, Bing), since later steps need it.
        3. `update_website_item` to record what's true (whose account, what we can do, the IDs): saving a value confirms it as yours. The Webhooks step takes webhooks_attributes (name, url, pairs). `mark_website_item_not_applicable` for what the site doesn't need.
        4. What only the client can do (adding us to an account, approving wording) goes to them as a question; never record a password or secret, only where it's kept.
      STEPS
    end
  end
end
