module WebsiteChecklist
  # A piece of the core's work made from a website's page, and the step it's about (if any).
  class TodoLink < ApplicationRecord
    belongs_to :site
    belongs_to :item, optional: true
    belongs_to :todo, class_name: "::Todo"
  end
end
