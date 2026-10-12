module WebsiteChecklist
  # One change to a website, a step or a webhook (Audited): who made it, when, from where (the app
  # or an agent, and through which connection), and each field's before and after as people read
  # them. Kept when what it describes is deleted.
  class Audit < ApplicationRecord
    FIELD_LABELS = { "name" => "Name", "url" => "Address", "client_id" => "Client", "title" => "Title", "detail" => "Detail",
      "group" => "Group", "value" => "Value", "confirmed_value" => "Confirmed as", "state" => "State", "note" => "Note",
      "custom" => "Custom", "pairs" => "Keys and values", "files" => "Files" }.freeze

    serialize :diff, coder: JSON, type: Hash

    belongs_to :actor, class_name: "User", optional: true

    scope :recent, -> { order(id: :desc) }

    def self.field_label(field) = FIELD_LABELS.fetch(field, field.humanize)

    # "Sarah", or "Ted's agent via Claude".
    def actor_label = [ actor_name || "Runwell", ("via #{via.presence || "an agent"}" if source == "agent") ].compact.join(" ")

    # "Webhook · Zapier", or the step's title.
    def subject_label = record_type == "Item" ? record_label : "#{record_type} · #{record_label}"
  end
end
