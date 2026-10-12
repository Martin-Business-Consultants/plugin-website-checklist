module WebsiteChecklist
  module Recommendations
    class RejectionsController < ApplicationController
      allow_staff
      agent_tool :reject_website_recommendation, on: :create, title: "Reject an AI audit's recommendation",
        description: "Leaves its checklist step as it is.", next_tools: %i[show_website_ai_audit]

      before_action :set_site, :set_recommendation

      def create
        @recommendation.reject!(by: Current.user)
        redirect_to website_checklist_site_scans_path(@site, rec: @recommendation.scan.pending.first&.id),
          notice: "Rejected the recommendation for “#{@recommendation.item.title}”."
      end
    end
  end
end
