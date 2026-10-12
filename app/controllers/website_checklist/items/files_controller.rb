module WebsiteChecklist
  module Items
    # Files kept on a checklist step: a sitemap, a DNS export, a screenshot of an approval.
    class FilesController < ApplicationController
      allow_staff
      agent_tool :add_website_item_file, on: :create, title: "Add a file to a website checklist step",
        description: "Keeps a file on the step (a sitemap, a DNS export, a screenshot), in its history too.",
        params: { files: "file[]" }
      agent_tool :remove_website_item_file, on: :destroy, title: "Remove a file from a website checklist step",
        description: "The file's id is in show_website's items[].files."

      before_action :set_site, :set_item

      def create
        uploads = Array(params[:files]).compact_blank
        return redirect_to(website_checklist_site_path(@site, item: @item.id), alert: "Choose a file to add.") if uploads.empty?

        uploads.each { @item.add_file(it) }
        redirect_to website_checklist_site_path(@site, item: @item.id), notice: "Added #{uploads.many? ? "#{uploads.size} files" : "the file"} to “#{@item.title}”."
      end

      def destroy
        file = @item.files.attachments.find(params[:id])
        @item.remove_file(file)
        redirect_to website_checklist_site_path(@site, item: @item.id), notice: "Removed #{file.filename} from “#{@item.title}”."
      end
    end
  end
end
