module WebsiteChecklist
  module Items
    # Files kept on a checklist step: a sitemap, a DNS export, a screenshot of an approval. The
    # page's drop box uploads them straight to storage and posts their signed ids; an agent posts
    # the files themselves. Either attaches.
    class FilesController < ApplicationController
      allow_staff
      agent_tool :add_website_item_file, on: :create, title: "Add a file to a website checklist step",
        description: "Keeps a file on the step (a sitemap, a DNS export, a screenshot), in its history too.",
        params: { files: "file!" }
      agent_tool :remove_website_item_file, on: :destroy, title: "Remove a file from a website checklist step",
        description: "The file's id is in show_website's items[].files."

      before_action :set_site, :set_item

      def create
        uploads = Array(params[:files]).compact_blank
        return redirect_to(website_checklist_site_path(@site, item: @item.id), alert: "Choose a file to add.") if uploads.empty?

        if (too_big = uploads.find { size_of(it) > Document::MAX_SIZE })
          return redirect_to(website_checklist_site_path(@site, item: @item.id), alert: "#{name_of(too_big)} is over the #{helpers.number_to_human_size(Document::MAX_SIZE)} limit.")
        end

        uploads.each { @item.add_file(it) }
        redirect_to website_checklist_site_path(@site, item: @item.id), notice: "Added #{uploads.many? ? "#{uploads.size} files" : "the file"} to “#{@item.title}”."
      end

      def destroy
        file = @item.files.attachments.find(params[:id])
        @item.remove_file(file)
        redirect_to website_checklist_site_path(@site, item: @item.id), notice: "Removed #{file.filename} from “#{@item.title}”."
      end

      private
        def blob_for(upload) = upload.is_a?(String) ? ActiveStorage::Blob.find_signed!(upload) : nil
        def size_of(upload) = blob_for(upload)&.byte_size || upload.size
        def name_of(upload) = blob_for(upload)&.filename&.to_s || upload.original_filename
    end
  end
end
