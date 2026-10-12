# The checklist is now the steps to take a site live, in order, kept by hand (the CMS reading is
# gone). Items the CMS made go, unless a person recorded something on them (those become custom
# items); "changed" (the CMS moved away from a confirmed value) is back to to-do; and every site
# gets the new standard steps in their order. The CMS columns stay until a later release.
class ReorderWebsiteChecklistsForGoLive < ActiveRecord::Migration[8.1]
  def up
    standard = WebsiteChecklist::Site::Defaults::ITEMS.map { it[:key] }
    quoted = standard.map { connection.quote(it) }.join(", ")

    execute <<~SQL
      DELETE FROM website_checklist_items
      WHERE custom = 0 AND key NOT IN (#{quoted}) AND state = 'unconfirmed' AND note IS NULL
        AND (value IS NULL OR kind = 'detected')
    SQL
    execute <<~SQL
      UPDATE website_checklist_items SET custom = 1, "group" = 'Custom', position = position + 1000
      WHERE custom = 0 AND key NOT IN (#{quoted})
    SQL
    execute "UPDATE website_checklist_items SET position = position + 1000 WHERE custom = 1 AND position < 1000"
    execute "UPDATE website_checklist_items SET state = 'unconfirmed' WHERE state = 'changed'"
    execute "UPDATE website_checklist_items SET kind = 'recorded'"

    WebsiteChecklist::Site.find_each(&:apply_standard_checklist)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
