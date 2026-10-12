module WebsiteChecklist
  module Items
    class ConfirmationsController < ApplicationController
      allow_staff
      agent_tool :confirm_website_item, on: :create, title: "Confirm a website checklist item",
        description: "Says the item's value is true, as you checked it: it's kept as what was confirmed, with your name and the time. value and note are recorded first when given (not for a value the CMS fills).",
        params: { item: { value: "string", note: "string" } }, next_tools: %i[show_website]
      agent_tool :reopen_website_item, on: :destroy, title: "Reopen a website checklist item",
        description: "Undoes a confirmation or not applicable: the item is to confirm again."

      before_action :set_site, :set_item

      def create
        attributes = params.fetch(:item, {}).permit(:value, :note).to_h.symbolize_keys
        if @item.confirm(by: Current.user, **attributes)
          redirect_to website_checklist_site_path(@site, item: @item.id), notice: "Confirmed “#{@item.title}”."
        else
          redirect_to website_checklist_site_path(@site), alert: @item.errors.full_messages.to_sentence
        end
      end

      def destroy
        @item.reopen
        redirect_to website_checklist_site_path(@site, item: @item.id), notice: "“#{@item.title}” is to confirm again."
      end
    end
  end
end
