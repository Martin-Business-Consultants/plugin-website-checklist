module WebsiteChecklist
  class ItemsController < ApplicationController
    allow_staff
    agent_tool :add_website_item, on: :create, title: "Add an item to a website's checklist",
      description: "An item of your own, beyond the standard checklist (it goes under Custom): what to check, and its value if known.",
      params: { item: { title: "string!", detail: "string", value: "string", note: "string" } }, next_tools: %i[confirm_website_item]
    agent_tool :update_website_item, on: :update, title: "Record a website checklist item's value",
      description: "The item's value (what is true now) and a note. Saving a value confirms it as yours, with the time; an empty value is to confirm again. A custom item's title and detail can change too. The Webhooks item records webhooks_attributes instead of a value: each webhook's name, url and pairs (keys and values); pass id to change one, id with _destroy: true to remove it.",
      params: { item: { value: "string", note: "string", title: "string", detail: "string",
        webhooks_attributes: [ { id: "integer", name: "string", url: "string", pairs: [ { key: "string", value: "string" } ], _destroy: "boolean" } ] } },
      next_tools: %i[confirm_website_item]
    agent_tool :delete_website_item, on: :destroy, title: "Remove a custom item from a website's checklist",
      description: "Only items added beyond the standard checklist can be removed; mark the others not applicable."

    before_action :set_site
    before_action :set_item, only: %i[edit update destroy]

    def create
      item = Item.add_custom(@site, **params.expect(item: %i[title detail value note]).to_h.symbolize_keys)
      if item.persisted?
        redirect_to website_checklist_site_path(@site, item: item.id), notice: "Added “#{item.title}” to #{@site.name}."
      else
        redirect_to website_checklist_site_path(@site), alert: item.errors.full_messages.to_sentence
      end
    end

    def edit
    end

    # A value saved is confirmed as the saver's (Item#record); a note or a custom item's title
    # alone is only revised. The site's page gets the item back on the right, and its row in the list.
    def update
      attributes = params.expect(item: [ :value, :note, :title, :detail, webhooks_attributes: [ [ :id, :name, :url, :_destroy, pairs: [ %i[key value] ] ] ] ])
      recording = attributes.key?(:value) || attributes.key?(:webhooks_attributes)
      saved = recording ? @item.record(attributes, by: Current.user) : @item.revise(attributes)

      if saved
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to website_checklist_site_path(@site, item: @item.id), notice: "“#{@item.title}” saved." }
        end
      else
        render :edit, formats: :html, status: :unprocessable_entity
      end
    end

    def destroy
      return redirect_to(website_checklist_site_path(@site), alert: "Only an item added to the standard checklist can be removed: mark it not applicable instead.") unless @item.custom?

      @item.destroy!
      redirect_to website_checklist_site_path(@site), notice: "Removed “#{@item.title}”."
    end
  end
end
