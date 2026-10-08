# The Website checklist plugin's tables, prefixed with its key. Clients are the core's, pointed at
# by id; a site's items go with it.
class CreateWebsiteChecklist < ActiveRecord::Migration[8.1]
  def change
    create_table :website_checklist_sites do |t|
      t.integer :client_id, null: false, index: true
      t.string :name, null: false
      t.string :url
      t.string :cms_url
      t.text :cms_token
      t.datetime :synced_at
      t.text :sync_error
      t.timestamps
    end

    create_table :website_checklist_items do |t|
      t.references :site, null: false, foreign_key: { to_table: :website_checklist_sites }
      t.string :key, null: false
      t.string :group, null: false
      t.string :subject
      t.string :title, null: false
      t.text :detail
      t.string :kind, null: false, default: "recorded"
      t.text :value
      t.text :confirmed_value
      t.string :state, null: false, default: "unconfirmed"
      t.text :problem
      t.text :note
      t.string :confirmed_by_name
      t.datetime :confirmed_at
      t.datetime :detected_at
      t.string :href
      t.integer :position, null: false, default: 0
      t.boolean :custom, null: false, default: false
      t.timestamps
      t.index %i[site_id key], unique: true
    end
  end
end
