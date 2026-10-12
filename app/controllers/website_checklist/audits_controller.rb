require "csv"

module WebsiteChecklist
  # Every change to websites, their steps and webhooks, newest first: for one site (site_id), one
  # step and its webhooks (item_id), or all of them; downloadable as CSV.
  class AuditsController < ApplicationController
    PER_PAGE = 100
    CSV_LIMIT = 50_000

    allow_staff
    agent_tool :website_history, on: :index, title: "Read the websites' history",
      description: "Every change to websites, their checklist steps and webhooks, newest first: who made it (and whether through an agent), when, and each field's before and after. site_id: one website's; item_id (with site_id): one step's, with its webhooks; before: an audit id, for the page after.",
      params: { site_id: "integer", item_id: "integer", before: "integer" }

    def index
      @site = Site.find(params[:site_id]) if params[:site_id].present?
      @item = @site.items.find(params[:item_id]) if @site && params[:item_id].present?
      scope = filtered(Audit.recent.includes(:actor))

      respond_to do |format|
        format.html { @audits = page(scope) }
        format.json { @audits = page(scope) }
        format.csv { send_data csv(scope.limit(CSV_LIMIT)), filename: "#{(@site&.name || "websites").parameterize}-history-#{Date.current}.csv", type: "text/csv" }
      end
    end

    private
      def filtered(scope)
        scope = scope.where(site_id: @site.id) if @site
        scope = scope.where(item_id: @item.id) if @item
        scope
      end

      def page(scope)
        scope = scope.where(id: ...params[:before].to_i) if params[:before].present?
        audits = scope.limit(PER_PAGE + 1).to_a
        @older = audits.size > PER_PAGE ? audits[PER_PAGE - 1].id : nil
        audits.first(PER_PAGE)
      end

      def csv(audits)
        CSV.generate do |rows|
          rows << %w[When Who Source Website Subject Action Field Before After]
          audits.each do |audit|
            changes = audit.diff.presence || { "" => [ nil, nil ] }
            changes.each do |field, (before, after)|
              rows << [ audit.created_at.iso8601, audit.actor_label, audit.source, audit.site_name, audit.subject_label, audit.action,
                (Audit.field_label(field) if field.present?), before, after ]
            end
          end
        end
      end
  end
end
