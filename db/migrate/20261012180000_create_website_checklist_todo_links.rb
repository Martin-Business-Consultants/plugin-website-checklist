# Work (the core's todos) made from a website's page: which site, and which step it's about.
# Points at the todo by id; a todo deleted in the core just drops out of the list.
class CreateWebsiteChecklistTodoLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :website_checklist_todo_links do |t|
      t.references :site, null: false, foreign_key: { to_table: :website_checklist_sites }
      t.references :item, foreign_key: { to_table: :website_checklist_items }
      t.integer :todo_id, null: false, index: true
      t.timestamps
    end
  end
end
