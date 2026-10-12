module WebsiteChecklist
  # The plugin's pages use the core's layout, and vanish while it's switched off.
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:website_checklist) }

    private
      def set_site = @site = Site.find(params[:site_id] || params[:id])
      def set_item = @item = @site.items.find(params[:item_id] || params[:id])
      def set_recommendation = @recommendation = Recommendation.joins(:scan).where(scan: { site_id: @site.id }).find(params[:recommendation_id])
  end
end
