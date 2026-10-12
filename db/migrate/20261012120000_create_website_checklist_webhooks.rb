# Webhooks recorded on a site's Webhooks step: each its name, address and keys and values.
class CreateWebsiteChecklistWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :website_checklist_webhooks do |t|
      t.references :item, null: false, foreign_key: { to_table: :website_checklist_items }
      t.string :name
      t.string :url
      t.text :pairs
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
