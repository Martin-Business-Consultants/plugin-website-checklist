module WebsiteChecklist
  class SyncsController < ApplicationController
    allow_staff
    agent_tool :sync_website, on: :create, title: "Read a website's CMS",
      description: "Reads the CMS that runs the website (sender, each published form's emails and where it posts, webhooks, sitemap, domain) into its checklist, in the background. A confirmed item the CMS now says otherwise about shows as changed. show_website a moment later has the result, and what couldn't be read.",
      next_tools: %i[show_website]

    before_action :set_site

    def create
      if @site.cms_linked?
        @site.sync_later
        redirect_to website_checklist_site_path(@site), notice: "Reading #{@site.name}'s CMS. Refresh in a moment."
      else
        redirect_to website_checklist_site_path(@site), alert: "#{@site.name} has no CMS to read: its checklist is kept by hand."
      end
    end
  end
end
