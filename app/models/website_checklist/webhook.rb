module WebsiteChecklist
  # A webhook the site's forms post to, recorded on the Webhooks step: its name, the address, and
  # the keys and values it's set up with (headers, field names, an account or list ID).
  class Webhook < ApplicationRecord
    include Audited

    belongs_to :item, touch: true, inverse_of: :webhooks

    serialize :pairs, coder: JSON, type: Array

    normalizes :name, :url, with: ->(text) { text.strip.presence }

    scope :ordered, -> { order(:position, :id) }

    # From the form, a hash of rows by index ({ "0" => { key:, value: } }) or a list; rows with no
    # key are dropped.
    def pairs=(rows)
      rows = rows.to_h.values unless rows.is_a?(Array)
      super(rows.filter_map do |row|
        row = row.to_h.stringify_keys
        { "key" => row["key"].to_s.strip, "value" => row["value"].to_s.strip } if row["key"].to_s.strip.present?
      end)
    end

    # "Zapier → https://hooks.zapier.com/… (list: 12, source: website)"
    def to_s
      line = [ name, url ].compact.join(" → ")
      pairs.any? ? "#{line} (#{pairs.map { "#{it["key"]}: #{it["value"]}" }.join(", ")})" : line
    end

    private
      def audit_site = item.site
      def audit_item_id = item_id
      def audit_label = name || url || "Webhook"
  end
end
