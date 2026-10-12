module WebsiteChecklist
  module Recommendations
    class ApprovalsController < ApplicationController
      allow_staff
      agent_tool :approve_website_recommendation, on: :create, title: "Approve an AI audit's recommendation",
        description: "Records the recommendation on its checklist step as yours (confirmed, in the history), with value and note changed first when given, and attaches any file it brought (the sitemap).",
        params: { recommendation: { value: "string", note: "string" } }, next_tools: %i[show_website_ai_audit]

      before_action :set_site, :set_recommendation

      def create
        attributes = params.fetch(:recommendation, {}).permit(:value, :note).to_h.symbolize_keys
        if @recommendation.approve!(by: Current.user, **attributes)
          redirect_to website_checklist_site_scans_path(@site, rec: @recommendation.scan.pending.first&.id),
            notice: "Recorded on “#{@recommendation.item.title}”."
        else
          redirect_to website_checklist_site_scans_path(@site, rec: @recommendation.id),
            alert: (@recommendation.errors.full_messages + @recommendation.item.errors.full_messages).to_sentence.presence || "Couldn't record it."
        end
      end
    end
  end
end
