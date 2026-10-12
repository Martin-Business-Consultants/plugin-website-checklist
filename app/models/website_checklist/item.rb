module WebsiteChecklist
  # One step to take a website live: an access to get, a setting to record, a check to make. A
  # person records its value and confirms it; what they confirmed is kept (`confirmed_value`), so
  # a value changed later is to confirm again. The standard steps' guidance (`how`, `example`) is
  # read from Site::Defaults.
  class Item < ApplicationRecord
    GROUPS = [ *Site::Defaults::GROUPS, "Custom" ].freeze
    STATES = %w[unconfirmed confirmed not_applicable].freeze
    STATE_LABELS = { "unconfirmed" => "To do", "confirmed" => "Confirmed", "not_applicable" => "Not applicable" }.freeze

    # Left from reading a CMS (before 0.3); dropped in a later release.
    self.ignored_columns += %w[kind detected_value detected_at problem href]

    belongs_to :site, touch: true
    has_many :webhooks, -> { ordered }, dependent: :delete_all
    accepts_nested_attributes_for :webhooks, allow_destroy: true, reject_if: :blank_webhook?

    validates :key, presence: true, uniqueness: { scope: :site_id }
    validates :title, :group, presence: true
    validates :state, inclusion: { in: STATES }

    normalizes :value, :note, with: ->(text) { text.strip.presence }

    scope :ordered, -> { order(:position, :id) }

    # An item of the team's own, beyond the standard checklist (Custom).
    def self.add_custom(site, title:, detail: nil, value: nil, note: nil)
      site.items.create(key: "custom:#{SecureRandom.hex(4)}", group: "Custom", title: title, detail: detail,
        value: value, note: note, custom: true, position: (site.items.maximum(:position) || 0) + 1)
    end

    def state_label = STATE_LABELS.fetch(state)
    def confirmed? = state == "confirmed"
    def not_applicable? = state == "not_applicable"
    def settled? = confirmed? || not_applicable?

    def how = Site::Defaults::BY_KEY.dig(key, :how)
    def example = Site::Defaults::BY_KEY.dig(key, :example)

    # The Webhooks step records each webhook (name, address, keys and values) rather than a line
    # of text; its value is them, written out.
    def webhooks? = key == "webhooks:integrations"

    # The value as it is now is the truth, as this person says.
    def confirm(by:, value: self.value, note: self.note)
      update(value: value, note: note, confirmed_value: value.to_s.strip.presence, state: "confirmed",
        confirmed_by_name: by.display_name, confirmed_at: Time.current)
    end

    def mark_not_applicable(by:, note: self.note)
      update(note: note, state: "not_applicable", confirmed_by_name: by.display_name, confirmed_at: Time.current)
    end

    # Back to unconfirmed, forgetting who confirmed it.
    def reopen
      update(state: "unconfirmed", confirmed_value: nil, confirmed_by_name: nil, confirmed_at: nil)
    end

    # A person's change: a new value has to be confirmed again (what was confirmed stays, as "was").
    def revise(attributes)
      attributes = attributes.to_h.symbolize_keys
      if webhooks? && attributes.key?(:webhooks_attributes)
        self.webhooks_attributes = attributes[:webhooks_attributes]
        kept = webhooks.reject(&:marked_for_destruction?)
        kept.each_with_index { |webhook, index| webhook.position = index }
        self.value = kept.map(&:to_s).join("\n")
      end
      assign_attributes(attributes.slice(:value, :note, *(custom? ? %i[title detail] : [])))
      self.state = "unconfirmed" if value_changed? && !not_applicable?
      save
    end

    # A person saying what's true: the value (and any note) saved and confirmed as theirs, or
    # an empty value back to confirm.
    def record(attributes, by:)
      revise(attributes) && (value.present? ? confirm(by: by) : reopen)
    end

    private
      def blank_webhook?(attributes)
        attributes["id"].blank? && attributes["name"].blank? && attributes["url"].blank?
      end
  end
end
