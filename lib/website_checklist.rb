require "website_checklist/version"
require "website_checklist/engine"

# Website checklist: each client's websites, and for each the facts of how it's set up (who form
# emails go to and come from, what the confirmation says, where forms post, whether the sitemap
# went to the search engines, who signed off), recorded and confirmed by a person. A site run by
# the CMS fills in what the CMS can tell, and a confirmed fact that no longer matches shows as
# changed.
module WebsiteChecklist
  # Plugin tables are prefixed with the plugin's key.
  def self.table_name_prefix = "website_checklist_"
end
