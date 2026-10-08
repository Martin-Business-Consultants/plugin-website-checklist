module WebsiteChecklist
  # Reads a site's CMS into its checklist (Site#sync_now), off the request.
  class Site::SyncJob < ApplicationJob
    def perform(site) = site.sync_now
  end
end
