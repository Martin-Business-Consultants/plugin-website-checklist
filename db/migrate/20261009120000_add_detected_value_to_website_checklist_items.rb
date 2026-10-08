# What the CMS says, kept apart from the value a person holds to be true, so a person can write
# an item's value on a site the CMS runs and a CMS that says otherwise is flagged.
class AddDetectedValueToWebsiteChecklistItems < ActiveRecord::Migration[8.1]
  def up
    add_column :website_checklist_items, :detected_value, :text
    execute "UPDATE website_checklist_items SET detected_value = value WHERE kind = 'detected'"
  end

  def down
    remove_column :website_checklist_items, :detected_value
  end
end
