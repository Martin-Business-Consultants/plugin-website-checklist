module WebsiteChecklist
  # One fact about how a website is set up: who a form's emails go to, what the confirmation
  # says, whether the sitemap went to Google. Its value is recorded by a person, or detected from
  # the site's CMS (`kind`), and a person confirms it; what they confirmed is kept
  # (`confirmed_value`), so a detected value that moves away from it shows as changed.
  class Item < ApplicationRecord
    GROUPS = [ "Email sender", "Forms", "Webhooks", "Search", "Launch", "Custom" ].freeze
    STATES = %w[unconfirmed confirmed changed not_applicable].freeze
    STATE_LABELS = { "unconfirmed" => "To confirm", "confirmed" => "Confirmed", "changed" => "Changed",
                     "not_applicable" => "Not applicable" }.freeze
    KINDS = %w[recorded detected].freeze

    belongs_to :site, touch: true

    validates :key, presence: true, uniqueness: { scope: :site_id }
    validates :title, :group, presence: true
    validates :state, inclusion: { in: STATES }
    validates :kind, inclusion: { in: KINDS }

    normalizes :value, :note, with: ->(text) { text.strip.presence }

    scope :ordered, -> { order(:position, :id) }
    scope :needing_attention, -> { where(state: %w[unconfirmed changed]).or(where.not(problem: nil)) }

    # An item of the team's own, beyond the standard checklist (Custom).
    def self.add_custom(site, title:, detail: nil, value: nil, note: nil)
      site.items.create(key: "custom:#{SecureRandom.hex(4)}", group: "Custom", title: title, detail: detail,
        value: value, note: note, custom: true, position: (site.items.maximum(:position) || 0) + 1)
    end

    def state_label = STATE_LABELS.fetch(state)
    def detected? = kind == "detected"
    def confirmed? = state == "confirmed"
    def changed? = state == "changed"
    def not_applicable? = state == "not_applicable"
    def settled? = confirmed? || not_applicable?

    # A person may write the value unless the CMS it comes from writes it.
    def value_editable? = !(detected? && site.cms_linked?)

    # The value as it is now is the truth, as this person says.
    def confirm(by:, value: self.value, note: self.note)
      value = self.value unless value_editable?
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
      attributes = attributes.to_h.symbolize_keys.slice(:value, :note, *(custom? ? %i[title detail] : []))
      attributes.delete(:value) unless value_editable?
      assign_attributes(attributes)
      self.state = "unconfirmed" if value_changed? && !not_applicable?
      save
    end

    # What the CMS says now (Site#sync_now). A confirmed value it no longer matches is changed;
    # one that comes back to it is confirmed again.
    def detect(value:, problem: nil, href: nil, detail: nil)
      assign_attributes(kind: "detected", value: value, problem: problem, href: href, detected_at: Time.current)
      self.detail = detail if detail
      if confirmed? && self.value.to_s != confirmed_value.to_s
        self.state = "changed"
      elsif changed? && self.value.to_s == confirmed_value.to_s
        self.state = "confirmed"
      end
      save!
    end
  end
end
