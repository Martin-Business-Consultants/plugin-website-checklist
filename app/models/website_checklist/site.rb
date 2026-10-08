module WebsiteChecklist
  # A client's website and its checklist: the facts of how it's set up, each recorded and
  # confirmed by a person. One run by the CMS also reads what the CMS can tell (Site::Syncable).
  class Site < ApplicationRecord
    include Syncable

    Summary = Data.define(:total, :confirmed, :changed, :unconfirmed, :not_applicable, :problems) do
      def ready? = total.positive? && confirmed == total && problems.zero?
      def to_h = super.merge(ready: ready?)
      def to_s = ready? ? "All #{total} confirmed" : "#{confirmed} of #{total} confirmed"
    end

    belongs_to :client
    has_many :items, -> { ordered }, dependent: :delete_all

    encrypts :cms_token

    normalizes :url, :cms_url, with: ->(url) { url.strip.chomp("/").presence }
    normalizes :name, with: ->(name) { name.strip }

    validates :name, presence: true
    validates :url, :cms_url, format: { with: %r{\Ahttps?://\S+\z}, message: "must start with http:// or https://" }, allow_nil: true
    validates :cms_token, presence: { message: "is needed to read the CMS" }, if: :cms_linked?

    after_create :add_default_items

    scope :ordered, -> { order(:name) }

    def cms_linked? = cms_url.present?

    def host
      URI.parse(url.to_s).host || url
    rescue URI::InvalidURIError
      url
    end

    # Saves a person's changes. The token field left blank keeps the token.
    def revise(attributes)
      attributes = attributes.to_h.symbolize_keys
      attributes.delete(:cms_token) if attributes[:cms_token].blank? && cms_token.present? && attributes[:cms_url].present?
      update(attributes)
    end

    # Counts over the items that apply (not the ones marked not applicable).
    def summary
      list = items.to_a
      applicable = list.reject(&:not_applicable?)
      Summary.new(total: applicable.size, confirmed: applicable.count(&:confirmed?), changed: applicable.count(&:changed?),
        unconfirmed: applicable.count { it.state == "unconfirmed" }, not_applicable: list.size - applicable.size,
        problems: applicable.count { it.problem.present? })
    end

    def needs_attention? = sync_error.present? || !summary.ready?

    # The standard checklist, once, when the site is added.
    def add_default_items
      existing = items.pluck(:key)
      now = Time.current
      rows = Defaults::ITEMS.each_with_index.filter_map do |item, index|
        item.merge(site_id: id, position: index * 10, created_at: now, updated_at: now) unless existing.include?(item[:key])
      end
      Item.insert_all!(rows) if rows.any?
      items.reset
    end
  end
end
