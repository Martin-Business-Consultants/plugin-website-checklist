module WebsiteChecklist
  module Items
    class NotApplicablesController < ApplicationController
      allow_staff
      agent_tool :mark_website_item_not_applicable, on: :create, title: "Mark a website checklist item not applicable",
        description: "This site doesn't need it (a site with no forms has no form emails). It stops counting toward the checklist. note: why.",
        params: { item: { note: "string" } }, next_tools: %i[show_website]

      before_action :set_site, :set_item

      def create
        @item.mark_not_applicable(by: Current.user, **params.fetch(:item, {}).permit(:note).to_h.symbolize_keys)
        redirect_to website_checklist_site_path(@site, anchor: "item_#{@item.id}"), notice: "“#{@item.title}” marked not applicable."
      end
    end
  end
end
