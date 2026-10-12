module WebsiteChecklist
  class SitesController < ApplicationController
    SHOW = %w[attention all].freeze

    allow_staff only: %i[index show]
    require_permission :manage_websites, except: %i[index show]
    agent_tool :list_websites, on: :index, title: "List websites",
      description: "Every client's websites with how much of each checklist is confirmed. show: attention (the default: a step still to do) or all. client_id: one client's.",
      params: { show: SHOW, client_id: "integer" }, next_tools: %i[show_website create_website]
    agent_tool :show_website, on: :show, title: "Show a website's checklist",
      description: "A website and its go-live checklist, in order: each step's value, whether it's confirmed (and who confirmed it, when) or not applicable, and how to do it. next_step is the first one still to do.",
      next_tools: %i[update_website_item confirm_website_item mark_website_item_not_applicable]
    agent_tool :create_website, on: :create, title: "Add a website",
      description: "A client's website, with the standard go-live checklist: access (domain, DNS, Search Console, Analytics…), forms and email, launch, after launch.",
      params: { site: { client_id: "integer!", name: "string!", url: "string" } },
      next_tools: %i[show_website]
    agent_tool :update_website, on: :update, title: "Change a website",
      description: "Its name or address.",
      params: { site: { name: "string", url: "string" } }
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
      @items = @site.items.with_attached_files.to_a
      @item = @items.find { it.id.to_s == params[:item].to_s } || @site.next_item || @items.first
    end

    def new
      @site = Site.new(client_id: params[:client_id])
    end

    def create
      @site = Site.new(site_params)
      if @site.save
        redirect_to website_checklist_site_path(@site), notice: "#{@site.name} added, with the go-live checklist."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @site.revise(site_params.except(:client_id))
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
      def site_params = params.expect(site: %i[client_id name url])
  end
end
