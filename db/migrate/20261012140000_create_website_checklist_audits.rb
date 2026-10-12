# Every change to a website, its steps and its webhooks: who, when, from where, and each field's
# before and after. No foreign keys: the history outlives what it describes.
class CreateWebsiteChecklistAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :website_checklist_audits do |t|
      t.integer :site_id, index: true
      t.string :site_name
      t.integer :item_id, index: true
      t.string :record_type, null: false
      t.integer :record_id
      t.string :record_label
      t.string :action, null: false
      t.text :diff
      t.integer :actor_id, index: true
      t.string :actor_name
      t.string :source
      t.string :via
      t.datetime :created_at, null: false
    end
  end
end
