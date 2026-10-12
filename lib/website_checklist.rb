require "website_checklist/version"
require "website_checklist/engine"

# Website checklist: each client's websites, and for each the steps to take it live, in order:
# access first (registrar, DNS, the domain's email, the current site, Search Console, Analytics,
# Business Profile, Bing), then forms and email, launch and after launch. A person records what
# each step needs and confirms it.
module WebsiteChecklist
  # Plugin tables are prefixed with the plugin's key.
  def self.table_name_prefix = "website_checklist_"
end
