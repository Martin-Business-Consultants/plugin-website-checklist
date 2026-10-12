# An AI audit of a site's domain: what was found from outside (facts), and the recommendations
# the AI made from it for the checklist's steps, each approved, changed or rejected by a person.
class CreateWebsiteChecklistScans < ActiveRecord::Migration[8.1]
  def change
    create_table :website_checklist_scans do |t|
      t.references :site, null: false, foreign_key: { to_table: :website_checklist_sites }
      t.integer :user_id, null: false
      t.string :domain, null: false
      t.string :state, null: false, default: "queued"
      t.text :facts
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    create_table :website_checklist_recommendations do |t|
      t.references :scan, null: false, foreign_key: { to_table: :website_checklist_scans }
      t.references :item, null: false, foreign_key: { to_table: :website_checklist_items }
      t.text :value
      t.text :note
      t.text :evidence
      t.string :confidence
      t.string :attach_file
      t.string :state, null: false, default: "pending"
      t.string :decided_by_name
      t.datetime :decided_at
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
