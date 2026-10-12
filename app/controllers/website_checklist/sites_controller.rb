module WebsiteChecklist
  class SitesController < ApplicationController
    SHOW = %w[attention all].freeze

    allow_staff only: %i[index show]
    require_permission :manage_websites, except: %i[index show]
    agent_tool :list_websites, on: :index, title: "List websites",
      description: "Every client's websites with how much of each checklist is confirmed. show: attention (the default: something to confirm, changed since it was confirmed, a problem, or a CMS that couldn't be read) or all. client_id: one client's.",
      params: { show: SHOW, client_id: "integer" }, next_tools: %i[show_website create_website]
    agent_tool :show_website, on: :show, title: "Show a website's checklist",
      description: "A website and its checklist: each item's value, whether it's confirmed (and who confirmed it, when), changed since, not applicable, or has a problem. The source of truth for how the site is set up.",
      next_tools: %i[confirm_website_item update_website_item sync_website]
    agent_tool :create_website, on: :create, title: "Add a website",
      description: "A client's website, with the standard checklist. cms_url and cms_token: the LibrePublish CMS that runs it (a token that can read settings, forms and webhooks), so a sync fills in what the CMS can tell.",
      params: { site: { client_id: "integer!", name: "string!", url: "string", cms_url: "string", cms_token: "string" } },
      next_tools: %i[sync_website show_website]
    agent_tool :update_website, on: :update, title: "Change a website",
      description: "Its name, address, or the CMS it's read from. A blank cms_token keeps the one saved.",
      params: { site: { name: "string", url: "string", cms_url: "string", cms_token: "string" } }
    agent_tool :delete_website, on: :destroy, title: "Delete a website", description: "Forgets the website and its checklist."

    before_action :set_site, only: %i[show edit update destroy]

    def index
      @show = params[:show].presence_in(SHOW) || "attention"
      @client = Client.find(params[:client_id]) if params[:client_id].present?
      sites = Site.ordered.includes(:client, :items)
      sites = sites.where(client: @client) if @client
      @sites = @show == "attention" ? sites.select(&:needs_attention?) : sites.to_a
      @counts = { "attention" => sites.count(&:needs_attention?), "all" => sites.size }
    end

    def show
      @items = @site.items.to_a
      @item = @items.find { it.id.to_s == params[:item].to_s } || @items.find { website_item_needs_look?(it) } || @items.first
    end

    def new
      @site = Site.new(client_id: params[:client_id])
    end

    def create
      @site = Site.new(site_params)
      if @site.save
        @site.sync_later if @site.cms_linked?
        redirect_to website_checklist_site_path(@site), notice: "#{@site.name} added, with the standard checklist.#{" Reading its CMS…" if @site.cms_linked?}"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @site.revise(site_params.except(:client_id))
        @site.sync_later if @site.cms_linked? && @site.saved_change_to_cms_url?
        redirect_to website_checklist_site_path(@site), notice: "#{@site.name} saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @site.destroy!
      redirect_to website_checklist_sites_path, notice: "#{@site.name} deleted, with its checklist."
    end

    private
      def website_item_needs_look?(item) = item.state.in?(%w[unconfirmed changed]) || item.problem.present?

      def site_params = params.expect(site: %i[client_id name url cms_url cms_token])
  end
end
